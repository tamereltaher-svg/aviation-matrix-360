import { createClient } from "@supabase/supabase-js";

export function publicSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) throw new Error("Missing public Supabase environment variables.");
  return createClient(url, anon);
}

export function adminSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Missing server Supabase environment variables.");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
}
