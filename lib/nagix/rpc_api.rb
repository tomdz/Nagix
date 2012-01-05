require 'sinatra'
require 'json'
require 'nagix/setup'
require 'nagix/mk_livestatus'

module Nagix
  class RpcApi < Sinatra::Base
    configure do
      config = Setup::setup_from_args
      if config
        config.to_hash.each do |k,v|
          set k.to_sym, v
        end
      end

      set :appname, "nagix-rpc-api"
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

    post "/" do
      content_type 'application/json'
      begin
        inquiry = JSON.parse(request.body.read)
      rescue JSON::ParserError
        status 400
        result = { 'jsonrpc' => '2.0', 'error' => { 'message' => 'JSON parse error' }, 'id' => params['id'] }
      end
      if inquiry['jsonrpc'] != '2.0' || !inquiry['method']
        status 400
        result = { 'jsonrpc' => '2.0', 'error' => { 'message' => 'Request is not in JSON-RPC 2.0 form' }, 'id' => params['id'] }
      end
      method = inquiry['method'].upcase
      params = inquiry['params'] || {}
      # we should change these two to host, service
      params['host_name'] = params['host'] if params['host']
      params['service_description'] = params['service'] if params['service']
      if method == "STATUS"
        host_name = params[:host_name]
        hosts = query("SELECT * FROM hosts WHERE host_name = '#{host_name}' OR alias = '#{host_name}' OR address = '#{host_name}'")
        if params['service']
          service = params[:service]
          hosts = query("SELECT * FROM services WHERE host_name = '#{hosts[0]['name']}' AND description = '#{service}'")
        end
        result = { 'jsonrpc' => '2.0', 'result' => hosts, 'id' => params['id'] }
      else
        execute method, params
        status 200
        result = { 'jsonrpc' => '2.0', 'result' => true, 'id' => params['id'] }
      end
      return result.to_json
    end
  end
end