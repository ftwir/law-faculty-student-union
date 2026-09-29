# Law Faculty Student Union — Full Project

Two real folders here:

- `backend/` — Django + DRF + Channels API (auth, hubs, posts, polls, quizzes,
  flashcards, chat, badges, notifications). Deployable to Render as-is
  (`render.yaml` included).
- `client_app/` — Flutter student app (login, hub list, hub feed). Talks to
  the backend over `API_BASE_URL`.

## Why this can't be assembled in APK Editor Studio

APK Editor Studio decompiles an *existing compiled APK* into Smali/resources
and repacks it. This project is brand-new source code (Dart/Flutter), not a
decompiled app — there is no APK to open in it. Flutter has its own build
toolchain and that's the only way to turn this source into an installable
APK:

```bash
cd client_app
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://<your-backend-url>
# output: build/app/outputs/flutter-apk/app-release.apk
```

This requires the Flutter SDK + Android SDK, either on your machine (Android
Studio installs both) or in a CI job. I can't run this build myself in this
environment — I don't have a mobile build toolchain or a way to sign/return
an APK binary here. What I can do is keep producing/adjusting the source.

## Deploying the backend to Render

1. Push the `backend/` folder to a GitHub repo (root `render.yaml` at the
   repo root, or adjust `rootDir` if nested).
2. In Render: New → Blueprint → point at the repo. It will read `render.yaml`
   and create the web service + Postgres + Redis together.
3. Once live, note the backend URL (e.g. `https://law-union-backend.onrender.com`)
   and pass it as `API_BASE_URL` when building the Flutter app.

## About your existing Render account

I don't have a delete capability on Render through the connection available
here (only list/create/deploy/update-env-vars). Your workspace currently has
several older services from earlier attempts (e.g. `law-union-v2`,
`law-union-admin-v2`, `LawStudentsUnion-ACM-Manager`,
`law-students-union-self-healing-agent`, and a few static sites/APIs). If you
want a clean slate, remove the ones you don't need from the Render dashboard
directly — I can point you to exactly which ones look stale if you want a
second opinion first.
