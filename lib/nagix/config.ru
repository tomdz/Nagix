lib_dir = File.expand_path("..", File.dirname(__FILE__))
$LOAD_PATH.unshift(lib_dir) if File.directory?(lib_dir) && !$LOAD_PATH.include?(lib_dir)

require 'rubygems'
require 'nagix'
require 'nagix/http'
require 'nagix/rest_api'
require 'nagix/rpc_api'
require 'sinatra'
require 'rack'

disable :run

map "/1.0/rest" do
  run Nagix::RestApi
end

map "/1.0/rpc" do
  run Nagix::RpcApi
end

map "/" do
  run Nagix::App
end
