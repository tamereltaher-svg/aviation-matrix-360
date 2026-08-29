"use client";
import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";

export default function ReviewItemPage(){
  const params=useParams<{id:string}>(); const router=useRouter();
  const id=params.id;
  const [item,setItem]=useState<any>(null);
  const [gate,setGate]=useState("");
  const [notes,setNotes]=useState("");
  const [message,setMessage]=useState("");
  const [busy,setBusy]=useState(false);

  async function load(){
    try{
      const x=await apiFetch(`/api/review/item/${id}`);
      setItem(x); setGate(x.next_qa_gate || x.gate_matrix?.find((g:any)=>g.pre_pilot_review_gate)?.qa_gate || "");
    }catch(e:any){setMessage(e.message)}
  }
  useEffect(()=>{load()},[id]);

  async function act(actionCode:string){
    if(!gate) return setMessage("Select a QA gate.");
    try{
      setBusy(true); setMessage("");
      const x=await apiFetch("/api/review/submit",{method:"POST",body:JSON.stringify({itemVersionId:id,actionCode,qaGate:gate,notes:notes || null})});
      setItem(x.item); setNotes(""); setMessage("Review action saved.");
    }catch(e:any){setMessage(e.message)}
    finally{setBusy(false)}
  }

  async function nav(direction:"NEXT"|"PREVIOUS"){
    try{
      const n=await apiFetch(`/api/review/neighbor?id=${encodeURIComponent(id)}&direction=${direction}`);
      if(!n.boundary_reached && n.item_version_id) router.push(`/review/${n.item_version_id}`);
    }catch(e:any){setMessage(e.message)}
  }

  if(!item) return <main className="shell"><div className="card">{message || "Loading review item…"}</div></main>;
  const gates=(item.gate_matrix || []).filter((g:any)=>g.pre_pilot_review_gate);

  return <main className="shell">
    <div className="topbar"><div><div className="brand">{item.item_code}</div><div className="subtle">{item.release_code} · {item.cefr_level} · {item.skill_code} · {item.author_difficulty}</div></div><a className="btn" href="/review">Back to Queue</a></div>
    <div className="review-layout">
      <section className="grid">
        {item.stimulus_body && <div className="card"><div className="subtle">{item.stimulus_code} · {item.stimulus_word_count} words</div><h3>{item.stimulus_title}</h3><div className="stimulus">{item.stimulus_body}</div></div>}
        <div className="card"><div className="subtle">{item.domain_code} · {item.construct_code}</div><p className="question">{item.stem_text}</p>{(item.options || []).map((o:any)=><div key={o.option_code} className={"option "+(o.is_correct?"correct":"")}><strong>{o.option_code}</strong><span>{o.option_text}</span>{o.is_correct && <span className="badge good" style={{marginLeft:"auto"}}>Key</span>}</div>)}</div>
        <div className="card"><div className="subtle">Primary Learning Outcome</div><h3>{item.primary_lo_code}</h3><p>{item.primary_lo_statement}</p><span className="badge">{item.primary_lo_mapping_status}</span></div>
        <div className="navrow"><button className="btn" onClick={()=>nav("PREVIOUS")}>← Previous</button><button className="btn" onClick={()=>nav("NEXT")}>Next →</button></div>
      </section>
      <aside className="grid" style={{alignContent:"start"}}>
        <div className="card"><div className="topbar"><strong>Review Progress</strong><span>{item.review_completion_pct}%</span></div><div className="progress"><span style={{width:`${item.review_completion_pct}%`}}/></div><p className="subtle">{item.pre_pilot_gate_passed}/{item.pre_pilot_gate_total} gates passed</p></div>
        <div className="card"><strong>QA Gate</strong><select className="input" value={gate} onChange={e=>setGate(e.target.value)} style={{marginTop:10}}>{gates.map((g:any)=><option key={g.qa_gate} value={g.qa_gate}>{g.qa_gate} — {g.qa_gate_name}</option>)}</select><div style={{marginTop:12}}>{gates.map((g:any)=><div className="gate" key={g.qa_gate}><div><strong>{g.qa_gate}</strong> <span className="badge">{g.gate_status}</span></div><div className="subtle">{g.qa_gate_name}</div>{g.review_notes && <small>{g.review_notes}</small>}</div>)}</div></div>
        <div className="card"><strong>Reviewer Notes</strong><textarea className="input" rows={5} value={notes} onChange={e=>setNotes(e.target.value)} placeholder="Required for changes, revision, rejection or retirement." style={{marginTop:10}}/><div className="actions"><button disabled={busy} className="btn primary" onClick={()=>act("APPROVE")}>Approve</button><button disabled={busy} className="btn" onClick={()=>act("APPROVE_WITH_CHANGES")}>Approve + Changes</button><button disabled={busy} className="btn" onClick={()=>act("NEEDS_REVISION")}>Needs Revision</button><button disabled={busy} className="btn danger" onClick={()=>act("REJECT")}>Reject</button><button disabled={busy} className="btn danger" onClick={()=>act("RETIRE")}>Retire</button></div>{message && <div className={message.includes("saved")?"success":"error"} style={{marginTop:12}}>{message}</div>}</div>
        <div className="card"><strong>Governance</strong><p className="subtle">Source: {item.version_source_state}</p><p className="subtle">Hydration: {item.hydration_tier}</p><p className="subtle">Approval: {item.approval_status}</p><p className="subtle">Lifecycle: {item.lifecycle_status}</p></div>
      </aside>
    </div>
  </main>;
}
