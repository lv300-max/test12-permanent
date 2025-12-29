# Test 12 Server (site submits → app reads)

This is a minimal HTTP API that persists **queue + session** state in a JSON file and enforces the Rule12 rules:

- Queue is chronological; immutable except removal.
- Session opens only when **12 waiting apps** exist; lasts **14 days**.
- Sessions auto-complete at `end_time`; completed apps exit cleanly.
- Apps are **metadata + store link only**.

## Run

```bash
cd server
npm install
TEST12_ADMIN_TOKEN=change-me npm run dev
```

Server listens on `PORT` (default `8787`).
State persists to `TEST12_STATE_PATH` (default `./data/state.json`).

## API

### Submit from your site

`POST /api/submit`

Body:

```json
{ "user_id": "u123", "app_name": "My App", "store_link": "https://play.google.com/..." }
```

Returns the user’s current position, plus the active session (if any).

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

### App reads user state

`GET /api/user/:userId`

Returns:
- `my_app`, `my_queue_position`
- `session`, `session_app_ids`
- `apps_by_id` containing metadata for `my_app` + `session_app_ids`

### Admin (token required)

Header: `X-Admin-Token: <TEST12_ADMIN_TOKEN>`

- `GET /api/admin/state`
- `DELETE /api/admin/apps/:appId` (logs the action; does **not** remove apps currently in an active session)

## Flutter app config

Build/run the app with:

- `--dart-define=TRY12_API_BASE_URL=http://localhost:8787`
- `--dart-define=TRY12_ADMIN_TOKEN=change-me` (optional; enables “REMOVE” in admin screen)

Notes:
- `store_link` supports `https://...` links and `try12://mock/<ID>` links for demo placeholder apps.
