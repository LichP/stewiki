#!/usr/bin/env ruby

require 'redcarpet'
require 'git'
require 'vfs'

module Stewiki
  @@renderers = {}
  @@git = nil
  #@@path = "~/.stewiki"
  @@path = "/home/pstewart/.stewiki"
  ## GOT TO HERE: Need to start using VFS and implement mkdir -p on Page#update
  
  def self.path
    @@path
  end
  
  def self.repo_path
    @@path + "/wikidata"
  end
  
  def self.git
    @@git ||= Git.open(repo_path)
  end
  
  def self.content(page_name)
    Page[page_name].content
  end

  def self.render(page_name, opts)
    Page[page_name].render_with(renderer(opts[:renderer]))
  end
  
  def self.update(page_name, new_content)
    Page[page_name].update(new_content)
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
      begin
        File.read(page_path)
      rescue Errno::ENOENT
        "# #{name}\nThis page does not exist yet."
      rescue IOError => error
        "Content not available: #{error.message}"
      end
    end
    
    def render_with(renderer)
      renderer.render(content)
    end
    
    def update(new_content)
      File.open(page_path, "w") do |page_file|
        page_file.write(new_content)
      end
      Stewiki.git.add(page_path)
      Stewiki.git.commit("Page edit of #{name}")
    end
    
    def page_path
      
      Stewiki.repo_path + "/pages/" + name[0].upcase + "/" + name
    end
  end
  
  class RenderHTMLWithWikiLinks < Redcarpet::Render::HTML
    def postprocess(document)
      document.gsub(/\[(\w+)\]/m, '<a href="/page/\1">\1</a>')
    end
  end
end
