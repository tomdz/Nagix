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
      config
    end
  end
end