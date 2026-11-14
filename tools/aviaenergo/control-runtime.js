/* AVIAENERGO local-only presentation controls. NOT authentication or server enforcement. */
(function(){"use strict";
const KEY="aviaenergo.local.presentation.v1", HISTORY="aviaenergo.local.presentation.history.v1";
const pages=[
["tree","AIP Foundation Tree","Knowledge"],
["service","Find a Service","Airport Intelligence"],
["matrix","Airport Capability Matrix","Airport Intelligence"],
["request","Flight Request Check","Airport Intelligence"],
["company","Company Readiness","Airport Intelligence"],
["sup","Supplements & Restrictions","Sources & Evidence"],
["library","AIP Source Library","Sources & Evidence"],
["dictionary","Operational Dictionary","Knowledge"],
["accuracy","Evidence Verification","Sources & Evidence"],
["control","Source Control Tower","Sources & Evidence"],
["brief","Service Evidence Brief","Sources & Evidence"],
["route","ENR Route Explorer","Airspace & Routes"],
["gateway","Egypt FIR Gateways","Airspace & Routes"],
["trace","Point-to-Airway Trace","Airspace & Routes"],
["cross","Cross-Border FIR Trace","Airspace & Routes"]];
const visuals=[
["brand","AVIAENERGO wordmark","Branding"],
["subtitle","Header supporting text","Branding"],
["chip","Header staff portal label","Branding"],
["intro","Overview introduction","Overview"],
["kpis","Overview statistics","Overview"],
["kpi_airports","Airports statistic","Overview"],
["kpi_services","Services statistic","Overview"],
["kpi_dictionary","Dictionary statistic","Overview"],
["kpi_supplements","Supplements statistic","Overview"],
["sectiontitle","Module heading and hint","Overview"],
["footer","Footer description","Branding"]];
const protectedItems=[
["safety","Operational safety / disclaimer","AIP and safety warnings must always remain visible."],
["source","Official AIP source and review status","The original evidence or review state cannot be changed by this tool."],
["auth","Actual authorizations and user roles","Hiding content cannot grant or revoke privileges."],
["operations","Flight validity, permissions and NOTAM","Presentation controls never confirm a flight or service."],
["control","Local control entry and restore path","The editing tool must remain independently accessible."]];
function defaults(){return {schema:1,pages:Object.fromEntries(pages.map(p=>[p[0],"visible"])),visuals:Object.fromEntries(visuals.map(v=>[v[0],true])),copy:{title:"One system. From ICAO rules to airport service decisions.",description:"Explore the AIP foundations, airport facilities, passenger and aircraft services, restrictions, official references and a plain-English operational dictionary — in one place."}};}
function valid(x){const d=defaults();if(!x||typeof x!=="object"||Array.isArray(x)||x.schema!==1)return false;
 if(!x.pages||!x.visuals||!x.copy)return false;
 if(Object.keys(x.pages).sort().join("|")!==Object.keys(d.pages).sort().join("|"))return false;
 if(Object.keys(x.visuals).sort().join("|")!==Object.keys(d.visuals).sort().join("|"))return false;
 if(Object.keys(x.copy).sort().join("|")!==Object.keys(d.copy).sort().join("|"))return false;
 if(!Object.values(x.pages).every(v=>["visible","unlisted","paused"].includes(v)))return false;
 if(!Object.values(x.visuals).every(v=>typeof v==="boolean"))return false;
 return Object.values(x.copy).every(v=>typeof v==="string"&&v.length<=220&&v.trim().length>0&&v.indexOf("<")<0&&v.indexOf(">")<0);
}
function getRecord(){try{const x=JSON.parse(localStorage.getItem(KEY));if(x&&valid(x.settings)&&Number.isSafeInteger(x.revision)&&x.revision>=0)return x;}catch(e){}return {revision:0,settings:defaults(),updatedAt:null};}
function history(){try{const x=JSON.parse(localStorage.getItem(HISTORY));return Array.isArray(x)?x.filter(v=>v&&valid(v.settings)&&Number.isSafeInteger(v.revision)).slice(-20):[];}catch(e){return [];}}
function publish(settings,expected){if(!valid(settings))throw Error("INVALID_SETTINGS");
 const old=getRecord();if(old.revision!==expected)throw Error("VERSION_CONFLICT");
 const next={revision:old.revision+1,updatedAt:new Date().toISOString(),settings:structuredClone(settings)};
 const hist=[...history(),old].slice(-20);
 try{localStorage.setItem(HISTORY,JSON.stringify(hist));localStorage.setItem(KEY,JSON.stringify(next));}
 catch(e){throw Error("STORAGE_UNAVAILABLE");}
 window.dispatchEvent(new Event("avia-control-published"));return next;
}
function title(id){return pages.find(x=>x[0]===id)?.[1]||id;}
function setHidden(node,hide){if(node)node.hidden=!!hide;}
function apply(settings){if(!valid(settings)||!document.querySelector(".navinner"))return;
 const status=k=>settings.pages[k]||"visible";
 document.querySelectorAll("[data-open]").forEach(n=>setHidden(n,status(n.dataset.open)!=="visible"));
 const firstIntel=["service","matrix","request","company","sup","library","dictionary","accuracy","control","brief"].find(k=>status(k)==="visible");
 document.querySelectorAll(".navbtn").forEach(n=>{let k=n.dataset.tab;if(k==="intelligence")k=firstIntel||"service";
   setHidden(n,n.dataset.tab!=="home"&&(n.dataset.tab==="intelligence"?!firstIntel:status(k)!=="visible"));});
 const check=(selector,key)=>setHidden(document.querySelector(selector),!settings.visuals[key]);
 check(".brand b","brand");check(".brand small","subtitle");check(".chip","chip");check(".intro","intro");check(".kpi","kpis");check(".sectiontitle","sectiontitle");check("main footer","footer");
 const stats=document.querySelectorAll(".kpi > div");["kpi_airports","kpi_services","kpi_dictionary","kpi_supplements"].forEach((k,i)=>setHidden(stats[i],!settings.visuals[k]));
 const h=document.querySelector(".intro h1"),p=document.querySelector(".intro p");
 if(h)h.textContent=settings.copy.title;if(p)p.textContent=settings.copy.description;
 // Safety notice and source warnings are not configurable.
}
let previewSettings=null;
function active(){return previewSettings||getRecord().settings;}
function pageStatus(id){return active().pages[id]||"visible";}
if(typeof window!=="undefined"){
window.AviaControl=Object.freeze({KEY,pages,visuals,protectedItems,defaults,valid,getRecord,history,publish,apply,active,pageStatus,title});
 if(document.querySelector(".navinner")){
  const refresh=()=>apply(active());
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",refresh);else refresh();
  window.addEventListener("storage",e=>{if(e.key===KEY)refresh();});
  window.addEventListener("avia-control-published",refresh);
  window.addEventListener("message",e=>{
   if(e.origin!==location.origin||!new URLSearchParams(location.search).has("design_preview"))return;
   if(e.data?.type!=="AVIA_LOCAL_DRAFT")return;
   if(!valid(e.data.settings))return;
   previewSettings=structuredClone(e.data.settings);refresh();
  });
 }
}
})();