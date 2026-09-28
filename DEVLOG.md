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
3. **`railway.json`'s `preDeployCommand` is silently ignored.** Set it to run
   `alembic upgrade head` before every deploy, but nothing in the deploy logs shows it ever
   running — the CLI warns Config-as-Code (`railway.json`/`.toml`) is deprecated in favor of a
   `.railway/railway.ts` IaC file, and the old format may just not be applied automatically by
   `railway up`. Worked around manually twice (opened a temporary `railway tcp-proxy` to Postgres,
   ran `alembic upgrade head` / the ingest script from the laptop against that public proxy, then
   deleted the proxy). **Not sustainable** — every future migration needs this by hand until fixed
   properly (likely `railway config migrate` to the new IaC file, unverified).
4. **Ingest against production isn't automatic.** Ran manually via the same temporary-proxy trick.
   New Cloudinary uploads won't show up in the deployed app until someone remembers to re-run it
   against prod. No cron/webhook yet.
5. `railway ssh` fails with "Host key verification failed" even after registering a key via
   `railway ssh keys add` — used the TCP-proxy workaround instead (see blocker 3). Not investigated
   further.

## Priority backlog (small/necessary → big/delayable)

**P0 — mostly done, cleanup remaining**
1. ~~Deploy backend + managed Postgres~~ — done (Railway).
2. ~~Point Flutter `ApiConfig.baseUrl` at the deployed URL via `--dart-define`~~ — done.
3. ~~Rotate the Cloudinary secret~~ — done.
4. Fix `preDeployCommand` so migrations run automatically on deploy (blocker 3 above) — **still open**.
5. Automate ingest-against-production, at least a documented manual step, ideally a cron/webhook
   (blocker 4 above) — **still open**.

**P1 — soon after**
- Backend: `GET /search?q=` (SQL `ILIKE` + index), pagination on `/library`.
- Frontend: search bar + debounce, infinite-scroll list matching the paginated API.
- Auth: verify Firebase ID token server-side; gate the home screen client-side; wire up the
  empty `user_repo.dart`. (Firebase sign-in exists but is currently decorative.)
- Frontend: loading / empty / error states on home + player screens.
- Frontend: `EnvConfigs.assertConfigured()`-style guard — assert on launch (debug only) that
  required `--dart-define` values aren't empty, so a forgotten flag fails loudly at startup
  instead of silently as a confusing empty-list/401 bug later. (Idea scanned from a reference
  Flutter codebase's `constants.dart`; directly motivated by the empty-`/library` confusion this
  session — see blocker 4 / session log below.)
- Frontend: cURL debug logging — print every outgoing HTTP request as a runnable `curl ...` line
  in debug console. Same source, would have made the empty-library issue obvious immediately.
- Frontend: a `BlocObserver` override logging Cubit state transitions (`onChange`/`onError`) to
  console. One class, cheap, gives free visibility into `SongsListCubit`/`PlayerCubit`.

**P2 — real features, can wait**
- Favorites, playlists, play history (all need the P1 auth work first).
- Background audio, queue, next/prev, shuffle/repeat (`audio_service` + `just_audio`).
- Signed/expiring Cloudinary stream URLs.
- Album/artist detail endpoints + screens.
- Structured logging / error tracking (e.g. free Sentry tier, or Firebase Crashlytics).
- Local caching of the library list (`shared_preferences`).

**P3 — polish, delay freely**
- Dynamic theming from album art, mini-player motion polish.
- pytest + GitHub Actions CI.
- Rate limiting / security headers.
- Docker + full production hardening (Roadmap Phase 6).
- Swap `http` package for `dio` — only if/when Phase 2 auth needs interceptors to attach a token
  to every request. Not worth the churn before that's a real need.
- Alice-style full in-app network inspector — skip; cURL logging (P1, above) gets most of the
  value for a fraction of the setup at this app's size.

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
