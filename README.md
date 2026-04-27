# Causey Website

The marketing site for **[causey.app](https://www.causey.app)** — strategic
planning software for nonprofits.

![Causey homepage](docs/homepage.png)

Built with [Bridgetown](https://www.bridgetownrb.com/) and
[Bookshop](https://github.com/CloudCannon/bookshop), edited in
[CloudCannon](https://cloudcannon.com/). Migrated from Jekyll in April 2026;
the legacy `site/` tree was removed once production parity was confirmed.

## Stack

- **Bridgetown 1.3** (Ruby static site generator) on Puma
- **Bookshop 3.3** component library, rendered via custom Liquid tags
- **esbuild** for JS, **sass-embedded** + PostCSS for SCSS
- **CloudCannon** for editorial workflow (`cloudcannon.config.yml`)

## Prerequisites

- Ruby `>= 3.1`
- Node `>= 20`
- Bundler (`gem install bundler`)

## Install

```sh
bundle install
npm install
```

## Development

```sh
npm start
```

Runs Bridgetown (`bundle exec bridgetown serve --port 6061 --unpublished`)
and `bookshop-browser` in parallel via `npm-run-all`. Open
[localhost:6061](http://localhost:6061) for the site and the bookshop
browser URL printed in the console for the component library.

The `--unpublished` flag includes drafts and unpublished posts so editors
can preview content locally.

### Other commands

```sh
# production build → output/
BRIDGETOWN_ENV=production bundle exec bridgetown build

# build only (default env, includes unpublished)
npm run build

# minified JS bundle
npm run esbuild

# JS watcher (rarely needed; npm start handles dev)
npm run esbuild-dev

# Bridgetown CLI
bin/bridgetown start
bin/bridgetown console
bin/bridgetown deploy
```

A `Procfile` / `Procfile.dev` is included for hosts and tools that expect
one (`web: bin/bridgetown start`).

## Project Structure

```
src/
  _layouts/         Page templates
  _includes/        Shared partials (Jekyll-style includes still supported)
  _pages/           Top-level pages (about, pricing, contact, …)
  _posts/           Blog posts
  _staff_members/   Staff collection
  _data/            Site data, including themes.yml
  assets/           SCSS entry points and static assets
  images/, uploads/ Editorial media

component-library/
  components/       Bookshop components (button, pricing-plans, …)
  shared/           Shared SCSS, partials
  bookshop/         Bookshop config

plugins/
  builders/         Custom Bridgetown builders (see below)
  scss_converter.rb sass-embedded + fluidvars equivalent

config/
  initializers.rb   Plugin wiring
  esbuild.defaults.js
  puma.rb
```

## Custom Bridgetown plugins

Ported during the Jekyll → Bridgetown migration to fill gaps Bridgetown
doesn't ship out of the box:

- `plugins/builders/bridgetown_bookshop.rb` — `{% bookshop %}`,
  `{% bookshop_include %}`, and `{% bookshop_scss %}` Liquid tags
  (re-implements `jekyll-bookshop`, since no Bridgetown engine exists)
- `plugins/builders/jekyll_compat.rb` — Jekyll-style `{% include %}`,
  Jekyll-flavored `find` filter, drop shims for `site.<collection>`,
  `page.url`, swapped `post.next` / `post.previous` semantics
- `plugins/builders/archives_and_redirects.rb` — replaces
  `jekyll-archives` and `jekyll-redirect-from`
- `plugins/scss_converter.rb` — sass-embedded converter plus a
  postcss-fluidvars equivalent that synthesizes `--s-N-M` `clamp()` vars

## Styling

SCSS uses BEM naming and CSS variables for theming. Site-wide themes live
in `src/_data/themes.yml`; brand colors and typography variables are
defined in `component-library/shared/`.

### Brand colors

| Name   | Hex       | Use                          |
|--------|-----------|------------------------------|
| Red    | `#cb3727` | Primary brand                |
| Yellow | `#faa21b` | Accent (e.g. the "y" in logo)|

A full palette and logo usage rules are in `CLAUDE.md` and the
`Causey - Brand Standards or Guidelines.pdf` in this repo.

## Deployment

Production builds go to `output/` and are deployed via CloudCannon, which
watches the repo and runs `BRIDGETOWN_ENV=production bundle exec bridgetown build`.

## Contributing

1. Branch from `main` (`git checkout -b my-feature`)
2. `npm start` and verify your changes locally
3. Commit and open a PR

For component changes, also confirm rendering in the Bookshop browser —
CloudCannon editors rely on it for previews.
