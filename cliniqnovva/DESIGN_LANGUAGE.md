# Cliniqnovva Design Language

The single source of truth for how Cliniqnovva looks. **Every design change must
be reflected here in the same commit that changes the code**, so the system stays
consistent as it grows. Code lives in `lib/core/theme/` (tokens) and
`lib/shared/widgets/` (components) — screens must always use the shared
components, never raw Material widgets (`ElevatedButton`, `TextField`, etc.).

## Typography

- **Font: General Sans** (`AppTheme.fontFamily`), bundled from Fontshare
  (`assets/fonts/`, license in `LICENSE.txt`). Weights: Regular 400, Medium 500,
  Semibold 600, Bold 700.
- **No italic text anywhere, ever.** No italic weights are bundled and a widget
  test enforces this on the login screen.

## Colors (`AppColors`)

**The brand lime (`#CFFF04`) is retired as of 2026-07-24 — `AppColors.primary`
no longer exists.** The system "primary" is now `context.appPrimary`
(`theme_ext.dart`): **black in light mode, white in dark mode.** This also
seeds the app's `ColorScheme` (`ColorScheme.fromSeed(seedColor: Colors.black`
/`Colors.white)`), so any default-Material-styled control (dialog action
buttons, etc.) that reads `colorScheme.primary` automatically follows suit —
don't reintroduce a colored accent as "primary" anywhere.

**`AppColors.skyBlue` (`#38BDF8`) is the system's second primary color
(2026-07-23)** — the one deliberate exception to "no color accent." Used for
the Overview revenue chart (line + a more-transparent fill beneath it),
`AvatarWidget`'s ring (2026-07-25, was `context.appPrimary`), and every star
rating + rating-distribution bar in the Reviews feature (2026-07-25, was
`AppColors.pillAmberText`/amber). Reach for this before introducing any other
accent color; it isn't a per-chart one-off.

| Token | Value | Use |
|---|---|---|
| `pageBackground` | `#FFFFFF` (pure white) | Every page/scaffold background, input fills, containers (light mode) |
| `pageBackgroundDark` | `#000000` (pure black) | Same role as `pageBackground`, dark mode (rule set 2026-07-23) |
| `textPrimary` | `#0B2545` | Headings/body text, light mode only — use `context.appText` (theme-aware) for anything that also renders in dark mode |
| `textSecondary` | `#5B6B73` | Labels/captions, light mode only — use `context.appSubtext` for theme-aware text |
| `successGreen` / `warningAmber` / `errorRed` | `#2ECC71` / `#F4A261` / `#E63946` | Status semantics |
| Pill pairs (`pillGreenBg/Text` etc.) | — | Inline banners only (e.g. login error, Add Clinic error box) — no longer used for `StatusBadge` |
| `brightGreen` / `brightRed` | `#34C759` / `#FF3B30` | `StatusBadge` success/error text (2026-07-23) — bright, no background |
| `skyBlue` | `#38BDF8` | Second primary/accent (2026-07-23) — Overview revenue chart line + fill |
| `avatarGradients` | 26 letter-keyed gradients | Avatar initials |

`deepNavy` was deleted entirely (2026-07-24) along with the five
`sidebar*`-prefixed constants Part 17 added for it — see the "no mixing
colors" rule below and the change log.

## No mixing colors (rule set 2026-07-23, copied from HRNova)

**A card/container must be the exact same flat color as the page it sits on.**
Pure white page → white cards. Pure black page (dark mode) → black cards.
Never give a card a distinct "secondary" shade — differentiate it from the
page with a **1px border only** (`AppTheme.cardBorderSide`/`context.appBorder`),
never a background-color difference. `AppTheme.cardColor(context)` and
`context.appCard` both resolve to the exact same value as the scaffold
background, in both themes — if you ever see them diverge, that's a bug.

**No card shadow, in either theme (rule 2026-07-24).** `CliniqnovvaCard` used
to carry a translucent-lime `boxShadow` (`AppTheme.cardShadow`, now deleted) —
it read as a muddy haze rather than a visible shadow in light mode, so it was
removed entirely. Border is the only card-definition mechanism now, in both
light and dark. Don't reintroduce a shadow on cards/containers.

Use `lib/core/theme/theme_ext.dart`'s `BuildContext` extension
(`isDark`, `appBg`, `appCard`, `appText`, `appSubtext`, `appBorder`,
`cardDeco()`) for anything that needs to look right in both themes, rather
than reaching for `AppColors.textPrimary`/`pageBackground` directly.

## Shape (`AppTheme`)

- Buttons: fully-rounded pill, radius **30**, height **45**
- Inputs: radius **12**, border width 1, dense, filled
- Cards: radius **18**, hairline border, same flat color as the page (see
  "No mixing colors" above) — never a distinct card shade

## Icons — Heroicons only (rule set 2026-07-23, copied from HRNova)

**Never use `Icon`/`Icons.*` (Material icons) in a screen.** Use the
`heroicons` package via two wrapper types:

- `IconRef` (`core/theme/app_icons.dart`) — a typed reference to a
  `HeroIcons` enum value.
- `AppIcons` (same file) — the catalog. Add a new named entry here when a
  new icon is needed, rather than reaching for `HeroIcons.xxx` inline.
- `AppIcon` (`shared/widgets/app_icon.dart`) — the rendering widget, a
  drop-in replacement for `Icon`. Always renders `HeroIconStyle.solid`.

```dart
AppIcon(AppIcons.view, size: 18, color: context.appSubtext)
```

## Sidebar / nav bar

`CliniqnovvaSidebar` has no background color of its own — it uses
`context.appBg`, the exact same white/black as the page (the earlier
hardcoded `deepNavy` rule is retired). No divider directly under the logo;
logo mark and wordmark sit close together (**4px gap**, tightened 2026-07-24).
A **1px right-edge border** (`context.appBorder`) marks where the sidebar
ends and page content begins (rule set 2026-07-24).

Nav items: **16px icons, 13px text** (tightened 2026-07-24 — was 18/14),
**14px radius** on the tile (was 10), **6px gap** between items (was 2, so
items read as more clearly separated rows).

Active nav items get a **soft secondary-background pill**
(`context.appSecondaryBg` — a neutral gray wash, see the new token below) with
bold text — **no left border** (rule updated 2026-07-24; was a primary-lime
tint, now a neutral one). Active/inactive text and icon color is theme-aware
(`context.appText`/`context.appSubtext`).

