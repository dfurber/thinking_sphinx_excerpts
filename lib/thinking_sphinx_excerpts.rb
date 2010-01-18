# ThinkingSphinxExcerpts
class Object
  def _metaclass
    class << self
      self
    end
  end

end

module ThinkingSphinx
  module Excerpts
    def self.included(base)
      base.extend ClassMethods
      base.class_eval do
        class << self    
          cattr_accessor :wraptag, :never_excerpt, :chunk_separator, :limit, :around, :paginating_find
          alias_method_chain :search, :excerpts
        end
      end
      base.send(:configure_excerpts)
    end
    
    
    module ClassMethods

      def configure_excerpts(options={})
        options.reverse_merge!({
          :wraptag => "strong",
          :chunk_separator => "...",
          :limit => 256, # maximum chars in excerpt
          :around => 5, # words around the term that should appear in the excerpt
          :never_excerpt => %w{login email login_slug username}, # names of attributes that should never be excerpted
          :paginating_find => false # return paging enumerator instead of will paginate collection
        })
        options.each {|k,v| self.send("#{k}=", v)}
      end

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
        results = ThinkingSphinx.search query, options
        if perform_excerpting and !results.empty?
          xoptions = excerpt_options(query, index_from_options(options))
          results.each_with_index do |result,i|
            attributes = excerpt_attrs || (result.attribute_names - never_excerpt)
            attributes.each do |name|
              if result[name].is_a?(String)
                excerpt = client.excerpts(xoptions.merge(:docs => [strip_bogus_characters(result[name])])).first
                results[i].send("#{name}=", excerpt) unless excerpt.nil?
              end
            end
            results[i].freeze
          end
        end
        if paginating_find
          PagingEnumerator.new(results.per_page, results.total_entries, false, options[:page] || 1, 1) { results.entries }
        else
          results
        end
      end
      
      private
      def client
        ThinkingSphinx::Configuration.instance.client
      end
      
      def index_from_options(options)
        (options[:classes] || options[:class]).first.sphinx_index_names.first
      end
      
      def excerpt_options(query, index)
        xoptions = {
            :words   => query.to_s,
            :index  => "#{index}",
            :chunk_separator => chunk_separator,
            :limit => limit,
            :around => around
        }
        unless wraptag.blank?
          xoptions.merge!  :before_match => "<#{wraptag}>", :after_match => "</#{wraptag}>"
        end
        
      end
      
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
  end
end

