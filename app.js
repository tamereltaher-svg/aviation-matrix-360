import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.57.4/+esm';

const SUPABASE_URL='https://vsuekfzyebqnhthyvwpf.supabase.co';
const SUPABASE_KEY='sb_publishable_sRvoFKXyDEzQPLaAk3xZOQ_RLVxh5g3';
const supabase=createClient(SUPABASE_URL,SUPABASE_KEY);

const D={
 ar:{dir:'rtl',hero:'أهلًا بك على متن رحلتك في عالم الطيران',sub:'من أول قرار مهني لحد المسار اللي يناسبك، Aviation Matrix بيبني رحلتك خطوة بخطوة داخل عالم الطيران.',start:'ابدأ الـ Check-in',journey:'رحلتك تبدأ قبل التخصص',journeySub:'مش بنبيع كورس واحد للجميع. بنبني صورة مهنية حقيقية ثم نفتح لك المسار الأنسب.',reg:'Aviation Candidate Check-in',fit:'Current Fit + Future Fit',learn:'My Flight Path',privacy:'بياناتك تستخدم لبدء التقييم وبناء ملفك المهني والتواصل فقط.',welcome:'تم فتح ملف رحلتك المهنية',confirm:'Confirm Profile',assess:'Pre-Flight Assessment',results:'Fit Results',dashboard:'My Flight Path',continue:'متابعة',next:'السؤال التالي',finish:'عرض النتيجة',mission:'المهمة الأولى'},
 en:{dir:'ltr',hero:'Welcome Aboard Your Aviation Journey',sub:'From your first career decision to the aviation path that fits you, Aviation Matrix builds your journey step by step.',start:'Start Candidate Check-in',journey:'Your journey starts before specialization',journeySub:'We do not sell one course to everyone. We build a verified professional picture, then open the right path.',reg:'Aviation Candidate Check-in',fit:'Current Fit + Future Fit',learn:'My Flight Path',privacy:'Your data is used to start assessment, build your professional profile, and communicate with you.',welcome:'Your aviation career file is now active',confirm:'Confirm Profile',assess:'Pre-Flight Assessment',results:'Fit Results',dashboard:'My Flight Path',continue:'Continue',next:'Next Question',finish:'View Results',mission:'First Mission'},
 fr:{dir:'ltr',hero:'Bienvenue à bord de votre parcours aviation',sub:'De votre première décision de carrière au parcours aviation qui vous correspond, Aviation Matrix construit votre trajectoire étape par étape.',start:'Commencer le check-in',journey:'Votre parcours commence avant la spécialisation',journeySub:'Nous construisons d’abord un profil professionnel vérifié, puis ouvrons le parcours le plus adapté.',reg:'Check-in du candidat aviation',fit:'Adéquation actuelle + future',learn:'Ma trajectoire',privacy:'Vos données servent à démarrer l’évaluation, construire votre profil et communiquer avec vous.',welcome:'Votre dossier aviation est actif',confirm:'Confirmer le profil',assess:'Évaluation pré-vol',results:'Résultats de compatibilité',dashboard:'Ma trajectoire',continue:'Continuer',next:'Question suivante',finish:'Voir les résultats',mission:'Première mission'},
 ru:{dir:'ltr',hero:'Добро пожаловать на борт вашей авиационной карьеры',sub:'От первого карьерного решения до подходящего авиационного направления — Aviation Matrix строит ваш путь шаг за шагом.',start:'Начать check-in',journey:'Ваш путь начинается до специализации',journeySub:'Сначала мы формируем подтверждённый профессиональный профиль, затем открываем подходящий путь.',reg:'Check-in авиационного кандидата',fit:'Текущая + будущая пригодность',learn:'Мой маршрут',privacy:'Данные используются для оценки, формирования профиля и связи с вами.',welcome:'Ваш авиационный профиль активирован',confirm:'Подтвердить профиль',assess:'Предполётная оценка',results:'Результаты соответствия',dashboard:'Мой маршрут',continue:'Продолжить',next:'Следующий вопрос',finish:'Показать результаты',mission:'Первая миссия'}
};

let runtimeQuestions=[];
let questionTimer=null;
let questionStartedAt=0;

let lang=localStorage.getItem('am_lang')||'ar';
let state=JSON.parse(localStorage.getItem('am_state')||'{}');
let assessment=null;
const app=document.getElementById('app');

