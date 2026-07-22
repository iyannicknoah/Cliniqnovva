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
| `primary` | `#CFFF04` (lime) | Brand accent: focus borders, highlights, charts, active-nav tint. **Never as body text/icon color** — too pale to read on white, see Sidebar below. |
| `pageBackground` | `#FFFFFF` (pure white) | Every page/scaffold background, input fills, containers (light mode) |
| `pageBackgroundDark` | `#000000` (pure black) | Same role as `pageBackground`, dark mode (rule set 2026-07-23) |
| `textPrimary` | `#0B2545` | Headings/body text, light mode only — use `context.appText` (theme-aware) for anything that also renders in dark mode |
| `textSecondary` | `#5B6B73` | Labels/captions, light mode only — use `context.appSubtext` for theme-aware text |
| `successGreen` / `warningAmber` / `errorRed` | `#2ECC71` / `#F4A261` / `#E63946` | Status semantics |
| Pill pairs (`pillGreenBg/Text` etc.) | — | Status badges and inline banners |
| `avatarGradients` | 26 letter-keyed gradients | Avatar initials |

`deepNavy` (`#0B2545`) still exists but is no longer used for any page/sidebar
background — see the "no mixing colors" rule below.

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
`AvatarWidget`, `CliniqnovvaSidebar` (background matches the page, see Sidebar
above), `AppIcon` (Heroicons wrapper, see Icons above).

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
