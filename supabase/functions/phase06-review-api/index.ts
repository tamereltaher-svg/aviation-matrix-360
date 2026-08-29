import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STAFF_API = `${SUPABASE_URL}/functions/v1/staff-admin-api`;
const ALLOWED_ORIGIN = "https://tamereltaher-svg.github.io";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function cors(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin === ALLOWED_ORIGIN ? origin : ALLOWED_ORIGIN,
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function json(body: unknown, status = 200, origin: string | null = null) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(origin), "Content-Type": "application/json; charset=utf-8" },
  });
}

function txt(value: unknown, max = 2000): string | null {
  if (value === null || value === undefined || value === "") return null;
  return String(value).slice(0, max);
}

async function resolveReviewer(authorization: string) {
  const staffRes = await fetch(STAFF_API, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: authorization },
    body: JSON.stringify({ action: "me" }),
  });

  if (!staffRes.ok) return { ok: false as const, status: 401, error: "STAFF_SESSION_INVALID" };

  const staffPayload = await staffRes.json().catch(() => ({}));
  const staff = staffPayload?.staff ?? staffPayload;
  const email = String(staff?.email ?? "").trim().toLowerCase();
  if (!email) return { ok: false as const, status: 403, error: "STAFF_EMAIL_REQUIRED" };

  let authUserId: string | null = null;
  for (let page = 1; page <= 10 && !authUserId; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 100 });
    if (error) return { ok: false as const, status: 500, error: "AUTH_LOOKUP_FAILED" };
    const match = data.users.find((u) => (u.email ?? "").toLowerCase() === email);
    if (match) authUserId = match.id;
    if (data.users.length < 100) break;
  }

  if (!authUserId) return { ok: false as const, status: 403, error: "REVIEWER_AUTH_USER_NOT_FOUND" };

  const { data: allowed, error: reviewerError } = await admin.rpc("phase06_is_reviewer", {
    p_auth_user_id: authUserId,
    p_cefr_level: null,
    p_skill_code: null,
  });
  if (reviewerError) return { ok: false as const, status: 500, error: "REVIEWER_AUTHORIZATION_CHECK_FAILED" };
  if (!allowed) return { ok: false as const, status: 403, error: "REVIEWER_NOT_AUTHORIZED" };

  return { ok: true as const, reviewerId: authUserId, email };
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    if (origin && origin !== ALLOWED_ORIGIN) return json({ error: "ORIGIN_NOT_ALLOWED" }, 403, origin);
    return new Response(null, { status: 204, headers: cors(origin) });
  }

  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405, origin);
  if (origin && origin !== ALLOWED_ORIGIN) return json({ error: "ORIGIN_NOT_ALLOWED" }, 403, origin);

  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return json({ error: "STAFF_SESSION_REQUIRED" }, 401, origin);

  const reviewer = await resolveReviewer(authorization);
  if (!reviewer.ok) return json({ error: reviewer.error }, reviewer.status, origin);

  const body = await req.json().catch(() => ({}));
  const action = String(body?.action ?? "").toLowerCase();

  try {
    if (action === "progress") {
      const { data, error } = await admin.rpc("phase06_get_review_progress");
      if (error) throw error;
      return json(data, 200, origin);
    }

    if (action === "queue") {
      const level = txt(body?.level, 2);
      const skill = txt(body?.skill, 3);

      if (level || skill) {
        const { data: scoped, error: scopedError } = await admin.rpc("phase06_is_reviewer", {
          p_auth_user_id: reviewer.reviewerId,
          p_cefr_level: level,
          p_skill_code: skill,
        });
        if (scopedError) throw scopedError;
        if (!scoped) return json({ error: "REVIEW_SCOPE_NOT_AUTHORIZED" }, 403, origin);
      }

      const requestedLimit = Number(body?.limit ?? 100);
      const requestedOffset = Number(body?.offset ?? 0);
      const limit = Number.isFinite(requestedLimit) ? Math.min(Math.max(Math.trunc(requestedLimit), 1), 200) : 100;
      const offset = Number.isFinite(requestedOffset) ? Math.max(Math.trunc(requestedOffset), 0) : 0;

      const { data, error } = await admin.rpc("phase06_get_review_queue", {
        p_cefr_level: level,
        p_skill_code: skill,
        p_status: txt(body?.status, 40),
        p_release_code: txt(body?.release, 60),
        p_limit: limit,
        p_offset: offset,
      });
      if (error) throw error;
      return json(data, 200, origin);
    }

    if (action === "item") {
      const itemVersionId = txt(body?.itemVersionId, 80);
      if (!itemVersionId) return json({ error: "ITEM_VERSION_ID_REQUIRED" }, 400, origin);
      const { data, error } = await admin.rpc("phase06_get_review_item", { p_item_version_id: itemVersionId });
      if (error) throw error;
      if (!data) return json({ error: "ITEM_NOT_FOUND" }, 404, origin);
      return json(data, 200, origin);
    }

    if (action === "neighbor") {
      const itemVersionId = txt(body?.itemVersionId, 80);
      if (!itemVersionId) return json({ error: "ITEM_VERSION_ID_REQUIRED" }, 400, origin);
      const direction = String(body?.direction ?? "NEXT").toUpperCase();
      if (!new Set(["NEXT", "PREVIOUS"]).has(direction)) return json({ error: "INVALID_DIRECTION" }, 400, origin);
      const { data, error } = await admin.rpc("phase06_get_review_neighbor", {
        p_item_version_id: itemVersionId,
        p_direction: direction,
        p_status: txt(body?.status, 40),
      });
      if (error) throw error;
      return json(data, 200, origin);
    }

    if (action === "submit") {
      const itemVersionId = txt(body?.itemVersionId, 80);
      const actionCode = String(body?.actionCode ?? "").toUpperCase();
      const qaGate = txt(body?.qaGate, 80);
      const notes = txt(body?.notes, 5000);
      const visibleActions = new Set(["APPROVE", "APPROVE_WITH_CHANGES", "NEEDS_REVISION", "REJECT", "RETIRE"]);
      if (!itemVersionId || !qaGate || !visibleActions.has(actionCode)) return json({ error: "INVALID_REVIEW_SUBMISSION" }, 400, origin);

      const { data, error } = await admin.rpc("phase06_submit_review_action", {
        p_item_version_id: itemVersionId,
        p_action_code: actionCode,
        p_reviewer_id: reviewer.reviewerId,
        p_qa_gate: qaGate,
        p_notes: notes,
      });
      if (error) throw error;
      return json(data, 200, origin);
    }

    return json({ error: "UNKNOWN_ACTION" }, 400, origin);
  } catch (error) {
    console.error("phase06-review-api", error);
    return json({ error: "REVIEW_API_OPERATION_FAILED" }, 500, origin);
  }
});
