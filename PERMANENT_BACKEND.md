# Make It Permanent (always-on)

Right now your backend is running through a temporary tunnel. It will go offline if your Mac sleeps/restarts.

To make it permanent (stable URL 24/7), deploy the backend to Render using the included `render.yaml`.

## What you do (3 steps)

1) Put this folder on GitHub (so Render can access it)
   - After you login to GitHub CLI: run `./publish-to-github.sh test12-permanent public`
2) On Render: **New** → **Blueprint** → select the repo → **Apply**
3) Copy the Render URL and run `./set-backend-url.sh https://YOUR-RENDER-URL`, then upload `netlify-upload.zip` to Netlify

## After you have the permanent backend URL

- Backend health check: `https://YOUR-BACKEND/api/health` should return `{"ok":true}`
- Website config: `https://test-12test.netlify.app/config.json` should show your backend URL
- `./set-backend-url.sh ...` also writes a numbered zip like `netlify-upload-001.zip` (use the highest number); `netlify-upload.zip` is always the latest copy.

## Notes

- The backend is the shared queue/session “real-time” state (everyone sees the same session once 13 are queued).
- The app reads `https://test-12test.netlify.app/config.json` automatically if you don’t hardcode a backend URL at build time.
