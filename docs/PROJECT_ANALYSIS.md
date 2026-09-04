# BSNL SIM Portal — Project Analysis

**Date:** 4 September 2026  
**Repo:** https://github.com/chandu-nogia/sim-bsnl  
**API version:** `locations-5`  
**Live UI:** https://web-rosy-seven-32.vercel.app  
**Live API:** https://bsnl-sim-api.onrender.com

Yeh document existing codebase ka inspection-based analysis hai. Naya project nahi, jo already chal raha hai uska map.

---

## 1. Project kya hai

BSNL shop / CSC management dashboard.

Admin locations aur employees banata hai. Har employee sirf apni assigned location ka data dekhta hai:

- **BSNL Portal** — SIM / new user register (CYMN, MNP, Swap, Postpaid)
- **CBC List** — bill / CBC payments
- **CTopUp** — recharge / top-up entries

Teen alag locations (jaise Khatu Shyam Ji, Sikar, Jaipur) ka data isolated rehna chahiye. Delete / update / create ek location mein doosri location ko touch nahi kare.

---

## 2. Architecture

```
Flutter Web (Vercel)
        |
        |  HTTPS + JWT  Authorization: Bearer
        |  Admin optionally sends X-Location-Id
        v
Express API (Render)          version: locations-5
        |
        v
MongoDB Atlas                 database: bsnl_sim
```

| Layer | Folder | Tech | Host |
|-------|--------|------|------|
| UI | `bsnl_sim_portal/` | Flutter Web, Dart 3.13 | Vercel |
| API | `backend/` | Node 18+, Express 4 | Render |
| DB | Atlas | MongoDB 6 driver | `bsnl_sim` |

Core rule:

```
Location
   ├── Employees   (locationId)
   ├── BSNL Portal / sims
   ├── CBC
   └── CTopUp
```

Join key **location name nahi**, **numeric `locationId`** hai (1, 2, 3…). Rename karne par ID same rehti hai.

---

## 3. Roles

### Admin

- Sab locations, employees, Portal / CBC / CTopUp
- Location create / edit / deactivate
- Employee create / edit / delete / password reset
- Dashboard totals + location-wise overview
- Reports, Activity Logs, Settings (API URL)

### Employee

- Sirf apni assigned location
- Portal / CBC / CTopUp CRUD usi location par
- Profile (read-only)
- Location change nahi kar sakta
- Frontend se bheja `locationId` trust nahi hota — backend JWT user se nikalta hai

---

## 4. Database collections

| Collection | Type | Key fields |
|------------|------|------------|
| `locations` | Global master | `id`, `name`, `code`, `status`, `createdAt`, `updatedAt` |
| `users` | Location (employees) / Global (admin) | `id`, `name`, `email`, `passwordHash`, `role`, `locationId`, `assignedLocations`, `status` |
| `sims` | Location data | Portal fields + `locationId`, `createdBy`, `employeeId` |
| `cbc` | Location data | name, mobile, landline, amount, transactionId + `locationId` |
| `ctopup` | Location data | name, number, amount, status, transactionId + `locationId` |
| `activity` | Location-aware log | `email`, `action`, `section`, `locationId`, `detail`, `at` |
| counters | Internal | `nextId` sequences |

Indexes (startup par `ensureIndexes`):

- `users.email` unique
- `locations.id` unique
- `sims` / `cbc` / `ctopup`: `{ locationId, id }`, `createdAt`, `createdBy`
- `activity`: `{ locationId, at }`, `{ email, at }`

---

## 5. Authentication flow

1. `POST /api/login` — email + password
2. Inactive user → 403
3. `bcrypt` compare
4. JWT 30 days — payload mein `userId`, `role`, `locationId`
5. Har protected route `requireUser` se **DB se user dubara load** karta hai
6. Employee scope = `user.locationId` (client header ignore)

Employee write:

```
authenticate → employee.locationId → stamp on new row
update/delete → WHERE id AND locationId
cross-location → 403 / 404
```

Admin list bina location ke empty scoped query use karta hai (mixed dump nahi), dashboard summary alag API se aati hai.

---

## 6. API map

Existing names preserve kiye gaye hain (`/api/sims` Portal ke liye).

