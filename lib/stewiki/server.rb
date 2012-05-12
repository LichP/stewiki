require File.dirname(__FILE__) + '/../stewiki'
require 'sinatra/base'

class Stewiki::Server < Sinatra::Base
  use Rack::Session::Cookie
  use Shield::Middleware, "/login"

  set :root, File.dirname(__FILE__)  + '/server'

  helpers Shield::Helpers
  
  get "/" do
    redirect to('/page/Home')
  end
  
  get "/login" do
    haml :login, :layout => false
  end

  post "/login" do
    if login(Stewiki::User, params[:login], params[:password], params[:remember_me])
      redirect(params[:return] || "/")
    else
      redirect "/login"
    end
  end
  
  get "/logout" do
    logout(Stewiki::User)
    redirect "/"
  end
              
  get "/page/:pagename/?:commit?" do
    @user = authenticated(Stewiki::User)
    @title = params[:pagename]
    @page = Stewiki::Page[params[:pagename]]
    @quicklinks = Stewiki::Page["QuickLinks"]
    @page.version = params[:commit] if params[:commit]

    haml :display
  end

  get "/edit/:pagename" do
    @user = authenticated(Stewiki::User)
    error(401) unless @user

    @title = "Editing: " + params[:pagename]
    @page = Stewiki::Page[params[:pagename]]
    @quicklinks = Stewiki::Page["QuickLinks"]

    haml :edit
  end

  post "/edit/:pagename" do
    user = authenticated(Stewiki::User)
    error(401) unless user

    Stewiki::Page[params[:pagename]].update(params[:content], params[:commit_message], user)

    redirect to("/page/" + params[:pagename])
  end

  get "/history/:pagename" do
    @user = authenticated(Stewiki::User)
    @title = "History: " + params[:pagename]
    @page = Stewiki::Page[params[:pagename]]
    @quicklinks = Stewiki::Page["QuickLinks"]

    haml :history
  end
end
