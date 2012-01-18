module Nagix

  class NagiosXcmd

    NAGIOSXCMDS = {
      :DISABLE_NOTIFICATIONS =>                     { :signature => "", :command_id => 7 },
      :ENABLE_NOTIFICATIONS =>                      { :signature => "", :command_id => 8 },
      :ENABLE_EVENT_HANDLERS =>                     { :signature => "", :command_id => 47 },
      :DISABLE_EVENT_HANDLERS =>                    { :signature => "", :command_id => 48 },
      :ENABLE_HOST_NOTIFICATIONS =>                 { :signature => "host_name", :command_id => 15 },
      :DISABLE_HOST_NOTIFICATIONS =>                { :signature => "host_name", :command_id => 16 },
      :ENABLE_HOST_SVC_CHECKS =>                    { :signature => "host_name", :command_id => 33 },
      :DISABLE_HOST_SVC_CHECKS =>                   { :signature => "host_name", :command_id => 34 },
      :ENABLE_HOST_SVC_NOTIFICATIONS =>             { :signature => "host_name", :command_id => 35 },
      :DISABLE_HOST_SVC_NOTIFICATIONS =>            { :signature => "host_name", :command_id => 36 },
      :ENABLE_HOST_CHECK =>                         { :signature => "host_name", :command_id => 53 },
      :DISABLE_HOST_CHECK =>                        { :signature => "host_name", :command_id => 54 },
      :REMOVE_HOST_ACKNOWLEDGEMENT =>               { :signature => "host_name", :command_id => 116 },
      :DISABLE_SVC_NOTIFICATIONS =>                 { :signature => "host_name;service_description", :command_id => 12 },
      :ENABLE_SVC_NOTIFICATIONS =>                  { :signature => "host_name;service_description", :command_id => 11 },
      :REMOVE_SVC_ACKNOWLEDGEMENT =>                { :signature => "host_name;service_description", :command_id => 117 },
      :ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS =>     { :signature => "servicegroup", :command_id => 91 },
      :DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS =>    { :signature => "servicegroup", :command_id => 92 },
      :ENABLE_SERVICEGROUP_HOST_NOTIFICATIONS =>    { :signature => "servicegroup", :command_id => 93 },
      :DISABLE_SERVICEGROUP_HOST_NOTIFICATIONS =>   { :signature => "servicegroup", :command_id => 94 },
      :ENABLE_SERVICEGROUP_SVC_CHECKS =>            { :signature => "servicegroup", :command_id => 95 },
      :DISABLE_SERVICEGROUP_SVC_CHECKS =>           { :signature => "servicegroup", :command_id => 96 },
      :ENABLE_HOSTGROUP_HOST_NOTIFICATIONS =>       { :signature => "hostgroup", :command_id => 81 },
      :ACKNOWLEDGE_HOST_PROBLEM =>                  { :signature => "host_name>;sticky;notify;persistent;author;comment", :command_id => 39 },
      :ACKNOWLEDGE_SVC_PROBLEM =>                   { :signature => "host_name>;service_description;sticky;notify;persistent;author;comment", :command_id => 40 },
      :PROCESS_SERVICE_CHECK_RESULT =>              { :signature => "host_name;service_description;return_code;plugin_output", :command_id => 114 }
    }

    def self.docurl(napixcmd)
      NAGIOSXCMDS.has_key?(napixcmd.to_sym) ? "http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=#{NAGIOSXCMDS[napixcmd.to_sym][:command_id]}" : nil
    end

    class Error < StandardError; end
    class MissingParameters < Error; end
    class UnknownCommand < Error; end

    def initialize(napixcmd, params)
      @napixcmd = napixcmd.to_sym
      @cmd = nil
      if NAGIOSXCMDS.has_key?(@napixcmd)
        @cmd = napixcmd
        NAGIOSXCMDS[@napixcmd][:signature].split(';').each do |p|
          raise MissingParameters, "Missing parameter #{p} for Nagios External Command #{@napixcmd}; see #{NagiosXcmd.docurl(@napixcmd)}" if params[p.to_sym] == nil
          @cmd += ";#{params[p.to_sym]}"
        end
      else
        raise UnknownCommand, "Unknown Nagios External Command #{@napixcmd}"
      end
    end

    def to_s
      @cmd
    end
  end
end

