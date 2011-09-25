#!/usr/bin/env ruby

require 'redcarpet'

module Stewiki
  @@renderers = {}

  def self.render(page_name, opts)
    Page.new(page_name).render_with(renderer(opts[:renderer]))
  end
  
  def self.renderer(renderer_sym)
    @@renderers[renderer_sym] ||= case renderer_sym
      when :html
        Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    end
  end
  
  class Page
    attr_reader :name
  
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
  end
end
