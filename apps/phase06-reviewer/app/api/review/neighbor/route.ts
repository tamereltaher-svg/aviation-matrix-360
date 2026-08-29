import { NextResponse } from "next/server";
import { adminSupabase } from "@/lib/supabase";
import { requireReviewer } from "@/lib/auth";

export async function GET(req: Request) {
  const auth = await requireReviewer(req);
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: auth.status });

  const url = new URL(req.url);
  const id = url.searchParams.get("id");
  if (!id) return NextResponse.json({ error: "Missing item id." }, { status: 400 });

  const { data, error } = await adminSupabase().rpc("phase06_get_review_neighbor", {
    p_item_version_id: id,
    p_direction: url.searchParams.get("direction") || "NEXT",
    p_status: url.searchParams.get("status") || null
  });

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  return NextResponse.json(data);
}
