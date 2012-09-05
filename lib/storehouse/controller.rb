module Storehouse
  module Controller

    STOREHOUSE_OPTIONS = [:expires_at, :expires_in, :storehouse]

    def self.extended(base)
      base.instance_eval do
        cattr_accessor :storehouse_page_cache_options
        cattr_accessor :storehouse_page_cache_action
      end
    end

    def caches_page(*actions)
      return unless perform_caching
      options = actions.extract_options!
      
      unless options.blank?
        self.storehouse_page_cache_options ||= {}
        actions.each do |action|
          self.storehouse_page_cache_options[action] = options.slice(*STOREHOUSE_OPTIONS)
        end
      end


      before_filter(:only => actions){|c| c.class.storehouse_page_cache_action = c.action_name.to_sym }
      super(*(actions | [options]))
    end

    def expire_page(path)

      instrument_page_cache :expire_page, path do
        Storehouse.delete(path)
      end unless Storehouse.config.disabled
      
      super
    end

    def cache_page(content, path, extension = nil, gzip = Zlib::BEST_COMPRESSION)
      return unless perform_caching

      options = self.storehouse_page_cache_action && self.storehouse_page_cache_options.try(:[], self.storehouse_page_cache_action) || {}

      use_cache = (options[:storehouse].nil? || options[:storehouse]) && Storehouse.config.consider_caching?(path)

      if !use_cache || Storehouse.config.continue_writing_filesystem || Storehouse.config.distribute?(path)
        super
      end

      if use_cache
        instrument_page_cache :write_page, path do
          Storehouse.write(path, content, options)
        end
      end
    
    end


  end
end