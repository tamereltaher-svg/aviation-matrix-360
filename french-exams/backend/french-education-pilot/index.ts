import postgres from "npm:postgres@3.4.5";
const URL=Deno.env.get("SUPABASE_URL")||"";
const KEY=Deno.env.get("SUPABASE_ANON_KEY")||"";
const DB=Deno.env.get("SUPABASE_DB_URL")||"";
const sql=postgres(DB,{max:1,prepare:false,idle_timeout:10,connect_timeout:8});
const ORIGIN="https://tamereltaher-svg.github.io";
const CORS={"Access-Control-Allow-Origin":ORIGIN,"Access-Control-Allow-Methods":"POST, OPTIONS","Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Cache-Control":"no-store","Vary":"Origin"};
const TOPICS=["colors","numbers","alphabet","shapes","animals","fruits"];
const CONSENT="fr-guardian-pilot-2026-11-v1";
class Failure extends Error{constructor(status,message){super(message);this.status=status;}}
const error=(code,message)=>{throw new Failure(code,message);};
const run=(q,args=[],db=sql)=>db.unsafe(q,args);
const response=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{...CORS,"Content-Type":"application/json; charset=utf-8"}});
const normalized=s=>String(s??"").trim().normalize("NFC").toLocaleLowerCase("fr-FR").replaceAll("œ","oe").replace(/\s+/g," ");
const shuffled=a=>{let x=[...a];for(let i=x.length-1;i>0;i--){const j=crypto.getRandomValues(new Uint32Array(1))[0]%(i+1);[x[i],x[j]]=[x[j],x[i]];}return x;};
const field=(b,k,max=120)=>{const s=b?.[k];if(typeof s!=="string"||!s.trim()||s.length>max)error(400,"Champ invalide: "+k);return s.trim();};
const validId=id=>typeof id==="string"&&/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(id);
async function userFrom(req){
 const auth=req.headers.get("authorization")||"";
 if(!/^Bearer\s+\S+$/i.test(auth))error(401,"Connexion requise");
 const token=auth.replace(/^Bearer\s+/i,"");
 const r=await fetch(URL+"/auth/v1/user",{headers:{authorization:"Bearer "+token,apikey:KEY}});
 if(!r.ok)error(401,"Session expirée");
 const u=await r.json();
 if(!u?.id||!u.email_confirmed_at)error(401,"Confirmez d'abord votre adresse email");
 return u;
}

