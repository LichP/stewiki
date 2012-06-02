$:.unshift File.expand_path('../../lib', File.dirname(__FILE__))
require 'stewiki/server'
require 'cutest'
require 'rack/test'

class Cutest::Scope
  include Rack::Test::Methods
  
  def app
    Stewiki::Server.new
  end
end
