require "minitest_helper"
require "json"
require "yaml"
require "digest"

# Build artifacts beyond the HTML pages: scheduled posts, redirects, archives,
# feed, sitemap, robots, social/structured data, and agent discovery files.
class TestBuild < Bridgetown::Test
  OUTPUT = File.expand_path("../output", __dir__)
  POSTS = File.expand_path("../src/_posts", __dir__)
  LIVE = "https://www.causey.app"

  HTML = Dir[File.join(OUTPUT, "**/*.html")].to_h { [_1, Nokolexbor::HTML(File.read(_1))] }
  STUBS, PAGES = HTML.partition { |_, doc| doc.at_css('meta[http-equiv="refresh"]') }.map(&:to_h)

  # [slug, publish time] for every post source.
  SOURCES = Dir[File.join(POSTS, "*.md")].filter_map do |file|
    slug = File.basename(file)[/\A\d{4}-\d\d-\d\d-(.+)\.md\z/, 1] or next
    slug = Bridgetown::Utils.slugify(slug) # matches slugify_mode "default" (drops emoji)
    [slug, Time.parse(YAML.safe_load_file(file, permitted_classes: [Date, Time], aliases: true)["date"].to_s)]
  end

  def built?(url)
    path = URI::RFC2396_PARSER.unescape(url.delete_prefix(LIVE))
    File.file?(File.join(OUTPUT, path)) || File.file?(File.join(OUTPUT, path, "index.html"))
  end

  def assert_none(failures) = assert_empty failures, failures.first(20).join("\n")

  describe "scheduled posts" do
    it "builds every post whose date has passed" do
      assert_none(SOURCES.filter_map { |slug, at| "unpublished: #{slug}" if at <= Time.now && !built?("/#{slug}/") })
    end

    it "holds back posts dated in the future" do
      assert_none(SOURCES.filter_map { |slug, at| "published early: #{slug}" if at > Time.now && built?("/#{slug}/") })
    end
  end

  describe "redirects" do
    it "points every on-site redirect stub at a page or file that exists" do
      assert_none(STUBS.filter_map do |file, doc|
        target = doc.at_css('meta[http-equiv="refresh"]')["content"][/url=(.+)\z/, 1]
        next unless target.start_with?(LIVE, "/") # off-site targets (Google Docs, the app) aren't ours to check
        "#{file.delete_prefix(OUTPUT)} -> #{target}" unless built?(target)
      end)
    end

    it "keeps redirect stubs out of search" do
      assert_none(STUBS.filter_map { |file, doc| file.delete_prefix(OUTPUT) unless doc.at_css('meta[name="robots"][content*="noindex"]') })
    end
  end

  describe "category archives" do
    it "lists at least one post on each category page" do
      pages = Dir[File.join(OUTPUT, "category/*/index.html")]
      expect(pages).wont_be_empty
      assert_none(pages.filter_map { |f| f.delete_prefix(OUTPUT) if HTML[f].css(".n-post-preview__title").empty? })
    end
  end

  describe "every page" do
    it "declares a language and a viewport" do
      assert_none(PAGES.filter_map do |file, doc|
        file.delete_prefix(OUTPUT) unless doc.at_css("html[lang]") && doc.at_css('meta[name="viewport"]')
      end)
    end

    it "has no unrendered Liquid" do
      assert_none(PAGES.filter_map { |file, doc| file.delete_prefix(OUTPUT) if doc.at_css("body")&.text.to_s.match?(/\{\{|\{%|Liquid (syntax )?error/) })
    end

    it "has Open Graph and Twitter tags with an og:url matching the canonical" do
      assert_none(PAGES.filter_map do |file, doc|
        next if doc.at_css('meta[name="robots"][content*="noindex"]')

        missing = %w[og:title og:description og:image og:url].reject { doc.at_css(%(meta[property="#{_1}"]))&.[]("content").to_s.strip.then { |v| !v.empty? } }
        missing << "twitter:card" unless doc.at_css('meta[name="twitter:card"]')
        og_url = doc.at_css('meta[property="og:url"]')&.[]("content")
        missing << "og:url != canonical" if og_url && !doc.at_css('link[rel="canonical"]')&.[]("href").to_s.start_with?(og_url)
        "#{file.delete_prefix(OUTPUT)}: #{missing.join(", ")}" if missing.any?
      end)
    end

    it "shares an og:image that exists in the build" do
      images = PAGES.values.filter_map { _1.at_css('meta[property="og:image"]')&.[]("content") }.uniq
      assert_none(images.reject { _1.start_with?(LIVE) && File.file?(File.join(OUTPUT, _1.delete_prefix(LIVE).split("?").first)) })
    end

    it "has structured data that parses as JSON" do
      assert_none(PAGES.flat_map do |file, doc|
        doc.css('script[type="application/ld+json"]').filter_map do
          JSON.parse(_1.text) && nil
        rescue JSON::ParserError => e
          "#{file.delete_prefix(OUTPUT)}: #{e.message[0, 80]}"
        end
      end)
    end

    it "links a markdown twin that exists" do
      assert_none(PAGES.filter_map do |file, doc|
        href = doc.at_css('link[rel="alternate"][type="text/markdown"]')&.[]("href") or next
        "#{file.delete_prefix(OUTPUT)}: #{href}" unless File.file?(File.join(OUTPUT, href))
      end)
    end

    it "advertises the feed for readers" do
      expect(HTML[File.join(OUTPUT, "index.html")].at_css('link[rel="alternate"][type="application/atom+xml"]')).wont_be_nil
    end
  end

  describe "posts" do
    it "marks up each post as a BlogPosting with a date" do
      SOURCES.select { |_, at| at <= Time.now }.first(5).each do |slug, _|
        get "/#{slug}/"
        html last_response
        doc = document
        types = doc.css('script[type="application/ld+json"]').map { JSON.parse(_1.text)["@type"] }
        expect(types).must_include "BlogPosting"
        expect(doc.at_css('meta[property="og:type"]')["content"]) == "article"
        expect(doc.at_css("time[datetime]")).wont_be_nil
      end
    end
  end

  describe "feed" do
    it "is valid Atom listing the newest published post" do
      feed = Nokolexbor::HTML(File.read(File.join(OUTPUT, "feed.xml")))
      links = feed.css("entry link[rel=alternate]").map { _1["href"] }
      expect(links).wont_be_empty
      newest = SOURCES.select { |_, at| at <= Time.now }.max_by(&:last).first
      expect(links).must_include "#{LIVE}/#{newest}/"
      assert_none(links.reject { built?(_1) })
    end
  end

  describe "sitemap" do
    it "lists only built, indexable pages" do
      locs = File.read(File.join(OUTPUT, "sitemap.xml")).scan(%r{<loc>([^<]+)</loc>}).flatten
      expect(locs.size).must_be :>, 50
      assert_none(locs.reject { built?(_1) })
      stubs = STUBS.keys.map { "#{LIVE}#{_1.delete_prefix(OUTPUT).delete_suffix("index.html")}" }
      assert_none(locs & stubs)
    end
  end

  describe "crawler files" do
    it "lets robots crawl and points them at the sitemap" do
      get "/robots.txt"
      expect(last_response.body).must_include "Sitemap: #{LIVE}/sitemap.xml"
      expect(last_response.body).wont_match %r{^Disallow: /\s*$}
    end

    it "serves llms.txt" do
      get "/llms.txt"
      expect(last_response.status) == 200
      expect(last_response.body).must_match(/\A# Causey/)
    end

    it "publishes agent skills whose files exist and match their digests" do
      index = JSON.parse(File.read(File.join(OUTPUT, ".well-known/agent-skills/index.json")))
      expect(index["skills"].size) == YAML.load_file(File.expand_path("../src/_data/agent_skills.yml", __dir__))["skills"].size
      index["skills"].each do |skill|
        body = File.read(File.join(OUTPUT, skill["url"]))
        expect(skill["digest"]) == "sha256:#{Digest::SHA256.hexdigest(body)}"
      end
    end

    it "publishes an api-catalog linking to the agent skills" do
      catalog = JSON.parse(File.read(File.join(OUTPUT, ".well-known/api-catalog")))
      hrefs = catalog["linkset"].flat_map { _1.values.grep(Array).flatten.map { |l| l["href"] } }
      expect(hrefs).must_include "#{LIVE}/.well-known/agent-skills/index.json"
    end
  end

  describe "forms" do
    it "posts the contact form over HTTPS" do
      get "/contact/"
      html last_response
      form = document.at_css("form.c-contact-form__form")
      expect(form["action"]).must_match %r{\Ahttps://}
      expect(form["method"]) == "post"
    end
  end
end