const ACCOUNT_TYPES=["guardian","adult_student","teacher"];
async function isAdmin(uid){
 return (await run("select 1 from fr_edu.user_roles where user_id=$1 and role_name='admin' limit 1",[uid])).length>0;
}
async function accountRequest(uid){
 const a=await run("select account_type,approval_status,requested_at,decided_at,admin_note from fr_edu.account_requests where user_id=$1",[uid]);
 return a[0]||null;
}
async function sessionInfo(u){
 const uid=u.id;
 if(await isAdmin(uid))return {role:"admin",approval_status:"active",email:u.email,consent_version:CONSENT};
 const req=await accountRequest(uid);
 if(!req)return {role:"unregistered",approval_status:"unregistered",email:u.email,consent_version:CONSENT};
 if(req.approval_status!=="active")return {role:"pending",...req,email:u.email,consent_version:CONSENT};
 return {role:req.account_type==="teacher"?"teacher":"guardian",account_type:req.account_type,approval_status:"active",email:u.email,consent_version:CONSENT};
}
async function registerAccount(uid,b){
 if(await isAdmin(uid))error(409,"Compte administrateur existant");
 const type=field(b,"account_type",30);
 if(!ACCOUNT_TYPES.includes(type)||b.adult_confirmed!==true||b.accept_notice!==true)
   error(400,"Inscription adulte et acceptation des informations requises");
 const prior=await accountRequest(uid);
 if(prior)return {...prior,existing:true};
 const x=await run("insert into fr_edu.account_requests(user_id,account_type) values($1,$2) on conflict(user_id) do nothing returning account_type,approval_status,requested_at",[uid,type]);
 return x[0]||await accountRequest(uid);
}
async function requireAccount(uid,kind="guardian"){
 if(await isAdmin(uid))return;
 const rec=await accountRequest(uid);
 if(!rec||rec.approval_status!=="active")error(403,"Compte en attente de validation administrative");
 if(kind==="teacher"&&rec.account_type!=="teacher")error(403,"Compte enseignant requis");
 if(kind==="guardian"&&rec.account_type==="teacher")error(403,"Compte responsable requis");
}
async function adminQueue(uid){
 if(!await isAdmin(uid))error(403,"Administrateur non autorisé");
 const accounts=await run("select a.user_id,a.account_type,a.approval_status,a.requested_at,a.decided_at,u.email from fr_edu.account_requests a join auth.users u on u.id=a.user_id order by case when a.approval_status='pending' then 0 else 1 end,a.requested_at desc limit 250");
 const learners=await run("select l.id,l.display_name,l.grade_code,l.approval_status,l.created_at,l.guardian_user_id,u.email as guardian_email,a.approval_status as guardian_status from fr_edu.learners l join auth.users u on u.id=l.guardian_user_id left join fr_edu.account_requests a on a.user_id=l.guardian_user_id where l.consent_revoked_at is null order by case when l.approval_status='pending' then 0 else 1 end,l.created_at desc limit 250");
 return {accounts,learners};
}
async function adminDecide(uid,b){
 if(!await isAdmin(uid))error(403,"Administrateur non autorisé");
 const target=field(b,"target",12),action=field(b,"decision",15);
 const note=typeof b.note==="string"?b.note.trim():"";
 if(note.length>500||!["account","learner"].includes(target)||!["approve","reject","suspend","reactivate"].includes(action))error(400,"Décision invalide");
 const id=field(b,"target_id",36);
 if(!validId(id))error(400,"Identifiant invalide");
 const transitions={
  approve:{from:["pending","rejected"],to:"active"},
  reject:{from:["pending"],to:"rejected"},
  suspend:{from:["active"],to:"suspended"},
  reactivate:{from:["suspended"],to:"active"}
 };
 const step=transitions[action];
 return await sql.begin(async tx=>{
  if(target==="account"){
   if(id===uid)error(403,"Auto-approbation interdite");
   const items=await run("select user_id,account_type,approval_status from fr_edu.account_requests where user_id=$1 for update",[id],tx);
   if(!items.length)error(404,"Demande inconnue");
   const current=items[0];
   if(!step.from.includes(current.approval_status))error(409,"Transition non autorisée: "+current.approval_status);
   const verified=await run("select email_confirmed_at from auth.users where id=$1",[id],tx);
   if(step.to==="active"&&!verified[0]?.email_confirmed_at)error(409,"Email non confirmé");
   await run("update fr_edu.account_requests set approval_status=$1,decided_at=now(),decided_by=$2,admin_note=$3 where user_id=$4",[step.to,uid,note||null,id],tx);
   if(current.account_type==="teacher"&&step.to==="active"){
    await run("insert into fr_edu.user_roles(user_id,role_name,assigned_by) values($1,'teacher',$2) on conflict(user_id,role_name) do nothing",[id,uid],tx);
   }
   await run("insert into fr_edu.registration_decisions(target_type,account_user_id,action,decided_by,note) values('account',$1,$2,$3,$4)",[id,action,uid,note||null],tx);
  }else{
   const rows=await run("select id,guardian_user_id,approval_status,consent_revoked_at from fr_edu.learners where id=$1 for update",[id],tx);
   if(!rows.length)error(404,"Profil élève inconnu");
   if(!step.from.includes(rows[0].approval_status))error(409,"Transition non autorisée: "+rows[0].approval_status);
   if(rows[0].consent_revoked_at)error(409,"Consentement retiré");
   if(step.to==="active"){
    const parents=await run("select approval_status from fr_edu.account_requests where user_id=$1",[rows[0].guardian_user_id],tx);
    if(parents[0]?.approval_status!=="active")error(409,"Compte responsable non actif");
   }
   await run("update fr_edu.learners set approval_status=$1,decided_at=now(),decided_by=$2,admin_note=$3 where id=$4",[step.to,uid,note||null,id],tx);
   await run("insert into fr_edu.registration_decisions(target_type,learner_id,action,decided_by,note) values('learner',$1,$2,$3,$4)",[id,action,uid,note||null],tx);
  }
  return {target,target_id:id,approval_status:step.to};
 });
}
async function teacher(uid){await requireAccount(uid,"teacher");return (await run("select 1 from fr_edu.user_roles where user_id=$1 and role_name='teacher' limit 1",[uid])).length>0;}
async function learner(uid,id){
 if(!validId(id))error(400,"Identifiant d'élève invalide");
 const x=await run("select id,display_name,grade_code,approval_status,consent_revoked_at from fr_edu.learners where id=$1 and guardian_user_id=$2",[id,uid]);
 if(!x.length||x[0].consent_revoked_at)error(403,"Accès élève refusé ou consentement retiré");
 return x[0];
}
async function accountReport(uid,id){
 await requireAccount(uid);await learner(uid,id);
 return await run("select assessment_code,attempt_number,auto_score,maximum_score,state,submitted_at from fr_edu.attempts where learner_id=$1 and student_user_id=$2 and state in ('scored','review_required') order by submitted_at desc limit 150",[id,uid]);
}
async function listLearners(uid){
 await requireAccount(uid);
 return await run("select id,display_name,grade_code,approval_status,admin_note,created_at from fr_edu.learners where guardian_user_id=$1 and consent_revoked_at is null order by created_at desc limit 100",[uid]);
}
async function createLearner(uid,b){
 await requireAccount(uid);
 if(b.consent!==true)error(400,"Accord du responsable légal requis");
 const name=field(b,"learner_alias",60);
 const grade=b.grade_code?field(b,"grade_code",12):null;
 if(grade&&!(await run("select 1 from fr_edu.grades where code=$1",[grade])).length)error(400,"Classe inconnue");
 const x=await run("insert into fr_edu.learners(guardian_user_id,display_name,grade_code,consent_version) values($1,$2,$3,$4) returning id,display_name,grade_code",[uid,name,grade,CONSENT]);
 return x[0];
}
async function teacherCode(uid){
 if(!await teacher(uid))error(403,"Compte enseignant non autorisé");
 let a=await run("select share_code from fr_edu.teacher_codes where teacher_user_id=$1",[uid]);
 if(!a.length){
  const code="FR"+crypto.randomUUID().replaceAll("-","").slice(0,12).toUpperCase();
  a=await run("insert into fr_edu.teacher_codes(teacher_user_id,share_code) values($1,$2) on conflict(teacher_user_id) do update set teacher_user_id=excluded.teacher_user_id returning share_code",[uid,code]);
 }
 return {code:a[0].share_code};
}
async function shareTeacher(uid,b){
 await requireAccount(uid);
 const linked=await learner(uid,b.learner_id);
 if(linked.approval_status!=="active")error(403,"Profil élève en attente de validation");
 const code=field(b,"teacher_code",40).toUpperCase();
 const rows=await run("select c.teacher_user_id from fr_edu.teacher_codes c join fr_edu.user_roles r on r.user_id=c.teacher_user_id and r.role_name='teacher' join fr_edu.account_requests a on a.user_id=c.teacher_user_id and a.approval_status='active' where c.share_code=$1 limit 1",[code]);
 if(!rows.length)error(404,"Code enseignant inconnu");
 await run("insert into fr_edu.teacher_learner_access(teacher_user_id,learner_id,granted_by_guardian_id) values($1,$2,$3) on conflict(teacher_user_id,learner_id) do update set revoked_at=null,granted_at=now(),granted_by_guardian_id=excluded.granted_by_guardian_id",[rows[0].teacher_user_id,b.learner_id,uid]);
 return {shared:true};
}
async function unshareTeacher(uid,b){
 await learner(uid,b.learner_id);
 const code=field(b,"teacher_code",40).toUpperCase();
 const rows=await run("select teacher_user_id from fr_edu.teacher_codes where share_code=$1",[code]);
 if(!rows.length)error(404,"Code enseignant inconnu");
 await run("update fr_edu.teacher_learner_access set revoked_at=now() where learner_id=$1 and teacher_user_id=$2 and granted_by_guardian_id=$3",[b.learner_id,rows[0].teacher_user_id,uid]);
 return {revoked:true};
}
async function deleteLearner(uid,b){
 const id=b.learner_id;
 if(!validId(id)||b.confirm_delete!==true)error(400,"Confirmation de suppression requise");
 const rows=await run("select id from fr_edu.learners where id=$1 and guardian_user_id=$2",[id,uid]);
 if(!rows.length)error(403,"Ce profil ne vous appartient pas");
 await sql.begin(async tx=>{
   await run("delete from fr_edu.attempts where learner_id=$1 and student_user_id=$2",[id,uid],tx);
   await run("delete from fr_edu.teacher_learner_access where learner_id=$1",[id],tx);
   await run("delete from fr_edu.learners where id=$1 and guardian_user_id=$2",[id,uid],tx);
 });
 return {deleted:true};
}
async function teacherReport(uid){
 if(!await teacher(uid))error(403,"Compte enseignant non autorisé");
 const learners=await run("select l.id,l.display_name,l.grade_code from fr_edu.teacher_learner_access x join fr_edu.learners l on l.id=x.learner_id join fr_edu.account_requests ap on ap.user_id=l.guardian_user_id and ap.approval_status='active' where x.teacher_user_id=$1 and x.revoked_at is null and l.consent_revoked_at is null and l.approval_status='active' order by l.created_at desc limit 200",[uid]);
 const attempts=await run("select a.learner_id,a.assessment_code,a.attempt_number,a.auto_score,a.maximum_score,a.submitted_at,a.state from fr_edu.teacher_learner_access x join fr_edu.learners l on l.id=x.learner_id join fr_edu.attempts a on a.learner_id=l.id join fr_edu.account_requests ap on ap.user_id=l.guardian_user_id and ap.approval_status='active' where x.teacher_user_id=$1 and x.revoked_at is null and l.consent_revoked_at is null and l.approval_status='active' and a.state in ('scored','review_required') order by a.submitted_at desc limit 500",[uid]);
 return {learners,attempts};
}
async function checkAttempt(uid,id){
 await requireAccount(uid);
 if(!validId(id))error(400,"Tentative invalide");
 const x=await run("select a.id,a.learner_id,a.assessment_code,a.attempt_number,a.state,a.auto_score,a.maximum_score from fr_edu.attempts a join fr_edu.learners l on l.id=a.learner_id where a.id=$1 and a.student_user_id=$2 and l.guardian_user_id=$2 and l.consent_revoked_at is null and l.approval_status='active'",[id,uid]);
 if(!x.length)error(403,"Accès refusé");
 return x[0];
}
async function questions(id){
 const rows=await run("select r.display_order,r.answer_mode,r.answer_value as saved_answer,l.topic_code,l.visual_type,l.visual_value,l.missing_index,l.canonical_fr from fr_edu.responses r join fr_edu.lexemes l on l.id=r.lexeme_id where r.attempt_id=$1 order by r.display_order",[id]);
 const out=[];
 for(const row of rows){
  const q={order:row.display_order,mode:row.answer_mode,topic:row.topic_code,visual_type:row.visual_type,visual_value:row.answer_mode==="letter"&&row.topic_code==="alphabet"?null:row.visual_value,saved_answer:row.saved_answer};
  if(row.answer_mode==="choose"){
   const previous=row.saved_answer&&row.saved_answer!==row.canonical_fr?row.saved_answer:null;
   const opts=await run("select canonical_fr from fr_edu.lexemes where topic_code=$1 and canonical_fr<>$2 and ($3::text is null or canonical_fr<>$3) order by random() limit $4",[row.topic_code,row.canonical_fr,previous,previous?2:3]);
   q.options=shuffled([row.canonical_fr,...(previous?[previous]:[]),...opts.map(x=>x.canonical_fr)]);
  }
  if(row.answer_mode==="letter"){
   const term=row.canonical_fr;
   if(row.topic_code==="alphabet"){
    const i=term.toUpperCase().charCodeAt(0)-65,s="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    q.partial=i===0?"_ B C":i===25?"X Y _":s[i-1]+" _ "+s[i+1];
   }else{
    const i=row.missing_index??1;
    q.partial=term.slice(0,i)+" _ "+term.slice(i+1);
   }
  }
  out.push(q);
 }
 return out;
}

