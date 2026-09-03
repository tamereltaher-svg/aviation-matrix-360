import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, content-type, apikey','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json'}});
const enc=new TextEncoder(); const hex=(a:Uint8Array)=>[...a].map(b=>b.toString(16).padStart(2,'0')).join(''); const sha=async(s:string)=>hex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(s))));
const clean=(v:any,max=500)=>String(v??'').trim().slice(0,max); const now=()=>new Date().toISOString();
async function authPassport(req:Request,admin:any){
 const a=req.headers.get('authorization')||'',t=a.startsWith('Bearer ')?a.slice(7).trim():''; if(!t)return null; const h=await sha(t);
 const {data:s}=await admin.from('kids_portal_access_tokens').select('id,passport_id,expires_at,revoked_at').eq('token_hash',h).maybeSingle(); if(!s||s.revoked_at||(s.expires_at&&new Date(s.expires_at).getTime()<=Date.now()))return null;
 const {data:p}=await admin.from('kids_explorer_passports').select('id,status').eq('id',s.passport_id).maybeSingle(); if(!p||p.status!=='active')return null;
 await admin.from('kids_portal_access_tokens').update({last_used_at:now()}).eq('id',s.id); return s;
}
async function hasEntitlement(admin:any,passportId:string,itemId:string,type:string){
 const ts=now();
 const {data:e}=await admin.from('kids_content_entitlements').select('id').eq('passport_id',passportId).eq('content_item_id',itemId).eq('entitlement_type',type).eq('status','active').lte('starts_at',ts).or(`ends_at.is.null,ends_at.gt.${ts}`).limit(1);
 return (e||[]).length>0;
}
async function canAccessContent(admin:any,passportId:string,item:any){
 if(item.status!=='published')return false;
 const access=String(item.access_level||'');
 if(access==='admin_only')return false;
 if(access==='free'||access==='public_preview')return true;
 if(access==='registered')return true;
 if(access==='purchased')return await hasEntitlement(admin,passportId,item.id,'purchase');
 if(access==='institution_licensed')return await hasEntitlement(admin,passportId,item.id,'institution');
 if(access==='program_only'){
  if(await hasEntitlement(admin,passportId,item.id,'program'))return true;
  if(item.mission_id){const {data:p}=await admin.from('kids_passport_mission_progress').select('status').eq('passport_id',passportId).eq('mission_id',item.mission_id).maybeSingle(); if(p&&['in_progress','completed'].includes(p.status))return true;}
  if(item.season_id){const {data:p}=await admin.from('kids_passport_season_progress').select('status').eq('passport_id',passportId).eq('season_id',item.season_id).maybeSingle(); if(p&&['in_progress','completed'].includes(p.status))return true;}
  return false;
 }
 return false;
}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors}); if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 try{
  const s=await authPassport(req,admin); if(!s)return json({error:'UNAUTHORIZED'},401); const b=await req.json(); const action=clean(b.action||'me',50); const pid=s.passport_id;
  if(action==='me'){
   const {data:summary,error}=await admin.from('kids_passport_experience_summary').select('*').eq('passport_id',pid).single(); if(error)throw error;
   const {data:passport}=await admin.from('kids_explorer_passports').select('id,journey_ref,learner_display_name,current_level_id,current_season_id,current_mission_id,status,started_at,profile_photo_path,profile_photo_updated_at').eq('id',pid).single();
   let profile_photo_url=null; if(passport?.profile_photo_path){const {data:su}=await admin.storage.from('kids-profile-photos').createSignedUrl(passport.profile_photo_path,900); profile_photo_url=su?.signedUrl||null;}
   const {data:levels}=await admin.from('kids_levels').select('id,code,name,age_range,sort_order').eq('is_active',true).order('sort_order');
   const {data:seasons}=await admin.from('kids_seasons').select('id,level_id,code,name,sort_order,mission_count').eq('is_active',true).order('sort_order');
   const {data:missions}=await admin.from('kids_missions').select('id,season_id,code,title,name,big_question,learning_goal,stamp_name,next_mission_code,sort_order').eq('is_active',true).order('sort_order');
   const [{data:mp},{data:sp},{data:lp},{data:certs}]=await Promise.all([
    admin.from('kids_passport_mission_progress').select('mission_id,status,started_at,completed_at,stamp_id,stamp_awarded_at').eq('passport_id',pid),
    admin.from('kids_passport_season_progress').select('season_id,completed_missions,collected_stamps,status,badge_id,badge_awarded_at,completed_at').eq('passport_id',pid),
    admin.from('kids_passport_level_progress').select('level_id,completed_seasons,collected_badges,status,completion_badge_id,completed_at').eq('passport_id',pid),
    admin.from('kids_certificates').select('id,level_id,certificate_type,status,issued_at,certificate_asset_path').eq('passport_id',pid).order('issued_at',{ascending:false})
   ]);
   const {data:items}=await admin.from('kids_content_items').select('id,code,title,content_type,language_code,short_description,cover_image_path,access_level,level_id,season_id,mission_id,status,commercial_mode,base_price,currency').eq('status','published').order('sort_order');
   const content:any[]=[]; for(const i of items||[]){content.push({...i,accessible:await canAccessContent(admin,pid,i)});}
   return json({passport:{...passport,profile_photo_url},summary,levels:levels||[],seasons:seasons||[],missions:missions||[],mission_progress:mp||[],season_progress:sp||[],level_progress:lp||[],certificates:certs||[],content});
  }
  if(action==='mission'){
   const mission_id=clean(b.mission_id,80); const {data:m,error}=await admin.from('kids_missions').select('id,season_id,code,title,name,big_question,learning_goal,stamp_name,next_mission_code,sort_order').eq('id',mission_id).single(); if(error)throw error;
   const {data:p}=await admin.from('kids_passport_mission_progress').select('*').eq('passport_id',pid).eq('mission_id',mission_id).maybeSingle(); const unlocked=!!p&&['in_progress','completed'].includes(p.status);
   const {data:items}=await admin.from('kids_content_items').select('id,code,title,content_type,language_code,short_description,description,duration_minutes,cover_image_path,thumbnail_path,access_level,level_id,season_id,mission_id,status,is_featured,sort_order,commercial_mode,base_price,currency,price_unit,allow_direct_purchase').eq('status','published').eq('mission_id',mission_id).order('sort_order'); const content:any[]=[]; for(const i of items||[])content.push({...i,accessible:await canAccessContent(admin,pid,i)});
   await admin.from('kids_experience_events').insert({passport_id:pid,event_type:'mission_view',mission_id,metadata:{unlocked}}); return json({mission:m,progress:p||null,unlocked,content});
  }
  if(action==='rewards'){
   const [{data:stamps},{data:badges},{data:certs}]=await Promise.all([
    admin.from('kids_passport_mission_progress').select('mission_id,status,stamp_id,stamp_awarded_at,kids_stamps(code,name,visual_brief)').eq('passport_id',pid).not('stamp_id','is',null),
    admin.from('kids_passport_season_progress').select('season_id,status,badge_id,badge_awarded_at,kids_badges(code,name,visual_brief)').eq('passport_id',pid).not('badge_id','is',null),
    admin.from('kids_certificates').select('*').eq('passport_id',pid).order('issued_at',{ascending:false})
   ]); return json({stamps:stamps||[],badges:badges||[],certificates:certs||[]});
  }
  if(action==='asset_url'){
   const asset_id=clean(b.asset_id,80); const {data:a,error}=await admin.from('kids_content_assets').select('*,kids_content_items(*)').eq('id',asset_id).single(); if(error)throw error; const item=a.kids_content_items; if(!await canAccessContent(admin,pid,item))return json({error:'LOCKED'},403);
   await admin.from('kids_experience_events').insert({passport_id:pid,event_type:'asset_open',content_item_id:item.id,metadata:{asset_id}});
   if(a.is_protected||a.storage_bucket==='kids-protected-assets'){const {data,error:se}=await admin.storage.from(a.storage_bucket||'kids-protected-assets').createSignedUrl(a.storage_path,300); if(se)throw se; return json({url:data.signedUrl,expires_in:300});}
   const bucket=a.storage_bucket||'kids-assets'; const {data}=admin.storage.from(bucket).getPublicUrl(a.storage_path); return json({url:data.publicUrl,expires_in:null});
  }
  if(action==='content_assets'){
   const content_item_id=clean(b.content_item_id,80); const {data:i,error}=await admin.from('kids_content_items').select('id,code,title,content_type,language_code,short_description,access_level,level_id,season_id,mission_id,status,commercial_mode,base_price,currency').eq('id',content_item_id).single(); if(error)throw error; const accessible=await canAccessContent(admin,pid,i);
   if(!accessible)return json({content:{id:i.id,code:i.code,title:i.title,content_type:i.content_type,access_level:i.access_level},accessible:false,assets:[]});
   const {data:a,error:ae}=await admin.from('kids_content_assets').select('id,asset_type,file_name,mime_type,language_code,is_downloadable,is_primary,is_protected').eq('content_item_id',content_item_id).order('sort_order'); if(ae)throw ae; return json({content:i,accessible:true,assets:a||[]});
  }
  if(action==='set_preferences'){
   const preferred_language=clean(b.preferred_language||'en',10); const {data,error}=await admin.from('kids_portal_preferences').upsert({passport_id:pid,preferred_language,reduced_motion:!!b.reduced_motion,audio_enabled:b.audio_enabled!==false,updated_at:now()},{onConflict:'passport_id'}).select().single(); if(error)throw error; return json({ok:true,preferences:data});
  }
  return json({error:'INVALID_ACTION'},400);
 }catch(e){console.error(e);return json({error:'SERVER_ERROR',detail:String((e as any)?.message||e)},500)}
});