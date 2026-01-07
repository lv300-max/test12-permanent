import express from "express";
import cors from "cors";

import { initialState, loadState, saveState } from "./state_store.js";
import { reconcile, SESSION_APP_COUNT } from "./rules_engine.js";

const PORT = Number(process.env.PORT || 8787);
const STATE_PATH = process.env.TEST12_STATE_PATH || "./data/state.json";
const ADMIN_TOKEN = process.env.TEST12_ADMIN_TOKEN || "";
const HEARTBEAT_TTL_MS = Number(process.env.TEST12_HEARTBEAT_TTL_MS || 24 * 60 * 60 * 1000); // 24 hours
const MAX_FAILED_SESSIONS = Number(process.env.TEST12_MAX_FAILED_SESSIONS || 3);
const PRODEV_SIZES = new Set([3, 5, 7, 10]);

const app = express();
app.use(cors());
app.use(express.json({ limit: "64kb" }));

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, heartbeat_ttl_ms: HEARTBEAT_TTL_MS });
});

// Submit an app (regular or ProDev drop)
app.post("/api/submit", (req, res) => {
  const { user_id, app_name, store_link, bundle_id } = req.body || {};
  const userId = typeof user_id === "string" ? user_id.trim() : "";
  const appName = typeof app_name === "string" ? app_name.trim() : "";
  const storeLink = normalizeLink(typeof store_link === "string" ? store_link : "");
  const bundleId = typeof bundle_id === "string" ? bundle_id.trim() : "";

  if (!userId || !appName || !isLinkValid(storeLink)) {
    return res.status(400).json({ ok: false, denied: true, note: "invalid_input" });
  }

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  let changed = reconcileAndHandle(state, nowMs);

  let bundle = null;
  if (bundleId) {
    bundle = state.prodev_bundles[bundleId];
    if (!bundle) {
      return res.status(400).json({ ok: false, denied: true, note: "unknown_bundle" });
    }
    if (bundle.state === "done" || bundle.drops_completed >= bundle.drops_total) {
      return res.status(409).json({ ok: false, denied: true, note: "bundle_exhausted" });
    }
  }

  const existingAppId = findAppIdByUserId(state, userId);
  let appId = existingAppId;
  let created = false;

  if (!existingAppId) {
    const stats = state.user_stats && typeof state.user_stats === "object" ? state.user_stats[userId] : null;
    const failed = stats && typeof stats.failed_sessions === "number" ? stats.failed_sessions : 0;
    if (failed >= MAX_FAILED_SESSIONS) {
      return res.status(403).json({ ok: false, denied: true, note: "ineligible" });
    }

    appId = createAppAndQueue(state, {
      userId,
      appName,
      storeLink,
      nowMs,
      bundle
    });
    created = true;
    changed = true;
  }

  changed = reconcileAndHandle(state, nowMs) || changed;
  if (changed) saveState(STATE_PATH, state);

  return res.json({
    ok: true,
    created,
    ...buildUserPayload(state, userId, nowMs)
  });
});

// Keep a slot alive
app.post("/api/heartbeat", (req, res) => {
  const { user_id } = req.body || {};
  const userId = typeof user_id === "string" ? user_id.trim() : "";
  if (!userId) return res.status(400).json({ ok: false, note: "missing_user" });

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  let changed = reconcileAndHandle(state, nowMs);

  const appId = findAppIdByUserId(state, userId);
  if (!appId) return res.status(404).json({ ok: false, note: "no_submission" });

  const q = findQueueEntry(state, appId);
  if (q && (q.status === "waiting" || q.status === "in_session")) {
    q.last_heartbeat_ms = nowMs;
    q.stale = false;
    if (q.status === "waiting") q.eligible = true;
    changed = true;
  }

  changed = reconcileAndHandle(state, nowMs) || changed;
  if (changed) saveState(STATE_PATH, state);
  return res.json({ ok: true, ...buildUserPayload(state, userId, nowMs) });
});

