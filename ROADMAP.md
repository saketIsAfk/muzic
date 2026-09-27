# Muzic — Build & Learning Roadmap (prompt for an AI pair-programmer)

> Paste this whole file as context to GPT (or any AI assistant) at the start of a session,
> then say: *"We're on Phase X, task Y. Teach me as we go, smallest working change first."*

---

## 0. Context — read this first, GPT

I'm a **beginner Python + Flutter developer** building a music streaming app for my
portfolio. I want to **learn while building**, so:

- Explain *why*, not just *what*. Name the concept (e.g. "this is an N+1 query", "this is a JWT").
- Prefer the **smallest change that works**. No premature abstraction, no speculative features.
- One phase at a time. Don't jump ahead. Each phase must run before we start the next.
- When you write code, tell me what to run to prove it works.

### Current architecture (as of this roadmap)

**Backend** — `server/app`, FastAPI:
- `GET /library` — walks the Cloudinary folder tree *live on every request*. Per song it makes
  3+ Cloudinary API calls. No database, no cache, no pagination, no search.
- `GET /stream/{public_id}` — returns the Cloudinary `secure_url` for an audio asset.
- No auth. No database. No models. `auth.py` is empty.
- Deps: `fastapi[standard]`, `cloudinary`, `python-dotenv`, `uvicorn`.

**Client** — `client/lib`, Flutter + BLoC (Cubit):
- State: `PlayerCubit` (just_audio playback), `SongsListCubit` (fetches `/library`).
- Firebase Google sign-in code exists (`core/services/auth_services.dart`) but is **not enforced** —
  splash routes straight to login, nothing gates the home screen.
- `baseUrl` is a hardcoded LAN IP duplicated across `songs_list_repo.dart` and `player_repo.dart`.
- `SongsListCubit` is provided twice (main_screen + home_screen).
- Routing: go_router. Models: `AlbumModel`, `SongModel`, `StreamInfo`.

### The core problem to fix

**Cloudinary is being used as the database.** Folder structure = data schema. That can't be
searched, paginated, sorted, or joined to user data (favorites, playlists, history). Cloudinary
is a *file store*. We need a **real database** (Postgres) as the source of truth for metadata,
with Cloudinary holding only the audio/image files.

### Target architecture

```
Flutter app ──HTTP──> FastAPI ──> Postgres (metadata: songs, albums, users, playlists…)
                          │
                          └──> Cloudinary (audio + cover image files only)

Auth: Firebase (client login) → backend verifies Firebase ID token → issues/uses it for protected routes.
```

---

## Guiding principles (apply every phase)

1. **DB is the source of truth for metadata.** Cloudinary only stores files.
2. **Never trust the client.** Every protected endpoint verifies identity server-side.
3. **One API client on the app.** All requests go through one place that knows the base URL and attaches the auth token.
4. **Ship the smallest working slice**, then iterate. A phase isn't done until it runs.
5. **Write one test for non-trivial logic.** Not full coverage — one check that fails if the logic breaks.

---

## PHASE 0 — Cleanup & foundations (do this first, ~1–2 days)

Goal: remove the duplication and wiring bugs so later phases build on solid ground.
No new features. Pure hygiene. **Learn:** dependency injection, config, single source of truth.

**Backend**
- [ ] Add `.env.example` (documents the env vars without secrets). Confirm `.env` is git-ignored.
- [ ] Add CORS middleware to `main.py` so the app can call it in dev.
- [ ] Add a `GET /health` endpoint returning `{"status":"ok"}`.

**Client**
- [ ] Create `core/network/api_client.dart` — one class holding `baseUrl` and a configured
      `http`/`dio` instance. Both repos use it. Delete the duplicated `_baseUrl` strings.
- [ ] Move `baseUrl` into a compile-time config (`--dart-define=API_BASE_URL=...`) so it isn't
      hardcoded. **Learn:** why hardcoded IPs break on real devices.
- [ ] Fix the double `SongsListCubit` provider — provide it once, high enough in the tree.
- [ ] Move `Firebase.initializeApp()` out of the splash screen into `main()` (before `runApp`),
      using a generated `firebase_options.dart` (`flutterfire configure`).

**Done when:** app builds, `/health` responds, only one place defines the base URL, no duplicate cubit.

---

## PHASE 1 — Real database & data model (the big architecture fix, ~3–5 days)

Goal: Postgres becomes the source of truth. `/library` reads the DB, not Cloudinary, per request.
**Learn:** relational schema, SQLAlchemy ORM, Alembic migrations, N+1 queries, pagination.

**Backend**
- [ ] Add Postgres. Locally via Docker (`docker compose up`). Deps: `sqlalchemy`, `psycopg2-binary`, `alembic`.
- [ ] Define models: `Artist`, `Album`, `Song` (song has `title`, `duration`, `audio_public_id`,
      `cover_url`, `album_id`, `artist_id`, timestamps).
- [ ] Set up Alembic; create the first migration.
- [ ] Write an **ingest script** (`scripts/ingest_cloudinary.py`) that runs the *current* folder-walking
      logic **once**, writing rows into Postgres. This is the one place Cloudinary-walking survives.
- [ ] Rewrite `GET /library` to read from Postgres with **pagination** (`?limit=&offset=`). Fast, no
      Cloudinary calls on the hot path.
- [ ] Keep `GET /stream/{public_id}` as-is for now.

**Client**
- [ ] Update `SongsListRepository` for the paginated response. Add infinite scroll / "load more"
      to the home list.

