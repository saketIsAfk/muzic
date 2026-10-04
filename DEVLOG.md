# Muzic — Dev Log

> Living log of what we've done, why, and what's blocked. Update this after every commit or
> significant chat session — new entries go at the **top** of "Session Log," newest first.
> This is not the plan (`ROADMAP.md`) and not the structural reference (`CLAUDE.md`) — it's the
> journal: decisions made, bugs found, reasoning, and open blockers. Keep it honest — if something
> was skipped or deferred, say so here instead of letting it go unrecorded.

---

## Current status

- **Phase 0 (Cleanup):** done, except CORS (skipped — no web target yet).
- **Phase 1 (Real Database):** Postgres + SQLAlchemy + Alembic done. Ingest script writes real
  rows (idempotent), run against both local and production DBs. `/library` reads Postgres, not
  Cloudinary. Pagination and a real test are still open.
- **Backend is deployed.** Railway project `amusing-charm`: `muzic-server` service (FastAPI) +
  `Postgres` service, public URL `https://muzic-server-production.up.railway.app`. Client
  `ApiConfig.baseUrl` now defaults to it via `--dart-define` (overridable for local LAN testing).
- Secret rotated — blocker #1 below is resolved.
- Nothing pushed to `origin/main` yet since the last commit.

## Open blockers

1. ~~Leaked Cloudinary secret~~ — **resolved.** Rotated in Cloudinary console, old key disabled.
   New key is only in `server/.env` (gitignored) and Railway's env vars, never in git.
2. **`Song.duration` comes back `None`.** Both the old Cloudinary-live `/library` and the ingest
   script hit this — `full_audio.get("duration")` doesn't return what's expected from Cloudinary's
   API for these assets. Not debugged yet; not blocking, just a known gap in the data.
3. ~~`railway.json`'s `preDeployCommand` is silently ignored~~ — **resolved**, see session log
   2026-10-04. Root cause: `railway up` only ever read `railway.json` for build settings;
   service-level deploy settings like `preDeployCommand` are config living in Railway's own
   service object and have to be set through their IaC tool, not a dropped-in file. Fixed via
   `.railway/railway.ts` + `railway config apply`. Confirmed in logs: every deploy now runs
   `alembic upgrade head` in a throwaway container, stops it, then starts the real `uvicorn`
   container — two "Starting Container" lines per deploy is the expected signature.
4. **Ingest against production isn't automatic.** Ran manually via the same temporary-proxy trick.
   New Cloudinary uploads won't show up in the deployed app until someone remembers to re-run it
   against prod. No cron/webhook yet.
5. `railway ssh` fails with "Host key verification failed" even after registering a key via
   `railway ssh keys add` — used the TCP-proxy workaround instead (see blocker 3). Not investigated
   further.

## Priority backlog (small/necessary → big/delayable)

**Re-ranked 2026-10-04 — resume-value-weighted (product-lead lens), see session log entry below
for full reasoning.** Supersedes the plain "small→big" ordering above for anything not already
done. Old P0 cleanup items kept at top since they're still real open bugs.

**NOW**
1. ~~Fix `preDeployCommand` so migrations run automatically on deploy~~ — **done**, see session log.
2. **Auth end-to-end** — verify Firebase ID token server-side (FastAPI dependency), gate home
   screen client-side, wire up empty `user_repo.dart`. Highest resume value: most-asked interview
   topic, and unlocks every personalization feature below. Firebase sign-in exists but is
   currently decorative/dead code.
3. **Automate Cloudinary → DB ingestion** (Cloudinary webhook → FastAPI endpoint → idempotent
   upsert of just the new asset, not a full re-walk). Replaces the manual tcp-proxy trick used
   twice this project already (blocker 4). Resume story: "event-driven media pipeline."
4. **CI/CD** — connect Railway service to GitHub so `git push` auto-deploys, instead of manual
   `railway up`. Cheap once the preDeployCommand bug (item 1) is fixed; itself an interview topic.

**NEXT**
- Search: `GET /search?q=` — start with SQL `ILIKE` + index, upgrade to `pg_trgm` (trigram
  similarity) for typo-tolerant fuzzy search — a genuine "better than Spotify" micro-flex.
  Frontend: search bar + debounce.
- User features: favorites, playlists, play history, "recently played" — the thing that makes
  this look like a product, not a CRUD demo. Needs auth (NOW item 2) done first.
- Player polish: queue, gapless/crossfade, background audio, offline cache (`audio_service` +
  `just_audio`) — high demo/interview-screenshare value.