**`context.appSecondaryBg`** (`theme_ext.dart`) — a subtle neutral fill
distinct from `appBg`/`appCard`, for interactive-state highlights (active nav
item, the profile menu's theme-toggle track and row backgrounds). Never the
brand lime for this role — lime is reserved for the profile chip and other
deliberate brand accents, not neutral hover/active states.

### Profile chip (bottom of sidebar)

**No background, 1px border only** (`context.appBorder` — corrected
2026-07-24; briefly had a lime fill/no border the same day, that was wrong).
Text/icons are theme-aware (`context.appText`/`context.appSubtext`) since the
chip no longer has a fixed-color background to contrast against.

Tapping the **"more" (⋯) icon** opens a small floating menu — implemented via
a custom `OverlayEntry` + `CompositedTransformFollower`/`Target` (not
`PopupMenuButton`, so each row can have independent tap handling without the
menu closing prematurely). The menu itself: **300px wide, 10px padding
(2026-07-24, was 16), bordered (`context.appBorder`), no shadow** (shadows are
gone project-wide — see "No mixing colors"), positioned so its **left edge
sits ~50px from the window's left edge** regardless of the chip's exact
position (`targetAnchor: topLeft`/`followerAnchor: bottomLeft` + a fixed
`Offset(50, -8)` — the sidebar is always docked flush left, so this is
effectively an absolute screen position, not just relative to the chip).
Contents: a Light/Dark segmented theme toggle, a Language row, and a Logout
row. This is the **only** sign-out entry point now — the topbar's old "Sign
out" button is gone.

**Language row (2026-07-24, design-only):** tapping it opens a SECOND
floating panel — same styling as the main menu (bordered, `appCard`, radius
16, 10px padding), 220px wide, listing Kinyarwanda/English/Français —
anchored beside (to the right of, 8px gap) the whole main menu panel via its
own `LayerLink`/`OverlayEntry`, so it visually reads as a nested submenu, not
a nested dialog. **It does not call `setLocale()` yet** — this is explicitly
a design-only placeholder per instruction; picking any option just dismisses
both floating panels. Wire up real language switching only when that's
separately requested — don't infer it from this submenu existing.

## Topbar

No bottom border (rule 2026-07-24 — was a 1px `appBorder` divider, removed).
Right side is a plain icon row: a chat icon (`AppIcons.chat` →
`HeroIcons.chatBubbleOvalLeftEllipsis`, navigates to `/chat`) and a
notification bell (`AppIcons.notification` → `HeroIcons.bell`, currently
static — no unread-count/notifications feature exists yet to wire a badge
to). The old "Super Admin" role pill and "Sign out" button are both gone —
sign-out lives in the sidebar profile chip's menu now.

## Buttons (`CliniqnovvaButton`)

**Filled buttons are theme-inverted** (rule set 2026-07-19):

- **Light mode: black background, white text.**
- **Dark mode: white background, black text.**

Leave `color` unset to get this automatically — the component resolves it from
the active theme. Text color is auto-picked for contrast
(`estimateBrightnessForColor`): black text on light fills, white on dark fills —
never hardcode a foreground. As of 2026-07-23 no screen needs an explicit
override anymore (the suspended screen's old always-navy exception was
retired along with the sidebar's — see "No mixing colors" above).

`.text()` is the transparent link-style secondary variant ("Forgot password?"),
with an optional underline.

## Backgrounds

Pure white (`AppColors.pageBackground`) in light mode, pure black
(`AppColors.pageBackgroundDark`) in dark mode — scaffold backgrounds,
text-field fills, containers, dropdowns, cards (see "No mixing colors").
There is no off-white/off-black tint token — do not reintroduce one.

## Admin screen layout

`SuperAdminScaffold` (`features/super_admin/widgets/super_admin_scaffold.dart`)
is the shared shell for every Super Admin screen: `CliniqnovvaSidebar` on the
left, a topbar (screen title + the chat/notification icon row — see Topbar
above) on the right, body content scrolls underneath. New Super Admin screens
should use this instead of building their own Scaffold/Row/sidebar boilerplate.

## Centered modal panel

A 480px-wide centered modal (`Add Clinic`, `features/super_admin/widgets/
add_clinic_panel.dart`) — `showGeneralDialog` + `Center` + a combined
`FadeTransition`/`ScaleTransition` (0.96 → 1.0). Rounded with `AppTheme.cardRadius`
(18px) and a `context.appBorder` border, same as every other card/dialog surface
(`Material(borderRadius: ..., clipBehavior: Clip.antiAlias)` wrapping a bordered
`Container`) — no shadow, per the "no mixing colors" rule. Capped at 85% of
screen height with an internal `SingleChildScrollView` for tall forms. Reuse
this pattern for any future "quick add" form that shouldn't be a full page.
(Changed 2026-07-23 from an earlier right-side slide-out panel — centered +
rounded matches the rest of the system's dialog language better than a
flush-edge sheet.)

## Theme mode

The app defaults to **light mode**, never `ThemeMode.system`. Page backgrounds
are hardcoded pure white, so inheriting the OS's dark mode would flip only the
theme-driven pieces (buttons turning white-on-white and vanishing). Dark mode
is an explicit in-app choice via `ThemeNotifier.setThemeMode`/`toggle`.

## Components (`lib/shared/widgets/`)

`CliniqnovvaButton`, `CliniqnovvaTextField`, `CliniqnovvaCard`, `MetricCard`
(label over 18px w600 value), `CliniqnovvaTableHeader` + `CliniqnovvaTableRow`
(divider-bracketed header, `Expanded`-per-cell rows, each row also followed by
its own hairline divider — 2026-07-25, so every row is fully divided, not just
the header), `StatusBadge` (plain
colored text, no pill background — `brightGreen`/`brightRed` for
success/error, see Colors above), `AvatarWidget`, `CliniqnovvaSidebar`
(background matches the page, see Sidebar above), `AppIcon` (Heroicons
wrapper, see Icons above).

**Selectable-option chip** (`_BillingStatusChip`, `payment_history_panel.dart`,
2026-07-23) — for a small set of mutually-exclusive options (billing status,
etc.): pill-shaped (`borderRadius: 100`), filled `context.appPrimary` with
inverse text when selected, border-only (`context.appBorder`) with
`context.appText` otherwise. Not yet promoted to `shared/widgets/` since it
only has one caller — promote it if a second one shows up.

## Loading/success feedback (`runWithFeedback`, `shared/utils/async_feedback.dart`)

**Every write action shows a loading SnackBar while in flight, replaced by a
success SnackBar when it finishes (2026-07-23)** — so a slow request never
reads as a silent no-op. Call `runWithFeedback(context, () => notifier.doThing(...),
loadingMessage: '…', successMessage: '…')` around every mutation instead of
awaiting the notifier call directly; it rethrows on failure so callers can
still run their own inline error handling (form error text, etc.) in
addition to the automatic failure SnackBar. Applied to every Super Admin
write action: create/update/suspend/activate a clinic, create a branch on a
clinic's behalf, set billing status, record a payment. Deliberately NOT
applied to read-only lookups (search-as-you-type, "View record", the
Support View session start/end) — those already have their own inline
loading/result UI, and a toast on every keystroke would be noise, not
signal.

**SnackBar theme** (`AppTheme._snackBarTheme`) follows the same black/white
inversion rule as `CliniqnovvaButton`/selected chips: black background with
white text in light mode, white background with black text in dark mode —
floating, 12px radius, no color accent.

## Brand assets

- Source marks at the repo root (both 2000×2000, added 2026-07-23):
  **`Logo.png`** (black square, white circle, black medical cross) is the
  IN-APP logo source; **`AppIcon.png`** (blue square, same mark in blue) is
  the APP-ICON source (favicon, PWA, Android/iOS). They supersede the
  `Light Logo.png`/`Dark Logo.png` pair.
- **In-app logo is one single mark** (rule updated 2026-07-23, asset swapped
  2026-07-26): `assets/images/logo.png` (256×256, from the repo-root
  transparent-background `Cliniqnovva No BG.png`) is shown in BOTH light and
  dark mode — transparent so it reads correctly on both a pure white and a
  pure black page with no visible edge, which is why this specific asset
  (not the white-background one) was chosen for on-screen use.
  `logo_dark.png`/`logo_light.png` stay in the asset bundle but are
  unreferenced. Always use the shared `CliniqnovvaLogo` widget (`size`,
  `radius` params) — never `Image.asset` a logo file directly. Placements
  (sizes reduced 2026-07-23): login screen (24px, radius 8) and sidebar
  (20px, radius 6), each next to the bold wordmark.
- Favicon, PWA icons, and mobile app icons all derive from **`AppIcon.png`**
  (repo root — swapped 2026-07-26 to the white-background `Cliniqnovva
  Logo.png`, deliberately the opposite choice from the on-screen logo: a
  favicon/app icon needs an opaque background of its own since it's never
  shown against the app's own page background).
- Mobile icon source (`assets/icon/app_icon_source.png`) must stay a raw,
  un-rounded square — the OS applies its own mask. Web favicon/PWA icons are
  pre-rounded (browsers don't mask); maskable PWA variants stay full-bleed.

## Dialogs

Every `AlertDialog`/`SimpleDialog` in the app is themed globally via
`AppTheme._dialogTheme()` (`dialogTheme:` on both `lightTheme()`/
`darkTheme()`) — **never style an individual dialog's title/content text or
background directly**; that's exactly what produced the inconsistent-looking
dialogs this rule fixes (2026-07-24). One title style (18px, w600) and one
content style (14px, `appSubtext`-equivalent) used everywhere, background
matches the page (white/black, no shadow, border only — same "no mixing
colors" + `surfaceTintColor: Colors.transparent` treatment as cards and the
date picker), so a plain `AlertDialog(title: Text(...), content: Text(...))`
with no manual styling is always correct.

## Date pickers

`showDatePicker` is themed explicitly via `AppTheme._datePickerTheme()`
(`datePickerTheme:` on both `lightTheme()`/`darkTheme()`) — **never leave it
on Material 3 defaults**. Left un-themed, Flutter derives the calendar's
colors from `ColorScheme.fromSeed(seedColor: AppColors.primary)`, which
produced a beige/olive-tinted calendar (the lime seed's tonal palette) with
zero relation to the app's actual black/white design system — a real bug,
not a deliberate look. Fixed 2026-07-24:

- Background/header/text: white+black in light mode, black+white in dark
  (`context.appBg`/`appText` equivalents, hardcoded via `AppColors.*` since
  this builder has no `BuildContext`).
- **No primary lime anywhere in the calendar** — selection uses the same
  black/white inversion `CliniqnovvaButton` already uses, not brand color.
- Selected day: solid circle, `black bg + white text` (light) /
  `white bg + black text` (dark).
- Today: a **bordered** (not filled) circle in the text color — filled only
  if today also happens to be selected.
- `surfaceTintColor: Colors.transparent` — this is the actual fix for the
  beige wash: Material 3's elevation tonal-overlay defaults to a
  primary-derived tint, and that's what was bleeding the lime hue into the
  whole dialog surface, not just the selected-day chip.
- Cancel/OK buttons: plain black/white text, no primary tint.

## Overview page (Super Admin landing page)

`OverviewScreen` (`/super-admin/overview`, `features/super_admin/screens/
overview_screen.dart`) is now the first page a Super Admin reaches — added
2026-07-24, structurally modeled on a typical admin-dashboard overview (KPI
row → growth chart → a recent-clinics table) but built entirely on
Cliniqnovva's own real data, not copied reference content. "Recent clinics"
is a full-width `CliniqnovvaCard` containing a real `CliniqnovvaTableHeader`
+ `CliniqnovvaTableRow` table (2026-07-23) — full width + the standard table
component is the reference pattern for any future "recent X" list on this
screen. (The audit-log-backed "Recent platform activity" table that used to
sit alongside it was removed 2026-07-23 along with the rest of the audit
log feature — see the change log.)

**Chart**: `fl_chart`'s `LineChart`, one series (real monthly revenue,
summed server-side from every clinic's recorded cash payments — see
`GET /api/v1/platform/revenue-trend`), colored with `AppColors.skyBlue`
(the system's second primary, 2026-07-23) and a more-transparent
`skyBlue.withValues(alpha: 0.15)` area fill beneath. X-axis labels are
capped at ~8 visible via `labelInterval = (points.length / 8).ceil()` —
without it, one label per data point overlaps/duplicates once there are
more than a handful of months. `LineChartBarData.preventCurveOverShooting:
true` + `LineChartData.clipData: FlClipData.all()` (2026-07-23) keep the
cubic-bezier curve smoothing inside `minY`/`maxY` — without them, a sharp
flat-to-steep jump in the data (e.g. a long flat stretch before a payment
spike) makes the curve dip below the axis and bleed into the month labels.
Reuse this pattern (single-series `LineChart`, `skyBlue` line + low-alpha
fill, interval-capped month labels, curve-clamping) for any future
growth/trend chart rather than introducing a new chart style or color.

## Change log

- **2026-08-09 (Patient App: empty states, offline banner, app icon/splash —
  Part 27 Tasks 2-4, `cliniqnovva_patient` only, no new tokens)** —
  `cliniqnovva_patient/lib/shared/widgets/empty_state.dart` is a
  byte-for-byte port of the web dashboard's `EmptyState` (icon + warm
  one-liner + optional action button, both-or-neither) — every prior empty
  list in the Patient App (My Bookings, Medical Records, Chat, My Reviews)
  was a bare `context.appSubtext` `Text`, same starting point the web
  dashboard's own Part 17 pass fixed. Wired into those four screens plus a
  small inline (non-full-page) version on Home's upcoming-appointment card,
  which previously rendered nothing at all when there was no booking to
  show. `offline_banner.dart` + `core/providers/connectivity_provider.dart`
  mirror the web dashboard's own Part 17 Task 8 pair (same `errorRed` strip
  pinned above the app via `MaterialApp.router`'s `builder:`, same
  `AppIcons.offline` / `HeroIcons.signalSlash`) — deliberately a smaller
  port: the web version also drives a local offline-write queue (walk-in
  registration/vitals/check-in typed while offline) that has no Patient App
  equivalent, so only the connectivity strip itself was copied, not the
  queue/sync machinery. New dependency: `connectivity_plus` (same version
  as the web app already pins). Launcher icon regenerated as a proper
  Android adaptive icon (`adaptive_icon_background: "#FFFFFF"` +
  `adaptive_icon_foreground`, the transparent brand mark) instead of the
  legacy flat icon it shipped with since Part 19 — background matches
  `AppColors.pageBackground` exactly, no new color. `remove_alpha_ios: true`
  added after `flutter_launcher_icons` warned the base icon has an alpha
  channel (App Store rejects that). Splash screen added via
  `flutter_native_splash` for the first time — was the stock unbranded
  Flutter placeholder on both platforms before this; white (light) / pure
  black (dark) backgrounds, same as `AppColors.pageBackground`/
  `pageBackgroundDark` — no new color introduced here either, consistent
  with "No mixing colors."
- **2026-07-30 (Dashboard: Quick Actions back to a column at 45% width,
  revenue chart always renders, section reorder)** — Explicit user
  instruction, same day as the two changes below it.
  `_TodayAppointmentsCard`, `_RevenueByDepartmentCard`, and
  `_QuickActionsCard` (`features/dashboard/screens/dashboard_screen.dart`)
  all pass `showBorder: false` to `CliniqnovvaCard` now (background/radius
  kept, border dropped — the existing opt-out `CliniqnovvaCard` already
  supports). Quick Actions reverts today's earlier side-by-side layout
  back to a column — all three buttons (including Run Reports, previously
  full-width) now sized to ~45% of the card's width via `LayoutBuilder`.
  The revenue chart no longer shows a "no revenue yet" placeholder text —
  with nothing recorded, it renders a flat zero-value line across 5 empty
  x points instead, so the chart itself is always what's on screen; real
  per-department data replaces it the moment there's revenue to show.
  `_DashboardBody`'s section order also changed: the Revenue by
  Department / Quick Actions row now comes before Today's Appointments
  (was after).
- **2026-07-30 (Fix: "Audit Log" title showed twice on the Super Admin
  route)** — `AuditLogBody` gained a `showTitle` param (default true,
  `false` on the Super Admin route only) — `SuperAdminScaffold` already
  renders the title via its own `title` param, so `AuditLogBody`'s own
  heading was redundant there. The Clinic Admin route (no scaffold-level
  title) keeps the heading.
- **2026-07-30 (Dashboard: narrower Quick Action buttons, Revenue by
  Department switches to a line chart)** — Explicit user instruction.
  `_QuickActionsCard` (`features/dashboard/screens/dashboard_screen.dart`):
  Register Patient / Book Appointment now sit side by side at ~45% of the
  card's width each (`LayoutBuilder` + explicit `SizedBox` width) instead
  of stacking full-width; Run Reports is unchanged (full-width text link,
  the lower-emphasis third action). `_RevenueByDepartmentCard`'s chart
  changed from a `BarChart` to a `LineChart` — curved, no dots, sky-blue
  line with a 15%-opacity fill beneath, no new color introduced (reuses
  `AppColors.skyBlue`, the same one already used for the bar fill, and the
  exact same curve/dot/fill settings as the Pharmacist/Accountant overview
  trend charts, see `pharmacist_overview_screen.dart`'s
  `_DispenseTrendChart`) — same department-name x-axis labels and
  RWF-formatted tooltip as before, just a different mark for the data.
- **2026-07-30 (Patients table drops its avatar circle)** — Explicit user
  instruction, scoped to "tables" specifically: checked every
  `AvatarWidget` usage in the app (14 files) and the Patients screen
  (`features/patients/screens/patients_screen.dart`) turned out to be the
  *only* one actually inside a `CliniqnovvaTableRow` — every other
  usage (chat, profile headers, reviews, booking/dispense patient
  pickers) is a different list style, not a data table, so those are
  unchanged. The Patients table's name cell is now plain text, no leading
  `AvatarWidget`/`Row` wrapper.
- **2026-08-08 (Patient App foundation — new `cliniqnovva_patient` client
  reuses this doc's tokens as-is)** — Part 19 of the Master Context: a
  second Flutter app (Android/iOS, `C:\WhiteZebra\Cliniqnovva\cliniqnovva_patient`)
  for patients, talking to the same backend/Firestore as this web
  dashboard. **No new colors, radii, or fonts were introduced.** The new
  app's `core/theme/` (`app_colors.dart`/`app_theme.dart`/`theme_ext.dart`)
  is a byte-for-byte copy of this app's: black/white `context.appPrimary`
  (light/dark inversion), `AppColors.textPrimary` `#0B2545` navy for
  light-mode-only body text, `AppColors.skyBlue` `#38BDF8` as the second
  accent, `cardRadius` 18 / `buttonRadius` 30 / `inputRadius` 12, General
  Sans font (same bundled `.otf` files). This was a deliberate decision —
  the part's own brief described an older "teal `#2A9D8F` primary, navy for
  key accents" scheme (the system's design *before* the 2026-07-18 lime
  swap and the 2026-07-24 lime-retirement covered earlier in this doc), and
  matching the actual current tokens was chosen over the brief's stale
  wording so the two clients look like one product. Mobile-specific
  adaptations, none of which change a token: **sidebar → bottom navigation
  bar** (`PatientAppShell`, 60px tall, same `context.appBorder` top border a
  card would use, 5 tabs: Home/Browse/Bookings/Chat/Settings per Task 6),
  and `AppTheme.sidebarWidth`/`topbarHeight` replaced by a single
  `AppTheme.bottomNavHeight` constant (the desktop-only constants have no
  mobile equivalent, so they were dropped rather than left unused). Shared
  components (`CliniqnovvaButton`, `CliniqnovvaCard`, `CliniqnovvaTextField`,
  `AvatarWidget`, `StatusBadge`, `CliniqnovvaLogo`) are likewise identical
  copies, sized the same (e.g. the 45px-tall pill button) since touch
  targets at these sizes already meet mobile accessibility minimums — no
  "mobile-sized" scaling was needed despite Part 19's brief mentioning it.
- **2026-08-08 (Patient App: Browse Clinics and Doctors — new components,
  no new tokens)** — Part 20 of the Master Context, `cliniqnovva_patient`
  only. Three new shared components, all built from existing tokens:
  **`RatingStars`** (`shared/widgets/rating_stars.dart`) — a 1-5 star row,
  rounds to the nearest whole star, filled stars use `AppColors.skyBlue`
  (matching this doc's own 2026-07-25 rule that Reviews star ratings use the
  second-primary accent, not amber — followed here rather than reintroducing
  amber for a new client). **Filter chips** (`browse_screen.dart`'s
  `_FilterChip`, sort-by/department) — pill-shaped (`borderRadius: 20`),
  filled `context.appPrimary` with inverse text when selected, `context.
  appSecondaryBg` fill with `context.appText` otherwise — the same
  selected/unselected shape as the web app's existing "Selectable-option
  chip" (`_BillingStatusChip`, documented above); this is the second call
  site for that pattern, both apps now share the same chip language even
  though the code isn't literally shared. **`BranchCard`**
  (`features/browse/widgets/branch_card.dart`) — a `CliniqnovvaCard`
  wrapping name/`RatingStars`/address/service tags, with an optional
  "New" pill badge (`AppColors.pillTealBg`/`pillTealText`, an existing pill
  pair token, no new color) for branches below the review-count threshold.
  Doctor's review-reply box (`clinic_detail_screen.dart`'s `_ReviewTile`)
  reuses `context.appSecondaryBg` on a 12px-radius container, the same
  neutral-fill role `appSecondaryBg` already plays for sidebar active-nav
  and menu tracks on the web app. No new colors, radii, or fonts introduced.
- **2026-08-08 (Patient App: Book/Reschedule/Cancel — one new step-badge
  component, one new date-strip component, no new tokens)** — Part 21 of
  the Master Context, `cliniqnovva_patient` only. **`_StepLabel`**
  (`booking_screen.dart`) — a numbered step indicator for the Booking
  screen's department→service→doctor→date wizard: a 22px circle, filled
  `context.appPrimary` with inverse-contrast number text, next to a 15px
  w600 label. New shape, not a reuse of an existing component — flag if a
  second multi-step flow needs it, worth promoting to `shared/widgets/`
  then. **`DateStripPicker`** (`features/booking/widgets/`) — a
  horizontally-scrolling next-14-days strip, 52px-wide rounded cells
  (weekday abbreviation over day number), same selected/unselected fill
  language as `BookingChip`/Browse's filter chips (`context.appPrimary`
  filled + inverse text when selected, `context.appSecondaryBg` otherwise)
  just in a taller cell shape suited to a two-line date. **`BookingChip`**
  itself is not a new pattern — it's `browse_screen.dart`'s `_FilterChip`
  promoted to a shared, feature-scoped widget (`features/booking/widgets/
  booking_chip.dart`) since department/service/doctor/slot pickers all
  needed the identical shape; Browse's own `_FilterChip` is untouched
  (still private to that screen, not merged into this one to avoid a
  cross-feature import for a purely cosmetic match). Appointment status
  badges reuse the existing `StatusBadge`/`BadgeType` mapping unchanged
  (`pending`/`checkedIn` → warning, `confirmed`/`completed` → success,
  `cancelled` → error) — no new badge colors. The cancel-confirmation
  dialog is a plain themed `AlertDialog` (see "Dialogs" above) with no
  custom styling. No new colors, radii, or fonts introduced anywhere in
  this part.
- **2026-08-08 (Patient App: My Bookings + status timeline — one new
  segmented-tabs component, one new timeline component, no new tokens)** —
  Part 22 of the Master Context, `cliniqnovva_patient` only.
  **Segmented tabs** (`my_bookings_screen.dart`'s `_SegmentedTabs`/
  `_Segment`) — My Bookings' Upcoming/Past switcher: a `context.
  appSecondaryBg`-filled 12px-radius track (3px inset padding) holding two
  equal-width segments, the active one filled `context.appPrimary` with
  inverse text (10px radius, so it reads as a pill nested inside the
  outer track) — same selected/unselected black-white-inversion language
  as every other chip/button in this app, just packaged as a fixed
  two-way switch rather than a scrollable chip row. This is the Patient
  App's first tabbed screen; reuse this component (not Material's
  `TabBar`, which would need its own theming pass to match) for any
  future two/three-way view switch. **`_StatusTimeline`**
  (`booking_detail_screen.dart`) — a 4-step horizontal progress line
  (pending → confirmed → checked in → completed): 12px filled/hollow dots
  connected by 2px bars, `context.appPrimary` for reached steps,
  `context.appBorder` for the rest, current step's label bolded. Only
  rendered for a non-cancelled appointment — a cancelled one jumped out of
  the linear sequence from wherever it was, so it shows only the existing
  red `StatusBadge` instead of a broken/backtracked timeline. No new
  colors, radii, or fonts introduced anywhere in this part.
- **2026-08-08 (Patient App: Settings profile form + Notification Center —
  one new badge component, everything else reused)** — Part 26 of the
  Master Context, `cliniqnovva_patient` only. **`NotificationBell`**
  (`features/notifications/widgets/notification_bell.dart`) is the one
  new piece: a bell `AppIcon` with a small `AppColors.errorRed` count
  pill (`borderRadius: 8`, not a circle — a circle distorts once the
  count needs two characters, i.e. "9+") positioned top-right, same
  `errorRed` token the app already uses for destructive actions
  (Cancel/Delete buttons). Notification Center rows and the Settings
  profile form both reuse existing patterns exactly: unread dot in
  `AppColors.skyBlue` (the system's second-primary accent — same role it
  already plays as `RatingStars`'/`AvatarWidget`'s accent color, not a
  new "unread" color), the profile form's date-of-birth field is a
  tappable container styled with the same `context.appBorder`/12px-radius
  input border every `CliniqnovvaTextField` already uses (opening the
  existing themed date picker, see "Date pickers" above), and the
  notification-preference toggles are the exact same `Switch` Settings'
  Appearance section already had — no new colors, radii, or fonts
  introduced anywhere in this part.
- **2026-08-08 (Patient App: Chat — first messaging UI in either client,
  built from existing tokens only)** — Part 25 of the Master Context,
  `cliniqnovva_patient` only (`features/chat/`). Chat List rows reuse
  `CliniqnovvaCard` + `AvatarWidget` (branch-initial avatar, same as every
  other list row in this app) with a small unread dot in
  `context.appPrimary`. Thread bubbles are new: "mine" (patient) bubbles
  are `context.appPrimary`-filled with inverse text, "theirs" (staff)
  bubbles are `context.appSecondaryBg` — the exact same filled/neutral
  selected-vs-unselected language `BookingChip`/Browse's filter chips
  already established (Part 20/21), just applied to a chat bubble instead
  of a pill. The composer is a rounded-pill `TextField` (`context.
  appSecondaryBg`, `borderRadius: 24`, matching the search-field radius
  used elsewhere) with a circular `context.appPrimary` send button. Two
  small full-width info banners sit above the message list: the fixed
  disclaimer ("not a substitute for an in-person consultation," `context.
  appSecondaryBg`) and, when the thread is linked to an appointment, a
  tappable context banner in `AppColors.pillTealBg`/`pillTealText` — same
  teal pill pair Browse's "New" badge already uses, not a new color. No
  new colors, radii, or fonts introduced.
- **2026-08-08 (Patient App: Reviews — new interactive star input; web
  Reviews screen gains a "Flagged" badge)** — Part 24 of the Master
  Context. `cliniqnovva_patient` gets **`StarRatingInput`**
  (`shared/widgets/star_rating_input.dart`) — a tappable 1-5 star row,
  the write counterpart to the existing read-only `RatingStars` (Part
  20): same `AppColors.skyBlue` filled-star color for consistency, plain
  `GestureDetector`-per-star, no new color/radius. `CliniqnovvaTextField`
  gained a `maxLines` param (defaults to 1, every existing call site
  unaffected) for Leave/Edit Review's comment fields — same incremental-
  extension pattern as the 2026-07-26 `prefixIcon` addition logged above.
  On the WEB dashboard: `reviews_screen.dart`'s `_ReviewCard` gained a
  `StatusBadge(type: BadgeType.warning)` "Flagged (N)" pill next to the
  existing "Hidden" one, shown when `ReviewModel.flagCount > 0` (Part 24's
  new patient-facing "Report" action) — reuses the existing badge
  component/warning-amber semantic, not a new color. No new colors, radii,
  or fonts introduced anywhere in this part.
- **2026-08-08 (Patient App: Medical Records + Receipts — no new visual
  patterns)** — Part 23 of the Master Context, `cliniqnovva_patient` only,
  read-only screens. Every element (document rows, prescription list
  items, invoice line-item/summary rows) is a plain `CliniqnovvaCard` +
  `AppIcon` + the same label-left/value-right row shape Booking
  Detail's `_Row` already established (Part 21) — nothing new to log here.
  The downloadable receipt PDF (`receipt_detail_screen.dart`) deliberately
  mirrors the web dashboard's `invoice_detail_screen.dart#
  _generateReceiptPdf` layout byte-for-byte (same A5 page, same table/
  totals structure, same plain-RWF-no-thousands-separator line-item
  formatting) rather than inventing a Patient-App-specific receipt look —
  intentional, so a receipt looks identical regardless of which client
  printed it.
- **2026-07-30 (Offline-first for the three front-desk flows)** — Explicit
  user instruction, following an earlier discussion about connectivity
  drops in Rwandan clinics. Scope is deliberately narrow: **patient
  registration**, **recording vitals**, and **appointment check-in** now
  queue locally (`shared_preferences`, via new `core/offline/offline_queue.dart`)
  instead of failing outright when offline, and replay automatically
  (`core/offline/offline_sync.dart`) the moment `isOfflineProvider` flips
  back to online — billing/invoicing and every other write stays
  online-only (queuing money-related writes risks double-charges, judged
  worse than "try again in a moment"). `OfflineBanner`
  (`shared/widgets/offline_banner.dart`) gains two more states beyond
  plain offline/online, both reusing the existing red/`AppColors.errorRed`
  offline-bar treatment plus one new `AppColors.warningAmber` bar (no new
  colors introduced) — a "Syncing N changes…" bar while queued writes
  haven't synced yet, and a tappable "N changes couldn't sync" bar (opens
  an `AlertDialog`, plain `TextButton`s, no new dialog component) for
  entries that got a real rejection from the server rather than just
  "still offline." `offline_message`'s copy was updated in all three
  languages to say which actions still work while offline, instead of
  just "changes won't save." No PWA/service-worker work was needed —
  Flutter's default web build already caches the app shell for offline
  loading; this is purely the data-layer queue+sync.
- **2026-07-29 (New Laboratorian role + lab orders/results, and Audit Log
  viewer restored)** — Explicit user instruction, two features.
  (1) New **Laboratorian** staff role, added alongside the existing 8 in
  `AppConstants`/`requireRole.js`. Doctor orders a lab test from inside
  `PatientProfileScreen`'s new "Lab Orders" tab
  (`features/lab_orders/widgets/patient_lab_orders_section.dart`); Nurse
  *or* Laboratorian (intentional dual capability) collects the specimen and
  records the result, either from that same tab or from the new branch-wide
  worklist screen (`features/lab_orders/screens/lab_orders_screen.dart`,
  `/lab-orders`, nav item shared with Nurse); Doctor reviews the result.
  New `LaboratorianOverviewScreen`
  (`features/lab_orders/screens/laboratorian_overview_screen.dart`,
  `/laboratorian-overview`) is this role's home route, structured exactly
  like `PharmacistOverviewScreen` — **Pending Collection**/**Awaiting
  Result**/**Resulted Today** KPIs, a sky-blue "Tests resulted, last 30
  days" line chart, a "Needs action" table capped at 5. `StatusBadge`
  reused for the ordered/collected/resulted/reviewed lifecycle (amber for
  anything still pending, green once reviewed) — no new badge colors.
  (2) The Audit Log viewer, deliberately removed 2026-07-24, is restored:
  `AuditLogScreen`/`AuditLogBody`
  (`features/audit_log/screens/audit_log_screen.dart`) is shared by a
  Clinic Admin route (`/audit-log`, new nav item, inside the general
  `AppShell`) and a Super Admin route (`/super-admin/audit-log`, new nav
  item in `superAdminNavItems`, wrapped in `SuperAdminScaffold` instead
  since Super Admin never goes through `AppShell`) — same
  `CliniqnovvaTableHeader`/`CliniqnovvaTableRow` list pattern as every
  other admin table, actor name resolved via the existing staff lookup
  (same pattern `inventory_screen.dart`'s `_ItemNameCell` already uses).
  Both new icons (`AppIcons.labOrders` — beaker, `AppIcons.auditLog` —
  clipboard) are Heroicons added to the existing catalog, never a raw
  `Icons.*`. No new colors introduced anywhere in either feature — status
  semantics reuse the existing `BadgeType` palette throughout.
- **2026-07-26 (New Pharmacist Overview page — stock version of the
  Accountant one)** — Explicit user instruction: `PharmacistOverviewScreen`
  (`features/inventory/screens/pharmacist_overview_screen.dart`,
  `/pharmacist-overview`) mirrors `AccountantOverviewScreen`'s structure
  exactly — KPI row, a sky-blue line-chart card, a recent-items table card
  — with Pharmacist's own numbers instead of billing ones: **Total
  Items**/**Low Stock**/**Expired** KPIs, a "Dispensing trend" chart
  (units dispensed per day, last 30 days, from `inventoryAdjustmentsProvider`
  filtered to `type == 'dispense'`), and an "Items needing reorder" table
  (items where `needsReorder`, capped at 5). Same branch-only scoping
  reasoning as Accountant — Pharmacist is never org-level. Now the home
  route for this role (`homeRouteForRole`), replacing the earlier plain
  redirect to `/inventory`; new nav item added above Inventory reusing the
  existing `nav_overview` translation key.
- **2026-07-26 (Profile "more" menu sized back up a little)** — Explicit
  user instruction, follow-up to the earlier shrink of `_ProfileMenuContent`
  (`cliniqnovva_sidebar.dart`): that shrink went too far, so it's bumped
  back up modestly — 220→250px wide, padding/radius/font sizes and spacing
  all nudged up a bit — deliberately well short of the original 300px, per
  "not too much, like how it was, increase a little." Same modest bump
  applied to `_ThemeOption` and the `_LanguageSubmenu` it opens, so the
  whole menu stays visually consistent at the new size.
- **2026-07-26 (New Accountant Overview page + Reports shows real names,
  not raw ids)** — Explicit user instruction, two related fixes.
  (1) New `AccountantOverviewScreen`
  (`features/billing/screens/accountant_overview_screen.dart`), structured
  like Super Admin's `/super-admin/overview`: a 3-tile KPI row (Total
  Revenue Today, Pending Invoices, Paid Invoices), a "Revenue growth" line
  chart (same sky-blue-line-plus-transparent-fill style as
  `overview_screen.dart`'s `_RevenueChart`, adapted for a daily
  `Map<String, int>` trend instead of the platform's monthly
  `RevenueTrendPoint` list), and a "Recent invoices" table (5 most recent,
  tappable to `/billing/:id`). Scoped to the Accountant's own branch only —
  Accountant is always branch-scoped, never org-level, so there's no
  branch selector here. New route `/accountant-overview`, added as the
  first nav item for this role (same "role-specific home page at the top
  of the nav" pattern as doctor-today/nurse-today) and now
  `homeRouteForRole`'s Accountant landing page, replacing the earlier
  straight-to-`/billing` default. (2) Reports' "By branch" breakdown
  (`reports_screen.dart`'s `_RevenueTab`/`_VolumeTab`) had a real bug
  independent of any permissions issue: it always passed a hardcoded empty
  names map (`const <String, String>{}`) instead of building one from
  `branchesProvider` the way `_NoShowTab` already correctly does elsewhere
  in the same file — fixed to match. This surfaced (and was compounded by)
  a second, permissions-level issue: Accountant lacked read access to
  staff/services/branches entirely, so even "By doctor"/"By service" (whose
  code was already correct) silently showed raw ids because the name-lookup
  requests 403'd and `.valueOrNull ?? []` swallowed the failure. Fixed by
  adding Accountant to the `READ_ROLES` list on `staff.routes.js`,
  `services.routes.js`, and `branches.routes.js`. All 37 backend tests
  pass; `flutter analyze` clean on every touched file.
- **2026-07-26 (Accountant can now actually print a receipt)** — Follow-up
  to the print-button fix directly below: once the button started
  surfacing real errors instead of failing silently, the user immediately
  hit "Failed: Insufficient role permissions" as Accountant — the print
  flow fetches the patient's name/phone via `GET /patients/detail/:id`,
  and Accountant had never been added to that route's allowed roles (a
  pre-existing gap the silent-failure bug had been masking). Fixed:
  Accountant added to `patients.routes.js`'s `READ_ROLES`, and given the
  same clinical-data-free response shape `patients.service.js`'s `getById`
  already gives Receptionist (name/phone only, no medicalRecords/
  documents). See `docs/technical-spec.md` section 6.8 for the spec note;
  covered by a new test in `backend/test/patients.test.js`.
- **2026-07-26 (Invoice receipt: real print feedback + the clinic's own
  name)** — Explicit user instruction, two fixes to
  `invoice_detail_screen.dart`. (1) "Print / Download Receipt" previously
  had zero loading state or error handling — any failure (a patient lookup
  error, or the `printing` package's pdf.js failing to load on web) was
  silently swallowed, which is exactly why the button could look "broken."
  Wired to `runWithFeedback` like every other write action: "Preparing
  receipt…" loading SnackBar, "Receipt ready." on success, a visible error
  SnackBar on failure. (2) The receipt PDF header hardcoded
  `AppConstants.appName` ("Cliniqnovva," the platform) instead of the
  issuing clinic's own name. New `InvoiceModel.clinicName`, populated by
  `GET /invoices/:id` from `req.scope.clinicName` — `attachScope`
  (`branchScope.middleware.js`) already fetches the clinic doc on every
  org-scoped request for the suspension check, so stashing the name there
  is a free read, not a new query or a new role-gated endpoint (`GET
  /clinics/:id` is Clinic Admin/Super Admin only, since it also returns
  billing/subscription fields no other billing-capable role should see).
  Falls back to the app name only if a clinic somehow has no name on
  record. `clinic-suspension.test.js` updated for the new `req.scope`
  shape; all 36 backend tests pass.
- **2026-07-26 (Reschedule dialog gets loading/success feedback)** —
  Explicit user instruction: `_RescheduleDialog`'s Confirm button
  (`appointments_screen.dart`) previously awaited the reschedule call with
  no feedback beyond an inline error box on failure — no indication
  anything was happening while it saved. Wired to the app's existing
  `runWithFeedback` helper (`shared/utils/async_feedback.dart`, the same
  one Cancel-appointment and Save-staff already use): a "Rescheduling…"
  SnackBar with a spinner while the request is in flight, replaced by
  "Appointment rescheduled." on success. The dialog stays open and
  re-enables its buttons on failure (via the existing `_saving` flag) so
  the user can pick a different slot without re-entering the date, instead
  of closing prematurely.
- **2026-07-26 (/appointments' "+ Book Appointment" button no longer wraps)**
  — The button was pinned to a fixed 170px `SizedBox`, too narrow for "+
  Book Appointment" at 14px/w600, so it wrapped onto two lines. Fixed in
  `appointments_screen.dart` by removing the `SizedBox` and passing
  `isFullWidth: false` instead, so the button sizes to its own content
  (same fix shape as any button that needs to size to its label rather
  than a guessed fixed width).
- **2026-07-26 (Profile "more" menu shrunk)** — Explicit user instruction:
  the sidebar profile chip's Theme/Language/Logout popup
  (`_ProfileMenuContent`, `cliniqnovva_sidebar.dart`) was too big. Shrunk
  the container (300→220px wide, padding 10→8, radius 16→12) and scaled
  everything inside it down to match: section labels 13→11.5px, the
  light/dark segmented toggle (`_ThemeOption`) padding 8→6px and text
  13→11.5px, the language row and Logout button padding tightened with
  explicit 12px text (was unset/default), and all the internal spacing
  (14px gaps around dividers → 10px). The language submenu it opens
  (`_LanguageSubmenu`) shrunk to match (220→160px, same padding/font
  reductions) since it's the same interaction flow.
- **2026-07-26 (Bigger logo, lighter sky-blue wordmark)** — Explicit user
  instruction, applied everywhere the logo mark and "Cliniqnovva" wordmark
  appear together (sidebar, login screen, onboarding wizard — the 3
  `CliniqnovvaLogo` call sites): logo size increased (sidebar 20→28px,
  login/onboarding 24→32px, `radius` scaled with it), and the wordmark text
  went from bold/`w700`, 18px, `context.appText` to `w500`, 16px,
  `AppColors.skyBlue` — the system's second-primary accent (same token as
  `AvatarWidget`'s ring and the Reviews star color), replacing the
  theme-neutral text color with a deliberate brand-color accent for the
  wordmark specifically.
- **2026-07-26 (New logo mark: opaque for icons, transparent on-screen)** —
  Explicit user instruction, two new repo-root sources: `Cliniqnovva
  Logo.png` (white background, 1254×1254) → favicon/PWA/mobile app icon
  everywhere, and `Cliniqnovva No BG.png` (transparent, 500×500) →
  `assets/images/logo.png`, the single on-screen mark `CliniqnovvaLogo`
  renders in both light and dark mode — chosen specifically because it has
  no background, so it never shows a mismatched edge against either theme.
  Regenerated: `assets/images/logo.png` (256×256), `assets/icon/
  app_icon_source.png` (1024×1024, raw un-rounded square for
  `flutter_launcher_icons`, then reran it for Android/iOS), `web/
  favicon.png` (32×32) and `web/icons/Icon-192/512.png` (pre-rounded, 22%
  corner radius — measured from the previous icons to match exactly),
  `web/icons/Icon-maskable-192/512.png` (full-bleed, un-rounded), and the
  repo-root `AppIcon.png` canonical source copy. No Dart code changed for
  the on-screen logo — `CliniqnovvaLogo` already only reads `assets/images/
  logo.png` by path, so swapping the file was enough; `ClipRRect`/`radius`
  stayed (a no-op on the now-transparent corners, kept so a future
  opaque-background swap doesn't need a second code change).
- **2026-07-26 (SearchableDropdown clears on focus, like a normal
  dropdown)** — Explicit user instruction: clicking `SearchableDropdown`
  (`shared/widgets/searchable_dropdown.dart`) was behaving like a plain
  text field pre-filled with the current selection's label — the user had
  to manually delete that text before typing would filter anything, unlike
  a normal dropdown where clicking immediately shows every option. Fixed
  in `_onFocusChange`: gaining focus now clears the controller (which
  re-triggers `optionsBuilder` with an empty query, i.e. every option) —
  losing focus without picking anything still reverts to the last
  confirmed selection's label, unchanged from before.
- **2026-07-26 (Per-doctor break-between-appointments buffer)** — Explicit
  user instruction, confirmed via clarifying questions before building:
  break minutes is one value per doctor (not per schedule-slot), and it
  applies around manually blocked slots too, not just real appointments.
  `/doctor-schedule`'s "Weekly schedule" card (`_WeeklyScheduleSection` in
  `doctor_schedule_screen.dart`) gained a `CliniqnovvaTextField` labeled
  "Break between appointments (minutes)" between the header row and the
  slot list, 260px wide, same `IgnorePointer(ignoring: !canEdit)` read-only
  pattern as the rest of the card, saved together with the schedule via the
  same "Save schedule" button (one PUT call, `{schedule, breakMinutes}`).
  Backend: `getAvailableSlots`, `book()`, and `reschedule()` in
  `appointments.service.js` all now pad every booked appointment and
  blocked slot by the doctor's `breakMinutes` on both sides
  (`overlapsWithBuffer`) before checking a candidate slot against it — a
  60-min appointment at 2:00 with a 10-min break makes 3:10 the next real
  slot, not 3:00, per the request's own example. Covered by two new backend
  tests in `appointments.test.js`. See `docs/technical-spec.md` section 6.5
  and the `/doctors/{userId}` field list for the corresponding spec note.
- **2026-07-26 (Public holidays no longer block booking; the section is
  removed from Doctor Schedule)** — Explicit user instruction: Rwandan
  clinics operate on public holidays like any other day, so the
  "Auto-blocked for booking unless overridden for this branch" behavior
  (and the section explaining/toggling it) was wrong for this market.
  Backend: removed the holiday check from `effectiveScheduleWindows`
  (`backend/src/services/appointments.service.js`) — a doctor's normal
  weekly schedule now applies on a public holiday same as any other day;
  Umuganda-Saturday clipping is untouched. Frontend: removed the whole
  "Public holidays" card from `/doctor-schedule` (`_PublicHolidaysSection`
  in `doctor_schedule_screen.dart`) along with its now-fully-unused
  `publicHolidaysProvider`/`PublicHolidayModel` files (deleted, zero
  remaining references). Left in place, deliberately: the `publicHolidays`
  Firestore collection, its CRUD routes, and `branches.holidayOverrides` —
  no in-app UI ever created a holiday (only read the list + toggled the
  override, both now gone), so this is inert rather than reachable dead
  code, and removing a whole collection/route set wasn't what was asked.
  See `docs/technical-spec.md` section 6.5 for the corresponding spec note.
- **2026-07-26 (Doctor pickers are now searchable, system-wide)** — Explicit
  user instruction: the doctor-selection dropdown must be type-to-filter,
  everywhere it appears, not just on `/doctor-schedule`. New shared
  component `SearchableDropdown` (`shared/widgets/searchable_dropdown.dart`)
  — same optional-label-above-a-bordered-field shape as the existing
  `LabeledDropdown` (`patient_form_fields.dart`), but built on
  `RawAutocomplete` (no new package) so typing filters the list instead of
  only scrolling it. Suffix icon is `AppIcon(AppIcons.search)` — Heroicons,
  never raw `Icons.search`. There were exactly two doctor pickers in the
  whole app and both now use it: `doctor_schedule_screen.dart`'s
  `_DoctorPicker` (was a bare `DropdownButtonFormField`, no label — kept
  label-less) and `booking_screen.dart`'s `_DoctorPicker` (was
  `LabeledDropdown`, kept its `label: 'Doctor'`). `LabeledDropdown` itself
  is untouched and still used as-is for every non-doctor dropdown (Province/
  District, Gender, Department, Service) — those didn't need search and
  weren't part of the request.
- **2026-07-26 (Staff row tap opens a details popup)** — Explicit user
  instruction: tapping a `/staff` table row now opens a details dialog
  (`showStaffDetailsDialog`, new `staff_details_dialog.dart`) — same
  `showGeneralDialog` fade+scale shell as the existing Add/Edit Staff panel
  (`AppTheme.cardRadius`, `context.appCard`/`appBorder`, close `AppIcon` top
  right). Shows name + `StatusBadge`, then Role/Specialty/Phone/Email as
  label-left/value-right rows (same shape as `branches_screen.dart`'s
  `_InfoRow`). For `canManage` roles, two buttons at the bottom: "Edit"
  (filled, closes the dialog and opens the existing edit panel) and
  "Deactivate"/"Activate" (`.text()`, `AppColors.pillRedText`/`pillGreenText`
  — the same semantic-color-on-a-text-button convention as "Unarchive"/
  "Delete clinic" on the Super Admin clinic detail screen). The row's "..."
  menu (`RowActionsMenu`, Edit/Deactivate) is untouched — this is an
  additional entry point onto the same actions, not a replacement.
- **2026-07-26 (`CliniqnovvaTextField` gains a `prefixIcon` slot; Staff gets
  a search field)** — Explicit user instruction: `/staff` now has a
  `CliniqnovvaTextField` (label "Search", same styling as the existing
  Patients/Clinics search fields) filtering the table client-side by name,
  role, specialty, or status (Active/Inactive), case-insensitive substring
  match. It sits in its own row under the title, search field on the left
  (`Expanded`) and "+ Add Staff" sharing that row on the right — the button
  moved out of the title row into this one; the title row now only has
  "Staff" + the branch selector. New component-level addition: `CliniqnovvaTextField`
  takes an optional `prefixIcon`, rendered via `InputDecoration.prefixIcon`
  same as the existing `suffixIcon`. Staff's field passes `AppIcon(AppIcons.search)`
  (already cataloged, previously unused) at 18px/`context.appSubtext` — per
  the Heroicons-only rule, never a raw `Icons.search`. The existing
  Patients/Clinics search fields are untouched (not asked for) and still
  have no icon — a candidate for a follow-up consistency pass, not done here.
- **2026-07-26 (Staff table row drops the name avatar)** — Explicit user
  instruction: the initials-circle `AvatarWidget` in front of the staff
  member's name on `/staff`'s table (`staff_screen.dart`) is removed; the
  row now shows just the name text, no other row's cell changed. `AvatarWidget`
  itself is untouched and still used everywhere else (Patients, Reviews,
  Doctor Schedule, etc.) — this was a Staff-table-only removal, not a
  component change.
- **2026-07-26 (`.text()` button now theme-aware, fixing invisible
  Dark-mode text buttons)** — `CliniqnovvaButton.text()` defaulted its
  color to `AppColors.textPrimary` (`#0B2545`, a light-mode-only navy per
  this doc's own token table), so any `.text()` button that didn't pass an
  explicit `color` was near-invisible on a dark background — reported via
  the Dashboard's "Run Reports" button. Same root cause as the 2026-07-23
  login-screen fix below, just in a shared component instead of one screen.
  Fixed at the component level: the default now resolves the same way the
  filled variant already did (`isDark ? Colors.white : Colors.black`), so
  every unstyled `.text()` button across the app — Reports' Export CSV/PDF,
  the empty-state action link, "+ Register new" on Booking, "Cancel" on
  Adjust Stock, "Change" on Dispense, "View as Clinic Admin" — is fixed at
  once, not just the one that got reported.
- **2026-07-26 (Dashboard joins the combined "All branches" view)** — Explicit
  user instruction reversing part of the same-day entry below: picking "All
  branches" on `/dashboard` no longer shows the "Pick a branch above to get
  started" empty state. It now renders the same metrics/appointments/revenue
  layout with every branch's data combined — the metric row, Today's
  Appointments table, and Revenue by Department chart all query with
  `branchId: null`, which their underlying providers already treated as
  "every branch in the org" (same convention Billing/Staff/Inventory/etc.
  already used). No new visual pattern; same cards/chart, org-wide numbers.
- **2026-07-26 (BranchSelector gains an "All branches" option)** — Explicit
  user instruction: a Clinic Admin's shared branch-filter dropdown (used
  across Dashboard, Departments, Services, Staff, Doctor Schedule, Patients,
  Merge Patients, Appointments, Billing, Inventory, Reports, Reviews, Popular
  Clinics, and Register Patient) now lists "All branches" above the real
  branch options, same dropdown styling, no new visual pattern. Selecting it
  shows every branch's data combined instead of forcing a single-branch pick.
  Screens that are inherently single-branch (Booking, Doctor Schedule's
  actual schedule editor, Popular Clinics' rank-among-siblings view,
  Inventory's Dispense tab) keep requiring one specific branch — "All"
  behaves there exactly like "nothing chosen yet" always has.
- **2026-07-25 (Clinic "Delete" archives + auto-purges after 14 days,
  instead of the old branch-count-gated hard delete)** — Explicit user
  instruction, replacing two earlier same-day entries below (the
  branch-count restriction and the original hard-delete implementation).
  `clinics.service.js#archive` now backs "Delete clinic": sets
  `isActive: false` + `isArchived: true` + `archivedAt` on the clinic and
  every branch under it — nothing is removed, fully reversible via
  `unarchive()`. A new daily cron job (`jobs/purgeArchivedClinics.job.js`,
  02:30 Africa/Kigali, same `node-cron` pattern as `popularityRecalc.job.js`)
  calls `permanentlyDeleteArchivedClinics()`, which finds every clinic
  archived more than `PURGE_AFTER_DAYS` (14) ago and cascade-deletes it via
  `cascadeDeleteClinic()` — branches, staff/doctor Firestore docs AND
  Firebase Auth accounts, patients (+ their `documents` subcollection
  metadata — the underlying Cloudflare R2 files are NOT deleted, a known
  gap noted in the code), medical records, appointments, invoices,
  departments, services, reviews, inventory (+ adjustment log),
  publicHolidays, queueCounters, chats (+ `messages` subcollection), and
  patientMergeLogs, before the clinic doc itself. `archivedAt` is filtered
  in JS rather than a Firestore range query, so no new composite index was
  needed. Frontend: `Clinic` gained `isArchived`/`archivedAt`/
  `daysUntilPurge` (replacing the old `canDelete` getter entirely — deletion
  now works regardless of what's linked, since nothing is destroyed
  immediately). Clinics list gained an "Archived (N)" MetricCard and a
  "Show archived" toggle revealing archived rows with an
  "Archived — Nd left" red `StatusBadge` and a single "Unarchive"
  `RowActionsMenu` action instead of View/Suspend/Delete. Clinic detail
  page gained a red banner (`AppColors.pillRedBg`/`pillRedText`, matching
  the warning-banner pattern `support_view_screen.dart` already
  established) with the days-left count and an inline "Unarchive" button
  when `org.isArchived`; Save changes/Suspend/View as Clinic
  Admin/+ Create branch all hide in that state, since there's nothing
  useful to do to an archived clinic except restore or wait it out.
- **2026-07-25 (+ Add Branch is now two steps: branch, then its admin)** —
  Explicit user instruction. Creating a branch now immediately opens the
  existing "+ Add Staff" panel a second time, pre-locked to the Branch
  Admin role, so a new branch is never left without one. No new UI
  component — `showStaffPanel` (`add_edit_staff_panel.dart`) gained an
  optional `lockedRole` param: when set, the title becomes "Add {role
  label}" (e.g. "Add Branch Admin"), the role dropdown shows only that one
  role and is disabled (same visual treatment Edit mode already used for
  a fixed role), and the doctor-only fields stay hidden exactly as they
  already did for any non-Doctor role. Dismissible like every other
  panel — closing it doesn't undo the branch, it just skips assigning an
  admin right now (can still be done later from the Staff screen once
  Branch Admin creation is exposed there too — currently only reachable
  through this chained step). Backend: `staff.service.js` now accepts
  `branch_admin` as a creatable/listable role — gated to Clinic
  Admin/Super Admin callers, one per branch, so the new admin shows up in
  that branch's own Staff list with the "Branch Admin" role badge like any
  other staff member (`roleLabel()` already mapped this role — no
  frontend display change needed there).
