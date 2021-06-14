#!/usr/bin/env ruby

# frozen_string_literal: true

# bundler inline to get the right gems
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'colorize'
  gem 'typhoeus'
end

require 'date'
require 'json'

# rubocop:disable Metrics/ClassLength
class RubyGems
  VERSION = '0.6.1'
  MAX_REQUESTS_PER_SECOND = 10
  RATE_LIMIT_DOCUMENTATION_URL = 'https://guides.rubygems.org/rubygems-org-rate-limits/'

  def initialize(gems:)
    @gem_list = gems
    @batches = []
  end

  def lookup
    exit_early if @gem_list.empty?

    prepare_list
    process_batches
  end

  def self.version
    puts "version #{VERSION}"
  end

  def self.help
    puts <<~HELP
      This application's purpose is to make working with with RubyGems.org easier. 💖
      It uses the RubyGems public API to perform lookups, and parses the JSON response
      body to provide details about the most recent version, as well as links to
      the home page, source code, and changelog.

      #{usage}

      Feel free to pass in as many gems that you like, as it makes requests in
      parallel. There is a rate limit, #{MAX_REQUESTS_PER_SECOND}/sec. If it detects the amount of gems it
      has been passed is more than the rate limit, the application will run in Batch
      mode, and introduce a one second delay between batch lookups.

      Rate limit documentation: #{RATE_LIMIT_DOCUMENTATION_URL}

      #{options}
    HELP
  end

  def self.usage
    file_name = __FILE__.start_with?('./') ? __FILE__ : __FILE__.split('/').last

    <<~USAGE.chomp
      Usage: #{file_name} [GEM_NAME]

      Example: #{file_name} rails rspec
    USAGE
  end

  def self.options
    <<~OPTIONS
      Output Options:
        -h --help            Display the help screen.
        -v --version         Display version information.
    OPTIONS
  end

  private

  def prepare_list
    format_list
    batch_gems
  end

  def process_batches
    puts "=> ✨ Gems: #{@gem_list.size}" if @gem_list.size > 1

    @batches.each_with_index do |batch, index|
      puts "=> 🧺 Batch: #{index + 1} of #{@batches.size}".magenta if batch_mode?
      puts "=> 🔎 Looking up: #{batch.join(', ')}"

      make_requests batch: batch

      sleep 1 if batch_mode?
    end
  end

  def make_requests(batch:)
    Typhoeus::Hydra.hydra.tap do |hydra|
      populate_requests hydra: hydra, batch: batch
    end.run
  end

  def populate_requests(hydra:, batch:)
    batch.each do |gem_name|
      hydra.queue build_request gem_name: gem_name
    end
  end

  def build_request(gem_name:)
    url = api_url gem_name: gem_name
    Typhoeus::Request.new(url).tap do |request|
      request.on_complete do |response|
        if response.code == 200
          puts display_json(json: JSON.parse(response.body, symbolize_names: true))
        else
          puts not_found(gem_name: gem_name)
        end
      end
    end
  end

  def api_url(gem_name:)
    "https://rubygems.org/api/v1/gems/#{gem_name}.json"
  end

  # rubocop:disable Metrics/AbcSize
  def display_json(json:)
    [].tap do |output|
      output.push "=> 💎 #{json[:name]} is at #{json[:version]}".green
      output.push "==> 📅 #{convert_date(date: json[:version_created_at])}"
      output.push "==> 🏠 #{json[:homepage_uri]}"
      output.push "==> 🔗 #{json[:source_code_uri]}" if json[:source_code_uri]
      output.push changelog(changelog_uri: json[:changelog_uri])
    end.join "\n"
  end
  # rubocop:enable Metrics/AbcSize

  def changelog(changelog_uri:)
    return "==> 📑 #{changelog_uri}".light_blue if changelog_uri

    '==> 🚫 No changelog'.red
  end

  def not_found(gem_name:)
    "=> 💎 #{gem_name} not found".red
  end

  # Returns date times as date, aka "November 13, 2014"
  def convert_date(date:)
    Date.parse(date).strftime '%B %-d, %Y'
  end

  def format_list
    @gem_list.map!(&:downcase).uniq!
  end

  def batch_gems
    gems = @gem_list.dup

    @batches.push gems.shift(MAX_REQUESTS_PER_SECOND) while gems.any?
  end

  def batch_mode?
    @batches.size > 1
  end

  def exit_early
    puts ['', self.class.usage, '', self.class.options].join "\n"
    exit 1
  end
end

if ARGV.any? && (ARGV.first == '-h' || ARGV.first == '--help')
  RubyGems.help
elsif ARGV.any? && (ARGV.first == '-v' || ARGV.first == '--version')
  RubyGems.version
else
  RubyGems.new(gems: ARGV).lookup
end
# rubocop:enable Metrics/ClassLength