- Pagination on `/library`; frontend infinite-scroll to match.
- Frontend: loading/empty/error states on home + player screens.
- Frontend: `EnvConfigs.assertConfigured()`-style guard — assert on launch (debug only) that
  required `--dart-define` values aren't empty, so a forgotten flag fails loudly instead of as a
  confusing empty-list bug later (scanned from a reference Flutter codebase; motivated by the
  empty-`/library` confusion earlier this project).
- Frontend: cURL debug logging (print every outgoing request as a runnable `curl` line) and a
  `BlocObserver` override logging Cubit state transitions — both cheap, both scanned from the
  same reference codebase.

**LATER**
- Observability: structured logs, Sentry (or Firebase Crashlytics), request metrics dashboard —
  real SDE-level interview topic, compounds the longer the app runs.
- Caching layer (Redis) in front of `/library` and `/search` — save before/after latency numbers
  for the README; needs real traffic/data volume to be a credible story first.
- Tests + CI (pytest, GitHub Actions) — write alongside new features going forward, don't
  backfill all at once.
- Signed/expiring Cloudinary stream URLs.
- Album/artist detail endpoints + screens.
- Dynamic theming from album art, mini-player motion polish.
- Rate limiting / security headers.
- Docker + full production hardening (Roadmap Phase 6).
- Swap `http` package for `dio` — only if/when the auth work needs interceptors to attach a
  token to every request automatically. Not worth the churn before that's a real need.
- Alice-style full in-app network inspector — skip; cURL logging above gets most of the value
  for a fraction of the setup at this app's size.

**MOONSHOT — the actual "beat Spotify" wedges, do after NEXT tier has real usage data**
- Simple recommendations ("because you played X") — even naive co-occurrence counting, no ML
  framework needed. Highest-leverage differentiator vs. a generic music-app clone. Needs play
  history (NEXT tier) to mean anything.
- Real-time listening rooms (Spotify Jam equivalent) via WebSockets — genuinely harder than
  anything Spotify ships smoothly; rare, hard, great interview story.
- Explainable search/recommendations ("why this song") — transparency Spotify deliberately
  doesn't offer. Needs recommendations to exist first.

## Concepts covered so far

Git ignore pattern resolution (last match wins) · sequences / auto-increment (`nextval`) ·
Alembic migrations (autogenerate, upgrade/downgrade, why unnamed constraints break downgrade) ·
idempotent ingestion / get-or-create · FastAPI dependency injection (`Depends`, `yield`-based
cleanup) · SQLAlchemy ORM (`Column`, `relationship`, `sessionmaker`, `Session`) · N+1 queries and
eager loading (`joinedload`) · deployment / process / port / env vars / domain / HTTPS / reverse
proxy (Railway) · driver resolution (`postgresql://` vs explicit `+psycopg2`) · pre-deploy
commands · private vs public networking (`*.railway.internal` vs a TCP proxy) · `--dart-define` /
`String.fromEnvironment` as Flutter's compile-time equivalent of `.env`.

---

## Session log

### 2026-10-04 — Backend verifies Firebase ID tokens; `users` table added
- **Concept: never trust the client.** Anyone could previously call the backend claiming to be
  any user — nothing checked. Firebase Admin SDK + a service account key lets the backend verify
  a client's ID token against Google's public keys itself, no round trip to Firebase needed per
  request.
- Downloaded the Firebase service account key from the console, added
  `**/firebase-service-account.json` to `.gitignore` **before** the file even existed locally, and
  proved it with `git check-ignore -v` on a placeholder file — same discipline as the `.env` setup.
- `firebase_admin.initialize_app(credentials.Certificate(...))` in `main.py`, path from
  `FIREBASE_SERVICE_ACCOUNT_PATH` env var (added to `.env` / `.env.example`).
- New `app/core/views/auth/auth.py` (previously an empty placeholder per `CLAUDE.md`): a
  `get_current_user` dependency using FastAPI's `HTTPBearer` security scheme to read the
  `Authorization: Bearer <token>` header, then `firebase_admin.auth.verify_id_token(...)`. Returns
  401 on missing header (`HTTPBearer` itself), invalid token, or expired token — each a distinct,
  named exception from the SDK.
- `GET /auth/me` — minimal protected route, no DB involved, just proves verification works:
  returns the decoded `uid`/`email`.
- **Verified with a real token**, not a mock: added a temporary debug line in
  `login_screen.dart` logging the ID token after Google sign-in, copied it from the Flutter debug
  console, `curl`'d `/auth/me` with it → `200 {"uid": "...", "email": "saket.singh@vetic.in"}`.
  Also confirmed the negative cases: no header → `401 Not authenticated` (from `HTTPBearer`
  itself); garbage token → `401 Invalid Firebase ID token` (from our `except` block).
