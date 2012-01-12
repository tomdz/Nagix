require 'yaml'

module Nagix
  class Setup
    def self.setup_from_args
      config_file = nil
      if ARGV.any?
        require 'optparse'
        OptionParser.new { |op|
          op.on('-c path') { |val| config_file = val }
        }.parse!(ARGV.dup)
      end

      if config_file
        config = YAML.load_file(config_file)
      else
        if File.exist?(".nagixrc")
          config = YAML.load_file(".nagixrc")
        elsif File.exists?("#{ENV['HOME']}/.nagixrc")
          config = YAML.load_file("#{ENV['HOME']}/.nagixrc")
        elsif File.exists?("/etc/nagixrc")
          config = YAML.load_file("etc/nagixrc")
        end
      end
      config = config.to_hash if config
      # defaults
      return {
        'mklivestatus_socket' => nil,
        'mklivestatus_log_file' => nil,
        'mklivestatus_log_level' => nil
      }.merge(config || {})
    end
  end
end