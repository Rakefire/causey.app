# frozen_string_literal: true

# JekyllCompat — shims to let Jekyll-style Liquid templates run on Bridgetown
# unmodified. Used during the Jekyll → Bridgetown migration of causey.app.
#
# What it does:
#   1. Replaces Liquid's `{% include %}` with a Jekyll-IncludeTag-compatible
#      version: bare filenames, `.html`/`.svg` extensions, `include.X` scope,
#      `_includes/` lookup.
#   2. Patches Bridgetown::Drops::SiteDrop so `site.<collection>` returns the
#      collection's resources sorted reverse-chronologically (Jekyll
#      semantics for `site.posts`, `site.staff_members`, etc).
#   3. Patches Bridgetown::Drops::ResourceDrop so `page.url` and `post.url`
#      return `relative_url` (Jekyll exposes `.url`; Bridgetown exposes
#      `.relative_url`/`.absolute_url`).
#
# Patches happen at file-load time so they're in place before any Liquid
# rendering. The SiteBuilder wrapper exists only because Bridgetown's
# Zeitwerk autoload requires `plugins/builders/<file>.rb` to define
# `Builders::<File>`.

module Builders
  class JekyllCompat < SiteBuilder
    def build
      # Register Jekyll-only Liquid filters that Bridgetown doesn't ship.
      liquid_filter "find", :jekyll_find
      liquid_filter "find_exp", :jekyll_find_exp
    end

    # Returns the first item in `input` whose `property` equals `value`.
    # Mirrors Jekyll's `find` filter. Items may be raw Bridgetown resources
    # (which don't define `[]`), so we look up properties via `data` first.
    def jekyll_find(input, property, value)
      return nil if input.nil? || !input.respond_to?(:each)
      Array(input).find do |item|
        item_value = lookup_property(item, property)
        item_value.to_s == value.to_s
      end
    end

    def lookup_property(item, property)
      if item.respond_to?(:data) && item.data
        v = item.data[property] || item.data[property.to_s] || item.data[property.to_sym]
        return v unless v.nil?
      end
      if item.respond_to?(:[])
        v = item[property] || item[property.to_s] || item[property.to_sym]
        return v unless v.nil?
      end
      if item.respond_to?(property)
        item.public_send(property)
      end
    end

    # Returns the first item in `input` for which the Liquid expression
    # evaluates truthy. Mirrors Jekyll's `find_exp` filter (less common).
    def jekyll_find_exp(input, variable, expression)
      return nil if input.nil? || !input.respond_to?(:each)
      parsed = Liquid::Template.parse("{% if #{expression} %}true{% endif %}")
      Array(input).find do |item|
        ctx = filters_context.dup
        ctx[variable] = item
        parsed.render(ctx).strip == "true"
      end
    end
  end
end

# ---- 1) Jekyll-style {% include %} replacement -----------------------------

