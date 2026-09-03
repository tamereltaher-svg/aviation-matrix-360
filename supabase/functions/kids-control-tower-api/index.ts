import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, content-type, apikey','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json'}});
const enc=new TextEncoder();
function hex(bytes:Uint8Array){return [...bytes].map(b=>b.toString(16).padStart(2,'0')).join('')}
async function sha(s:string){return hex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(s))))}
const clean=(v:any,n=100)=>String(v??'').trim().slice(0,n);
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 const sb=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 try{
  const a=req.headers.get('authorization')||'',t=a.startsWith('Bearer ')?a.slice(7).trim():''; if(!t)return json({error:'UNAUTHORIZED'},401);
  const h=await sha(t); const {data:s}=await sb.from('staff_sessions').select('id,user_id,expires_at,revoked_at').eq('token_hash',h).maybeSingle();
  if(!s||s.revoked_at||new Date(s.expires_at).getTime()<=Date.now())return json({error:'SESSION_EXPIRED'},401);
  const {data:staff}=await sb.from('staff_accounts').select('user_id,is_active').eq('user_id',s.user_id).maybeSingle(); if(!staff?.is_active)return json({error:'FORBIDDEN'},403);
  const {data:p}=await sb.from('staff_permissions').select('permission_code').eq('user_id',s.user_id).eq('permission_code','kids.manage').eq('is_allowed',true).maybeSingle(); if(!p)return json({error:'FORBIDDEN'},403);
  await sb.from('staff_sessions').update({last_seen_at:new Date().toISOString()}).eq('id',s.id);
  const body=await req.json(); const action=clean(body.action,50);
  if(action==='dashboard'||action==='run_health'){
   if(action==='run_health'){const r=await sb.rpc('kids_run_health_check');if(r.error)throw r.error}
   const [exec,levels,exp,commercial,health,alerts,checks,rules]=await Promise.all([
    sb.from('kids_executive_dashboard').select('*').single(),sb.from('kids_level_analytics').select('*').order('code'),sb.from('kids_experience_analytics').select('*').single(),sb.from('kids_commercial_analytics').select('*').single(),sb.from('kids_health_snapshots').select('*').order('snapshot_at',{ascending:false}).limit(1).maybeSingle(),sb.from('kids_system_alerts').select('*').eq('status','open').order('severity').order('last_seen_at',{ascending:false}),sb.from('kids_launch_checks').select('id,code,category,title,requirement,hard_block,sort_order').order('sort_order'),sb.from('kids_automation_rules').select('*').eq('is_active',true).order('sort_order')]);
   const checkIds=(checks.data||[]).map((x:any)=>x.id); let latest:any[]=[];
   if(checkIds.length){const rr=await sb.from('kids_launch_check_results').select('*').in('launch_check_id',checkIds).order('checked_at',{ascending:false}); const seen=new Set(); for(const x of rr.data||[]){if(!seen.has(x.launch_check_id)){seen.add(x.launch_check_id);latest.push(x)}}}
   const by=Object.fromEntries(latest.map((x:any)=>[x.launch_check_id,x]));
   return json({executive:exec.data||{},levels:levels.data||[],experience:exp.data||{},commercial:commercial.data||{},health:health.data||null,alerts:alerts.data||[],checks:(checks.data||[]).map((x:any)=>({...x,result:by[x.id]||null})),automation_rules:rules.data||[]});
  }
  if(action==='resolve_alert'){const key=clean(body.alert_key,120);if(!key)return json({error:'KEY_REQUIRED'},400);const r=await sb.from('kids_system_alerts').update({status:'resolved',resolved_at:new Date().toISOString(),last_seen_at:new Date().toISOString()}).eq('alert_key',key);if(r.error)throw r.error;return json({ok:true})}
  return json({error:'INVALID_ACTION'},400);
 }catch(e){console.error(e);return json({error:'SERVER_ERROR',detail:String((e as any)?.message||e)},500)}
});