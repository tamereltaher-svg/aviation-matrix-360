import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json'}});
const enc=new TextEncoder();
const clean=(v:any,n=500)=>String(v??'').trim().slice(0,n);
const now=()=>new Date().toISOString();
async function sha256Hex(s:string){const h=await crypto.subtle.digest('SHA-256',enc.encode(s));return [...new Uint8Array(h)].map(b=>b.toString(16).padStart(2,'0')).join('')}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 try{
  const auth=req.headers.get('authorization')||'',token=auth.startsWith('Bearer ')?auth.slice(7).trim():'';
  if(!token)return json({error:'UNAUTHORIZED'},401);
  const tokenHash=await sha256Hex(token);
  const {data:session}=await admin.from('staff_sessions').select('id,user_id,expires_at,revoked_at').eq('token_hash',tokenHash).maybeSingle();
  if(!session||session.revoked_at||new Date(session.expires_at).getTime()<=Date.now())return json({error:'SESSION_EXPIRED'},401);
  const {data:staff}=await admin.from('staff_accounts').select('user_id,email,full_name,role_code,is_active').eq('user_id',session.user_id).maybeSingle();
  if(!staff?.is_active)return json({error:'FORBIDDEN'},403);
  const {data:perms}=await admin.from('staff_permissions').select('permission_code').eq('user_id',staff.user_id).eq('is_allowed',true);
  const ps=new Set((perms||[]).map((x:any)=>x.permission_code));
  const body=await req.json(); const action=clean(body.action,80);
  const readActions=new Set(['dashboard','list_candidates','get_candidate']);
  const manageActions=new Set(['create_candidate','append_event','update_current_state','capture_snapshot']);
  const canRead=ps.has('candidate_lifetime.read')||ps.has('candidate_lifetime.manage');
  if(readActions.has(action)&&!canRead)return json({error:'FORBIDDEN'},403);
  if(manageActions.has(action)&&!ps.has('candidate_lifetime.manage'))return json({error:'FORBIDDEN'},403);
  await admin.from('staff_sessions').update({last_seen_at:now()}).eq('id',session.id);

  if(action==='dashboard'){
    const [candidates,persons,events,evidence]=await Promise.all([
      admin.from('am_candidate_records').select('*',{count:'exact',head:true}),
      admin.from('am_persons').select('*',{count:'exact',head:true}),
      admin.from('am_candidate_lifetime_events').select('*',{count:'exact',head:true}),
      admin.from('am_candidate_evidence').select('*',{count:'exact',head:true})
    ]);
    const {data:recent}=await admin.from('am_candidate_lifetime_summary').select('*').order('updated_at',{ascending:false}).limit(12);
    return json({stats:{candidates:candidates.count||0,persons:persons.count||0,lifetime_events:events.count||0,evidence:evidence.count||0},recent:recent||[]});
  }

  if(action==='list_candidates'){
    const q=clean(body.q,200).toLowerCase();
    let query=admin.from('am_candidate_lifetime_summary').select('*').order('updated_at',{ascending:false}).limit(300);
    const {data,error}=await query;if(error)throw error;
    const rows=(data||[]).filter((x:any)=>!q||[x.full_name,x.candidate_number,x.email,x.mobile].join(' ').toLowerCase().includes(q));
    return json({candidates:rows});
  }

  if(action==='get_candidate'){
    const id=clean(body.candidate_id,80); if(!id)return json({error:'CANDIDATE_REQUIRED'},400);
    const [summary,events,evidence,state,snaps]=await Promise.all([
      admin.from('am_candidate_lifetime_summary').select('*').eq('candidate_id',id).maybeSingle(),
      admin.from('am_candidate_lifetime_events').select('*').eq('candidate_id',id).order('occurred_at',{ascending:false}).limit(500),
      admin.from('am_candidate_evidence').select('*').eq('candidate_id',id).order('created_at',{ascending:false}).limit(500),
      admin.from('am_candidate_current_state').select('*').eq('candidate_id',id).maybeSingle(),
      admin.from('am_candidate_lifetime_snapshots').select('id,snapshot_type,snapshot_version,captured_at,integrity_hash').eq('candidate_id',id).order('captured_at',{ascending:false}).limit(100)
    ]);
    if(summary.error||!summary.data)return json({error:'NOT_FOUND'},404);
    return json({candidate:summary.data,current_state:state.data||null,events:events.data||[],evidence:evidence.data||[],snapshots:snaps.data||[]});
  }

  if(action==='create_candidate'){
    const p=body.person||{}; const fullName=clean(p.full_name,220); if(!fullName)return json({error:'FULL_NAME_REQUIRED'},400);
    const personIns=await admin.from('am_persons').insert({full_name:fullName,date_of_birth:p.date_of_birth||null,email:clean(p.email,220)||null,mobile:clean(p.mobile,80)||null,current_city:clean(p.current_city,120)||null,preferred_language:clean(p.preferred_language,40)||'en'}).select().single();
    if(personIns.error)throw personIns.error;
    const candIns=await admin.from('am_candidate_records').insert({person_id:personIns.data.id,lifecycle_stage:'applicant',metadata:{created_via:'candidate-lifetime-api'}}).select().single();
    if(candIns.error){await admin.from('am_persons').delete().eq('id',personIns.data.id);throw candIns.error}
    await admin.from('am_candidate_current_state').insert({candidate_id:candIns.data.id,person_id:personIns.data.id,lifecycle_stage:'applicant'});
    await admin.rpc('am_append_candidate_lifetime_event',{p_candidate_id:candIns.data.id,p_event_code:'CANDIDATE_CREATED',p_event_domain:'identity',p_title:'Candidate created',p_detail:'Candidate entered the Aviation Matrix lifetime record.',p_payload:{candidate_number:candIns.data.candidate_number},p_source_system:'candidate-lifetime-api',p_source_table:'am_candidate_records',p_source_id:candIns.data.id,p_recorded_by:staff.user_id});
    return json({ok:true,candidate_id:candIns.data.id,candidate_number:candIns.data.candidate_number});
  }

  if(action==='append_event'){
    const id=clean(body.candidate_id,80),code=clean(body.event_code,100),title=clean(body.title,240); if(!id||!code||!title)return json({error:'MISSING_EVENT_FIELDS'},400);
    const {data,error}=await admin.rpc('am_append_candidate_lifetime_event',{p_candidate_id:id,p_event_code:code,p_event_domain:clean(body.event_domain,80)||'lifetime',p_title:title,p_detail:clean(body.detail,2000)||null,p_payload:body.payload||{},p_source_system:clean(body.source_system,100)||'candidate-lifetime-api',p_source_table:clean(body.source_table,100)||null,p_source_id:body.source_id||null,p_evidence_id:body.evidence_id||null,p_occurred_at:body.occurred_at||now(),p_recorded_by:staff.user_id});
    if(error)throw error;return json({ok:true,event_id:data});
  }

  if(action==='update_current_state'){
    const id=clean(body.candidate_id,80); if(!id)return json({error:'CANDIDATE_REQUIRED'},400);
    const allowed=['lifecycle_stage','qualification_status','readiness_status','english_level','computer_level','current_career_code','current_career_fit','active_gap_count','active_course_count','valid_credential_count','latest_assessment_at','latest_training_at','latest_exam_at','latest_credential_at','state_json'];
    const patch:any={updated_at:now(),recalculated_at:now()}; for(const k of allowed)if(Object.prototype.hasOwnProperty.call(body.state||{},k))patch[k]=body.state[k];
    const {data,error}=await admin.from('am_candidate_current_state').update(patch).eq('candidate_id',id).select().single(); if(error)throw error;
    await admin.rpc('am_append_candidate_lifetime_event',{p_candidate_id:id,p_event_code:'CURRENT_STATE_RECALCULATED',p_event_domain:'qualification',p_title:'Current qualification state recalculated',p_detail:'Current state changed; historical evidence remains unchanged.',p_payload:patch,p_source_system:'candidate-lifetime-api',p_source_table:'am_candidate_current_state',p_source_id:id,p_recorded_by:staff.user_id});
    return json({ok:true,current_state:data});
  }

  if(action==='capture_snapshot'){
    const id=clean(body.candidate_id,80); const {data,error}=await admin.rpc('am_capture_candidate_lifetime_snapshot',{p_candidate_id:id,p_snapshot_type:clean(body.snapshot_type,80)||'current_state',p_captured_by:staff.user_id}); if(error)throw error;return json({ok:true,snapshot_id:data});
  }

  return json({error:'INVALID_ACTION'},400);
 }catch(e){console.error(e);return json({error:'SERVER_ERROR',detail:String((e as any)?.message||e)},500)}
});