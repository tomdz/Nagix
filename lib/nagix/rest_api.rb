require 'sinatra'
require 'rack/conneg'
require 'json'
require 'nagix/setup'
require 'nagix/mk_livestatus'

module Nagix
  # The Nagix REST API, which is available under `/1.0/rest`.
  class RestApi < Sinatra::Base
    use(Rack::Conneg) do |conneg|
      conneg.set :accept_all_extensions, false
      conneg.set :fallback, :html
      conneg.provide [:json, :html]
    end

    configure do
      config = Setup::setup_from_args
      if config
        config.to_hash.each do |k,v|
          set k.to_sym, v
        end
      end

      set :appname, "nagix-rest-api"
    end

    before do
      if negotiated?
        content_type negotiated_type
      end
    end

    # Executes a nagios command via MK Livestatus and sets the response status
    # to either 200 if successful, or 400 if an error occurred. In the latter case,
    # the body will be set to the error message.
    #
    # @param [String] cmd_name The command
    # @param [Hash,nil] params A hash with parameters for the command, if any
    # @return [void]
    def execute(cmd_name, params)
      begin
        lql = Nagix::MKLivestatus.new(:socket => settings.mklivestatus_socket,
                                      :log_file => settings.mklivestatus_log_file,
                                      :log_level => settings.mklivestatus_log_level)
        lql.execute(cmd_name, params)
        status 200
      rescue Exception => e
        halt 400, e.message
      end
    end

    # Performs an NQL query. If an error occurred, then this method will set the
    # response status to 400 and the body to the error message.
    #
    # @param [String] nql_query The query
    # @return [Hash,void] The query result
    def query(nql_query)
      begin
        lql = Nagix::MKLivestatus.new(:socket => settings.mklivestatus_socket,
                                      :log_file => settings.mklivestatus_log_file,
                                      :log_level => settings.mklivestatus_log_level)
        lql.query(nql_query)
      rescue Exception => e
        halt 400, e.message
      end
    end

    # Converts a boolean string (`true`, `false`) to the numbers 1 and 0. If the value
    # is undefined, then the passed in default value will be used instead.
    #
    # @param [String] value The value, can be `nil`
    # @param [String] default_value The default value, used when value = `nil`
    # @return [Integer] 1 for `true`, 0 otherwise
    def bool_to_num(value, default_value)
      if "true".casecmp(value || default_value.to_s)
        1
      else
        0
      end
    end

    # Enables all host and service event handlers.
    # Equivalent to [`ENABLE_EVENT_HANDLERS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=47).
    put "/eventHandlers" do
      execute :ENABLE_EVENT_HANDLERS
    end

    # Disables all host and service event handlers.
    # Equivalent to [`DISABLE_EVENT_HANDLERS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=48).
    delete "/eventHandlers" do
      execute :DISABLE_EVENT_HANDLERS
    end

    # Enables all notifications.
    # Equivalent to [`ENABLE_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=8).
    put "/notifications" do
      execute :ENABLE_NOTIFICATIONS
    end

    # Disables all notifications.
    # Equivalent to [`DISABLE_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=7).
    delete "/notifications" do
      execute :DISABLE_NOTIFICATIONS
    end

    # Enables checks for all services in the specified service group.
    # Equivalent to [`ENABLE_SERVICEGROUP_SVC_CHECKS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=95).
    put "/serviceGroups/:name/checks" do
      execute :ENABLE_SERVICEGROUP_SVC_CHECKS,
              :servicegroup => params[:name]
    end

    # Disables checks for all services in the service group.
    # Equivalent to [`DISABLE_SERVICEGROUP_SVC_CHECKS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=96).
    delete "/serviceGroups/:name/checks" do
      execute :DISABLE_SERVICEGROUP_SVC_CHECKS,
              :servicegroup => params[:name]
    end

    # Enables notifications for all services in the service group.
    # Equivalent to [`ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=91).
    put "/serviceGroups/:name/notifications" do
      execute :ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
              :servicegroup => params[:name]
    end

    # Disables notifications for all services in the service group.
    # Equivalent to [`DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=92).
    delete "/serviceGroups/:name/notifications" do
      execute :DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
              :servicegroup => params[:name]
    end

    # Returns the status (via MK Livestatus) for the given host. Supports either html or json
    # via the `Accept` header (`text/html` vs. `application/json`) or file ending (`.../status.html` or
    # `.../status.json`).
    get "/hosts/:name/status" do
      @host_name = params[:host_name]
      @hosts = query("SELECT * FROM hosts WHERE host_name = '#{@host_name}' OR alias = '#{@host_name}' OR address = '#{@host_name}'")
      respond_to do |wants|
        wants.html { @hosts == nil or @hosts.length == 0 ? halt(404, "Host #{@host_name} not found") : haml(:host) }
        wants.json { @hosts.to_json }
      end
    end

    # Acknowledges the problem for the given host.
    # Allowed query parameters are:
    #
    # * `author=...` - the author
    # * `comment=...` - a comment
    # * `sticky=true|false` - whether the acknowledgement will remain until the host returns to an UP state
    # * `notify=true|false` - whether a notification should be sent out to contacts indicating that the current host problem has been acknowledged
    # * `persistent=true|false` - whether the comment associated with the acknowledgement will survive across restarts of the Nagios process
    #
    # Equivalent to [`ACKNOWLEDGE_HOST_PROBLEM`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=39).
    put "/hosts/:name/acknowledgement" do
      execute :ACKNOWLEDGE_HOST_PROBLEM,
              :host_name => params[:name],
              :sticky => bool_to_num(request.params[:sticky], true),
              :notify => bool_to_num(request.params[:notify], true),
              :persistent => bool_to_num(request.params[:persistent], true),
              :author => request.params[:persistent] || '',
              :comment => request.params[:persistent] || ''
    end

    # Removes the problem acknowledgement for the given host.
    # Equivalent to [`REMOVE_HOST_ACKNOWLEDGEMENT`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=116).
    delete "/hosts/:name/acknowledgement" do
      execute :REMOVE_HOST_ACKNOWLEDGEMENT,
              :host_name => params[:name]
    end

    # Enables checks for the given host.
    # Equivalent to [`ENABLE_HOST_CHECK`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=53).
    put "/hosts/:name/checks" do
      execute :ENABLE_HOST_CHECK,
              :host_name => params[:name]
    end

    # Disables checks for the given host.
    # Equivalent to [`DISABLE_HOST_CHECK`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=54).
    delete "/hosts/:name/checks" do
      execute :DISABLE_HOST_CHECK,
              :host_name => params[:name]
    end

    # Enables notifications for the given host.
    # Equivalent to [`ENABLE_HOST_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=15).
    put "/hosts/:name/notifications" do
      execute :ENABLE_HOST_NOTIFICATIONS,
              :host_name => params[:name]
    end

    # Disables notifications for the given host.
    # Equivalent to [`DISABLE_HOST_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=16).
    delete "/hosts/:name/notifications" do
      execute :DISABLE_HOST_NOTIFICATIONS,
              :host_name => params[:name]
    end

    # Returns all services configured in Nagios for the given host. Supports either html or json
    # via the `Accept` header (`text/html` vs. `application/json`) or file ending (`.../status.html` or
    # `.../status.json`).
    get "/hosts/:name/services" do
      # TODO
    end

    # Enables checks for all services on the given host.
    # Equivalent to [`ENABLE_HOST_SVC_CHECKS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=33).
    put "/hosts/:name/services/checks" do
      execute :ENABLE_HOST_SVC_CHECKS,
              :host_name => params[:name]
    end

    # Disables checks for all services for the given host.
    # Equivalent to [`DISABLE_HOST_SVC_CHECKS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=34).
    delete "/hosts/:name/services/checks" do
      execute :DISABLE_HOST_SVC_CHECKS,
              :host_name => params[:name]
    end

    # Enables notifications for all services on the given host.
    # Equivalent to [`ENABLE_HOST_SVC_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=35).
    put "/hosts/:name/services/notifications" do
      execute :ENABLE_HOST_SVC_NOTIFICATIONS,
              :host_name => params[:name]
    end

    # Disables notifications for all services on the given host.
    # Equivalent to [`DISABLE_HOST_SVC_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=36).
    delete "/hosts/:name/services/notifications" do
      execute :DISABLE_HOST_SVC_NOTIFICATIONS,
              :host_name => params[:name]
    end

    # Returns the status (MK Livestatus) for the given service on the given host. Supports either
    # html or json  via the `Accept` header (`text/html` vs. `application/json`) or file ending
    # (`.../status.html` or `.../status.json`).
    get "/hosts/:name/services/:service/status" do
      @host_name = params[:name]
      @service_description = params[:service]
      host = query("SELECT name FROM hosts WHERE host_name = '#{@host_name}' OR alias = '#{@host_name}' OR address = '#{@host_name}'")
      @hosts = query("SELECT * FROM services WHERE host_name = '#{host[0]['name']}' AND description = '#{@service_description}'")
      respond_to do |wants|
        wants.html { @hosts == nil ? halt(404, "Host #{@host_name} not found") : haml(:host) }
        wants.json { @hosts.to_json }
      end
    end

    # Acknowledges the problem for the given service on the given host.
    # Allowed query parameters are:
    #
    # * `author=...` - the author
    # * `comment=...` - a comment
    # * `sticky=true|false` - whether the acknowledgement will remain until the host returns to an UP state
    # * `notify=true|false` - whether a notification should be sent out to contacts indicating that the current host problem has been acknowledged
    # * `persistent=true|false` - whether the comment associated with the acknowledgement will survive across restarts of the Nagios process
    #
    # Equivalent to [`ACKNOWLEDGE_SVC_PROBLEM`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=40).
    put "/hosts/:name/services/:service/acknowledgement" do
      execute :ACKNOWLEDGE_SVC_PROBLEM,
              :host_name => params[:name],
              :service_description => params[:service],
              :sticky => bool_to_num(request.params[:sticky], true),
              :notify => bool_to_num(request.params[:notify], true),
              :persistent => bool_to_num(request.params[:persistent], true),
              :author => request.params[:persistent] || '',
              :comment => request.params[:persistent] || ''
    end

    # Removes the problem acknowledgement for the given service on the given host.
    # Equivalent to [`REMOVE_SVC_ACKNOWLEDGEMENT`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=117).
    delete "/hosts/:name/services/:service/acknowledgement" do
      execute :REMOVE_SVC_ACKNOWLEDGEMENT,
              :host_name => params[:name],
              :service_description => params[:service]
    end

    # Enables notifications for the given service on the given host.
    # Equivalent to [`ENABLE_SVC_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=11).
    put "/hosts/:name/services/:service/notifications" do
      execute :ENABLE_SVC_NOTIFICATIONS,
              :host_name => params[:name]
    end

    # Disables notifications for the given service on the given host.
    # Equivalent to [`DISABLE_SVC_NOTIFICATIONS`](http://old.nagios.org/developerinfo/externalcommands/commandinfo.php?command_id=12).
    delete "/hosts/:name/services/:service/notifications" do
      execute :DISABLE_SVC_NOTIFICATIONS,
              :host_name => params[:name]
    end
  end
end
