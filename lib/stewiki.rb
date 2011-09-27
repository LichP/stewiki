#!/usr/bin/env ruby

require 'redcarpet'
require 'git'
require 'vfs'

module Stewiki
  @@renderers = {}
  @@git = nil
  #@@path = "~/.stewiki"
  @@path = "/home/pstewart/.stewiki".to_dir
  
  def self.path
    @@path
  end
  
  def self.repo_path
    @@path['wikidata']
  end
  
  def self.git
    @@git ||= Git.open(repo_path.path)
  end
  
  def self.content(page_name)
    Page[page_name].content
  end

  def self.render(page_name, opts)
    ## REFACTOR: Migrate this to an instance method in Page and remove this wrapping interface
    Page[page_name].render_with(renderer(opts[:renderer]))
  end
  
  def self.update(page_name, new_content, commit_message)
    Page[page_name].update(new_content, commit_message)
  end
  
  def self.renderer(renderer_sym)
    @@renderers[renderer_sym] ||= case renderer_sym
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
    
    def content
      if page_file.exist?
        page_file.read
      else
        "# #{name}\nThis page does not exist yet."
      end
    end
    
    def render_with(renderer)
      renderer.render(content)
    end
    
    def update(new_content, commit_message = default_commit_message)
      page_file.write(new_content)
      Stewiki.git.add(page_file.path)
      Stewiki.git.commit(commit_message)
    end
    
    def page_file      
      Stewiki.repo_path["pages/#{name[0].upcase}/#{name}"]
    end
    
    def log
      Stewiki.git.log.object(page_file.path)
    end
    
    def last_commit
      log.first
    end
    
    def last_modified
      log.first.date
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
