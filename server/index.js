import express from "express";
import cors from "cors";

import { initialState, loadState, saveState } from "./state_store.js";
import { reconcile } from "./rules_engine.js";

const PORT = Number(process.env.PORT || 8787);
const STATE_PATH = process.env.TEST12_STATE_PATH || "./data/state.json";
const ADMIN_TOKEN = process.env.TEST12_ADMIN_TOKEN || "";

const app = express();
app.use(cors());
app.use(express.json({ limit: "32kb" }));

app.get("/api/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/api/submit", (req, res) => {
  const { user_id, app_name, store_link } = req.body || {};
  const userId = typeof user_id === "string" ? user_id.trim() : "";
  const appName = typeof app_name === "string" ? app_name.trim() : "";
  const storeLink = normalizeLink(typeof store_link === "string" ? store_link : "");

  if (!userId || !appName || !isLinkValid(storeLink)) {
    return res.status(400).json({ ok: false, denied: true });
  }

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  reconcile(state, nowMs);

  const existingAppId = findAppIdByUserId(state, userId);
  let appId = existingAppId;
  let created = false;

  if (!existingAppId) {
    appId = nextAppId(state);
    state.apps_by_id[appId] = {
      app_id: appId,
      user_id: userId,
      app_name: appName,
      store_link: storeLink
    };
    state.queue.push({
      app_id: appId,
      user_id: userId,
      entered_at: nowMs,
      status: "waiting"
    });
    created = true;
  }

  reconcile(state, nowMs);
  saveState(STATE_PATH, state);

  return res.json({
    ok: true,
    created,
    ...buildUserPayload(state, userId, nowMs)
  });
});

app.get("/api/user/:userId", (req, res) => {
  const userId = String(req.params.userId || "").trim();
  if (!userId) return res.status(400).json({ ok: false });

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  const changed = reconcile(state, nowMs);
  if (changed) saveState(STATE_PATH, state);

  return res.json({ ok: true, ...buildUserPayload(state, userId, nowMs) });
});

app.get("/api/admin/state", (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ ok: false });

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  const changed = reconcile(state, nowMs);
  if (changed) saveState(STATE_PATH, state);

  return res.json({
    ok: true,
    now_ms: nowMs,
    apps_by_id: state.apps_by_id,
    queue: state.queue,
    session: state.session,
    admin_log: state.admin_log
  });
});

app.delete("/api/admin/apps/:appId", (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ ok: false });

  const appId = String(req.params.appId || "").trim();
  if (!appId) return res.status(400).json({ ok: false });

  const nowMs = Date.now();
  const state = loadState(STATE_PATH);
  reconcile(state, nowMs);

  const appMeta = state.apps_by_id[appId];
  if (!appMeta) {
    return res.status(404).json({ ok: false });
  }

  if (state.session && state.session.status === "active" && state.session.app_ids.includes(appId)) {
    return res.status(409).json({ ok: false, note: "cannot_remove_active_session_app" });
  }

  const q = state.queue.find((e) => e.app_id === appId);
  if (q) q.status = "removed";
  delete state.apps_by_id[appId];

  state.admin_log.push({
    at: nowMs,
    action: "remove_app",
    details: `app_id=${appId}`
  });

  reconcile(state, nowMs);
  saveState(STATE_PATH, state);
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

function buildUserPayload(state, userId, nowMs) {
  const appId = findAppIdByUserId(state, userId);
  const myApp = appId ? state.apps_by_id[appId] : null;

  const waiting = state.queue
    .filter((q) => q.status === "waiting")
    .slice()
    .sort((a, b) => a.entered_at - b.entered_at);
  const queuePos = appId ? waiting.findIndex((q) => q.app_id === appId) : -1;

  const session = state.session;
  const sessionIds = session && session.status === "active" ? session.app_ids : [];

  const apps = {};
  if (myApp) apps[myApp.app_id] = myApp;
  for (const id of sessionIds) {
    if (state.apps_by_id[id]) apps[id] = state.apps_by_id[id];
  }

  return {
    now_ms: nowMs,
    user_id: userId,
    my_app_id: appId,
    my_app: myApp,
    my_queue_position: queuePos === -1 ? null : queuePos + 1,
    session,
    session_app_ids: sessionIds,
    apps_by_id: apps
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
