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
async function teacher(uid){return (await run("select 1 from fr_edu.user_roles where user_id=$1 and role_name in ('teacher','admin') limit 1",[uid])).length>0;}
async function learner(uid,id){
 if(!validId(id))error(400,"Identifiant d'élève invalide");
 const x=await run("select id,display_name,grade_code,consent_revoked_at from fr_edu.learners where id=$1 and guardian_user_id=$2",[id,uid]);
 if(!x.length||x[0].consent_revoked_at)error(403,"Accès élève refusé ou consentement retiré");
 return x[0];
}
async function accountReport(uid,id){
 await learner(uid,id);
 return await run("select assessment_code,attempt_number,auto_score,maximum_score,state,submitted_at from fr_edu.attempts where learner_id=$1 and student_user_id=$2 and state in ('scored','review_required') order by submitted_at desc limit 150",[id,uid]);
}
async function listLearners(uid){
 return await run("select id,display_name,grade_code,created_at from fr_edu.learners where guardian_user_id=$1 and consent_revoked_at is null order by created_at desc limit 100",[uid]);
}
async function createLearner(uid,b){
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
 await learner(uid,b.learner_id);
 const code=field(b,"teacher_code",40).toUpperCase();
 const rows=await run("select c.teacher_user_id from fr_edu.teacher_codes c join fr_edu.user_roles r on r.user_id=c.teacher_user_id and r.role_name in ('teacher','admin') where c.share_code=$1 limit 1",[code]);
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
 const learners=await run("select l.id,l.display_name,l.grade_code from fr_edu.teacher_learner_access x join fr_edu.learners l on l.id=x.learner_id where x.teacher_user_id=$1 and x.revoked_at is null and l.consent_revoked_at is null order by l.created_at desc limit 200",[uid]);
 const attempts=await run("select a.learner_id,a.assessment_code,a.attempt_number,a.auto_score,a.maximum_score,a.submitted_at,a.state from fr_edu.teacher_learner_access x join fr_edu.learners l on l.id=x.learner_id join fr_edu.attempts a on a.learner_id=l.id where x.teacher_user_id=$1 and x.revoked_at is null and l.consent_revoked_at is null and a.state in ('scored','review_required') order by a.submitted_at desc limit 500",[uid]);
 return {learners,attempts};
}
async function checkAttempt(uid,id){
 if(!validId(id))error(400,"Tentative invalide");
 const x=await run("select a.id,a.learner_id,a.assessment_code,a.attempt_number,a.state,a.auto_score,a.maximum_score from fr_edu.attempts a join fr_edu.learners l on l.id=a.learner_id where a.id=$1 and a.student_user_id=$2 and l.guardian_user_id=$2 and l.consent_revoked_at is null",[id,uid]);
 if(!x.length)error(403,"Accès refusé");
 return x[0];
}
async function questions(id){
 const rows=await run("select r.display_order,r.answer_mode,l.topic_code,l.visual_type,l.visual_value,l.missing_index,l.canonical_fr from fr_edu.responses r join fr_edu.lexemes l on l.id=r.lexeme_id where r.attempt_id=$1 order by r.display_order",[id]);
 const out=[];
 for(const row of rows){
  const q={order:row.display_order,mode:row.answer_mode,topic:row.topic_code,visual_type:row.visual_type,visual_value:row.visual_value};
  if(row.answer_mode==="choose"){
   const opts=await run("select canonical_fr from fr_edu.lexemes where topic_code=$1 and canonical_fr<>$2 order by random() limit 3",[row.topic_code,row.canonical_fr]);
   q.options=shuffled([row.canonical_fr,...opts.map(x=>x.canonical_fr)]);
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
async function start(uid,b){
 const own=await learner(uid,b.learner_id);
 const code=field(b,"assessment_code",100);
 const assessments=await run("select code,question_count,max_attempts from fr_edu.assessments where code=$1 and pilot_enabled=true",[code]);
 if(!assessments.length)error(404,"Examen indisponible");
 const def=assessments[0];
 const previous=await run("select id,attempt_number,state from fr_edu.attempts where student_user_id=$1 and learner_id=$2 and assessment_code=$3 order by attempt_number desc",[uid,own.id,code]);
 const current=previous.find(x=>x.state==="in_progress");
 if(current)return {attempt_id:current.id,attempt_number:current.attempt_number,questions:await questions(current.id),resumed:true};
 if(previous.length>=Number(def.max_attempts))error(409,"Trois tentatives déjà utilisées");
 const pool=await run("select topic_code,mode,question_count from fr_edu.assessment_pool where assessment_code=$1 order by topic_code,mode",[code]);
 if(!pool.length)error(422,"Examen sans banque de questions");
 const no=previous.length+1;
 const id=await sql.begin(async tx=>{
  const created=await run("insert into fr_edu.attempts(student_user_id,learner_id,assessment_code,attempt_number) values($1,$2,$3,$4) returning id",[uid,own.id,code,no],tx);
  const id=created[0].id,selected=[];
  for(const block of pool){
   const lex=await run("select id from fr_edu.lexemes where topic_code=$1 and content_status<>'retired' order by random() limit $2",[block.topic_code,block.question_count],tx);
   if(lex.length!==Number(block.question_count))error(422,"Banque incomplète");
   for(const item of lex)selected.push({id:item.id,mode:block.mode});
  }
  if(selected.length!==Number(def.question_count))error(422,"Nombre de questions incohérent");
  let order=1;
  for(const q of shuffled(selected))await run("insert into fr_edu.responses(attempt_id,display_order,lexeme_id,answer_mode) values($1,$2,$3,$4)",[id,order++,q.id,q.mode],tx);
  return id;
 });
 return {attempt_id:id,attempt_number:no,questions:await questions(id),resumed:false};
}
async function getAttempt(uid,b){
 const a=await checkAttempt(uid,b.attempt_id);
 return a.state==="in_progress"?{attempt_id:a.id,attempt_number:a.attempt_number,state:a.state,questions:await questions(a.id)}:{attempt_id:a.id,attempt_number:a.attempt_number,state:a.state,score:a.auto_score,maximum:a.maximum_score};
}
async function submit(uid,b){
 const id=field(b,"attempt_id",36),answers=b.answers;
 if(!Array.isArray(answers)||answers.length>200)error(400,"Réponses invalides");
 await checkAttempt(uid,id);
 return await sql.begin(async tx=>{
  const checked=await run("select state,student_user_id from fr_edu.attempts where id=$1 for update",[id],tx);
  if(!checked.length||checked[0].student_user_id!==uid)error(403,"Accès refusé");
  if(checked[0].state!=="in_progress"){
   const old=await run("select state,auto_score,maximum_score from fr_edu.attempts where id=$1",[id],tx);
   return {score:old[0].auto_score,maximum:old[0].maximum_score,state:old[0].state,already_submitted:true};
  }
  const questions=await run("select r.display_order,r.answer_mode,l.canonical_fr,l.missing_index,l.topic_code from fr_edu.responses r join fr_edu.lexemes l on l.id=r.lexeme_id where r.attempt_id=$1 order by r.display_order for update of r",[id],tx);
  if(answers.length!==questions.length||!questions.length)error(400,"Toutes les réponses sont requises");
  const map=new Map();
  for(const a of answers){
   if(!a||!Number.isInteger(a.order)||a.order<1||typeof a.answer!=="string"||a.answer.length>100||!a.answer.trim()||map.has(a.order))error(400,"Réponse invalide");
   map.set(a.order,a.answer);
  }
  let score=0;
  for(const q of questions){
   const ans=map.get(q.display_order);
   if(typeof ans!=="string")error(400,"Réponse manquante");
   const expected=q.answer_mode==="letter"?(q.topic_code==="alphabet"?q.canonical_fr:q.canonical_fr[q.missing_index??1]):q.canonical_fr;
   const pts=normalized(ans)===normalized(expected)?1:0;
   score+=pts;
   await run("update fr_edu.responses set answer_value=$1,score=$2,checked_at=now() where attempt_id=$3 and display_order=$4",[ans,pts,id,q.display_order],tx);
  }
  await run("update fr_edu.attempts set state='scored',auto_score=$1,maximum_score=$2,submitted_at=now() where id=$3",[score,questions.length,id],tx);
  return {score,maximum:questions.length,state:"scored",already_submitted:false};
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
   case "session":value={role:await teacher(uid)?"teacher":"guardian",email:u.email,consent_version:CONSENT};break;
   case "catalog":value=await run("select code,title_fr,question_count,max_attempts from fr_edu.assessments where pilot_enabled=true order by code");break;
   case "list-learners":value=await listLearners(uid);break;
   case "create-learner":value=await createLearner(uid,b);break;
   case "teacher-code":value=await teacherCode(uid);break;
   case "share-teacher":value=await shareTeacher(uid,b);break;
   case "unshare-teacher":value=await unshareTeacher(uid,b);break;
   case "delete-learner":value=await deleteLearner(uid,b);break;
   case "teacher-report":value=await teacherReport(uid);break;
   case "own-report":value=await accountReport(uid,b.learner_id);break;
   case "start":value=await start(uid,b);break;
   case "get-attempt":value=await getAttempt(uid,b);break;
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