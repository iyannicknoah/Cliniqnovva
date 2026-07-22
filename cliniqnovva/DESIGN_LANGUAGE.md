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

| Token | Value | Use |
|---|---|---|
| `primary` | `#CFFF04` (lime) | Brand accent: focus borders, highlights, charts |
| `pageBackground` | `#FFFFFF` (pure white) | Every page/scaffold background, input fills, containers (light mode) |
| `deepNavy` | `#0B2545` | Sidebar, suspended screen, dark surfaces |
| `textPrimary` | `#0B2545` | Headings and body text |
| `textSecondary` | `#5B6B73` | Labels, captions, subtitles |
| `successGreen` / `warningAmber` / `errorRed` | `#2ECC71` / `#F4A261` / `#E63946` | Status semantics |
| Pill pairs (`pillGreenBg/Text` etc.) | — | Status badges and inline banners |
| `avatarGradients` | 26 letter-keyed gradients | Avatar initials |

Dark mode surfaces: background `#071820`, cards `#0F2430` (private to `AppTheme`).

## Shape (`AppTheme`)

- Buttons: fully-rounded pill, radius **30**, height **45**
- Inputs: radius **12**, border width 1, dense, filled
- Cards: radius **18**, hairline border, white in light / `#0F2430` in dark

## Buttons (`CliniqnovvaButton`)

**Filled buttons are theme-inverted** (rule set 2026-07-19):

- **Light mode: black background, white text.**
- **Dark mode: white background, black text.**

Leave `color` unset to get this automatically — the component resolves it from
the active theme. Only pass an explicit `color` when the button sits on a
surface that ignores the theme (e.g. the always-navy suspended screen uses
`Colors.white`). Text color is auto-picked for contrast
(`estimateBrightnessForColor`): black text on light fills, white on dark fills —
never hardcode a foreground.

`.text()` is the transparent link-style secondary variant ("Forgot password?"),
with an optional underline.

## Backgrounds

Pure white (`AppColors.pageBackground`) everywhere in light mode (rule set
2026-07-19): scaffold backgrounds, text-field fills, containers, dropdowns.
There is no off-white tint token anymore — do not reintroduce one.

## Admin screen layout

`SuperAdminScaffold` (`features/super_admin/widgets/super_admin_scaffold.dart`)
is the shared shell for every Super Admin screen: `CliniqnovvaSidebar` on the
left, a topbar (screen title, "Super Admin" pill badge, sign-out button) on
the right, body content scrolls underneath. New Super Admin screens should use
this instead of building their own Scaffold/Row/sidebar boilerplate.

## Slide-out panel

A right-side 480px panel (`Add Organization`, `features/super_admin/widgets/
add_organization_panel.dart`) — `showGeneralDialog` + `Align(alignment:
centerRight)` + a `SlideTransition` from `Offset(1,0)` to `Offset.zero`. Reuse
this pattern for any future "quick add" form that shouldn't be a full page.

## Theme mode

The app defaults to **light mode**, never `ThemeMode.system`. Page backgrounds
are hardcoded pure white, so inheriting the OS's dark mode would flip only the
theme-driven pieces (buttons turning white-on-white and vanishing). Dark mode
is an explicit in-app choice via `ThemeNotifier.setThemeMode`/`toggle`.

## Components (`lib/shared/widgets/`)

`CliniqnovvaButton`, `CliniqnovvaTextField`, `CliniqnovvaCard`, `MetricCard`
(label over 18px w600 value), `CliniqnovvaTableHeader` + `CliniqnovvaTableRow`
(divider-bracketed header, `Expanded`-per-cell rows), `StatusBadge`,
`AvatarWidget`, `CliniqnovvaSidebar` (always deepNavy in both themes).

## Brand assets

- Current source marks at the repo root: **`Light Logo.png`** and
  **`Dark Logo.png`** (both 2000×2000) — supersede the earlier
  `favappIcon.png`/`Logo.png` pair, which are no longer referenced.
- **In-app logo is theme-aware** (rule set 2026-07-20): light mode shows
  `assets/images/logo_light.png` (from `Light Logo.png`), dark mode shows
  `assets/images/logo_dark.png` (from `Dark Logo.png`). Always use the shared
  `CliniqnovvaLogo` widget (`size`, `radius` params) — never `Image.asset` a
  logo file directly. Placements: login screen (30px, radius 10) and sidebar
  (26px, radius 8), each next to the bold wordmark.
- Favicon, PWA icons, and mobile app icons all derive from **`Dark Logo.png`**.
- Mobile icon source (`assets/icon/app_icon_source.png`) must stay a raw,
  un-rounded square — the OS applies its own mask. Web favicon/PWA icons are
  pre-rounded (browsers don't mask); maskable PWA variants stay full-bleed.

## Change log

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
