# BSNL SIM Portal

Flutter web + Node.js API. Data **MongoDB Atlas** mein. Live host **Cloudflare Workers**.

Repo: [chandu-nogia/sim-bsnl](https://github.com/chandu-nogia/sim-bsnl)

## Local

```bash
# 1. MongoDB Atlas URI
cp server/.env.example server/.env
# MONGODB_URI edit karo

# 2. API
cd server
npm install
npm start
# http://localhost:5050

# 3. UI (dusri terminal)
flutter run -d chrome
```

Settings mein API URL: `http://localhost:5050`

## Cloudflare (live website)

1. [MongoDB Atlas](https://www.mongodb.com/atlas) free cluster, Network Access `0.0.0.0/0`
2. Website build:

```bash
flutter build web --release
cd server
npx wrangler login
npx wrangler secret put MONGODB_URI
npm run deploy
```

URL: `https://bsnl-sim-portal.<account>.workers.dev`

GitHub se auto-deploy: [Cloudflare Dashboard](https://dash.cloudflare.com) → Workers & Pages → Create → Connect git repo `chandu-nogia/sim-bsnl` → deploy command `npm run deploy` (root: `server`).

## API

| Method | Path |
|--------|------|
| GET | `/api/health` |
| GET | `/api/sims` |
| POST | `/api/sims` |
| PUT | `/api/sims/:id` |
| DELETE | `/api/sims/:id` |
