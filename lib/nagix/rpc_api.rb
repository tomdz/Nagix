require 'sinatra'
require 'json'
require 'nagix/setup'

module Nagix
  class RpcApi < Sinatra::Base
    configure do
      Setup::setup_from_args.each do |k,v|
        set k.to_sym, v
      end

      set :root, File.expand_path("../..", File.dirname(__FILE__))
      set :appname, "nagix-rpc-api"
      enable :logging
    end

    def execute(cmd_name, params = {})
      lql = settings.create_lql
      lql.execute(cmd_name, params)
    end

    def query(nql_query)
      begin
        lql = settings.create_lql
        lql.query(nql_query)
      rescue Exception => e
        puts "#{$!}\n\t" + e.backtrace.join("\n\t")
        logger.error "#{$!}\n\t" + e.backtrace.join("\n\t")
        halt 400, e.message
      end
    end

    def status_query(host_name, service_description)
      hosts = query("SELECT * FROM hosts WHERE host_name = '#{host_name}' OR alias = '#{host_name}' OR address = '#{host_name}'")
      if hosts.nil? || hosts.empty?
        result = { :error => { :code => 404, :message => "Host #{host_name} not found" } }
      elsif service_description.nil?
        result = { :result => hosts }
      else
        services = query("SELECT * FROM services WHERE host_name = '#{hosts[0]['name']}' AND description = '#{service_description}'")
        if services.nil? || services.empty?
          result = { :error => { :code => 404, :message => "Service #{service_description} on host #{host_name} not found" } }
        else
          result = { :result => services} 
        end
      end
      result
    end

    post "/" do
      content_type 'application/json'
      begin
        inquiry = JSON.parse(request.body.read)
        if inquiry['jsonrpc'] != '2.0' || !inquiry.has_key?('method')
          result = { :jsonrpc => '2.0', :error => { :code => 400, :message => 'Request is not in JSON-RPC 2.0 form' }, :id => inquiry['id'] }
        end
      rescue JSON::ParserError
        result = { :jsonrpc => '2.0', :error => { :code => 400, :message => 'JSON parse error' } }
      rescue => e
        puts "#{$!}\n\t" + e.backtrace.join("\n\t")
        logger.error "#{$!}\n\t" + e.backtrace.join("\n\t")
        result = { :jsonrpc => '2.0', :error => { :code => 500, :message => e.message } }
      end
      if result.nil?
        method = inquiry['method'].upcase
        inquiry_params = inquiry['params'] || {}

        # we should change these two to host, service
        inquiry_params['host_name'] = inquiry_params['host'] if inquiry_params.has_key?('host')
        inquiry_params['service_description'] = inquiry_params['service'] if inquiry_params.has_key?('service')
        begin
          if method == "STATUS"
            result = status_query(inquiry_params['host_name'], inquiry_params['service_description'])
            result.merge!({ :jsonrpc => '2.0', :id => inquiry['id'] })
          else
            execute(method, inquiry_params)
            result = { :jsonrpc => '2.0', :result => true, :id => inquiry['id'] }
          end
        rescue => e
          puts "#{$!}\n\t" + e.backtrace.join("\n\t")
          logger.error "#{$!}\n\t" + e.backtrace.join("\n\t")
          result = { :jsonrpc => '2.0', :error => { :code => 500, :message => e.message }, :id => inquiry['id'] }
        end
      end
      status result.has_key?(:error) ? result[:error][:code].to_i : 200
      params[:pretty] ? JSON.pretty_generate(result) : result.to_json
    end
  end
end
