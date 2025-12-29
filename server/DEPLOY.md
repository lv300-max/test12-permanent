## Deploy (simple)

This server is the shared “real-time” state for the queue + 12-app sessions.

### Run locally

```bash
cd server
npm install
TEST12_ADMIN_TOKEN=change-me npm run dev
```

Open `http://localhost:8787/api/health`.

### Deploy (Docker)

Build:

```bash
cd server
docker build -t test12-server .
```

Run (persists state on your machine):

```bash
docker run -p 8787:8787 -e TEST12_ADMIN_TOKEN=change-me -v "$PWD/data:/app/data" test12-server
```

### Point the Flutter app at the server

Build/run with:

```bash
--dart-define=TRY12_API_BASE_URL=https://YOUR-SERVER-DOMAIN
```

Optional:

```bash
--dart-define=TRY12_AUTO_SUBMIT_REMOTE=true
```

