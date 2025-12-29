TEST12 (Rule12 system)

Drop this folder in VS Code and run:

  flutter pub get
  flutter run

App flow:
- Gate (identity + basic verification)
- Queue (chronological)
- Session (12 apps, 14 days, auto-complete)
- Assignment map (13 icons: your app + 12 slots)
- Admin view (read-only + remove app, logs actions)

Optional: connect to a shared server (site submits → app reads):

- Start the server in `../server/` (see `../server/README.md`)
- Run Flutter with:
  - `--dart-define=TRY12_API_BASE_URL=http://localhost:8787`
  - `--dart-define=TRY12_ADMIN_TOKEN=...` (optional; enables REMOVE in admin)
