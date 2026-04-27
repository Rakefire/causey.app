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
