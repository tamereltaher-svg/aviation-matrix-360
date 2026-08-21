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

const questions=[
 {dim:'communication',q:'مسافر متضايق وبيتحدث بصوت عالي. أول تصرف ليك؟',opts:[['أسمع المشكلة كاملة وأهدي الموقف',95],['أشرح القواعد مباشرة',76],['أطلب من زميل يتدخل',64],['أطلب منه يهدى قبل أي نقاش',54]]},
 {dim:'teamwork',q:'زميلك متأخر في تنفيذ جزء من مهمة مشتركة، تعمل إيه؟',opts:[['أتأكد من السبب وأساعد في إعادة توزيع العمل',92],['أنفذ الجزء بتاعه من غير ما أتكلم',70],['أبلغ المسؤول فورًا قبل ما أفهم السبب',58],['أسيبه يتحمل النتيجة وحده',40]]},
 {dim:'attention',q:'لاحظت اختلاف صغير بين رقم في النظام والمستند الورقي.',opts:[['أوقف الإجراء وأتحقق من المصدرين',96],['أكمل لأن الفرق صغير',38],['أسأل زميل فقط',66],['أعدل الرقم الأقرب للمنطق',30]]},
 {dim:'judgment',q:'عندك ضغط وقت ومعلومة ناقصة تؤثر على القرار.',opts:[['أحدد المعلومة الحرجة وأصعّد لو لازم',94],['أخمن وأكمل',32],['أنتظر بدون تواصل',54],['أختار أسرع حل متاح',62]]},
 {dim:'customer',q:'عميل طلب حاجة خارج الإجراء المعتاد.',opts:[['أوضح المتاح وأبحث عن بديل مسموح',93],['أرفض مباشرة',55],['أوافق عشان أرضيه',35],['أحوله لشخص آخر فورًا',67]]},
 {dim:'digital',q:'ظهرلك نظام جديد في الشغل لأول مرة.',opts:[['أتعلم الأساسيات وأجرب في بيئة آمنة',90],['أفضل الورق فقط',40],['أستنى حد يعمله مكاني',35],['أستخدمه مباشرة بدون فهم',52]]},
 {dim:'english',q:'لو وصلك Instruction بالإنجليزي وفي مصطلح مش واضح.',opts:[['أتأكد من المصطلح قبل التنفيذ',92],['أعتمد على التخمين',35],['أتجاهل الجزء غير الواضح',28],['أترجم ترجمة سريعة وأنفذ فورًا',66]]},
 {dim:'communication',q:'مطلوب منك توصل معلومة مهمة في وقت قصير.',opts:[['أذكر المعلومة الأساسية والتأثير والخطوة المطلوبة',95],['أحكي كل التفاصيل من البداية',68],['أرسل جملة مختصرة جدًا بدون سياق',50],['أؤجل الرسالة لوقت أهدى',40]]},
 {dim:'teamwork',q:'في اختلاف رأي داخل الفريق على أولوية التنفيذ.',opts:[['نرجع للهدف والإجراء ونحدد الأولوية بوضوح',94],['كل شخص يعمل بطريقته',34],['أمشي رأيي لأنه الأسرع',48],['نوقف كل شيء لحد المدير',60]]},
 {dim:'judgment',q:'أي وصف أقرب لك في مهنة الطيران؟',opts:[['أفضل العمل المنظم والمسؤولية والتعلم المستمر',92],['أهم شيء شكل الوظيفة والسفر',44],['أفضل الوظائف بدون ضغط أو إجراءات',38],['لسه بستكشف ومحتاج أعرف المسارات',78]]}
];

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

