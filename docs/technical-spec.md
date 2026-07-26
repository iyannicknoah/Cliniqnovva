# Clinic Management System — Technical Specification (Cliniqnovva)

**Document purpose:** This is the complete functional and technical reference for the system. Hand this to an AI assistant or a developer so they understand every feature, rule, role, and data structure before any code is written.
**Primary product:** The **Clinic Management System (CMS)** — the admin/staff-facing product sold to clinics. The Patient Mobile App is a companion booking channel feeding into the same backend.
**Market:** Built specifically for **Rwanda**. Localization is not an afterthought — currency, address structure, phone format, ID numbers, language, timezone, insurance context, and public holidays follow Rwandan conventions throughout.
**Business model:** Platform owner (you) sells subscriptions to clinic **Clinics**, which may have one or more **Branches**. Patient and clinic-level payments are cash-in-hand; your subscription revenue from clinics is also collected manually/offline. See section 4.

---

## Table of Contents
1. Rwanda Localization
2. Tech Stack
3. System Architecture
4. Platform Structure — Clinics & Branches
5. User Roles & Permissions
6. Core Modules — Clinic Management System
7. Patient Mobile App
8. Staff Mobile App & Doctor Web Dashboard
9. Firebase Database Model
10. Security Model
11. Global Business Rules
12. Non-Functional Requirements
13. Open Decisions

---

## 1. Rwanda Localization

These conventions apply across every module and every collection in the system — not an add-on layer.