// Record assigned test completion (evidence optional)
app.post("/api/test", (req, res) => {
  const { user_id, target_app_id, evidence_note, evidence_hash } = req.body || {};
  const userId = typeof user_id === "string" ? user_id.trim() : "";
  const targetId = typeof target_app_id === "string" ? target_app_id.trim() : "";
  if (!userId || !targetId) {
    return res.status(400).json({ ok: false, note: "invalid_input" });
  }

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  let changed = reconcileAndHandle(state, nowMs);

  const appId = findAppIdByUserId(state, userId);
  if (!appId) return res.status(404).json({ ok: false, note: "no_submission" });

  const q = findQueueEntry(state, appId);
  const targetMeta = state.apps_by_id[targetId];

  if (!q || q.status !== "in_session") {
    return res.status(409).json({ ok: false, note: "not_in_session" });
  }

  const sessionId = typeof q.session_id === "string" ? q.session_id : null;
  const session =
    sessionId && Array.isArray(state.sessions)
      ? state.sessions.find((s) => s.session_id === sessionId && s.status === "active") || null
      : null;
  if (!session) {
    return res.status(409).json({ ok: false, note: "no_active_session" });
  }
  if (!targetMeta || targetMeta.user_id === userId) {
    return res.status(400).json({ ok: false, note: "invalid_target" });
  }
  if (!Array.isArray(session.app_ids) || !session.app_ids.includes(targetId)) {
    return res.status(400).json({ ok: false, note: "invalid_target" });
  }
  if (!Array.isArray(q.assigned_tests) || !q.assigned_tests.includes(targetId)) {
    return res.status(400).json({ ok: false, note: "not_assigned" });
  }
  if (Array.isArray(q.completed_tests) && q.completed_tests.some((t) => t.target_app_id === targetId)) {
    return res.status(409).json({ ok: false, note: "already_done" });
  }

  const entry = {
    target_app_id: targetId,
    evidence_note: typeof evidence_note === "string" ? evidence_note.slice(0, 1000) : undefined,
    evidence_hash: typeof evidence_hash === "string" ? evidence_hash.slice(0, 256) : undefined,
    at: nowMs
  };

  q.completed_tests = Array.isArray(q.completed_tests) ? q.completed_tests : [];
  q.completed_tests.push(entry);
  q.tests_done = Number(q.tests_done || 0) + 1;
  if (q.tests_done >= (q.tests_required || 0)) q.eligible = true;
  changed = true;

  state.test_log.push({
    ...entry,
    user_id: userId,
    app_id: appId,
    session_id: session.session_id
  });

  changed = reconcileAndHandle(state, nowMs) || changed;
  if (changed) saveState(STATE_PATH, state);
  return res.json({ ok: true, ...buildUserPayload(state, userId, nowMs) });
});

// Create a ProDev bundle (admin/payment hook)
app.post("/api/prodev/bundle", (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ ok: false });
  const { user_id, app_name, store_link, size, receipt_id } = req.body || {};
  const userId = typeof user_id === "string" ? user_id.trim() : "";
  const appName = typeof app_name === "string" ? app_name.trim() : "";
  const storeLink = normalizeLink(typeof store_link === "string" ? store_link : "");
  const bundleSize = Number(size);

  if (!userId || !appName || !isLinkValid(storeLink) || !PRODEV_SIZES.has(bundleSize)) {
    return res.status(400).json({ ok: false, note: "invalid_bundle_input" });
  }

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  let changed = reconcileAndHandle(state, nowMs);

  const bundleId = nextBundleId(state);
  const bundle = {
    bundle_id: bundleId,
    user_id: userId,
    app_name: appName,
    store_link: storeLink,
    drops_total: bundleSize,
    drops_completed: 0,
    active_drop_app_id: null,
    state: "active",
    created_at: nowMs,
    metadata: receipt_id ? { receipt_id } : {}
  };
  state.prodev_bundles[bundleId] = bundle;
  state.admin_log.push({ at: nowMs, action: "create_bundle", details: `bundle_id=${bundleId},size=${bundleSize}` });
  changed = true;

  const scheduled = scheduleNextProDrop(state, bundle, nowMs);
  if (scheduled) changed = true;

  changed = reconcileAndHandle(state, nowMs) || changed;
  if (changed) saveState(STATE_PATH, state);

  return res.json({
    ok: true,
    bundle: {
      ...bundle,
      active_drop_app_id: state.prodev_bundles[bundleId]?.active_drop_app_id || null
    }
  });
});

