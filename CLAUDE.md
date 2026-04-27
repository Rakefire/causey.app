# Causey Website

Bridgetown + Bookshop component-based site for causey.app. Migrated from
Jekyll in April 2026 — see `verification/` for the pixel-perfect parity
harness used during cutover.

## Development

- `npm start` runs the Bridgetown dev server (port 6061) plus `bookshop-browser`
- Bridgetown source: `bridgetown/src/`
- Bookshop component library: `component-library/components/` (unchanged from
  the Jekyll era — the migration ports the build, not the components)
- SCSS follows BEM naming, uses CSS variables for theming
  (`bridgetown/src/_data/themes.yml`, currently a symlink to `site/_data/`)

## Migration status

The Bridgetown port lives in `bridgetown/`. The legacy Jekyll source still
exists in `site/`; content collections (`_pages`, `_posts`, `_drafts`,
`_staff_members`) and `_data`/`images`/`uploads` are accessed via symlinks
from `bridgetown/src/` so both builds see the same content. The final
file consolidation (move content out of `site/`, delete the legacy tree) is
still pending and intentionally left as a manual step.

Custom plugins ported during the migration:

- `bridgetown/plugins/builders/bridgetown_bookshop.rb` — `{% bookshop %}`,
  `{% bookshop_include %}`, `{% bookshop_scss %}` Liquid tags
- `bridgetown/plugins/builders/jekyll_compat.rb` — Jekyll-style
  `{% include %}`, Jekyll-flavored `find` filter, drop shims for
  `site.<collection>`, `page.url`, `post.next`/`post.previous`
- `bridgetown/plugins/builders/archives_and_redirects.rb` — replaces
  `jekyll-archives` and `jekyll-redirect-from`
- `bridgetown/plugins/scss_converter.rb` — sass-embedded converter +
  postcss-fluidvars equivalent (synthesizes `--s-N-M` clamp() vars)

## Verification

`verification/scripts/` runs Playwright + Pixelmatch against both builds.
`node capture.js --baseline` and `node capture.js --bridgetown` capture
PNGs at three viewports; `node diff.js` compares with a 0.1% per-page
threshold. Current parity: 199/201 pages and 52/52 redirects matching.

## Brand Guidelines

Brand guide PDF: `Causey - Brand Standards or Guidelines.pdf` (in repo root)

### Colors

| Name   | Pantone | Hex       | RGB               |
|--------|---------|-----------|-------------------|
| Red    | 7626C   | `#cb3727` | R 203 G 55 B 39   |
| Yellow | 137C    | `#faa21b` | R 250 G 162 B 27  |

### Secondary Colors (Design System)

CSS variables prefixed `--mm-`. Used across the site for theming and UI elements.

| Name        | Hex       | Pantone | RGB                 |
|-------------|-----------|---------|---------------------|
| Light Gold  | `#fdd671` | 127C    | R 253 G 214 B 113  |
| Teal        | `#1d988c` | 7473C   | R 29 G 152 B 140   |
| Dark Navy   | `#243746` | 303C    | R 36 G 55 B 70     |
| Green       | `#46b978` | 7479C   | R 70 G 185 B 120   |
| Cream       | `#f8f0e1` | 7527C   | R 248 G 240 B 225  |
| Warm Gray   | `#686158` | 405C    | R 104 G 97 B 88    |
| Purple      | `#634b78` | 7664C   | R 99 G 75 B 120    |

### Logo Variants

- **Logo (no tag)**: Icon + "causey" wordmark (primary usage, no tagline)
- **Wordmark**: "causey" text only (red with yellow "y")
- **Icon**: Splash/droplet mark only

### Logo Usage Rules

- Use logo as: single color, white, black, or the full color combination
- No colors other than the approved palette above
- Inverted (white) versions exist for use on red or yellow backgrounds

## Screenshots

When using Playwright or browser tools to take screenshots, save them to `.screenshots/` directory (gitignored). Do not save screenshots to the project root.

```
.screenshots/   # All browser automation screenshots go here
```
