# Colour themes

## Invariants

- Tinycast Dark and Tinycast Light preserve the shipped colour tokens. The theme harness checks
  both sets of literals at framebuffer precision.
- `AppAppearance` chooses Dark, Light or System. Each appearance has its own selected theme ID.
  System leaves `NSApp.appearance` unset so macOS still owns the appearance.
- The palette, its floating surfaces, dialogs, HUDs, Quick Actions and Notes consume `Theme.Colors`.
  Settings and AI Chat use the baseline. Icons and masks carry their own rendering rules.
- A palette holds colours. Window opacity and blur are appearance preferences shared across variants.

## Theme definitions

Definitions are strict JSON objects. The example below customises Nord.

```json
{
  "id": "nord-midnight",
  "name": "Nord Midnight",
  "variant": "dark",
  "inherits": "nord",
  "colors": {
    "accent": "#EBCB8B",
    "accent_foreground": "#2E3440",
    "background": "#242933A6",
    "foreground": "#ECEFF4",
    "secondary_background": "#2E3440",
    "border": "#4C566A",
    "muted": "#A5AFBF",
    "selection": "#88C0D038",
    "syntax_keyword": "#B48EAD",
    "menu_background": "#2E3440C0"
  }
}
```

`id`, `name` and `variant` are required. The variant is `dark` or `light`. `inherits` and
`colors` are optional. Use a stable, unique ID for each definition. Colour values are sRGB
`#RGB`, `#RRGGBB` or `#RRGGBBAA` strings.

The `colors` object accepts these keys:

| Key | What it colours |
| --- | --- |
| `accent` | Primary actions, focus accents, progress and drop targets |
| `accent_foreground` | Text and glyphs drawn over the accent |
| `background` | The main window scrim and the default menu opacity |
| `foreground` | Primary text, carets, and the base ink for translucent fills and borders |
| `secondary_background` | Raised surfaces such as room cards, tooltips and the terminal |
| `border` | Control borders, card outlines, separators and emoji hover outlines |
| `muted` | Secondary text and menu symbols, with a fallback for syntax comments |
| `placeholder` | Placeholder text and other tertiary labels |
| `selection` | Selected row fills |
| `danger` | Destructive actions and the fallback for syntax deletions |
| `success` | Success indicators and the fallback for syntax insertions |
| `warning` | Warning indicators |
| `blue` | Links and a fallback hue for syntax functions, types and properties |
| `cyan` | A fallback hue for syntax types, properties and functions |
| `green` | A fallback hue for success, syntax strings and insertions |
| `magenta` | A fallback hue for syntax keywords and constants |
| `orange` | A fallback hue for warnings, syntax numbers and attributes |
| `purple` | A fallback hue for syntax constants and keywords |
| `red` | A fallback hue for destructive actions and syntax deletions |
| `yellow` | Find highlights and a fallback hue for warnings, syntax numbers and attributes |
| `menu_background` | Floating menu backgrounds, including their theme opacity |
| `syntax_keyword` | Language keywords |
| `syntax_string` | String literals |
| `syntax_number` | Numeric literals |
| `syntax_comment` | Comments |
| `syntax_type` | Type names |
| `syntax_function` | Function names |
| `syntax_constant` | Constants |
| `syntax_attribute` | Attributes and annotations |
| `syntax_property` | Property names |
| `syntax_inserted` | Added lines in a diff |
| `syntax_deleted` | Removed lines in a diff |

`ThemeDefinition.decode(_:)` returns a definition and diagnostics. Invalid JSON or invalid required
metadata prevents a definition from loading. Unknown fields and invalid colour values are reported
and skipped. A child supplies overrides before its parent contributes missing colours. An unresolved,
cross-variant or cyclic parent link is reported and ends traversal. Colours collected so far still
apply. Built-in IDs are reserved. For a duplicate user ID the catalogue retains the first definition
in the input order and reports the collision.

The catalogue resolves each selection by ID and variant. A definition that inherits a baseline
theme with no colour overrides keeps the baseline rendering.

## User theme files