- Own mistake caught mid-session: `echo ... >> .env` glued a new line onto `DATABASE_URL`'s value
  because the file had no trailing newline — caught immediately via `cat .env`, rewrote the file
  correctly before it could cause a confusing crash later.
- **`users` table added** — `User` model (`id`, `firebase_uid` unique, `email`, `display_name`,
  timestamps) mirrors the identity Firebase proves, giving future tables (favorites, playlists,
  play history) something of ours to foreign-key against; Firebase itself isn't a relational DB.
  Clean autogenerated migration, applied locally, verified `firebase_uid`'s uniqueness constraint
  backs a real index (`users_firebase_uid_key`) — matters since every verified request will look a
  user up by it. Not yet applied to production; next `railway up` will run it automatically via
  the now-fixed `preDeployCommand`.
- **Not done yet:** nothing resolves a verified token into an actual `User` row yet (`/auth/me`
  only echoes the token's claims). Next task. Also still pending: remove the temporary debug log
  line in `login_screen.dart`, attach the token to outgoing requests from the client, and gate the
  home screen on sign-in state.

### 2026-10-04 — Fixed the `preDeployCommand` bug (migrations now run automatically on deploy)
- **Diagnosed first, not guessed:** queried the service's actual live config via
  `railway status --json` → `serviceManifest.deploy.preDeployCommand` was `null`. Proved
  `railway.json` was never applied at all, not "applied and silently failing."
- **Root cause:** `railway up` only reads `railway.json` for *build*-time settings (Railpack).
  Deploy-level service config (`preDeployCommand`, `startCommand`, replicas, etc.) is state that
  lives on the Railway service object itself, changed through their actual config system — not
  something a file sitting in the repo gets auto-applied from. The CLI's repeated deprecation
  warning about `railway.json`/`.toml` was the hint pointing at this the whole time.
- **Fix: Railway's IaC flow.** `railway config pull` → generated `.railway/railway.ts`, a
  TypeScript file that's the actual source of truth, matching the project's real resources
  (Postgres, `muzic-server`, the volume). Added `preDeploy: "alembic upgrade head"` to the
  `muzic-server` service definition by hand.
  - Tried `railway config migrate` first (meant to auto-convert `railway.json`) — it invented a
    *new* service named `server` instead of recognizing the existing `muzic-server`, which would
    have created a duplicate service if applied. Discarded that output, used the hand-edited
    `pull`'d file instead. Did keep one useful fact from it: the correct field name is `preDeploy`,
    not `preDeployCommand` (that's the GraphQL/API name, not the IaC SDK's).
  - `railway config plan` (read-only) confirmed exactly one intended change before touching
    anything live — `~ Update muzic-server deploy.preDeployCommand (null → ["alembic upgrade head"])`.
  - `railway config apply --yes` applied it. Verified via the same `status --json` query:
    `preDeployCommand: ['alembic upgrade head']`.
- Needed `npm install railway` (the IaC SDK) locally for the CLI to evaluate the `.ts` file —
  added `server/package.json` + `node_modules/` (gitignored) purely as deploy tooling; doesn't
  touch the Python app at all.
- **Verified for real:** redeployed with `railway up`, then checked `railway logs -d` — saw
  `Starting Container` → Alembic output → `Stopping Container` → `Starting Container` again (the
  real `uvicorn` process). Two container starts per deploy is the correct signature: one throwaway
  container for the migration, one for the app. `/library` still served data correctly after.
- Deleted the now-dead `railway.json`.

### 2026-10-04 — Resume-value re-ranking of the backlog
- User asked to re-rank remaining work as a product lead would: optimize for full-stack-developer
  resume impact and an eventual "Spotify-level, better in some respects" ambition, not just
  small-effort-first.
- Verdict on the 3 items user asked to compare: **auth first** (gates every personalization
  feature, most-asked interview topic, currently decorative dead code in the repo) → **automate
  Cloudinary ingestion second** (independent of auth, removes manual tcp-proxy toil hit twice
  already, strong standalone "event-driven pipeline" story) → **search third** (no dependencies,
  real value, but unlocks less than the other two).
- Also pulled the open `preDeployCommand` bug and CI/CD (git-push auto-deploy) into the same NOW
  tier — both cheap, both direct interview talking points, and CI/CD is blocked on the
  preDeployCommand bug being fixed first anyway.
- Named 3 concrete "beat Spotify" wedges instead of vague "make it better": typo-tolerant
  (`pg_trgm`) search, simple usage-based recommendations, and real-time shared listening rooms —
  flagged as MOONSHOT tier, after NEXT-tier features exist (recommendations need real play-history
  data to mean anything).
- Replaced the old flat P0–P3 "small→big" backlog ordering with NOW/NEXT/LATER/MOONSHOT tiers
  above — old tiers kept where still accurate (e.g. still-open P0 bugs), superseded ordering
  otherwise.
- Nothing implemented this entry — planning/prioritization only.

### 2026-09-28 — Reference-codebase scan (Vetic app): what's worth borrowing
- User shared a production Flutter app's `constants.dart` + `pubspec.yaml` and asked what to
  adopt for debugging/observability.
- Filtered out everything company-specific (MoEngage, Razorpay, Singular, Facebook events,
  jwt_decode, custom lints) — irrelevant to Muzic's current scope.
- Kept 3 items worth adopting soon (small, high learning value) and 2 to just track, not build
  yet — see P1/P3 backlog above for the full reasoning. Nothing implemented this entry, only
  logged, per "one task at a time" — was mid-way through P0 cleanup.

### 2026-09-28 — Fixed empty `/library` after pointing app at Railway
- Symptom: app showed an empty library after `ApiConfig.baseUrl` was switched to the deployed URL.
- Not a bug: production Postgres had the schema (migration ran) but zero rows — the ingest script
  had only ever been run locally.
- Fix: same temporary-`tcp-proxy` trick as the migration — opened a public proxy to the Postgres
  service, built a one-off `DATABASE_URL` pointed at it, ran `scripts/ingest_cloudinary.py` against
  production, deleted the proxy again. Added 6 songs (more than the 1 that existed at last local
  ingest — more had been uploaded to Cloudinary since).
- Confirmed via `curl .../library` — non-empty, matches what the app should now show.
- Logged as an open gap: this has to be repeated manually after every future Cloudinary upload
  until it's automated (blocker 4, backlog item P0-5).

### 2026-09-28 — Backend deployed to Railway
- Installed `railway` CLI (`brew install railway`), `railway login` (browser OAuth).
- `railway init` → new project `amusing-charm`. `railway add --database postgres` → managed
  Postgres provisioned automatically, no config needed.
- `railway add --service muzic-server` → empty service for the FastAPI code.
- Added a `Procfile` (`web: uvicorn app.main:app --host 0.0.0.0 --port $PORT`) — Railway's
  Railpack builder needs this to know how to start the app; it auto-detected Python via
  `requirements.txt` for the build itself.
- Set env vars on `muzic-server` via `railway variable set ... --stdin` (piped straight from
  `.env`, so secret values never appeared in any terminal output): the 4 Cloudinary vars, plus
  `DATABASE_URL=${{Postgres.DATABASE_URL}}` — a **variable reference**, so it always tracks
  whatever Postgres's actual connection string is instead of a hand-copied value.
- **Bug found:** first deploy crashed — `ModuleNotFoundError: No module named 'psycopg'`. A bare
  `postgresql://` URL let SQLAlchemy pick a default driver; it picked `psycopg2` locally but
  `psycopg` (v3, not installed) on Railway's SQLAlchemy version. Fixed by hardcoding
  `postgresql+psycopg2://` in both `app/database.py` and `alembic/env.py`.
- `railway domain --service muzic-server` → public HTTPS URL, no manual TLS setup:
  `https://muzic-server-production.up.railway.app`. `/health` returned 200 immediately after.
- `/library` initially 500'd: `relation "albums" does not exist` — the `preDeployCommand` in
  `railway.json` (meant to auto-run `alembic upgrade head` before boot) never actually fired (see
  blocker 3). Worked around by opening a temporary public `tcp-proxy` to the Postgres service and
  running `alembic upgrade head` from the laptop against it, then deleting the proxy — `/library`
  returned `{"library": []}` (200) after, i.e. schema now exists, just no rows yet (see next entry).
- Tried `railway ssh` first to run the migration remotely instead of the proxy workaround — failed
  with a host-key verification error even after registering an SSH key; abandoned in favor of the
  proxy method (see blocker 5).

### 2026-09-28 — Flutter now points at the deployed backend
- Changed `ApiConfig.baseUrl` from a hardcoded LAN IP to
  `String.fromEnvironment('API_BASE_URL', defaultValue: '<railway-url>')` — a **compile-time**
  config value, since a shipped Flutter binary has no `.env` file to read at runtime the way the
  Python backend does.
- `flutter run` now hits Railway by default; `flutter run --dart-define=API_BASE_URL=http://<lan-ip>:8000`
  still available for local-backend testing.
- Since `songs_list_repo.dart` and `player_repo.dart` both already went through the single
  `ApiConfig.baseUrl` (from the earlier Phase 0 cleanup), this one edit updated both call sites.

## Session log

### 2026-09-27 — `/library` now reads Postgres, not Cloudinary
- **Problem:** old `/library` made ~3 Cloudinary API calls per song, every request (the N+1
  explosion flagged in `CLAUDE.md`).
- Added `get_db()` to `app/database.py` — a FastAPI dependency (`yield`-based) that opens one
  session per request and always closes it, even on error.
- Added the missing ORM link: `Album.songs` / `Song.album` `relationship()` — the `album_id`
  foreign key column already existed, but nothing let Python code walk `album.songs` without
  writing a manual query.
- Rewrote `GET /library` as `db.query(Album).options(joinedload(Album.songs)).all()` — one SQL
  `JOIN`, not one query per album (the N+1 fix, on the DB side this time).
- Removed the now-dead `BASE_FOLDER` constant from `stream.py`.
- **Verified:** `curl /library` returns byte-identical JSON *shape* to the old Cloudinary-backed
  version (`album_name` / `song_name` / `duration` / `audio_public_id` / `cover_url` keys
  unchanged) — client (`song_list_info.dart`, `album_info.dart`) needs zero changes.
- Not committed yet.

### 2026-09-27 — Ingest script writes real DB rows
- **Concept:** idempotent ingestion (get-or-create). Script will be re-run every time new songs
  land in Cloudinary, so re-running it must never duplicate rows.
- `scripts/ingest_cloudinary.py`: walks Cloudinary same as the old live `/library` did, but now
  `get_or_create_album()` by title, and skips a song if its `audio_public_id` (unique-constrained
  in the DB) already exists.
- Cloudinary folder structure has no artist level (`Uploaded/<Album>/<Song>/...`), so `artist_id`
  stays `NULL` on both tables for now — nullable column, not a blocker, just undecided where
  artist data will come from.
- **Verified:** ran twice. First run: `ADDED Tum ho toh`. Second run: `SKIP Tum ho toh: already in
  DB` — proves idempotency. Queried DB directly to confirm `album_id` foreign key links correctly.

### 2026-09-27 — Migration squash, Phase 0 + Phase 1 committed (`e9b3219`)
- **Bug found:** `alembic downgrade` crashed on `make_audio_public_id_unique` — its
  `op.create_unique_constraint(None, ...)` let Postgres auto-name the constraint on upgrade, but
  `op.drop_constraint(None, ..., type_='unique')` on downgrade can't resolve `None` back to
  whatever name Postgres actually picked. Lesson: autogenerated constraint names need to be
  filled in by hand if downgrade has to work.
- **Bug found:** the migration chain wasn't reproducible from an empty database — the first
  migration ran `op.add_column('songs', ...)` but no migration ever created `songs`; that table
  only existed because of the old `create_tables.py` script. Would fail on a fresh machine/CI/prod.
- **Fix:** since all 3 tables were empty and never shared, squashed to one clean migration:
  dropped `artists`/`albums`/`songs`/`alembic_version` directly via `psql`, deleted the 3 broken
  migration files, ran `alembic revision --autogenerate -m "initial schema"`, applied it.
  Verified all three `id` columns now have real `nextval(...)` sequence defaults.
- Deleted `create_tables.py` (Alembic owns the schema now), the dead empty `server/models/`,
  `server/routes/`, `server/schemas/` folders, and the scratch `test_connection.py` /
  `test_models.py` files.
- Added `__pycache__/` and `*.pyc` to `.gitignore`; deleted stray `__pycache__` dirs (never
  tracked, safe to remove).
- Committed everything as one commit: `e9b3219 chore: Phase 0 cleanup + Phase 1 DB foundation`.

### 2026-09-27 — `.env` / `.gitignore` audit
- Verified `server/.env` is ignored: `git check-ignore -v server/.env` → matched
  `.gitignore:2:**/.env`.
- Verified `server/.env.example` is **not** ignored: `**/.env.*` (line 3) matches it, but
  `!**/.env.example` (line 5) un-ignores it again — in `.gitignore`, the **last matching rule
  wins**.
- **Found the real problem:** the *old* root `.env` (before it moved to `server/.env`) was
  already committed in `479b7f4` and is sitting on `origin/main` right now, with a real
  Cloudinary API secret in it. `.gitignore` only stops *future* adds — it does nothing for a file
  already tracked, and it can't be scrubbed from history without a rewrite. Recorded as blocker
  #1 above; rotation is the fix, not history rewriting (the old key has to be treated as
  compromised either way).
