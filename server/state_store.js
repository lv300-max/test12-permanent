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
    version: 1,
    next_app_seq: 1,
    apps_by_id: {},
    queue: [],
    session: null,
    admin_log: []
  };
}

function normalizeState(state) {
  const out = initialState();
  out.version = typeof state.version === "number" ? state.version : 1;
  out.next_app_seq =
    typeof state.next_app_seq === "number" ? state.next_app_seq : 1;
  out.apps_by_id =
    state.apps_by_id && typeof state.apps_by_id === "object"
      ? state.apps_by_id
      : {};
  out.queue = Array.isArray(state.queue) ? state.queue : [];
  out.session = state.session && typeof state.session === "object" ? state.session : null;
  out.admin_log = Array.isArray(state.admin_log) ? state.admin_log : [];
  return out;
}

