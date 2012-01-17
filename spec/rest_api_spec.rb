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

  def app
    Nagix::RestApi
  end

  def get_test(uri, result_key, data)
    lql = flexmock()
    expected_value = nil
    data.each do |key, value|
      expected_value = value if key == result_key
      lql.should_receive(:query).with(key).and_return(value)
    end
    Nagix::RestApi.set :create_lql, Proc.new { lql }

    get uri

    if result_key.nil?
      last_response.should be_not_found
    else
      last_response.should be_ok
      body = JSON.parse(last_response.body)
      body.should be_a_kind_of(Array)
      body.length.should be(expected_value.length)
      expected_value.each do |item|
        body.should include(item)
      end
    end
  end

  def put_test(uri, cmd, params = {})
    lql = flexmock()
    lql.should_receive(:execute).with(cmd, params).once
    Nagix::RestApi.set :create_lql, Proc.new { lql }

    put uri
    last_response.should be_ok
    last_response.body.should eq('')
  end

  def delete_test(uri, cmd, params = {})
    lql = flexmock()
    lql.should_receive(:execute).with(cmd, params).once
    Nagix::RestApi.set :create_lql, Proc.new { lql }

    delete uri
    last_response.should be_ok
    last_response.body.should eq('')
  end

  describe "/eventHandlers" do
    it "responds to PUT" do
      put_test "/eventHandlers", :ENABLE_EVENT_HANDLERS
    end

    it "responds to DELETE" do
      delete_test "/eventHandlers", :DISABLE_EVENT_HANDLERS
    end
  end

  describe "/notifications" do
    it "responds to PUT" do
      put_test "/notifications", :ENABLE_NOTIFICATIONS
    end

    it "responds to DELETE" do
      delete_test "/notifications", :DISABLE_NOTIFICATIONS
    end
  end

  describe "/services" do
    it "returns no services if none are configured" do
      get_test "/services.json",
               "SELECT * FROM services",
               "SELECT * FROM services" => []
    end

    it "returns all configured services" do
      get_test "/services.json",
               "SELECT * FROM services",
               "SELECT * FROM services" =>
                   [ { "description" => "dummy1", "groups" => "test", "host_name" => "foo" },
                     { "description" => "dummy2", "groups" => "test", "host_name" => "bar" } ]
    end
  end

  describe "/serviceGroups/:name" do
    it "returns 404 if service group not found" do
      get_test "/serviceGroups/foo.json",
               nil,
               "SELECT * FROM servicegroups WHERE name = 'foo' OR alias = 'foo'" => []
    end

    it "returns indicated service group" do
      get_test "/serviceGroups/foo.json",
               "SELECT * FROM servicegroups WHERE name = 'foo' OR alias = 'foo'",
               "SELECT * FROM servicegroups WHERE name = 'foo' OR alias = 'foo'" => 
                   [ { "name" => "foo", "num_services" => 1 } ]
    end
  end

  describe "/serviceGroups/:name/services" do
    it "returns 404 if service group not found" do
      get_test "/serviceGroups/foo/services.json",
               nil,
               "SELECT * FROM servicegroups WHERE name = 'foo' OR alias = 'foo'" => []
    end

    it "returns all configured service groups" do
      get_test "/serviceGroups/test/services.json",
               "SELECT * FROM services WHERE groups contains 'test'",
               "SELECT * FROM servicegroups WHERE name = 'test' OR alias = 'test'" =>
                   [ { "name" => "test", "num_services" => 2 } ],
               "SELECT * FROM services WHERE groups contains 'test'" => 
                   [ { "description" => "dummy1", "groups" => "test", "host_name" => "foo" },
                     { "description" => "dummy2", "groups" => "test", "host_name" => "bar" } ]
    end
  end

  describe "/serviceGroups/:name/checks" do
    it "responds to PUT" do
      put_test "/serviceGroups/foo/checks", :ENABLE_SERVICEGROUP_SVC_CHECKS,
               :servicegroup => "foo"
    end

    it "responds to DELETE" do
      delete_test "/serviceGroups/foo/checks", :DISABLE_SERVICEGROUP_SVC_CHECKS,
                  :servicegroup => "foo"
    end
  end

  describe "/serviceGroups/:name/notifications" do
    it "responds to PUT" do
      put_test "/serviceGroups/foo/notifications", :ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
               :servicegroup => "foo"
    end

    it "responds to DELETE" do
      delete_test "/serviceGroups/foo/notifications", :DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS,
                  :servicegroup => "foo"
    end
  end

  describe "/hosts" do
    it "returns no hosts if none are configured" do
      get_test "/hosts.json",
               "SELECT * FROM hosts",
               "SELECT * FROM hosts" => []
    end

    it "returns all configured hosts" do
      get_test "/hosts.json",
               "SELECT * FROM hosts",
               "SELECT * FROM hosts" => 
                   [ { "name" => "dummy1", "address" => "127.0.0.1" },
                     { "name" => "dummy2", "address" => "127.0.0.2" } ]
    end
  end

  describe "/hosts/:name" do
    it "returns 404 if host not found" do
      get_test "/hosts/foo.json",
               nil,
               "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => []
    end

    it "returns indicated host" do
      get_test "/hosts/foo.json",
               "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'",
               "SELECT * FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                   [ { "name" => "dummy1", "address" => "127.0.0.1" } ]
    end
  end

  describe "/hosts/:name/acknowledgement" do
    it "responds to PUT" do
      put_test "/hosts/foo/acknowledgement", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
    end

    it "responds to PUT with author query param" do
      put_test "/hosts/foo/acknowledgement?author=Bob", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "Bob", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
    end

    it "responds to PUT with comment query param" do
      put_test "/hosts/foo/acknowledgement?comment=Test", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "", :comment => "Test", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
    end

    it "responds to PUT with notify query param set to true" do
      put_test "/hosts/foo/acknowledgement?notify=true", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
    end

    it "responds to PUT with notify query param set to false" do
      put_test "/hosts/foo/acknowledgement?notify=false", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 0, :persistent => 1, :sticky => 1
    end

    it "responds to PUT with persistent param set to true" do
      put_test "/hosts/foo/acknowledgement?persistent=true", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
    end

    it "responds to PUT with persistent param set to false" do
      put_test "/hosts/foo/acknowledgement?persistent=false", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 0, :sticky => 1
    end

    it "responds to PUT with sticky param set to true" do
      put_test "/hosts/foo/acknowledgement?sticky=true", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 1
    end

    it "responds to PUT with sticky param set to false" do
      put_test "/hosts/foo/acknowledgement?sticky=false", :ACKNOWLEDGE_HOST_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :sticky => 0
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/acknowledgement", :REMOVE_HOST_ACKNOWLEDGEMENT,
                  :host_name => "foo"
    end
  end

  describe "/hosts/:name/checks" do
    it "responds to PUT" do
      put_test "/hosts/foo/checks", :ENABLE_HOST_CHECK,
               :host_name => "foo"
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/checks", :DISABLE_HOST_CHECK,
                  :host_name => "foo"
    end
  end

  describe "/hosts/:name/notifications" do
    it "responds to PUT" do
      put_test "/hosts/foo/notifications", :ENABLE_HOST_NOTIFICATIONS,
               :host_name => "foo"
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/notifications", :DISABLE_HOST_NOTIFICATIONS,
                  :host_name => "foo"
    end
  end

  describe "/hosts/:name/services" do
    it "returns 404 if host not found" do
      get_test "/hosts/foo/services.json",
               nil,
               "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => []
    end

    it "returns services of indicated host" do
      get_test "/hosts/foo/services.json",
               "SELECT * FROM services WHERE host_name = 'foo'",
               "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                   [ { "name" => "foo", "address" => "127.0.0.1" } ],
               "SELECT * FROM services WHERE host_name = 'foo'" => 
                   [ { "description" => "dummy1", "groups" => "test", "host_name" => "foo" },
                     { "description" => "dummy2", "groups" => "test", "host_name" => "foo" } ]
    end
  end

  describe "/hosts/:name/services/checks" do
    it "responds to PUT" do
      put_test "/hosts/foo/services/checks", :ENABLE_HOST_SVC_CHECKS,
               :host_name => "foo"
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/services/checks", :DISABLE_HOST_SVC_CHECKS,
                  :host_name => "foo"
    end
  end

  describe "/hosts/:name/services/notifications" do
    it "responds to PUT" do
      put_test "/hosts/foo/services/notifications", :ENABLE_HOST_SVC_NOTIFICATIONS,
               :host_name => "foo"
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/services/notifications", :DISABLE_HOST_SVC_NOTIFICATIONS,
                  :host_name => "foo"
    end
  end

  describe "/hosts/:name/services/:service" do
    it "returns 404 if host not found" do
      get_test "/hosts/foo/services/bar.json",
               nil,
               "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => []
    end

    it "returns 404 if service not found" do
      get_test "/hosts/foo/services/bar.json",
               nil,
               "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                   [ { "name" => "foo", "address" => "127.0.0.1" } ],
               "SELECT * FROM services WHERE host_name = 'foo' AND description = 'bar'" => 
                   [ ]
    end

    it "returns named service of indicated host" do
      get_test "/hosts/foo/services/bar.json",
               "SELECT * FROM services WHERE host_name = 'foo' AND description = 'bar'",
               "SELECT name FROM hosts WHERE host_name = 'foo' OR alias = 'foo' OR address = 'foo'" => 
                   [ { "name" => "foo", "address" => "127.0.0.1" } ],
               "SELECT * FROM services WHERE host_name = 'foo' AND description = 'bar'" => 
                   [ { "description" => "bar", "groups" => "test", "host_name" => "foo" } ]
    end
  end

  describe "/hosts/:name/services/:service/acknowledgement" do
    it "responds to PUT" do
      put_test "/hosts/foo/services/bar/acknowledgement", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
    end

    it "responds to PUT with author query param" do
      put_test "/hosts/foo/services/bar/acknowledgement?author=Bob", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "Bob", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
    end

    it "responds to PUT with comment query param" do
      put_test "/hosts/foo/services/bar/acknowledgement?comment=Test", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "", :comment => "Test", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
    end

    it "responds to PUT with notify query param set to true" do
      put_test "/hosts/foo/services/bar/acknowledgement?notify=true", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
    end

    it "responds to PUT with notify query param set to false" do
      put_test "/hosts/foo/services/bar/acknowledgement?notify=false", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 0, :persistent => 1, :service_description => "bar", :sticky => 1
    end

    it "responds to PUT with persistent param set to true" do
      put_test "/hosts/foo/services/bar/acknowledgement?persistent=true", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
    end

    it "responds to PUT with persistent param set to false" do
      put_test "/hosts/foo/services/bar/acknowledgement?persistent=false", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 0, :service_description => "bar", :sticky => 1
    end

    it "responds to PUT with sticky param set to true" do
      put_test "/hosts/foo/services/bar/acknowledgement?sticky=true", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 1
    end

    it "responds to PUT with sticky param set to false" do
      put_test "/hosts/foo/services/bar/acknowledgement?sticky=false", :ACKNOWLEDGE_SVC_PROBLEM,
               :author => "", :comment => "", :host_name => "foo", :notify => 1, :persistent => 1, :service_description => "bar", :sticky => 0
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/services/bar/acknowledgement", :REMOVE_SVC_ACKNOWLEDGEMENT,
                  :host_name => "foo", :service_description => "bar"
    end
  end

  describe "/hosts/:name/services/:service/notifications" do
    it "responds to PUT" do
      put_test "/hosts/foo/services/bar/notifications", :ENABLE_SVC_NOTIFICATIONS,
               :host_name => "foo", :service_description => "bar"
    end

    it "responds to DELETE" do
      delete_test "/hosts/foo/services/bar/notifications", :DISABLE_SVC_NOTIFICATIONS,
                  :host_name => "foo", :service_description => "bar"
    end
  end
end
