require File.dirname(__FILE__) + '/../stewiki'
require 'sinatra/base'
require 'haml'
require 'rack-flash'

class Stewiki::Server < Sinatra::Base
  use Rack::Session::Cookie
  use Rack::Flash
  use Shield::Middleware, "/login"

  set :root, File.dirname(__FILE__)  + '/server'

  helpers Shield::Helpers
  
  helpers do
    def user
      authenticated(Stewiki::User)
    end
  
    def ensure_can_edit(pagename)
      error(401) unless user
      unless user.can_edit?
        flash[:error] = "You do not have permission to edit this page."
        redirect to("/page/#{pagename}")
      end
    end
    
    def ensure_is_admin(message = nil)
      error(401) unless user
      unless user.is_admin?
        flash[:error] = message || "You do not have permission to access the requested feature."
        redirect to('/')
      end
    end
  
    def quicklinks
      Stewiki::Page["QuickLinks"]
    end
  end
  
  get "/" do
    redirect to('/page/Home')
  end
  
  # Login routes
  get "/login" do
    haml :login
  end

  post "/login" do
    if login(Stewiki::User, params[:login], params[:password], params[:remember_me])
      redirect to(params[:return] || "/")
    else
      redirect to("/login")
    end
  end
  
  get "/logout" do
    logout(Stewiki::User)
    redirect to("/")
  end

  # Page routes
  get "/page/:pagename/?:commit?" do
    @title = params[:pagename]
    @page = Stewiki::Page[params[:pagename]]
    @page.version = params[:commit] if params[:commit]

    haml :display
  end

  get "/edit/:pagename" do
    ensure_can_edit(params[:pagename])

    @title = "Editing: " + params[:pagename]
    @page = Stewiki::Page[params[:pagename]]

    haml :edit
  end

  post "/edit/:pagename" do
    ensure_can_edit(params[:pagename])

    Stewiki::Page[params[:pagename]].update(params[:content], params[:commit_message], user)

    redirect to("/page/" + params[:pagename])
  end

  get "/history/:pagename" do
    @title = "History: " + params[:pagename]
    @page = Stewiki::Page[params[:pagename]]

    haml :history
  end
  
  # User maintenance routes
  get "/users" do
    ensure_is_admin('You do not have permission to view Users.')
    @users = Stewiki::User.all
    
    haml :users
  end
  
  helpers do
    def edit_credentials_checks(user_to_edit)
      if !user_to_edit
        flash[:error] = "User #{params[:email]} does not exist"
        redirect to('/users')
      end
    
      if user_to_edit.is_superuser? && !user.is_superuser?
        flash[:error] = "You do not have permission to edit credentials of superuser #{user_to_edit.name}"
        redirect to('/users')
      end    
    end
  end
  
  get "/user/credentials/:email" do
    ensure_is_admin('You do not have permission to edit User credentials.')
    @user_to_edit = Stewiki::User[params[:email]]
    edit_credentials_checks(@user_to_edit)
    
    haml :user_credentials
  end
  
  post "/user/credentials/:email" do
    ensure_is_admin('You do not have permission to edit User credentials.')
    user_to_edit = Stewiki::User[params[:email]]
    edit_credentials_checks(user_to_edit)

    if params[:superuser] && !user.is_superuser?
        flash[:error] = "You do not have permission to set superuser credentials."
        redirect to('/user/credentials/' + params[:email])
    end
    
    new_credentials = []
    new_credentials << 'edit'      if params[:edit]
    new_credentials << 'admin'     if params[:admin]
    new_credentials << 'superuser' if params[:superuser]
    
    user_to_edit.credentials = new_credentials
    user_to_edit.save(:actor => user)    
    
    flash[:info] = "Successfully updated credentials of #{user_to_edit}."
    redirect to('/users')
  end
end
