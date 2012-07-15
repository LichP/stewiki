require File.dirname(__FILE__) + '/../stewiki'
require 'sinatra/base'
require 'haml'
require 'rack-flash'

class Stewiki::Server < Sinatra::Base
  use Rack::Session::Cookie
  use Rack::Flash
  use Shield::Middleware, "/login"

  set :root, File.dirname(__FILE__)  + '/server'
  set :show_exceptions, :after_handler

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
    
    def ensure_can_set_superuser(message = nil)
      if params[:superuser] && !user.is_superuser?
        flash[:error] = message || "You do not have permission to set superuser credentials."
        yield if block_given?
      end
    end
    
    def user_error_text
      {
        not_present:  "is required",
        not_email:    "must be an email address",
        not_matching: "does not match"
      }
    end
    
    def prettify(sym)
      sym.to_s.split("_").collect { |word| word.capitalize }.join(" ")
    end
    
    def quicklinks
      Stewiki::Page["QuickLinks"]
    end
  end
  
  # Error handling
  error Grit::NoSuchPathError do
    redirect to('/firstrun')
  end
  
  error Grit::InvalidGitRepositoryError do
    haml :invalid_repo, layout: false
  end

  # Root
  get "/" do
    redirect to('/page/Home')
  end
  
  # First run routes
  get "/firstrun" do
     begin
       Stewiki.repo
     rescue Grit::NoSuchPathError
       return haml :first_run, layout: false
     end
     flash[:error] = "Not performing First Run on already initialized repository."
     redirect to('/')
  end
  
  post "/firstrun" do
     begin
       Stewiki.repo
     rescue Grit::NoSuchPathError
       # Process form
       new_user = Stewiki::NewUser.new(params)
       unless new_user.valid?
         error_markup = "<ul>"
         new_user.errors.each_pair do |field, errors|
           errors.each do |error|
             error_markup << "<li>#{prettify(field)} #{user_error_text[error]}</li>"
           end
         end
         error_markup << "</ul>"
         flash.now[:error] = error_markup
         return haml :first_run, layout: false
       end

       # Create repo
       Stewiki.init_repo
       
       # Save user
       new_user.credentials = ['edit', 'admin', 'superuser']
       saved_user = new_user.save_as_stewiki_user(actor: Stewiki.first_run_actor)
       
       # Login, redirect to edit of home page
       login(Stewiki::User, new_user.email, new_user.password)
       redirect to('/edit/Home')
     end
     flash[:error] = "Not performing First Run on already initialized repository."
     redirect to('/')
  end
  
  # Login routes
  get "/login" do
    haml :login
      flash.now[:error] = error_markup
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

    ensure_can_set_superuser do
      redirect to('/user/credentials/' + params[:email])
    end
    
    user_to_edit.credentials = params[:credentials]
    user_to_edit.save(actor: user)    
    
    flash[:info] = "Successfully updated credentials of #{user_to_edit.name}."
    redirect to('/users')
  end
  
  get "/user/add" do
    ensure_is_admin("You do not have permission to add new Users.")
    
    haml :user_add
  end

  post "/user/add" do
    ensure_is_admin("You do not have permission to add new Users.")

    ensure_can_set_superuser do
      return haml :user_add
    end    
    
    new_user = Stewiki::NewUser.new(params)

    if new_user.valid?
      new_user.save_as_stewiki_user(actor: user)
      flash[:info] = "Successfully created user #{new_user.name}"
      redirect to("/users")
    else
      error_markup = "<ul>"
      new_user.errors.each_pair do |field, errors|
        errors.each do |error|
          error_markup << "<li>#{prettify(field)} #{user_error_text[error]}</li>"
        end
      end
      error_markup << "</ul>"

      flash.now[:error] = error_markup
      haml :user_add
    end
  end
  
end
