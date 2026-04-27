# frozen_string_literal: true

# ArchivesAndRedirects — replaces Jekyll's `jekyll-archives` and
# `jekyll-redirect-from` plugins for the migration to Bridgetown.
#
# Archives:
#   For each unique post category, generate a page at `/category/<slug>/`
#   that uses the `archive` layout. Title = the (lowercase) category name.
#   Mirrors the `jekyll-archives.enabled: [categories]` config from the
#   Jekyll-era _config.yml.
#
# Redirects:
#   - `redirect_to: <url>` on a page → the page itself becomes a redirect stub.
#     Bridgetown's `redirect_to` isn't natively supported, so this builder
#     rewrites the rendered output of any resource carrying that key.
#   - `redirect_from: [<urls>]` on any resource → generate redirect stub
#     pages at each listed URL pointing to the resource's actual URL.
#
# Stub HTML matches jekyll-redirect-from's "default" template byte-for-byte
# (apart from base URL substitution) so the verification harness's redirect
# target check accepts them as equivalent.

module Builders
  class ArchivesAndRedirects < SiteBuilder
    def build
      hook :site, :post_read do |site|
        generate_archives(site)
        generate_redirects(site)
      end

      # `redirect_to` resources need their content replaced with the stub at
      # render time so they're treated as proper resources during the build
      # (so layouts, permalinks, etc. all still apply).
      hook :resources, :post_render do |resource|
        target = resource.data["redirect_to"]
        next unless target.is_a?(String) && !target.empty?
        resource.output = redirect_html(target)
      end
    end

    private

    def generate_archives(site)
      posts = site.collections["posts"]&.resources || []
      categories = posts.flat_map do |post|
        Array(post.data["categories"])
      end.compact.map(&:to_s).reject(&:empty?).uniq

      categories.each do |category|
        slug = Bridgetown::Utils.slugify(category, mode: site.config.slugify_mode)
        next if slug.empty?
        next if site.generated_pages.any? { |p| p.url == "/category/#{slug}/" }

        page = build_archive_page(site, category, slug)
        site.generated_pages << page
      end
    end

    def build_archive_page(site, category, slug)
      Bridgetown::GeneratedPage.new(site, site.source, "", "category/#{slug}.html").tap do |p|
        p.data["layout"] = "archive"
        # Preserve the original category name as the page title — jekyll-archives
        # passes it through verbatim to `page.title`, so casing matters for the
        # `<title>` tag and any SEO/meta usage in head.html.
        p.data["title"] = category
        p.data["permalink"] = "/category/#{slug}/"
        # Match Jekyll-era behavior: archives don't render the page-level
        # bookshop component (only the archive layout content).
        p.data["dont_render_bookshop_components"] = true
        p.content = ""
      end
    end

    def generate_redirects(site)
      sources = site.collections.values.flat_map(&:resources)
      sources.each do |resource|
        froms = Array(resource.data["redirect_from"]).compact.reject { |u| u.to_s.empty? }
        next if froms.empty?

        target = resource_url(site, resource)
        next unless target

        froms.each do |from|
          path = stub_path_from_url(from)
          next if path.nil?
          next if site.generated_pages.any? { |p| p.url == path[:url] }

          page = build_redirect_stub(site, path, target)
          site.generated_pages << page
        end
      end
    end

    def build_redirect_stub(site, path, target)
      Bridgetown::GeneratedPage.new(site, site.source, "", path[:relative_path]).tap do |p|
        p.data["layout"] = "none"
        p.data["sitemap"] = false
        p.data["permalink"] = path[:url]
        p.content = redirect_html(target)
      end
    end

    # Convert a redirect_from URL into a destination relative_path + url.
    # Mirrors jekyll-redirect-from's emission rules:
    #   "/foo/"     → /foo/             written as foo/index.html
    #   "/foo"      → /foo.html         written as foo.html  (Jekyll appends
    #                                   the default .html extension when the
    #                                   path has no trailing slash and no ext)
    #   "/foo.html" → /foo.html         written as foo.html
    def stub_path_from_url(url)
      u = url.to_s.strip
      u = "/#{u}" unless u.start_with?("/")
      if u.end_with?("/")
        return { url: u, relative_path: "#{u[1..]}index.html" }
      end
      if u.end_with?(".html") || u.end_with?(".htm")
        return { url: u, relative_path: u[1..].to_s }
      end
      # No trailing slash, no extension — Jekyll writes the stub at <url>.html
      out_url = "#{u}.html"
      { url: out_url, relative_path: out_url[1..].to_s }
    end

    def resource_url(site, resource)
      url = resource.respond_to?(:relative_url) ? resource.relative_url : nil
      return nil if url.nil? || url.empty?
      site_url = site.config.url.to_s
      site_url.empty? ? url : "#{site_url}#{url}"
    end

    # Mirrors jekyll-redirect-from's default template.
    def redirect_html(target)
      <<~HTML
        <!DOCTYPE html>
        <html lang="en-US">
          <meta charset="utf-8">
          <title>Redirecting&hellip;</title>
          <link rel="canonical" href="#{target}">
          <script>location="#{target}"</script>
          <meta http-equiv="refresh" content="0; url=#{target}">
          <meta name="robots" content="noindex">
          <h1>Redirecting&hellip;</h1>
          <a href="#{target}">Click here if you are not redirected.</a>
        </html>
      HTML
    end
  end
end
