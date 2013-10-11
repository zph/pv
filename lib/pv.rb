require 'core_ext/string'
require 'core_ext/object'

require 'pv/configuration'
require 'pv/command'
require 'pv/version'
require 'pv/bug_tracker'
require 'pv/story'

require 'vcr'


module Pv
  # Load YAML configuration
  def self.config
    @config ||= Pv::Configuration.new
  end

  # Connect to Pivotal Tracker
  def self.tracker
    @tracker ||= Pv::BugTracker.new
  end

  # Find where this code lives
  def self.root
    @root ||= begin
      spec = Gem::Specification.find_by_name 'pv'
      spec.gem_dir
    end
  end
end

VCR.configure do |c|
  c.cassette_library_dir = File.join(ENV['HOME'], ".pv_cache")
  c.hook_into :webmock
  c.default_cassette_options = { :re_record_interval => 60 }
  c.filter_sensitive_data('<PASSWORD>') { Pv.config.password }
  c.filter_sensitive_data('<EMAIL_ADDRESS>') { Pv.config.username }
end
