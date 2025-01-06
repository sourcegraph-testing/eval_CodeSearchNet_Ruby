module GhostInThePost
  
  class GhostJSError < StandardError; end

  class PhantomTransform
    PHANTOMJS_SCRIPT = File.expand_path('../phantom/staticize.js', __FILE__)
    ERROR_TAG = "[GHOSTINTHEPOST-STATICIZE-ERROR]"

    def initialize(html, timeout=nil, wait_event=nil, included_scripts=nil)
      @inliner = JsInline.new(html, included_scripts)
      @timeout = timeout || GhostInThePost.timeout
      @wait_event = wait_event || GhostInThePost.wait_event
    end

    def transform
      @inliner.inline
      begin
        htmlfile = html_file(@inliner.html)
        @inliner.html = checkError(IO.popen(command(htmlfile)){|io| io.read})
      ensure
        if GhostInThePost.debug and @has_error
          p "Generated html can be found at #{htmlfile.path}"
        elsif !htmlfile.nil?
          htmlfile.unlink
        end
      end
      if GhostInThePost.remove_js_tags
        @inliner.remove_all_script 
      else
        @inliner.remove_inlined
      end
      @inliner.html
    end

    private

    def command html_file
      [
        GhostInThePost.phantomjs_path, 
        PHANTOMJS_SCRIPT, 
        html_file.path,
        @timeout,
        @wait_event,
      ].map(&:to_s)
    end

    #generate a tempfile with all the html that we need so that phantom can inject
    #easily and not have to max out a single command
    def html_file(html)
      file = Tempfile.new(['ghost_in_the_post', '.html'], encoding: Encoding::UTF_8)
      file.write(html)
      file.close #closing the file makes it accessible by phantom
      file
    end

    def checkError output
      if output.start_with?(ERROR_TAG) and GhostInThePost.raise_js_errors
        @has_error = true
        raise GhostJSError.new(output.gsub(ERROR_TAG, "")) 
      end
      output
    end

  end
end
