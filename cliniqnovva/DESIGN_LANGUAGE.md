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
(2026-07-23)** — the one deliberate exception to "no color accent." Currently
used for the Overview revenue chart (line + a more-transparent fill beneath
it). Reach for this before introducing any other accent color; it isn't a
per-chart one-off.

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
- **In-app logo is one single mark** (rule updated 2026-07-23):
  `assets/images/logo.png` (256×256, downscaled from the black `Logo.png`)
  is shown in BOTH light and dark mode. `logo_dark.png`/`logo_light.png` stay in the
  asset bundle but are unreferenced. Always use the shared `CliniqnovvaLogo`
  widget (`size`, `radius` params) — never `Image.asset` a logo file
  directly. Placements (sizes reduced 2026-07-23): login screen (24px,
  radius 8) and sidebar (20px, radius 6), each next to the bold wordmark.
- Favicon, PWA icons, and mobile app icons all derive from **`AppIcon.png`**.
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
