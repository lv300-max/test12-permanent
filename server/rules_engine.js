const SESSION_LENGTH_MS = 14 * 24 * 60 * 60 * 1000;

export function reconcile(state, nowMs) {
  let changed = false;

  if (state.session && state.session.status === "active") {
    if (nowMs >= state.session.end_time) {
      const completedIds = Array.isArray(state.session.app_ids)
        ? state.session.app_ids.slice()
        : [];

      for (const appId of completedIds) {
        delete state.apps_by_id[appId];
        const idx = state.queue.findIndex((q) => q.app_id === appId);
        if (idx !== -1) state.queue.splice(idx, 1);
      }
      state.session = null;
      changed = true;
    }
  }

  if (!state.session) {
    const opened = tryOpenSession(state, nowMs);
    if (opened) changed = true;
  }

  return changed;
}

function tryOpenSession(state, nowMs) {
  const waiting = state.queue.filter((q) => q.status === "waiting");
  if (waiting.length < 12) return false;

  waiting.sort((a, b) => {
    if (a.entered_at !== b.entered_at) return a.entered_at - b.entered_at;
    return String(a.app_id).localeCompare(String(b.app_id));
  });

  const picked = waiting.slice(0, 12).map((q) => q.app_id);

  for (const q of state.queue) {
    if (picked.includes(q.app_id) && q.status === "waiting") {
      q.status = "promoted";
    }
  }

  state.session = {
    session_id: `S${nowMs}`,
    start_time: nowMs,
    end_time: nowMs + SESSION_LENGTH_MS,
    status: "active",
    app_ids: picked
  };
  return true;
}