Save one definition per file in `~/.config/tinycast/themes/*.json`. Debug builds use
`~/.config/tinycast-dev/themes/`. Other channels and forks use the same bundle-ID rule as
[settings.json](settings-file.md#location).

In **Settings → General → Appearance**, **Create theme file** creates the folder if needed and
reveals a starter file in Finder. It copies the current Dark or Light theme's resolved colour
overrides, inherits that theme and picks an unused ID such as `my-theme`. **Themes folder → Open**
opens the existing folder in Finder. The pickers list user and built-in themes separately.

Both processes load the folder after launch and reload it after writes settle. This includes
in-place edits, saves by rename, and files or the folder appearing and disappearing. Tinycast
reads the first 200 visible regular JSON files in filename order, without recursing into
subfolders or following file symlinks. Each file is limited to 256 KB and the total decoded
input to 2 MB. With duplicate IDs, the first usable definition in filename order wins.

Appearance lists current issues with filenames, including inheritance problems in themes that
are unselected. The main app shows a brief HUD when a new issue appears. If a selected theme
disappears, Tinycast keeps its ID and uses the variant's default until that theme returns. The
issue includes the last known filename when Tinycast has seen the selected theme in this session.

Theme files contain colour data and cannot grant capabilities. These files stay in the config
folder and are excluded from settings backups and iCloud Sync. The selected theme IDs still
travel with the appearance preferences.

## Derivation

- `background` and `foreground` default to the selected variant's scrim and ink. When
  `secondary_background` is absent, it mixes the background towards the foreground by 8% in Dark
  or 4% in Light and keeps the background alpha.
- Rows, hovers, separators and controls use the foreground with the variant's token alpha stops.
  When a token uses `selection`, `border`, `muted`, `placeholder` or `accent`, it takes that
  colour and its alpha if supplied. The foreground ramp supplies gaps.
- Primary actions, progress and drop targets use the accent, with the system accent as a fallback.
  `accent_foreground` supplies ink over the accent. Its default is black or white, whichever
  contrasts more with the accent. Destructive actions look for `danger` then `red`, success
  looks for `success` then `green`, and warnings look for `warning`, `orange`, then `yellow`.
  Each falls back to its original system colour. Find marks prefer `yellow`, then `accent`,
  then the system highlighter. Links prefer `blue`, then `accent`, then the system link colour.
- Syntax colours prefer their own `syntax_*` key, then take the first available fallback.
  Keywords use `magenta`, `purple`, then `accent`. Constants reverse the order of the two hues.
  Strings use `green` then `accent`. Numbers and attributes use `orange`, `yellow`, then `accent`.
  Types and properties use `cyan`, `blue`, then `accent`. Functions reverse the order of the
  two hues. Comments use `muted`, insertions use `success` then `green`, and deletions use
  `danger` then `red`. If none is supplied, the shipped syntax colour applies.
- Menus use `menu_background` with its own alpha. Otherwise they use the secondary background at
  the theme's background opacity. An explicit window opacity applies to both the panel and the
  menu, including the default themes' menu scrim. Raised surfaces use the secondary background
  with each surface's own alpha.
- Dimming, shadows, layout previews, transparency checkerboards, the brand and icon tile inks
  retain their original colours. Mask gradients retain their original luminance.

## Built-in themes

| Dark | Light | Palette source |
| --- | --- | --- |
| Tinycast Dark | Tinycast Light | Tinycast's shipped `Theme.Colors` literals |
| Tokyo Night | | [Tokyo Night](https://github.com/folke/tokyonight.nvim/tree/main/lua/tokyonight/colors) |
| Catppuccin Mocha | Catppuccin Latte | [Catppuccin palette](https://github.com/catppuccin/palette/blob/main/palette.json) |
| Gruvbox Dark | Gruvbox Light | [Gruvbox](https://github.com/morhetz/gruvbox/blob/master/colors/gruvbox.vim) |
| Nord | | [Nord](https://github.com/nordtheme/nord/blob/develop/src/nord.css) |
| Rosé Pine | Rosé Pine Dawn | [Rosé Pine](https://github.com/rose-pine/neovim/blob/main/lua/rose-pine/palette.lua) |
| Kanagawa | | [Kanagawa Wave](https://github.com/rebelot/kanagawa.nvim/blob/master/lua/kanagawa/colors.lua) |
| Everforest Dark | | [Everforest Medium](https://github.com/sainnhe/everforest/blob/master/autoload/everforest.vim) |
| Dracula | | [Dracula Classic](https://draculatheme.com/spec) |
| | Solarized Light | [Solarized](https://ethanschoonover.com/solarized/) |
| Matte Black | | [Omarchy](https://github.com/basecamp/omarchy/blob/master/themes/matte-black/colors.toml) |

Tinycast chooses a translucent background alpha for each preset so the desktop can still show
through. The original Tinycast values are 0.40 in Dark and 0.55 in Light.

## Settings and live updates

In Settings → General → Appearance, choose the two theme IDs and whether to use the theme's
own opacity. Both pickers show the selected palette's swatches.

| Settings file key | Meaning |
| --- | --- |
| `appearance.theme` | The existing System, Light or Dark appearance mode |
| `appearance.darkTheme` | Theme ID for Dark, default `tinycast-dark` |
| `appearance.lightTheme` | Theme ID for Light, default `tinycast-light` |
| `appearance.windowOpacity` | `null` for the theme's alpha or a numeric override from 0 to 1 |
| `appearance.windowBlur` | Behind-window glass and blur, on by default |

The four new keys travel with the appearance iCloud Sync group and in settings backups.
A backup with the new blur field and an omitted opacity restores the theme's default opacity.
A backup from before these fields leaves the current values in place.

`AppCore` loads the store in both processes so Settings can show the catalogue. The main
process publishes the rendering snapshot. Themed hosting roots observe that snapshot and pass it
through the SwiftUI environment, keeping their view identity and focus. Each theme colour resolves
through `ShapeStyle.resolve(in:)`, so even a cached `Color` value reads the new environment.
The root supplies custom foreground ink to hierarchical styles while the defaults keep system
foreground and vibrancy. Native AppKit colours read the same snapshot under a mutex. The Notes
editor observes palette changes and restyles its TextKit attributes and pinned block decorations.

With blur off the affected glass effects become identity effects or are omitted where AppKit
provides the glass. Menus still get a scrim. With blur on, the compact capsule and floating
interactive controls use a translucent accent tint where present. The main panel keeps the existing
order of scrim, glass and clip.
