import { NextResponse } from "next/server";
import { adminSupabase } from "@/lib/supabase";
import { requireReviewer } from "@/lib/auth";

export async function GET(req: Request) {
  const auth = await requireReviewer(req);
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: auth.status });

  const { data, error } = await adminSupabase().rpc("phase06_get_review_progress");
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}
