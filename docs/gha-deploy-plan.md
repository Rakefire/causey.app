# causey.app — GHA deploy alignment plan

**Repo:** `~/github/www-causey-app`
**Goals:**
1. Bump Ruby `3.4.4` → `4.0.3`
2. Bump `actions/upload-pages-artifact` to `@v5`
3. **Remove** unused esbuild scaffolding (verified not consumed by any layout/template — confirmed in audit)
4. Switch workflow build command from `bundle exec bridgetown build` to `bundle exec rake deploy` (consistency)
5. Port IndexNow + HTML minifier builders from Stoked
6. Update `docs/gha-deploy-flow.md`

Daily cron is already in place (`0 6 * * *`). No frontend changes needed beyond removal — the site's CSS comes from `src/assets/main.scss` via Bridgetown's `plugins/scss_converter.rb` (sass-embedded), and JS is either static files in `src/assets/js/` or build-time-rendered ERB (`src/_pages/webmcp.erb` → `/javascript/webmcp.js`). None of the `frontend/` directory output is referenced.

## Site facts

- **Site URL:** `https://www.causey.app` (from `config/initializers.rb`)
- **IndexNow key (generated):** `2df97b9b-a29d-43a6-9963-4f9f5121c603`

## Pre-flight — re-verify esbuild is unused

Before deleting anything, confirm:

```bash
cd ~/github/www-causey-app

# Anything reference esbuild output paths?
grep -rE "asset_path|/_bridgetown/static|frontend\.(js|css)" src/ component-library/ 2>/dev/null
# expect: no matches

# Where is webmcp.js actually defined?
find src -name "*webmcp*"
# expect: src/_pages/webmcp.erb (ERB-generated, permalink /javascript/webmcp.js)
#         src/_data/webmcp.yml

# Confirm main.css comes from src/assets/main.scss
cat src/_includes/head.html | grep -E "main\.css|webmcp\.js"
ls src/assets/main.scss
```

If any of these surface unexpected esbuild references, **stop and reassess** before continuing.

## Change 1 — Workflow updates

**File:** `.github/workflows/pages.yml`

```diff
       - uses: ruby/setup-ruby@v1
         with:
-          ruby-version: "3.4.4"
+          ruby-version: "4.0.3"
           bundler-cache: true
```

```diff
-      - name: Build with Bridgetown
-        run: bundle exec bridgetown build
+      - name: Build site
+        run: bundle exec rake deploy
         env:
           BRIDGETOWN_ENV: production
```

```diff
       - name: Upload artifact
-        uses: actions/upload-pages-artifact@v3
+        uses: actions/upload-pages-artifact@v5
         with:
           path: output
```

(No Node setup needed — frontend scaffolding is being removed.)

## Change 2 — Remove esbuild scaffolding

**Delete these files/directories:**

```bash
cd ~/github/www-causey-app
rm -rf frontend/
rm esbuild.config.js
rm config/esbuild.defaults.js
rm postcss.config.js
```

(Verify `postcss.config.js` is only used by esbuild — it should be. The Bridgetown sass converter at `plugins/scss_converter.rb` does its own postcss-fluidvars equivalent in Ruby and does not load `postcss.config.js`. Confirm with `grep -r postcss plugins/` if uncertain.)

## Change 3 — Clean up package.json

**File:** `package.json`

The current scripts include `esbuild` and `esbuild-dev` which are now dead. Replace the file with:

```json
{
  "name": "causey-website",
  "version": "1.0.0",
  "type": "module",
  "private": true,
  "description": "Bridgetown + Bookshop site for causey.app",
  "license": "MIT",
  "scripts": {
    "bookshop": "bookshop-browser",
    "bridgetown": "bundle exec bridgetown serve --port 6061 --unpublished",
    "build": "bundle exec bridgetown build --unpublished",
    "start": "run-p bookshop bridgetown"
  },
  "devDependencies": {
    "@bookshop/browser": "3.3.0",
    "@bookshop/generate": "3.3.0",
    "@bookshop/live": "3.3.0",
    "npm-run-all": "^4.1.5"
  }
}
```

Removed deps: `esbuild`, `glob`, `postcss`, `postcss-flexbugs-fixes`, `postcss-import`, `postcss-load-config`, `postcss-preset-env`, `read-cache`, `sass`, `sass-loader`.

(Keep Bookshop deps + npm-run-all — these are used by the Bookshop dev workflow, which remains unchanged.)

Then:

```bash
rm package-lock.json
npm install
```

Commit the new `package-lock.json`.

## Change 4 — Rakefile: drop frontend:build

**File:** `Rakefile`

The current `:deploy` task chains through `frontend:build` which calls `npm run esbuild`. With esbuild removed, that script no longer exists. Update to:

```ruby
require "bridgetown"

Bridgetown.load_tasks

task default: :deploy

desc "Build the Bridgetown site for deployment"
task :deploy => [:clean] do
  Bridgetown::Commands::Build.start
end

desc "Build the site in a test environment"
task :test do
  ENV["BRIDGETOWN_ENV"] = "test"
  Bridgetown::Commands::Build.start
end

desc "Runs the clean command"
task :clean do
  Bridgetown::Commands::Clean.start
end
```

(Removed the entire `namespace :frontend` block.)

## Change 5 — Add htmlcompressor gem

**File:** `Gemfile`

Add after the existing `bridgetown` gem line:

```ruby
gem "htmlcompressor", "~> 0.4"
```

Then `bundle install`. Commit `Gemfile.lock`.

## Change 6 — Create IndexNow key file

**File:** `src/2df97b9b-a29d-43a6-9963-4f9f5121c603.txt`

