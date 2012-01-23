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

      @columns = "Columns: " + @qsparams['attribute'].join(' ') + "\n" if @qsparams['attribute'].kind_of?(Array)
      @columns = "Columns: " + @qsparams['attribute'] + "\n" if @qsparams['attribute'].kind_of?(String)

      @lql = settings.create_lql
    end

    get '/' do
      haml :index
    end

    get '/hostgroups' do
      haml :hostgroups
    end

    get '/host' do
      haml :host
    end

    get '/hosts' do
      haml :hosts
    end

    get '/servicegroups' do
      haml :servicegroups
    end

    get '/service' do
      haml :service
    end

    get '/services' do
      haml :services
    end

    get '/nagios' do
      @items = @lql.query("SELECT * FROM status")
      respond_to do |wants|
        wants.html { @items == nil ? not_found : haml(:nagios) }
        wants.json { @items.to_json }
      end
    end

  end
end
