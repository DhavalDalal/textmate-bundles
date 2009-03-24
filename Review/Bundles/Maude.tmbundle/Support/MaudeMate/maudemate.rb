require "#{ENV['TM_BUNDLE_SUPPORT']}/lib/executor"
require "#{ENV['TM_SUPPORT_PATH']}/lib/tm/save_current_document"
require "pathname"
require "ostruct"
require "cgi"

module Maude
  class OutputParser
    def initialize
      extend CGI::Html4
      element_init
      extend CGI::HtmlExtension
    end
    
    def br
      super + "\n"
    end
    
    def num(&block)
      # span({'style' => 'color: blue'}, &block)
      em &block
    end
    
    # def symbols(str)
    #   str.gsub!(/-->/, '&#10236;')
    #   str.gsub!(/<--/, '&#10235;')
    #   str.gsub!(/=(>|&gt;)\+/, '&rArr;' + sup { '+' })
    #   str.gsub!(/(<|&lt;)=\?/, '&lArr;' + sup { '?' })
    #   str.gsub!('=/=', '&ne;')
    #   str
    # end
    
    def rx_ruler
      /^[-=]{5,}$/
    end
    
    def emit_ruler
      hr
    end
    
    def rx_solution
      /^(Solution) (\d+)\b(.*)$/
    end
    
    def emit_solution(msg, num, rest)
      strong { htmlize(msg) + ' ' + num } + emit_numbers(rest) + br
    end
    
    def rx_no_solution
      /^(No solution\.)$/
    end
    
    def emit_no_solution(msg)
      strong { htmlize(msg) } + br
    end
    
    def rx_states
      # Note the double whitespace after the number
      /^(states): (\d+)  (rewrites): (.+)$/
    end
    
    def emit_states(stat, number, time, rest)
      strong { stat } + ': ' + num { number } + br + emit_timing(time, rest)
    end

    def rx_timing
      /^(Decision time|rewrites): (.+)$/
    end
    
    def emit_timing(timing, rest)
      strong { timing } + ': ' + i { emit_numbers(rest) } + br
    end
    
    def emit_numbers(str)
      # highlight all emitted numbers, insert space before the unit
      str.gsub(/(\d+)(ms\b)?/) { num { $1 } + ($2 ? " #{$2}" : "") }
    end

    def rx_result
      /^(result) ([^:]+): (.+)$/
    end
    
    def emit_result(msg, type, rest)
      strong { htmlize(msg) } + ' ' + strong { htmlize(type) } + ': ' +
      blockquote { code { htmlize(rest) } }
    end
    
    def rx_command
      /^(\w+)(?: (\[[^\]]+\]) | )in (\S+) : (.+) \.$/
    end
    
    def emit_command(cmd, lmt, fmod, rest)
      lmt &&= ' ' + strong { htmlize(lmt) }
      strong { htmlize(cmd) } + lmt.to_s + ' in ' +
      strong { htmlize(fmod) } + ': ' +
      kbd { htmlize(rest) } + br
    end

    def rx_parse
      /^(\w+): (.*)(?!<\.)$/
    end
    
    def emit_parse(type, rest)
      strong { htmlize(type) } + ': ' + kbd { htmlize(rest) } + br
    end
    
    def rx_bye
      /^(Bye\.)\s*$/
    end
    
    def emit_bye(bye)
      strong { bye } + br
    end
    
    def emit_html(str)
      str.gsub(/Maude>\s*/, '').collect do |line|
        line.chomp!
        case line
        when rx_ruler then
          emit_ruler
        when rx_bye then
          emit_bye($1)
        when rx_solution then
          emit_solution($1, $2, $3)
        when rx_no_solution then
          emit_no_solution($1)
        when rx_timing then
          emit_timing($1, $2)
        when rx_states then
          emit_states($1, $2, $3, $4)
        when rx_result then
          emit_result($1, $2, $3)
        when rx_command then
          emit_command($1, $2, $3, $4)
        when rx_parse then
          emit_parse($1, $2)
        else
          htmlize(line) + br
        end
      end.join()
    end
  end

  class ErrorParser
    def initialize
      extend CGI::Html4
      element_init
      extend CGI::HtmlExtension
    end
    
    # The kinds of messages Maude emits, and the colors used to display them.
    def colors
      { "Warning" => "red", "Advisory" => "green" }
    end
    
    # Matches an "Error" message emitted by Maude.
    def rx_message
      /^(#{colors.keys.join("|")}):       # type of the message
        (?:\s
          ("[^"]+"|<[^>]+>)               # filename or stream
          (?:,\sline\s(\d+))?             # line number
          (?:\s\(([^)]+)\))?              # module name
          :)?\s
        (.+)$                             # message text
      /x
    end
    
    # Matches a marker on a source line emitted by Maude.
    # These could be used to get the column number for a message...
    def rx_source_marker
      /\A(.*) (<---\*HERE\*)\Z/
    end
    
    def href(file, line)
      url = "txmt://open?line=#{line}"
      return url if file.nil?
      if Pathname.new(file).absolute? then
        url << "&amp;url=file://" + e_url(file)
      elsif ENV.has_key?('TM_DIRECTORY') then
        url << "&amp;url=file://" + e_url(File.join(ENV['TM_DIRECTORY'], file))
      end
      url
    end
    
    def filename(file)
      file = file_or_stream?(file)
      if file.nil? then
        ENV['TM_FILENAME'] || 'untitled'
      elsif Pathname.new(file).absolute? then
        File.basename(file)
      else
        file
      end
    end
    
    def file_or_stream?(file)
      case file
      when /^<.*>$/ then
        nil
      when /^"(.*)"$/ then
        $1
      else
        file
      end
    end
    
    def emit_message(type, file, text)
      htmlfile = strong { htmlize(filename(file)) }
      htmltext = htmlize(text)
      htmltext.gsub!(htmlize(file), htmlfile)  if file
      p do
        span({'style' => "color: #{colors[type]}"}) do
          strong { htmlize(type) }
        end + ': ' + htmltext
      end
    end
    
    def emit_link(file, line, fmod)
      fmod = fmod ? htmlize(fmod) : 'at the top level'
      self.blockquote do
        a(href(file, line)) do
          em { fmod }
        end + ' in ' + strong do
          filename(file)
        end + ' at line ' + htmlize(line)
      end
    end
    
    def emit_source(line, mark = nil)
      mark &&= ins { '&lArr;' + em { 'Here' } }
      blockquote { code { htmlize(line) } + '&nbsp;' + mark.to_s }
    end
    
    def emit_html(str)
      str.collect do |line|
        line.chomp!
        case line
        when rx_message then
          type, file, line, fmod, text = $1, $2, $3, $4, $5
          out = emit_message(type, file, text)
          out << emit_link(file, line, fmod) if line
          out
        when rx_source_marker then
          code, mark = $1, $2
          emit_source(code, mark)
        else
          emit_source(line)
        end
      end.join
    end
  end

  Language = OpenStruct.new({
    :language => 'Core Maude',
    :executable => ENV['TM_MAUDE'] || 'maude',
    :arguments => %w[-batch -no-banner -no-ansi-color -no-wrap],
    :environment => { 'MAUDE_LIB' => [ENV['MAUDE_LIB'], ENV['TM_DIRECTORY']].compact.join(':') },
    :version => 'Core Maude \1',
  })
