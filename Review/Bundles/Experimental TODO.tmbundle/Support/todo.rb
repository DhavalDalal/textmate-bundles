#!/usr/bin/env ruby

$tags = [
  { :label => "FIXME",   :color => "#A00000", :regexp => /FIX ?ME[\s,:]+(\S.*)$/i },
  { :label => "TODO",    :color => "#CF830D", :regexp => /TODO[\s,:]+(\S.*)$/i    },
  { :label => "CHANGED", :color => "#008000", :regexp => /CHANGED[\s,:]+(\S.*)$/  },
  { :label => "RADAR",   :color => "#0090C8", :regexp => /(.*<)ra?dar:\/(?:\/problem|)\/([&0-9]+)(>.*)$/, :trim_if_empty => true },
]

if RUBY_VERSION =~ /^1\.6\./ then
  puts <<-HTML
<p>Sorry, but this function requires Ruby 1.8.</p>
<p>If you do have Ruby 1.8 installed (default for Tiger users) then you need to setup the path variable in <tt> ~/.MacOSX/environment.plist</tt>.</p>
<p>For detailed instructions see <a href="http://macromates.com/textmate/manual/shell_commands#search_path">the manual</a> (scroll down to the paragraph starting with <em>Important</em>.)</p>
HTML
  abort
end

require "#{ENV['TM_SUPPORT_PATH']}/lib/osx/plist"
require "#{ENV['TM_SUPPORT_PATH']}/lib/textmate"
require "#{ENV['TM_SUPPORT_PATH']}/lib/web_preview"
require "erb"
include ERB::Util

ignores = ENV['TM_TODO_IGNORE']

def TextMate.file_link (file, line = 0)
  return "txmt://open/?url=file://" +
    file.gsub(/[^a-zA-Z0-9.-\/]/) { |m| sprintf("%%%02X", m[0]) } +
    "&amp;line=" + line.to_s
end

# setup empty array for per tag results
$tags.each { |tag| tag[:matches] = [ ] }

# output header

options_a = []
$tags.each do |tag|
  options_a << "\##{tag[:label]} {color: #{tag[:color]}}"
  options_a << "tr.#{tag[:label]} {color: #{tag[:color]}}"
end

options = '<style type="text/css">' + options_a.join("\n") + '</style>'

puts html_head(:window_title => "TODO", :page_title => "TODO List", :sub_title => 'TODO', :html_head => options)
tmpl_file = "#{ENV['TM_BUNDLE_SUPPORT']}/template_head.rhtml"
puts ERB.new(File.open(tmpl_file), 0, '<>').result
# puts '<table class="todo">'
STDOUT.flush

TextMate.each_text_file do |file|
  next if (ignores != nil and file =~ /#{ignores}/) or File.symlink?(file)
  $tags.each do |tag|
    File.open(file) do |io|
      io.grep(tag[:regexp]) do |content|
        $match = {
          :file => file,
          :line => io.lineno,
          :content => content,
          :type => tag[:label]
        }
        if tag[:label] == "RADAR" then
          url = "rdar://" + $2
          $match[:match] = html_escape($1) + "<a href=\"" + url + "\">" + html_escape(url) + "</a>" + html_escape($3)
        else
          $match[:match] = html_escape($1)
        end
        # tag[:matches] << $match
        tmpl_file = "#{ENV['TM_BUNDLE_SUPPORT']}/template_item.rhtml"
        puts ERB.new(File.open(tmpl_file), 0, '<>').result        
      end
    end
  end
end

# trim tags that didn't match, if requested
# $tags.delete_if { |tag| tag[:trim_if_empty] and tag[:matches].empty? }
puts '</table>'
html_footer()

# tmpl_file = "#{ENV['TM_BUNDLE_SUPPORT']}/template_tail.rhtml"
# puts ERB.new(File.open(tmpl_file), 0, '<>').result