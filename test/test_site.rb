require "minitest_helper"

# Site-wide SEO and integrity checks across every built HTML page.
class TestSite < Bridgetown::Test
  OUTPUT = File.expand_path("../output", __dir__)
  LIVE = "https://www.causey.app"

  # Indexable pages: skip redirect stubs and noindex pages.
  PAGES = Dir[File.join(OUTPUT, "**/*.html")].filter_map do |file|
    doc = Nokolexbor::HTML(File.read(file))
    next if doc.at_css('meta[http-equiv="refresh"]')
    next if doc.at_css('meta[name="robots"]')&.[]("content").to_s.include?("noindex")

    ["/#{file.delete_prefix("#{OUTPUT}/").delete_suffix("index.html")}", doc]
  end.to_h

  def self.local_file?(href)
    path = URI::RFC2396_PARSER.unescape(href.split(/[?#]/).first.to_s)
    return true if path.empty? || path == "/"

    base = File.join(OUTPUT, path)
    File.file?(base) || File.file?(File.join(base, "index.html")) || File.file?("#{base}.html")
  end

  def failures_for
    PAGES.flat_map { |url, doc| Array(yield(doc)).map { "#{url}: #{_1}" } }
  end

  def assert_none(failures) = assert_empty failures, failures.first(20).join("\n")

  it "finds the pages" do
    expect(PAGES.size).must_be :>, 50
  end

  it "gives every page a title of at most 70 characters" do
    assert_none(failures_for do |doc|
      title = doc.at_css("title")&.text.to_s.strip
      if title.empty? then "missing <title>"
      elsif title.length > 70 then "title is #{title.length} chars: #{title}"
      end
    end)
  end

  it "gives every page a meta description" do
    assert_none(failures_for { |doc| "missing description" if doc.at_css('meta[name="description"]')&.[]("content").to_s.strip.empty? })
  end

  it "keeps titles and descriptions unique" do
    %w[title meta[name="description"]].each do |sel|
      values = PAGES.transform_values { |doc| (el = doc.at_css(sel)) && (el["content"] || el.text).strip }
      dupes = values.group_by { _2 }.select { |_, v| v.size > 1 }.map { |val, pairs| "#{pairs.map(&:first).join(", ")} share #{val}" }
      assert_none dupes
    end
  end

  it "has an absolute canonical URL on every page" do
    assert_none(failures_for { |doc| "bad canonical" unless doc.at_css('link[rel="canonical"]')&.[]("href").to_s.start_with?(LIVE) })
  end

  it "has exactly one h1 per page" do
    assert_none(failures_for { |doc| (n = doc.css("h1").size) == 1 ? nil : "#{n} h1 elements" })
  end

  it "gives every image alt text, real dimensions, and a file that exists" do
    assert_none(failures_for do |doc|
      doc.css("img").filter_map do |img|
        src = img["src"].to_s
        next "img without alt: #{src}" unless img.key?("alt")
        next unless src.start_with?("/") && !src.start_with?("//")
        next "missing image file: #{src}" unless self.class.local_file?(src)
        "no width/height: #{src}" if src.match?(/\.(png|jpe?g|gif|webp)\z/i) && !(img["width"] && img["height"])
      end
    end)
  end

  it "has no broken internal links" do
    assert_none(failures_for do |doc|
      doc.css("a[href]").map { _1["href"] }.uniq.filter_map do |href|
        "broken link: #{href}" if href.start_with?("/") && !href.start_with?("//") && !self.class.local_file?(href)
      end
    end)
  end

  it "self-hosts fonts and preloads files that exist" do
    assert_none(failures_for do |doc|
      bad = doc.css('link[href*="fonts.googleapis"], link[href*="fonts.gstatic"]').map { "external font: #{_1["href"]}" }
      bad + doc.css('link[rel="preload"]').filter_map { "missing preload: #{_1["href"]}" unless self.class.local_file?(_1["href"]) }
    end)
  end

  it "publishes a sitemap and feed, without noindex pages" do
    sitemap = File.read(File.join(OUTPUT, "sitemap.xml"))
    expect(sitemap).must_include "#{LIVE}/pricing/"
    expect(sitemap).wont_include "startupranking"
    expect(File.file?(File.join(OUTPUT, "feed.xml"))).must_equal true
  end
end