app.get("/api/user/:userId", (req, res) => {
  const userId = String(req.params.userId || "").trim();
  if (!userId) return res.status(400).json({ ok: false });

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  const changed = reconcileAndHandle(state, nowMs);
  if (changed) saveState(STATE_PATH, state);

  return res.json({ ok: true, ...buildUserPayload(state, userId, nowMs) });
});

app.get("/api/admin/state", (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ ok: false });

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  const changed = reconcileAndHandle(state, nowMs);
  if (changed) saveState(STATE_PATH, state);

  return res.json({
    ok: true,
    now_ms: nowMs,
    apps_by_id: state.apps_by_id,
    queue: state.queue,
    sessions: state.sessions,
    admin_log: state.admin_log,
    prodev_bundles: state.prodev_bundles,
    test_log: state.test_log,
    user_stats: state.user_stats
  });
});

app.delete("/api/admin/apps/:appId", (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ ok: false });

  const appId = String(req.params.appId || "").trim();
  if (!appId) return res.status(400).json({ ok: false });

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  let changed = reconcileAndHandle(state, nowMs);

  const appMeta = state.apps_by_id[appId];
  if (!appMeta) {
    return res.status(404).json({ ok: false });
  }

  if (isAppInAnyActiveSession(state, appId)) {
    return res.status(409).json({ ok: false, note: "cannot_remove_active_session_app" });
  }

  const q = findQueueEntry(state, appId);
  if (q) q.status = "removed";
  delete state.apps_by_id[appId];
  changed = true;

  state.admin_log.push({
    at: nowMs,
    action: "remove_app",
    details: `app_id=${appId}`
  });

  // If it was a ProDev drop, free the slot and schedule the next one
  const proChanged = handleProCompletion(state, [appId], nowMs);
  if (proChanged) changed = true;

  changed = reconcileAndHandle(state, nowMs) || changed;
  if (changed) saveState(STATE_PATH, state);
  return res.json({ ok: true });
});

app.listen(PORT, () => {
  const state = loadState(STATE_PATH);
  if (!state || typeof state !== "object") saveState(STATE_PATH, initialState());
  console.log(`Test12 server listening on :${PORT}`);
});

function isAdmin(req) {
  if (!ADMIN_TOKEN) return false;
  const token = req.get("x-admin-token") || "";
  return token === ADMIN_TOKEN;
}

function findAppIdByUserId(state, userId) {
  for (const [appId, meta] of Object.entries(state.apps_by_id || {})) {
    if (meta && meta.user_id === userId) return appId;
  }
  return null;
}

function findQueueEntry(state, appId) {
  return state.queue.find((q) => q.app_id === appId);
}

function isAppInAnyActiveSession(state, appId) {
  const sessions = Array.isArray(state.sessions) ? state.sessions : [];
  return sessions.some((s) => s && s.status === "active" && Array.isArray(s.app_ids) && s.app_ids.includes(appId));
}

