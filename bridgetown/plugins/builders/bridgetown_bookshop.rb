# frozen_string_literal: true

# BridgetownBookshop — port of jekyll-bookshop for Bridgetown.
#
# Wrapped in a SiteBuilder so Zeitwerk autoload (plugins/builders) is happy.
# Registration of Liquid tags + the pre_read hook happens in #build, which
# Bridgetown calls once per build cycle.

require "pathname"

module Builders
  class BridgetownBookshop < SiteBuilder
    VERSION = "0.1.0"

    def build
      # SiteBuilder#build runs inside the :pre_read hook itself, so nested
      # `hook :site, :pre_read` registrations would fire one cycle too late.
      # Set up bookshop locations on the site config directly.
      Opener.open_bookshop(site)

      Liquid::Template.register_tag("bookshop", Tag)
      Liquid::Template.register_tag("bookshop_include", IncludeTag)
      Liquid::Template.register_tag("bookshop_scss", StyleTag)
      Liquid::Template.register_tag("bookshop_browser", NoopTag)
      Liquid::Template.register_tag("bookshop_component_browser", NoopTag)
    end

    # Resolve bookshop_locations to absolute paths and register component +
    # shared paths on the site config so tags can find them.
    module Opener
      def self.open_bookshop(site)
        raw = site.config["bookshop_locations"] || []
        base_locations = filter_existing(site.source, raw)
        component_locations = base_locations.map { |b| Pathname.new("#{b}/components/").cleanpath.to_s }
        shared_locations = base_locations.map { |b| Pathname.new("#{b}/shared/jekyll/").cleanpath.to_s }

        site.config["bookshop_base_locations"] = base_locations
        site.config["bookshop_component_locations"] = component_locations
        site.config["bookshop_shared_locations"] = shared_locations

        site.config["sass"] ||= {}
        (site.config["sass"]["load_paths"] ||= []).concat(base_locations)

        # Hook into Bridgetown's file watcher so editing a `.jekyll.html`
        # component (or any file under component-library/) during
        # `bridgetown serve` triggers a rebuild. Mirrors the patched
        # CloudCannon `jekyll-watch` behavior used in the Jekyll setup.
        site.config.additional_watch_paths ||= []
        site.config.additional_watch_paths.concat(base_locations)
        site.config.additional_watch_paths.uniq!
      end

      def self.filter_existing(src, locations)
        locations.map do |loc|
          Pathname.new("#{src}/#{loc}/").cleanpath.to_s
        end.select { |p| Dir.exist?(p) }
      end
    end

    # Parse `key=value` pairs separated by whitespace.
    module AttrParser
      ATTR_RE = /
        (\w[\w\-]*)             # key
        \s*=\s*
        (
          "[^"]*" | '[^']*' |   # quoted string
          [\w\.\-]+             # bare identifier
        )
      /x

      def self.parse(markup)
        attrs = {}
        markup.scan(ATTR_RE) { |k, v| attrs[k] = Liquid::Expression.parse(v) }
        attrs
      end

      def self.evaluate(attrs, context)
        out = {}
        attrs.each { |k, expr| out[k] = context.evaluate(expr) }
        if out.key?("bind") && out["bind"].is_a?(Hash)
          bind = out.delete("bind")
          out = bind.merge(out)
        else
          out.delete("bind")
        end
        out
      end
    end

    # Resolve and parse-cache `.jekyll.html` partials.
    class PartialResolver
      @cache = {}

      def self.cache
        @cache
      end

      def self.find(roots, candidates)
        roots.each do |root|
          candidates.each do |rel|
            full = File.join(root, rel)
            return full if File.exist?(full)
          end
        end
        nil
      end

      def self.render(path, context)
        template = @cache[path] ||= begin
          site = context.registers[:site]
          error_mode = (site.config.dig("liquid", "error_mode") || "lax").to_sym
          Liquid::Template.parse(File.read(path), error_mode: error_mode, line_numbers: true)
        end
        template.render!(context)
      end
    end

    # {% bookshop name attr=val ... %}
    class Tag < Liquid::Tag
      SYNTAX = %r/\A\s*([\w\.\-\/]+|\{\{[^}]+\}\})\s*(.*?)\s*\z/m

      def initialize(tag_name, markup, options)
        super
        match = SYNTAX.match(markup)
        raise Liquid::SyntaxError, "Invalid {% #{tag_name} %} syntax: #{markup}" unless match
        @name_token = match[1]
        @attrs = AttrParser.parse(match[2] || "")
      end

      def render(context)
        site = context.registers[:site]
        name = resolve_name(context)
        cname = name.split("/").last
        roots = site.config["bookshop_component_locations"] || []
        candidates = ["#{name}/#{cname}.jekyll.html", "#{name}.jekyll.html"]
        path = PartialResolver.find(roots, candidates)
        unless path
          raise IOError,
                "Bookshop component '#{name}' not found. Looked in: #{roots.join(", ")} for #{candidates.join(" or ")}"
        end
        params = AttrParser.evaluate(@attrs, context)
        context.stack do
          context["include"] = params
          PartialResolver.render(path, context)
        end
      end

      protected

      # Match jekyll-bookshop semantics: only render the token as a variable if
      # it contains a `{{ ... }}` expression. Bare tokens are literal component
      # names, even if a same-named variable exists in the context.
      def resolve_name(context)
        tok = @name_token
        return tok unless tok.include?("{{")
        Liquid::Template.parse(tok).render(context).to_s.strip
      end
    end

    # {% bookshop_include name attr=val ... %}
    class IncludeTag < Tag
      def render(context)
        site = context.registers[:site]
        name = resolve_name(context)
        roots = site.config["bookshop_shared_locations"] || []
        candidates = ["#{name}.jekyll.html"]
        path = PartialResolver.find(roots, candidates)
        raise IOError, "Bookshop shared partial '#{name}' not found in: #{roots.join(", ")}" unless path
        params = AttrParser.evaluate(@attrs, context)
        context.stack do
          context["include"] = params
          PartialResolver.render(path, context)
        end
      end
    end

    # {% bookshop_scss %}
    class StyleTag < Liquid::Tag
      def render(context)
        site = context.registers[:site]
        base_locations = site.config["bookshop_base_locations"] || []
        files = []
        base_locations.each do |location|
          loc = Pathname.new("#{location}/").cleanpath.to_s
          Dir.glob("#{loc}/**/*.scss").sort.each do |scss|
            files << scss.sub("#{loc}/", "").sub(/\.scss\z/, "")
          end
        end
        imports = files.sort do |a, b|
          a_shared = a.start_with?("shared/")
          b_shared = b.start_with?("shared/")
          if a_shared && !b_shared then -1
          elsif !a_shared && b_shared then 1
          else a <=> b
          end
        end.map { |f| %(@import "#{f}";) }.join

        "@media all, bookshop {#{imports}}"
      end
    end

    class NoopTag < Liquid::Tag
      def render(_context); ""; end
    end
  end
end
