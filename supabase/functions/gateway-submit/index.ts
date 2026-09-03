import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'content-type, apikey, authorization','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
const clean=(v:any,max=500)=>String(v??'').trim().slice(0,max);
const emailOk=(s:string)=>!s||/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
const uuidOk=(s:string)=>/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(s);
const audienceAllowed=new Set(['nursery','school','university','individual','institution','government']);
const publicTypeAllowed=new Set(['program_request','custom_program','product_request','meeting_request','callback_request']);
const itemTypeAllowed=new Set(['program','addon','product','custom']);
const dbTypeMap:Record<string,string>={program_request:'program',custom_program:'custom_program',product_request:'product',meeting_request:'meeting',callback_request:'callback'};
const enc=new TextEncoder();
function bytesToHex(bytes:Uint8Array){return [...bytes].map(b=>b.toString(16).padStart(2,'0')).join('')}
async function sha256Hex(s:string){return bytesToHex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(s))))}
function clientIp(req:Request){return clean(req.headers.get('cf-connecting-ip')||req.headers.get('x-forwarded-for')?.split(',')[0]||'unknown',120)}
async function rate(admin:any,raw:string,action:string,max:number,windowSeconds:number){const scope=await sha256Hex(`gateway-v1|${raw}`);const {data,error}=await admin.rpc('am_check_public_api_rate_limit',{p_scope_hash:scope,p_action:action,p_window_seconds:windowSeconds,p_max_requests:max});if(error)throw error;return data}
function safeJson(v:any,maxBytes=12000){if(v==null||typeof v!=='object')return null;const blocked=new Set(['status','estimated_total','total','subtotal','unit_price','price','amount','currency','quotation_status','accepted','approved','is_admin','role','permission','permissions']);const walk=(x:any,depth=0):any=>{if(depth>4)return null;if(Array.isArray(x))return x.slice(0,50).map(y=>walk(y,depth+1));if(x&&typeof x==='object'){const o:any={};for(const [k,val] of Object.entries(x).slice(0,80)){if(blocked.has(k.toLowerCase()))continue;o[clean(k,80)]=walk(val,depth+1)}return o}if(typeof x==='string')return clean(x,1000);if(typeof x==='number')return Number.isFinite(x)?x:null;if(typeof x==='boolean')return x;return null};const out=walk(v);const s=JSON.stringify(out);return new TextEncoder().encode(s).length<=maxBytes?out:null}
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return json({error:'METHOD_NOT_ALLOWED'},405);
 const len=Number(req.headers.get('content-length')||0);if(len>131072)return json({error:'REQUEST_TOO_LARGE'},413);
 try{
  const body=await req.json();const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const publicRequestType=clean(body.request_type,40),dbRequestType=dbTypeMap[publicRequestType],audience=clean(body.audience_code,40);
  if(!publicTypeAllowed.has(publicRequestType)||!dbRequestType)return json({error:'INVALID_REQUEST_TYPE'},400);if(!audienceAllowed.has(audience))return json({error:'INVALID_AUDIENCE'},400);
  const institutionName=clean(body.institution_name,160),contactPerson=clean(body.contact_person,160),email=clean(body.email,200).toLowerCase(),mobile=clean(body.mobile,60).replace(/\s+/g,''),city=clean(body.city,120),country=clean(body.country||'Egypt',120),notes=clean(body.notes,2000);
  if(!contactPerson&&!email&&!mobile)return json({error:'CONTACT_REQUIRED'},400);if(!emailOk(email))return json({error:'INVALID_EMAIL'},400);
  const ip=clientIp(req),contactKey=(email||mobile||contactPerson.toLowerCase());
  const r1=await rate(admin,ip,'gateway_submit_ip',20,3600);if(!r1?.ok)return json({error:'RATE_LIMITED',retry_after_seconds:r1?.retry_after_seconds||60},429);
  const r2=await rate(admin,`${ip}|${contactKey}`,'gateway_submit_contact',5,3600);if(!r2?.ok)return json({error:'RATE_LIMITED',retry_after_seconds:r2?.retry_after_seconds||60},429);

  let programId:string|null=null,programCurrency:string|null=null;const programName=clean(body.program_name,200);
  if(programName){const p=await admin.from('am_programs').select('id,currency').eq('name',programName).eq('is_active',true).maybeSingle();if(p.data?.id){programId=p.data.id;programCurrency=clean(p.data.currency||'EGP',10)}}

  const inputItems=Array.isArray(body.items)?body.items.slice(0,50):[];const resolved:any[]=[];const currencies=new Set<string>();
  for(const raw of inputItems){
   const itemType=clean(raw?.item_type||'product',40);if(!itemTypeAllowed.has(itemType))return json({error:'INVALID_ITEM_TYPE'},400);
   const qty=Math.max(1,Math.min(100000,Number(raw?.quantity||1)||1));
   const config=safeJson(raw?.config,8000)||{};
   if(itemType==='custom'){
    const name=clean(raw?.name,200);if(!name)return json({error:'CUSTOM_ITEM_NAME_REQUIRED'},400);
    resolved.push({item_type:'custom',ref_id:null,name,quantity:qty,unit_price:0,amount:0,config});continue;
   }
   const refId=clean(raw?.ref_id,80);if(!uuidOk(refId))return json({error:'INVALID_ITEM_REFERENCE'},400);
   let row:any=null;
   if(itemType==='product'){const q=await admin.from('store_products').select('id,name,base_price,currency').eq('id',refId).eq('is_active',true).maybeSingle();row=q.data}
   if(itemType==='program'){const q=await admin.from('am_programs').select('id,name,base_price,currency').eq('id',refId).eq('is_active',true).maybeSingle();row=q.data}
   if(itemType==='addon'){const q=await admin.from('am_program_addons').select('id,name,unit_price,currency').eq('id',refId).eq('is_active',true).maybeSingle();row=q.data}
   if(!row)return json({error:'INVALID_ITEM_REFERENCE'},400);
   const unit=Math.max(0,Number(itemType==='addon'?row.unit_price:row.base_price)||0),cur=clean(row.currency||'EGP',10).toUpperCase();currencies.add(cur);
   resolved.push({item_type:itemType,ref_id:row.id,name:clean(row.name,200),quantity:qty,unit_price:unit,amount:qty*unit,config});
  }
  if(currencies.size>1)return json({error:'MIXED_CURRENCY_ITEMS'},400);
  const currency=[...currencies][0]||programCurrency||'EGP';
  const estimatedTotal=resolved.length?resolved.reduce((s:number,x:any)=>s+Number(x.amount||0),0):null;

  let institutionId:string|null=null;
  if(audience!=='individual'&&institutionName){let found:any=null;if(email){const q=await admin.from('am_institutions').select('id').eq('email',email).eq('name',institutionName).maybeSingle();found=q.data}if(!found&&mobile){const q=await admin.from('am_institutions').select('id').eq('mobile',mobile).eq('name',institutionName).maybeSingle();found=q.data}if(found){institutionId=found.id}else{const ins=await admin.from('am_institutions').insert({institution_type:audience,name:institutionName,contact_person:contactPerson||null,email:email||null,mobile:mobile||null,city:city||null,country,status:'lead',notes:notes||null}).select('id').single();if(ins.error)throw ins.error;institutionId=ins.data.id}}

  const learnerCount=body.learner_count==null||body.learner_count===''?null:Math.max(1,Math.min(100000,Number(body.learner_count)||1)),preferredDate=clean(body.preferred_date,20)||null,preferredTime=clean(body.preferred_time,20)||null,deliveryMode=clean(body.delivery_mode,60)||null,contactMethod=clean(body.preferred_contact_method,60)||null;
  const payload={source:'aviation_gateway',public_request_type:publicRequestType,program_name:programName||null,notes:notes||null,customization:safeJson(body.customization),personalization:safeJson(body.personalization)};
  const rq=await admin.from('am_requests').insert({request_type:dbRequestType,audience_code:audience,institution_id:institutionId,program_id:programId,status:'new',contact_person:contactPerson||null,email:email||null,mobile:mobile||null,learner_count:learnerCount,delivery_mode:deliveryMode,preferred_contact_method:contactMethod,preferred_date:preferredDate,preferred_time:preferredTime,estimated_total:estimatedTotal,currency,payload}).select().single();if(rq.error)throw rq.error;
  if(resolved.length){const rows=resolved.map((x:any)=>({request_id:rq.data.id,item_type:x.item_type,ref_id:x.ref_id,name:x.name,quantity:x.quantity,unit_price:x.unit_price,config:x.config}));const ir=await admin.from('am_request_items').insert(rows);if(ir.error)throw ir.error}
  if(publicRequestType==='meeting_request'||publicRequestType==='callback_request'){let scheduledAt:string|null=null;if(preferredDate&&preferredTime){const d=new Date(`${preferredDate}T${preferredTime}:00`);if(!Number.isNaN(d.getTime()))scheduledAt=d.toISOString()}const mr=await admin.from('am_meetings').insert({request_id:rq.data.id,institution_id:institutionId,meeting_type:publicRequestType==='meeting_request'?'online_meeting':'callback',scheduled_at:scheduledAt,status:'requested',contact_person:contactPerson||null,mobile:mobile||null,email:email||null,notes:notes||null});if(mr.error)throw mr.error}
  await admin.from('am_request_events').insert({request_id:rq.data.id,event_type:'request_received',to_status:'new',title:'Request received',detail:'Your request has been received by Aviation Matrix and is queued for review.',visibility:'customer',actor_type:'customer'});
  await admin.from('am_customer_notifications').insert({request_id:rq.data.id,channel:'portal',recipient:email||mobile||null,template_code:'request_received',subject:'Aviation Matrix request received',payload:{request_number:rq.data.request_number},status:'sent',sent_at:new Date().toISOString()});
  return json({ok:true,request_id:rq.data.id,request_number:rq.data.request_number});
 }catch(e){console.error('gateway-submit',e);return json({error:'SERVER_ERROR'},500)}
});