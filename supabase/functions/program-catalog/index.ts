import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'content-type, apikey, authorization','Access-Control-Allow-Methods':'GET, POST, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json','Cache-Control':'public, max-age=60'}});
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(!['GET','POST'].includes(req.method))return json({error:'METHOD_NOT_ALLOWED'},405);
 try{
  const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error}=await admin.from('am_programs').select('id,code,audience_code,name,short_description,description,base_price,currency,pricing_unit,duration_label,delivery_modes,is_featured,sort_order,cover_image_path,cover_image_alt,card_theme,overlay_strength').eq('is_active',true).order('sort_order').order('name');
  if(error)throw error;
  return json({programs:data||[]});
 }catch(e){console.error(e);return json({error:'SERVER_ERROR'},500)}
});