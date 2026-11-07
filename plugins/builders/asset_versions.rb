require "digest"

# Appends ?v=<content hash> to local asset URLs in the built HTML and CSS, so
# Cloudflare can cache them for a year and a changed file gets a new URL.
class Builders::AssetVersions < SiteBuilder
  EXT = "css|js|svg|png|jpe?g|gif|webp|avif|ico|woff2?"
  HTML_REF = /(\s(?:src|href|srcset)=")(\/[^"?#\s,]+\.(?:#{EXT}))(?=")/i
  CSS_REF = /(url\(["']?)(\/[^"')?#\s]+\.(?:#{EXT}))(?=["']?\))/i

  def build
    hook :site, :post_write do
      hashes = {}
      version = ->(path) do
        hashes.fetch(path) do
          file = File.join(site.dest, path)
          hashes[path] = File.file?(file) ? Digest::MD5.file(file).hexdigest[0, 10] : nil
        end
      end

      # CSS first: its font URLs change its hash, which the HTML then references.
      files = Dir.glob(File.join(site.dest, "**", "*.css")) + Dir.glob(File.join(site.dest, "**", "*.html"))
      files.each do |file|
        text = File.read(file)
        out = text.gsub(file.end_with?(".css") ? CSS_REF : HTML_REF) do
          v = version.(Regexp.last_match(2))
          v ? "#{Regexp.last_match(1)}#{Regexp.last_match(2)}?v=#{v}" : Regexp.last_match(0)
        end
        File.write(file, out) unless out == text
      end
    end
  end
end
