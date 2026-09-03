import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, content-type, apikey','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json'}});
const enc=new TextEncoder();
function bytesToHex(bytes:Uint8Array){return [...bytes].map(b=>b.toString(16).padStart(2,'0')).join('')}
async function sha256Hex(s:string){return bytesToHex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(s))))}
const clean=(v:any,max=500)=>String(v??'').trim().slice(0,max);
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 try{
  const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const auth=req.headers.get('authorization')||'',token=auth.startsWith('Bearer ')?auth.slice(7).trim():'';
  if(!token)return json({error:'UNAUTHORIZED'},401);
  const tokenHash=await sha256Hex(token);
  const {data:session}=await admin.from('staff_sessions').select('id,user_id,expires_at,revoked_at').eq('token_hash',tokenHash).maybeSingle();
  if(!session||session.revoked_at||new Date(session.expires_at).getTime()<=Date.now())return json({error:'SESSION_EXPIRED'},401);
  const {data:staff}=await admin.from('staff_accounts').select('is_active').eq('user_id',session.user_id).maybeSingle();
  if(!staff?.is_active)return json({error:'FORBIDDEN'},403);
  const {data:perm}=await admin.from('staff_permissions').select('permission_code').eq('user_id',session.user_id).eq('permission_code','programs.manage').eq('is_allowed',true).maybeSingle();
  if(!perm)return json({error:'FORBIDDEN'},403);
  const body=await req.json();const action=clean(body.action,50),programId=clean(body.program_id,80);
  if(!programId)return json({error:'PROGRAM_REQUIRED'},400);
  const {data:program}=await admin.from('am_programs').select('id,cover_image_path').eq('id',programId).maybeSingle();
  if(!program)return json({error:'PROGRAM_NOT_FOUND'},404);
  if(action==='save_appearance'){
   const theme=clean(body.card_theme||'aviation_blue',40);
   if(!['aviation_blue','light','dark','kids_colorful'].includes(theme))return json({error:'INVALID_THEME'},400);
   const overlay=Math.max(0,Math.min(85,Number(body.overlay_strength??42)));
   const alt=clean(body.cover_image_alt,250)||null;
   const {data,error}=await admin.from('am_programs').update({card_theme:theme,overlay_strength:overlay,cover_image_alt:alt,updated_at:new Date().toISOString()}).eq('id',programId).select().single();
   if(error)throw error;return json({ok:true,program:data});
  }
  if(action==='upload_cover'){
   const filename=clean(body.filename||'cover.jpg',200),contentType=clean(body.content_type||'image/jpeg',80),dataB64=String(body.data_base64||'');
   if(!dataB64)return json({error:'MISSING_IMAGE_DATA'},400);
   if(!['image/jpeg','image/png','image/webp'].includes(contentType))return json({error:'INVALID_IMAGE_TYPE'},400);
   const raw=atob(dataB64),bytes=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);
   if(bytes.length>5*1024*1024)return json({error:'IMAGE_TOO_LARGE'},413);
   const safe=filename.replace(/[^a-zA-Z0-9._-]/g,'-'),path=`${programId}/${Date.now()}-${safe}`;
   const up=await admin.storage.from('program-images').upload(path,bytes,{contentType,upsert:false});if(up.error)throw up.error;
   if(program.cover_image_path)await admin.storage.from('program-images').remove([program.cover_image_path]);
   const {data,error}=await admin.from('am_programs').update({cover_image_path:path,cover_image_alt:clean(body.alt_text,250)||filename,updated_at:new Date().toISOString()}).eq('id',programId).select().single();
   if(error)throw error;return json({ok:true,program:data});
  }
  if(action==='delete_cover'){
   if(program.cover_image_path)await admin.storage.from('program-images').remove([program.cover_image_path]);
   const {data,error}=await admin.from('am_programs').update({cover_image_path:null,cover_image_alt:null,updated_at:new Date().toISOString()}).eq('id',programId).select().single();
   if(error)throw error;return json({ok:true,program:data});
  }
  return json({error:'INVALID_ACTION'},400);
 }catch(e){console.error(e);return json({error:'SERVER_ERROR',detail:String((e as any)?.message||e)},500)}
});