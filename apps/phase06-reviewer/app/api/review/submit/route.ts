import { NextResponse } from "next/server";
import { adminSupabase } from "@/lib/supabase";
import { requireReviewer } from "@/lib/auth";

export async function POST(req: Request) {
  const auth = await requireReviewer(req);
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: auth.status });
  const body = await req.json();
  if (!body?.itemVersionId || !body?.actionCode || !body?.qaGate) {
    return NextResponse.json({ error: "Missing required review fields." }, { status: 400 });
  }
  const { data, error } = await adminSupabase().rpc("phase06_submit_review_action", {
    p_item_version_id: body.itemVersionId,
    p_action_code: body.actionCode,
    p_reviewer_id: auth.reviewerId,
    p_qa_gate: body.qaGate,
    p_notes: body.notes || null
  });
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}
