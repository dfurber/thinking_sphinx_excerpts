# ThinkingSphinxExcerpts
module ThinkingSphinx
  class Configuration
    attr_accessor :excerpt_options
    def configure_excerpts(options={})
      self.excerpt_options = options.reverse_merge!({
        :wraptag => "strong",
        :chunk_separator => "...",
        :limit => 256, # maximum chars in excerpt
        :around => 5, # words around the term that should appear in the excerpt
        :never_excerpt => %w{login email login_slug username}, # names of attributes that should never be excerpted
        :paginating_find => false # return paging enumerator instead of will paginate collection
      })
    end
    self.instance.configure_excerpts
  end
  class Search
    def excerpt_for_with_options(string, model = nil)
      if model.nil? && one_class
        model ||= one_class
      end
      
      populate
      
      xoptions = ThinkingSphinx::Configuration.instance.excerpt_options
      options = {
        :docs   => [strip_bogus_characters(string)],
        :words  => strip_query_commands(results[:words].keys.join(' ')),
        :index  => "#{model.source_of_sphinx_index.sphinx_name}_core",
        :chunk_separator => xoptions[:chunk_separator],
        :limit => xoptions[:limit],
        :around => xoptions[:around]
      }
      unless xoptions[:wraptag].blank?
        wraptag = xoptions[:wraptag]
        options.merge!  :before_match => "<#{wraptag}>", :after_match => "</#{wraptag}>"
      end
      client.excerpts(options).first
    end
    alias_method_chain :excerpt_for, :options

    def strip_bogus_characters(s)
      # Used to remove some garbage before highlighting
      s.gsub(/<.*?>|\.\.\.|\342\200\246|\n|\r/, " ").gsub(/http.*?( |$)/, ' ') if s
    end

    def strip_query_commands(s)
      # XXX Hack for query commands, since Sphinx doesn't intelligently parse the query in excerpt mode
      # Also removes apostrophes in the middle of words so that they don't get split in two.
      s.gsub(/(^|\s)(AND|OR|NOT|\@\w+)(\s|$)/i, "").gsub(/(\w)\'(\w)/, '\1\2')
    end 

  end
  module SearchMethods
    module ClassMethods
      def search_with_excerpts(*args)
        query = args.clone  # an array
        options = query.extract_options!
        perform_excerpting = options.delete(:excerpts)
        unless perform_excerpting.blank?
          if perform_excerpting.is_a?(Array)
            excerpt_attrs = perform_excerpting.dup
            perform_excerpting = true
          else
            excerpt_attrs = nil
          end
        end
        results = ThinkingSphinx::Search.new *search_options(args)
        if perform_excerpting and !results.empty?
          results.each_with_index do |result,i|
            attributes = excerpt_attrs || (result.attribute_names - attributes_not_to_excerpt)
            attributes.each do |name|
              if result[name].is_a?(String)
                excerpt = results.excerpt_for(result[name], result.class)
                results[i].send("#{name}=", excerpt) unless excerpt.nil?
              end
            end
            results[i].freeze
          end
        end
        if using_paginating_find?
          PagingEnumerator.new(results.per_page, results.total_entries, false, options[:page] || 1, 1) { results.entries }
        else
          results
        end
      end
      alias_method_chain :search, :excerpts

      private
      
      def using_paginating_find?
        ThinkingSphinx::Configuration.instance.excerpt_options[:paginating_find]
      end
      
      def attributes_not_to_excerpt
        ThinkingSphinx::Configuration.instance.excerpt_options[:never_excerpt] || []
      end
      
      def client
        ThinkingSphinx::Configuration.instance.client
      end

    end
  end
end