**Done when:** `/library` responds in milliseconds from Postgres, paginates, and Cloudinary is only
touched by the ingest script. Add one test: ingest N folders → assert N song rows exist.

---

## PHASE 2 — Auth, end to end (~3–4 days)

Goal: real login enforced on both client and server. **Learn:** OAuth/OIDC, ID tokens vs sessions,
verifying tokens server-side, route guards, protected endpoints.

Pick **one** identity approach and commit to it:
- **Option A (recommended — reuse what's here):** keep Firebase Google sign-in on the app. Backend
  verifies the Firebase **ID token** on each request (`firebase-admin` SDK). Simplest given existing code.
- **Option B:** own email/password auth with `passlib` (bcrypt) + your own JWTs. More to learn, more to maintain.

**Backend (Option A)**
- [ ] Add `firebase-admin`. On protected routes, read `Authorization: Bearer <idToken>`, verify it,
      resolve/create a `User` row (`firebase_uid`, `email`, `display_name`).
- [ ] Add a FastAPI dependency `get_current_user()` that 401s if the token is missing/invalid.
- [ ] Protect the routes that should require login.

**Client**
- [ ] Enforce auth in routing: an unauthenticated user can't reach home. Use go_router's `redirect`
      driven by `authStateChanges`.
- [ ] API client attaches the Firebase ID token to every request; refreshes it when expired.
- [ ] Wire up the existing login/signup/logout screens for real. Fill in `user_repo.dart`.

**Done when:** logged-out user lands on login and can't bypass it; backend rejects requests without a
valid token; a `users` row exists per real user.

---

## PHASE 3 — Search & lists (~2–3 days)

Goal: find songs/albums/artists. **Learn:** SQL `LIKE`/full-text search, indexing, debouncing.

**Backend**
- [ ] `GET /search?q=` — search songs/albums/artists by name. Start with `ILIKE`; add a Postgres
      full-text index if it gets slow. Paginated.
- [ ] `GET /albums`, `GET /albums/{id}`, `GET /artists/{id}` — proper list/detail endpoints.

**Client**
- [ ] Search screen with a **debounced** text field (don't fire a request per keystroke).
- [ ] Album detail page (tap album → its songs). A `SearchCubit` for search state.

**Done when:** typing a query returns matching results without hammering the API; album detail works.

---

## PHASE 4 — User library features (~3–5 days)

Goal: the features that *need* both a DB and auth — this is why Phases 1–2 came first.
**Learn:** many-to-many joins, per-user data, optimistic UI updates.

**Backend**
- [ ] `favorites` (user↔song). `POST/DELETE /favorites/{song_id}`, `GET /favorites`.
- [ ] `playlists` + `playlist_songs` (many-to-many, ordered). CRUD endpoints, all scoped to the
      current user.
- [ ] `play_history` — record on stream. Powers "Recently played".

**Client**
- [ ] Heart/like toggle on songs (optimistic update, then confirm with server).
- [ ] Playlists: create, add/remove songs, reorder, playlist detail screen.
- [ ] "Recently played" and "Your favorites" sections on home.

**Done when:** a logged-in user can favorite songs and build playlists that persist across restarts
and devices. Test: create playlist, add song, refetch → song is present and ordered.

---

## PHASE 5 — Player polish (~2–4 days)

Goal: make it feel like a real music app. **Learn:** background audio, platform services, streaming.

- [ ] Playback **queue** (next/previous, play a whole album/playlist).
- [ ] **Background playback** + lock-screen/notification controls (`just_audio_background` or `audio_service`).
- [ ] Shuffle, repeat.
- [ ] (Optional) **Signed, expiring stream URLs** from the backend so raw Cloudinary URLs aren't
      handed out permanently — improves the `/stream` endpoint's security.
- [ ] (Optional) Offline download of favorites.

**Done when:** audio keeps playing when the app is backgrounded, with working notification controls.

---

## PHASE 6 — Production readiness (~2–4 days)

Goal: something you can show off and deploy. **Learn:** containers, migrations in prod, CI.

- [ ] `Dockerfile` for the backend; `docker-compose.yml` for API + Postgres.
- [ ] Run Alembic migrations on deploy (not `create_all`).
- [ ] Backend tests with `pytest` (a test DB); a small CI workflow (GitHub Actions) running lint + tests.
- [ ] Structured logging + a global error handler on the API. Sensible error UI in the app
      (retry on failed `/library`, empty states).
- [ ] Deploy the API (Render/Railway/Fly.io) + managed Postgres. Point the app at the deployed URL
      via `--dart-define`.
- [ ] Write the README: architecture diagram, screenshots, run instructions. **This is what recruiters read.**

**Done when:** `docker compose up` runs the whole backend; the app talks to a deployed API; README explains it.

---

## Priority summary (if time is short)

| Priority | Phase | Why |
|----------|-------|-----|
| 🔴 Must  | 0, 1, 2 | Fixes the broken architecture: real DB + enforced auth. Everything depends on these. |
| 🟠 High  | 3, 4    | Search + favorites/playlists — the features that make it a *product*. |
| 🟢 Nice  | 5, 6    | Polish + deploy — what makes the portfolio piece impressive. |

**Do not** build Phase 4 (favorites/playlists) before Phases 1–2 — they have nowhere to live without
a DB and a user identity. That ordering is the whole point.

---

## How to work with me each session, GPT

- Start by confirming which phase/task we're on.
- Show me the smallest diff that works, then tell me the exact command to verify it.
- Point out the concept I'm learning by name so I can go read more.
- If I ask for something out of phase order, remind me why the current phase comes first.
