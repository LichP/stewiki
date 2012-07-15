#!/usr/bin/env ruby

require 'redcarpet'
require 'grit'
require 'json'
require 'shield'
require 'scrivener'

module Stewiki
  @renderers = {}
  @repo_path_default = File.join(ENV['HOME'], ".stewiki/wikidata.git")
  
  def self.repo_path
    @repo_path ||= @repo_path_default
  end
  
  def self.repo_path=(new_path)
    @repo_path = new_path
  end
  
  def self.repo
    @repo ||= Grit::Repo.new(repo_path)
  end
  
  def self.init_repo
    # Ensure the repo path is not otherwise engaged
    raise "Cannot init repo: File/directory already exists at #{self.repo_path}" if File.exist?(repo_path)
    
    # If the path ends in .git, initialise bare, otherwise initialise with working tree
    warn repo_path
    warn File.extname(repo_path)
    if File.extname(repo_path) == '.git'
      Grit::Repo.init_bare(repo_path)
    else
      Grit::Repo.init(repo_path)
    end
    
    # Do initial setup
    index = repo.index
    index.add("init", Time.now.to_s)
    index.commit("Initialize Stewiki Repo", nil, first_run_actor, nil, 'master')
    
    # Return the repo
    repo
  end
  
  def self.default_actor(user = self.repo.config['user.name'], email = self.repo.config['user.email'])
    Grit::Actor.new(user, email)
  end
  
  def self.first_run_actor
    Grit::Actor.new("Stewiki First Run", "stewiki@localhost")
  end
  
  def self.renderer(renderer_sym)
    @renderers[renderer_sym] ||= case renderer_sym
      when :html
        Redcarpet::Markdown.new(RenderHTMLWithWikiLinks, :fenced_code_blocks => true)
    end
  end
  
  class User < Grit::Actor
    include Shield::Model
    
    attr_accessor :crypted_password, :credentials

    class << self
      def fetch(email)
        user_blob = Stewiki.repo.tree/("users/#{email}")
        user_blob ? self.new_from_blob(user_blob) : nil
      end
      
      alias_method :'[]', :fetch
      
      def new_from_blob(blob)
        blob_data = JSON.parse(blob.data)
        self.new(*blob_data)
      end
      
      def all
        user_tree = Stewiki.repo.tree./("users").contents
        user_tree.reject! { |child| !child.kind_of?(Grit::Blob) }
        user_tree.collect { |blob| self.new_from_blob(blob) }
      end
    end
    
    def initialize(name, email, crypted_password = "", credentials = ['edit'])
      super(name, email)
      @crypted_password = crypted_password
      @credentials = credentials
    end
    
    alias_method :id, :email
    
    def credentials=(*tokens)
      @credentials = tokens.flatten & ['edit', 'admin', 'superuser']
    end

    def can_edit?
      self.credentials.include?('edit')
    end
    
    def is_admin?
      self.credentials.include?('admin') || self.is_superuser?
    end
    
    def is_superuser?
      self.credentials.include?('superuser')
    end
    
    def short_credentials
      result = ""
      result << 'E' if self.can_edit?
      result << 'A' if self.is_admin?
      result << 'S' if self.is_superuser?
      result
    end
    
    def save(opts = {})
      commit_actor = opts[:actor] || self
      index = Stewiki.repo.index
      index.read_tree('master')
      index.add("users/#{self.email}", self.to_json)
      index.commit("Update user: #{self.email}", [Stewiki.repo.commits.first], commit_actor, nil, 'master')
    end
    
    def to_json
      [self.name, self.email, self.crypted_password, self.credentials].to_json
    end

    def inspect
      %Q{#<Stewiki::User "#{@name} <#{@email}>">}
    end
  end
  
  class NewUser < Scrivener
    attr_accessor :name
    attr_accessor :email
    attr_accessor :password
    attr_accessor :confirm_password
    attr_accessor :credentials
  
    def validate
      assert_present :name
      assert_present :email
      assert_email   :email
      assert_present :password
      assert password == confirm_password, [:confirm_password, :not_matching]
    end
    
    def save_as_stewiki_user(opts = {})
      return unless self.valid?
      new_user = Stewiki::User.new(self.name, self.email)
      new_user.password = self.password
      new_user.credentials = self.credentials
      new_user.save(opts)
      new_user
    end
  end
  
  class Page
    attr_reader   :name
    attr_accessor :version
  
    def self.get(attrs)
      new(attrs)
    end
    
    def self.[](name)
      get(name)
    end

    def initialize(name, version = :current)
      @name = name
      @version = version
    end
    
    def current?
      version == :current
    end
    
    def blob
      if current?
        Stewiki.repo.tree/(page_file)
      else
        commit = Stewiki.repo.commits(version).first
        commit ? commit.tree/(page_file) : nil
      end
    end
    
    def content
      if blob
        blob.data
      else
        if current?
          "This page does not exist yet."
        else
          "This page not found in commit #{version}."
        end
      end
    end
    
    def titled?
      content =~ /^#/
    end
    
    def render(opts = {})
      render_with(Stewiki.renderer(opts[:renderer] || :html))
    end
    
    def render_with(renderer)
      renderer.render(content)
    end
    
    def update(new_content, commit_message = default_commit_message, user = Stewiki.default_actor)
      index = Stewiki.repo.index
      index.read_tree('master')
      index.add(page_file, new_content)
      index.commit(commit_message, [Stewiki.repo.commits.first], user, nil, 'master')
    end
    
    def page_file
      "pages/#{name[0].upcase}/#{name}"
    end
    
    def commits
      Stewiki.repo.log('master', page_file)
    end
    
    def last_modified
      commits.length > 0 ? commits.first.authored_date : "Never"
    end
    
    def last_commit_abbrev
      commits.length > 0 ? commits.first.id_abbrev : "N/A"
    end
    
    def selected_version_commit
      if current?
        commits.first
      else
        Stewiki.repo.commits(version).first
      end
    end
    
    def selected_version_id_abbrev
      selected_version_commit ? selected_version_commit.id_abbrev : "N/A"
    end
    
    def selected_version_authored_date
      selected_version_commit ? selected_version_commit.authored_date : "Unknown"
    end
    
    def selected_version_author
      selected_version_commit ? selected_version_commit.author.name : "Unknown"
    end
    
    def default_commit_message
      "Page edit of #{name}"
    end
  end
  
  class RenderHTMLWithWikiLinks < Redcarpet::Render::HTML
    def postprocess(document)
      document.gsub(/\[(\w+)\]/m, '<a href="/page/\1">\1</a>')
    end
  end
end
