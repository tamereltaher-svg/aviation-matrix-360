import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS'};
const reply=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
const clean=(v:unknown,n=220)=>String(v??'').trim().slice(0,n);
const routes=['applicant','guardian','employer','instructor','institution'];
const fields:Record<string,string[]>={applicant:['date_of_birth','education_stage','aviation_interest'],guardian:['child_name','birth_year','relationship'],employer:['organization','company_type','job_title','country','website'],instructor:['professional_role','qualifications','experience','teaching_areas'],institution:['organization','country','representative_role','training_areas']};
async function hash(s:string){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s))),b=>b.toString(16).padStart(2,'0')).join('')}
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return reply({error:'METHOD_NOT_ALLOWED'},405);
 try{
  const raw=await req.text();if(raw.length>16000)return reply({error:'REQUEST_TOO_LARGE'},413);
  let b:any;try{b=JSON.parse(raw)}catch{return reply({error:'INVALID_JSON'},400)}
  const url=Deno.env.get('SUPABASE_URL')!,key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const auth=req.headers.get('authorization')||'',token=auth.startsWith('Bearer ')?auth.slice(7):'';
  if(!token)return reply({error:'UNAUTHORIZED'},401);
  const check=(r:any)=>{if(r.error)throw r.error;return r.data};
  if(['review_queue','review'].includes(b.action)){
   const meResponse=await fetch(url+'/functions/v1/staff-admin-api',{method:'POST',headers:{'Content-Type':'application/json',Authorization:auth},body:JSON.stringify({action:'me'})});
   const me=await meResponse.json();if(!meResponse.ok)return reply({error:'UNAUTHORIZED'},401);
   const allowed=new Set(me.permissions||[]);
   if(!allowed.has('registration.manage')&&!(b.action==='review_queue'&&allowed.has('registration.read')))return reply({error:'FORBIDDEN'},403);
   if(b.action==='review_queue'){
    const requests=check(await db.from('am_access_requests').select('*').neq('status','draft').order('updated_at',{ascending:false}).limit(200));
    const ids=[...new Set(requests.map((r:any)=>r.user_id))];
    const profiles=ids.length?check(await db.from('am_access_profiles').select('*').in('user_id',ids)):[];
    return reply({requests,profiles});
   }
   const status=clean(b.status,30),message=clean(b.message,1000);
   if(!['more_info','reviewed','rejected'].includes(status)||message.length<3)return reply({error:'INVALID_REVIEW'},400);
   const result=await db.rpc('am_access_review',{p_id:clean(b.id,80),p_actor:me.staff.user_id,p_status:status,p_message:message});
   if(result.error)return reply({error:'REVIEW_CONFLICT'},409);
   return reply({request:result.data});
  }
  const {data:{user},error}=await db.auth.getUser(token);
  if(error||!user||!user.email_confirmed_at||!user.email)return reply({error:'VERIFIED_ACCOUNT_REQUIRED'},401);
  const rate=check(await db.rpc('am_check_public_api_rate_limit',{p_scope_hash:await hash('identity|'+user.id),p_action:'identity_access',p_window_seconds:900,p_max_requests:120}));
  if(!rate?.ok)return reply({error:'RATE_LIMITED'},429);
  if(b.action==='me'){
   const profile=check(await db.from('am_access_profiles').select('*').eq('user_id',user.id).maybeSingle());
   const requests=check(await db.from('am_access_requests').select('*').eq('user_id',user.id).order('created_at'));
   const bindings=check(await db.from('am_application_auth_bindings').select('application_number,lead_id').eq('auth_user_id',user.id).is('revoked_at',null));
   return reply({profile,requests,applications:bindings,email:user.email});
  }
  if(b.action==='save_profile'){
   const full_name=clean(b.full_name),mobile=clean(b.mobile,80),city=clean(b.city,120);
   if(full_name.length<2)return reply({error:'FULL_NAME_REQUIRED'},400);
   const profile=check(await db.from('am_access_profiles').upsert({user_id:user.id,full_name,mobile,city,updated_at:new Date().toISOString()}).select().single());
   return reply({profile});
  }
  if(b.action==='save_request'){
   const route=clean(b.route,30);if(!routes.includes(route))return reply({error:'INVALID_ROUTE'},400);
   const payload:Record<string,unknown>={};for(const f of fields[route])payload[f]=clean(b.payload?.[f],1000);
   payload.consent=b.payload?.consent===true;payload.consent_version='intake-2026-11-05';
   const submit=b.submit===true;
   if(submit){
    if(!payload.consent)return reply({error:'CONSENT_REQUIRED'},400);
    const required=fields[route].filter(f=>f!=='website');if(required.some(f=>!payload[f]))return reply({error:'COMPLETE_REQUIRED_FIELDS'},400);
    const profile=check(await db.from('am_access_profiles').select('*').eq('user_id',user.id).maybeSingle());
    if(!profile?.mobile||!profile?.city)return reply({error:'COMPLETE_PROFILE_FIRST'},400);
    if(route==='applicant'){
     if(!['school','secondary','university','graduate','other'].includes(String(payload.education_stage))||!['cabin_crew','passenger_services','cargo','ground_operations','flight_ops','not_sure'].includes(String(payload.aviation_interest)))return reply({error:'INVALID_APPLICATION_FIELDS'},400);
     const d=String(payload.date_of_birth),date=new Date(d+'T00:00:00Z');
     if(!/^\d{4}-\d{2}-\d{2}$/.test(d)||!Number.isFinite(date.getTime())||date.toISOString().slice(0,10)!==d||date.getTime()>Date.now()||date.getUTCFullYear()<1900)return reply({error:'INVALID_DATE'},400);
     if(date.getTime()>new Date(new Date().getUTCFullYear()-18,new Date().getUTCMonth(),new Date().getUTCDate()).getTime())return reply({error:'USE_GUARDIAN_ROUTE_UNDER_18'},400);
    }
    if(route==='guardian'){
     const y=Number(payload.birth_year),year=new Date().getUTCFullYear();if(!Number.isInteger(y)||y<year-17||y>year-6)return reply({error:'CHILD_AGE_6_TO_17'},400);
    }
    payload.submission_consent_at=new Date().toISOString();
   }
   const r=await db.rpc('am_access_submit',{p_user:user.id,p_email:user.email,p_route:route,p_payload:payload,p_submit:submit});
   if(r.error){console.error('intake_transaction',r.error.code);return reply({error:'REQUEST_NOT_SAVED'},409)}
   return reply({request:r.data});
  }
  return reply({error:'INVALID_ACTION'},400);
 }catch(e){console.error('identity-access-api failure');return reply({error:'SERVER_ERROR'},500)}
});
