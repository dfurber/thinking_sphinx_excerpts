if defined?(ThinkingSphinx) 
  require 'thinking_sphinx_excerpts'
  if defined?(PagingEnumerator)
    ThinkingSphinx::Configuration.instance.configure_excerpts :paginating_find => true
  end
end