| Method | Path | Access |
|--------|------|--------|
| GET | `/api/ready` | Public — version |
| GET | `/api/health` | Public — Mongo ping |
| POST | `/api/login` | Public |
| GET | `/api/me` | Logged in |
| GET/POST/PUT/DELETE | `/api/locations` | Admin write; list scoped |
| GET/POST/PUT/DELETE | `/api/employees` | Admin |
| POST | `/api/employees/:id/reset-password` | Admin |
| GET | `/api/summary` | Admin |
| GET | `/api/summary/location/:id` | Own location / admin |
| GET | `/api/reports` | Admin |
| GET | `/api/activity` | Scoped |
| GET/POST/PUT/DELETE | `/api/sims` | Location scoped |
| GET/POST/PUT/DELETE | `/api/cbc` | Location scoped |
| GET/POST/PUT/DELETE | `/api/ctopup` | Location scoped |

Search aur pagination Mongo query par `locationId` ke saath chalte hain.

---

## 7. Flutter screens

| Screen | File | Kaun dekhe |
|--------|------|------------|
| Login | `login_page.dart` | Public |
| Dashboard | `dashboard_page.dart` | Dono |
| Locations | `locations_page.dart` + form | Admin |
| Employees | `employees_page.dart` | Admin — Location **text input** |
| BSNL Portal | `home_page.dart` + form/table | Dono (scoped) |
| CBC | `cbc_page.dart` | Dono |
| CTopUp | `ctopup_page.dart` | Dono |
| Reports | `reports_page.dart` | Admin |
| Activity | `activity_page.dart` | Admin |
| Settings | `settings_page.dart` | Admin — API URL |
| Profile | `profile_page.dart` | Employee — location locked |
| Users (admin nav) | same Portal grid | Admin “Users” = Portal list |

Employee sidebar: Dashboard, BSNL Portal, CBC List, CTopUp, Profile, Logout.  
Header: `Assigned Location: …` — koi location switcher nahi.

Admin sidebar: Locations / Employees / Portal / CBC / CTopUp ke andar All Locations + har location.

Exports: Excel (`excel_export.dart`), PDF (`pdf_export.dart`).

---

## 8. Location isolation — current status

**Root cause (pehle):** ek hi Mongo document sab employees ko dikhta tha, aur DELETE sirf `{ id }` se hota tha. ID global unique hone ki wajah se Khatu delete Sikar/Jaipur ko bhi hata deta tha.

**Ab:**

- Employee GET/POST/PUT/DELETE backend par `locationId` se bound
- Client `locationId` / `X-Location-Id` employee ke liye ignore
- Unscoped old rows sirf Khatu ko map — duplicate copy nahi
- Location “delete” = `status: inactive` — records safe
- Unit check: `backend/scripts/test-isolation.js`

Agar kisi employee ka Atlas `locationId` abhi bhi Khatu hai, to usko Khatu data dikhega. Fix: Admin → Edit employee → location name type karke save.

---

## 9. Important backend files

| File | Kaam |
|------|------|
| `backend/server.js` | Routes, CORS, writeMeta |
| `backend/lib/auth.js` | Login, JWT, seed, locations |
| `backend/lib/rbac.js` | listScope / writeScope |
| `backend/lib/location_resolve.js` | Name → locationId, find-or-create |
| `backend/lib/employees.js` | Employee CRUD |
| `backend/lib/sims.js` | Portal CRUD |
| `backend/lib/records.js` | CBC + CTopUp |
| `backend/lib/summary.js` | Admin dashboard numbers |
| `backend/lib/reports.js` | Location / employee reports |
| `backend/lib/activity.js` | Audit log |
| `backend/lib/indexes.js` | Indexes |
| `backend/lib/db.js` | Mongo client |

---

## 10. Important frontend files

| File | Kaam |
|------|------|
| `lib/main.dart` | App + login gate |
| `lib/state/auth_store.dart` | Token, role, location lock |
| `lib/state/sim_store.dart` | Portal list/cache |
| `lib/services/api_service.dart` | HTTP client |
| `lib/widgets/app_shell.dart` | Sidebar + routing |
| `lib/screens/employees_page.dart` | Location text field |
| `lib/data/seed.dart` | Local/dev seed (release API use karta hai) |

---

## 11. Jo already theek hai

- Location isolation backend + DB level par
- Employee location text input (dropdown nahi)
- Location rename ID nahi todta
- Inactive employee login nahi kar sakta
- Inactive location par employee write block
- Activity log mein locationId
- Admin all-location overview + per-location view
- Search / pagination location-aware
- Excel / PDF export
- Live deploy: Vercel + Render + Atlas

---

## 12. Related document

Kami, security holes, aur add kiye ja sakne wale features:

**[KAMI_AUR_ADD_FEATURES.md](./KAMI_AUR_ADD_FEATURES.md)**
