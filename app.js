import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.57.4/+esm';

const SUPABASE_URL='https://vsuekfzyebqnhthyvwpf.supabase.co';
const SUPABASE_KEY='sb_publishable_sRvoFKXyDEzQPLaAk3xZOQ_RLVxh5g3';
const supabase=createClient(SUPABASE_URL,SUPABASE_KEY);

const D={
 en:{
  dir:'ltr',
  nav:['Confirm profile','Pre-flight assessment','Fit results','My journey'],
  home:'Home',
  start:'Start your journey',
  journey:'See how it works',
  reg:'Candidate Check-in',
  welcome:'Welcome aboard',
  continueApp:'Continue My Application',
  profileTitle:'My Aviation Matrix Profile',
  application:'Application',
  assessmentComplete:'Assessment complete',
  currentFit:'Cabin Crew Current Fit',
  readiness:'Aviation Readiness Panel',
  evidence:'Assessment evidence remains attached to your Aviation Matrix profile.',
  nextStage:'Next Stage · Formal Enrollment',
  lockedTitle:'Your Learning Journey Is Locked',
  lockedBody:'Your assessment is complete, but training missions do not open until your formal Aviation Matrix file is activated.',
  enrollmentRequired:'Enrollment Required',
  candidateNo:'Candidate Number',
  candidateNoPending:'Issued at formal enrollment',
  signature:'Signature',
  payment:'Payment',
  pending:'Pending',
  journeyCode:'Journey Code',
  notActivated:'Not activated',
  startMission:'Start Mission',
  checkin:'Check-in',
  assessment:'Assessment',
  fit:'Fit',
  formalEnrollment:'Formal Enrollment',
  journeyActivation:'Journey Activation',
  strengths:'Why Cabin Crew?',
  development:'Development Priorities',
  status:'Readiness Status',
  currentFitLabel:'Current Fit',
  futureFitLabel:'Future Fit',
  resultIntro:'The recommendation is explained using the competency evidence below. Aviation Matrix does not use a hidden pass/fail score.',
  currentFitDesc:'What your current assessment evidence shows today.',
  futureFitDesc:'Estimated development potential — not a guarantee of future performance.',
  viewProfile:'View My Aviation Profile',
  noGaps:'No major development gaps identified in this assessment.'
 },
 fr:{
  dir:'ltr',
  nav:['Confirmer le profil','Évaluation prévol','Résultats de compatibilité','Ma trajectoire'],
  home:'Accueil',
  start:'Commencer votre parcours',
  journey:'Voir le fonctionnement',
  reg:'Enregistrement candidat',
  welcome:'Bienvenue à bord',
  continueApp:'Continuer ma candidature',
  profileTitle:'Mon profil Aviation Matrix',
  application:'Candidature',
  assessmentComplete:'Évaluation terminée',
  currentFit:'Compatibilité actuelle Cabin Crew',
  readiness:'Tableau de préparation aviation',
  evidence:'Les preuves de votre évaluation restent liées à votre profil Aviation Matrix.',
  nextStage:'Étape suivante · Inscription formelle',
  lockedTitle:'Votre parcours de formation est verrouillé',
  lockedBody:'Votre évaluation est terminée, mais les missions de formation restent verrouillées jusqu’à l’activation officielle de votre dossier Aviation Matrix.',
  enrollmentRequired:'Inscription requise',
  candidateNo:'Numéro candidat',
  candidateNoPending:'Attribué lors de l’inscription formelle',
  signature:'Signature',
  payment:'Paiement',
  pending:'En attente',
  journeyCode:'Code du parcours',
  notActivated:'Non activé',
  startMission:'Démarrer la mission',
  checkin:'Enregistrement',
  assessment:'Évaluation',
  fit:'Compatibilité',
  formalEnrollment:'Inscription formelle',
  journeyActivation:'Activation du parcours',
  strengths:'Pourquoi Cabin Crew ?',
  development:'Priorités de développement',
  status:'Statut de préparation',
  currentFitLabel:'Compatibilité actuelle',
  futureFitLabel:'Compatibilité future',
  resultIntro:'La recommandation est expliquée à partir des compétences observées. Aviation Matrix n’utilise pas de seuil caché de réussite/échec.',
  currentFitDesc:'Ce que montrent aujourd’hui les éléments observés dans votre évaluation.',
  futureFitDesc:'Potentiel de développement estimé — ce n’est pas une garantie de performance future.',
  viewProfile:'Voir mon profil Aviation Matrix',
  noGaps:'Aucun écart majeur de développement identifié dans cette évaluation.'
 },
 ru:{
  dir:'ltr',
  nav:['Подтвердить профиль','Предполётная оценка','Результаты соответствия','Мой маршрут'],
  home:'Главная',
  start:'Начать путь',
  journey:'Как это работает',
  reg:'Регистрация кандидата',
  welcome:'Добро пожаловать',
  continueApp:'Продолжить заявку',
  profileTitle:'Мой профиль Aviation Matrix',
  application:'Заявка',
  assessmentComplete:'Оценка завершена',
  currentFit:'Текущая пригодность Cabin Crew',
  readiness:'Панель авиационной готовности',
  evidence:'Результаты оценки остаются привязаны к вашему профилю Aviation Matrix.',
  nextStage:'Следующий этап · Официальное зачисление',
  lockedTitle:'Ваш учебный маршрут заблокирован',
  lockedBody:'Оценка завершена, но учебные миссии откроются только после официальной активации вашего профиля Aviation Matrix.',
  enrollmentRequired:'Требуется зачисление',
  candidateNo:'Номер кандидата',
  candidateNoPending:'Выдаётся при официальном зачислении',
  signature:'Подпись',
  payment:'Оплата',
  pending:'Ожидается',
  journeyCode:'Код маршрута',
  notActivated:'Не активирован',
  startMission:'Начать миссию',
  checkin:'Регистрация',
  assessment:'Оценка',
  fit:'Соответствие',
  formalEnrollment:'Официальное зачисление',
  journeyActivation:'Активация маршрута',
  strengths:'Почему Cabin Crew?',
  development:'Приоритеты развития',
  status:'Статус готовности',
  currentFitLabel:'Текущая пригодность',
  futureFitLabel:'Будущая пригодность',
  resultIntro:'Рекомендация объясняется на основе наблюдаемых компетенций. Aviation Matrix не использует скрытую систему pass/fail.',
  currentFitDesc:'Что текущая оценка показывает о вашей готовности сегодня.',
  futureFitDesc:'Оценочный потенциал развития — не гарантия будущей эффективности.',
  viewProfile:'Открыть мой профиль Aviation Matrix',
  noGaps:'В этой оценке не выявлено серьёзных пробелов развития.'
 }
};

