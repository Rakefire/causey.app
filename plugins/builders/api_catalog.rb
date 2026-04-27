require "fileutils"
require "json"

# Generates /.well-known/api-catalog (RFC 9727 linkset+json).
# Data-driven: reads src/_data/api_catalog.yml if present (with a "linkset" key),
# otherwise emits a default linkset pointing at the site's agent-skills index.
class Builders::APICatalog < SiteBuilder
  DEST_PATH = ".well-known/api-catalog".freeze

  def build
    hook :site, :post_write do
      generate
    end
  end

  private

  def generate
    catalog = { "linkset" => linkset }

    dest = File.join(site.config["destination"], DEST_PATH)
    FileUtils.mkdir_p(File.dirname(dest))
    File.write(dest, JSON.pretty_generate(catalog) + "\n")

    Bridgetown.logger.info "ApiCatalog:", "wrote #{DEST_PATH} (#{linkset.size} anchor(s))"
  end

  def linkset
    custom = site.data.dig("api_catalog", "linkset")
    return custom if custom.is_a?(Array) && !custom.empty?

    base = site.config["url"].to_s.chomp("/")
    [
      {
        "anchor" => "#{base}/",
        "service-doc" => [
          { "href" => "#{base}/.well-known/agent-skills/index.json", "type" => "application/json" }
        ]
      }
    ]
  end
end
