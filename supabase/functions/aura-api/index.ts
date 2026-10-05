import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const DEV_TOKEN = Deno.env.get("AURA_LOCAL_DEV_TOKEN") || "";

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false }
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors() });
  }
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  try {
    const authHeader = req.headers.get("authorization") || "";
    const devToken = req.headers.get("x-aura-dev-token") || "";

    let userId: string | null = null;

    if (authHeader.startsWith("Bearer ")) {
      const token = authHeader.slice(7);
      const userClient = createClient(
        SUPABASE_URL,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: `Bearer ${token}` } } }
      );
      const { data } = await userClient.auth.getUser();
      userId = data.user?.id || null;
    }

    // Local development escape hatch.
    // Never use this token as your production security model.
    const localDevAllowed =
      !!DEV_TOKEN && !!devToken && timingSafeEqual(DEV_TOKEN, devToken);

    if (!userId && !localDevAllowed) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json();
    const { operation, familyId, payload } = body;

    if (!familyId) return json({ error: "familyId required" }, 400);

    // Production membership check.
    if (userId && !localDevAllowed) {
      const { data: membership, error: membershipError } = await admin
        .from("family_members")
        .select("id, family_id, user_id, is_active")
        .eq("family_id", familyId)
        .eq("user_id", userId)
        .eq("is_active", true)
        .maybeSingle();

      if (membershipError || !membership) {
        return json({ error: "No active access to family" }, 403);
      }
    }

    let result: unknown;

    switch (operation) {
      case "profile.upsert": {
        const { data, error } = await admin.rpc("aura_profile_upsert", {
          p_id: payload.id || null,
          p_family_id: familyId,
          p_family_member_id: payload.familyMemberId || null,
          p_owner: payload.owner,
          p_name: payload.name,
          p_profile_type: payload.profileType || "standard_adult",
          p_pregnancy_enabled: !!payload.pregnancyEnabled,
          p_postpartum_enabled: !!payload.postpartumEnabled,
          p_status: payload.status || "active",
          p_preferences: payload.preferences || {},
          p_motivation_config: payload.motivationConfig || {},
          p_privacy_config: payload.privacyConfig || {},
        });
        if (error) throw error;
        result = { id: data };
        break;
      }

      case "plan.upsert": {
        const { data, error } = await admin.rpc("aura_plan_upsert", {
          p_id: payload.id || null,
          p_family_id: familyId,
          p_profile_id: payload.profileId,
          p_name: payload.name,
          p_plan_type: payload.planType || "fitness",
          p_goal: payload.goal || null,
          p_start_date: payload.startDate || null,
          p_end_date: payload.endDate || null,
          p_status: payload.status || "active",
          p_nutrition_config: payload.nutritionConfig || {},
          p_motivation_config: payload.motivationConfig || {},
          p_metadata: payload.metadata || {},
        });
        if (error) throw error;
        result = { id: data };
        break;
      }

      case "session.upsert": {
        const { data, error } = await admin.rpc("aura_session_upsert_json", {
          p_family_id: familyId,
          p_profile_id: payload.profileId,
          p_plan_id: payload.planId,
          p_session: payload.session,
          p_sync_nestora: payload.syncNestora !== false,
        });
        if (error) throw error;
        result = { id: data };
        break;
      }

      case "quest.toggle": {
        const { data, error } = await admin.rpc("aura_quest_toggle", {
          p_family_id: familyId, p_profile_id: payload.profileId,
          p_quest_key: payload.questKey, p_title: payload.title,
          p_category: payload.category || "daily", p_xp: payload.xp || 0,
          p_completed: !!payload.completed, p_quest_date: payload.questDate || null,
          p_metadata: payload.metadata || {}
        });
        if (error) throw error; result = data; break;
      }

      case "player.snapshot": {
        const { data, error } = await admin.rpc("aura_player_snapshot", { p_profile_id: payload.profileId });
        if (error) throw error; result = data; break;
      }

      case "api.health": {
        result = { status: "ok", familyId, authenticated: !!userId, devMode: localDevAllowed }; break;
      }

      case "plan.syncCalendar": {
        const { data, error } = await admin.rpc(
          "aura_sync_plan_calendar_to_nestora",
          { p_plan_id: payload.planId }
        );
        if (error) throw error;
        result = { syncedSessions: data };
        break;
      }

      default:
        return json({ error: `Unsupported operation: ${operation}` }, 400);
    }

    return json({ ok: true, result });
  } catch (error) {
    console.error(error);
    return json({ error: error?.message || String(error) }, 500);
  }
});

function cors() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-headers":
      "authorization, x-client-info, apikey, content-type, x-aura-dev-token",
  };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...cors() },
  });
}

function timingSafeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}