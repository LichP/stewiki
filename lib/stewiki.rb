#!/usr/bin/env ruby

require 'redcarpet'
require 'grit'
require 'vfs'

module Stewiki
  @renderers = {}
  @git = nil
  #@path = "~/.stewiki"
  @path = "/home/pstewart/.stewiki".to_dir
  
  def self.path
    @path
  end
  
  def self.repo_path
    @path['wikidata']
  end
  
  def self.repo
    @repo ||= Grit::Repo.new(repo_path.path)
  end
  
  def self.actor
    Grit::Actor.new('Phil Stewart', 'phil.stewart@lichp.co.uk')
  end
  
  def self.renderer(renderer_sym)
    @renderers[renderer_sym] ||= case renderer_sym
      when :html
        Redcarpet::Markdown.new(RenderHTMLWithWikiLinks, :fenced_code_blocks => true)
    end
  end
  
  class Page
    attr_reader :name
  
    def self.get(attrs)
      new(attrs)
    end
    
    def self.[](name)
      get(name)
    end

    def initialize(name)
      @name = name
    end
    
    def blob
      Stewiki.repo.tree/(page_file)
    end
    
    def content
      blob ? blob.data : "This page does not exist yet."
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
    
    def update(new_content, commit_message = default_commit_message)
      index = Stewiki.repo.index
      index.read_tree('master')
      index.add(page_file, new_content)
      index.commit(commit_message, [Stewiki.repo.commits.first], Stewiki.actor, nil, 'master')
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
