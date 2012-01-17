require 'rubygems'
require 'json'
require 'sinatra/base'
require 'sinatra/respond_to'
require 'haml'
require 'yaml'
require 'nagix/mk_livestatus'
require 'nagix/nagios_object'
require 'nagix/nagios_external_command'
require 'nagix/version'
require 'nagix/setup'

module Nagix

  class App < Sinatra::Base

    register Sinatra::RespondTo

    set :app_file, __FILE__
    set :root, File.expand_path("../..", File.dirname(__FILE__))

    configure do
      config = Setup::setup_from_args
      if config
        config.to_hash.each do |k,v|
          set k.to_sym, v
        end
      end

      set :appname, "nagix"
    end

    configure :production do
      set :show_exceptions, false
    end

    before do
      @qsparams = Rack::Utils.parse_query(request.query_string) # route does not handle query strings with duplicate names

      @filter = nil
      @columns = nil

      @columns = "Columns: " + @qsparams['attribute'].join(' ') + "\n" if @qsparams['attribute'].kind_of?(Array)
      @columns = "Columns: " + @qsparams['attribute'] + "\n" if @qsparams['attribute'].kind_of?(String)

      @lql = settings.create_lql
    end

    get '/' do
      haml :index
    end

    get '/hosts/?' do
      @hosts = @lql.query("SELECT host_name, name FROM hosts")
      respond_to do |wants|
        wants.html { @hosts.nil? ? not_found : haml(:hosts) }
        wants.json { @hosts.to_json }
      end
    end

    get ('foo') do
      if params[:host_name] != "" and params[:service_description] == ""
        redirect "/hosts/#{params[:host_name]}/attributes"
      elsif params[:host_name] != "" and params[:service_description] != ""
        redirect "/hosts/#{params[:host_name]}/#{params[:service_description]}/attributes"
      end

      @hosts = @lql.query("hosts", @filter, @columns)
      respond_to do |wants|
        wants.html { @hosts == nil ? not_found : haml(:hosts) }
        wants.json { @hosts.to_json }
      end
    end

    get '/hosts/:host_name/attributes' do
      @host_name = params[:host_name]
      @hosts = @lql.query("SELECT * FROM hosts WHERE host_name = '#{@host_name}' OR alias = '#{@host_name}' OR address = '#{@host_name}'")
      respond_to do |wants|
        wants.html { @hosts == nil or @hosts.length == 0 ? halt(404, "Host not found") : haml(:host) }
        wants.json { @hosts.to_json }
      end
    end

    get %r{/hosts/([a-zA-Z0-9\.]+)/([a-zA-Z0-9\.\/:_-]+)/attributes} do |host_name, service_description|
      h = @lql.query("SELECT name FROM hosts WHERE host_name = '#{host_name}' OR alias = '#{host_name}' OR address = '#{host_name}'")
      @hosts = @lql.query("SELECT * FROM services WHERE host_name = '#{h[0]['name']}' AND description = '#{service_description}'")
      respond_to do |wants|
        wants.html { @hosts == nil ? halt(404, "#{host_name} Host not found") : haml(:host) }
        wants.json { @hosts.to_json }
      end
    end

    get %r{/hosts/([a-zA-Z0-9\.]+)/([a-zA-Z0-9\.\/:_-]+)/command/([A-Z_]+)} do |host_name, service_description, napixcmd|
      @host_name = host_name
      @service_description = service_description
      @napixcmd = napixcmd
      @napicxmd_params =  {}
      haml :napixcmd
#      NagiosXcmd.docurl(napixcmd) ? redirect("#{NagiosXcmd.docurl(napixcmd)}",307) : halt(404, "Nagios External Command #{napixcmd} Not Found")
    end

    put %r{/hosts/([a-zA-Z0-9\.]+)/([a-zA-Z0-9\.\/:_-]+)/command/([A-Z_]+)} do |host_name, service_description, napixcmd|
      begin
        napixcmd_params = JSON.parse(request.body.read)
        napixcmd_params[:host_name] = host_name
        napixcmd_params[:service_description] = service_description
      rescue JSON::ParserError
        halt 400, "JSON parse error\n"
      end
      begin
        @lql.execute(napixcmd, napixcmd_params)
      rescue NagiosXcmd::Error => e
        halt 400, e.message
      end
    end

    put %r{/hosts/([a-zA-Z0-9\.]+)/command/([A-Z_]+)} do |host_name, napixcmd|
      begin
        napixcmd_params = JSON.parse(request.body.read)
        napixcmd_params[:host_name] = host_name
      rescue JSON::ParserError
        halt 400, "JSON parse error\n"
      end
      begin
        @lql.execute(napixcmd, napixcmd_params)
      rescue NagiosXcmd::Error => e
        halt 400, e.message
      end
    end

    post '/hosts' do
      if params[:host_name] != "" and params[:service_description] == ""
        redirect "/hosts/#{params[:host_name]}/attributes"
      elsif params[:host_name] != "" and params[:service_description] != ""
        redirect "/hosts/#{params[:host_name]}/#{params[:service_description]}/attributes"
      else
        redirect "/"
      end
    end

    get '/nagios' do
      @items = @lql.query("SELECT * FROM status")
      respond_to do |wants|
        wants.html { @items == nil ? not_found : haml(:table) }
        wants.json { @items.to_json }
      end
    end

  end
end