function t(k){return D[lang][k]||k}
function esc(s=''){return String(s).replace(/[&<>'"]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[m]))}
function save(){localStorage.setItem('am_state',JSON.stringify(state))}
function setLang(l){lang=l;localStorage.setItem('am_lang',l);document.documentElement.lang=l;document.documentElement.dir=D[l].dir;render()}

function header(){
 return `<header class="topbar"><div class="container topbar-inner">
  <div class="brand"><div class="brand-mark">✈</div><div>Aviation Matrix<small>Talent Intelligence & Development</small></div></div>
  <div class="lang">${['ar','en','fr','ru'].map(l=>`<button data-lang="${l}" class="${lang===l?'active':''}">${l.toUpperCase()}</button>`).join('')}</div>
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
    <div class="cta-row"><button id="startBtn" class="btn btn-primary">✈ &nbsp; ${t('start')}</button><button class="btn btn-outline" data-scroll="journey">${t('journey')}</button></div>
    <div class="status-strip"><span class="status-dot"></span><strong>STATUS</strong><span>READY FOR CANDIDATE CHECK-IN</span></div>
   </div>
   <aside class="boarding-pass">
    <div class="boarding-head"><span class="mono">BOARDING PASS</span><span class="mono">AMX · 001</span></div>
    <h3>${t('reg')}</h3><p>${lang==='ar'?'ابدأ كمرشح طيران، مش مجرد طالب كورس.':lang==='fr'?'Commencez comme candidat aviation, pas simplement comme stagiaire.':lang==='ru'?'Начните как авиационный кандидат, а не просто слушатель курса.':'Start as an aviation candidate, not just a course applicant.'}</p>
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
   <div class="field"><label>Preferred language</label><select name="preferred_language"><option value="ar">Arabic</option><option value="en">English</option><option value="ar_en">Arabic / English</option></select></div>
   <div class="field full"><div class="check"><input type="checkbox" id="consent" name="consent" required><label for="consent">${t('privacy')}</label></div></div>
   <div class="field full"><div id="regMsg" class="helper"></div><button class="btn btn-dark" type="submit">${t('continue')}</button></div>
  </div></form>
 </div></div>`;
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
 <h1>${t('welcome')}</h1><p class="section-lead">${esc(state.full_name||'Candidate')}, your application is active. We will confirm your profile, run a short pre-flight assessment, then open your aviation path.</p>
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
   ready_now:'Ready Now',
   ready_with_development:'Ready with Development',
   development_required:'Development Required',
   future_eligible:'Future Eligible'
 }[r.readiness_status]||r.readiness_status||'Assessment Complete';
 return flowShell(`<div dir="ltr" style="text-align:left">
  <span class="eyebrow" style="color:#0b5279;border-color:#cfe8f5;background:#effaff">FIT ANALYSIS COMPLETE</span>
  <h1>Cabin Crew Career Fit</h1>
  <p class="section-lead">${esc(r.summary||'Your result is based on the behavior demonstrated across the assessment scenarios.')}</p>
  <div class="result-hero">
   <div class="fit-card"><span class="muted">Current Fit</span><b>${Math.round(Number(r.current_fit)||0)}%</b><p>What your current assessment evidence shows today.</p></div>
   <div class="fit-card"><span class="muted">Future Fit</span><b>${Math.round(Number(r.future_fit)||0)}%</b><p>Estimated development potential — not a guarantee of future performance.</p></div>
  </div>
  <div style="margin:18px 0;padding:16px;border-radius:18px;background:#f2f8fc;border:1px solid #dceaf3">
    <strong>Readiness Status: ${esc(statusLabel)}</strong>
  </div>
  <h3>Why Cabin Crew?</h3>
  <p class="muted">The recommendation is explained using the competency evidence below. Aviation Matrix does not use a hidden pass/fail score.</p>
  <div class="grid-3">${strengths.map(s=>`<div class="card info-card"><strong>${esc(s.name||s.code)}</strong><p><b>${Math.round(Number(s.score)||0)}%</b><br>Observed strength contributing to Cabin Crew fit.</p></div>`).join('')}</div>
  <h3 style="margin-top:22px">Development Priorities</h3>
  <div class="path-list">${gaps.length?gaps.map(g=>`<div class="path"><strong>${esc(g.name||g.code)}</strong><span style="float:right">${Math.round(Number(g.score)||0)}% → target ${Math.round(Number(g.target)||0)}%</span><br><small class="muted">${esc(g.reason||'Development recommended.')}${g.recommended_path?' · '+esc(g.recommended_path):''}</small></div>`).join(''):`<div class="path best"><strong>No major development gaps identified in this assessment.</strong></div>`}</div>
  <div style="margin-top:22px"><button id="openJourney" class="btn btn-dark">View My Aviation Profile →</button></div>
 </div>`,3,82);
}
function dashboard(){
 const r=state.assessment||{};
 const dims=r.dimensions||{};
 const d=(code)=>Math.round(Number(dims[code]?.score)||0);
 return flowShell(`<section class="journey-hero" dir="ltr" style="text-align:left">
  <small style="letter-spacing:.13em;color:#bce9ff;font-weight:900">MY AVIATION MATRIX PROFILE</small>
  <h1 style="margin:10px 0 8px">${esc(state.full_name||'Candidate')}</h1>
  <p style="color:#d8e9f4;margin:0">Assessment complete · Cabin Crew Current Fit: <strong>${Math.round(Number(r.current_fit)||0)}%</strong></p>
  <div class="journey-path"><span class="done">Check-in ✓</span><span class="done">Assessment ✓</span><span class="done">Fit ✓</span><span>Formal Enrollment 🔒</span><span>Journey Activation 🔒</span></div>
 </section>
 <div class="dashboard-grid" dir="ltr" style="text-align:left">
  <div>
   <div class="readiness"><h3>Aviation Readiness Panel</h3><p class="muted">Assessment evidence remains attached to your permanent Aviation Matrix profile.</p>
    <div class="meter"><div style="width:${Math.round(Number(r.current_fit)||0)}%"></div></div>
    <div class="mini-bars">
     ${[['Safety Mindset',d('safety_mindset')],['Communication',d('communication')],['Teamwork / CRM',d('teamwork_crm')],['English Readiness',d('english_readiness')]].map(x=>`<div class="mini-bar"><div class="head"><span>${x[0]}</span><strong>${x[1]}%</strong></div><div class="bar"><span style="width:${x[1]}%"></span></div></div>`).join('')}
    </div>
   </div>
  </div>
  <aside class="card mission">
   <div class="mission-head"><small>NEXT STAGE · FORMAL ENROLLMENT</small><h3>Your Learning Journey Is Locked</h3><p>Your assessment is complete, but training missions do not open until your formal Aviation Matrix file is activated.</p></div>
   <div class="mission-body">
    <span class="pill warn">🔒 ENROLLMENT REQUIRED</span>
    <div class="meta-grid">
     <div class="meta"><label>Candidate Number</label><strong>Issued at formal enrollment</strong></div>
     <div class="meta"><label>Signature</label><strong>${new Date().getFullYear()-new Date(state.date_of_birth||'1900-01-01').getFullYear()<18?'Guardian required':'Candidate signature'}</strong></div>
     <div class="meta"><label>Payment</label><strong>Pending</strong></div>
     <div class="meta"><label>Journey Code</label><strong>Not activated</strong></div>
    </div>
    <button class="btn btn-soft" disabled>START MISSION 🔒</button>
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
  preferred_language:fd.get('preferred_language'),consent:true,source:'landing_pilot'
 };
 const msg=document.getElementById('regMsg');msg.textContent='Registering candidate...';msg.className='helper';
 try{
  const {error}=await supabase.from('aviation_interest_leads').insert([{...payload,status:'new'}]);
  if(error)throw error;
  state={...state,...payload};save();
  document.getElementById('regOverlay')?.remove();render('welcome');
 }catch(e){
  console.error(e);msg.className='helper error';msg.textContent='Supabase registration error: '+(e.message||'Please check database table/RLS.');
 }
}

function attach(){
 document.querySelectorAll('[data-lang]').forEach(b=>b.onclick=()=>setLang(b.dataset.lang));
 document.querySelector('[data-scroll]')?.addEventListener('click',e=>document.getElementById(e.currentTarget.dataset.scroll)?.scrollIntoView());
 const start=document.getElementById('startBtn');if(start)start.onclick=()=>{document.body.insertAdjacentHTML('beforeend',registration());attachModal()};
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
function render(view='landing'){
 clearInterval(questionTimer);
 document.documentElement.lang=lang;document.documentElement.dir=D[lang].dir;
 if(view==='welcome')app.innerHTML=welcome();
 else if(view==='confirm')app.innerHTML=confirmProfile();
 else if(view==='assessment')app.innerHTML=assessmentScreen();
 else if(view==='results')app.innerHTML=results();
 else if(view==='dashboard')app.innerHTML=dashboard();
 else app.innerHTML=landing();
 attach();
 if(view==='assessment') setTimeout(startQuestionTimer,0);
}
render();
