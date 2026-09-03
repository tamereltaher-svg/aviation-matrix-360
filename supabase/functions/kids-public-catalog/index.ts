import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'GET, OPTIONS'};
const json=(b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...cors,'Content-Type':'application/json','Cache-Control':'public, max-age=60'}});
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='GET')return json({error:'METHOD_NOT_ALLOWED'},405);
 try{
  const url=Deno.env.get('SUPABASE_URL')!,service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const db=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const [contentQ,charsQ,catsQ]=await Promise.all([
   db.from('kids_content_items').select('id,code,title,content_type,category_id,language_code,short_description,description,duration_minutes,cover_image_path,thumbnail_path,access_level,level_id,status,is_featured,sort_order,commercial_mode,base_price,currency,price_unit,allow_direct_purchase,commercial_notes').eq('status','published').in('access_level',['free','public_preview']).order('is_featured',{ascending:false}).order('sort_order').order('title'),
   db.from('kids_characters').select('id,code,name,short_name,role_title,description,personality,values,primary_image_path,profile_image_path,sort_order').eq('is_active',true).order('sort_order').order('name'),
   db.from('kids_content_categories').select('id,code,name,icon,sort_order').eq('is_active',true).order('sort_order')
  ]);
  if(contentQ.error)throw contentQ.error;if(charsQ.error)throw charsQ.error;if(catsQ.error)throw catsQ.error;
  const items=contentQ.data||[],ids=items.map((x:any)=>x.id);
  let assets:any[]=[],ages:any[]=[],characterLinks:any[]=[],programLinks:any[]=[],productLinks:any[]=[];
  if(ids.length){
   const [a,ag,ch,pr,pl]=await Promise.all([
    db.from('kids_content_assets').select('id,content_item_id,asset_type,storage_path,file_name,mime_type,language_code,is_primary,is_downloadable,sort_order,storage_bucket,is_protected').in('content_item_id',ids).eq('is_protected',false).or('storage_bucket.is.null,storage_bucket.eq.kids-assets').order('sort_order'),
    db.from('kids_content_age_groups').select('content_item_id,age_group_id,kids_age_groups(code,label,min_age,max_age,sort_order)').in('content_item_id',ids),
    db.from('kids_content_characters').select('content_item_id,character_id,role_code,kids_characters(code,name,role_title)').in('content_item_id',ids),
    db.from('program_content_items').select('content_item_id,program_id,sequence_no,is_required,learner_visibility,am_programs(code,name,audience_code,base_price,currency,pricing_unit,is_active)').in('content_item_id',ids),
    db.from('kids_product_links').select('content_item_id,program_id,product_id,link_type,store_products(id,sku,slug,name,short_description,base_price,currency,is_active)').in('content_item_id',ids)
   ]);
   if(a.error)throw a.error;if(ag.error)throw ag.error;if(ch.error)throw ch.error;if(pr.error)throw pr.error;if(pl.error)throw pl.error;
   assets=a.data||[];ages=ag.data||[];characterLinks=ch.data||[];programLinks=(pr.data||[]).filter((x:any)=>x.am_programs?.is_active!==false);productLinks=(pl.data||[]).filter((x:any)=>x.store_products?.is_active!==false);
  }
  return json({ok:true,items,characters:charsQ.data||[],categories:catsQ.data||[],relations:{assets,age_groups:ages,characters:characterLinks,programs:programLinks,products:productLinks}});
 }catch(e){console.error('kids-public-catalog',e);return json({error:'SERVER_ERROR'},500)}
});