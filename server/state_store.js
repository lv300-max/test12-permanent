import fs from "node:fs";
import path from "node:path";

export function loadState(filePath) {
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return initialState();
    return normalizeState(parsed);
  } catch {
    return initialState();
  }
}

export function saveState(filePath, state) {
  const dir = path.dirname(filePath);
  fs.mkdirSync(dir, { recursive: true });
  const tmpPath = `${filePath}.tmp`;
  fs.writeFileSync(tmpPath, JSON.stringify(state, null, 2), "utf8");
  fs.renameSync(tmpPath, filePath);
}

export function initialState() {
  return {
    version: 2,
    next_app_seq: 1,
    next_bundle_seq: 1,
    next_session_seq: 1,
    apps_by_id: {},
    queue: [],
    sessions: [],
    admin_log: [],
    test_log: [],
    prodev_bundles: {},
    user_stats: {}
  };
}

function normalizeState(state) {
  const out = initialState();
  out.version = typeof state.version === "number" ? state.version : out.version;
  out.next_app_seq =
    typeof state.next_app_seq === "number" ? state.next_app_seq : 1;
  out.next_bundle_seq =
    typeof state.next_bundle_seq === "number" ? state.next_bundle_seq : 1;
  out.next_session_seq =
    typeof state.next_session_seq === "number" ? state.next_session_seq : 1;

  const apps =
    state.apps_by_id && typeof state.apps_by_id === "object"
      ? state.apps_by_id
      : {};
  out.apps_by_id = {};
  for (const [id, meta] of Object.entries(apps)) {
    out.apps_by_id[id] = normalizeAppMeta(id, meta);
  }

  out.queue = Array.isArray(state.queue)
    ? state.queue.map((q) => normalizeQueueEntry(q))
    : [];
  out.admin_log = Array.isArray(state.admin_log) ? state.admin_log : [];
  out.test_log = Array.isArray(state.test_log) ? state.test_log : [];

  if (Array.isArray(state.sessions)) {
    out.sessions = state.sessions.map((s) => normalizeSession(s)).filter(Boolean);
  } else if (state.session && typeof state.session === "object") {
    out.sessions = [normalizeSession(state.session)].filter(Boolean);
  } else {
    out.sessions = [];
  }

  // Back-compat: older states used "promoted" and a single "session" object.
  // Ensure in-session queue entries have a session_id when possible.
  const appIdToSessionId = new Map();
  for (const s of out.sessions) {
    if (!s || s.status !== "active") continue;
    for (const appId of s.app_ids) {
      appIdToSessionId.set(appId, s.session_id);
    }
  }
  for (const q of out.queue) {
    if (q.status === "in_session" && !q.session_id) {
      q.session_id = appIdToSessionId.get(q.app_id) || null;
    }
  }

  const bundles =
    state.prodev_bundles && typeof state.prodev_bundles === "object"
      ? state.prodev_bundles
      : {};
  out.prodev_bundles = {};
  for (const [id, bundle] of Object.entries(bundles)) {
    out.prodev_bundles[id] = normalizeBundle(id, bundle);
  }

  const stats =
    state.user_stats && typeof state.user_stats === "object" ? state.user_stats : {};
  out.user_stats = {};
  for (const [userId, s] of Object.entries(stats)) {
    out.user_stats[userId] = normalizeUserStats(userId, s);
  }

  return out;
}

function normalizeAppMeta(id, meta) {
  const base =
    meta && typeof meta === "object"
      ? { ...meta }
      : { app_id: id, user_id: "", app_name: "", store_link: "" };
  base.app_id = base.app_id || id;
  base.is_pro = Boolean(base.is_pro);
  base.bundle_id = typeof base.bundle_id === "string" ? base.bundle_id : null;
  base.drop_seq = typeof base.drop_seq === "number" ? base.drop_seq : null;
  base.drop_total = typeof base.drop_total === "number" ? base.drop_total : null;
  return base;
}

function normalizeQueueEntry(q) {
  const out =
    q && typeof q === "object"
      ? { ...q }
      : { app_id: "", user_id: "", entered_at: Date.now(), status: "waiting" };
  out.status = typeof out.status === "string" ? out.status : "waiting";
  if (out.status === "promoted") out.status = "in_session";
  out.eligible = out.eligible === false ? false : true;
  out.tests_required = typeof out.tests_required === "number" ? out.tests_required : 0;
  out.tests_done = typeof out.tests_done === "number" ? out.tests_done : 0;
  out.assigned_tests = Array.isArray(out.assigned_tests) ? out.assigned_tests : [];
  out.completed_tests = Array.isArray(out.completed_tests) ? out.completed_tests : [];
  out.last_heartbeat_ms =
    typeof out.last_heartbeat_ms === "number" ? out.last_heartbeat_ms : null;
  out.stale = Boolean(out.stale);
  out.is_pro = Boolean(out.is_pro);
  out.bundle_id = typeof out.bundle_id === "string" ? out.bundle_id : null;
  out.drop_seq = typeof out.drop_seq === "number" ? out.drop_seq : null;
  out.drop_total = typeof out.drop_total === "number" ? out.drop_total : null;
  out.session_id = typeof out.session_id === "string" ? out.session_id : null;
  return out;
}

function normalizeBundle(id, bundle) {
  const out =
    bundle && typeof bundle === "object"
      ? { ...bundle }
      : { bundle_id: id, user_id: "", app_name: "", store_link: "" };
  out.bundle_id = out.bundle_id || id;
  out.user_id = typeof out.user_id === "string" ? out.user_id : "";
  out.app_name = typeof out.app_name === "string" ? out.app_name : "";
  out.store_link = typeof out.store_link === "string" ? out.store_link : "";
  out.drops_total = typeof out.drops_total === "number" ? out.drops_total : 0;
  out.drops_completed =
    typeof out.drops_completed === "number" ? out.drops_completed : 0;
  out.active_drop_app_id =
    typeof out.active_drop_app_id === "string" ? out.active_drop_app_id : null;
  out.state = out.state === "done" ? "done" : "active";
  out.created_at = typeof out.created_at === "number" ? out.created_at : Date.now();
  out.metadata = out.metadata && typeof out.metadata === "object" ? out.metadata : {};
  return out;
}

function normalizeSession(session) {
  if (!session || typeof session !== "object") return null;
  const s = { ...session };
  s.session_id = typeof s.session_id === "string" ? s.session_id : "";
  s.start_time = typeof s.start_time === "number" ? s.start_time : 0;
  s.end_time = typeof s.end_time === "number" ? s.end_time : 0;
  s.status = s.status === "complete" ? "complete" : "active";
  s.app_ids = Array.isArray(s.app_ids) ? s.app_ids.filter((x) => typeof x === "string") : [];
  return s.session_id ? s : null;
}

function normalizeUserStats(userId, s) {
  const out = s && typeof s === "object" ? { ...s } : {};
  out.user_id = userId;
  out.total_sessions = typeof out.total_sessions === "number" ? out.total_sessions : 0;
  out.completed_sessions =
    typeof out.completed_sessions === "number" ? out.completed_sessions : 0;
  out.failed_sessions = typeof out.failed_sessions === "number" ? out.failed_sessions : 0;
  out.last_session_id = typeof out.last_session_id === "string" ? out.last_session_id : null;
  out.last_session_completed =
    typeof out.last_session_completed === "boolean" ? out.last_session_completed : null;
  out.last_seen_ms = typeof out.last_seen_ms === "number" ? out.last_seen_ms : null;
  return out;
}
