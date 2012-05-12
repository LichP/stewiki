#!/usr/bin/env ruby

require 'redcarpet'
require 'grit'
require 'json'
require 'shield'

module Stewiki
  @renderers = {}
  @repo_path_default = File.join(ENV['HOME'], ".stewiki/wikidata.git")
  
  def self.repo_path
    @repo_path_default
  end
  
  def self.repo
    @repo ||= Grit::Repo.new(repo_path)
  end
  
  def self.default_actor(user = self.repo.config['user.name'], email = self.repo.config['user.email'])
    Grit::Actor.new(user, email)
  end
  
  def self.renderer(renderer_sym)
    @renderers[renderer_sym] ||= case renderer_sym
      when :html
        Redcarpet::Markdown.new(RenderHTMLWithWikiLinks, :fenced_code_blocks => true)
    end
  end
  
  class User < Grit::Actor
    attr_accessor :crypted_password
    include Shield::Model
    
    class << self
      def fetch(email)
        user_blob = Stewiki.repo.tree/("users/#{email}")
        if user_blob
          blob_data = JSON.parse(user_blob.data)
          self.new(*blob_data)
        else
          nil
        end
      end
      
      alias_method :'[]', :fetch
    end
    
    def initialize(name, email, crypted_password = "")
      super(name, email)
      @crypted_password = crypted_password
    end
    
    alias_method :id, :email
    
    def save
      index = Stewiki.repo.index
      index.read_tree('master')
      index.add("users/#{self.email}", self.to_json)
      index.commit("Update user: #{self.email}", [Stewiki.repo.commits.first], self, nil, 'master')
    end
    
    def to_json
      [self.name, self.email, self.crypted_password].to_json
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