function assignTests(state, appId, nowMs) {
  const q = findQueueEntry(state, appId);
  const meta = state.apps_by_id[appId];
  if (!q || !meta) return;

  // Pre-session eligibility: keep queue entries eligible by default.
  // Session participation requirements are enforced once the user is placed into a session.
  q.assigned_tests = [];
  q.tests_required = 0;
  q.tests_done = 0;
  q.completed_tests = [];
  q.eligible = true;
  q.last_heartbeat_ms = nowMs;

  meta.tests_required = q.tests_required;
  meta.tests_done = q.tests_done;
  meta.assigned_tests = q.assigned_tests;
  meta.eligible = q.eligible;
}

function createAppAndQueue(state, { userId, appName, storeLink, nowMs, bundle }) {
  const appId = nextAppId(state);
  const isPro = Boolean(bundle);
  const dropSeq = bundle ? bundle.drops_completed + 1 : null;
  const dropTotal = bundle ? bundle.drops_total : null;

  state.apps_by_id[appId] = {
    app_id: appId,
    user_id: userId,
    app_name: appName,
    store_link: storeLink,
    is_pro: isPro,
    bundle_id: bundle ? bundle.bundle_id : null,
    drop_seq: dropSeq,
    drop_total: dropTotal
  };
  state.queue.push({
    app_id: appId,
    user_id: userId,
    entered_at: nowMs,
    status: "waiting",
    eligible: false,
    tests_required: 0,
    tests_done: 0,
    assigned_tests: [],
    completed_tests: [],
    last_heartbeat_ms: nowMs,
    stale: false,
    is_pro: isPro,
    bundle_id: bundle ? bundle.bundle_id : null,
    drop_seq: dropSeq,
    drop_total: dropTotal
  });

  assignTests(state, appId, nowMs);
  if (bundle) {
    bundle.active_drop_app_id = appId;
  }
  return appId;
}

function scheduleNextProDrop(state, bundle, nowMs) {
  if (!bundle || bundle.state === "done") return null;
  if (bundle.active_drop_app_id) return null;
  if (bundle.drops_completed >= bundle.drops_total) {
    bundle.state = "done";
    return null;
  }
  const appId = createAppAndQueue(state, {
    userId: bundle.user_id,
    appName: bundle.app_name,
    storeLink: bundle.store_link,
    nowMs,
    bundle
  });
  return appId;
}

function handleProCompletion(state, completedAppIds, nowMs) {
  if (!Array.isArray(completedAppIds) || completedAppIds.length === 0) return false;
  let changed = false;
  const ids = new Set(completedAppIds);

  for (const bundle of Object.values(state.prodev_bundles || {})) {
    if (bundle.active_drop_app_id && ids.has(bundle.active_drop_app_id)) {
      bundle.active_drop_app_id = null;
      bundle.drops_completed = Math.min(
        bundle.drops_total,
        Number(bundle.drops_completed || 0) + 1
      );
      if (bundle.drops_completed >= bundle.drops_total) {
        bundle.state = "done";
      } else {
        const scheduled = scheduleNextProDrop(state, bundle, nowMs);
        if (scheduled) changed = true;
      }
      changed = true;
    }
  }
  return changed;
}

function reconcileAndHandle(state, nowMs) {
  const result = reconcile(state, nowMs, {
    heartbeatTtlMs: HEARTBEAT_TTL_MS
  });
  let changed = result.changed;
  if (result.completed_app_ids.length > 0) {
    const proChanged = handleProCompletion(state, result.completed_app_ids, nowMs);
    changed = changed || proChanged;
  }
  return changed;
}

