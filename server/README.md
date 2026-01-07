# Test 12 Server (site submits → app reads)

This is a minimal HTTP API that persists **queue + session** state in a JSON file and enforces the Rule12 rules:

- Queue is chronological; immutable except removal.
- A session opens when **13 eligible waiting apps** exist; each session lasts **14 days**.
- Multiple sessions can be active at once (new sessions open as the queue fills).
- Sessions auto-complete at `end_time`; completed apps exit cleanly.
- Apps are **metadata + store link only**.
- Participation required: each session participant completes **12 tests** (the other apps in their 13‑app session). Heartbeats keep entries eligible; stale entries are skipped.
- ProDev bundles (3/5/7/10 drops): admin can create paid “drops” that auto-queue sequentially.

## Run

```bash
cd server
npm install
TEST12_ADMIN_TOKEN=change-me npm run dev
```

Server listens on `PORT` (default `8787`).
State persists to `TEST12_STATE_PATH` (default `./data/state.json`).

Config knobs (env):
- `TEST12_HEARTBEAT_TTL_MS` (default: 15m) — if no heartbeat since this window, waiting entry is marked stale/ineligible.
- `TEST12_MAX_FAILED_SESSIONS` (default: 3) — deny new submissions after this many failed sessions.

## API

### Submit from your site

`POST /api/submit`

Body:

```json
{ "user_id": "u123", "app_name": "My App", "store_link": "https://play.google.com/...", "bundle_id": "optional-prodev-bundle-id" }
```

Returns the user’s current position, plus the user’s active session (if any).

Example (browser JS):

```js
await fetch("https://your-domain.com/api/submit", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    user_id: "u123",
    app_name: "My App",
    store_link: "https://play.google.com/store/apps/details?id=com.example"
  })
});
```

### Heartbeat (keep slot alive)

`POST /api/heartbeat`

Body: `{ "user_id": "u123" }`

### Submit assigned test evidence

`POST /api/test`

Body: `{ "user_id": "u123", "target_app_id": "A0007", "evidence_hash": "...", "evidence_note": "optional" }`

Marks one assigned test complete for the user’s active session; when `tests_done >= tests_required` (12), the user is marked complete (`eligible: true` in `my_app`).

### App reads user state

`GET /api/user/:userId`

Returns:
- `my_app`, `my_queue_position`
- `session`, `session_app_ids` (when waiting and eligible, `session.status` can be `forming` to show the user’s 13‑app room filling)
- `apps_by_id` containing metadata for `my_app` + `session_app_ids`
- `prodev_bundle` if applicable
- Fields such as `assigned_tests`, `tests_done`, `tests_required`, `eligible`, `stale`

## Local demo (fill your room)

If you’re the only real user and want to see a full 13‑app session for testing, run:

```bash
node server/bin/seed_room.js http://127.0.0.1:8787 <YOUR_USER_ID>
```

### Admin (token required)

Header: `X-Admin-Token: <TEST12_ADMIN_TOKEN>`

- `GET /api/admin/state`
- `DELETE /api/admin/apps/:appId` (logs the action; does **not** remove apps currently in an active session)
- `POST /api/prodev/bundle` — create bundle drops (size 3/5/7/10) for a user; automatically queues the first drop

## Flutter app config

Build/run the app with:

- `--dart-define=TRY12_API_BASE_URL=http://localhost:8787`

Notes:
- `store_link` supports `https://...` links and `try12://mock/<ID>` links for demo placeholder apps.
