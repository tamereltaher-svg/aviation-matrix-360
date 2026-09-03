import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
const enc=new TextEncoder();
const now=()=>new Date().toISOString();
function bytesToHex(bytes:Uint8Array){return [...bytes].map(b=>b.toString(16).padStart(2,'0')).join('')}
async function sha256Hex(s:string){return bytesToHex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(s))))}
const clean=(v:any,max=200)=>String(v??'').trim().slice(0,max);
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
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
  const body=await req.json(); const action=clean(body.action,60);
  const readActions=new Set(['me','management_overview','list_candidates','candidate_dashboard','employer_dashboard','report_templates']);
  const canRead=ps.has('platform.reporting.read')||ps.has('platform.reporting.manage');
  if(readActions.has(action)&&!canRead)return json({error:'FORBIDDEN'},403);
  if(action==='create_report_snapshot'&&!ps.has('platform.reporting.manage'))return json({error:'FORBIDDEN'},403);
  await admin.from('staff_sessions').update({last_seen_at:now()}).eq('id',session.id);
  if(action==='me')return json({ok:true,staff});
  if(action==='management_overview'){const {data,error}=await admin.from('am_management_overview').select('*').single();if(error)throw error;return json({overview:data})}
  if(action==='list_candidates'){const {data,error}=await admin.from('am_candidate_360_dashboard').select('*').order('last_activity_at',{ascending:false}).limit(300);if(error)throw error;return json({candidates:data||[]})}
  if(action==='candidate_dashboard'){
   const id=clean(body.candidate_id,80);if(!id)return json({error:'CANDIDATE_ID_REQUIRED'},400);
   const [summary,cases,evidence,documents,exams,credentials,readiness,plans,ratings,timeline,decisions]=await Promise.all([
    admin.from('am_candidate_360_dashboard').select('*').eq('candidate_id',id).maybeSingle(),
    admin.from('am_candidate_cases').select('*').eq('candidate_id',id).order('created_at',{ascending:false}),
    admin.from('am_candidate_evidence').select('*').eq('candidate_id',id).order('created_at',{ascending:false}),
    admin.from('am_candidate_documents').select('*').eq('candidate_id',id).order('created_at',{ascending:false}),
    admin.from('am_candidate_exam_transcript').select('*').eq('candidate_id',id).order('finalized_at',{ascending:false}),
    admin.from('am_learning_credentials').select('*').eq('candidate_id',id).order('created_at',{ascending:false}),
    admin.from('am_candidate_readiness_summary').select('*').eq('candidate_id',id).order('completed_at',{ascending:false}),
    admin.from('am_candidate_development_plans').select('*,am_candidate_development_actions(*)').eq('candidate_id',id).order('created_at',{ascending:false}),
    admin.from('am_candidate_competency_ratings').select('*,am_competencies(code,name,category)').eq('candidate_id',id).order('created_at',{ascending:false}),
    admin.from('am_candidate_timeline_events').select('*').eq('candidate_id',id).order('occurred_at',{ascending:false}),
    admin.from('am_decision_records').select('*').eq('candidate_id',id).order('decided_at',{ascending:false})
   ]);
   if(summary.error)throw summary.error;return json({summary:summary.data,cases:cases.data||[],evidence:evidence.data||[],documents:documents.data||[],exams:exams.data||[],credentials:credentials.data||[],readiness:readiness.data||[],development:plans.data||[],competencies:ratings.data||[],timeline:timeline.data||[],decisions:decisions.data||[]})
  }
  if(action==='employer_dashboard'){const {data,error}=await admin.from('am_employer_recruitment_dashboard').select('*').order('organization_name');if(error)throw error;return json({employers:data||[]})}
  if(action==='report_templates'){const {data,error}=await admin.from('am_report_templates').select('*').eq('status','active').order('name');if(error)throw error;return json({templates:data||[]})}
  if(action==='create_report_snapshot'){
   const candidateId=clean(body.candidate_id,80),templateCode=clean(body.template_code,80);if(!candidateId||!templateCode)return json({error:'MISSING_FIELDS'},400);
   const {data:t,error:te}=await admin.from('am_report_templates').select('*').eq('template_code',templateCode).eq('status','active').maybeSingle();if(te)throw te;if(!t)return json({error:'TEMPLATE_NOT_FOUND'},404);
   const dash=await admin.from('am_candidate_360_dashboard').select('*').eq('candidate_id',candidateId).maybeSingle();if(dash.error)throw dash.error;if(!dash.data)return json({error:'CANDIDATE_NOT_FOUND'},404);
   const [ev,docs,exams,cred,ready,plans,ratings,timeline,decisions]=await Promise.all([
    admin.from('am_candidate_evidence').select('*').eq('candidate_id',candidateId),admin.from('am_candidate_documents').select('*').eq('candidate_id',candidateId),admin.from('am_candidate_exam_transcript').select('*').eq('candidate_id',candidateId),admin.from('am_learning_credentials').select('*').eq('candidate_id',candidateId),admin.from('am_candidate_readiness_summary').select('*').eq('candidate_id',candidateId),admin.from('am_candidate_development_plans').select('*,am_candidate_development_actions(*)').eq('candidate_id',candidateId),admin.from('am_candidate_competency_ratings').select('*,am_competencies(code,name,category)').eq('candidate_id',candidateId),admin.from('am_candidate_timeline_events').select('*').eq('candidate_id',candidateId),admin.from('am_decision_records').select('*').eq('candidate_id',candidateId)
   ]);
   const code=`AM-RPT-${Date.now()}`,verification=crypto.randomUUID().replaceAll('-','').slice(0,16).toUpperCase();
   const snap={summary:dash.data,evidence:ev.data||[],documents:docs.data||[],exams:exams.data||[],credentials:cred.data||[],readiness:ready.data||[],development:plans.data||[],competencies:ratings.data||[],timeline:timeline.data||[],decisions:decisions.data||[]};
   const {data:r,error}=await admin.from('am_report_snapshots').insert({report_code:code,template_id:t.id,subject_type:'candidate',subject_id:candidateId,candidate_id:candidateId,report_type:t.report_type,status:'draft',title:`${t.name} — ${dash.data.full_name}`,data_snapshot:snap,verification_code:verification,metadata:{created_by:staff.user_id}}).select().single();if(error)throw error;return json({ok:true,report:r})
  }
  return json({error:'INVALID_ACTION'},400);
 }catch(e){console.error(e);return json({error:'SERVER_ERROR',detail:String((e as any)?.message||e)},500)}
});