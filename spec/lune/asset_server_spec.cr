require "../spec_helper"
require "http/client"

private def http_get(url : String) : HTTP::Client::Response
  uri = URI.parse(url)
  client = HTTP::Client.new(uri)
  client.connect_timeout = 5.seconds
  client.read_timeout = 5.seconds
  client.get(uri.request_target)
end

describe Lune::AssetServer do
  it "url returns an http://127.0.0.1 address on a non-zero port" do
    server = Lune::AssetServer.new
    server.url.should match(/\Ahttp:\/\/127\.0\.0\.1:\d+\z/)
    server.port.should be > 0
  end

  it "each instance binds its own port" do
    a = Lune::AssetServer.new
    b = Lune::AssetServer.new
    a.port.should_not eq(b.port)
  end

  it "serves /index.html from embedded assets" do
    server = Lune::AssetServer.new
    server.start
    begin
      response = http_get("#{server.url}/index.html")
      response.status_code.should eq(200)
      response.body.should eq("fixture index\n")
    ensure
      server.stop
    end
  end

  it "normalises / to /index.html" do
    server = Lune::AssetServer.new
    server.start
    begin
      response = http_get(server.url)
      response.status_code.should eq(200)
      response.body.should eq("fixture index\n")
    ensure
      server.stop
    end
  end

  it "serves nested assets" do
    server = Lune::AssetServer.new
    server.start
    begin
      response = http_get("#{server.url}/nested/info.txt")
      response.status_code.should eq(200)
      response.body.should eq("nested fixture\n")
    ensure
      server.stop
    end
  end

  it "returns 404 for unknown paths" do
    server = Lune::AssetServer.new
    server.start
    begin
      response = http_get("#{server.url}/no-such-file.html")
      response.status_code.should eq(404)
    ensure
      server.stop
    end
  end

  it "sets Content-Type for html files" do
    server = Lune::AssetServer.new
    server.start
    begin
      response = http_get("#{server.url}/index.html")
      response.headers["Content-Type"]?.should eq("text/html; charset=utf-8")
    ensure
      server.stop
    end
  end
end
