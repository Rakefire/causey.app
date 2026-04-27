---
marp: true
theme: default
paginate: true
title: causey.app — GHA Deploy Flow
---

# GHA Deploy Flow

**www.causey.app**

Bridgetown 2.1 (migrated from Jekyll) → GitHub Pages

Single workflow: `.github/workflows/pages.yml`

---

## Triggers

- `push` to `main` / `master`
- `schedule: "0 6 * * *"` — daily 06:00 UTC rebuild
- `workflow_dispatch` — manual

**Permissions**

- `contents: read`, `pages: write`, `id-token: write`

**Concurrency**

- `group: pages`, `cancel-in-progress: false`

---

## Two jobs: `build` → `deploy`

```
build (ubuntu-latest)
  └─ checkout → setup ruby → rake deploy → upload artifact

deploy (ubuntu-latest, needs: build)
  └─ actions/deploy-pages@v4
```

---

## `build` job — environment setup

1. `actions/checkout@v4`
2. `ruby/setup-ruby@v1` — Ruby `4.0.3`, `bundler-cache: true`
3. `actions/configure-pages@v5`

**No Node setup, no `npm ci`** — the esbuild scaffolding was removed
(it was never invoked in CI and nothing in the source tree referenced it).
The `package.json` that remains exists only for the local Bookshop dev
workflow.

---

## The build step

```yaml
- run: bundle exec rake deploy
  env:
    BRIDGETOWN_ENV: production
```

`rake deploy` chains `:clean → bridgetown build` and is the same entrypoint
used locally — so CI and local builds run the same task graph.

---

## Bridgetown config (Jekyll-shaped)

`config/initializers.rb` translates `_config.yml` → Bridgetown:

- `url "https://www.causey.app"`
- `template_engine "liquid"` — Liquid, not ERB (legacy from Jekyll)
- `permalink "/:slug/"`
- `slugify_mode "default"` — match Jekyll's stricter slug rules
- `bookshop_locations = ["../component-library"]` — sibling repo lookup
- `init :"bridgetown-feed"`, `init :"bridgetown-sitemap"`
- Custom collections: `posts`, `pages`, `staff_members` (output: false), `clients`
- `defaults` array preserved from Jekyll, including a global `layout: default`
- `posts` get `dont_render_bookshop_components: true`

---

## Site builders (`plugins/builders/`)

| Builder | What it does |
|---|---|
| `agent_skills` | Writes `.well-known/agent-skills/index.json` + skill files |
| `api_catalog` | Linkset → agent-skills index |
| `markdown_for_agents` | Emits markdown twins of HTML pages |
| `archives_and_redirects` | Generates archive index pages + redirect stubs |
| `bridgetown_bookshop` | Custom Bookshop integration reading `../component-library` |
| `jekyll_compat` | Compatibility shims for Jekyll-era templates |
| `indexnow` | Submits sitemap URLs to IndexNow API after each production build |
| `html_minifier` | Minifies all `output/**/*.html` via `htmlcompressor` |

The Bookshop and Jekyll-compat builders are unique to this site
because of the migration history.

---

## IndexNow

After each production build, `plugins/builders/indexnow.rb`:

1. Reads `output/sitemap.xml`
2. POSTs the URL list to `https://api.indexnow.org/indexnow`
3. Uses key `2df97b9b-a29d-43a6-9963-4f9f5121c603`, served at
   `https://www.causey.app/2df97b9b-a29d-43a6-9963-4f9f5121c603.txt`
   (committed at `src/2df97b9b-a29d-43a6-9963-4f9f5121c603.txt`)

Runs when `BRIDGETOWN_ENV=production` or `INDEXNOW=true`.

---

## HTML minifier

`plugins/builders/html_minifier.rb` runs on `:post_write` (skipped during
`--watch`) and compresses every `*.html` under `output/` using
`htmlcompressor` (gem). Strips comments and multi-spaces, preserves
intertag spaces and line breaks where it matters.

---

## Sitemap, feed, robots

| File | Source |
|---|---|
| `/sitemap.xml` | `bridgetown-sitemap` gem |
| `/feed.xml` | `bridgetown-feed` gem |
| `/robots.txt` | `src/robots.txt` (committed) |

No SEO-tag plugin — SEO metadata is handled in the layouts.

---

## Sass / CSS

`Gemfile` includes `sass-embedded ~> 1.99`.

`plugins/scss_converter.rb` is the actual SCSS compilation path: a
sass-embedded converter plus a Ruby implementation of postcss-fluidvars
(synthesizes `--s-N-M` clamp() vars). `src/assets/main.scss` →
`output/assets/main.css`.

`src/assets/cms-styles.css` is the committed Bookshop CMS stylesheet.

---

## Artifact + deploy

```yaml
- uses: actions/upload-pages-artifact@v5
  with:
    path: output

deploy:
  needs: build
  steps:
    - uses: actions/deploy-pages@v4
```

Standard Pages handoff.

---

## Caching summary

| Layer | Cached? |
|---|---|
| `vendor/bundle` | ✅ via `bundler-cache: true` |
| `node_modules` | n/a — Node never set up; esbuild scaffolding removed |
| `output/` | ❌ regenerated each run |

---

## Notable per-run side effects

- **IndexNow submission** to api.indexnow.org on production builds
- **HTML minification** of all output HTML
- **Daily cron rebuild** — anything time-dependent (date helpers,
  future-dated content) refreshes daily
- **Bookshop component library is read from a sibling repo**
  (`../component-library`) — but only what's committed at build time

---

## Failure modes to know about

- **`../component-library` not present** → Bookshop builder fails (CI
  checks out only this repo). If this currently works, it's because
  everything Bookshop needs is already inlined or the builder degrades
  gracefully.
- **IndexNow API outage** → builder logs a warning, build still succeeds
  (rescued in the builder)
- **Cron drift** → site rebuilds daily even when nothing changes,
  costing a Pages deployment slot

---

## Files / paths to know

```
.github/workflows/pages.yml          # workflow (calls rake deploy)
Rakefile                             # :deploy → :clean + bridgetown build
config/initializers.rb               # Liquid template engine, Jekyll-shaped config
plugins/builders/
  ├── agent_skills.rb
  ├── api_catalog.rb
  ├── markdown_for_agents.rb
  ├── archives_and_redirects.rb
  ├── bridgetown_bookshop.rb         # reads ../component-library
  ├── jekyll_compat.rb               # migration shims
  ├── indexnow.rb                    # IndexNow submission
  └── html_minifier.rb               # htmlcompressor pass
plugins/scss_converter.rb            # sass-embedded + postcss-fluidvars equiv
src/2df97b9b-a29d-43a6-9963-4f9f5121c603.txt  # IndexNow key file
src/assets/main.scss                 # site CSS source
src/assets/cms-styles.css            # committed Bookshop CMS CSS
package.json                         # Bookshop dev workflow only
```

---

# End

Questions?
