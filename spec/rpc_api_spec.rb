lib_dir = File.expand_path("../lib", File.dirname(__FILE__))
$LOAD_PATH.unshift(lib_dir) if File.directory?(lib_dir) && !$LOAD_PATH.include?(lib_dir)

require 'nagix/rpc_api'
require 'nagix/nagios_external_command'
require 'rack/test'
require 'flexmock/rspec'

set :environment, :test

RSpec.configure do |config|
  config.mock_with :flexmock
end

describe Nagix::RpcApi do
  include Rack::Test::Methods

  class RpcRequestBuilder
    attr_reader :lql, :data, :cmd, :params, :result_key, :expected_value

    def initialize(lql, &block)
      @lql = lql
      @data = {}
      @params = {}
      instance_eval(&block) if block_given?
    end

    def command(cmd, items = {})
      @lql.should_receive(:execute).with(cmd.to_s, items.inject({}) {|h, (key, value)| h[key.to_s] = value; h}).once
      @cmd = cmd.to_s
      @params = items
    end

    def parameters(items)
      @params = items
    end

    def result(item)
      item.each do |key, value|
        @result_key = key
        @expected_value = value
        @lql.should_receive(:query).with(key).and_return(value)
      end
    end

    def data(items)
      items.each do |key, value|
        @lql.should_receive(:query).with(key).and_return(value)
      end
    end
  end

  def app
    Nagix::RpcApi
  end

  def status_test(&block)
    request = RpcRequestBuilder.new(flexmock(), &block)
    Nagix::RpcApi.set :create_lql, Proc.new { request.lql }

    body = { :jsonrpc => "2.0", 
             :method => "STATUS",
             :params => request.params,
             :id => "123" }
    post "/", body.to_json, :content_type => "application/json"

    body = JSON.parse(last_response.body)
    body.should be_a_kind_of(Hash)
    body.should include("jsonrpc" => "2.0")
    body.should include("id" => "123")
    if request.result_key.nil?
      last_response.should be_not_found
      body.should include("error")
      body['error'].should include("code" => 404)
      body.should_not include("result")
    else
      last_response.should be_ok
      body.should include("result" => request.expected_value)
      body.should_not include("error")
    end
  end

  def execute_test(&block)
    request = RpcRequestBuilder.new(flexmock(), &block)
    Nagix::RpcApi.set :create_lql, Proc.new { request.lql }

    body = { :jsonrpc => "2.0", 
             :method => request.cmd,
             :params => request.params,
             :id => "123" }
    post "/", body.to_json, :content_type => "application/json"

    last_response.should be_ok
    body = JSON.parse(last_response.body)
    body.should be_a_kind_of(Hash)
    body.should include("jsonrpc" => "2.0")
    body.should include("id" => "123")
    body.should include("result" => true)
    body.should_not include("error")
  end

  describe "STATUS for host" do
    it "returns error response for unknown host" do
      status_test do
        parameters :host => "foo"
        data "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => []
      end
    end

    it "returns indicated host" do
      status_test do
        parameters :host => "foo"
        result "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                   [ { "name" => "foo", "address" => "127.0.0.1" } ]
      end
    end
  end

  describe "STATUS for host and service" do
    it "returns error response for unknown host" do
      status_test do
        parameters :host => "foo", :service => "bar"
        data "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => []
      end
    end

    it "returns error response for unknown service" do
      status_test do
        parameters :host => "foo", :service => "bar"
        data "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                 [ { "name" => "foo", "address" => "127.0.0.1" } ],
             "SELECT * FROM services WHERE host_name = 'foo' AND description = 'bar'" => 
                 [ ]
      end
    end

    it "returns host & service" do
      status_test do
        parameters :host => "foo", :service => "bar"
        data "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                 [ { "name" => "foo", "address" => "127.0.0.1" } ]
        result "SELECT * FROM services WHERE host_name = 'foo' AND description = 'bar'" => 
                   [ { "description" => "bar", "groups" => "test", "host_name" => "foo" } ]
      end
    end
  end

  describe "EVENT_HANDLERS" do
    it "responds to ENABLE_EVENT_HANDLERS" do
      execute_test do
        command :ENABLE_EVENT_HANDLERS
      end
    end

    it "responds to DISABLE_EVENT_HANDLERS" do
      execute_test do
        command :DISABLE_EVENT_HANDLERS
      end
    end
  end

  describe "NOTIFICATIONS" do
    it "responds to ENABLE_NOTIFICATIONS" do
      execute_test do
        command :ENABLE_NOTIFICATIONS
      end
    end

    it "responds to DISABLE_NOTIFICATIONS" do
      execute_test do
        command :DISABLE_NOTIFICATIONS
      end
    end
  end

  describe "SERVICEGROUP_SVC_CHECKS" do
    it "responds to ENABLE_SERVICEGROUP_SVC_CHECKS" do
      execute_test do
        command :ENABLE_SERVICEGROUP_SVC_CHECKS,
                :servicegroup => "foo"
      end
    end

    it "responds to DISABLE_SERVICEGROUP_SVC_CHECKS" do
      execute_test do
        command :DISABLE_SERVICEGROUP_SVC_CHECKS,
                :servicegroup => "foo"
      end
    end
  end

  describe "SERVICEGROUP_SVC_NOTIFICATIONS" do
    it "responds to ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS" do
      execute_test do
        command :ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
                :servicegroup => "foo"
      end
    end

    it "responds to DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS" do
      execute_test do
        command :DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
                :servicegroup => "foo"
      end
    end
  end

  describe "HOST_PROBLEM" do
    it "responds to ACKNOWLEDGE_HOST_PROBLEM" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_HOST_PROBLEM with author query param" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "Bob", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_HOST_PROBLEM with comment query param" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "Test", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_HOST_PROBLEM with notify query param set to true" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_HOST_PROBLEM with notify query param set to false" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 0, :persistent => 1, :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_HOST_PROBLEM with persistent param set to true" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_HOST_PROBLEM with persistent param set to false" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 0, :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_HOST_PROBLEM with sticky param set to true" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_HOST_PROBLEM with sticky param set to false" do
      execute_test do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 0
      end
    end

    it "responds to REMOVE_HOST_ACKNOWLEDGEMENT" do
      execute_test do
        command :REMOVE_HOST_ACKNOWLEDGEMENT,
                :host_name => "foo"
      end
    end
  end

  describe "HOST_CHECK" do
    it "responds to ENABLE_HOST_CHECK" do
      execute_test do
        command :ENABLE_HOST_CHECK,
                :host_name => "foo"
      end
    end

    it "responds to DISABLE_HOST_CHECK" do
      execute_test do
        command :DISABLE_HOST_CHECK,
                :host_name => "foo"
      end
    end
  end

  describe "HOST_NOTIFICATIONS" do
    it "responds to ENABLE_HOST_NOTIFICATIONS" do
      execute_test do
        command :ENABLE_HOST_NOTIFICATIONS,
                :host_name => "foo"
      end
    end

    it "responds to DISABLE_HOST_NOTIFICATIONS" do
      execute_test do
        command :DISABLE_HOST_NOTIFICATIONS,
                :host_name => "foo"
      end
    end
  end

  describe "HOST_SVC_CHECKS" do
    it "responds to ENABLE_HOST_SVC_CHECKS" do
      execute_test do
        command :ENABLE_HOST_SVC_CHECKS,
                :host_name => "foo"
      end
    end

    it "responds to DISABLE_HOST_SVC_CHECKS" do
      execute_test do
        command :DISABLE_HOST_SVC_CHECKS,
                :host_name => "foo"
      end
    end
  end

  describe "HOST_SVC_NOTIFICATIONS" do
    it "responds to ENABLE_HOST_SVC_NOTIFICATIONS" do
      execute_test do
        command :ENABLE_HOST_SVC_NOTIFICATIONS,
                :host_name => "foo"
      end
    end

    it "responds to DISABLE_HOST_SVC_NOTIFICATIONS" do
      execute_test do
        command :DISABLE_HOST_SVC_NOTIFICATIONS,
                :host_name => "foo"
      end
    end
  end

  describe "SVC_PROBLEM" do
    it "responds to ACKNOWLEDGE_SVC_PROBLEM" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_SVC_PROBLEM with author query param" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "Bob", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_SVC_PROBLEM with comment query param" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "Test", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with notify query param set to true" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_SVC_PROBLEM with notify query param set to false" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 0, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_SVC_PROBLEM with persistent param set to true" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_SVC_PROBLEM with persistent param set to false" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 0, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_SVC_PROBLEM with sticky param set to true" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to ACKNOWLEDGE_SVC_PROBLEM with sticky param set to false" do
      execute_test do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 0
      end
    end

    it "responds to REMOVE_SVC_ACKNOWLEDGEMENT" do
      execute_test do
        command :REMOVE_SVC_ACKNOWLEDGEMENT,
                :host_name => "foo", :service_description => "bar"
      end
    end
  end

  describe "SVC_NOTIFICATIONS" do
    it "responds to ENABLE_SVC_NOTIFICATIONS" do
      execute_test do
        command :ENABLE_SVC_NOTIFICATIONS,
                :host_name => "foo", :service_description => "bar"
      end
    end

    it "responds to DISABLE_SVC_NOTIFICATIONS" do
      execute_test do
        command :DISABLE_SVC_NOTIFICATIONS,
                :host_name => "foo", :service_description => "bar"
      end
    end
  end

  describe "unsupported method" do
    it "doesn't respond to ENABLE_FOO_NOTIFICATIONS" do
      lql = flexmock()
      lql.should_receive(:execute).with("ENABLE_FOO_NOTIFICATIONS", {}).once.and_raise(Nagix::NagiosXcmd::UnknownCommand, "Unknown Nagios External Command ENABLE_FOO_NOTIFICATIONS")
      Nagix::RpcApi.set :create_lql, Proc.new { lql }

      body = { :jsonrpc => "2.0", 
               :method => "ENABLE_FOO_NOTIFICATIONS",
               :params => {},
               :id => "123" }
      post "/", body.to_json, :content_type => "application/json"

      last_response.status.should == 400
      body = JSON.parse(last_response.body)
      body.should be_a_kind_of(Hash)
      body.should include("jsonrpc" => "2.0")
      body.should include("id" => "123")
      body.should_not include("result")
      body.should include("error")
      body["error"].should include("code" => 400)
    end
  end
end