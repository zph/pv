require 'yaml'

module Pv
  class Configuration

    def initialize
      @attributes = YAML::load_file from_path
      @attributes.each do |k,v|
        Configuration.send(:attr_accessor, k)
        instance_variable_set("@#{k}", v)
      end
    end

    def present?
      File.exists? from_path
    end

  private
    def from_path
      File.expand_path yaml_file_location
    end

    def yaml_file_location
      if File.exists? "#{Dir.pwd}/.pv"
        "#{Dir.pwd}/.pv"
      else
        "~/.pv"
      end
    end
  end
end
