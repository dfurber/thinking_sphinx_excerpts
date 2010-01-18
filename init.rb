if defined?(ThinkingSphinx) 
  require 'thinking_sphinx_excerpts'
  ThinkingSphinx::Search.send(:include, ThinkingSphinx::Excerpts)
  if defined?(PagingEnumerator)
    ThinkingSphinx::Search.configure_excerpts :paginating_find => true
  end
end


