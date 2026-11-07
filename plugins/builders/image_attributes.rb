require "uri"

# Gives every local raster <img> its real width/height (so the page doesn't
# jump as images load) and lazy loading. Tags that already set width/height
# or loading keep them; mark above-the-fold images loading="eager".
class Builders::ImageAttributes < SiteBuilder
  def build
    hook :site, :post_write do
      sizes = {}
      Dir.glob(File.join(site.dest, "**", "*.html")).each do |file|
        html = File.read(file)
        out = html.gsub(/<img\b[^>]*>/) do |tag|
          src = tag[/\ssrc="(\/[^"?#]+\.(?:png|jpe?g|gif|webp))(?:\?[^"]*)?"/i, 1]
          next tag unless src

          path = File.join(site.dest, URI::RFC2396_PARSER.unescape(src))
          size = sizes.fetch(path) { sizes[path] = self.class.dimensions(path) }
          extra = +""
          extra << %( width="#{size[0]}" height="#{size[1]}") if size && !tag.match?(/\s(?:width|height)=/)
          extra << ' loading="lazy" decoding="async"' unless tag.include?(" loading=")
          extra.empty? ? tag : tag.sub(/\s*\/?>\z/) { |close| extra + close }
        end
        File.write(file, out) unless out == html
      end
    end
  end

  # [width, height] read from the file header, or nil if unknown.
  def self.dimensions(path)
    return unless File.file?(path)

    File.open(path, "rb") do |f|
      head = f.read(30).to_s
      if head.start_with?("\x89PNG".b)
        head[16, 8].unpack("NN")
      elsif head.start_with?("GIF8")
        head[6, 4].unpack("vv")
      elsif head.start_with?("RIFF") && head[8, 4] == "WEBP"
        webp(head)
      elsif head.start_with?("\xFF\xD8".b)
        jpeg(f)
      end
    end
  end

  def self.webp(head)
    case head[12, 4]
    when "VP8 " then head[26, 4].unpack("vv").map { _1 & 0x3fff }
    when "VP8L"
      bits = head[21, 4].unpack1("V")
      [(bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1]
    when "VP8X"
      w0, w1, w2, h0, h1, h2 = head[24, 6].unpack("C6")
      [(w0 | w1 << 8 | w2 << 16) + 1, (h0 | h1 << 8 | h2 << 16) + 1]
    end
  end

  # Walk JPEG segments to the first start-of-frame marker.
  def self.jpeg(f)
    f.seek(2)
    while (marker = f.read(2)) && marker.bytesize == 2
      type = marker.getbyte(1)
      length = f.read(2).to_s.unpack1("n") or return
      if (0xC0..0xCF).cover?(type) && ![0xC4, 0xC8, 0xCC].include?(type)
        height, width = f.read(5).unpack("xnn")
        return [width, height]
      end
      f.seek(length - 2, IO::SEEK_CUR)
    end
  end
end
