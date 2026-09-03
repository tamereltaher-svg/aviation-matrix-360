import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json'}});
const enc=new TextEncoder(); const clean=(v:any,n=500)=>String(v??'').trim().slice(0,n); const now=()=>new Date().toISOString();
async function sha256Hex(s:string){const h=await crypto.subtle.digest('SHA-256',enc.encode(s));return [...new Uint8Array(h)].map(b=>b.toString(16).padStart(2,'0')).join('')}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors}); if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 try{
  const auth=req.headers.get('authorization')||'',token=auth.startsWith('Bearer ')?auth.slice(7).trim():''; if(!token)return json({error:'UNAUTHORIZED'},401);
  const tokenHash=await sha256Hex(token); const {data:session}=await admin.from('staff_sessions').select('id,user_id,expires_at,revoked_at').eq('token_hash',tokenHash).maybeSingle();
  if(!session||session.revoked_at||new Date(session.expires_at).getTime()<=Date.now())return json({error:'SESSION_EXPIRED'},401);
  const {data:staff}=await admin.from('staff_accounts').select('user_id,is_active').eq('user_id',session.user_id).maybeSingle(); if(!staff?.is_active)return json({error:'FORBIDDEN'},403);
  const {data:perms}=await admin.from('staff_permissions').select('permission_code').eq('user_id',staff.user_id).eq('is_allowed',true); const ps=new Set((perms||[]).map((x:any)=>x.permission_code));
  const body=await req.json(); const action=clean(body.action,80);
  const readActions=new Set(['dashboard','list_stages','list_question_bank','list_journeys','get_journey']);
  const manageActions=new Set(['save_stage_version','link_question','unlink_question','publish_stage_version']);
  const canRead=ps.has('assessment.read')||ps.has('assessment.manage');
  if(readActions.has(action)&&!canRead)return json({error:'FORBIDDEN'},403);
  if(manageActions.has(action)&&!ps.has('assessment.manage'))return json({error:'FORBIDDEN'},403);
  await admin.from('staff_sessions').update({last_seen_at:now()}).eq('id',session.id);

  if(action==='dashboard'){
    const [journeys,attempts,completed,inprog]=await Promise.all([
      admin.from('am_candidate_assessment_journeys').select('*',{count:'exact',head:true}),
      admin.from('am_candidate_stage_attempts').select('*',{count:'exact',head:true}),
      admin.from('am_candidate_stage_attempts').select('*',{count:'exact',head:true}).eq('status','completed'),
      admin.from('am_candidate_stage_attempts').select('*',{count:'exact',head:true}).eq('status','in_progress')]);
    const {data:stages}=await admin.from('am_assessment_stage_registry').select('id,code,name,stage_order,is_active').order('stage_order');
    return json({stats:{journeys:journeys.count||0,attempts:attempts.count||0,completed:completed.count||0,in_progress:inprog.count||0},stages:stages||[]});
  }

  if(action==='list_stages'){
    const {data:stages,error}=await admin.from('am_assessment_stage_registry').select('*').order('stage_order'); if(error)throw error;
    const {data:versions}=await admin.from('am_assessment_stage_versions').select('*').order('version_no',{ascending:false});
    const {data:items}=await admin.from('am_assessment_stage_version_items').select('id,stage_version_id,question_id,sequence_no,weight,is_required,question_bank(code,prompt,status,difficulty)');
    return json({stages:stages||[],versions:versions||[],items:items||[]});
  }

  if(action==='save_stage_version'){
    const v=body.version||{},stageId=clean(v.stage_id,80); if(!stageId)return json({error:'STAGE_REQUIRED'},400);
    const payload={version_label:clean(v.version_label,80)||'v1.0',instructions:clean(v.instructions,4000)||null,min_questions:Math.max(0,Number(v.min_questions||0)),time_limit_minutes:v.time_limit_minutes?Math.max(1,Number(v.time_limit_minutes)):null,scoring_rule:v.scoring_rule||{},level_bands:Array.isArray(v.level_bands)?v.level_bands:[],retake_rule:v.retake_rule||{},updated_at:now()};
    let r; if(v.id)r=await admin.from('am_assessment_stage_versions').update(payload).eq('id',v.id).select().single(); else {const {data:last}=await admin.from('am_assessment_stage_versions').select('version_no').eq('stage_id',stageId).order('version_no',{ascending:false}).limit(1);r=await admin.from('am_assessment_stage_versions').insert({...payload,stage_id:stageId,version_no:Number(last?.[0]?.version_no||0)+1,status:'draft'}).select().single()}
    if(r.error)throw r.error; return json({ok:true,version:r.data});
  }

  if(action==='list_question_bank'){
    const q=clean(body.q,150).toLowerCase(); const {data,error}=await admin.from('question_bank').select('id,assessment_version_id,code,prompt,question_type,difficulty,status,time_limit_seconds').order('updated_at',{ascending:false}).limit(500); if(error)throw error;
    const rows=(data||[]).filter((x:any)=>!q||[x.code,x.prompt,x.question_type,x.status].join(' ').toLowerCase().includes(q)); return json({questions:rows});
  }

  if(action==='link_question'){
    const stageVersionId=clean(body.stage_version_id,80),questionId=clean(body.question_id,80); if(!stageVersionId||!questionId)return json({error:'MISSING_FIELDS'},400);
    const {data,error}=await admin.from('am_assessment_stage_version_items').upsert({stage_version_id:stageVersionId,question_id:questionId,sequence_no:Number(body.sequence_no||999),weight:Number(body.weight||1),is_required:body.is_required!==false},{onConflict:'stage_version_id,question_id'}).select().single(); if(error)throw error; return json({ok:true,item:data});
  }
  if(action==='unlink_question'){const {error}=await admin.from('am_assessment_stage_version_items').delete().eq('id',clean(body.id,80));if(error)throw error;return json({ok:true})}

  if(action==='publish_stage_version'){
    const id=clean(body.id,80); const {data:v,error}=await admin.from('am_assessment_stage_versions').select('*').eq('id',id).single(); if(error)throw error;
    const {count}=await admin.from('am_assessment_stage_version_items').select('*',{count:'exact',head:true}).eq('stage_version_id',id); if((count||0)<Number(v.min_questions||0)||Number(count||0)===0)return json({error:'QUESTION_SET_NOT_READY',detail:'Add approved questions before publishing.'},400);
    await admin.from('am_assessment_stage_versions').update({status:'retired',effective_to:now(),updated_at:now()}).eq('stage_id',v.stage_id).eq('status','published').neq('id',id);
    const {data,error:e2}=await admin.from('am_assessment_stage_versions').update({status:'published',effective_from:now(),effective_to:null,updated_at:now()}).eq('id',id).select().single(); if(e2)throw e2; return json({ok:true,version:data});
  }

  if(action==='list_journeys'){
    const {data,error}=await admin.from('am_candidate_assessment_journey_summary').select('*').order('last_activity_at',{ascending:false,nullsFirst:false}).limit(400); if(error)throw error; return json({journeys:data||[]});
  }
  if(action==='get_journey'){
    const candidateId=clean(body.candidate_id,80); const [j,a,e]=await Promise.all([
      admin.from('am_candidate_assessment_journey_summary').select('*').eq('candidate_id',candidateId).maybeSingle(),
      admin.from('am_candidate_stage_attempts').select('*').eq('candidate_id',candidateId).order('started_at',{ascending:false}),
      admin.from('am_candidate_evidence').select('*').eq('candidate_id',candidateId).eq('evidence_type','assessment_stage_result').order('created_at',{ascending:false})]);
    return json({journey:j.data||null,attempts:a.data||[],evidence:e.data||[]});
  }
  return json({error:'INVALID_ACTION'},400);
 }catch(e){console.error(e);return json({error:'SERVER_ERROR',detail:String((e as any)?.message||e)},500)}
});