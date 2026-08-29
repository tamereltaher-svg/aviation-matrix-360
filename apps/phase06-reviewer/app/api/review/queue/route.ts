import { NextResponse } from "next/server";
import { adminSupabase } from "@/lib/supabase";
import { requireReviewer } from "@/lib/auth";

export async function GET(req: Request) {
  const auth = await requireReviewer(req);
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: auth.status });

  const url = new URL(req.url);
  const { data, error } = await adminSupabase().rpc("phase06_get_review_queue", {
    p_cefr_level: url.searchParams.get("level") || null,
    p_skill_code: url.searchParams.get("skill") || null,
    p_status: url.searchParams.get("status") || null,
    p_release_code: url.searchParams.get("release") || null,
    p_limit: Number(url.searchParams.get("limit") || 50),
    p_offset: Number(url.searchParams.get("offset") || 0)
  });

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}
