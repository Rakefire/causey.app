# Causey Website

Bridgetown + Bookshop component-based site for causey.app. Migrated from
Jekyll in April 2026; the legacy `site/` tree was removed once production
parity was confirmed against `https://www.causey.app`.

## Development

- `npm start` runs the Bridgetown dev server (port 6061) plus `bookshop-browser`
- Source lives at the repo root: `src/_layouts/`, `src/_includes/`, `src/_posts/`, `src/_pages/`, etc.
- Bookshop component library: `component-library/components/`
- SCSS follows BEM naming, uses CSS variables for theming (`src/_data/themes.yml`)
- Build with `BRIDGETOWN_ENV=production bundle exec bridgetown build` → `output/`

## Custom Bridgetown plugins

Ported during the Jekyll migration to fill gaps Bridgetown doesn't ship:

- `plugins/builders/bridgetown_bookshop.rb` — `{% bookshop %}`,
  `{% bookshop_include %}`, `{% bookshop_scss %}` Liquid tags (re-implements
  jekyll-bookshop, since no Bridgetown engine exists)
- `plugins/builders/jekyll_compat.rb` — Jekyll-style `{% include %}`,
  Jekyll-flavored `find` filter, drop shims for `site.<collection>`,
  `page.url`, swapped `post.next`/`post.previous` semantics
- `plugins/builders/archives_and_redirects.rb` — replaces `jekyll-archives`
  and `jekyll-redirect-from`
- `plugins/scss_converter.rb` — sass-embedded converter plus a
  postcss-fluidvars equivalent that synthesizes `--s-N-M` clamp() vars

## Verification

`verification/scripts/` runs Playwright + Pixelmatch against any reference
URL (production or another local build). `node capture.js --bridgetown` and
`node capture.js --baseline --base-url=https://www.causey.app` capture PNGs
at three viewports; `node diff.js` compares with a 0.1% per-page threshold.
Last full run: 196/201 pages + 52/52 redirects + 65/66 SEO meta + 68/68
sitemap entries vs. production.

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
