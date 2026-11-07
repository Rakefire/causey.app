# Causey Website

Bridgetown 2.2 + Bookshop component-based site for causey.app. Migrated from
Jekyll in April 2026; the legacy `site/` tree was removed once production
parity was confirmed against `https://www.causey.app`.

## Bridgetown setup

- Templates are **Liquid** (`template_engine "liquid"`), not ERB, so the
  Jekyll-era templates and Bookshop components keep working.
- Config lives in `config/initializers.rb` (there is no `bridgetown.config.yml`):
  URL, `/:slug/` permalinks, Jekyll-style `slugify_mode`, collections
  (`posts`, `pages`, `clients` output; `staff_members` data only), front-matter
  defaults, `bridgetown-feed`, `bridgetown-sitemap`, and pagination.
- Pagination is Bridgetown's built-in paginator. `/blog/` sets
  `paginate: { collection: posts, per_page: 10 }`; the `posts-list` component
  reads `paginator.resources` and infinite-scrolls `/blog/page/N/`.
- Changes to `config/initializers.rb` need a dev server restart.
- Upgrade with `bundle update bridgetown --conservative`, then diff `output/`
  against a pre-upgrade build (only `feed.xml`/`sitemap.xml` timestamps and the
  generator version should change).

## Development

- `npm start` runs the Bridgetown dev server (port 6061) plus `bookshop-browser`
- Source lives under `src/`: `_layouts/`, `_includes/`, `_posts/`, `_pages/`,
  `_staff_members/`, `_data/`, `uploads/`
- Bookshop component library: `component-library/components/<name>/` with
  `<name>.jekyll.html`, `<name>.scss`, `<name>.bookshop.yml`. Pages are mostly
  `content_blocks` front matter that render these components.
- SCSS follows BEM naming, uses CSS variables for theming (`src/_data/themes.yml`).
  Root font-size is 10px, so `1.6rem` = 16px.
- Local build: `bundle exec bridgetown build` → `output/`
- **Don't run a production build locally.** `BRIDGETOWN_ENV=production`
  triggers `plugins/builders/indexnow.rb`, which submits every sitemap URL to
  IndexNow. Production builds are for deploys only.

## Tests

- `bundle exec rake test` (or `npm test`) builds the site in the `test`
  environment, then runs Minitest in `test/` using Bridgetown's
  `Bridgetown::Test` (Rack::Test against the Roda server + Nokolexbor).
- `test/test_site.rb` checks every indexable page: title (≤70 chars) and meta
  description, unique titles/descriptions, absolute canonical, one `h1`, image
  `alt` + width/height + file exists, no broken internal links, sitemap/feed.
- `test/test_pages.rb` covers key page behavior (hero screenshot, blog
  pagination, pricing switch, partner logos).
- The GitHub Pages workflow runs the tests before building; a failure stops
  the deploy. Pull requests run the tests only.

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

Post-build output (run after the site is written):

- `plugins/builders/image_attributes.rb` — adds real `width`/`height` and
  `loading="lazy" decoding="async"` to local raster images. Mark
  above-the-fold images `loading="eager"` (the hero also sets
  `fetchpriority="high"`)
- `plugins/builders/html_minifier.rb` — compresses HTML (skipped in watch mode)
- `plugins/builders/markdown_for_agents.rb` — writes a `.md` twin of each page
  for Cloudflare's `Accept: text/markdown` rewrite
- `plugins/builders/agent_skills.rb` — `/.well-known/agent-skills/` from
  `src/_data/agent_skills.yml`
- `plugins/builders/api_catalog.rb` — `/.well-known/api-catalog`
- `plugins/builders/indexnow.rb` — pings IndexNow, production or
  `INDEXNOW=true` only (see above)

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
