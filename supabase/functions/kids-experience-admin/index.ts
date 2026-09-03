import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, content-type, apikey','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json'}});
const enc=new TextEncoder();
const hex=(a:Uint8Array)=>[...a].map(b=>b.toString(16).padStart(2,'0')).join('');
const sha=async(s:string)=>hex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(s))));
const clean=(v:any,max=500)=>String(v??'').trim().slice(0,max);
const now=()=>new Date().toISOString();
async function authStaff(req:Request,admin:any){
 const a=req.headers.get('authorization')||'',t=a.startsWith('Bearer ')?a.slice(7).trim():''; if(!t) return null;
 const h=await sha(t); const {data:s}=await admin.from('staff_sessions').select('id,user_id,expires_at,revoked_at').eq('token_hash',h).maybeSingle();
 if(!s||s.revoked_at||new Date(s.expires_at).getTime()<=Date.now()) return null;
 const {data:st}=await admin.from('staff_accounts').select('user_id,is_active').eq('user_id',s.user_id).maybeSingle(); if(!st?.is_active)return null;
 const {data:p}=await admin.from('staff_permissions').select('permission_code').eq('user_id',s.user_id).eq('permission_code','kids.manage').eq('is_allowed',true).maybeSingle(); if(!p)return null;
 await admin.from('staff_sessions').update({last_seen_at:now()}).eq('id',s.id); return s;
}
async function issuePortalToken(admin:any,passportId:string,label='Learner Portal',days=90){
 const raw=crypto.randomUUID()+crypto.randomUUID().replaceAll('-',''); const token_hash=await sha(raw); const expires_at=new Date(Date.now()+Math.max(1,days)*86400000).toISOString();
 const {error}=await admin.from('kids_portal_access_tokens').insert({passport_id:passportId,token_hash,label,expires_at}); if(error)throw error; return {token:raw,expires_at};
}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors}); if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 try{
  const staff=await authStaff(req,admin); if(!staff)return json({error:'UNAUTHORIZED'},401); const b=await req.json(); const action=clean(b.action,60);
  if(action==='list_passports'){
   const {data,error}=await admin.from('kids_passport_experience_summary').select('*').order('journey_ref'); if(error)throw error;
   const ids=(data||[]).map((x:any)=>x.passport_id); let photos:any[]=[]; if(ids.length){const r=await admin.from('kids_explorer_passports').select('id,profile_photo_path,profile_photo_updated_at').in('id',ids); photos=r.data||[];}
   const pm=Object.fromEntries(photos.map((x:any)=>[x.id,x])); return json({items:(data||[]).map((x:any)=>({...x,profile_photo_path:pm[x.passport_id]?.profile_photo_path||null,profile_photo_updated_at:pm[x.passport_id]?.profile_photo_updated_at||null}))});
  }
  if(action==='create_passport'){
   const journey_ref=clean(b.journey_ref,120), learner_display_name=clean(b.learner_display_name,120)||null, level_code=clean(b.level_code||'L1',20); if(!journey_ref)return json({error:'JOURNEY_REF_REQUIRED'},400);
   const {data:l,error:le}=await admin.from('kids_levels').select('id,code').eq('code',level_code).single(); if(le)throw le;
   const {data:s,error:se}=await admin.from('kids_seasons').select('id,code').eq('level_id',l.id).order('sort_order').limit(1).single(); if(se)throw se;
   const {data:m,error:me}=await admin.from('kids_missions').select('id,code').eq('season_id',s.id).order('sort_order').limit(1).single(); if(me)throw me;
   const {data:p,error:pe}=await admin.from('kids_explorer_passports').insert({journey_ref,learner_display_name,current_level_id:l.id,current_season_id:s.id,current_mission_id:m.id,status:'active'}).select().single(); if(pe)throw pe;
   await admin.from('kids_passport_mission_progress').insert({passport_id:p.id,mission_id:m.id,status:'in_progress',started_at:now()});
   await admin.from('kids_passport_season_progress').insert({passport_id:p.id,season_id:s.id,status:'in_progress'});
   await admin.from('kids_passport_level_progress').insert({passport_id:p.id,level_id:l.id,status:'in_progress'});
   const access=await issuePortalToken(admin,p.id,'Initial Learner Portal',Number(b.days||90)); return json({ok:true,passport:p,access});
  }
  if(action==='issue_access_token'){
   const passport_id=clean(b.passport_id,80); if(!passport_id)return json({error:'PASSPORT_REQUIRED'},400); const access=await issuePortalToken(admin,passport_id,clean(b.label,100)||'Learner Portal',Number(b.days||90)); return json({ok:true,access});
  }
  if(action==='revoke_access_token'){
   const id=clean(b.id,80); const {error}=await admin.from('kids_portal_access_tokens').update({revoked_at:now()}).eq('id',id); if(error)throw error; return json({ok:true});
  }
  if(action==='upload_profile_photo'){
   const passport_id=clean(b.passport_id,80),filename=clean(b.filename||'profile.jpg',180),mime=clean(b.content_type||'image/jpeg',80),base64=String(b.data_base64||'');
   if(!passport_id||!base64)return json({error:'MISSING_PHOTO_DATA'},400); if(!['image/jpeg','image/png','image/webp'].includes(mime))return json({error:'INVALID_IMAGE_TYPE'},400);
   const raw=atob(base64),bytes=new Uint8Array(raw.length); for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i); if(bytes.length>5*1024*1024)return json({error:'PHOTO_TOO_LARGE'},413);
   const {data:old}=await admin.from('kids_explorer_passports').select('profile_photo_path').eq('id',passport_id).single();
   const ext=mime==='image/png'?'png':mime==='image/webp'?'webp':'jpg',path=`passport/${passport_id}/profile-${Date.now()}.${ext}`;
   const up=await admin.storage.from('kids-profile-photos').upload(path,bytes,{contentType:mime,upsert:false}); if(up.error)throw up.error;
   const {error}=await admin.from('kids_explorer_passports').update({profile_photo_path:path,profile_photo_updated_at:now(),updated_at:now()}).eq('id',passport_id); if(error)throw error;
   if(old?.profile_photo_path)await admin.storage.from('kids-profile-photos').remove([old.profile_photo_path]); return json({ok:true,path});
  }
  if(action==='remove_profile_photo'){
   const passport_id=clean(b.passport_id,80); const {data:p}=await admin.from('kids_explorer_passports').select('profile_photo_path').eq('id',passport_id).single(); if(p?.profile_photo_path)await admin.storage.from('kids-profile-photos').remove([p.profile_photo_path]);
   const {error}=await admin.from('kids_explorer_passports').update({profile_photo_path:null,profile_photo_updated_at:now(),updated_at:now()}).eq('id',passport_id); if(error)throw error; return json({ok:true});
  }
  if(action==='profile_photo_url'){
   const passport_id=clean(b.passport_id,80); const {data:p,error}=await admin.from('kids_explorer_passports').select('profile_photo_path').eq('id',passport_id).single(); if(error)throw error; if(!p?.profile_photo_path)return json({url:null}); const {data,error:se}=await admin.storage.from('kids-profile-photos').createSignedUrl(p.profile_photo_path,300); if(se)throw se; return json({url:data.signedUrl,expires_in:300});
  }
  if(action==='grant_entitlement'){
   const passport_id=clean(b.passport_id,80),content_item_id=clean(b.content_item_id,80),entitlement_type=clean(b.entitlement_type||'admin',30),source_ref=clean(b.source_ref,150)||null;
   if(!passport_id||!content_item_id)return json({error:'PASSPORT_AND_CONTENT_REQUIRED'},400); if(!['free','program','purchase','institution','admin'].includes(entitlement_type))return json({error:'INVALID_ENTITLEMENT'},400);
   const {data,error}=await admin.from('kids_content_entitlements').insert({passport_id,content_item_id,entitlement_type,source_ref,status:'active'}).select().single(); if(error)throw error; return json({ok:true,item:data});
  }
  if(action==='upload_protected_asset'){
   const content_item_id=clean(b.content_item_id,80),asset_type=clean(b.asset_type||'other',30),filename=clean(b.filename||'asset.bin',220),mime=clean(b.content_type||'application/octet-stream',100),base64=String(b.data_base64||'');
   if(!content_item_id||!base64)return json({error:'MISSING_ASSET_DATA'},400); const raw=atob(base64),bytes=new Uint8Array(raw.length); for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i); if(bytes.length>50*1024*1024)return json({error:'ASSET_TOO_LARGE'},413);
   const safe=filename.replace(/[^a-zA-Z0-9._-]/g,'-'),path=`content/${content_item_id}/${Date.now()}-${safe}`; const up=await admin.storage.from('kids-protected-assets').upload(path,bytes,{contentType:mime,upsert:false}); if(up.error)throw up.error;
   const {data,error}=await admin.from('kids_content_assets').insert({content_item_id,asset_type,storage_path:path,storage_bucket:'kids-protected-assets',is_protected:true,file_name:filename,mime_type:mime,language_code:clean(b.language_code||'en',10),is_primary:!!b.is_primary,is_downloadable:!!b.is_downloadable,sort_order:Number(b.sort_order||999)}).select().single(); if(error)throw error; return json({ok:true,asset:data});
  }
  return json({error:'INVALID_ACTION'},400);
 }catch(e){console.error(e);return json({error:'SERVER_ERROR',detail:String((e as any)?.message||e)},500)}
});