require File.dirname(__FILE__) + '/../stewiki'
require 'sinatra/base'

class Stewiki::Server < Sinatra::Base

  set :root, File.dirname(__FILE__)  + '/server'

  helpers do
  end

  get "/" do
    redirect to('/page/Home')
  end

  get "/page/:pagename/?:commit?" do
    @title = params[:pagename]
    @page = Stewiki::Page[params[:pagename]]
    @quicklinks = Stewiki::Page["QuickLinks"]
    @page.version = params[:commit] if params[:commit]
    haml :display
  end

  get "/edit/:pagename" do
    @title = "Editing: " + params[:pagename]
    @page = Stewiki::Page[params[:pagename]]
    @quicklinks = Stewiki::Page["QuickLinks"]
    haml :edit
  end

  post "/edit/:pagename" do
    Stewiki::Page[params[:pagename]].update(params[:content], params[:commit_message])
    redirect to("/page/" + params[:pagename])
  end

  get "/history/:pagename" do
    @title = "History: " + params[:pagename]
    @page = Stewiki::Page[params[:pagename]]
    @quicklinks = Stewiki::Page["QuickLinks"]
    haml :history
  end
end
