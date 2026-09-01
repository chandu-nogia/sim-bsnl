# BSNL SIM Portal

Flutter web UI. Live host: **Vercel**. API: **Render**. Data: **MongoDB Atlas**.

## Local

```bash
# 1. API
cd backend
cp .env.example .env
# MONGODB_URI edit karo
npm install
npm start

# 2. UI
cd bsnl_sim_portal
flutter run -d chrome
```

Settings API URL: `http://localhost:5050`

## Vercel

```bash
flutter build web --release --dart-define=API_URL=https://bsnl-sim-api.onrender.com
npx vercel deploy build/web --prod --yes
```

`vercel.json` SPA fallback ke liye hai. Output folder: `build/web`.

## Stack

| Part | Host |
|------|------|
| Flutter web | Vercel |
| Node.js API | Render |
| MongoDB | Atlas |
