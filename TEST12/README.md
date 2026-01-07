TEST12 (Rule12 system)

Drop this folder in VS Code and run:

  flutter pub get
  flutter run

App flow:
- Gate (tap `START DEMO` or enter fields)
- Terminal (live backend): shows your queue/session state
- Session view: 13 apps total (yours + 12 others); tap each target, open store link, then `MARK TEST COMPLETE`

Backend config:
- Preferred: `--dart-define=TRY12_API_BASE_URL=https://YOUR-BACKEND`
- Fallback: reads `api_base_url` from `https://test-12test.netlify.app/config.json`