end

module MaudeMate
  class << self
    def filter_stdout(str)
      @stdout_parser ||= Maude::OutputParser.new
      @stdout_parser.emit_html(str)
    end

    def filter_stderr(str)
      # We can't hook into Maude like Ruby or Python, so instead we filter the
      # error messages here and redirect them to where Executor expects its
      # neatly formatted exception report.
      @stderr_parser ||= Maude::ErrorParser.new
      io = IO.for_fd(ENV['TM_ERROR_FD'].to_i)
      io << @stderr_parser.emit_html(str)
      io.flush
      ''
    end

    def emit_options(input, other_opts)
      @maude ||= Maude::Language
      puts @maude.language
      puts @maude.executable
      opts = {}
      opts[:version_replace] = @maude.version
      opts[:env] = @maude.environment
      unless input.empty?
        opts[:input] = input.join("\n")
        opts[:interactive_input] = false
      end
      [@maude.executable, @maude.arguments, ENV['TM_FILEPATH'], opts.merge(other_opts)]
    end

    def run(input, opts = {})
      TextMate.save_current_document
      Maude::Executor.run(*emit_options(input, opts)) { |str, type| 
        case type
        when :out
          filter_stdout(str)
        when :err
          filter_stderr(str)
        end
      }
    end
  end
end
