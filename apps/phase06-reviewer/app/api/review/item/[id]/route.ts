import { NextResponse } from "next/server";
import { adminSupabase } from "@/lib/supabase";
import { requireReviewer } from "@/lib/auth";

export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireReviewer(req);
  if (!auth.ok) return NextResponse.json({ error: auth.error }, { status: auth.status });

  const { id } = await ctx.params;
  const { data, error } = await adminSupabase().rpc("phase06_get_review_item", {
    p_item_version_id: id
  });

  if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  if (!data) return NextResponse.json({ error: "Item not found." }, { status: 404 });
  return NextResponse.json(data);
}
