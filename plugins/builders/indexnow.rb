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
