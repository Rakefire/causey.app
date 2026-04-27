# Bridgetown configuration for the Causey site.
# Translated from site/_config.yml during the Jekyll → Bridgetown migration.

Bridgetown.configure do |config|
  url "https://www.causey.app"
  template_engine "liquid"
  permalink "/:slug/"

  # Match Jekyll's slugify mode so post titles produce the same paths.
  # Bridgetown defaults to "pretty" (keeps commas, apostrophes); Jekyll
  # defaulted to "default" which strips most punctuation.
  slugify_mode "default"

  # The component-library Bookshop directory is read by our custom plugin.
  # Paths are resolved relative to the source directory (src/), so go up two
  # levels to reach the repo root, then into component-library.
  config.bookshop_locations = ["../../component-library"]

  # Keep Jekyll's exclude semantics
  config.exclude = (config.exclude || []) + ["postcss.config.js", "node_modules"]

  # Plugin equivalents for jekyll-feed, jekyll-sitemap. Archives, redirects,
  # and bookshop are implemented in plugins/builders/.
  init :"bridgetown-feed"
  init :"bridgetown-sitemap"

  # Custom collections matching site/_config.yml. Posts inherits the
  # top-level permalink template, but we set it explicitly for safety.
  collections do
    posts do
      output true
      permalink "/:slug/"
    end
    pages do
      output true
      permalink "/:slug/"
    end
    staff_members do
      output false
    end
    clients do
      output true
    end
  end

  # Defaults translated from site/_config.yml. Bridgetown supports the same
  # `defaults` array shape as Jekyll. The `path: ""` scope applies sitewide.
  defaults [
    {
      "scope" => { "path" => "" },
      "values" => { "layout" => "default" },
    },
    {
      "scope" => { "path" => "_pages/index.html" },
      "values" => { "permalink" => "/" },
    },
    {
      "scope" => { "type" => "posts" },
      "values" => {
        "layout" => "post",
        "dont_render_bookshop_components" => true,
      },
    },
    {
      "scope" => { "type" => "clients" },
      "values" => { "layout" => "client" },
    },
  ]
end
