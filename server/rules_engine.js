const SESSION_LENGTH_MS = 14 * 24 * 60 * 60 * 1000;
const DEFAULT_HEARTBEAT_TTL_MS = 15 * 60 * 1000; // 15 minutes
export const SESSION_APP_COUNT = 13; // each participant tests 12 others

export function reconcile(state, nowMs, opts = {}) {
  const res = {
    changed: false,
    completed_app_ids: [],
    opened_session: false
  };

  const heartbeatTtlMs =
    typeof opts.heartbeatTtlMs === "number" ? opts.heartbeatTtlMs : DEFAULT_HEARTBEAT_TTL_MS;
  markStale(state, nowMs, heartbeatTtlMs);

  const completed = completeExpiredSessions(state, nowMs);
  if (completed.length > 0) {
    res.changed = true;
    res.completed_app_ids = completed;
  }

  const openedCount = openEligibleSessions(state, nowMs);
  if (openedCount > 0) {
    res.changed = true;
    res.opened_session = true;
  }

  return res;
}

function markStale(state, nowMs, ttlMs) {
  if (!ttlMs || ttlMs <= 0) return;
  for (const q of state.queue) {
    if (q.status === "removed") continue;
    const fallback = typeof q.entered_at === "number" ? q.entered_at : 0;
    const last =
      typeof q.last_heartbeat_ms === "number" ? q.last_heartbeat_ms : fallback;
    if (last === 0 || nowMs - last > ttlMs) {
      q.stale = true;
      if (q.status === "waiting") q.eligible = false;
    }
  }
}

function completeExpiredSessions(state, nowMs) {
  const completedAppIds = [];
  const sessions = Array.isArray(state.sessions) ? state.sessions : [];
  const remaining = [];

  for (const s of sessions) {
    if (!s || s.status !== "active") {
      remaining.push(s);
      continue;
    }
    if (typeof s.end_time === "number" && nowMs >= s.end_time) {
      const ids = Array.isArray(s.app_ids) ? s.app_ids : [];

      recordSessionOutcome(state, s, nowMs);

      for (const appId of ids) {
        completedAppIds.push(appId);
        delete state.apps_by_id[appId];
        const idx = state.queue.findIndex((q) => q.app_id === appId);
        if (idx !== -1) state.queue.splice(idx, 1);
      }
      continue;
    }
    remaining.push(s);
  }

  if (remaining.length !== sessions.length) state.sessions = remaining;
  return completedAppIds;
}

function openEligibleSessions(state, nowMs) {
  let opened = 0;

  // Keep opening sessions while enough eligible waiting entries exist.
  while (true) {
    const waiting = state.queue
      .filter((q) => isEligibleWaiting(q))
      .slice()
      .sort((a, b) => {
        if (a.entered_at !== b.entered_at) return a.entered_at - b.entered_at;
        return String(a.app_id).localeCompare(String(b.app_id));
      });

    if (waiting.length < SESSION_APP_COUNT) break;

    const picked = waiting.slice(0, SESSION_APP_COUNT).map((q) => q.app_id);
    const sessionId = nextSessionId(state, nowMs);
    const session = {
      session_id: sessionId,
      start_time: nowMs,
      end_time: nowMs + SESSION_LENGTH_MS,
      status: "active",
      app_ids: picked
    };

    state.sessions = Array.isArray(state.sessions) ? state.sessions : [];
    state.sessions.push(session);

    const pickedSet = new Set(picked);
    for (const q of state.queue) {
      if (q.status === "waiting" && pickedSet.has(q.app_id)) {
        q.status = "in_session";
        q.session_id = sessionId;
      }
    }

    assignSessionTests(state, session, nowMs);

    opened += 1;
  }

  return opened;
}

function isEligibleWaiting(entry) {
  return (
    entry &&
    entry.status === "waiting" &&
    entry.eligible !== false &&
    entry.stale !== true
  );
}

function nextSessionId(state, nowMs) {
  const seq = Number(state.next_session_seq || 1);
  state.next_session_seq = seq + 1;
  return `S${nowMs}-${String(seq).padStart(4, "0")}`;
}

function assignSessionTests(state, session, nowMs) {
  if (!session || !Array.isArray(session.app_ids)) return;
  const sessionAppIds = session.app_ids.slice();
  const sessionId = session.session_id;
  const appIdsSet = new Set(sessionAppIds);

  for (const q of state.queue) {
    if (q.status !== "in_session") continue;
    if (q.session_id !== sessionId) continue;
    if (!appIdsSet.has(q.app_id)) continue;

    q.assigned_tests = sessionAppIds.filter((id) => id !== q.app_id);
    q.tests_required = q.assigned_tests.length;
    q.tests_done = 0;
    q.completed_tests = [];
    q.eligible = false; // "unlocked" once tests_done >= tests_required
    q.stale = false;
    if (typeof q.last_heartbeat_ms !== "number") q.last_heartbeat_ms = nowMs;
  }
}

function recordSessionOutcome(state, session, nowMs) {
  const ids = Array.isArray(session.app_ids) ? session.app_ids : [];
  if (ids.length === 0) return;

  state.user_stats = state.user_stats && typeof state.user_stats === "object" ? state.user_stats : {};

  for (const appId of ids) {
    const q = state.queue.find((entry) => entry && entry.app_id === appId) || null;
    const meta = state.apps_by_id && state.apps_by_id[appId] ? state.apps_by_id[appId] : null;

    const userId = (q && typeof q.user_id === "string" && q.user_id) || (meta && meta.user_id) || null;
    if (!userId) continue;

    const testsRequired = q && typeof q.tests_required === "number" ? q.tests_required : 0;
    const testsDone = q && typeof q.tests_done === "number" ? q.tests_done : 0;
    const completed = testsRequired <= 0 ? true : testsDone >= testsRequired;
    const lastSeenMs =
      q && typeof q.last_heartbeat_ms === "number" ? q.last_heartbeat_ms : nowMs;

    const prev = state.user_stats[userId] && typeof state.user_stats[userId] === "object"
      ? state.user_stats[userId]
      : { user_id: userId, total_sessions: 0, completed_sessions: 0, failed_sessions: 0 };

    const next = { ...prev };
    next.user_id = userId;
    next.total_sessions = Number(next.total_sessions || 0) + 1;
    if (completed) next.completed_sessions = Number(next.completed_sessions || 0) + 1;
    else next.failed_sessions = Number(next.failed_sessions || 0) + 1;
    next.last_session_id = session.session_id;
    next.last_session_completed = completed;
    next.last_seen_ms = lastSeenMs;

    state.user_stats[userId] = next;
  }
}