Contents:

```
2df97b9b-a29d-43a6-9963-4f9f5121c603
```

## Change 7 — IndexNow builder

**File:** `plugins/builders/indexnow.rb` (new)

```ruby
require "net/http"
require "json"
require "uri"
require "rexml/document"

class Builders::Indexnow < SiteBuilder
  INDEXNOW_KEY = "2df97b9b-a29d-43a6-9963-4f9f5121c603"
  INDEXNOW_API = "https://api.indexnow.org/indexnow"
  SITE_HOST = "https://www.causey.app"

  def build
    hook :site, :post_write do
      next unless should_run?

      urls = collect_urls_from_sitemap

      if urls.empty?
        Bridgetown.logger.info "IndexNow:", "No URLs to submit"
        next
      end

      submit_urls(urls)
    end
  end

  private

  def should_run?
    return true if ENV["INDEXNOW"] == "true"
    return true if Bridgetown.environment == "production"

    false
  end

  def collect_urls_from_sitemap
    sitemap_path = site.in_dest_dir("sitemap.xml")
    unless File.exist?(sitemap_path)
      Bridgetown.logger.warn "IndexNow:", "sitemap.xml not found at #{sitemap_path}"
      return []
    end

    doc = REXML::Document.new(File.read(sitemap_path))
    doc.elements.collect("urlset/url/loc") { |el| el.text }
  end

  def submit_urls(urls)
    Bridgetown.logger.info "IndexNow:", "Submitting #{urls.size} URL(s) to IndexNow"
    urls.each { |url| Bridgetown.logger.info "IndexNow:", "  → #{url}" }

    body = {
      host: URI(SITE_HOST).host,
      key: INDEXNOW_KEY,
      keyLocation: "#{SITE_HOST}/#{INDEXNOW_KEY}.txt",
      urlList: urls
    }

    uri = URI(INDEXNOW_API)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json; charset=utf-8"
    request.body = JSON.generate(body)

    response = http.request(request)

    case response.code.to_i
    when 200, 202
      Bridgetown.logger.info "IndexNow:", "Successfully submitted (HTTP #{response.code})"
    else
      Bridgetown.logger.warn "IndexNow:", "API returned HTTP #{response.code}: #{response.body}"
    end
  rescue => e
    Bridgetown.logger.error "IndexNow:", "Submission failed: #{e.class} - #{e.message}"
  end
end
```

`bridgetown-sitemap` is already enabled in `config/initializers.rb` — generates `output/sitemap.xml`.

## Change 8 — HTML minifier builder

**File:** `plugins/builders/html_minifier.rb` (new)

```ruby
require "htmlcompressor"

class Builders::HTMLMinifier < SiteBuilder
  def build
    hook :site, :post_write do
      next if config[:watch]

      Bridgetown.logger.info "HTML Minifier:", "Compressing HTML files..."

      compressor = HtmlCompressor::Compressor.new(
        remove_comments: true,
        remove_multi_spaces: true,
        remove_intertag_spaces: false,
        preserve_line_breaks: false
      )

      html_files = Dir.glob(File.join(site.dest, "**", "*.html"))
      html_files.each do |file|
        content = File.read(file)
        compressed = compressor.compress(content)
        File.write(file, compressed)
      end

      Bridgetown.logger.info "HTML Minifier:", "Compressed #{html_files.size} HTML files"
    end
  end
end
```

## Change 9 — Update docs/gha-deploy-flow.md

The current deck flagged the esbuild-not-running issue. Now the resolution is explicit: esbuild was unused, scaffolding removed. Update slides:

- Environment setup: Ruby `3.4.4` → `4.0.3`
- Build step: `bundle exec bridgetown build` → `bundle exec rake deploy`
- **Remove the "⚠️ esbuild does not run in CI" slide** — replace with a single line in caching summary noting esbuild scaffolding was removed
- Add slides for `indexnow` and `html_minifier` builders (mirror Stoked deck structure)
- "Files / paths to know" slide: remove `frontend/`, `esbuild.config.js`, `postcss.config.js`; add the new builders + key file

## Verify

```bash
cd ~/github/www-causey-app

# Confirm scaffolding gone
ls frontend/ esbuild.config.js postcss.config.js config/esbuild.defaults.js 2>&1
# expect: all "No such file or directory"

# Build still works
bundle exec rake deploy
# expect: clean → bridgetown build → HTML Minifier compresses N files

# Site CSS still produced (via plugins/scss_converter.rb)
ls output/assets/main.css
# expect: file exists, non-empty

# webmcp.js still produced (ERB-rendered)
ls output/javascript/webmcp.js
# expect: file exists, non-empty

# IndexNow dry run
INDEXNOW=true bundle exec rake deploy
# expect: "Submitting N URL(s)" + "Successfully submitted"
```

## Commit

```bash
git add .github/workflows/pages.yml \
        Rakefile \
        Gemfile Gemfile.lock \
        package.json package-lock.json \
        plugins/builders/ \
        src/2df97b9b-a29d-43a6-9963-4f9f5121c603.txt \
        docs/gha-deploy-flow.md
git rm -r frontend/
git rm esbuild.config.js config/esbuild.defaults.js postcss.config.js
git commit -m "Align CI with sister sites: Ruby 4.0.3, remove unused esbuild, add IndexNow + HTML minifier"
```

## Out of scope (do not do)

- Do not change `template_engine "liquid"` to ERB. The migrated Jekyll templates rely on Liquid.
- Do not touch `plugins/scss_converter.rb` — that's the actual SCSS compilation path and must stay.
- Do not remove the bookshop dev scripts from `package.json` — the visual editor uses them.
