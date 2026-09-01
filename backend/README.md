# BSNL SIM API

Node.js + **MongoDB Atlas**. Live host: **Render**.

Flutter UI: `../bsnl_sim_portal` (Vercel).

## Local

```bash
cp .env.example .env
# MONGODB_URI Atlas se paste karo
npm install
npm start
# http://localhost:5050
```

## Render

1. GitHub pe `backend/` push karo
2. [Render](https://dashboard.render.com) → New → Blueprint / Web Service
   - Root directory: `backend` (agar monorepo ho)
   - Build: `npm install --omit=dev`
   - Start: `node server.js`
3. Environment:
   - `MONGODB_URI` = Atlas connection string
   - `MONGODB_DB` = `bsnl_sim`
4. Atlas → Network Access → `0.0.0.0/0`

URL: `https://bsnl-sim-api.onrender.com`

## API

| Method | Path |
|--------|------|
| GET | `/api/ready` |
| GET | `/api/health` |
| GET | `/api/sims` |
| POST | `/api/sims` |
| PUT | `/api/sims/:id` |
| DELETE | `/api/sims/:id` |
