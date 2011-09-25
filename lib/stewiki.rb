#!/usr/bin/env ruby

require 'redcarpet'

module Stewiki
  @@renderers = {}
  
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
        Redcarpet::Markdown.new(Redcarpet::Render::HTML, :fenced_code_blocks => true)
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
        File.read("/home/pstewart/.stewiki/wikidata/pages/#{name[0].upcase}/#{name}")
      rescue IOError, error
        "Content not available: #{error.message}"
      end
    end
    
    def render_with(renderer)
      renderer.render(content)
    end
    
    def update(new_content)
      File.open("/home/pstewart/.stewiki/wikidata/pages/#{name[0].upcase}/#{name}", "w") do |page_file|
        page_file.write(new_content)
      end
    end
  end
end
