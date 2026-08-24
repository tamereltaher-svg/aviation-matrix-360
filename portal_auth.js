
const AM_STAFF_API='https://vsuekfzyebqnhthyvwpf.supabase.co/functions/v1/staff-admin-api';
const AM_TOKEN_KEY='am_staff_token';
function amToken(){return localStorage.getItem(AM_TOKEN_KEY)||''}
async function amStaffCall(action, body={}){
  const headers={'Content-Type':'application/json'};
  const t=amToken(); if(t) headers['Authorization']='Bearer '+t;
  const r=await fetch(AM_STAFF_API,{method:'POST',headers,body:JSON.stringify({action,...body})});
  const j=await r.json().catch(()=>({}));
  if(!r.ok) throw Object.assign(new Error(j.error||j.detail||('HTTP '+r.status)),{status:r.status,body:j});
  return j;
}
async function amRequireSession(){
  if(!amToken()){ location.replace('portal.html'); return false; }
  try{ await amStaffCall('me'); return true; }
  catch(e){ localStorage.removeItem(AM_TOKEN_KEY); location.replace('portal.html'); return false; }
}
async function amLogout(){
  try{ if(amToken()) await amStaffCall('logout'); }catch(e){}
  localStorage.removeItem(AM_TOKEN_KEY);
  location.replace('portal.html');
}
