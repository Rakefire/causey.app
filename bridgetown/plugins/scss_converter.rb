# frozen_string_literal: true

# SCSS converter for Bridgetown — compiles .scss assets through sass-embedded
# (Dart Sass), replacing Jekyll's jekyll-sass-converter integration.
#
# Runs after Bridgetown's LiquidTemplates converter, so any `{% include %}`
# or `{% bookshop_scss %}` directives in main.scss are already inlined by
# the time this converter sees the content.
#
# Load paths:
#   - <source>/_includes               (so @import "sass/foo" still works)
#   - <bookshop_base_locations>        (for component-library/components/*.scss)

require "sass-embedded"

class ScssConverter < Bridgetown::Converter
  priority :low
  input :scss

  def convert(content, convertible = nil)
    site = Bridgetown::Current.site
    load_paths = compute_load_paths(site)

    result = Sass.compile_string(
      content,
      syntax: :scss,
      style: production? ? :compressed : :expanded,
      load_paths: load_paths
    )
    apply_fluidvars(result.css)
  rescue Sass::CompileError => e
    path = convertible.respond_to?(:relative_path) ? convertible.relative_path : "(unknown)"
    Bridgetown.logger.error "Sass Exception:", "#{e.message} in #{path}"
    raise
  end

  # postcss-fluidvars equivalent: scan for `var(--s-N-M)` references and
  # inject clamp() declarations into the existing :root block (or prepend
  # one if missing). Mirrors the JS plugin's namespace-based behavior with
  # the namespace fixed to "s".
  FLUIDVAR_REF = /var\(\s*--s-(\d+(?:_\d+)?)-(\d+(?:_\d+)?)\s*\)/
  def apply_fluidvars(css)
    needed = css.scan(FLUIDVAR_REF).map { |a, b| [num(a), num(b)] }.uniq
    return css if needed.empty?
    declarations = needed.sort.map do |min, max|
      "--s-#{fmt(min)}-#{fmt(max)}: clamp(#{fmt(min)}px, calc(#{fmt(min)}px + #{fmt(max - min)} * (100vw - var(--s-design-min) * 1px) / (var(--s-design-max) - var(--s-design-min))), #{fmt(max)}px);"
    end
    block = declarations.join("\n  ")
    if css =~ /(:root\s*\{)([^}]*)\}/
      pre, vars = Regexp.last_match(1), Regexp.last_match(2)
      replacement = "#{pre}#{vars.rstrip}\n  #{block}\n}"
      css.sub(/:root\s*\{[^}]*\}/, replacement)
    else
      ":root {\n  #{block}\n}\n#{css}"
    end
  end

  def num(s)
    f = s.tr("_", ".").to_f
    f == f.to_i ? f.to_i : f
  end

  def fmt(n)
    n == n.to_i ? n.to_i.to_s : n.to_s
  end

  def output_ext(_ext)
    ".css"
  end

  private

  def compute_load_paths(site)
    paths = []
    if site
      src = site.source
      paths << File.join(src, "_includes")
      paths.concat(Array(site.config["bookshop_base_locations"]))
    end
    paths.select { |p| Dir.exist?(p) }
  end

  def production?
    Bridgetown.env.production?
  end
end
