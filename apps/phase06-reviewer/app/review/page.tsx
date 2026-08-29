"use client";
import { useEffect, useState } from "react";
import { apiFetch } from "@/lib/api";

type QueueRow = any;

export default function ReviewQueuePage(){
  const [progress,setProgress]=useState<any>(null);
  const [rows,setRows]=useState<QueueRow[]>([]);
  const [total,setTotal]=useState(0);
  const [loading,setLoading]=useState(true);
  const [error,setError]=useState("");
  const [filters,setFilters]=useState({level:"",skill:"",status:"NOT_STARTED",release:""});

  async function load(){
    try{
      setLoading(true); setError("");
      const qs=new URLSearchParams();
      Object.entries(filters).forEach(([k,v])=>{ if(v) qs.set(k,v); });
      qs.set("limit","100");
      const [p,q]=await Promise.all([
        apiFetch("/api/review/progress"),
        apiFetch("/api/review/queue?"+qs.toString())
      ]);
      setProgress(p); setRows(q.rows || []); setTotal(q.total || 0);
    }catch(e:any){setError(e.message)}
    finally{setLoading(false)}
  }

  useEffect(()=>{load()},[filters.level,filters.skill,filters.status,filters.release]);
  const o=progress?.overall || {};

  return <main className="shell">
    <div className="topbar">
      <div><div className="brand">Phase 06 Human Review</div><div className="subtle">Reading & Language Use · 1536 Items</div></div>
      <a className="btn" href="/login">Reviewer Login</a>
    </div>

    <div className="grid stats">
      <div className="card stat"><span className="subtle">Total</span><strong>{o.total_items ?? "—"}</strong></div>
      <div className="card stat"><span className="subtle">Not Started</span><strong>{o.not_started ?? "—"}</strong></div>
      <div className="card stat"><span className="subtle">In Review</span><strong>{o.in_review ?? "—"}</strong></div>
      <div className="card stat"><span className="subtle">Complete</span><strong>{o.review_complete ?? "—"}</strong></div>
    </div>

    <div className="filters">
      <select className="input" value={filters.level} onChange={e=>setFilters({...filters,level:e.target.value})}>
        <option value="">All Levels</option>{["A1","A2","B1","B2","C1","C2"].map(x=><option key={x}>{x}</option>)}
      </select>
      <select className="input" value={filters.skill} onChange={e=>setFilters({...filters,skill:e.target.value})}>
        <option value="">All Skills</option><option>LNG</option><option>RDG</option>
      </select>
      <select className="input" value={filters.status} onChange={e=>setFilters({...filters,status:e.target.value})}>
        <option value="">All Statuses</option>{["NOT_STARTED","IN_REVIEW","ACTION_REQUIRED","REJECTED","COMPLETE_WITH_EDIT","COMPLETE"].map(x=><option key={x}>{x}</option>)}
      </select>
      <input className="input" placeholder="Release e.g. ENG-P06-R01" value={filters.release} onChange={e=>setFilters({...filters,release:e.target.value})}/>
      <button className="btn" onClick={load}>Refresh</button>
    </div>

    {error && <div className="error">{error}</div>}
    <div className="card">
      <div className="topbar"><strong>Review Queue</strong><span className="subtle">{loading?"Loading…":`${total} items`}</span></div>
      <div style={{overflowX:"auto"}}>
        <table className="table">
          <thead><tr><th>Item</th><th>Level</th><th>Skill</th><th>Status</th><th>Progress</th><th>Next Gate</th><th></th></tr></thead>
          <tbody>{rows.map(r=><tr key={r.item_version_id}>
            <td><strong>{r.item_code}</strong><div className="subtle">{r.release_code}</div></td>
            <td>{r.cefr_level}</td><td>{r.skill_code}</td>
            <td><span className={"badge "+(r.pre_pilot_review_status==="ACTION_REQUIRED"?"bad":r.pre_pilot_review_status==="COMPLETE"?"good":"")}>{r.pre_pilot_review_status}</span></td>
            <td style={{minWidth:150}}><div className="progress"><span style={{width:`${r.review_completion_pct}%`}}/></div><small>{r.review_completion_pct}%</small></td>
            <td>{r.next_qa_gate || "—"}</td>
            <td><a className="btn" href={`/review/${r.item_version_id}`}>Open</a></td>
          </tr>)}</tbody>
        </table>
      </div>
    </div>
  </main>;
}
