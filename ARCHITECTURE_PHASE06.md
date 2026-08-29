# Phase 06 Deployment Architecture

Frontend: GitHub Pages (`portal.html` → `learning_hub.html` → `english_assessment_hub.html` → `phase06_review.html`).

Backend: Supabase Database, Auth, RPCs and `phase06-review-api` Edge Function.

No Vercel. No browser service-role key. No GitHub-to-Supabase deployment credential is required by this architecture.
