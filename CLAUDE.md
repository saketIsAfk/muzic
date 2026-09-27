# CLAUDE.md — Muzic project guide

Context for AI assistants (and the developer) working in this repo. Read this first to
understand how things fit together before touching code. For the phased build plan, see `ROADMAP.md`.

**Owner:** beginner Python + Flutter developer. Portfolio project. Prefers small, well-explained
changes and learning the concept by name. Ship the smallest working slice first.

---

## What Muzic is

A music streaming app: a Flutter client plays songs whose files live in **Cloudinary**, served
through a **FastAPI** backend. Repo has two parts:

```
muzic/
├── server/   FastAPI backend
├── client/   Flutter app
├── ROADMAP.md
└── CLAUDE.md  (this file)
```

---

## Backend — `server/`

FastAPI. Entry: `server/app/main.py`. Run: `cd server && uvicorn app.main:app --reload --host 0.0.0.0`.

**Deps** (`server/requirements.txt`): `fastapi[standard]`, `cloudinary`, `python-dotenv`, `uvicorn`.

**Config:** Cloudinary credentials loaded from `.env` (`CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`,
`CLOUDINARY_API_SECRET`) in `main.py`.

### Layout
```
server/app/
├── main.py                     # FastAPI app, Cloudinary config, mounts stream_router
└── core/views/
    ├── stream/stream.py        # the only working router — /library and /stream
    └── auth/auth.py            # EMPTY — auth not implemented yet
```

### Endpoints (`core/views/stream/stream.py`)
- `GET /library` — walks the Cloudinary folder tree **live, every request**. Base folder `"Uploaded"`.
  Structure: `Uploaded/<Album>/<Song>/Song/` (audio, `resource_type="video"`) and `.../Profile/` (cover image).
  Per song it makes ~3 Cloudinary API calls (list audio, fetch full audio for duration, list cover).
  Returns `{"library": [{"album_name", "songs": [{"song_name","duration","audio_public_id","cover_url"}]}]}`.
- `GET /stream/{public_id:path}` — `cloudinary.api.resource(...)` → returns `{"stream_url": secure_url}`.
  404s via `cloudinary.exceptions.NotFound`.

### Known issues / debt
- **Cloudinary is used as the database.** Folder layout = schema. No Postgres, no models, no migrations.
- `/library` is an **N+1 explosion** against Cloudinary — slow, no cache, no pagination, no search.
- **No auth** anywhere on the backend. `auth.py` empty.
- No CORS config, no `/health`, no tests, no Docker.

---

## Client — `client/` (Flutter)

Run: `cd client && flutter run`. State management: **BLoC / Cubit** (`flutter_bloc`).
Routing: **go_router**. Audio: **just_audio** + `rxdart`. Auth SDK: **Firebase** + `google_sign_in`.

**Key deps** (`client/pubspec.yaml`): `flutter_bloc`, `go_router`, `just_audio`, `rxdart`, `http`,
`firebase_core`, `firebase_auth`, `google_sign_in`, `firebase_remote_config`, `shared_preferences`,
`flutter_svg`, `hexcolor`.

### Layout (`client/lib/`)
```
main.dart                       # runApp; MultiBlocProvider provides PlayerCubit only
core/
├── app_routing_manager/        # go_router config (splash → login → signup → home/main)
├── screen_names.dart           # route name constants
├── theme/                      # AppTheme, AppPallete
├── services/
│   ├── auth_services.dart      # Firebase Google sign-in/out/delete — WRITTEN BUT NOT ENFORCED
│   └── app_icon_service.dart   # dynamic app-icon switching (driven by Remote Config)
constants/                      # assets, theme, fonts constants
features/
├── auth/view/pages/            # login, signup, signup_process, logout screens
├── helper_widgets/             # home_drawer, custom_text_field, sliver_main_app_bar
└── resources/repositories/
    ├── songs_list_repo.dart    # GET /library  (hardcoded baseUrl)
    ├── songs_list_cubit.dart   # + songs_list_state.dart — library fetch state
    ├── player_repo.dart        # GET /stream/{id} (hardcoded baseUrl — duplicated)
    ├── player_cubit.dart       # + player_state.dart — just_audio playback
    ├── song_list_info.dart     # SongsListInfo, StreamInfo (JSON models)
    ├── album_info.dart         # AlbumModel, SongModel
    └── user_repo.dart          # EMPTY
view/
├── splash/splash_screen.dart   # inits Firebase + Remote Config app-icon, then → login
├── main_screen/main_screen.dart
├── home/view/                  # home_screen, song_card
└── mini_player/mini_player.dart
```

### How playback flows
1. Home screen provides `SongsListCubit` → `fetchLibrary()` → `SongsListRepository` → `GET /library`.
2. Tap a song → `PlayerCubit.playSong(song)` → `PlayerRepository.getStreamUrl(audioPublicId)` →
   `GET /stream/{id}` → `just_audio` plays the returned URL. `mini_player` shows current track.

### Known issues / debt
- **Auth not enforced.** Splash inits Firebase then routes to login unconditionally; nothing gates
  home. `user_repo.dart` empty. Login/signup screens exist but aren't fully wired.
- `Firebase.initializeApp()` lives in the **splash screen**, not `main()`, and uses no generated
  `firebase_options.dart`.
- **`baseUrl` hardcoded** (LAN IP `192.168.8.224:8000`) and **duplicated** in `songs_list_repo.dart`
  and `player_repo.dart`. No shared API client, no auth-token attach.
- **`SongsListCubit` provided twice** (both `main_screen.dart` and `home_screen.dart`).
- No search, playlists, favorites, history, background audio, queue, or offline.

---

## Target architecture (where this is going)

```
Flutter app ──HTTP──> FastAPI ──> Postgres (metadata: songs, albums, artists, users, playlists, favorites)
                          │
                          └──> Cloudinary (audio + cover FILES only)

Auth: Firebase login on client → backend verifies Firebase ID token → resolves a User row.
```

Principles: DB is the source of truth for metadata; Cloudinary only stores files; never trust the
client (verify tokens server-side); one API client on the app; smallest working slice first.

**Build order (see `ROADMAP.md` for detail):**
0. Cleanup — one API client, kill duplication, Firebase init in `main()`.
1. Postgres + SQLAlchemy + Alembic; ingest script populates DB from Cloudinary; `/library` reads DB, paginated.
2. Auth end-to-end — backend verifies Firebase ID token; route guards on the app.
3. Search + album/artist list & detail endpoints.
4. User features — favorites, playlists, play history (needs DB + auth).
5. Player polish — queue, background audio, shuffle/repeat, signed stream URLs.
6. Production — Docker, migrations, pytest + CI, deploy, README.

---

## Conventions & notes for future sessions
- Backend routers live under `core/views/<area>/<area>.py` and are mounted in `main.py`.
- Client features live under `features/<feature>/`; shared UI under `features/helper_widgets/`;
  cross-cutting code under `core/`.
- State is Cubit-based; repositories wrap HTTP calls; models have `fromJson` factories.
- When adding an endpoint: DB first (source of truth), then repo, then cubit, then UI.
- Keep this file current — if structure or plans change, update CLAUDE.md in the same change.