async function adminTimers(uid){
 if(!await isAdmin(uid))error(403,"Administrateur non autorisé");
 return await run("select code,title_fr,question_count,timer_enabled,timer_duration_seconds from fr_edu.assessments where pilot_enabled=true order by title_fr");
}
async function adminSetTimer(uid,b){
 if(!await isAdmin(uid))error(403,"Administrateur non autorisé");
 const code=field(b,"assessment_code",100);
 const enabled=b.timer_enabled;
 const duration=b.duration_seconds;
 if(typeof enabled!=="boolean"||!Number.isInteger(duration)||duration<60||duration>7200)
  error(400,"Durée invalide : 1 à 120 minutes");
 return await sql.begin(async tx=>{
  const a=await run("update fr_edu.assessments set timer_enabled=$1,timer_duration_seconds=$2 where code=$3 and pilot_enabled=true returning code,timer_enabled,timer_duration_seconds",[enabled,duration,code],tx);
  if(!a.length)error(404,"Examen pilote non disponible");
  await run("insert into fr_edu.audit_events(actor_user_id,event_code,object_kind,object_id,context) values($1,'timer_updated','assessment',$2,$3::jsonb)",[uid,code,JSON.stringify({timer_enabled:enabled,duration_seconds:duration})],tx);
  return a[0];
 });
}
function attemptTime(a){
 return {attempt_id:a.id,attempt_number:a.attempt_number,state:a.state,
  time_limit_seconds:a.time_limit_seconds??null,deadline_at:a.deadline_at??null,
  server_now:a.server_now,submission_reason:a.submission_reason??null};
}
async function finalizeTimedOut(id){
 const rows=await run("select * from fr_edu.finalize_attempt($1::uuid,'timeout')",[id]);
 return rows[0];
}
async function start(uid,b){
 await requireAccount(uid);
 const own=await learner(uid,b.learner_id);
 if(own.approval_status!=="active")error(403,"Profil élève en attente de validation");
 const code=field(b,"assessment_code",100);
 const assessments=await run("select code,question_count,max_attempts,timer_enabled,timer_duration_seconds from fr_edu.assessments where code=$1 and pilot_enabled=true",[code]);
 if(!assessments.length)error(404,"Examen indisponible");
 const def=assessments[0];
 const previous=await run("select id,attempt_number,state,deadline_at,time_limit_seconds,clock_timestamp() as server_now,(deadline_at is not null and deadline_at<=clock_timestamp()) as expired from fr_edu.attempts where student_user_id=$1 and learner_id=$2 and assessment_code=$3 order by attempt_number desc",[uid,own.id,code]);
 const current=previous.find(x=>x.state==="in_progress");
 if(current){
  if(current.expired){
   const r=await finalizeTimedOut(current.id);
   return {...attemptTime(current),state:r.state,score:r.auto_score,maximum:r.maximum_score,submission_reason:"timeout",expired:true};
  }
  return {...attemptTime(current),questions:await questions(current.id),resumed:true};
 }
 if(previous.length>=Number(def.max_attempts))error(409,"Trois tentatives déjà utilisées");
 const pool=await run("select topic_code,mode,question_count from fr_edu.assessment_pool where assessment_code=$1 order by topic_code,mode",[code]);
 if(!pool.length)error(422,"Examen sans banque de questions");
 const no=previous.length+1;
 let id;
 try{
 id=await sql.begin(async tx=>{
  const created=await run(
   "insert into fr_edu.attempts(student_user_id,learner_id,assessment_code,attempt_number,time_limit_seconds,deadline_at) values($1,$2,$3,$4,case when $5::boolean then $6::integer else null end,case when $5::boolean then clock_timestamp()+($6::integer * interval '1 second') else null end) returning id",
   [uid,own.id,code,no,Boolean(def.timer_enabled),def.timer_duration_seconds??null],tx);
  const attemptId=created[0].id,selected=[];
  for(const block of pool){
   const lex=await run("select id from fr_edu.lexemes where topic_code=$1 and content_status<>'retired' order by random() limit $2",[block.topic_code,block.question_count],tx);
   if(lex.length!==Number(block.question_count))error(422,"Banque incomplète");
   for(const item of lex)selected.push({id:item.id,mode:block.mode});
  }
  if(selected.length!==Number(def.question_count))error(422,"Nombre de questions incohérent");
  let order=1;
  for(const q of shuffled(selected))await run("insert into fr_edu.responses(attempt_id,display_order,lexeme_id,answer_mode) values($1,$2,$3,$4)",[attemptId,order++,q.id,q.mode],tx);
  return attemptId;
 });
 }catch(e){
  if(e?.code==="23505")error(409,"Une autre tentative a été ouverte ; actualisez pour la reprendre.");
  throw e;
 }
 const info=await run("select id,attempt_number,state,time_limit_seconds,deadline_at,submission_reason,clock_timestamp() as server_now from fr_edu.attempts where id=$1",[id]);
 return {...attemptTime(info[0]),questions:await questions(id),resumed:false};
}
async function getAttempt(uid,b){
 const a=await checkAttempt(uid,b.attempt_id);
 const rows=await run("select id,attempt_number,state,deadline_at,time_limit_seconds,submission_reason,auto_score,maximum_score,clock_timestamp() as server_now,(deadline_at is not null and deadline_at<=clock_timestamp()) as expired from fr_edu.attempts where id=$1",[a.id]);
 const v=rows[0];
 if(v.state!=="in_progress")return {...attemptTime(v),score:v.auto_score,maximum:v.maximum_score};
 if(v.expired){
  const result=await finalizeTimedOut(v.id);
  return {...attemptTime(v),state:result.state,score:result.auto_score,maximum:result.maximum_score,submission_reason:"timeout",expired:true};
 }
 return {...attemptTime(v),questions:await questions(v.id)};
}
async function saveAnswer(uid,b){
 const id=field(b,"attempt_id",36);
 if(!Number.isInteger(b.order)||b.order<1||b.order>200||typeof b.answer!=="string"||b.answer.length>100||!b.answer.trim())error(400,"Réponse invalide");
 await checkAttempt(uid,id);
 return await sql.begin(async tx=>{
  const a=await run("select id,state,deadline_at,clock_timestamp() as server_now,(deadline_at is not null and deadline_at<=clock_timestamp()) as expired from fr_edu.attempts where id=$1 for update",[id],tx);
  if(!a.length)error(404,"Tentative introuvable");
  if(a[0].state!=="in_progress")return {saved:false,finished:true,state:a[0].state};
  if(a[0].expired){
   const finished=await run("select * from fr_edu.finalize_attempt($1::uuid,'timeout')",[id],tx);
   return {saved:false,finished:true,state:finished[0].state,score:finished[0].auto_score,maximum:finished[0].maximum_score,submission_reason:"timeout"};
  }
  const changed=await run("update fr_edu.responses set answer_value=$1,score=null,checked_at=null where attempt_id=$2 and display_order=$3 returning display_order",[b.answer.trim(),id,b.order],tx);
  if(!changed.length)error(404,"Question introuvable");
  return {saved:true,finished:false,server_now:a[0].server_now};
 });
}
async function submit(uid,b){
 const id=field(b,"attempt_id",36),provided=b.answers;
 if(provided!==undefined&&(!Array.isArray(provided)||provided.length>200))error(400,"Réponses invalides");
 await checkAttempt(uid,id);
 return await sql.begin(async tx=>{
  const a=await run("select id,state,student_user_id,deadline_at,(deadline_at is not null and deadline_at<=clock_timestamp()) as expired from fr_edu.attempts where id=$1 for update",[id],tx);
  if(!a.length||a[0].student_user_id!==uid)error(403,"Accès refusé");
  if(a[0].state!=="in_progress"){
   const x=await run("select state,auto_score,maximum_score,submission_reason from fr_edu.attempts where id=$1",[id],tx);
   return {score:x[0].auto_score,maximum:x[0].maximum_score,state:x[0].state,submission_reason:x[0].submission_reason,already_submitted:true};
  }
  if(a[0].expired){
   const x=await run("select * from fr_edu.finalize_attempt($1::uuid,'timeout')",[id],tx);
   return {score:x[0].auto_score,maximum:x[0].maximum_score,state:x[0].state,submission_reason:"timeout",already_submitted:false};
  }
  const items=await run("select display_order,answer_value from fr_edu.responses where attempt_id=$1 order by display_order for update",[id],tx);
  if(!items.length)error(422,"Aucune question");
  if(Array.isArray(provided)){
   if(provided.length!==items.length)error(400,"Toutes les réponses sont requises");
   const entries=new Map();
   for(const value of provided){
    if(!value||!Number.isInteger(value.order)||value.order<1||typeof value.answer!=="string"||value.answer.length>100||!value.answer.trim()||entries.has(value.order))error(400,"Réponse invalide");
    entries.set(value.order,value.answer.trim());
   }
   for(const item of items){
    const answer=entries.get(item.display_order);
    if(typeof answer!=="string")error(400,"Réponses manquantes");
    await run("update fr_edu.responses set answer_value=$1 where attempt_id=$2 and display_order=$3",[answer,id,item.display_order],tx);
   }
  }else if(items.some(x=>!x.answer_value?.trim()))error(400,"Toutes les réponses doivent être enregistrées");
  const x=await run("select * from fr_edu.finalize_attempt($1::uuid,'manual')",[id],tx);
  return {score:x[0].auto_score,maximum:x[0].maximum_score,state:x[0].state,submission_reason:x[0].submission_reason,already_submitted:false};
 });
}
Deno.serve(async req=>{
 try{
  const origin=req.headers.get("origin");
  if(origin&&origin!==ORIGIN)return response({ok:false,error:"Origin not allowed"},403);
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers:CORS});
  if(req.method!=="POST")return response({ok:false,error:"Method not allowed"},405);
  if(Number(req.headers.get("content-length")||0)>16000)error(413,"Payload too large");
  const raw=await req.text();if(raw.length>16000)error(413,"Payload too large");
  let b;try{b=JSON.parse(raw)}catch{error(400,"Invalid JSON")}
  const u=await userFrom(req),uid=u.id;
  let value;
  switch(b.action){
   case "session":value=await sessionInfo(u);break;
   case "register-account":value=await registerAccount(uid,b);break;
   case "admin-queue":value=await adminQueue(uid);break;
   case "admin-decide":value=await adminDecide(uid,b);break;
   case "catalog":await requireAccount(uid);value=await run("select code,title_fr,question_count,max_attempts,timer_enabled,timer_duration_seconds from fr_edu.assessments where pilot_enabled=true order by code");break;
   case "admin-timers":value=await adminTimers(uid);break;
   case "admin-set-timer":value=await adminSetTimer(uid,b);break;
   case "list-learners":value=await listLearners(uid);break;
   case "create-learner":value=await createLearner(uid,b);break;
   case "teacher-code":await requireAccount(uid,"teacher");value=await teacherCode(uid);break;
   case "share-teacher":value=await shareTeacher(uid,b);break;
   case "unshare-teacher":value=await unshareTeacher(uid,b);break;
   case "delete-learner":value=await deleteLearner(uid,b);break;
   case "teacher-report":await requireAccount(uid,"teacher");value=await teacherReport(uid);break;
   case "own-report":value=await accountReport(uid,b.learner_id);break;
   case "start":value=await start(uid,b);break;
   case "get-attempt":value=await getAttempt(uid,b);break;
   case "save-answer":value=await saveAnswer(uid,b);break;
   case "submit":value=await submit(uid,b);break;
   default:error(400,"Action inconnue");
  }
  return response({ok:true,result:value});
 }catch(e){
  const status=e instanceof Failure?e.status:500;
  if(status===500)console.error("french_education_pilot:",String(e?.message||e).slice(0,350));
  return response({ok:false,error:status===500?"Erreur serveur":String(e?.message||e)},status);
 }
});