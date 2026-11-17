# CINEVERSE Backend (PHP + MySQL)

Native PHP 8.2 REST API for the React client. It uses PDO prepared statements, MySQL transactions, password hashing, signed short-lived bearer tokens, role checks, audit logging, validated image uploads, and soft archival for movies. No payment gateway is connected: selecting a paid subscription creates a **pending** subscription and billing record. Users can open a prefilled WhatsApp request to the admin; the admin must explicitly mark the recorded payment successful before the paid plan becomes active.

## XAMPP setup

1. Start Apache and MySQL in the XAMPP Control Panel.
2. Import `backend/database/movie_db.sql` into phpMyAdmin (or run `C:\xampp\mysql\bin\mysql.exe -u root -p < backend\database\movie_db.sql`).
3. Copy `backend/.env.example` to `backend/.env`. Set database credentials and replace `APP_KEY` with a unique random value of 32 or more characters. Keep `.env` private.
4. Open `http://localhost/clothes/backend/public/health`. It should return `{"data":{"status":"ok","service":"cineverse-api"}}`.
5. For React dev server access, copy the root `.env.example` to `.env` (default API base `/api`) and run `npm run dev`. Vite proxies `/api` requests to the XAMPP backend. The public catalog, watchlist, recommendations, admin movie, genre, actor, user, billing, and analytics screens use backend APIs. Profile editing and some secondary dashboard figures remain demonstration data.
6. For backend/API development, run the React app at `http://localhost:5173` while Apache serves the API under `/clothes/backend/public/`. Production SPA hosting needs Apache rewrite rules and a build-time API base matching the chosen deployment path.

### Google sign-in setup

Create an OAuth 2.0 **Web application** client in Google Cloud Console. Add both `http://localhost` and `http://localhost:5173` as authorized JavaScript origins. Set the client ID as `VITE_GOOGLE_CLIENT_ID` in the frontend `.env` and as `GOOGLE_CLIENT_ID` in `backend/.env`; these values must match. For deployment, add the exact HTTPS site origin in Google Console and use the same client ID in both environment files. Restart Vite after changing `.env`, and rebuild the frontend after setting the production client ID. The API verifies Google credentials with Google's token info endpoint, so the PHP server needs outbound HTTPS access. If the client ID is not set, the Google button stays disabled and password login continues to work.

Create the first administrator by registering an account through `/auth/register`, then promote that account in phpMyAdmin:

```sql
UPDATE users SET role = 'admin' WHERE email = 'your-admin@example.com';
```

Never expose the database or `backend/.env` publicly. The backend directory denies direct web access; only `backend/public` is intended to be served. Uploaded images are MIME checked, limited to 5 MB, assigned random filenames, and stored under `backend/public/uploads`. Movie videos accept MP4/WebM up to 1 GB and are stored outside the public directory in `backend/storage/videos`; playback/download uses short-lived signed links and requires an active subscription for regular users. The API's `.htaccess` sets `upload_max_filesize=1024M` and `post_max_size=1050M` for XAMPP's Apache PHP handler.

## API conventions

All API responses use `{ "data": ... }`; errors use `{ "error": { "message": ..., "details": [] } }`. Send JSON with `Content-Type: application/json`; protected requests include `Authorization: Bearer <token>`. IDs are numeric. Movie list responses include pagination metadata. Upload requests use `multipart/form-data`.

### Routes

| Method | Path | Access | Purpose |
|---|---|---|---|
| GET | `/health` | Public | API health check |
| POST | `/auth/register`, `/auth/login`, `/auth/google` | Public | Register/login with password or Google credential; registration assigns the active Free plan |
| GET | `/auth/me`, `/profile` | User | Current identity/profile |
| PUT | `/profile` | User | Update profile (multipart photo supported) |
| GET | `/movies`, `/movies/{id}` | Public | Published/available catalog, search, genre, rating, year, sort, page, limit |
| POST | `/movies/{id}/media-token` | Active subscriber/Admin | Short-lived token for uploaded movie media |
| GET | `/movies/{id}/stream`, `/movies/{id}/download` | Token | Stream or download the uploaded movie video |
| POST/PUT/PATCH/DELETE | `/movies[/{id}]` | Admin | Create/update/archive movies; delete archives |
| GET/POST/PUT/DELETE | `/genres[/{id}]` | Public read/Admin write | Genre management |
| GET/POST/PUT/DELETE | `/actors[/{id}]` | Public read/Admin write | Actor management |
| POST | `/movies/{id}/cast` | Admin | Assign actor and role |
| GET/POST | `/watchlist`, `/watchlist/items` | User | Read/add own watchlist |
| DELETE | `/watchlist/items/{movieId}` | User | Remove from own watchlist |
| POST | `/movies/{id}/views` | User | Record viewing activity |
| GET | `/recommendations` | User | Genre/activity/popularity-based suggestions |
| GET | `/plans` | Public | Free, Weekly (1,000 RWF), and Monthly (3,000 RWF) plans from MySQL |
| POST | `/subscriptions` | User | Activate Free immediately or create a pending paid subscription and billing record |
| GET | `/subscriptions/me`, `/billing/me` | User | Own subscription and billing history |
| POST | `/subscriptions/{id}/change`, `/subscriptions/{id}/cancel` | User | Request plan change or cancel own subscription |
| POST/PUT/DELETE | `/admin/plans[/{id}]` | Admin | Create/update/deactivate plans |
| GET | `/admin/subscriptions`, `/admin/billing`, `/admin/users` | Admin | Searchable data source for management screens |
| PATCH | `/admin/users/{id}/status` | Admin | Activate/suspend account |
| PATCH | `/billing/{id}/status` | Admin | Record simulated payment outcome |
| GET | `/admin/analytics`, `/admin/recommendations` | Admin | Database-derived dashboard metrics/activity |

## Data model

`movie_db.sql` defines users/profiles/preferences, genres, movies, actors/cast, movie images, watchlists, viewing history, recommendation logs, subscription plans, subscriptions, plan-change history, billing records, and audit logs. Foreign keys and unique keys enforce relationships and prevent duplicate emails, usernames, and watchlist entries. Historical movie references are restricted; movie deletion is implemented as archival.

## Limitations and next integration work

The public movie catalog, authentication, watchlists, recommendations, admin movie/genre/actor management, user management, billing review, and analytics use the API. Profile editing and some secondary dashboard figures still use demonstration data. The backend needs production hardening before deployment (HTTPS, refresh/revocation strategy, rate limiting, stricter CORS allowlist, operational backups). No real payment gateway is connected. MySQL requires the local XAMPP service to be running.
