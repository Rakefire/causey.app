require "minitest_helper"

# Key pages, requested through Bridgetown's Roda server like a browser would.
class TestPages < Bridgetown::Test
  def page(path)
    get path
    expect(last_response.status) == 200
    html last_response
  end

  describe "core pages" do
    %w[/ /pricing/ /about/ /contact/ /blog/ /sbdc/ /cohorts/ /terms/ /privacy/].each do |path|
      it "serves #{path} with one h1" do
        page path
        expect(document.css("h1").size) == 1
      end
    end
  end

  describe "homepage" do
    it "shows the real Overview screenshot first, at high priority" do
      page "/"
      img = document.at_css(".c-plan-hero__shot img")
      expect(img["src"]).must_match %r{\A/uploads/causey-overview\.webp\?v=}
      expect(img["fetchpriority"]) == "high"
      expect(img["alt"].to_s).wont_be_empty
    end

    it "links to the free trial" do
      page "/"
      expect(document.css('a[href="https://my.causey.app/sign_ups/new"]')).wont_be_empty
    end
  end

  describe "blog" do
    it "shows 10 posts and links to the next page for infinite scroll" do
      page "/blog/"
      expect(document.css(".n-post-preview__title").size) == 10
      expect(document.at_css("[data-posts-more]")["href"]) == "/blog/page/2/"
    end

    it "ends pagination on the last page" do
      last = Dir[File.expand_path("../output/blog/page/*", __dir__)].map { File.basename(_1).to_i }.max
      page "/blog/page/#{last}/"
      expect(document.css(".n-post-preview__title")).wont_be_empty
      expect(document.at_css("[data-posts-more]")).must_be_nil
    end
  end

  describe "pricing" do
    it "has a native monthly/yearly switch and both sets of prices" do
      page "/pricing/"
      expect(document.at_css('input.c-pricing-plans__switch[role="switch"]')).wont_be_nil
      expect(document.css('[data-period="month"]')).wont_be_empty
      expect(document.css('[data-period="year"]')).wont_be_empty
    end
  end

  describe "about" do
    it "lists consulting partners with logos" do
      page "/about/"
      logos = document.css(".c-columns__logo")
      expect(logos.size).must_be :>=, 7
      logos.each { expect(_1["alt"].to_s).wont_be_empty }
    end
  end

  describe "asset versions" do
    it "fingerprints CSS, JS, fonts and images so they can be cached for a year" do
      page "/"
      refs = document.css("link[rel=stylesheet], link[rel=preload], script[src], img[src]")
        .map { _1["href"] || _1["src"] }.select { _1.start_with?("/") }
      expect(refs).wont_be_empty
      refs.each { expect(_1).must_match(/\?v=\h{10}\z/) }
      css = File.read(File.expand_path("../output/assets/main.css", __dir__))
      expect(css.scan(%r{url\(/fonts/[^)]+\)}).all? { _1.include?("?v=") }).must_equal true
    end
  end
end
