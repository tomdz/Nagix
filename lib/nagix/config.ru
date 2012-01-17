lib_dir = File.expand_path("..", File.dirname(__FILE__))
$LOAD_PATH.unshift(lib_dir) if File.directory?(lib_dir) && !$LOAD_PATH.include?(lib_dir)

require 'rubygems'
require 'nagix'
require 'nagix/http'
require 'nagix/rest_api'
require 'nagix/rpc_api'
require 'nagix/setup'
require 'sinatra'
require 'rack'

disable :run

lql_creator = Proc.new { Nagix::MKLivestatus.new(:socket => settings.mklivestatus_socket,
                                                 :log_file => settings.mklivestatus_log_file,
                                                 :log_level => settings.mklivestatus_log_level) }

Nagix::RestApi.set :create_lql, lql_creator
Nagix::RpcApi.set :create_lql, lql_creator
Nagix::App.set :create_lql, lql_creator

map "/1.0/rest" do
  run Nagix::RestApi
end

map "/1.0/rpc" do
  run Nagix::RpcApi
end

map "/" do
  run Nagix::App
end