- **2026-07-25 (Today's Appointments card border restored)** — Explicit
  user instruction reverting the entry two below: the Dashboard's Today's
  Appointments card no longer passes `showBorder: false` — it's back to
  the default bordered `CliniqnovvaCard` like every other card. The
  `showBorder` flag itself stays on `CliniqnovvaCard` (harmless, defaults
  `true`, no current caller uses `false`) in case a future card needs it.
- **2026-07-25 (Dashboard's Reviews section removed)** — Explicit user
  instruction: the Reviews Needing Reply card is gone from `/dashboard`
  entirely, along with `_ReviewsNeedingReplyCard`/`_NeedsReplyPreviewCard`/
  `_relativeDate` and the now-unused `patients_provider.dart`/
  `reviews/models/review_model.dart`/`reviews/providers/reviews_provider.dart`/
  `reviews/widgets/review_display.dart` imports. Quick Actions now pairs
  with Revenue by Department as the last row on the Dashboard. The shared
  `review_display.dart` (`RatingSummaryHeader`/`SimpleReviewCard`/sample
  data) stays — the real Reviews page (`reviews_screen.dart`) still uses it.
- **2026-07-25 (Dashboard's Today's Appointments card has no border;
  CliniqnovvaCard gets a `showBorder` opt-out)** — Explicit user
  instruction: `CliniqnovvaCard` now takes `showBorder` (default `true`,
  every existing card keeps its border unchanged). The Dashboard's Today's
  Appointments card is the first (and so far only) caller passing
  `showBorder: false` — background and 18px radius stay, the
  `Border.fromBorderSide(...)` is just `null` instead.
- **2026-07-25 (RowActionsMenu: hover truly gone + left-aligned under
  "Actions")** — Explicit user instruction, correcting the two entries
  below: neither fix actually worked as intended once seen live.
  (1) **Hover**: `PopupMenuButton`'s `icon:` path wraps in a Material 3
  `IconButton`, which paints its own grey hover/focus overlay from
  `IconButtonThemeData` and **ignores** `ThemeData.hoverColor` entirely —
  the earlier "wrap in a transparent `Theme`" fix only ever reached the
  dropdown's own items (which use a plain `InkWell`), never the trigger
  button itself. Switched to `PopupMenuButton(child: …)` instead of
  `icon: …` — per `popup_menu.dart` source, the `child` path wraps in a
  plain `InkWell` too, which *does* respect the ambient `Theme`, so the
  same transparent-`Theme` wrap now actually removes the hover fill on the
  "⋯" trigger. (2) **Alignment**: wrapping both the icon and the empty-state
  "—" in a fixed 40×40 `SizedBox` didn't work either — `Expanded`
  (`Flexible` with `FlexFit.tight`) forces its child to the *full* column
  width on the main axis regardless of the `SizedBox`'s requested width, so
  the icon was centering within the whole cell, not a 40px box. Replaced
  with `Align(alignment: Alignment.centerLeft)`, which gives its child
  loose constraints and positions it at the child's own natural size — now
  both the icon and "—" render at their natural (small) size, left-edge
  flush with the "Actions" header text above them.
- **2026-07-25 (RowActionsMenu: empty state lines up with the "⋯" icon)** —
  Explicit user instruction: a row with no actions used to render a plain
  left-aligned `Text('—')` while a row with actions rendered the "⋯" icon
  button (which has its own internal padding) — the two didn't sit in the
  same column. `RowActionsMenu` now owns both states itself: an empty
  `actions` list renders a centered "—" inside the same fixed
  `_kActionsCellSize` (40×40) box the icon button is also wrapped in, so
  every row's Actions cell lines up in one vertical line regardless of
  whether that row has actions. `doctor_today_screen.dart` and
  `appointments_screen.dart`'s `_ActionsCell` no longer branch on
  `actions.isEmpty` themselves — they just always call `RowActionsMenu`,
  passing an empty list when there's nothing to show.
- **2026-07-25 (RowActionsMenu: no hover tint on dropdown items)** —
  Explicit user instruction, follow-up to the row-actions-dropdown entry
  below: `RowActionsMenu`'s dropdown items no longer show Material's
  default hover/highlight/splash tint. Implemented by wrapping the
  `PopupMenuButton` in a local `Theme` with `hoverColor`/`highlightColor`/
  `splashColor` all `Colors.transparent` — `PopupMenuButton` captures the
  ambient `Theme` into the overlay route it opens, so this reaches the
  dropdown items themselves, not just the "⋯" button.
- **2026-07-25 (Table rows taller + row actions moved to a "⋯" dropdown,
  system-wide)** — Explicit user instruction, two reference screenshots
  (a taller Catalog row; a small "⋯" dropdown with Edit/Delete). (1)
  `CliniqnovvaTableRow`'s vertical padding grew 16→26px — since every table
  in the app shares this one component, every row got taller in one edit.
  (2) New shared `shared/widgets/row_actions_menu.dart`: `RowActionsMenu`
  (a `PopupMenuButton` behind `AppIcons.moreHoriz`, `context.appCard`
  background, `context.appBorder` outline, 10px radius) + `RowAction`
  (`label`, `onTap`, optional `isDestructive` → `AppColors.brightRed` text).
  Renders nothing if the action list is empty, same as the inline-buttons
  row it replaces did. Rolled out everywhere a table had a row of
  inline `CliniqnovvaButton.text`/`IconButton` actions: Super Admin
  Clinics (View/Suspend/Delete), Staff (Edit/Deactivate), Branches
  (Edit/Deactivate), Inventory (Edit/Adjust/Deactivate), Services
  (Edit/Deactivate/Delete), Departments (Rename/Deactivate/Delete),
  Doctor Today (Mark Complete), and the shared `AppointmentsList`
  (Confirm/Check-In/Mark Complete/Reschedule/Cancel — the biggest one,
  used by both the Appointments screen and the Dashboard). One visual
  regression accepted as part of this: the "Has services"/"Has history"/
  "clinic has branches" muted-tooltip-label pattern (2026-07-23/24 entries
  below) that explained why Delete was blocked is gone — a blocked delete
  now just doesn't appear in the menu at all, with no inline reason shown.
  Tables with no per-row action buttons (Patients, Billing/Invoices,
  clinic detail's Branches sub-table, Nurse Today) were left untouched, as
  was Doctor Schedule's weekly-schedule editor (an add/remove-row editing
  UI, not a static data table with an Actions column — a single delete
  icon-tap suits it better than a menu).
- **2026-07-25 (Dashboard's Reviews card now mirrors the real Reviews
  page)** — Explicit user instruction, follow-up to the Reviews redesign
  below: the shared bits (`ReviewStarRow`, `ReviewDistributionRow`,
  `RatingSummaryHeader`, `SimpleReviewCard`, the `sample*` data constants)
  moved out of `reviews_screen.dart` into a new
  `features/reviews/widgets/review_display.dart`, so both the Reviews page
  and the Dashboard's "Reviews Needing Reply" card render the identical
  rating-summary-header + distribution-bars + comment-first-card look
  instead of two designs drifting apart. `RatingSummaryHeader` takes an
  `asCard` flag (`true` on the Reviews page — its own `CliniqnovvaCard`;
  `false` on the Dashboard — embedded as plain content inside the
  Dashboard's own card, avoiding a card-inside-a-card). Same sample-data
  fallback (4.8 / 1.1K ratings / three sample cards) when the branch has
  zero reviews, same "Sample preview" labeling.
- **2026-07-25 (Reviews page redesigned + sky blue everywhere in Reviews)**
  — Explicit user instruction, screenshot-driven. `/reviews`
  (`reviews_screen.dart`) now opens with a rating-summary `CliniqnovvaCard`:
  big average rating + "`N`K ratings"/"`N` rating(s)" + a star row on the
  left, the 5/4/3/2/1 distribution bars (`_DistributionRow`, new) on the
  right. Below it, a Rating filter dropdown (All/5..1 stars) and a Filter
  by patient dropdown (built from the unique patient IDs in the branch's
  own review list, names resolved via `patientDetailProvider` same as the
  cards already did) — both filter the real list client-side, no new
  endpoint. `_StarRow` (both here and `doctor_reviews_screen.dart`'s own
  copy) changed from `AppColors.pillAmberText`/amber to `AppColors.skyBlue`
  for filled stars — explicit instruction: stars and the distribution bars
  both use the system's one sky-blue accent, never the black/white
  "primary", across every reviews screen. Added a sample-data fallback
  (`_sampleAverageRating` 4.8 / `_sampleRatingCount` 1100 /
  `_sampleDistribution` / `_sampleReviewCards`, matching the reference
  screenshot's numbers) shown only when a branch has zero reviews — same
  "Sample preview" labeling convention as the Dashboard's Reviews card.
  `CliniqnovvaCard` gained an optional `trailing` widget parameter
  (right-aligned next to `title`, ignored if `title` is null) — first used
  by this page's "View all" link on the Dashboard's Reviews card (see the
  Dashboard entry below); every other `CliniqnovvaCard` call site is
  unaffected since `trailing` defaults to null.
- **2026-07-25 (Dashboard: Revenue+Quick Actions combined, Reviews full
  width with "View all")** — Explicit user instruction. Revenue by
  Department and Quick Actions now share one row again (briefly full-width
  solo for one revision each). Reviews Needing Reply is now full width,
  standalone, with a "View all" text link on the title row (via
  `CliniqnovvaCard`'s new `trailing` param) linking to `/reviews`, replacing
  the old "Open Reviews" button that sat at the bottom of the card's list.
- **2026-07-25 (Avatar ring is now sky blue system-wide)** — Explicit user
  instruction: `AvatarWidget`'s 1.5px circular ring (`avatar_widget.dart`)
  was `context.appPrimary` (black in light mode, white in dark mode) — now
  hardcoded to `AppColors.skyBlue`, the system's one deliberate accent color
  (see Colors section above, previously only used for the Overview revenue
  chart). Since `AvatarWidget` is the single shared avatar component used
  everywhere a person's initials-circle appears (patient booking flow,
  reviews, dashboard, etc.), this one-file change applies system-wide with
  no other edits needed. `theme_ext.dart` import dropped from the file —
  nothing else in it used `context.*`.
- **2026-07-25 (Dashboard: Recent Chats/Low Stock removed, Revenue full
  width, sample reviews)** — Explicit user instruction, follow-up to the
  Today's Appointments change below. Removed the "Recent Chats" card
  (`_RecentChatsCard`) and the "Low Stock" card (`_LowStockCard`) from
  `/dashboard` entirely — along with their now-unused `_PatientName` helper
  and `chats_provider.dart`/`inventory_provider.dart`/
  `patients_provider.dart`/`app_icon.dart` imports. Revenue by Department is
  now its own full-width row (was the right 40% of a row shared with Recent
  Chats) and its chart height grew 220→280 to fill the extra width better.
  Reviews Needing Reply now pairs with Quick Actions (was paired with Low
  Stock) — Reviews on the left, Quick Actions on the right, per explicit
  instruction on left/right placement. Reviews Needing Reply also gained a
  sample-data fallback (`_sampleReviews`, 3 hardcoded name/rating/comment
  tuples) shown — clearly labeled "Sample preview" in italic — only when
  there are zero real reviews needing a reply, so the card's look can be
  previewed without waiting for real review data. Sample rows are never
  mixed with real ones; the moment a real review needing a reply exists,
  the sample block disappears entirely.
- **2026-07-25 (Dashboard's "Today's Appointments" is now the full
  Patient/Doctor/Date & time/Status/Actions table)** — Explicit user
  instruction: the compact 60%-width time+name+status-dot list on
  `/dashboard` (Clinic Admin, Branch Admin, AND Receptionist all share this
  one screen — there's no separate per-role dashboard) is replaced with the
  same table the Appointments screen's Today tab already uses, full width,
  Confirm/Reschedule/Cancel actions included. `AppointmentsScreen`'s
  previously-private `_AppointmentsList` is now the public
  `AppointmentsList` (`appointments_screen.dart`) with a new `embedded`
  flag: `false` (default, used by the Appointments screen itself) keeps the
  original `Expanded`+`ListView` so it fills the screen; `true` (used by
  the Dashboard) renders a plain non-scrolling `Column` of rows instead,
  since the Dashboard's own `SingleChildScrollView` already owns scrolling
  for the whole page and `Expanded` needs a bounded-height ancestor it
  doesn't have there. Reshuffled the rows below it to keep pairs even:
  Revenue by Department + Recent Chats, then Quick Actions + Low Stock,
  then Reviews Needing Reply full-width alone at the bottom.
- **2026-07-25 (Super Admin's bell now shows a live badge)** — Explicit
  user instruction, follow-up to the Chat-moved-to-topbar entry below:
  `SuperAdminScaffold`'s topbar bell was a plain static `AppIcon` with no
  unread count at all — it now renders the shared `NotificationBell`
  widget (same one `AppShell` uses), so Super Admin gets the same live
  red-circle unread badge every other role's topbar already had. The chat
  icon next to it is unchanged (still a plain `AppIcon` + `context.push
  ('/chat')` — Super Admin's chat access wasn't part of this ask).
- **2026-07-25 (Chat moved from sidebar to topbar)** — Explicit user
  instruction: the non-Super-Admin shell (`AppShell`, `app_shell.dart`) now
  matches `SuperAdminScaffold`'s topbar layout — a chat icon
  (`ChatBell`, new: `features/chat/widgets/chat_bell.dart`) sits directly
  left of the existing `NotificationBell`, both right-aligned in the 56px
  topbar `Container`. The `nav_chat` `SidebarNavItem` (Clinic
  Admin/Branch Admin/Receptionist only) is removed entirely — same
  `_chatEnabledRoles` list now gates the topbar icon instead, so access is
  unchanged, only the location moved. `ChatBell` mirrors
  `NotificationBell`'s icon-plus-circular-badge visual (same `AppColors
  .brightRed` circle, white 10px w700 text, `9+` cap at >9) but has no
  dropdown menu — it's a straight `context.push('/chat')`. Its badge count
  is the same `chatTotalUnreadProvider(branchId)` the old sidebar badge
  used; `null` branchId (Clinic Admin with no active branch selected yet)
  just means no badge, the icon still navigates.
- **2026-07-25 (distinct sidebar icons: Branches/Departments/Services)** —
  Explicit user instruction: the Branches, Departments, and Services nav
  items looked too similar (Branches and Services both reused
  building-shaped Heroicons — Branches had `buildingOffice2`/`AppIcons.clinics`
  and Services had `buildingOffice`/`AppIcons.department`, the same icon
  Departments itself uses). Added two new icon-catalog entries:
  `AppIcons.branchLocation` (`HeroIcons.mapPin`, now used by Branches) and
  `AppIcons.service` (`HeroIcons.wrenchScrewdriver`, now used by Services).
  Departments keeps `AppIcons.department`/`buildingOffice` unchanged — only
  Branches and Services needed new icons to make all three visually
  distinct in `appNavItems` (`app_shell.dart`).
- **2026-07-25 (table rows fully divided)** — Explicit user instruction:
  `CliniqnovvaTableRow` now renders its own hairline `Divider` (same
  `height: 1, thickness: 1, color: context.appBorder` as the header's) after
  every row, not just between the header and the first row. Since every
  table in the app (Clinics, Staff, Services, Departments, Overview's
  "Recent clinics", etc.) is built on this one shared component, the change
  applies everywhere at once — no per-screen edits needed. This also means
  the last row in any table is now followed by a trailing hairline before
  the surrounding `CliniqnovvaCard`'s padding ends, which is intentional
  (a closing rule, consistent with the divided-row look).
- **2026-07-24 (terminology + Audit Log removed)** — Explicit user
  instruction, two changes visible in the UI: (1) "Organization"
  terminology retired system-wide in favor of "Clinic" — every visible
  string that said "Organization Admin" now says "Clinic Admin" (via the
  centralized `roleLabel()` helper), and the Super Admin section's own
  nav/route naming (already "Clinics" since Part 17's translation keys)
  stays consistent with the rest of the system. (2) The Audit Log feature
  was removed entirely, so its sidebar nav item (and the `/audit-log`
  screen behind it) no longer exists for Clinic Admin. Underneath these
  two visible changes, `organizationId` was also renamed to `clinicId`
  everywhere in the schema (Firestore fields, the `organizations`
  collection → `clinics`, Firebase Auth custom claims) — not itself a
  design-language change, but the reason the rename touched so much code;
  see `docs/security-review.md` and the backend's own git history for the
  full scope.
- **2026-07-24 (Part 18 follow-up: sidebar navy-lock reverted)** — Explicit
  user instruction: the sidebar should match the page background (white in
  light mode, black in dark mode) everywhere, same as everything else in
  the app, not stay locked to navy. `CliniqnovvaSidebar`'s Container is back
  to `context.appBg`/`context.appBorder`; every color inside it (logo text,
  nav icon/label, profile chip text/border/"more" icon) is back to
  `context.appText`/`context.appSubtext`/`context.appBorder`. Active nav
  pill uses `context.appSecondaryBg` (the same neutral highlight token used
  everywhere else for this role); hover is a small inline black/white-alpha
  tint (`0.04`) rather than a named token, since it's a one-off state with
  no other user. `AppColors.deepNavy` and the five `sidebar*` constants
  Part 17 added are deleted — nothing else referenced them. This directly
  reverses the entry immediately below; treat THIS entry as the current
  state of the sidebar, not the Part 17 one.
- **2026-07-24 (Part 17: admin dashboard final polish)** — The biggest
  structural change yet: `CliniqnovvaSidebar` is now used app-wide (via a
  new `AppShell` + a `ShellRoute` in `app_router.dart`), not just by Super
  Admin — every other screen's own bare `Scaffold` unchanged, just nested
  inside the shell's content pane. **The sidebar is now ALWAYS
  `AppColors.deepNavy` (`#0B2545`), regardless of light/dark mode** (Task
  5, explicit instruction) — five new fixed on-navy constants
  (`sidebarText`/`sidebarSubtext`/`sidebarBorder`/`sidebarHoverBg`/
  `sidebarActiveBg`) replace every `context.appX` reference *inside the
  sidebar's persistent Container only* — the floating profile/theme/
  language popup menus it opens stay theme-reactive, since they're
  detached overlays over the page, not part of the sidebar itself. Nav
  item badges (small red pill, same shape as the notification bell's
  unread count from Part 14) are the first per-nav-item indicator in the
  app. `SidebarNavItem.label` changed meaning: it's now an
  `easy_localization` translation KEY, not display text — rendered via
  `.tr()`, first real wiring of language switching (Task 6) after it sat
  design-only since Part 1; a missing key falls back to showing the key
  itself, so nothing breaks for a label not yet translated. `EmptyState`
  (icon + friendly message + optional action button) is the first empty
  state anywhere in the app with an icon or CTA — every prior one was a
  bare gray `Text`; `NoBranchSelectedState` collapses the 13-file-
  duplicated "No branch to show yet." into one shared widget. The offline
  banner (`OfflineBanner`, wired into `MaterialApp.router`'s `builder:`)
  is a full-width `errorRed` strip pinned above the whole app — the
  second "standing notice, not dismissible" banner pattern after Part
  15's chat disclaimer, now in red for an active problem rather than a
  neutral notice.
- **2026-07-24 (Part 16: reviews, ratings, popular clinics)** — First use
  of a **star rating row** (`_StarRow`, `reviews_screen.dart`) — five
  `AppIcons.star`, filled `pillAmberText` up to the rating and
  `appBorder`-colored beyond it. Amber was already reserved for "needs
  attention" (low-stock, Part 13) but reads as "rating" here instead —
  deliberately reused rather than adding a new brand color, since the two
  meanings never appear on the same screen. A review card's clinic reply
  is the same `appSecondaryBg`-tint block pattern as an unread chat bubble
  (Part 15) — a quoted, subordinate piece of text sitting under the primary
  content, not a new pattern. Popular Clinics' explanation card
  (`_PopularityView`, "How this is calculated") is the first place this
  app explains a computed number in plain language directly in the UI
  rather than leaving it as a bare metric — appropriate here since
  popularityScore is opaque by design (recency + confidence weighting) and
  staff seeing "2.1" next to a 4.5 raw average need to know why. Two new
  `AppIcons`: `star` and `trophy` (the latter only for that explanation
  card's leading icon, not a repeating motif).
- **2026-07-24 (Part 15: clinic chat)** — /chat is this app's first screen
  reading/writing Firestore DIRECTLY (`cloud_firestore` via
  `FirebaseService`), not through `ApiService`/the Node.js backend — chat's
  established, deliberate exception (see `firebase/firestore.rules`'s
  comment block; `FirebaseService.chatsRef()` was reserved for this back in
  Part 1). Message bubbles are the first left/right-aligned two-party
  layout in the app: sender-role text in `appCard` fill and receiver-role
  in `appSecondaryBg`, both border-only, same "no filled color, no shadow"
  card language as everywhere else, just mirrored left/right by who sent
  it. The disclaimer banner (`_DisclaimerBanner`, "not for medical
  emergencies…") is a full-width `appSecondaryBg` strip pinned under the
  header, no icon, no dismiss control — deliberately impossible to miss or
  close, since it's a standing legal/safety notice, not a dismissible tip.
  Two new `AppIcons` entries: `back` (`arrowLeft`, thread header) and
  `send` (`paperAirplane`, composer) — the first icons in the catalog added
  specifically to complete a chat-style screen rather than an admin table.
- **2026-07-24 (Part 14: notifications, reports, audit log)** — The
  **Notification Bell** (`NotificationBell`, Admin Dashboard header) is the
  first floating menu outside the sidebar to reuse its
  `OverlayEntry` + `CompositedTransformTarget`/`Follower` pattern (previously
  only the sidebar's profile chip and its language submenu) — same
  `appCard`/16px-radius/border-only panel, confirming that pattern
  generalizes beyond the sidebar and is worth reaching for anywhere else a
  floating menu is needed. Unread count renders as a small solid-red circle
  badge pinned to the bell icon's top-right corner (`AppColors.brightRed`,
  white text) — the one deliberate exception to this app's "no filled pill
  backgrounds" status-text convention, justified because a badge needs to
  read at a glance over an icon, not sit in a text flow. An unread
  notification's row gets a plain `appSecondaryBg` tint (no border, no
  pill) plus a small green dot, rather than bold text — consistent with the
  rest of the app using color/shape for state instead of weight changes.
  /reports' trend visualization is a **plain proportional bar list**
  (`_TrendBars` — label, `appPrimary`-filled bar sized by
  `FractionallySizedBox`, value), not a charting library — deliberate,
  even though `fl_chart` has been a dependency since Part 1: every other
  screen in this app uses plain widgets with no charts, and a first chart
  usage isn't worth the added visual-verification risk this session (no
  screenshot access) for a Part 14-scope deliverable. Revisit with
  `fl_chart` once there's a way to visually confirm it renders correctly.
  CSV export has no dedicated UI treatment — it's a plain `CliniqnovvaButton.text`
  next to "Export PDF", both firing on tap with no dialog; PDF export reuses
  Part 12's `pw.Document`/`Printing.layoutPdf()` receipt pattern exactly,
  now for a metrics table instead of a receipt.
- **2026-07-24 (Part 13: inventory + pharmacy)** — /inventory reuses
  `SegmentedTabs` for its Stock/Dispense/Log split rather than introducing a
  new tab pattern. The stock table layers `StatusBadge` entries vertically
  in one cell (Active/Inactive plus an optional amber "Low stock" and/or red
  "Expired" badge) — the first place more than one status badge appears
  stacked in a single cell, since an item can be low-stock AND expired at
  once and both need to be visible without a tooltip. Low-stock quantity
  text itself turns `pillAmberText` + semibold directly in the table (not
  just the badge) so it's scannable without reading the badge column.
  Adjust Stock introduces a small **direction-toggle chip pair**
  (`_DirectionChip`, `adjust_stock_dialog.dart`) — "Restock (+)" / "Write
  off (−)", `appSecondaryBg` fill + `appBorder`/`appPrimary` border on the
  selected side — a lighter-weight sibling to the existing
  `_BillingStatusChip` "selectable-option chip" pattern for exactly-one-of-2
  choices; promote both to a shared widget together if a third caller shows
  up. The dispense flow (`DispensePanel`) reuses Booking's numbered
  step-card reveal (only step 2 renders once a patient is picked, step 3
  once a prescription is picked) and its patient-search list item look
  verbatim, plus a new **selectable list row** (bordered card, `appPrimary`
  border + check icon when selected) reused for both the prescription list
  and the matching-stock-item list.
- **2026-07-24 (Part 12: billing + invoicing)** — Line items get their own
  inline-editable row pattern (description + RWF amount + trash icon,
  `IgnorePointer`-disabled once an invoice is voided) — same shape as the
  doctor-schedule builder's rows, now applied to money instead of time. A
  running total updates live as amounts are typed, shown only in the
  editable state (a static invoice just shows the summary card below it,
  no redundant live total). The summary card (`_SummaryCard`) is the first
  place a "bold last row" total pattern appears — every prior line plain,
  the final Balance Due row bold, set off by a plain `Divider` — reused
  wherever a running-total breakdown is shown (Cash paid / Insurance
  covered / Balance due). Void's confirmation dialog collects a required
  reason via `CliniqnovvaTextField` inline in the dialog body — the first
  dialog in the app to combine a confirm action with mandatory text input
  rather than just a plain yes/no. Receipt PDF (`pdf` + `printing`
  packages, A5 page) is plain black-on-white, no brand color — a legal/
  financial document, not a themed UI surface.
- **2026-07-24 (Part 11: appointment booking + queue)** — `SegmentedTabs`
  (`shared/widgets/segmented_tabs.dart`) is the tab-selector pattern
  promoted out of Patient Profile's private `_TabSelector` — same
  `appSecondaryBg` track / `appCard` pill, now shared by Patient Profile's
  Profile/Medical Records/Documents tabs AND Appointments' Today/Upcoming/
  History tabs. Booking screen introduces a numbered step-card layout
  ("1. Patient", "2. Department & Service", …) — each `_SectionCard` only
  renders once its prerequisite is chosen, so the form reveals itself
  progressively rather than showing every field disabled up front. Slot
  buttons reuse the branch-form/doctor-schedule "chip with `appPrimary`
  fill when selected" look, now applied to time-of-day picks specifically.
  The Appointments table's Actions cell shows only the buttons a
  status legally allows next (never a disabled "Mark Complete") — the UI
  literally cannot offer an illegal transition, matching the server's own
  state-machine enforcement. A `_QueueBanner` ("Now Serving #N · N
  waiting · Last completed #N") sits between the page header and the tab
  row — plain `cardDeco()` card, no color accent, since this is status
  information, not a warning.
- **2026-07-23 (Part 10: duplicate detection + patient merge)** — New
  patterns: the Register Patient flow no longer pre-flight-checks before
  submitting — it submits directly and branches on the server's response
  (created vs. 409 possible-duplicate), which simplified the screen and is
  now the reference pattern for "server decides, client reacts" flows
  instead of a separate check-then-submit round trip. Merge Patients
  (`/patients/merge`) introduces a two-slot side-by-side comparison layout
  (`_PatientSlot`, each independently searchable, swappable via a "Change"
  link) — the first screen in the app comparing two records of the same
  type at once. A `_CountRow` (label left, bold value right) is the
  compact stat-line pattern for the record/appointment/invoice/document
  counts; reappears anywhere a quick side-by-side numeric comparison is
  needed. The "Merge" action is gated behind a confirming `AlertDialog`
  naming both patients by name (not just "are you sure") since it moves
  clinical/financial history between records — the bar for a plain
  confirm dialog vs. a stronger warning treatment is "does it move or
  destroy data," and this clears it without needing the red/error
  treatment (nothing is deleted, it's explained plainly instead).
- **2026-07-23 (Part 9: patient records + front-desk registration)** — New
  patterns: a 3-segment tab selector (`_TabSelector` on Patient Profile —
  `appSecondaryBg` track, `appCard` selected pill, same shape as the
  Light/Dark theme toggle in the sidebar's profile menu) used instead of
  Material's default `TabBar`, keeping the "no primary color" rule intact
  without needing to re-theme an indicator line. A reusable
  `PatientAddressForm` (`GlobalKey`-driven `validate`/`value` pattern, same
  contract as `BranchForm`) shared between Register Patient and the Profile
  tab's edit form, plus public `LabeledDropdown`/`GenderDropdown`/
  `PatientDateField` in `patient_form_fields.dart` — the first form-field
  extraction promoted to a shared file rather than duplicated privately
  per-screen, since Register and Profile needed the exact same ~150-line
  address block twice. Role-restricted tab content renders a plain
  `_RestrictedNotice` card (message only, no icon/warning color — this
  isn't an error state, just "nothing here for you") when the API omitted
  a field entirely, distinct from an empty-list "nothing yet" state.
- **2026-07-23 (Part 8: staff + doctor schedule)** — New patterns: a role
  badge (`_RoleBadge`, `appSecondaryBg` pill, matches the department-chip
  style from onboarding) on the Staff table. Add Staff panel's password
  field has two suffix actions (Generate — `AppIcons.generate`/`arrowPath`
  — and the usual show/hide eye toggle); on create, a plain `AlertDialog`
  with `SelectableText` shows the login email + temp password once,
  matching the master spec's exact phrasing ("Login: ... / Temp password:
  ... — share this directly"). Doctor Schedule screen introduces an
  inline-editable row pattern (day dropdown + two `_MiniTimeButton`s +
  duration field + trash icon, `IgnorePointer`-disabled for a Doctor's own
  read-only view) for the weekly schedule builder — distinct from
  `BranchForm`'s static time buttons since these rows are addable/
  removable. Conflict warnings (blocking a date that overlaps existing
  bookings) use `AppColors.pillAmberBg`/`pillAmberText` — the same amber
  pair `StatusBadge`'s warning type already used, now reused as a banner
  background+text pair rather than just badge text. Public holiday rows
  use a `Switch` identical in styling to the Umuganda-override switch from
  `BranchForm`, confirming that's now the standard toggle look wherever a
  binary override is offered inline in a list row.
- **2026-07-23 (Part 7: departments + service catalog)** — New patterns:
  a right-edge SLIDE-OUT panel (`showServicePanel`, full height, 420px,
  `SlideTransition` from `Offset(1,0)`, left border only) for "+ Add
  Service" — the spec's explicit wording for this one form, distinct from
  the centered-modal quick-add pattern used everywhere else (Add Branch,
  Add Clinic). A small `AlertDialog` (not the full modal chrome) for
  name-only forms — Add/Rename Department. A muted, tooltipped inline label
  ("Has services" / "Has history") replaces the Delete action wherever
  deletion is blocked server-side (department with services attached,
  service with appointment/invoice history) — Deactivate stays available
  either way. Departments/Services screens share a `BranchSelector`
  dropdown (styled like other label-above selects) for a Clinic
  Admin choosing among branches; a Branch Admin never sees it (server-scoped
  to their own branch). Added `AppIcons.trash`/`plus`/`department`
  (Heroicons `trash`/`plus`/`buildingOffice`) to the icon catalog.
- **2026-07-23 (24-hour + overnight working hours)** — The branch form's
  working hours now support round-the-clock clinics (an "Open 24 hours"
  switch that hides the time pickers; stored as `{is24Hours: true}`) and
  overnight shifts: a closing time earlier than the opening time is valid
  and means the branch closes the NEXT day (e.g. 20:00 – 04:00), with a
  subtle "Closes after midnight" hint under the pickers and a
  "(next day)" suffix wherever hours are displayed. The only rejected pair
  is start == end (ambiguous — that's what the 24-hour switch is for).
  Enforced client-side and server-side.
- **2026-07-23 (Part 6: onboarding wizard + branches)** — New patterns:
  full-screen 3-step wizard (`/onboarding`, 560px column, "Step X of 3"
  over a 6px `LinearProgressIndicator` in `appPrimary` on `appSecondaryBg`,
  Back as text button bottom-left / Next-Finish filled bottom-right);
  removable chips (`appSecondaryBg` pill, 20px radius, close icon) for the
  departments step; label-above dropdown styled like `CliniqnovvaTextField`
  (`_LabeledDropdown` in `branch_form.dart`) for Province → District
  cascading selects; tappable time-field buttons (`_TimeButton`, border-only
  field look) opening `showTimePicker`. Branches screen uses the standard
  table components with text-button row actions (Edit / Deactivate). The
  branch form (`BranchForm`) is the one reusable component for onboarding
  Step 1, the Add/Edit Branch modal, and the Branch Admin hours-only mode.
- **2026-07-23 (Login screen made theme-aware)** — The login screen was
  still hardcoded to light colors (`AppColors.pageBackground`/`textPrimary`/
  `textSecondary`), so in dark mode only the theme-driven inputs/button
  flipped while the page stayed white. Now uses `context.appBg`/`appText`/
  `appSubtext` like every other screen, per the global page-background rule.
- **2026-07-23 (Split: black logo on screens, blue app icon)** — The
  on-screen logo went back to the black `Logo.png` mark
  (`assets/images/logo.png` regenerated) at the user's request; the blue
  `AppIcon.png` remains the source for all app icons (favicon, PWA,
  Android/iOS launcher icons) only.
- **2026-07-23 (AppIcon.png → logo + all app icons)** — New repo-root
  `AppIcon.png` source (blue square, white circle, blue cross) replaces
  `Logo.png` everywhere: regenerated `assets/images/logo.png` (256×256,
  on-screen logo, same placements/sizes), `assets/icon/app_icon_source.png`
  (1024×1024 raw square) + reran `flutter_launcher_icons` for Android/iOS,
  `web/favicon.png` (32) and `web/icons/Icon-192/512` (pre-rounded, 25%
  radius), `web/icons/Icon-maskable-192/512` (full-bleed).
- **2026-07-23 (New logo mark + smaller sizes)** — New repo-root `Logo.png`
  source (black square, white circle, black cross) bundled as
  `assets/images/logo.png` (256×256) and used by `CliniqnovvaLogo` on every
  placement, same mark in both themes. Rendered sizes reduced: login
  30px/r10 → 24px/r8, sidebar 26px/r8 → 20px/r6 (widget defaults now
  24/r8). `logo_dark.png`/`logo_light.png` remain bundled but unreferenced.
- **2026-07-23 (Logo → always the dark mark)** — `CliniqnovvaLogo` no longer
  switches assets by theme: it now renders `assets/images/logo_dark.png` in
  both light and dark mode (explicit instruction; supersedes the 2026-07-20
  theme-aware rule). `logo_light.png` remains bundled but unreferenced. See
  "Brand assets" above. (Superseded same-day by the new `Logo.png` mark.)
- **2026-07-23 (Audit log feature + Oversight page removed)** — The
  platform audit log display and the whole "Platform Oversight" page
  (`/super-admin/oversight`, cross-clinic branch/staff search, read-only
  record lookup, and the filterable audit log table) were removed at the
  user's request — not needed. Deleted `oversight_screen.dart`, its route,
  and its sidebar nav item; removed the "Recent platform activity" table
  from the Overview page; removed the now-unused backend endpoints
  (`GET /audit-log`, `GET /search`, `GET /record/:collection/:id`) and their
  service functions; removed `AuditLogEntry`/`AuditLogFilter`/
  `PlatformSearchResults`/`BranchSearchResult`/`StaffSearchResult` from the
  Flutter models. Support View (accessed from a Clinic detail page's "View
  as Clinic Admin" button) is unaffected — its "Exit" now returns to the
  clinic's detail page instead of the deleted Oversight page. **The
  underlying audit-log writes on every mutation (suspend/activate, billing
  status changes, staff invites, branch creation, payments recorded,
  Support View start/end) were intentionally left in place** — this was a
  removal of the viewing feature, not the accountability trail itself;
  flag it if the write-side should go too.
- **2026-07-23 (Overview "recent" panels → full-width tables)** — "Recent
  clinics" and "Recent platform activity" changed from two half-width cards
  side by side (a custom tinted-row list, `_OverviewListRow`) to full-width
  `CliniqnovvaCard`s stacked in a `Column`, each using the standard
  `CliniqnovvaTableHeader`/`CliniqnovvaTableRow` table component with real
  columns (Name/Plan/Created; Action/Clinic/Time) instead of a single
  title+subtitle+trailing row. `_OverviewListRow` was deleted — no other
  callers.
- **2026-07-23 (Real names in the audit log; chart curve fix)** — The
  platform audit log (Oversight screen + Overview's "Recent platform
  activity") was showing raw Firestore ids for Clinic and Actor, which read
  as fake/meaningless even though the entries were real. `getAuditLog`
  (`platform.service.js`) now resolves `clinicId` → the clinic's real
  name and `actorId` → a real name/email (`/users` doc first, falling back
  to the Firebase Auth record for auth-only accounts like Super Admin) —
  new `clinicName`/`actorLabel` fields on `AuditLogEntry`. Also fixed
  the revenue chart's curve dipping below the axis and overlapping the
  month labels on a sharp flat-to-steep jump — see the Overview page's
  Chart section above for the `preventCurveOverShooting`/`clipData` fix.
- **2026-07-23 (Loading/success SnackBar on every write action)** — Added
  `runWithFeedback` (`shared/utils/async_feedback.dart`) and a new global
  `SnackBarThemeData` (black/white-inverted, matching `CliniqnovvaButton`).
  Every Super Admin mutation now shows a loading SnackBar while in flight and
  a success one when it resolves: Add Clinic, Suspend/Activate (both the
  Clinics list and Clinic detail screen), Save changes on Clinic detail,
  Create branch on a clinic's behalf, set billing status, record a payment.
  Read-only actions (search, View record, Support View) were left alone —
  see "Loading/success feedback" above for the reasoning.
- **2026-07-23 (Revenue chart → sky blue, fixed label crowding)** — Added
  `AppColors.skyBlue` (`#38BDF8`) as the system's second primary color — the
  one deliberate exception to the black/white-only rule. The Overview
  revenue chart's line changed from `context.appPrimary` to `skyBlue`, and
  its area fill to `skyBlue` at a lower alpha (0.15, up from 0.08) so it
  reads as a visible tinted wash rather than a near-invisible grey haze.
  Also fixed the x-axis: it previously rendered a label for every single
  data point, which overlapped/duplicated once there were more than ~8
  months of data — now capped at ~8 evenly-spaced labels via a computed
  `labelInterval`.
- **2026-07-23 (Manual billing status + payment gate)** — `billingStatus` is
  now a manually-set field (`notPaid` | `pending` | `paid`, default `notPaid`
  on clinic creation) instead of computed from `nextDueDate` — the Super
  Admin sets it via a new 3-option chip selector (`_BillingStatusChip`,
  `payment_history_panel.dart`): filled black/white (`context.appPrimary`)
  when selected, border-only otherwise — same selection-state pattern as
  everywhere else in the system. **Recording a payment is only allowed once
  a clinic is marked `paid`** — the "+ Record Payment" button is disabled
  (with a one-line explanation) otherwise, enforced both client-side and
  server-side (`PUT /api/v1/clinics/:id/billing-status`,
  `POST .../record-payment` now 400s if not yet marked paid). The Billing
  screen's metric row changed from 2 cards (paid/overdue) to 3 (paid /
  pending / not paid) to match.
- **2026-07-23 (StatusBadge → bright, no background)** — `StatusBadge` no
  longer renders a pill/background at all (the `filled` toggle from the
  previous change is gone — always plain text now). Success/error status
  text (Active/Suspended, Paid/Overdue, etc.) uses new bright, no-background
  colors `AppColors.brightGreen` (`#34C759`) / `brightRed` (`#FF3B30`) instead
  of the muted `pillGreenText`/`pillRedText`, which remain only for inline
  banners with a tinted background. Applies everywhere `StatusBadge` is used
  (Clinics list, Clinic detail, Billing, Support View).
- **2026-07-23 (Add Clinic → centered modal)** — The "Add Clinic" panel
  (`add_clinic_panel.dart`) changed from a right-side 480px slide-out
  sheet to a centered 480px modal: `Center` + fade/scale transition, rounded
  `AppTheme.cardRadius` (18px) with a `context.appBorder` border, capped at
  85% of screen height. See "Centered modal panel" above — this is now the
  reference pattern for future quick-add forms (the slide-out pattern is
  retired). Also: "Clinic" renamed to "Clinic" throughout Super Admin
  UI text (nav label, screen titles, button/field labels, dialogs) — internal
  Dart identifiers, routes, and backend/Firestore field names (`clinicId`,
  `clinics` collection) intentionally kept as-is.
- **2026-07-24 (Overview page + chart)** — New Super Admin landing page,
  `/super-admin/overview`, first sidebar item, first page reached after
  login. Real revenue-growth `LineChart` (single series, `appPrimary` +
  low-alpha fill, no color accent). Add Clinic panel gained a
  "Subscription amount (RWF)" field (was previously only settable after
  creation, on the detail page).
- **2026-07-24 (primary retired + dialogs)** — `AppColors.primary` (brand
  lime) deleted entirely; the system "primary" is now `context.appPrimary`
  (black light / white dark), and the app's `ColorScheme` is seeded from
  black/white instead of lime. Every dialog themed globally
  (`AppTheme._dialogTheme()`) — one title style, one content style, page-flat
  background, no shadow — fixing both the beige wash and the previously
  inconsistent per-dialog text styling. `StatusBadge` gained a `filled: false`
  mode (plain colored text, no pill background); used for the Clinics
  table's Status column.
- **2026-07-24 (date picker)** — `showDatePicker` explicitly themed
  black/white in both modes (`AppTheme._datePickerTheme()`) — was silently
  inheriting a beige/olive Material 3 default from the lime `ColorScheme`
  seed. `surfaceTintColor: Colors.transparent` was the key fix for the
  background wash; selected-day/today styling matches the button inversion
  rule. No primary color anywhere in the calendar.
- **2026-07-24 (language submenu)** — Language row in the profile menu now
  opens a second floating panel (same styling, positioned beside the main
  menu to its right) instead of a dialog — design-only, no `setLocale()` call
  yet. Main menu padding reduced to 10px (was 16px).
- **2026-07-24 (refinement pass)** — Sidebar: tighter logo/wordmark gap (4px),
  smaller nav icons/text (16px/13px), larger tile radius (14px) and more
  vertical gap between items (6px). Profile chip corrected back to
  no-background/border-only (the same-day "lime background" version was
  wrong). Profile dropdown menu: border restored, positioned a fixed 50px
  from the window's left edge (was centered over the chip, which made it read
  as clipped to the sidebar). Topbar chat icon switched to the specific
  `chatBubbleOvalLeftEllipsis` heroicon. Removed `AppTheme.cardShadow`
  entirely (translucent-lime shadow, unreadable in light mode) — see "No
  mixing colors."
- **2026-07-24** — Sidebar: removed the divider under the logo, added a
  1px right-edge divider marking the sidebar's end, active-item background
  changed from primary-lime tint to a new neutral `context.appSecondaryBg`
  token. Profile chip rebuilt: no border, always primary-lime background,
  "more" icon opens a floating theme/language/logout menu (custom
  `OverlayEntry`, not `PopupMenuButton`). Topbar: removed the bottom border;
  replaced the "Super Admin" pill + "Sign out" button with a plain chat +
  notification icon row — sign-out now lives only in the sidebar's profile menu.
- **2026-07-23** — Major overhaul copied from the HRNova reference project
  (`C:\WhiteZebra\HRNova`): sidebar background retired (now matches the page,
  no more permanent deepNavy), sidebar active-item left border removed
  (replaced with a soft primary-tinted pill), Heroicons adopted app-wide
  (`AppIcons`/`AppIcon`, no more `Icon`/`Icons.*`), dark mode unified to pure
  black with cards/containers matching the page exactly (`pageBackgroundDark`,
  "No mixing colors" rule), new `theme_ext.dart` `BuildContext` extension for
  theme-aware colors. Suspended screen's old always-navy background retired
  too, since it's now covered by the same global page-background rule.
- **2026-07-20** — Brand-asset sources replaced with `Light Logo.png`/
  `Dark Logo.png`; favicon/PWA/mobile icons now derive from `Dark Logo.png`.
- **2026-07-20** — In-app logo is theme-aware via the `CliniqnovvaLogo` widget:
  light-mode mark in light mode, dark-mode mark in dark mode.
- **2026-07-19** — All brand assets (favicon, PWA icons, mobile app icons,
  in-app logo) now derive from `Logo.png`; `favappIcon.png` retired. Logo added
  to the sidebar on every dashboard page.
- **2026-07-19** — Theme mode defaults to light (was system): OS dark mode was
  turning buttons white-on-white against the hardcoded white pages.
- **2026-07-19** — Filled buttons theme-inverted: black/white in light mode,
  white/black in dark mode.
- **2026-07-19** — All backgrounds pure white `#FFFFFF` (pages, input fills);
  removed the old `backgroundTint` `#F6FAFA`.
- **2026-07-18** — Login rebuilt per Signin reference; real brand assets wired.
- **2026-07-18** — Primary color teal `#2A9D8F` → lime `#CFFF04` (from the
  Overview chart reference).
- **2026-07-18** — Flexra design language applied: General Sans, pill buttons,
  radius-12 inputs, radius-18 cards, no italics.
