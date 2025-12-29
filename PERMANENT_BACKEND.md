# Make It Permanent (always-on)

Right now your backend is running through a temporary tunnel. It will go offline if your Mac sleeps/restarts.

To make it permanent (stable URL 24/7), deploy the backend to Render using the included `render.yaml`.

## What you do (3 steps)

1) Put this folder on GitHub (so Render can access it)
2) On Render: **New** → **Blueprint** → select the repo → **Apply**
3) Copy the Render URL and paste it into `TEST12/web/config.json` as `api_base_url`, then redeploy Netlify with `netlify-upload.zip`

## After you have the permanent backend URL

- Backend health check: `https://YOUR-BACKEND/api/health` should return `{"ok":true}`
- Website config: `https://test-12test.netlify.app/config.json` should show your backend URL

## Notes

- The backend is the shared queue/session “real-time” state (everyone sees the same session once 12 are queued).
- The app reads `https://test-12test.netlify.app/config.json` automatically if you don’t hardcode a backend URL at build time.

