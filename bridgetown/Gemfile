source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

####
# Welcome to your project's Gemfile, used by Rubygems & Bundler.
#
# To install a plugin, run:
#
#   bundle add new-plugin-name
#
# and add a relevant init comment to your config/initializers.rb file.
#
# When you run Bridgetown commands, we recommend using a binstub like so:
#
#   bin/bridgetown start (or console, etc.)
#
# This will help ensure the proper Bridgetown version is running.
####

# If you need to upgrade/switch Bridgetown versions, change the line below
# and then run `bundle update bridgetown`
gem "bridgetown", "~> 1.3"

# Puma is the Rack-compatible web server used by Bridgetown
gem "puma", "< 7"

# Plugin replacements for Jekyll-era plugins
gem "bridgetown-feed", "~> 4.0"
gem "bridgetown-sitemap", "~> 3.0"

# Sass compilation for assets/main.scss (replaces jekyll-sass-converter)
gem "sass-embedded", "~> 1.99"

# Uncomment to use the Inspectors API to manipulate the output
# of your HTML or XML resources:
# gem "nokogiri", "~> 1.13"

# Or for faster parsing of HTML-only resources via Inspectors, use Nokolexbor:
# gem "nokolexbor", "~> 0.5"
