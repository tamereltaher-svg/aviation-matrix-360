import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'content-type, authorization, apikey',
  'Access-Control-Allow-Methods':'POST, OPTIONS'
};
const enc=new TextEncoder();
const clean=(v:any,n=500)=>String(v??'').trim().slice(0,n);
const json=(b:unknown,s=200,extra:Record<string,string>={})=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store',...extra}});
async function sha(s:string){const h=await crypto.subtle.digest('SHA-256',enc.encode(s));return [...new Uint8Array(h)].map(b=>b.toString(16).padStart(2,'0')).join('')}
function randomToken(){const b=new Uint8Array(32);crypto.getRandomValues(b);return [...b].map(x=>x.toString(16).padStart(2,'0')).join('')}
function clientIp(req:Request){return clean(req.headers.get('cf-connecting-ip')||req.headers.get('x-forwarded-for')?.split(',')[0]||'unknown',120)}
const emailOk=(s:string)=>/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
const appOk=(s:string)=>/^AM-A-\d{4}-\d{6}$/.test(s);
const dateOk=(s:string)=>/^\d{4}-\d{2}-\d{2}$/.test(s)&&!Number.isNaN(new Date(`${s}T00:00:00Z`).getTime())&&new Date(`${s}T00:00:00Z`).getTime()<=Date.now();

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
  if(req.method!=='POST') return json({error:'METHOD_NOT_ALLOWED'},405);
  const len=Number(req.headers.get('content-length')||0);
  if(len>32768) return json({error:'REQUEST_TOO_LARGE'},413);

  const url=Deno.env.get('SUPABASE_URL')!;
  const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anonKey=Deno.env.get('SUPABASE_ANON_KEY')!;
  const admin=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const ip=clientIp(req);

  async function scope(kind:string,raw:string){return await sha(`application-access-v2|${serviceKey}|${kind}|${raw.toLowerCase()}`)}
  async function rate(kind:string,raw:string,action:string,max:number,windowSeconds:number){
    const {data,error}=await admin.rpc('am_check_public_api_rate_limit',{p_scope_hash:await scope(kind,raw),p_action:action,p_window_seconds:windowSeconds,p_max_requests:max});
    if(error) throw error;
    return data;
  }
  async function limited(kind:string,raw:string,action:string,max:number,windowSeconds:number){const r=await rate(kind,raw,action,max,windowSeconds);return r?.ok?null:r}
  async function findAuthUserByEmail(email:string){
    for(let page=1;page<=10;page++){
      const {data,error}=await admin.auth.admin.listUsers({page,perPage:1000});
      if(error) return null;
      const u=(data?.users||[]).find((x:any)=>clean(x.email,320).toLowerCase()===email.toLowerCase());
      if(u) return u;
      if((data?.users||[]).length<1000) break;
    }
    return null;
  }
  async function genericSend(){return json({ok:true,sent:true,channel:'email',masked_email:'your registered email'});}

  try{
    const body=await req.json().catch(()=>({}));
    const action=clean(body.action,60).toLowerCase();

    if(action==='register'){
      const ipr=await limited('ip',ip,'application_register_ip',10,3600);if(ipr)return json({error:'RATE_LIMITED',retry_after_seconds:ipr.retry_after_seconds||60},429,{'Retry-After':String(ipr.retry_after_seconds||60)});
      const fullName=clean(body.full_name,220),mobile=clean(body.mobile,80).replace(/\s+/g,''),email=clean(body.email,220).toLowerCase(),dob=clean(body.date_of_birth,20);
      const education=clean(body.education_stage,80),city=clean(body.current_city,120),interest=clean(body.aviation_interest,100),language=clean(body.preferred_language,20)||'en';
      if(!fullName||!mobile||!email||!dob||!education||!city||!interest||body.consent!==true) return json({error:'INVALID_APPLICATION_INPUT'},400);
      if(!emailOk(email)||!dateOk(dob)) return json({error:'INVALID_APPLICATION_INPUT'},400);
      const cr=await limited('contact',email,'application_register_contact',3,3600);if(cr)return json({error:'RATE_LIMITED',retry_after_seconds:cr.retry_after_seconds||60},429,{'Retry-After':String(cr.retry_after_seconds||60)});
      const mr=await limited('contact',mobile,'application_register_mobile',3,3600);if(mr)return json({error:'RATE_LIMITED',retry_after_seconds:mr.retry_after_seconds||60},429,{'Retry-After':String(mr.retry_after_seconds||60)});
      const {data,error}=await admin.rpc('public_register_application',{p_full_name:fullName,p_mobile:mobile,p_email:email,p_date_of_birth:dob,p_education_stage:education,p_current_city:city,p_aviation_interest:interest,p_preferred_language:language,p_consent:true});
      if(error){console.error('register_application',error.code);return json({error:'APPLICATION_NOT_ACCEPTED'},400)}
      const appNo=clean(data?.application_number,80).toUpperCase();
      const {data:lead,error:leadErr}=await admin.from('aviation_interest_leads').select('id').eq('application_number',appNo).maybeSingle();
      if(leadErr||!lead) throw leadErr||new Error('LEAD_NOT_FOUND_AFTER_REGISTER');
      const resumeToken=randomToken(),tokenHash=await sha(resumeToken),expiresAt=new Date(Date.now()+30*24*3600*1000).toISOString();
      const {error:te}=await admin.from('am_application_resume_tokens').insert({lead_id:lead.id,token_hash:tokenHash,expires_at:expiresAt});if(te)throw te;
      return json({...data,resume_token:resumeToken,resume_token_expires_at:expiresAt});
    }

    if(action==='resume_token'){
      const appNo=clean(body.application_number,80).toUpperCase(),resumeToken=clean(body.resume_token,200);
      if(!appOk(appNo)||!/^[a-f0-9]{64}$/i.test(resumeToken)) return json({error:'INVALID_OR_EXPIRED_RESUME_TOKEN'},401);
      const ir=await limited('ip',ip,'application_resume_token_ip',60,900);if(ir)return json({error:'RATE_LIMITED',retry_after_seconds:ir.retry_after_seconds||60},429,{'Retry-After':String(ir.retry_after_seconds||60)});
      const tr=await limited('token',resumeToken,'application_resume_token',20,900);if(tr)return json({error:'RATE_LIMITED',retry_after_seconds:tr.retry_after_seconds||60},429,{'Retry-After':String(tr.retry_after_seconds||60)});
      const oldHash=await sha(resumeToken),nextToken=randomToken(),nextHash=await sha(nextToken),nextExp=new Date(Date.now()+30*24*3600*1000).toISOString();
      const {data:rot,error:rotErr}=await admin.rpc('am_consume_application_resume_token',{p_token_hash:oldHash,p_application_number:appNo,p_new_token_hash:nextHash,p_new_expires_at:nextExp});
      if(rotErr||!rot?.ok) return json({error:'INVALID_OR_EXPIRED_RESUME_TOKEN'},401);
      const {data:lead}=await admin.from('aviation_interest_leads').select('email,date_of_birth').eq('id',rot.lead_id).maybeSingle();
      if(!lead) return json({error:'INVALID_OR_EXPIRED_RESUME_TOKEN'},401);
      const [{data:application,error:aErr},{data:assessment,error:sErr}]=await Promise.all([
        admin.rpc('public_resume_application',{p_application_number:appNo,p_email:lead.email,p_date_of_birth:lead.date_of_birth}),
        admin.rpc('public_resume_assessment',{p_application_number:appNo,p_email:lead.email,p_date_of_birth:lead.date_of_birth})
      ]);
      if(aErr||sErr) throw aErr||sErr;
      return json({ok:true,application,assessment,resume_token:nextToken,resume_token_expires_at:nextExp});
    }

    const appNo=clean(body.application_number,80).toUpperCase();
    if(!appOk(appNo)) return action==='send'?genericSend():json({error:'INVALID_OR_EXPIRED_CODE'},401);

    if(action==='send'){
      const ir=await limited('ip',ip,'application_otp_send_ip',20,900);if(ir)return json({error:'RATE_LIMITED',retry_after_seconds:ir.retry_after_seconds||60},429,{'Retry-After':String(ir.retry_after_seconds||60)});
      const ar=await limited('application',appNo,'application_otp_send_application',5,900);if(ar)return json({error:'RATE_LIMITED',retry_after_seconds:ar.retry_after_seconds||60},429,{'Retry-After':String(ar.retry_after_seconds||60)});
      const {data:lead}=await admin.from('aviation_interest_leads').select('id,email').eq('application_number',appNo).maybeSingle();
      if(!lead?.email) return await genericSend();
      const email=clean(lead.email,220).toLowerCase();
      const cr=await limited('contact',email,'application_otp_send_contact',5,900);if(cr)return json({error:'RATE_LIMITED',retry_after_seconds:cr.retry_after_seconds||60},429,{'Retry-After':String(cr.retry_after_seconds||60)});
      const user=await findAuthUserByEmail(email);
      if(user){
        try{
          await fetch(`${url}/auth/v1/otp`,{method:'POST',headers:{'Content-Type':'application/json','apikey':anonKey},body:JSON.stringify({email,create_user:false})});
          await admin.from('application_otp_requests').upsert({application_number:appNo,last_sent_at:new Date().toISOString(),send_count:1},{onConflict:'application_number'});
        }catch(e){console.error('otp_send_internal',e)}
      }
      return await genericSend();
    }

    if(action==='verify'){
      const token=clean(body.token,20);
      if(!/^\d{6,8}$/.test(token)) return json({error:'INVALID_OR_EXPIRED_CODE'},401);
      const ir=await limited('ip',ip,'application_otp_verify_ip',30,900);if(ir)return json({error:'RATE_LIMITED',retry_after_seconds:ir.retry_after_seconds||60},429,{'Retry-After':String(ir.retry_after_seconds||60)});
      const ar=await limited('application',appNo,'application_otp_verify_application',8,900);if(ar)return json({error:'RATE_LIMITED',retry_after_seconds:ar.retry_after_seconds||60},429,{'Retry-After':String(ar.retry_after_seconds||60)});
      const {data:lead}=await admin.from('aviation_interest_leads').select('id,email').eq('application_number',appNo).maybeSingle();
      if(!lead?.email) return json({error:'INVALID_OR_EXPIRED_CODE'},401);
      const email=clean(lead.email,220).toLowerCase();
      const cr=await limited('contact',email,'application_otp_verify_contact',8,900);if(cr)return json({error:'RATE_LIMITED',retry_after_seconds:cr.retry_after_seconds||60},429,{'Retry-After':String(cr.retry_after_seconds||60)});
      const vr=await fetch(`${url}/auth/v1/verify`,{method:'POST',headers:{'Content-Type':'application/json','apikey':anonKey},body:JSON.stringify({email,token,type:'email'})});
      const vj=await vr.json().catch(()=>({}));
      if(!vr.ok||!vj?.access_token||!vj?.refresh_token||!vj?.user?.id||clean(vj.user.email,220).toLowerCase()!==email) return json({error:'INVALID_OR_EXPIRED_CODE'},401);
      const uid=String(vj.user.id);
      const {data:existing}=await admin.from('am_application_auth_bindings').select('auth_user_id').eq('lead_id',lead.id).is('revoked_at',null).maybeSingle();
      if(existing?.auth_user_id&&existing.auth_user_id!==uid) return json({error:'APPLICATION_ACCESS_DENIED'},403);
      const {error:be}=await admin.from('am_application_auth_bindings').upsert({auth_user_id:uid,lead_id:lead.id,application_number:appNo,verified_at:new Date().toISOString(),revoked_at:null},{onConflict:'lead_id'});if(be)throw be;
      return json({ok:true,access_token:vj.access_token,refresh_token:vj.refresh_token,expires_in:vj.expires_in||3600,token_type:vj.token_type||'bearer'});
    }

    return json({error:'INVALID_ACTION'},400);
  }catch(e){console.error('application-login',e);return json({error:'SERVER_ERROR'},500)}
});