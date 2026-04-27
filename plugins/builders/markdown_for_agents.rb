require "reverse_markdown"
require "nokogiri"
require "fileutils"

# Pre-generates a `.md` twin for every `.html` page in the build output, so
# Cloudflare can URL-rewrite `Accept: text/markdown` requests to the markdown
# version. Pairs with a Cloudflare Transform Rule on the edge.
class Builders::MarkdownForAgents < SiteBuilder
  SKIP_PATHS = ["/_bridgetown/"].freeze

  def build
    hook :site, :post_write do
      generate_twins
    end
  end

  private

  def generate_twins
    dest = site.config["destination"]
    posts_by_url = blog_post_sources_by_url

    count = 0
    Dir.glob(File.join(dest, "**", "*.html")).each do |html_path|
      relative = html_path.sub("#{dest}/", "/")
      next if SKIP_PATHS.any? { |p| relative.include?(p) }

      md = build_markdown_for(html_path, relative, posts_by_url)
      next if md.nil? || md.empty?

      md_path = html_path.sub(/\.html\z/, ".md")
      File.write(md_path, md)
      count += 1
    end

    Bridgetown.logger.info "MarkdownForAgents:", "wrote #{count} .md twin(s)"
  end

  # For blog posts, prefer the original markdown source.
  # For everything else, convert the rendered HTML body to markdown.
  def build_markdown_for(html_path, relative, posts_by_url)
    permalink_dir = File.dirname(relative)
    permalink_dir = "/" if relative.end_with?("/index.html") && permalink_dir != "/"
    url_key = relative.sub(/index\.html\z/, "")

    if (source_md = posts_by_url[url_key])
      strip_frontmatter(File.read(source_md))
    else
      html = File.read(html_path)
      # Skip redirect-stub pages (e.g. from jekyll-redirect-from / archives_and_redirects).
      return nil if html.include?('http-equiv="refresh"')
      doc = Nokogiri::HTML(html)
      doc.css("nav, footer, script, style, noscript, link, header").remove
      main = doc.at_css("main") || doc.at_css("article") || doc.at_css("body")
      return nil unless main
      ReverseMarkdown.convert(main.inner_html, unknown_tags: :bypass, github_flavored: true).strip + "\n"
    end
  end

  def blog_post_sources_by_url
    site.collections.posts.resources.each_with_object({}) do |resource, hash|
      next unless resource.relative_url && resource.path
      hash[resource.relative_url] = resource.path.to_s
    end
  rescue StandardError => e
    Bridgetown.logger.warn "MarkdownForAgents:", "could not enumerate post sources: #{e.message}"
    {}
  end

  def strip_frontmatter(content)
    return content unless content.start_with?("---")
    parts = content.split(/^---\s*$/, 3)
    return content if parts.length < 3
    parts[2].lstrip
  end
end
