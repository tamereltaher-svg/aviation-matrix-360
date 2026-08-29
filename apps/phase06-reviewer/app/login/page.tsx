"use client";
import { FormEvent, useState } from "react";
import { publicSupabase } from "@/lib/supabase";

export default function LoginPage() {
  const [email,setEmail]=useState("");
  const [password,setPassword]=useState("");
  const [message,setMessage]=useState("");

  async function submit(e:FormEvent){
    e.preventDefault();
    setMessage("Signing in...");
    const {data,error}=await publicSupabase().auth.signInWithPassword({email,password});
    if(error || !data.session){ setMessage(error?.message || "Sign in failed."); return; }
    localStorage.setItem("phase06_access_token",data.session.access_token);
    window.location.href="/review";
  }

  return <main className="shell" style={{maxWidth:520}}>
    <div className="card" style={{marginTop:80}}>
      <div className="brand">Phase 06 Reviewer</div>
      <p className="subtle">Authorized reviewers only.</p>
      <form onSubmit={submit} className="grid">
        <input className="input" type="email" placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)} required/>
        <input className="input" type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)} required/>
        <button className="btn primary">Sign in</button>
      </form>
      {message && <p className="subtle">{message}</p>}
    </div>
  </main>;
}