let runtimeQuestions=[];
let questionTimer=null;
let questionStartedAt=0;

let lang=['en','fr','ru'].includes(localStorage.getItem('am_lang'))?localStorage.getItem('am_lang'):'en';
let state=JSON.parse(localStorage.getItem('am_state')||'{}');
let assessment=null;
let currentView=localStorage.getItem('am_view')||'landing';
const app=document.getElementById('app');

function ui(k){return (D[lang]&&D[lang][k])||(D.en&&D.en[k])||k;}
function t(k){return D[lang][k]||k}
function esc(s=''){return String(s).replace(/[&<>'"]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[m]))}
function save(){localStorage.setItem('am_state',JSON.stringify(state))}
function setLang(l){
 if(!['en','fr','ru'].includes(l) || currentView==='assessment') return;
 lang=l;
 localStorage.setItem('am_lang',l);
 document.documentElement.lang=l;
 document.documentElement.dir='ltr';
 render(currentView);
}

function header(){
 return `<header class="topbar"><div class="container topbar-inner">
  <div class="brand"><div class="brand-mark">✈</div><div>Aviation Matrix<small>Talent Intelligence & Development</small></div></div>
  <div style="display:flex;gap:10px;align-items:center">
      ${currentView!=='landing'?`<button id="homeBtn" class="btn btn-outline" style="padding:8px 14px">${ui('home')}</button>`:''}
      <div class="lang">${currentView==='assessment'?'':['en','fr','ru'].map(l=>`<button data-lang="${l}" class="${lang===l?'active':''}">${l.toUpperCase()}</button>`).join('')}</div>
    </div>
 </div></header>`;
}

function landing(){
 return `<div>${header()}
 <section class="hero"><div class="route-art"><div class="route-plane">✈</div></div>
  <div class="runway"><span class="rlight r1"></span><span class="rlight r2"></span><span class="rlight r3"></span><span class="rlight r4"></span><span class="rlight r5"></span><span class="rlight r6"></span></div>
  <div class="container hero-grid">
   <div>
    <span class="eyebrow">WELCOME ABOARD · AVIATION MATRIX</span>
    <div class="route-code">CHECK-IN → PRE-FLIGHT → FIT → FLIGHT PATH</div>
    <h1>${t('hero')}</h1><p class="lead">${t('sub')}</p>
    <div class="cta-row"><button id="startBtn" class="btn btn-primary">✈ &nbsp; ${t('start')}</button><button id="continueBtn" class="btn btn-outline">${ui('continueApp')}</button><button class="btn btn-outline" data-scroll="journey">${t('journey')}</button></div>
    <div class="status-strip"><span class="status-dot"></span><strong>STATUS</strong><span>READY FOR CANDIDATE CHECK-IN</span></div>
   </div>
   <aside class="boarding-pass">
    <div class="boarding-head"><span class="mono">BOARDING PASS</span><span class="mono">AMX · 001</span></div>
    <h3>${t('reg')}</h3><p>${lang==='fr'?'Commencez comme candidat aviation, pas simplement comme stagiaire.':lang==='ru'?'Начните как авиационный кандидат, а не просто слушатель курса.':'Start as an aviation candidate, not just a course applicant.'}</p>
    <div class="ticket-list">
     <div class="ticket"><b>01</b><span>Candidate Check-in</span><em>OPEN</em></div>
     <div class="ticket"><b>02</b><span>Pre-Flight Assessment</span><em>NEXT</em></div>
     <div class="ticket"><b>03</b><span>Current / Future Fit</span><em>FIT</em></div>
     <div class="ticket"><b>04</b><span>Suggested Aviation Path</span><em>PATH</em></div>
     <div class="ticket"><b>05</b><span>My Flight Path</span><em>READY</em></div>
    </div>
    <div class="boarding-foot"><span>GATE</span><strong>AM</strong><span>DESTINATION</span><strong>YOUR AVIATION FUTURE</strong></div>
   </aside>
  </div>
 </section>
 <section class="section" id="journey"><div class="container"><h2>${t('journey')}</h2><p class="section-lead">${t('journeySub')}</p>
  <div class="grid-3">
   <div class="card info-card"><strong>01 · Candidate Check-in</strong><p>Identity, education, interests and professional starting point.</p></div>
   <div class="card info-card"><strong>02 · ${t('fit')}</strong><p>Strengths, development gaps, current fit and future fit.</p></div>
   <div class="card info-card"><strong>03 · ${t('learn')}</strong><p>Missions, technical English, decision quality and airline readiness.</p></div>
  </div>
 </div></section>
 <footer class="footer"><div class="container">Aviation Matrix · ${t('privacy')}</div></footer></div>`;
}

function registration(){
 return `<div class="overlay" id="regOverlay"><div class="modal">
  <div class="modal-kicker">CANDIDATE CHECK-IN · GATE AM</div>
  <div class="checkin-steps"><span>1 · CHECK-IN</span><span>2 · PRE-FLIGHT</span><span>3 · FIT</span><span>4 · FLIGHT PATH</span></div>
  <div class="modal-head"><div><h2>${t('reg')}</h2><p class="muted">No CV upload — your professional profile is built inside Aviation Matrix.</p></div><button class="close" id="closeModal">×</button></div>
  <form id="regForm"><div class="form-grid">
   <div class="field"><label>Full name</label><input name="full_name" required value="${esc(state.full_name||'')}"></div>
   <div class="field"><label>Mobile</label><input name="mobile" required value="${esc(state.mobile||'')}"></div>
   <div class="field"><label>Email</label><input type="email" name="email" required value="${esc(state.email||'')}"></div>
   <div class="field"><label>Date of birth</label><input type="date" name="date_of_birth" required value="${esc(state.date_of_birth||'')}"></div>
   <div class="field"><label>Education stage</label><select name="education_stage"><option value="school">School</option><option value="secondary">Secondary</option><option value="university">University</option><option value="graduate">Graduate</option><option value="other">Other</option></select></div>
   <div class="field"><label>Current city</label><input name="current_city" required value="${esc(state.current_city||'')}"></div>
   <div class="field"><label>Aviation interest</label><select name="aviation_interest"><option value="cabin_crew">Cabin Crew</option><option value="passenger_services">Passenger Services</option><option value="cargo">Cargo</option><option value="ground_operations">Ground Operations</option><option value="flight_ops">Flight Operations</option><option value="not_sure">Not sure yet</option></select></div>
   <div class="field"><label>Interface language</label><select name="preferred_language"><option value="en">English</option><option value="fr">French</option><option value="ru">Russian</option></select></div>
   <div class="field full"><div class="check"><input type="checkbox" id="consent" name="consent" required><label for="consent">${t('privacy')}</label></div></div>
   <div class="field full"><div id="regMsg" class="helper"></div><button class="btn btn-dark" type="submit">${t('continue')}</button></div>
  </div></form>
 </div></div>`;
}


function resumeApplicationModal(){
 return `<div class="overlay" id="resumeOverlay"><div class="modal">
  <div class="modal-kicker">EXISTING APPLICATION · AVIATION MATRIX</div>
  <div class="modal-head"><div><h2>Continue My Application</h2><p class="muted">Enter the details linked to your first registration.</p></div><button class="close" id="closeResume">×</button></div>
  <form id="resumeForm"><div class="form-grid">
   <div class="field full"><label>Application Number</label><input name="application_number" placeholder="AM-A-2026-000001" required></div>
   <div class="field"><label>Email</label><input type="email" name="email" required></div>
   <div class="field"><label>Date of birth</label><input type="date" name="date_of_birth" required></div>
   <div class="field full"><div id="resumeMsg" class="helper"></div><button class="btn btn-dark" type="submit">Continue Application →</button></div>
  </div></form>
 </div></div>`;
}

async function resumeApplication(form){
 const fd=new FormData(form);
 const args={
  p_application_number:String(fd.get('application_number')||'').trim().toUpperCase(),
  p_email:String(fd.get('email')||'').trim(),
  p_date_of_birth:fd.get('date_of_birth')
 };
 const msg=document.getElementById('resumeMsg');
 if(msg){msg.className='helper';msg.textContent='Finding your Aviation Matrix application...';}
 try{
  const {data,error}=await supabase.rpc('public_resume_application',args);
  if(error) throw error;
  state={...state,...data};
  if(data.assessment_result){
   const er=data.assessment_result.evidence_payload||{};
   state.assessment={
    current_fit:data.assessment_result.current_fit,
    future_fit:data.assessment_result.future_fit,
    readiness_status:data.assessment_result.readiness_status,
    summary:data.assessment_result.summary,
    ...er
   };
  }
  save();

  const {data:resumeData,error:resumeError}=await supabase.rpc('public_resume_assessment',args);
  if(resumeError) throw resumeError;
  document.getElementById('resumeOverlay')?.remove();

  if(resumeData.status==='in_progress'){
   await loadPublishedQuestions();
   assessment={
    index:Math.min(Number(resumeData.answered_count)||0,runtimeQuestions.length-1),
    attempt_id:resumeData.attempt_id,
    access_token:resumeData.access_token,
    candidate_id:resumeData.candidate_id,
    locked:false,
    result:null
   };
   render('assessment');
  }else if(resumeData.status==='completed' && state.assessment){
   render('results');
  }else if(data.assessment_result){
   render('results');
  }else if(data.profile_status){
   render('confirm');
  }else{
   render('welcome');
  }
 }catch(e){
  console.error(e);
  if(msg){msg.className='helper error';msg.textContent=e.message?.includes('APPLICATION_NOT_FOUND')?'Application not found. Check the number, email and date of birth.':'Unable to continue this application: '+(e.message||'Unknown error');}
 }
}

function flowShell(content,step,pct){
 const steps=[t('confirm'),t('assess'),t('results'),t('dashboard')];
 return `${header()}<main class="container flow"><div class="flight-strip">✈ &nbsp; AVIATION JOURNEY CONTROL &nbsp; · &nbsp; CHECK-IN → PRE-FLIGHT → FIT → FLIGHT PATH</div>
 <div class="progress"><div style="width:${pct}%"></div></div>
 <div class="stepbar">${steps.map((s,i)=>`<span class="step ${i+1<step?'done':''} ${i+1===step?'active':''}">${s}</span>`).join('')}</div>
 <div class="card screen-card">${content}</div></main>`;
}

function welcome(){
 return flowShell(`<span class="eyebrow" style="color:#0b5279;border-color:#cfe8f5;background:#effaff">JOURNEY STARTED</span>
 <h1>${t('welcome')}</h1>
 <div style="margin:14px 0;padding:16px 18px;border:1px solid #cfe6f3;background:#effaff;border-radius:18px">
  <span class="muted">Your Application Number</span><br>
  <strong style="font-size:28px;letter-spacing:.06em">${esc(state.application_number||'Pending')}</strong><br>
  <small class="muted">Keep this number. You will use it to continue online and when you visit the branch.</small>
 </div>
 <p class="section-lead">${esc(state.full_name||'Candidate')}, your application is active. We will confirm your profile, run a short pre-flight assessment, then open your aviation path.</p>
 <div class="grid-3">
  <div class="info-card card"><strong>01 · Check-in</strong><p>Profile and declared data</p></div>
  <div class="info-card card"><strong>02 · Pre-Flight</strong><p>Decision quality and readiness</p></div>
  <div class="info-card card"><strong>03 · Flight Path</strong><p>Current fit, future fit and missions</p></div>
 </div><div style="margin-top:20px"><button id="confirmBtn" class="btn btn-dark">${t('confirm')} →</button></div>`,1,20);
}

function confirmProfile(){
 return flowShell(`<h2>${t('confirm')}</h2><p class="section-lead">Check the information that will form the first version of your Aviation Matrix profile.</p>
 <div class="grid-3">
  <div class="info-card card"><strong>${esc(state.full_name||'—')}</strong><p>${esc(state.email||'—')}<br>${esc(state.mobile||'—')}</p></div>
  <div class="info-card card"><strong>${esc(state.education_stage||'—')}</strong><p>${esc(state.current_city||'—')}</p></div>
  <div class="info-card card"><strong>${esc(state.aviation_interest||'—')}</strong><p>Declared aviation interest</p></div>
 </div><div style="margin-top:20px"><button id="beginAssessment" class="btn btn-primary">${t('assess')} ✈</button></div>`,1,30);
}


async function loadPublishedQuestions(){
 const {data,error}=await supabase
   .from('question_bank')
   .select('id,code,prompt,time_limit_seconds,question_options(id,option_code,option_text,sequence_no)')
   .eq('status','published')
   .like('code','CFV1_CC_%')
   .order('code',{ascending:true});
 if(error) throw error;
 runtimeQuestions=(data||[]).map(q=>({
   ...q,
   question_options:(q.question_options||[]).sort((a,b)=>a.sequence_no-b.sequence_no)
 }));
 if(!runtimeQuestions.length) throw new Error('No published Cabin Crew questions found.');
}

async function beginLiveAssessment(){
 const btn=document.getElementById('beginAssessment');
 if(btn){btn.disabled=true;btn.textContent='Preparing assessment...';}
 try{
  await loadPublishedQuestions();
  const {data,error}=await supabase.rpc('public_start_assessment',{
    p_email:state.email,
    p_mobile:state.mobile,
    p_date_of_birth:state.date_of_birth,
    p_career_code:'cabin_crew'
  });
  if(error) throw error;
  assessment={
    index:0,
    attempt_id:data.attempt_id,
    access_token:data.access_token,
    candidate_id:data.candidate_id,
    locked:false,
    result:null
  };
  state.candidate_id=data.candidate_id;
  save();
  render('assessment');
 }catch(e){
  console.error(e);
  if(btn){btn.disabled=false;btn.textContent='Pre-Flight Assessment ✈';}
  alert('Unable to start assessment: '+(e.message||'Unknown error'));
 }
}

function assessmentScreen(){
 if(!assessment || !runtimeQuestions.length){
   return flowShell(`<h2>Assessment not ready</h2><p class="muted">Please return and start the assessment again.</p>`,2,35);
 }
 const q=runtimeQuestions[assessment.index];
 const visible=(q.question_options||[]).filter(o=>o.option_code!=='TIMEOUT');
 const pct=Math.round((assessment.index/runtimeQuestions.length)*100);
 const limit=q.time_limit_seconds||15;
 return flowShell(`<div dir="ltr" style="text-align:left">
   <div style="display:flex;justify-content:space-between;align-items:center;gap:14px;margin-bottom:14px">
    <div class="question-meta">CABIN CREW · PRE-FLIGHT ASSESSMENT · ${assessment.index+1} / ${runtimeQuestions.length}</div>
    <div id="questionTimer" style="min-width:64px;text-align:center;padding:9px 12px;border-radius:999px;background:#071a2f;color:#fff;font-size:18px;font-weight:900">${limit}s</div>
   </div>
   <div style="height:8px;background:#e7eef3;border-radius:999px;overflow:hidden;margin-bottom:22px">
    <div id="timerBar" style="height:100%;width:100%;background:#45b8f6;transition:width .2s linear"></div>
   </div>
   <h2>${esc(q.prompt)}</h2>
   <p class="muted">Choose the response closest to what you would naturally do. You have ${limit} seconds. When time expires, the question closes automatically.</p>
   <div class="options">
    ${visible.map(o=>`<button class="option" data-option-id="${o.id}"><strong>${esc(o.option_code)}</strong> — ${esc(o.option_text)}</button>`).join('')}
   </div>
   <div id="answerMsg" class="helper" style="margin-top:12px"></div>
  </div>`,2,35+pct*0.35);
}

function startQuestionTimer(){
 clearInterval(questionTimer);
 if(!assessment || assessment.locked || !runtimeQuestions.length) return;
 const q=runtimeQuestions[assessment.index];
 const limit=q.time_limit_seconds||15;
 questionStartedAt=Date.now();
 let remaining=limit;
 const label=document.getElementById('questionTimer');
 const bar=document.getElementById('timerBar');
 const paint=()=>{
   if(label) label.textContent=`${remaining}s`;
   if(bar) bar.style.width=`${Math.max(0,(remaining/limit)*100)}%`;
   if(label){
     label.style.background=remaining<=5?'#9b2c2c':remaining<=8?'#9a6714':'#071a2f';
   }
 };
 paint();
 questionTimer=setInterval(async()=>{
   remaining-=1; paint();
   if(remaining<=0){
     clearInterval(questionTimer);
     await submitTimedAnswer(null,true);
   }
 },1000);
}

async function submitTimedAnswer(optionId,isTimeout=false){
 if(!assessment || assessment.locked) return;
 assessment.locked=true;
 clearInterval(questionTimer);
 const q=runtimeQuestions[assessment.index];
 const options=q.question_options||[];
 const selected=isTimeout ? options.find(o=>o.option_code==='TIMEOUT') : options.find(o=>o.id===optionId);
 if(!selected){
   assessment.locked=false;
   const msg=document.getElementById('answerMsg');
   if(msg){msg.className='helper error';msg.textContent='Unable to record this answer.';}
   return;
 }
 document.querySelectorAll('.option').forEach(b=>b.disabled=true);
 const elapsed=isTimeout ? (q.time_limit_seconds||15) : Math.max(1,Math.min(q.time_limit_seconds||15,Math.ceil((Date.now()-questionStartedAt)/1000)));
 const msg=document.getElementById('answerMsg');
 if(msg){msg.textContent=isTimeout?'Time expired — moving to the next question...':'Answer recorded...';}
 try{
   const {error}=await supabase.rpc('public_submit_assessment_answer',{
     p_attempt_id:assessment.attempt_id,
     p_access_token:assessment.access_token,
     p_question_id:q.id,
     p_option_id:selected.id,
     p_response_time_seconds:elapsed
   });
   if(error) throw error;
   assessment.index+=1;
   assessment.locked=false;
   if(assessment.index>=runtimeQuestions.length){
     await finishLiveAssessment();
   }else{
     render('assessment');
   }
 }catch(e){
   console.error(e);
   assessment.locked=false;
   document.querySelectorAll('.option').forEach(b=>b.disabled=false);
   if(msg){msg.className='helper error';msg.textContent='Connection error. Your question is paused — tap an answer again.';}
 }
}

async function finishLiveAssessment(){
 clearInterval(questionTimer);
 app.innerHTML=flowShell(`<div dir="ltr" style="text-align:left"><h2>Calculating your Cabin Crew fit...</h2><p class="muted">Your decisions are being evaluated against the Aviation Matrix competency model.</p></div>`,3,76);
 try{
   const {data,error}=await supabase.rpc('public_finish_assessment',{
     p_attempt_id:assessment.attempt_id,
     p_access_token:assessment.access_token,
     p_career_code:'cabin_crew'
   });
   if(error) throw error;
   assessment.result=data;
   state.assessment=data;
   state.assessment_completed_at=new Date().toISOString();
   save();
   render('results');
 }catch(e){
   console.error(e);
   app.innerHTML=flowShell(`<div dir="ltr" style="text-align:left"><h2>We could not calculate the result</h2><p class="error">${esc(e.message||'Unknown error')}</p><button id="retryFinish" class="btn btn-dark">Retry result calculation</button></div>`,3,76);
   document.getElementById('retryFinish')?.addEventListener('click',finishLiveAssessment);
 }
}

function results(){
 const r=state.assessment;
 if(!r || typeof r.current_fit==='undefined') return render('confirm');
 const strengths=r.strengths||[];
 const gaps=r.development_gaps||[];
 const statusLabel={
   ready_now:lang==='fr'?'Prêt maintenant':lang==='ru'?'Готов сейчас':'Ready Now',
   ready_with_development:lang==='fr'?'Prêt avec développement':lang==='ru'?'Готов с развитием':'Ready with Development',
   development_required:lang==='fr'?'Développement requis':lang==='ru'?'Требуется развитие':'Development Required',
   future_eligible:lang==='fr'?'Potentiel futur':lang==='ru'?'Перспективен в будущем':'Future Eligible'
 }[r.readiness_status]||r.readiness_status||'Assessment Complete';
 return flowShell(`<div dir="ltr" style="text-align:left">
  <span class="eyebrow" style="color:#0b5279;border-color:#cfe8f5;background:#effaff">FIT ANALYSIS COMPLETE</span>
  <h1>Cabin Crew Career Fit</h1>
  <p class="section-lead">${esc(r.summary||'Your result is based on the behavior demonstrated across the assessment scenarios.')}</p>
  <div class="result-hero">
   <div class="fit-card"><span class="muted">${ui('currentFitLabel')}</span><b>${Math.round(Number(r.current_fit)||0)}%</b><p>${ui('currentFitDesc')}</p></div>
   <div class="fit-card"><span class="muted">${ui('futureFitLabel')}</span><b>${Math.round(Number(r.future_fit)||0)}%</b><p>${ui('futureFitDesc')}</p></div>
  </div>
  <div style="margin:18px 0;padding:16px;border-radius:18px;background:#f2f8fc;border:1px solid #dceaf3">
    <strong>${ui('status')}: ${esc(statusLabel)}</strong>
  </div>
  <h3>${ui('strengths')}</h3>
  <p class="muted">${ui('resultIntro')}</p>
  <div class="grid-3">${strengths.map(s=>`<div class="card info-card"><strong>${esc(s.name||s.code)}</strong><p><b>${Math.round(Number(s.score)||0)}%</b><br>Observed strength contributing to Cabin Crew fit.</p></div>`).join('')}</div>
  <h3 style="margin-top:22px">${ui('development')}</h3>
  <div class="path-list">${gaps.length?gaps.map(g=>`<div class="path"><strong>${esc(g.name||g.code)}</strong><span style="float:right">${Math.round(Number(g.score)||0)}% → target ${Math.round(Number(g.target)||0)}%</span><br><small class="muted">${esc(g.reason||'Development recommended.')}${g.recommended_path?' · '+esc(g.recommended_path):''}</small></div>`).join(''):`<div class="path best"><strong>${ui('noGaps')}</strong></div>`}</div>
  <div style="margin-top:22px"><button id="openJourney" class="btn btn-dark">${ui('viewProfile')} →</button></div>
 </div>`,3,82);
}
function dashboard(){
 const r=state.assessment||{};
 const dims=r.dimensions||{};
 const d=(code)=>Math.round(Number(dims[code]?.score)||0);
 const under18=(new Date().getFullYear()-new Date(state.date_of_birth||'1900-01-01').getFullYear()<18);
 const sig=under18
   ? (lang==='fr'?'Tuteur requis':lang==='ru'?'Требуется опекун':'Guardian required')
   : (lang==='fr'?'Signature du candidat':lang==='ru'?'Подпись кандидата':'Candidate signature');
 return flowShell(`<section class="journey-hero" dir="ltr" style="text-align:left">
  <small style="letter-spacing:.13em;color:#bce9ff;font-weight:900">${ui('profileTitle').toUpperCase()}</small>
  <h1 style="margin:10px 0 8px">${esc(state.full_name||'Candidate')}</h1>
  <p style="color:#d8e9f4;margin:0">${ui('application')}: <strong>${esc(state.application_number||'—')}</strong> · ${ui('assessmentComplete')} · ${ui('currentFit')}: <strong>${Math.round(Number(r.current_fit)||0)}%</strong></p>
  <div class="journey-path"><span class="done">${ui('checkin')} ✓</span><span class="done">${ui('assessment')} ✓</span><span class="done">${ui('fit')} ✓</span><span>${ui('formalEnrollment')} 🔒</span><span>${ui('journeyActivation')} 🔒</span></div>
 </section>
 <div class="dashboard-grid" dir="ltr" style="text-align:left">
  <div>
   <div class="readiness"><h3>${ui('readiness')}</h3><p class="muted">${ui('evidence')}</p>
    <div class="meter"><div style="width:${Math.round(Number(r.current_fit)||0)}%"></div></div>
    <div class="mini-bars">
     ${[['Safety Mindset',d('safety_mindset')],['Communication',d('communication')],['Teamwork / CRM',d('teamwork_crm')],['English Readiness',d('english_readiness')]].map(x=>`<div class="mini-bar"><div class="head"><span>${x[0]}</span><strong>${x[1]}%</strong></div><div class="bar"><span style="width:${x[1]}%"></span></div></div>`).join('')}
    </div>
   </div>
  </div>
  <aside class="card mission">
   <div class="mission-head"><small>${ui('nextStage')}</small><h3>${ui('lockedTitle')}</h3><p>${ui('lockedBody')}</p></div>
   <div class="mission-body">
    <span class="pill warn">🔒 ${ui('enrollmentRequired')}</span>
    <div class="meta-grid">
     <div class="meta"><label>${ui('candidateNo')}</label><strong>${ui('candidateNoPending')}</strong></div>
     <div class="meta"><label>${ui('signature')}</label><strong>${sig}</strong></div>
     <div class="meta"><label>${ui('payment')}</label><strong>${ui('pending')}</strong></div>
     <div class="meta"><label>${ui('journeyCode')}</label><strong>${ui('notActivated')}</strong></div>
    </div>
    <button class="btn btn-soft" disabled>${ui('startMission')} 🔒</button>
   </div>
  </aside>
 </div>`,4,100);
}
function missionDemo(){
 const msg=document.getElementById('missionMsg');if(msg){msg.className='helper success';msg.textContent='Mission engine ready. Next we will build this mission as a sequence of interactive aviation screens.'}
}

async function submitRegistration(form){
 const fd=new FormData(form);
 const payload={
  full_name:fd.get('full_name'),mobile:fd.get('mobile'),email:fd.get('email'),
  date_of_birth:fd.get('date_of_birth'),education_stage:fd.get('education_stage'),
  current_city:fd.get('current_city'),aviation_interest:fd.get('aviation_interest'),
  preferred_language:fd.get('preferred_language'),consent:true
 };
 const msg=document.getElementById('regMsg');msg.textContent='Creating your Aviation Matrix application...';msg.className='helper';
 try{
  const {data,error}=await supabase.rpc('public_register_application',{
   p_full_name:payload.full_name,p_mobile:payload.mobile,p_email:payload.email,
   p_date_of_birth:payload.date_of_birth,p_education_stage:payload.education_stage,
   p_current_city:payload.current_city,p_aviation_interest:payload.aviation_interest,
   p_preferred_language:payload.preferred_language,p_consent:true
  });
  if(error)throw error;
  state={...state,...payload,...data};save();
  document.getElementById('regOverlay')?.remove();render('welcome');
 }catch(e){
  console.error(e);msg.className='helper error';
  if(e.message?.includes('EMAIL_ALREADY_REGISTERED')||e.message?.includes('MOBILE_ALREADY_REGISTERED')){
   msg.textContent='An application already exists with this mobile number or email. Use “Continue My Application” instead.';
  }else{
   msg.textContent='Registration error: '+(e.message||'Please try again.');
  }
 }
}

function attach(){
 document.getElementById('homeBtn')?.addEventListener('click',()=>{
   clearInterval(questionTimer);
   currentView='landing';
   localStorage.setItem('am_view','landing');
   render('landing');
 });
 document.querySelectorAll('[data-lang]').forEach(b=>b.onclick=()=>setLang(b.dataset.lang));
 document.querySelector('[data-scroll]')?.addEventListener('click',e=>document.getElementById(e.currentTarget.dataset.scroll)?.scrollIntoView());
 const start=document.getElementById('startBtn');if(start)start.onclick=()=>{document.body.insertAdjacentHTML('beforeend',registration());attachModal()};
 const cont=document.getElementById('continueBtn');if(cont)cont.onclick=()=>{document.body.insertAdjacentHTML('beforeend',resumeApplicationModal());attachResumeModal()};
 document.getElementById('confirmBtn')?.addEventListener('click',()=>render('confirm'));
 document.getElementById('beginAssessment')?.addEventListener('click',beginLiveAssessment);
 document.querySelectorAll('.option').forEach(b=>b.onclick=()=>submitTimedAnswer(b.dataset.optionId,false));
 document.getElementById('openJourney')?.addEventListener('click',()=>render('dashboard'));
 document.getElementById('startMission')?.addEventListener('click',missionDemo);
}
function attachModal(){
 document.getElementById('closeModal')?.addEventListener('click',()=>document.getElementById('regOverlay')?.remove());
 document.getElementById('regForm')?.addEventListener('submit',e=>{e.preventDefault();submitRegistration(e.currentTarget)});
}
function attachResumeModal(){
 document.getElementById('closeResume')?.addEventListener('click',()=>document.getElementById('resumeOverlay')?.remove());
 document.getElementById('resumeForm')?.addEventListener('submit',e=>{e.preventDefault();resumeApplication(e.currentTarget)});
}
function render(view=currentView||'landing'){
 clearInterval(questionTimer);
 currentView=view||'landing';
 localStorage.setItem('am_view',currentView);
 document.documentElement.lang=lang;
 document.documentElement.dir='ltr';
 if(currentView==='welcome')app.innerHTML=welcome();
 else if(currentView==='confirm')app.innerHTML=confirmProfile();
 else if(currentView==='assessment')app.innerHTML=assessmentScreen();
 else if(currentView==='results')app.innerHTML=results();
 else if(currentView==='dashboard')app.innerHTML=dashboard();
 else {currentView='landing';localStorage.setItem('am_view','landing');app.innerHTML=landing();}
 attach();
 if(currentView==='assessment') setTimeout(startQuestionTimer,0);
}
if(currentView==='assessment') currentView=state.assessment?'results':(state.application_number?'welcome':'landing');
if(currentView==='results' && !state.assessment) currentView=state.application_number?'welcome':'landing';
render(currentView);
