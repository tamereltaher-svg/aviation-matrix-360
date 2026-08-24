
const API='https://vsuekfzyebqnhthyvwpf.supabase.co/functions/v1/platform-reporting-api';
const token=()=>localStorage.getItem('am_staff_token')||'';
async function api(action,extra={}){
  const r=await fetch(API,{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+token()},body:JSON.stringify({action,...extra})});
  const j=await r.json().catch(()=>({}));
  if(!r.ok) throw new Error(j.error||j.detail||('HTTP '+r.status));
  return j;
}
function esc(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))}
function num(v){return v==null?'—':Number(v).toLocaleString(undefined,{maximumFractionDigits:2})}
function fmt(v){if(!v)return '—';try{return new Date(v).toLocaleString()}catch{return v}}
function err(e){const x=document.getElementById('err');if(x){x.style.display='block';x.textContent='Unable to load: '+e.message}}
