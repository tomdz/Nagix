lib_dir = File.expand_path("../lib", File.dirname(__FILE__))
$LOAD_PATH.unshift(lib_dir) if File.directory?(lib_dir) && !$LOAD_PATH.include?(lib_dir)

require 'nagix/rest_api'
require 'rack/test'
require 'flexmock/rspec'

set :environment, :test

RSpec.configure do |config|
  config.mock_with :flexmock
end

describe Nagix::RestApi do
  include Rack::Test::Methods

  class RestRequestBuilder
    attr_reader :lql, :data, :result_key, :expected_value

    def initialize(lql, &block)
      @lql = lql
      @data = {}
      instance_eval(&block) if block_given?
    end

    def command(cmd, params = {})
      @lql.should_receive(:execute).with(cmd, params).once
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
    Nagix::RestApi
  end

  def get_test(uri, &block)
    request = RestRequestBuilder.new(flexmock(), &block)
    Nagix::RestApi.set :create_lql, Proc.new { request.lql }

    get uri

    if request.result_key.nil?
      last_response.should be_not_found
    else
      last_response.should be_ok
      body = JSON.parse(last_response.body)
      body.should be_a_kind_of(Array)
      body.length.should be(request.expected_value.length)
      request.expected_value.each do |item|
        body.should include(item)
      end
    end
  end

  def put_test(uri, &block)
    request = RestRequestBuilder.new(flexmock(), &block)
    Nagix::RestApi.set :create_lql, Proc.new { request.lql }

    put uri
    last_response.should be_ok
    last_response.body.should eq('')
  end

  def delete_test(uri, &block)
    request = RestRequestBuilder.new(flexmock(), &block)
    Nagix::RestApi.set :create_lql, Proc.new { request.lql }

    delete uri
    last_response.should be_ok
    last_response.body.should eq('')
  end

  describe "/eventHandlers" do
    it "responds to PUT" do
      put_test "/eventHandlers" do
        command :ENABLE_EVENT_HANDLERS
      end
    end

    it "responds to DELETE" do
      delete_test "/eventHandlers" do
        command :DISABLE_EVENT_HANDLERS
      end
    end
  end

  describe "/notifications" do
    it "responds to PUT" do
      put_test "/notifications" do
        command :ENABLE_NOTIFICATIONS
      end
    end

    it "responds to DELETE" do
      delete_test "/notifications" do
        command :DISABLE_NOTIFICATIONS
      end
    end
  end

  describe "/services" do
    it "returns no services if none are configured" do
      get_test "/services.json" do
        result "SELECT * FROM services" => []
      end
    end

    it "returns all configured services" do
      get_test "/services.json"do
        result "SELECT * FROM services" =>
                   [ { "description" => "dummy1", "groups" => "test", "host_name" => "foo" },
                     { "description" => "dummy2", "groups" => "test", "host_name" => "bar" } ]
      end
    end
  end

  describe "/serviceGroups/:name" do
    it "returns 404 if service group not found" do
      get_test "/serviceGroups/foo.json"do
        data "SELECT * FROM servicegroups WHERE name = 'foo' OR alias = 'foo'" => []
      end
    end

    it "returns indicated service group" do
      get_test "/serviceGroups/foo.json"do
        result "SELECT * FROM servicegroups WHERE name = 'foo' OR alias = 'foo'" => 
                   [ { "name" => "foo", "num_services" => 1 } ]
      end
    end
  end

  describe "/serviceGroups/:name/services" do
    it "returns 404 if service group not found" do
      get_test "/serviceGroups/foo/services.json"do
        data "SELECT * FROM servicegroups WHERE name = 'foo' OR alias = 'foo'" => []
      end
    end

    it "returns all configured service groups" do
      get_test "/serviceGroups/test/services.json"do
         data "SELECT * FROM servicegroups WHERE name = 'test' OR alias = 'test'" =>
                  [ { "name" => "test", "num_services" => 2 } ]
         result "SELECT * FROM services WHERE groups contains 'test'" => 
                    [ { "description" => "dummy1", "groups" => "test", "host_name" => "foo" },
                      { "description" => "dummy2", "groups" => "test", "host_name" => "bar" } ]
      end
    end
  end

  describe "/serviceGroups/:name/checks" do
    it "responds to PUT" do
      put_test "/serviceGroups/foo/checks" do
        command :ENABLE_SERVICEGROUP_SVC_CHECKS,
                :servicegroup => "foo"
      end
    end

    it "responds to DELETE" do
      delete_test "/serviceGroups/foo/checks" do
        command :DISABLE_SERVICEGROUP_SVC_CHECKS,
                :servicegroup => "foo"
      end
    end
  end

  describe "/serviceGroups/:name/notifications" do
    it "responds to PUT" do
      put_test "/serviceGroups/foo/notifications" do
        command :ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
                :servicegroup => "foo"
      end
    end

    it "responds to DELETE" do
      delete_test "/serviceGroups/foo/notifications" do
        command :DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
                :servicegroup => "foo"
      end
    end
  end

  describe "/hosts" do
    it "returns no hosts if none are configured" do
      get_test "/hosts.json"do
        result "SELECT * FROM hosts" => []
      end
    end

    it "returns all configured hosts" do
      get_test "/hosts.json"do
        result "SELECT * FROM hosts" => 
                   [ { "name" => "dummy1", "address" => "127.0.0.1" },
                     { "name" => "dummy2", "address" => "127.0.0.2" } ]
      end
    end
  end

  describe "/hosts/:name" do
    it "returns 404 if host not found" do
      get_test "/hosts/foo.json"do
        data "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => []
      end
    end

    it "returns indicated host" do
      get_test "/hosts/foo.json"do
        result "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                   [ { "name" => "dummy1", "address" => "127.0.0.1" } ]
      end
    end
  end

  describe "/hosts/:name/acknowledgement" do
    it "responds to PUT" do
      put_test "/hosts/foo/acknowledgement" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to PUT with author query param" do
      put_test "/hosts/foo/acknowledgement?author=Bob" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "Bob", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to PUT with comment query param" do
      put_test "/hosts/foo/acknowledgement?comment=Test" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "Test", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to PUT with notify query param set to true" do
      put_test "/hosts/foo/acknowledgement?notify=true" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to PUT with notify query param set to false" do
      put_test "/hosts/foo/acknowledgement?notify=false" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 0, :persistent => 1, :sticky => 1
      end
    end

    it "responds to PUT with persistent param set to true" do
      put_test "/hosts/foo/acknowledgement?persistent=true" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to PUT with persistent param set to false" do
      put_test "/hosts/foo/acknowledgement?persistent=false" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 0, :sticky => 1
      end
    end

    it "responds to PUT with sticky param set to true" do
      put_test "/hosts/foo/acknowledgement?sticky=true" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
      end
    end

    it "responds to PUT with sticky param set to false" do
      put_test "/hosts/foo/acknowledgement?sticky=false" do
        command :ACKNOWLEDGE_HOST_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 0
      end
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/acknowledgement" do
        command :REMOVE_HOST_ACKNOWLEDGEMENT,
                :host_name => "foo"
      end
    end
  end

  describe "/hosts/:name/checks" do
    it "responds to PUT" do
      put_test "/hosts/foo/checks" do
        command :ENABLE_HOST_CHECK,
                :host_name => "foo"
      end
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/checks" do
        command :DISABLE_HOST_CHECK,
                :host_name => "foo"
      end
    end
  end

  describe "/hosts/:name/notifications" do
    it "responds to PUT" do
      put_test "/hosts/foo/notifications" do
        command :ENABLE_HOST_NOTIFICATIONS,
                :host_name => "foo"
      end
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/notifications" do
        command :DISABLE_HOST_NOTIFICATIONS,
                :host_name => "foo"
      end
    end
  end

  describe "/hosts/:name/services" do
    it "returns 404 if host not found" do
      get_test "/hosts/foo/services.json" do
        data "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => []
      end
    end

    it "returns services of indicated host" do
      get_test "/hosts/foo/services.json"do
        data "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                 [ { "name" => "foo" } ]
        result "SELECT * FROM services WHERE host_name = 'foo'" => 
                   [ { "description" => "dummy1", "groups" => "test", "host_name" => "foo" },
                     { "description" => "dummy2", "groups" => "test", "host_name" => "foo" } ]
      end
    end
  end

  describe "/hosts/:name/services/checks" do
    it "responds to PUT" do
      put_test "/hosts/foo/services/checks" do
        command :ENABLE_HOST_SVC_CHECKS,
                :host_name => "foo"
      end
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/services/checks" do
        command :DISABLE_HOST_SVC_CHECKS,
                :host_name => "foo"
      end
    end
  end

  describe "/hosts/:name/services/notifications" do
    it "responds to PUT" do
      put_test "/hosts/foo/services/notifications" do
        command :ENABLE_HOST_SVC_NOTIFICATIONS,
                :host_name => "foo"
      end
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/services/notifications" do
        command :DISABLE_HOST_SVC_NOTIFICATIONS,
                :host_name => "foo"
      end
    end
  end

  describe "/hosts/:name/services/:service" do
    it "returns 404 if host not found" do
      get_test "/hosts/foo/services/bar.json" do
        data "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => []
      end
    end

    it "returns 404 if service not found" do
      get_test "/hosts/foo/services/bar.json" do
        data "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                 [ { "name" => "foo" } ],
             "SELECT * FROM services WHERE host_name = 'foo' AND description = 'bar'" => 
                 [ ]
      end
    end

    it "returns named service of indicated host" do
      get_test "/hosts/foo/services/bar.json"do
        data "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                 [ { "name" => "foo" } ]
        result "SELECT * FROM services WHERE host_name = 'foo' AND description = 'bar'" => 
                   [ { "description" => "bar", "groups" => "test", "host_name" => "foo" } ]
      end
    end
  end

  describe "/hosts/:name/services/:service/acknowledgement" do
    it "responds to PUT" do
      put_test "/hosts/foo/services/bar/acknowledgement" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with author query param" do
      put_test "/hosts/foo/services/bar/acknowledgement?author=Bob" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "Bob", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with comment query param" do
      put_test "/hosts/foo/services/bar/acknowledgement?comment=Test" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "Test", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with notify query param set to true" do
      put_test "/hosts/foo/services/bar/acknowledgement?notify=true" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with notify query param set to false" do
      put_test "/hosts/foo/services/bar/acknowledgement?notify=false" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 0, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with persistent param set to true" do
      put_test "/hosts/foo/services/bar/acknowledgement?persistent=true" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with persistent param set to false" do
      put_test "/hosts/foo/services/bar/acknowledgement?persistent=false" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 0, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with sticky param set to true" do
      put_test "/hosts/foo/services/bar/acknowledgement?sticky=true" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
      end
    end

    it "responds to PUT with sticky param set to false" do
      put_test "/hosts/foo/services/bar/acknowledgement?sticky=false" do
        command :ACKNOWLEDGE_SVC_PROBLEM,
                :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 0
      end
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/services/bar/acknowledgement" do
        command :REMOVE_SVC_ACKNOWLEDGEMENT,
                :host_name => "foo", :service_description => "bar"
      end
    end
  end

  describe "/hosts/:name/services/:service/notifications" do
    it "responds to PUT" do
      put_test "/hosts/foo/services/bar/notifications" do
        command :ENABLE_SVC_NOTIFICATIONS,
                :host_name => "foo", :service_description => "bar"
      end
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/services/bar/notifications" do
        command :DISABLE_SVC_NOTIFICATIONS,
                :host_name => "foo", :service_description => "bar"
      end
    end
  end
end