function resetAssessment(){
 assessment={index:0,answers:[],scores:{communication:0,teamwork:0,attention:0,judgment:0,customer:0,digital:0,english:0},counts:{communication:0,teamwork:0,attention:0,judgment:0,customer:0,digital:0,english:0}};
}
function assessmentScreen(){
 if(!assessment) resetAssessment();
 const q=questions[assessment.index],pct=Math.round(((assessment.index)/questions.length)*100);
 return flowShell(`<div class="question-meta">PRE-FLIGHT ASSESSMENT · ${assessment.index+1} / ${questions.length}</div>
 <h2>${q.q}</h2><p class="muted">Pick the action closest to your natural response. We measure decision quality, not just right/wrong answers.</p>
 <div class="options">${q.opts.map((o,i)=>`<button class="option" data-opt="${i}"><strong>${String.fromCharCode(65+i)}</strong> — ${o[0]}</button>`).join('')}</div>`,2,35+pct*0.35);
}
function chooseAnswer(i){
 const q=questions[assessment.index],score=q.opts[i][1];
 assessment.answers.push({question:assessment.index,dim:q.dim,option:i,score});
 assessment.scores[q.dim]+=score;assessment.counts[q.dim]+=1;assessment.index++;
 if(assessment.index>=questions.length){finishAssessment()}else render('assessment');
}
function averages(){
 const out={};Object.keys(assessment.scores).forEach(k=>out[k]=assessment.counts[k]?Math.round(assessment.scores[k]/assessment.counts[k]):0);return out;
}
function finishAssessment(){
 const a=averages(),overall=Math.round(Object.values(a).reduce((x,y)=>x+y,0)/Object.values(a).length);
 const cabin=Math.round(a.communication*.18+a.customer*.14+a.teamwork*.14+a.judgment*.18+a.english*.18+a.attention*.12+a.digital*.06);
 const pax=Math.round(a.communication*.20+a.customer*.22+a.teamwork*.15+a.judgment*.15+a.english*.10+a.attention*.10+a.digital*.08);
 const ground=Math.round(a.teamwork*.18+a.judgment*.22+a.attention*.22+a.digital*.16+a.communication*.12+a.english*.10);
 const cargo=Math.round(a.attention*.26+a.judgment*.22+a.digital*.18+a.teamwork*.13+a.communication*.10+a.english*.11);
 const fits=[['Cabin Crew',cabin],['Passenger Services',pax],['Ground Operations',ground],['Cargo',cargo]].sort((x,y)=>y[1]-x[1]);
 state.assessment={averages:a,overall,fits,completed_at:new Date().toISOString(),answers:assessment.answers};save();render('results');
}
function results(){
 const r=state.assessment;if(!r)return render('assessment');
 const best=r.fits[0],future=Math.min(97,best[1]+12);
 return flowShell(`<span class="eyebrow" style="color:#0b5279;border-color:#cfe8f5;background:#effaff">FIT ANALYSIS COMPLETE</span><h1>${t('results')}</h1>
 <div class="result-hero">
  <div class="fit-card"><span class="muted">Current Fit · ${best[0]}</span><b>${best[1]}%</b><p>Your current profile based on the pre-flight assessment.</p></div>
  <div class="fit-card"><span class="muted">Future Fit · ${best[0]}</span><b>${future}%</b><p>Potential after targeted development and mission completion.</p></div>
 </div>
 <h3 style="margin-top:22px">Suggested Aviation Paths</h3><div class="path-list">${r.fits.map((x,i)=>`<div class="path ${i===0?'best':''}"><strong>${i===0?'✈ ':''}${x[0]}</strong><span style="float:${D[lang].dir==='rtl'?'left':'right'}">${x[1]}%</span></div>`).join('')}</div>
 <div class="metric-grid">${Object.entries(r.averages).slice(0,4).map(([k,v])=>`<div class="metric"><span class="muted">${k}</span><b>${v}%</b></div>`).join('')}</div>
 <button id="openJourney" class="btn btn-dark">${t('dashboard')} →</button>`,3,78);
}
function dashboard(){
 const r=state.assessment||{overall:0,fits:[['Exploring',0]],averages:{}},best=r.fits[0]||['Exploring',0],future=Math.min(97,best[1]+12);
 const eng=r.averages.english||0,jud=r.averages.judgment||0,comm=r.averages.communication||0,attention=r.averages.attention||0;
 return flowShell(`<section class="journey-hero"><small style="letter-spacing:.13em;color:#bce9ff;font-weight:900">WELCOME ABOARD · MY AVIATION JOURNEY</small>
 <h1 style="margin:10px 0 8px">${esc(state.full_name||'Candidate')}</h1><p style="color:#d8e9f4;margin:0">Status: Cleared for Foundation Journey · Suggested Path: <strong>${best[0]}</strong></p>
 <div class="journey-path"><span class="done">Check-in ✓</span><span class="done">Assessment ✓</span><span class="done">Fit ✓</span><span>Foundation</span><span>Specialization</span><span>Airline Ready</span></div>
 </section>
 <div class="dashboard-grid">
  <div>
   <div class="readiness"><h3>Aviation Readiness Panel</h3><p class="muted">Overall readiness to start your foundation journey.</p><div class="meter"><div style="width:${future}%"></div></div>
    <div class="mini-bars">
     ${[['Technical English',eng],['Decision Quality',jud],['Communication',comm],['Attention to Detail',attention]].map(x=>`<div class="mini-bar"><div class="head"><span>${x[0]}</span><strong>${x[1]}%</strong></div><div class="bar"><span style="width:${x[1]}%"></span></div></div>`).join('')}
    </div>
   </div>
   <div class="module-list">
    <div class="module"><span class="pill ok">READY NEXT</span><div><strong>Learning Journey</strong><br><small>Foundation missions are ready to open.</small></div><span>→</span></div>
    <div class="module"><span class="pill gray">PARALLEL</span><div><strong>Documents</strong><br><small>Verification can continue while you learn.</small></div><span>→</span></div>
    <div class="module"><span class="pill warn">DEVELOP</span><div><strong>Technical English</strong><br><small>Integrated aviation terminology and communication.</small></div><span>→</span></div>
    <div class="module"><span class="pill ok">COMPLETE</span><div><strong>Pre-Flight Assessment</strong><br><small>Your raw decision events and results are recorded.</small></div><span>✓</span></div>
    <div class="module"><span class="pill gray">FUTURE</span><div><strong>Airline Matching</strong><br><small>Will compare your verified profile against current requirements.</small></div><span>→</span></div>
   </div>
  </div>
  <aside class="card mission">
   <div class="mission-head"><small>NEXT MISSION · FOUNDATION JOURNEY</small><h3>Mission 01 — Why Humans Wanted to Fly</h3><p>Before roles and procedures, start with the human dream, the need to cross distance, and the forces that made flight possible.</p></div>
   <div class="mission-body"><span class="pill ok">● READY FOR DEPARTURE</span>
    <div class="meta-grid"><div class="meta"><label>Estimated Time</label><strong>25 Minutes</strong></div><div class="meta"><label>Level</label><strong>Foundation</strong></div><div class="meta"><label>Type</label><strong>Interactive Mission</strong></div><div class="meta"><label>Outcome</label><strong>Open Mission 02</strong></div></div>
    <button class="btn btn-primary" id="startMission">START MISSION ✈</button><div id="missionMsg" class="helper" style="margin-top:12px"></div>
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
  preferred_language:fd.get('preferred_language'),consent:true,source:'github_pages'
 };
 const msg=document.getElementById('regMsg');msg.textContent='Registering candidate...';msg.className='helper';
 try{
  const {data,error}=await supabase.from('aviation_interest_leads').insert([{...payload,status:'new'}]).select('id').single();
  if(error)throw error;
  state={...state,...payload,candidate_id:data?.id||state.candidate_id};save();
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
 document.getElementById('beginAssessment')?.addEventListener('click',()=>{resetAssessment();render('assessment')});
 document.querySelectorAll('.option').forEach(b=>b.onclick=()=>chooseAnswer(Number(b.dataset.opt)));
 document.getElementById('openJourney')?.addEventListener('click',()=>render('dashboard'));
 document.getElementById('startMission')?.addEventListener('click',missionDemo);
}
function attachModal(){
 document.getElementById('closeModal')?.addEventListener('click',()=>document.getElementById('regOverlay')?.remove());
 document.getElementById('regForm')?.addEventListener('submit',e=>{e.preventDefault();submitRegistration(e.currentTarget)});
}
function render(view='landing'){
 document.documentElement.lang=lang;document.documentElement.dir=D[lang].dir;
 if(view==='welcome')app.innerHTML=welcome();
 else if(view==='confirm')app.innerHTML=confirmProfile();
 else if(view==='assessment')app.innerHTML=assessmentScreen();
 else if(view==='results')app.innerHTML=results();
 else if(view==='dashboard')app.innerHTML=dashboard();
 else app.innerHTML=landing();
 attach();
}
render();