module JekyllCompat
  # Matches Jekyll's IncludeTag syntax: `name [param=value ...]`.
  # `name` may be: bare identifier with slashes/dots/hyphens (e.g. svg/foo.svg),
  # a quoted string, or a `{{ var }}` reference.
  class IncludeTag < Liquid::Tag
    SYNTAX = %r/\A\s*([\w\.\-\/]+|"[^"]*"|'[^']*'|\{\{[^}]+\}\})\s*(.*?)\s*\z/m

    ATTR_RE = /
      (\w[\w\-]*)
      \s*=\s*
      (
        "[^"]*" | '[^']*' |
        [\w\.\-]+
      )
    /x

    def initialize(tag_name, markup, options)
      super
      match = SYNTAX.match(markup)
      raise Liquid::SyntaxError, "Invalid {% #{tag_name} %} syntax: #{markup}" unless match
      @name_token = match[1]
      @attrs = {}
      (match[2] || "").scan(ATTR_RE) do |k, v|
        @attrs[k] = Liquid::Expression.parse(v)
      end
    end

    def render(context)
      site = context.registers[:site]
      name = resolve_name(context)
      path = locate(site, name)
      raise IOError, "Include not found: '#{name}'" unless path

      params = @attrs.transform_values { |expr| context.evaluate(expr) }
      content = read_cached(path, site)
      template = parse_cached(path, content, site)

      context.stack do
        context["include"] = params
        template.render!(context)
      end
    end

    private

    def resolve_name(context)
      tok = @name_token
      if tok.start_with?(?', ?")
        return tok[1..-2]
      end
      if tok.start_with?("{{")
        var = tok.sub(/\A\{\{/, "").sub(/\}\}\z/, "").strip
        val = Liquid::VariableLookup.parse(var).evaluate(context)
        return val.to_s if val
        return tok
      end
      # Bare token: treat as literal filename (Jekyll behavior).
      tok
    end

    def locate(site, name)
      candidates = [name]
      # Liquid's standard render falls back to .liquid/.html if no extension;
      # Jekyll's include uses the literal filename with extension. Try both.
      unless name.include?(".")
        candidates << "#{name}.liquid" << "#{name}.html"
      end
      roots = include_roots(site)
      roots.each do |root|
        candidates.each do |cand|
          full = File.join(root, cand)
          return full if File.exist?(full)
        end
      end
      nil
    end

    def include_roots(site)
      @@roots_cache ||= {}
      @@roots_cache[site.source] ||= begin
        # _includes/ takes precedence; then components_load_paths for parity.
        includes_dir = File.join(site.source, "_includes")
        roots = []
        roots << includes_dir if Dir.exist?(includes_dir)
        roots.concat(site.config.components_load_paths.to_a)
        roots
      end
    end

    @@partial_cache = {}

    def read_cached(path, site)
      @@partial_cache[path] ||= File.read(path, **site.file_read_opts)
    end

    @@template_cache = {}

    def parse_cached(path, content, site)
      @@template_cache[path] ||= begin
        error_mode = (site.config.dig("liquid", "error_mode") || "lax").to_sym
        Liquid::Template.parse(content, error_mode: error_mode, line_numbers: true)
      end
    end
  end
end

Liquid::Template.register_tag("include", JekyllCompat::IncludeTag)

# ---- 2) site.<collection> proxy --------------------------------------------

module Bridgetown
  module Drops
    class SiteDrop
      # Resolve unknown keys to collection resources for Jekyll parity.
      # `site.posts` → reverse-chronological array of post resources.
      # `site.<name>` → resources of any collection registered on the site.
      alias_method :__jekyll_compat_orig_brackets, :[] unless method_defined?(:__jekyll_compat_orig_brackets)

      def [](key)
        existing = __jekyll_compat_orig_brackets(key)
        return existing unless existing.nil?

        coll = @obj.collections[key.to_s]
        return nil unless coll

        # Jekyll's `site.posts` is sorted reverse-chronological. For other
        # collections without dates, Jekyll sorts by file path ascending.
        # Mirror both: sort by date desc when all resources have dates,
        # otherwise by relative_path asc.
        resources = coll.resources
        # Posts always sort reverse-chronological; other collections sort by
        # file path ascending (Jekyll behavior).
        if key.to_s == "posts"
          resources.sort_by { |r| r.data["date"] || Time.at(0) }.reverse
        else
          resources.sort_by { |r| r.relative_path.to_s }
        end
      end

      def key?(key)
        return true unless self[key].nil?
        false
      end
    end
  end
end

# ---- 3) page.url / post.url shim + URL normalization -----------------------
#
# Bridgetown's PermalinkProcessor produces "//" when the permalink template
# is the literal "/" (the home page case). Patch Resource::Base so every
# downstream consumer — page.url, sitemap.xml, feed.xml, canonical tags —
# sees a single-slash URL.

module Bridgetown
  module Resource
    class Base
      alias_method :__jekyll_compat_orig_relative_url, :relative_url unless method_defined?(:__jekyll_compat_orig_relative_url)
      alias_method :__jekyll_compat_orig_absolute_url, :absolute_url unless method_defined?(:__jekyll_compat_orig_absolute_url)

      def relative_url
        normalize_url(__jekyll_compat_orig_relative_url)
      end

      def absolute_url
        normalize_url(__jekyll_compat_orig_absolute_url)
      end

      private

      def normalize_url(url)
        return url unless url.is_a?(String)
        # Collapse internal "//" to "/" while preserving the protocol "://".
        url.sub(%r{(?<!:)/{2,}}, "/")
      end
    end
  end

  module Drops
    class ResourceDrop
      # Jekyll exposed `.url` as the path-relative URL. Bridgetown exposes
      # `relative_url`/`absolute_url` but not bare `url`. Map `url` to
      # relative_url unless the resource's data already defined a `url` key.
      def url
        if @obj.respond_to?(:data) && @obj.data && @obj.data["url"]
          @obj.data["url"]
        elsif @obj.respond_to?(:relative_url)
          @obj.relative_url
        end
      end

      # Jekyll: `post.next` is the newer post (later in time), `post.previous`
      # is the older one. Bridgetown's posts collection sorts descending by
      # default, so `next_resource` walks the array forward — i.e. to OLDER
      # posts. Swap the aliases so chronological semantics match Jekyll.
      def next
        prev_obj = @obj.respond_to?(:previous_resource) ? @obj.previous_resource : nil
        prev_obj ? prev_obj.to_liquid : nil
      end

      def previous
        nxt = @obj.respond_to?(:next_resource) ? @obj.next_resource : nil
        nxt ? nxt.to_liquid : nil
      end
    end
  end
end
