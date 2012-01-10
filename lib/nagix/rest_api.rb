require 'sinatra'
require 'rack/conneg'
require 'json'
require 'nagix/setup'
require 'nagix/mk_livestatus'

module Nagix
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

    def bool_to_num(value, default_value)
      if "true".casecmp(value || default_value.to_s)
        1
      else
        0
      end
    end

    put "/eventHandlers" do
      execute :ENABLE_EVENT_HANDLERS
    end

    delete "/eventHandlers" do
      execute :DISABLE_EVENT_HANDLERS
    end

    put "/notifications" do
      execute :ENABLE_NOTIFICATIONS
    end

    delete "/notifications" do
      execute :DISABLE_NOTIFICATIONS
    end

    put "/serviceGroups/:name/checks" do
      execute :ENABLE_SERVICEGROUP_SVC_CHECKS,
              :servicegroup => params[:name]
    end

    delete "/serviceGroups/:name/checks" do
      execute :DISABLE_SERVICEGROUP_SVC_CHECKS,
              :servicegroup => params[:name]
    end

    put "/serviceGroups/:name/notifications" do
      execute :ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
              :servicegroup => params[:name]
    end

    delete "/serviceGroups/:name/notifications" do
      execute :DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
              :servicegroup => params[:name]
    end

    get "/hosts/:name" do
      @host_name = params[:host_name]
      @hosts = query("SELECT * FROM hosts WHERE host_name = '#{@host_name}' OR alias = '#{@host_name}' OR address = '#{@host_name}'")
      respond_to do |wants|
        wants.html { @hosts == nil or @hosts.length == 0 ? halt(404, "Host #{@host_name} not found") : haml(:host) }
        wants.json { @hosts.to_json }
      end
    end

    put "/hosts/:name/ack" do
      execute :ACKNOWLEDGE_HOST_PROBLEM,
              :host_name => params[:name],
              :sticky => bool_to_num(request.params[:sticky], true),
              :notify => bool_to_num(request.params[:notify], true),
              :persistent => bool_to_num(request.params[:persistent], true),
              :author => request.params[:persistent] || '',
              :comment => request.params[:persistent] || ''
    end

    delete "/hosts/:name/ack" do
      execute :REMOVE_HOST_ACKNOWLEDGEMENT,
              :host_name => params[:name]
    end

    put "/hosts/:name/checks" do
      execute :ENABLE_HOST_CHECK,
              :host_name => params[:name]
    end

    delete "/hosts/:name/checks" do
      execute :DISABLE_HOST_CHECK,
              :host_name => params[:name]
    end

    put "/hosts/:name/notifications" do
      execute :ENABLE_HOST_NOTIFICATIONS,
              :host_name => params[:name]
    end

    delete "/hosts/:name/notifications" do
      execute :DISABLE_HOST_NOTIFICATIONS,
              :host_name => params[:name]
    end

    get "/hosts/:name/services/:service" do
      @host_name = params[:name]
      @service_description = params[:service]
      host = query("SELECT name FROM hosts WHERE host_name = '#{@host_name}' OR alias = '#{@host_name}' OR address = '#{@host_name}'")
      @hosts = query("SELECT * FROM services WHERE host_name = '#{host[0]['name']}' AND description = '#{@service_description}'")
      respond_to do |wants|
        wants.html { @hosts == nil ? halt(404, "Host #{@host_name} not found") : haml(:host) }
        wants.json { @hosts.to_json }
      end
    end

    put "/hosts/:name/services/:service/ack" do
      execute :ACKNOWLEDGE_SVC_PROBLEM,
              :host_name => params[:name],
              :service_description => params[:service],
              :sticky => bool_to_num(request.params[:sticky], true),
              :notify => bool_to_num(request.params[:notify], true),
              :persistent => bool_to_num(request.params[:persistent], true),
              :author => request.params[:persistent] || '',
              :comment => request.params[:persistent] || ''
    end

    delete "/hosts/:name/services/:service/ack" do
      execute :REMOVE_SVC_ACKNOWLEDGEMENT,
              :host_name => params[:name],
              :service_description => params[:service]
    end

    put "/hosts/:name/services/checks" do
      execute :ENABLE_HOST_SVC_CHECKS,
              :host_name => params[:name]
    end

    delete "/hosts/:name/services/checks" do
      execute :DISABLE_HOST_SVC_CHECKS,
              :host_name => params[:name]
    end

    put "/hosts/:name/services/notifications" do
      execute :ENABLE_HOST_SVC_NOTIFICATIONS,
              :host_name => params[:name]
    end

    delete "/hosts/:name/services/notifications" do
      execute :DISABLE_HOST_SVC_NOTIFICATIONS,
              :host_name => params[:name]
    end

    put "/hosts/:name/services/:service/notifications" do
      execute :ENABLE_SVC_NOTIFICATIONS,
              :host_name => params[:name]
    end

    delete "/hosts/:name/services/:service/notifications" do
      execute :DISABLE_SVC_NOTIFICATIONS,
              :host_name => params[:name]
    end
  end
end
