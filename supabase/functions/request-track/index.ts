import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'content-type, apikey, authorization','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json'}});
const clean=(v:any,m=300)=>String(v??'').trim().slice(0,m);
const enc=new TextEncoder();
function bytesToHex(bytes:Uint8Array){return [...bytes].map(b=>b.toString(16).padStart(2,'0')).join('')}
async function sha256Hex(s:string){return bytesToHex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(s))))}
function clientIp(req:Request){return clean(req.headers.get('cf-connecting-ip')||req.headers.get('x-forwarded-for')?.split(',')[0]||'unknown',120)}
async function rate(admin:any,raw:string,action:string,max:number,windowSeconds:number){const scope=await sha256Hex(`track-v1|${raw}`);const {data,error}=await admin.rpc('am_check_public_api_rate_limit',{p_scope_hash:scope,p_action:action,p_window_seconds:windowSeconds,p_max_requests:max});if(error)throw error;return data}

Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 const len=Number(req.headers.get('content-length')||0);if(len>32768)return json({error:'REQUEST_TOO_LARGE'},413);
 try{
  const body=await req.json();
  const requestNumber=clean(body.request_number,60).toUpperCase();
  const email=clean(body.email,200).toLowerCase();
  const mobile=clean(body.mobile,60).replace(/\s+/g,'');
  const action=clean(body.action||'track',40);
  if(!['track','accept_quotation','reject_quotation'].includes(action))return json({error:'INVALID_ACTION'},400);
  if(!requestNumber||(!email&&!mobile))return json({error:'REQUEST_NUMBER_AND_CONTACT_REQUIRED'},400);

  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const ip=clientIp(req),contact=email||mobile;
  const r1=await rate(admin,ip,'request_track_ip',60,900);if(!r1?.ok)return json({error:'RATE_LIMITED',retry_after_seconds:r1?.retry_after_seconds||60},429);
  const r2=await rate(admin,`${requestNumber}|${contact}`,'request_track_target',20,900);if(!r2?.ok)return json({error:'RATE_LIMITED',retry_after_seconds:r2?.retry_after_seconds||60},429);

  const requestSelect='id,request_number,request_type,audience_code,status,contact_person,email,mobile,learner_count,delivery_mode,estimated_total,currency,created_at,updated_at,institution_id,program_id';
  const {data:r,error}=await admin.from('am_requests').select(requestSelect).eq('request_number',requestNumber).maybeSingle();
  if(error)throw error;
  if(!r)return json({error:'REQUEST_NOT_FOUND'},404);

  const emailMatch=!!email&&String(r.email||'').toLowerCase()===email;
  const mobileMatch=!!mobile&&String(r.mobile||'').replace(/\s+/g,'')===mobile;
  if(!emailMatch&&!mobileMatch)return json({error:'CONTACT_MISMATCH'},403);

  if(action==='accept_quotation'||action==='reject_quotation'){
   const qn=clean(body.quotation_number,80),actionToken=clean(body.action_token,256);
   if(!qn)return json({error:'QUOTATION_NUMBER_REQUIRED'},400);
   if(!actionToken)return json({error:'ACTION_TOKEN_REQUIRED'},401);
   const rm=await rate(admin,`${requestNumber}|${qn}|${await sha256Hex(actionToken)}`,'quotation_action_attempt',10,3600);if(!rm?.ok)return json({error:'RATE_LIMITED',retry_after_seconds:rm?.retry_after_seconds||60},429);
   const {data:q,error:qErr}=await admin.from('am_quotations').select('id,request_id,quotation_number,status').eq('request_id',r.id).eq('quotation_number',qn).maybeSingle();
   if(qErr)throw qErr;
   if(!q||q.status!=='sent')return json({error:'QUOTATION_NOT_AVAILABLE'},409);
   const tokenHash=await sha256Hex(actionToken);
   const {data:result,error:applyErr}=await admin.rpc('am_apply_customer_quotation_action',{p_token_hash:tokenHash,p_request_id:r.id,p_quotation_id:q.id,p_action:action});
   if(applyErr)throw applyErr;
   if(!result?.ok){const code=String(result?.error||'ACTION_NOT_AUTHORIZED');const status=code==='INVALID_ACTION_TOKEN'?403:code==='ACTION_TOKEN_EXPIRED'?410:code==='ACTION_TOKEN_USED'?409:code==='ACTION_TOKEN_REVOKED'?409:code==='QUOTATION_EXPIRED'?410:409;return json({error:code},status)}
  }

  const {data:rr,error:rrErr}=await admin.from('am_requests').select(requestSelect).eq('id',r.id).single();
  if(rrErr)throw rrErr;
  let institutionName:string|null=null,programName:string|null=null;
  if(rr.institution_id){const x=await admin.from('am_institutions').select('name').eq('id',rr.institution_id).maybeSingle();if(x.error)throw x.error;institutionName=x.data?.name||null}
  if(rr.program_id){const x=await admin.from('am_programs').select('name').eq('id',rr.program_id).maybeSingle();if(x.error)throw x.error;programName=x.data?.name||null}

  const [eventsQ,quotesQ]=await Promise.all([
   admin.from('am_request_events').select('event_type,title,detail,to_status,created_at').eq('request_id',r.id).eq('visibility','customer').order('created_at',{ascending:true}),
   admin.from('am_quotations').select('id,quotation_number,version_no,status,currency,total_amount,subtotal,discount_amount,tax_amount,valid_until,terms,notes,sent_at,accepted_at,rejected_at,created_at').eq('request_id',r.id).in('status',['sent','accepted','rejected','expired']).order('version_no',{ascending:false})
  ]);
  if(eventsQ.error)throw eventsQ.error;if(quotesQ.error)throw quotesQ.error;
  const quotes=quotesQ.data||[];let latest:any=null,items:any[]=[];
  if(quotes.length){latest=quotes[0];const it=await admin.from('am_quotation_items').select('item_type,name,description,quantity,unit_price,discount_amount,amount,config,sort_order').eq('quotation_id',latest.id).order('sort_order');if(it.error)throw it.error;items=it.data||[]}
  return json({ok:true,request:{request_number:rr.request_number,request_type:rr.request_type,audience_code:rr.audience_code,status:rr.status,contact_person:rr.contact_person,institution_name:institutionName,program_name:programName,learner_count:rr.learner_count,delivery_mode:rr.delivery_mode,estimated_total:rr.estimated_total,currency:rr.currency,created_at:rr.created_at,updated_at:rr.updated_at},events:eventsQ.data||[],quotation:latest?{...latest,items}:null});
 }catch(e){console.error('request-track',e);return json({error:'SERVER_ERROR'},500)}
});