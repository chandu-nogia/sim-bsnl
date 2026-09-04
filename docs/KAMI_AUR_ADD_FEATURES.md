# Kami, Risk, aur Add kiye ja sakte Features

**Date:** 4 September 2026  
Yeh file **alag** hai analysis se. Yahan sirf gaps aur future additions hain.

Priority:

- **P0** — jaldi fix (security / data risk)
- **P1** — product kami, daily use mein dikkat
- **P2** — accha enhancement
- **P3** — later / nice to have

---

## A. Abhi ki kami (gaps)

### P0 — Security

| # | Kami | Asar | Suggested fix |
|---|------|------|----------------|
| 1 | `AUTH_SECRET` default fallback source mein hai (`bsnl-sim-portal-change-me`) | Token guess / forge ho sakta hai | Render pe strong `AUTH_SECRET` set karo; fallback hatao production mein |
| 2 | `seedUsers()` **har server start par** admin + default employee ka password env/default se **overwrite** karta hai | Admin password change karo, restart ke baad wapas default | Seed sirf pehli baar insert; password `$set` mat karo |
| 3 | Default admin/employee emails + passwords code / env defaults mein | Source leak = account leak | Defaults hatao; pehla admin manually / one-time setup |
| 4 | Login pe **rate limit nahi** | Password brute-force | IP + email pe 5 fail / 10 min lock |
| 5 | Password minimum **4 characters** | Weak passwords | 8+ , number/symbol rule |
| 6 | CORS `origin: true` — koi bhi website API call kar sakti hai | Token wale browser se abuse | Sirf Vercel domain allow |
| 7 | JWT **30 din** | Chori hua token lamba chalta hai | 8–24h + refresh token; logout blacklist optional |
| 8 | Employee **khud password change** nahi kar sakta | Shared / leaked password stuck | Profile pe change-password API |

### P0 — Data / scale

| # | Kami | Asar | Suggested fix |
|---|------|------|----------------|
| 9 | `adminSummary()` **saari** `sims` / `cbc` / `ctopup` memory mein load karta hai | 10k+ rows par API slow / crash | Mongo `aggregate` + counts |
| 10 | Reports bhi full collections `find()` karte hain | Wahi scale problem | Date + location pe aggregate |
| 11 | List ke baad JS mein dubara `locationId` filter; `total` mismatch ho sakta hai | Pagination count galat | Sirf Mongo query, JS filter hatao |
| 12 | Location **name unique index nahi** | “Sikar” / “sikar ” / typo se duplicate locations | Unique normalized name index + confirm-before-create |
| 13 | Portal / CBC / CTopUp **hard delete** | Galti se data gaya to wapas nahi | Soft delete + Recycle bin (30 din) |

### P1 — Product / UX

| # | Kami | Asar |
|---|------|------|
| 14 | Employee **Forgot password** nahi | Admin pe depend |
| 15 | Profile sirf read-only — naam bhi employee nahi badal sakta | Chhoti update ke liye admin |
| 16 | Employee ko **Activity** nahi dikhta (apni location ke logs) | Khud ki galti track nahi |
| 17 | Settings mein API URL change — galat URL se app toot sakta hai | Production mein lock / hide |
| 18 | Amount string store (`"500"`) | Reports mein parse errors, sorting galat |
| 19 | Duplicate mobile / SIM / transactionId check nahi (location ke andar) | Double entry |
| 20 | Inactive location dashboard pe mix ho sakti hai | Confusing counts |
| 21 | Render **cold start** (free) | Pehla login 30–60s wait |
| 22 | Hindi + English mix messages | Training / screenshot mushkil |
| 23 | Google Sheets / Apps Script leftover files | Dead code, confusion |
| 24 | Automated tests sirf `test-isolation.js`; Flutter `widget_test` almost empty | Deploy ke baad regression |
| 25 | Backup / scheduled export nahi | Atlas outage = risk |
| 26 | Employee create karte time typo naya location bana deta hai | Extra ghost locations |

### P2 — Operations

| # | Kami |
|---|------|
| 27 | CI (GitHub Actions) nahi — test + analyze automatic nahi |
| 28 | Error monitoring (Sentry) nahi |
| 29 | Structured request logs / request-id nahi |
| 30 | Cloudflare Wrangler script leftover, use nahi ho raha |
| 31 | README chhota — naya aadmi setup nahi samajhta (ab `docs/` hai) |
| 32 | Dark mode / mobile-first layout incomplete (web table overflow) |
| 33 | PWA install / offline cache nahi |
| 34 | Android / desktop build official workflow nahi (sirf web) |

---

## B. Kya add kar sakte ho

Teen buckets: **jaldi useful**, **business growth**, **enterprise**.

### 1. Jaldi useful (1–2 week)

