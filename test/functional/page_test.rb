require File.expand_path("../helpers/functional", File.dirname(__FILE__))

scope do
  test "should get home page of wiki" do
    get "/page/Home"
    assert last_response.ok?
    assert last_response.body =~ /<h1>Home<\/h1>/
  end
  
  test "should get none existant page" do
    get "/page/NonExtantPage"
    assert last_response.ok?
    assert last_response.body =~ /This page does not exist yet./
  end
end