| Aspect | Rwandan Standard to Use |
|---|---|
| **Currency** | Rwandan Franc (RWF). Whole numbers only, no decimals. All monetary fields stored as integers. |
| **Phone numbers** | Format `+250 7XX XXX XXX`. Validate against Rwandan mobile prefixes (MTN: 078/079, Airtel: 073/072). Store in E.164 (`+2507XXXXXXXX`). |
| **National ID** | 16-digit Rwandan National ID. Optional field on patient profile — useful for identity verification, duplicate detection, and future insurance claims. |
| **Address structure** | Province → District → Sector → Cell → Village, not a flat free-text address. Province/District required; Sector/Cell/Village optional refinement. |
| **Language** | Kinyarwanda, English, and French (Rwanda's official languages; Swahili optional as a 4th). Language picker at first launch. All UI text built from translation keys from day one — never hardcoded strings. |
| **Timezone** | `Africa/Kigali` (UTC+2, no daylight saving). Store all timestamps in UTC, display in this timezone. |
| **Public holidays** | ~~Rwandan public holidays... stored and configurable so schedules auto-block them~~ — reversed 2026-07-26 (explicit user instruction): Rwandan clinics operate on public holidays like any other day, so booking is never auto-blocked on one. See section 6.5. |
| **Umuganda** | Mandatory community work on the last Saturday of each month affects operating hours for many businesses. Configurable per branch (e.g. "opens at 12pm on Umuganda Saturdays"). |
| **Health insurance context** | Many patients pay through **Mutuelle de Santé** (community-based insurance), **RSSB** medical schemes, or private insurers rather than 100% cash. Invoices must record the insurance-covered portion separately from the cash-paid portion, even without integrating an actual insurer API (section 6.7). |
| **Connectivity reality** | Not every patient has a smartphone or reliable data. The system must support **staff registering and booking on behalf of walk-in/non-app patients** (section 6.5A) — the Patient App is one channel in, not the only one. |

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Patient App | Flutter (Android/iOS) |
| Staff App (Doctor/Nurse) | Flutter, **mobile-only (Android/iOS phones)**. A tablet just runs this same app — treated as a phone form factor, not a separate build |
| Doctor Web Dashboard *(optional add-on)* | Web app for doctors at a computer — same backend as the mobile app, not a replacement for it (mobile stays mandatory) |
| Admin Dashboard | Web app (Flutter Web or React — decide before build; see section 13) |
| Backend | Node.js (REST API, e.g. Express/Fastify) |
| Database | Firebase (Firestore) |
| Auth | Firebase Authentication |
| File Storage | Firebase Storage (documents, X-rays, profile photos) |
| Notifications | Firebase Cloud Messaging (push, default) + SMS provider (fallback/critical alerts) |
| Payments | **Cash only — no online payment gateway.** System records payments made in person; no card/mobile-money processing integration required |
| Hosting | Firebase Hosting (admin web) + Cloud Functions / Node server (API) |
| Localization | i18n library (`flutter_localizations`/`easy_localization` for apps, `i18next` for Node) — Kinyarwanda, English, French |

---

## 3. System Architecture

```
[ Patient App ]   [ Staff App ]   [ Admin Web Dashboard ]
        \              |                 /
         \             |                /
          [ Node.js Backend API ]
                       |
        [ Firebase Auth | Firestore | Storage | FCM ]
```

**Rule:** No app writes directly to Firestore for anything that affects business logic (bookings, billing, medical records, staff/branch management). All writes go through the Node.js API, which validates and applies business rules before touching the database. Low-risk public reads (e.g. clinic search listings) may read Firestore directly if that's a deliberate architecture choice — otherwise everything goes through the API.

---

## 4. Platform Structure — Clinics & Branches

You sell to **Clinics** (a clinic business). Each Clinic has one or more **Branches** (physical locations).

```
Platform (you)
   └── Clinic (the customer you invoice — e.g. "Ya Clinic")
          └── Branch(es) (physical locations — e.g. "Kimihurura", "Remera")
```

| Level | Who controls it | Can do |
|---|---|---|
| **Platform** | **Super Admin (you)** | Create/suspend clinics; set subscription plan & branch limit; view platform-wide analytics; create a branch on an org's behalf for support (exception, not the norm) |
| **Clinic** | **Clinic Admin** (clinic owner/customer) | Create/manage their own branches day-to-day, up to plan limit; add/manage staff across branches; move staff between branches; view combined reports |
| **Branch** | **Branch Admin / Receptionist** | Day-to-day operations for one branch only — schedules, check-ins, patient records, billing at that location |

**Who creates a branch?** The Clinic Admin, as their normal everyday task, within their plan's branch limit. Super Admin creates the Clinic itself and sets the plan/limit, and can create a branch on an org's behalf only as a support exception.

**Branch creation is gated by subscription plan** (e.g. Basic = 1 branch, Pro = up to 5, Enterprise = unlimited). Backend checks current branch count against the plan limit before allowing a new one.

**Suspension:** Super Admin can suspend a clinic (e.g. non-payment of your subscription fee). This must immediately block API access for every user under that clinic — checked on every request, not just at login.

**Worked example — branch data isolation:**
"Ya Clinic" registers as one Clinic, with branches "Kimihurura" and "Remera".
- Every patient, appointment, invoice, and staff record is stamped with `branchId` (and `clinicId`).
- Staff at Kimihurura can only see records where `branchId` matches their own — never Remera's data, even though it's the same clinic business.
- The Clinic Admin (Ya Clinic's owner) is tied to `clinicId` only, not one branch, so their view combines both branches.
- Super Admin sees every clinic.
- This is enforced on the backend for every request — never assumed from the UI (see section 10).

**Platform subscription billing (you ↔ clinic):** Even though this is collected manually/in cash, the system should still **record** it — plan tier, billing cycle, amount due, payment history, and next-due date per clinic — so Super Admin has a clear picture of who's paid and who's overdue, without needing an actual payment gateway. See `/clinics` in section 9.

---

## 5. User Roles & Permissions

| Role | App(s) | Scope |
|---|---|---|
| Super Admin | Admin Web Dashboard | All clinics |
| Clinic Admin | Admin Web Dashboard | Own clinic, all its branches |
| Branch Admin | Admin Web Dashboard | One branch |
| Receptionist | Admin Web Dashboard | One branch |
| Accountant *(optional)* | Admin Web Dashboard | Own clinic or branch (configurable) |
| Pharmacist *(optional)* | Admin Web Dashboard or Staff App | One branch |
| Doctor | Staff App | Patients they treat, within their branch |
| Nurse | Staff App | Patients assigned for the day, within their branch |
| Patient | Patient App | Own data only |

Every account has exactly one role, assigned at creation, changeable only by Super Admin or Clinic Admin — never self-assigned.

**Staff onboarding flow:** New staff accounts are created by an Admin (not self-registered). The Admin enters name, role, branch, and contact info; the system sends an **invite link** (SMS or email) for the staff member to set their own password and complete their profile — rather than the Admin typing a password on their behalf. This is more secure and more practical for a Rwandan front-desk setting where the Admin may be onboarding several staff at once.

---

## 6. Core Modules — Clinic Management System

Each module lists: **Purpose**, **Functions**, **Roles Allowed**, **Conditions/Validation**.

### 6.1 Authentication & Access Control
**Purpose:** Secure login and role-based access for all staff.
**Functions:**
- Staff invite & first-login password setup (see section 5)
- Login (email or phone + password, Firebase Auth), logout, password reset
- Session/token management (Firebase ID tokens, refreshed regularly)
- Optional two-factor authentication for Super Admin and Clinic Admin accounts (highest-privilege roles)
- Role assignment & permission checks on every request
**Roles allowed:** Super Admin creates Clinic Admins; Clinic Admin/Branch Admin creates Doctors/Nurses/Receptionists/Pharmacists/Accountants for their branch(es).
**Conditions/Validation:**
- Email/phone must be unique across the system
- Password must meet minimum strength rules
- A deactivated account (`isActive: false`) must lose API access immediately — checked on every request, not just login
- Every API endpoint verifies the caller's role before executing — reject with 403 if mismatched
- Staff accounts are linked to exactly one branch (except Super Admin/Clinic Admin)

### 6.2 Clinic & Branch Management
**Purpose:** Manage the clinic business and its physical locations.
**Functions:**
- Super Admin: create/edit/suspend a clinic; set subscription plan, branch limit, and billing cycle
- Clinic Admin: create/edit/deactivate branches within plan limit — the normal, everyday way branches get added (name, address using Rwanda's Province/District/Sector/Cell/Village structure, contact, working hours, Umuganda override, services offered)
- Super Admin can create a branch on an org's behalf for onboarding support — an exception path
- Assign staff to a branch
- View clinic/branch list (scoped per role)
**Roles allowed:** Super Admin (all clinics), Clinic Admin (own clinic's branches)
**Conditions/Validation:**
- Clinic Admin can only edit/view data inside their `clinicId`
- New branch creation blocked if plan's branch limit already reached
- A branch cannot be hard-deleted if it has active appointments or staff — deactivate instead
- Working hours validated (opening time < closing time)
- Suspending a clinic blocks all its users' API access immediately

### 6.3 Staff Management
**Purpose:** Manage doctors, nurses, receptionists, pharmacists, accountants within a branch.
**Functions:**
- Add/edit/deactivate staff profile (name, role, specialty/department, contact, photo)
- Assign/reassign staff to a branch
- Set doctor/nurse schedules
- View staff list & profiles
**Roles allowed:** Clinic Admin (full control across own branches), Branch Admin (own branch), Super Admin (all)
**Conditions/Validation:**
- A doctor cannot be hard-deleted if they have appointment history — deactivate only
- Schedule slots must not overlap for the same staff member
- Only Clinic Admin/Super Admin can change a staff member's role

### 6.4 Departments & Service Catalog *(new)*
**Purpose:** Real clinics don't just have "doctors" — they organize by department/specialty (General Medicine, Dentistry, Pediatrics, Lab, etc.) and charge different, configurable prices for different services. This was missing from earlier drafts and matters for accurate booking and billing.
**Functions:**
- Define departments/specialties per branch (e.g. "Dental", "General Consultation", "Laboratory")
- Define a service catalog per branch: service name, default duration, default price in RWF, which department it belongs to
- Assign doctors to one or more departments
- When booking, patient/receptionist selects a service, which auto-fills expected duration and price (still editable by staff at billing time)
**Roles allowed:** Clinic Admin/Branch Admin (manage catalog), Receptionist/Patient (select service when booking), Doctor (view own department's services)
**Conditions/Validation:**
- A service's default duration must be a positive number consistent with the branch's slot-duration configuration
- Deleting a service that has appointment/invoice history is blocked — deactivate instead

### 6.5 Doctor Schedule & Availability
**Purpose:** Define when each doctor is bookable and drive real-time slot availability.
**Functions:**
- Set recurring weekly availability
- Set a break (minutes) required between one appointment and the next
- Block specific dates/times (leave, emergencies)
- Respect Umuganda-Saturday overrides
- View calendar of upcoming appointments per doctor

**2026-07-26 addition (explicit user instruction) — per-doctor appointment
buffer:** `doctors/{uid}.breakMinutes` (integer, default 0), set on the same
"Weekly schedule" card as the recurring-availability editor
(`_WeeklyScheduleSection` in `doctor_schedule_screen.dart`), saved together
via the existing `PUT /staff/:id/schedule` endpoint (now
`{schedule, breakMinutes}` instead of just `{schedule}`). `getAvailableSlots`
in `appointments.service.js` pads every booked appointment AND every
manually blocked slot by `breakMinutes` on both sides before checking a
candidate slot against it (`overlapsWithBuffer`) — so e.g. a 60-min
appointment at 2:00 with a 10-min break makes 3:10 the next real slot, not
3:00. Padding both sides (not just after) means the gap holds regardless of
which of two appointments got booked first. `book()` and `reschedule()`
re-apply the same buffered check inside their transactions — never trust a
slot list the client fetched moments earlier, same principle as the
double-booking guard. See `backend/test/appointments.test.js` for the
worked examples.

**2026-07-26 reversal (explicit user instruction):** public holidays no
longer auto-block booking — Rwandan clinics operate on public holidays same
as any other day, so this line's original "auto-block Rwandan public
holidays" is no longer accurate. The blocking check was removed from
`effectiveScheduleWindows` in `backend/src/services/appointments.service.js`,
and the "Public holidays" section (with its "Auto-blocked unless overridden"
copy and per-holiday override toggle) was removed from the Doctor Schedule
screen along with its now-dead frontend provider/model. The `publicHolidays`
Firestore collection, its CRUD routes, and `branches.holidayOverrides` are
left in place (harmless, unused) rather than torn out — no in-app UI ever
wrote to them beyond the now-removed toggle.
**Roles allowed:** Doctor (view own), Branch Admin/Receptionist (edit any doctor's schedule in their branch)
**Conditions/Validation:**
- Blocking a date/time that conflicts with existing bookings must flag them for staff review, never silently drop them
- Slot duration configurable per branch/service, consistent within a branch
- Booking a slot that's already taken must be prevented atomically (see 6.6)

### 6.5A Walk-In & Non-App Patient Registration *(new — important for Rwanda)*
**Purpose:** Not every patient has a smartphone or the app installed. Receptionists must be able to register a patient and book/manage their visit entirely from the front desk, with the same data model as an app-registered patient.
**Functions:**
- Receptionist creates a patient profile directly (name, phone, DOB, national ID if available, address) without the patient needing the app
- Receptionist books, reschedules, or checks in an appointment on behalf of this patient
- If the patient later installs the Patient App, they can be linked to their existing record (matched by phone number or National ID) rather than creating a duplicate
**Roles allowed:** Receptionist, Branch Admin
**Conditions/Validation:**
- Phone number is the minimum required identifier for a walk-in patient (no email required)
- The system should warn (not block) if a similar name+phone or matching National ID already exists, to reduce duplicate patient records — see 6.6A
- A walk-in-registered patient must have identical data structure and privacy rules as an app-registered one — no second-class record type

### 6.6 Patient Records (EMR/EHR)
**Purpose:** Digital medical record per patient, accessible to authorized staff.
**Functions:**
- Create/view/update patient profile (demographics, National ID, Rwanda address structure, emergency contact)
- Record medical history, allergies, chronic conditions
- Add visit notes, diagnoses, prescriptions per appointment
- Upload/view documents (lab results, X-rays, scans) via Firebase Storage, compressed before upload
- View full visit history timeline
- **Patient search** by name, phone, or National ID — needed constantly at the front desk
**Roles allowed:** Doctor (full read/write for patients they treat), Nurse (read + vitals entry), Receptionist (demographic/contact info only — never clinical notes), Patient (read-only, own record)
**Conditions/Validation:**
- Receptionist must never access clinical notes/diagnoses/prescriptions — enforced at API level, tested explicitly, not just hidden in UI
- Every write tagged with author ID and timestamp for the audit log
- Patient can view but never edit their own record
- Sensitive fields (diagnosis, prescriptions) encrypted at rest if Firestore rules alone aren't considered sufficient

### 6.6A Duplicate Patient Detection *(new)*
**Purpose:** With both app self-registration and front-desk walk-in registration creating patient records, duplicates are a real risk (e.g. same person registered twice under slightly different name spelling).
**Functions:**
- On new patient creation, check for existing records with matching phone number or National ID
- If a likely match is found, prompt staff to confirm "is this the same person?" before creating a new record
- Allow Clinic Admin/Branch Admin to manually merge two patient records if a duplicate slipped through (merges appointment/medical history under one patient ID, logs the merge action)
**Roles allowed:** Receptionist (prompted at registration), Branch Admin/Clinic Admin (manual merge)
**Conditions/Validation:**
- Merge action must be logged in the audit trail with both original record IDs
- Medical record history must never be lost during a merge — only consolidated

### 6.7 Appointment Management (Booking Engine)
**Purpose:** Central booking engine — the core operational feature.
**Functions:**
- View daily/weekly appointment calendar (per doctor, per branch)
- Confirm, reschedule, cancel an appointment
- Check in a patient on arrival
- Mark appointment completed
- Handle walk-in bookings (section 6.5A)
- **Queue/ticket display** — show a simple waiting-number/queue status for walk-in patients at the branch, so front desk and waiting patients know order of service *(new — common practical need in busy Rwanda clinics)*
- Sync bookings from the Patient App in real time
**Roles allowed:** Receptionist (full management), Doctor (view own, mark complete), Branch Admin/Clinic Admin (full oversight)
**Conditions/Validation:**
- **Double-booking prevention:** re-check slot availability at confirmation time using a Firestore transaction, to avoid race conditions between simultaneous bookings
- Cancelling frees the slot and notifies the patient
- Appointment cannot be marked completed until check-in has occurred
- Rescheduling re-validates against current doctor availability
- Every status change logged with timestamp

### 6.8 Billing & Invoicing
**Purpose:** Generate and track charges for consultations, tests, and services. **Payment method is cash only** — the system records payment, it does not process any online transaction.
**Functions:**
- Auto-generate invoice after appointment completion, pre-filled from the service catalog (section 6.4)
- Manually add/edit line items
- Record a cash payment (full or partial)
- Record an insurance-covered portion (Mutuelle de Santé, RSSB, or private insurer) separately from the cash-paid portion
- Track paid/unpaid/partial/voided status
- Generate/print receipts (in RWF)
**Roles allowed:** Receptionist/Accountant (create & manage), Branch Admin/Clinic Admin (view/reports), Patient (view own invoice/receipt — read only)
**Conditions/Validation:**
- Invoice total always equals sum of line items — recalculated server-side, never trusted from client input
- `insuranceCoveredAmountRwf + cashPaidAmountRwf` must never exceed `totalAmountRwf`
- Recording a cash payment updates `amountPaid`/`status` on the invoice — no gateway callback to reconcile
- Invoice cannot be deleted once a payment is recorded — only voided with a logged reason
- Partial payments update the running balance, not overwrite it
- All amounts in RWF, whole numbers

### 6.9 Inventory / Pharmacy Management *(optional module)*
**Purpose:** Track medicine/supply stock for clinics with an in-house pharmacy.
**Functions:**
- Add/edit stock items (name, quantity, unit, expiry date)
- Deduct stock when medicine is dispensed against a prescription
- Low-stock alerts
- Stock adjustment log (damages, corrections)
**Roles allowed:** Pharmacist (full control), Branch Admin/Clinic Admin (view/reports)
**Conditions/Validation:**
- Stock quantity never goes negative — block dispensing if insufficient, flag for reorder instead
- Every stock change logged with reason and staff ID
- Expired stock flagged and excluded from "available to dispense"

### 6.10 Reports & Analytics
**Purpose:** Turn operational data into business insight.
**Functions:**
- Revenue reports (daily/weekly/monthly, per doctor, per branch, per service)
- Patient volume/traffic reports, no-show rate
- Multi-branch roll-up per clinic, and multi-clinic comparison (Super Admin only)
- **Export reports** to CSV/PDF for offline sharing *(new)*
**Roles allowed:** Branch Admin (own branch), Clinic Admin (own clinic, all branches), Super Admin (all clinics), Accountant (financial reports)
**Conditions/Validation:**
- Reports computed from finalized/completed records only, not pending/draft data
- Date range filters validate start ≤ end
- Heavy report queries handled via scheduled Cloud Functions/aggregation, not live queries on every request

### 6.11 Notifications
**Purpose:** Keep staff and patients informed automatically.
**Functions:**
- Appointment confirmation, reminder, cancellation alerts
- New booking alert to receptionist/doctor
- Low-stock alert to pharmacist
- Payment-recorded confirmation to patient (cash payment logged, not an online transaction)
**Roles allowed:** System-triggered; visible to relevant role only
**Conditions/Validation:**
- Triggered by backend events, not client-side, so they fire even if the app is closed
- Push (FCM) is the default free channel; SMS reserved for patients without the app or for critical alerts, to control cost
- Must respect notification preferences (opt-out for non-critical alerts)
- Failed delivery retried or logged, not silently dropped

### 6.12 Audit Logs — **REMOVED 2026-07-24**
**Status:** this entire feature was removed by explicit instruction (general
activity-log feature retired system-wide) — the `/auditLogs` collection, its
backend service/controller/routes, and the `/audit-log` screen no longer
exist. Kept below as a historical record of the original spec, not a
description of the live system. `/patientMergeLogs` (6.6A) is a separate,
narrower feature that was NOT removed — it's the merge tool's own history
record, load-bearing for "medical record history must never be lost during
a merge," not a general audit trail.

**Purpose:** Accountability — who did what, when, especially for medical and financial data.
**Functions:**
- Log every create/update/delete on: patient records, appointments, invoices, staff accounts, patient merges
- View logs (filter by user, date, action type)
**Roles allowed:** Super Admin/Clinic Admin (view only — logs are never editable by anyone)
**Conditions/Validation:**
- Append-only — no update/delete operation ever exposed for this collection
- Every entry includes actor ID, role, action, target record ID, timestamp

### 6.13 Patient–Clinic Chat *(new)*
**Purpose:** Let a patient message a clinic branch directly — either to follow up on a recent appointment, or to ask a general question to a branch they've **never booked with before** (hours, services, whether a doctor is available, etc.). This is a pre-booking and post-booking communication channel, not tied to having an existing appointment.
**Functions:**
- Patient starts a chat with any branch listed in the app — no prior booking required
- Patient's chat list groups threads by clinic/branch, including ones they've booked with before
- A chat can optionally be linked to a specific appointment for context (e.g. "regarding your visit on July 20"), but this is optional, not required to start chatting
- Receptionist/Branch Admin at that branch sees an inbox of patient chats and replies
- Push notification to both sides on new message
**Roles allowed:** Patient (start/reply to any branch), Receptionist/Branch Admin (reply on behalf of the branch), Doctor *(optional — only for threads explicitly linked to their own appointment; decide as open item, section 13)*
**Conditions/Validation:**
- **A chat belongs to the branch, not to one individual staff member.** This matters for shift handoffs — if the receptionist who was replying goes off shift, any other staff member at that branch can pick up the same conversation seamlessly, without the patient needing to start over.
- Chat messages are **not part of the medical record** — they must not be treated as clinical advice or a diagnosis; consider a short in-app disclaimer ("For medical concerns, please book an appointment") shown in the chat screen.
- Chat needs to feel instant, so — as a deliberate, documented exception to the "no direct client writes" rule elsewhere in this spec — chat messages may be written directly to Firestore by the client, using real-time listeners, **strictly scoped by security rules** to participants of that specific chat thread only (the patient who owns it, and any staff whose `branchId` matches).
- Basic rate limiting on starting new chats, to prevent spam (e.g. one patient messaging many branches in a short burst)
- Messages are soft-deleted only (never hard-deleted) — kept for accountability and viewable by Clinic Admin/Super Admin if a dispute needs review

**Data model addition:**
```
/chats/{chatId}
    patientId, branchId, clinicId
    appointmentId (optional — null if it's a general inquiry, not tied to a visit)
    lastMessage, lastMessageAt, createdAt
    status: "open" | "closed"
/chats/{chatId}/messages/{messageId}
    senderId, senderRole, text, createdAt, isRead
```

---

## 7. Patient Mobile App

**Functions:**
- Register/login (Firebase Auth — phone or email)
- Search clinics/doctors/departments (by specialty, location, rating)
- View doctor availability and book appointment (selecting a service from the catalog)
- Reschedule/cancel own appointment
- View own medical history, prescriptions, invoices/receipts
- Receive notifications/reminders
- Rate/review doctor or clinic after a completed appointment
- Link to an existing walk-in-created record (matched by phone/National ID) instead of duplicating it
- **Chat with any clinic branch** — a recently booked one, or one never booked with before (section 6.13)
**Conditions/Validation:**
- Patients pay in cash at the branch — the app only displays invoice/receipt status, never processes payment
- A patient can only view/edit their own data (`patientId` must match authenticated user)
- Booking goes through the same slot-validation logic as the CMS (6.7) — no separate booking path
- Reviews only after a completed appointment
- Chat does not require a booking or prior relationship with the branch — see 6.13 for full rules

---

## 8. Staff Mobile App & Doctor Web Dashboard

**Staff App is mobile-only and mandatory** for every employee — doctors, nurses, receptionists, pharmacists, accountants, branch/clinic admins who need on-the-go access. If someone uses a tablet, it simply runs the same mobile app — there is no separate tablet-optimized build or UI; a tablet is treated as a (larger) phone.

**Doctor Web Dashboard is optional, additive, and doctor-only.** When a doctor is at a computer, they can log into a web dashboard (same backend, same data) for tasks that are easier on a bigger screen — e.g. reviewing longer patient histories, writing detailed notes. This does **not** replace the mandatory mobile app; it's an extra access point for doctors specifically, not for nurses/receptionists/other staff.

**Doctor functions (mobile — mandatory, and web dashboard — optional):**
- View schedule/appointments
- Access assigned patients' records
- Add diagnosis, prescription, visit notes
- Mark appointment complete

**Nurse functions (mobile only):**
- View assigned patients for the day
- Record vitals (BP, temperature, weight, etc.)
- Assist doctor with pre-consultation prep

**Conditions/Validation:**
- Same record-access rules as section 6.6 apply across mobile and web — different clients, same backend, not a separate data path
- The optional Doctor Web Dashboard must never expose functionality unavailable on mobile that would make mobile a "lesser" experience — mobile remains the primary, fully-capable client
- Offline behavior for the mobile app is explicitly decided later (cache last-loaded schedule/patients, sync when back online) — flagged as an open decision (section 13)

---

## 9. Firebase Database Model (Firestore)

```
/clinics/{clinicId}
    name, ownerContact, subscriptionPlan: "basic" | "pro" | "enterprise"
    branchLimit, billingCycle, subscriptionAmountRwf, nextDueDate
    subscriptionPaymentHistory: [ { date, amountRwf, recordedBy } ]
    isActive, createdAt
/branches/{branchId}
    clinicId, name
    location: { province, district, sector, cell, village }
    phone, workingHours, umugandaSaturdayHours (optional override)
    servicesOffered, isActive
/departments/{departmentId}
    branchId, name (e.g. "Dental", "General Consultation", "Laboratory")
/services/{serviceId}
    branchId, departmentId, name, defaultDurationMins, defaultPriceRwf, isActive
/users/{userId}
    role: "superAdmin" | "clinicAdmin" | "branchAdmin" | "doctor" | "nurse" | "receptionist" | "pharmacist" | "accountant" | "patient"
    clinicId (null for superAdmin/patient)
    branchId (null for superAdmin/clinicAdmin/patient)
    name, phone (+250 E.164 format), email, photoUrl
    preferredLanguage: "rw" | "en" | "fr"
    isActive, createdAt
/doctors/{userId}                       // extends /users via same ID
    specialty, bio, departmentIds: [ ]
    schedule: [ { day, startTime, endTime, slotDurationMins } ]
    breakMinutes                            // buffer required between appointments, default 0 (2026-07-26)
    blockedSlots: [ { date, startTime, endTime, reason } ]
/patients/{patientId}                   // extends /users via same ID
    nationalId (16-digit, optional)
    dateOfBirth, gender, emergencyContact, allergies, chronicConditions
    location: { province, district, sector, cell, village }
    registeredVia: "app" | "walkIn"
    linkedAppAccountId (null until a walk-in patient later links their app account)
/appointments/{appointmentId}
    patientId, doctorId, serviceId, branchId, clinicId
    date, startTime, endTime
    status: "pending" | "confirmed" | "checkedIn" | "completed" | "cancelled"
    queueNumber (for walk-in display)
    createdBy, createdAt, updatedAt
/medicalRecords/{recordId}
    patientId, doctorId, appointmentId
    diagnosis, prescriptions: [ { medicineName, dosage, duration } ]
    notes, attachments: [ storagePaths ]
    createdAt, authorId
/invoices/{invoiceId}
    patientId, branchId, appointmentId
    lineItems: [ { description, amountRwf } ]
    totalAmountRwf, cashPaidAmountRwf, insuranceCoveredAmountRwf
    insuranceScheme: "mutuelle" | "rssb" | "private" | "none"
    status: "unpaid" | "partial" | "paid" | "voided"
    paymentMethod: "cash"
    recordedBy, createdAt
/inventory/{itemId}                     // optional module
    branchId, name, quantity, unit, expiryDate, reorderLevel
/reviews/{reviewId}
    patientId, doctorId, branchId, appointmentId
    rating, comment, createdAt
/publicHolidays/{holidayId}
    name, date, appliesNationwide
/patientMergeLogs/{mergeId}
    survivingPatientId, mergedPatientId, mergedBy, timestamp
/notifications/{notificationId}
    userId, type, message, isRead, createdAt
```
(`/auditLogs/{logId}` — actorId, actorRole, action, targetCollection, targetId,
timestamp — removed 2026-07-24, see section 6.12.)

---

## 10. Security Model

- Every collection's Firestore rules check `request.auth.uid` against role, `clinicId`, and `branchId` before allowing read/write
- Clinical and financial writes (`medicalRecords`, `invoices`, `appointments` status changes) go through the Node.js backend using the Firebase Admin SDK — never direct client writes — so business logic (double-booking checks, invoice recalculation, branch-limit checks) is always enforced
- `patientMergeLogs`: `allow write: if false` for all clients — written only by backend (`auditLogs` no longer exists, removed 2026-07-24)
- **Branch data isolation is mandatory:** every query for patients, appointments, invoices, medical records, or staff must be filtered by the requester's `branchId` (or `clinicId` for a Clinic Admin, or nothing for Super Admin). No endpoint should ever leak data across branches, even by an accidental missing filter
- Two-factor authentication recommended for Super Admin/Clinic Admin accounts
- API rate limiting on authentication endpoints to prevent brute-force attempts

---

## 11. Global Business Rules

- Every write records `createdAt`/`updatedAt` and, where relevant, `updatedBy`
- No record is ever hard-deleted if it has dependent history (staff, doctors, invoices, patients) — use `isActive: false` / soft delete
- All monetary calculations (invoice totals, balances) happen server-side, never trusted from client input
- All date/time comparisons account for the branch's configured timezone
- Role permission checks happen on the backend for every request — the UI hiding a button is not a security control
- Patient records created via walk-in registration and via the app follow identical structure and privacy rules — no second-class data path

---

## 12. Non-Functional Requirements

- **Scalability:** support multiple clinics, each with multiple branches, from day one in the data model
- **Security:** Firebase Auth + Firestore rules + backend role checks (defense in depth)
- **Performance:** paginate large lists (patients, appointments, logs); avoid unbounded Firestore queries
- **Compliance:** design with HIPAA/GDPR-style data protection principles in mind (encryption, access logs, data minimization, patient consent tracking)
- **Reliability:** critical operations (booking, invoice recording) use Firestore transactions to avoid race conditions
- **Backup & disaster recovery:** scheduled Firestore backups (e.g. daily) with a documented restore procedure; not just relying on Firestore's default durability
- **Accessibility for low connectivity:** Staff App should degrade gracefully on weak signal; consider whether SMS/USSD-based booking is worth exploring later for patients without smartphones (flagged as a future consideration, not v1 scope)

---

## 13. Open Decisions to Finalize Before Development

- Admin Dashboard: Flutter Web or a separate web framework (e.g. React)?
- Offline support scope for the Staff App
- Which SMS/notification provider — check local delivery reliability for MTN/Airtel Rwanda numbers
- Whether Pharmacist/Accountant modules are included in v1 or added later
- Subscription plan tiers, branch limits, and billing cycle (monthly/quarterly) — exact numbers in RWF
- Data retention & backup policy for medical records
- Default app language (Kinyarwanda vs English) and whether Swahili is needed
- Whether to pre-load a static list of Rwandan public holidays for the current year or let Clinic Admins manage their own
- Whether queue/ticket numbering is a simple in-app counter or needs a physical ticket printer integration at busy branches
- Whether future USSD/SMS-based booking for non-smartphone patients is worth investing in, and on what timeline
- Whether Receptionist needs a mobile option to reply to patient chats (section 6.13) on the go, in addition to the Admin Web Dashboard inbox, or if desk-based replying is sufficient for v1
- Whether Doctors should be able to see/reply to chats linked to their own appointments from the mobile Staff App, or whether all chat replying stays with Receptionist/Branch Admin only