| Feature | Kyun |
|---------|------|
| **Change password** (employee + admin) | Security + independence |
| **Forgot password** (email OTP / admin temp link) | Lockout kam |
| **Soft delete + Recycle Bin** | Galti se delete recover |
| **Duplicate warning** — same mobile / SIM / Txn ID usi location mein | Data quality |
| **Confirm location on employee save** — “Sikar naya banega. OK?” | Ghost locations band |
| **Employee apni Activity** (sirf apni location) | Accountability |
| **Dashboard date filter** — aaj / week / month already numbers hain, UI filter add karo | Daily review |
| **CSV import** Portal / CBC (location scoped) | Purana Excel uthao |
| **Print / thermal receipt** CBC + CTopUp | Shop counter |
| **Stronger password + login lockout** | P0 security |
| **Seed password overwrite band** | P0 security |
| **Summary aggregates** | Dashboard speed |

### 2. Business / shop features

| Feature | Kyun |
|---------|------|
| **SIM stock / inventory** | Physical SIM pack in/out, low-stock alert |
| **Barcode / QR scan** SIM number | Typing error kam |
| **Customer photo / CAF / KYC file** (per Portal row) | Audit / BSNL visit |
| **FRC / plan tracking** better (expiry, pending FRC) | Follow-up list |
| **Pending vs Done** CTopUp workflow + settlement | Cash mismatch kam |
| **Daily closing** — employee din band kare, admin approve | Cash + count match |
| **Commission / target** location-wise | Incentive |
| **WhatsApp / SMS** customer ko SIM issued / recharge done | Service |
| **Multi-employee same location** leaderboard | Kaun kitna add kiya (report mein partial hai) |
| **Manager role** — 1 aadmi 2–3 locations, full admin nahi | District in-charge |
| **Holiday / shift** optional | Attendance later |
| **Notes / remarks** har entry par | Special cases |
| **Bulk status update** (Issued → Activated) | Portal cleanup |
| **Duplicate customer search** across Portal+CBC+CTopUp (same location) | 360° customer |

### 3. Admin / reports

| Feature | Kyun |
|---------|------|
| **Real charts** (14-day already backend mein) better UI | Decision |
| **Compare locations** — Khatu vs Sikar vs Jaipur ek screen | Performance |
| **Export all-location ZIP** (Excel per location) | Month end |
| **Scheduled email report** (daily 8pm) | Owner phone pe number |
| **Audit: who viewed / exported** | Leak track |
| **Location transfer** — employee move, old data wahi location pe rahe | Staff change |
| **Data retention policy** — 2 saal baad archive | DB size |
| **Restore from recycle / backup UI** | Recovery |

### 4. Technical / quality

| Feature | Kyun |
|---------|------|
| GitHub Actions: `flutter analyze` + `node test-isolation.js` | Safe deploy |
| Sentry (Flutter + Node) | Live errors |
| OpenAPI / Swagger | API document |
| Request rate limit middleware | Abuse |
| Helmet + CORS whitelist | Hardening |
| Unique `locationId + mobile` / `locationId + transactionId` index | Integrity |
| Amount as Number + currency | Correct sums |
| i18n — Hindi **ya** English toggle | Staff training |
| Android APK (same API) | Shop tablet / phone |
| Dark mode | Night shift |
| Session device list + “logout all” | Stolen phone |

---

## C. Add **nahi** karna (abhi)

| Idea | Kyun skip |
|------|-----------|
| Purana Khatu data Sikar/Jaipur mein copy | Isolation toot jayegi |
| Employee ko location dropdown / switcher | Spec violate |
| Frontend-only filter “security” | API se leak |
| Location name ko primary key banana | Rename tootega |
| Naya alag project rewrite | Existing architecture kaafi hai |
| Hard-delete location + saara data | Spec: deactivate, records safe |

---

## D. Suggested implementation order

Agar next sprint banana ho:

1. **P0 security** — AUTH_SECRET, seed overwrite band, rate limit, CORS lock, password rules  
2. **Change password + forgot password**  
3. **Soft delete / Recycle bin**  
4. **Duplicate checks + location confirm dialog**  
5. **Summary/reports Mongo aggregate** (speed)  
6. **CSV import + daily closing**  
7. **SIM stock + KYC photo**  
8. **Manager role + WhatsApp**  
9. **Android app + CI + Sentry**

---

## E. Short verdict

**Core kaam (location isolation) ab architecture-level par hai.**  
Kami mainly **security hardening**, **scale (full-table summary)**, **recoverability (soft delete)**, aur **shop-level features** (stock, daily close, import) ki hai.

Naya dashboard rewrite ki zaroorat nahi. Existing `backend/` + `bsnl_sim_portal/` par inhe layer karo.

Analysis: **[PROJECT_ANALYSIS.md](./PROJECT_ANALYSIS.md)**
