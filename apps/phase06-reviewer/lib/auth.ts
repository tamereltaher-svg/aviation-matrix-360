import { adminSupabase } from "./supabase";

export async function requireReviewer(req: Request) {
  const header = req.headers.get("authorization") || "";
  if (!header.startsWith("Bearer ")) {
    return { ok: false as const, status: 401, error: "Missing access token." };
  }

  const token = header.slice(7);
  const admin = adminSupabase();
  const { data, error } = await admin.auth.getUser(token);

  if (error || !data.user) {
    return { ok: false as const, status: 401, error: "Invalid session." };
  }

  const { data: allowed, error: reviewerError } = await admin.rpc(
    "phase06_is_reviewer",
    {
      p_auth_user_id: data.user.id,
      p_cefr_level: null,
      p_skill_code: null
    }
  );

  if (reviewerError) {
    return { ok: false as const, status: 500, error: reviewerError.message };
  }

  if (!allowed) {
    return { ok: false as const, status: 403, error: "User is not an authorized Phase 06 reviewer." };
  }

  return { ok: true as const, reviewerId: data.user.id, user: data.user };
}