function buildUserPayload(state, userId, nowMs) {
  const appId = findAppIdByUserId(state, userId);
  const myAppRaw = appId ? state.apps_by_id[appId] : null;
  const myQueue = appId ? findQueueEntry(state, appId) : null;
  const myApp = myAppRaw ? { ...myAppRaw } : null;

  if (myApp && myQueue) {
    myApp.tests_required = myQueue.tests_required || 0;
    myApp.tests_done = myQueue.tests_done || 0;
    myApp.assigned_tests = myQueue.assigned_tests || [];
    myApp.completed_tests = myQueue.completed_tests || [];
    myApp.eligible = myQueue.eligible !== false;
    myApp.last_heartbeat_ms = myQueue.last_heartbeat_ms || null;
    myApp.stale = Boolean(myQueue.stale);
  }

  const waiting = state.queue
    .filter((q) => q.status === "waiting")
    .slice()
    .sort((a, b) => a.entered_at - b.entered_at);
  const queuePos = appId ? waiting.findIndex((q) => q.app_id === appId) : -1;

  const inActiveSession = myQueue && myQueue.status === "in_session";
  const sessionId = inActiveSession ? myQueue.session_id : null;
  const session =
    sessionId && Array.isArray(state.sessions)
      ? state.sessions.find((s) => s.session_id === sessionId && s.status === "active") || null
      : null;

  const forming = !session && appId && myQueue && myQueue.status === "waiting"
    ? buildFormingSession(state, appId)
    : null;

  const sessionObj = session || (forming ? forming.session : null);
  const sessionIds = session ? session.app_ids : (forming ? forming.app_ids : []);

  const apps = {};
  if (myAppRaw) apps[myAppRaw.app_id] = myAppRaw;
  for (const id of sessionIds) {
    if (state.apps_by_id[id]) apps[id] = state.apps_by_id[id];
  }

  const bundle = myApp && myApp.bundle_id ? state.prodev_bundles[myApp.bundle_id] || null : null;

  return {
    now_ms: nowMs,
    user_id: userId,
    my_app_id: appId,
    my_app: myApp,
    my_queue_position: queuePos === -1 ? null : queuePos + 1,
    session: sessionObj,
    session_app_ids: sessionIds,
    apps_by_id: apps,
    prodev_bundle: bundle || undefined
  };
}

function buildFormingSession(state, appId) {
  const eligibleWaiting = state.queue
    .filter(
      (q) =>
        q &&
        q.status === "waiting" &&
        q.eligible !== false &&
        q.stale !== true
    )
    .slice()
    .sort((a, b) => {
      if (a.entered_at !== b.entered_at) return a.entered_at - b.entered_at;
      return String(a.app_id).localeCompare(String(b.app_id));
    });

  const idx = eligibleWaiting.findIndex((q) => q.app_id === appId);
  if (idx === -1) return null;

  const roomIndex = Math.floor(idx / SESSION_APP_COUNT);
  const start = roomIndex * SESSION_APP_COUNT;
  const room = eligibleWaiting.slice(start, start + SESSION_APP_COUNT);
  const ids = room.map((q) => q.app_id);

  return {
    session: {
      session_id: `ROOM-${roomIndex + 1}`,
      status: "forming",
      app_ids: ids,
      required: SESSION_APP_COUNT,
      filled: ids.length,
      needed: Math.max(0, SESSION_APP_COUNT - ids.length),
      position_in_room: idx - start + 1
    },
    app_ids: ids
  };
}

function isLinkValid(url) {
  try {
    const u = new URL(url);
    if (u.protocol === "http:" || u.protocol === "https:") return Boolean(u.hostname);
    if (u.protocol === "try12:") return u.host === "mock" && Boolean(u.pathname) && u.pathname !== "/";
    return false;
  } catch {
    return false;
  }
}

function normalizeLink(url) {
  const trimmed = String(url || "").trim().replace(/\s+/g, "");
  if (!trimmed) return "";
  if (/^try12:\/\//i.test(trimmed)) return trimmed;
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return `https://${trimmed}`;
}

function nextAppId(state) {
  const seq = Number(state.next_app_seq || 1);
  state.next_app_seq = seq + 1;
  return `A${String(seq).padStart(4, "0")}`;
}

function nextBundleId(state) {
  const seq = Number(state.next_bundle_seq || 1);
  state.next_bundle_seq = seq + 1;
  return `PB${String(seq).padStart(4, "0")}`;
}
