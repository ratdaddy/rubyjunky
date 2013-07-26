class QuietHighlighting
  $highlighting = true

  def self.quiet
    $highlighting = false
    yield
  ensure
    $highlighting = true
  end

  module Extension
    def self.registered app
      app.after_configuration do
        Middleman::Renderers::MiddlemanRedcarpetHTML.send :include, MarkdownCodeRenderer
      end
    end
  end

  module MarkdownCodeRenderer
    def block_code code, language
      if $highlighting
        super
      else
        "<pre>#{code}</pre>"
      end
    end
  end
end
