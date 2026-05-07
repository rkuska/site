#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"

ROOT = File.expand_path("..", __dir__)
TEX_PATH = File.join(ROOT, "_cv", "robert-kuska-cv.tex")
HTML_PATH = File.join(ROOT, "cv.html")

COMMAND_ARITY = {
  "cvheading" => 3,
  "cvsection" => 1,
  "cvtext" => 1,
  "cvjob" => 5,
  "cveducation" => 5,
  "cvtalk" => 3
}.freeze

CVPARAGRAPH = "cvparagraph"

def parse_balanced_group(text, index)
  index += 1 while index < text.length && text[index].match?(/\s/)
  raise "Expected '{' at byte #{index}" unless text[index] == "{"

  index += 1
  start = index
  depth = 1
  escaped = false

  while index < text.length
    char = text[index]
    if escaped
      escaped = false
    elsif char == "\\"
      escaped = true
    elsif char == "{"
      depth += 1
    elsif char == "}"
      depth -= 1
      return [text[start...index], index + 1] if depth.zero?
    end
    index += 1
  end

  raise "Unterminated group starting at byte #{start}"
end

class TexParser
  def initialize(input)
    @input = input
    @index = 0
  end

  def each_command
    commands = []
    while @index < @input.length
      if @input[@index] == "\\"
        command = read_command
        if COMMAND_ARITY.key?(command)
          args = COMMAND_ARITY.fetch(command).times.map { read_group }
          commands << [command, args]
        end
      else
        @index += 1
      end
    end
    commands
  end

  private

  def read_command
    @index += 1
    start = @index
    @index += 1 while @index < @input.length && @input[@index].match?(/[A-Za-z]/)
    @input[start...@index]
  end

  def read_group
    value, @index = parse_balanced_group(@input, @index)
    value
  end
end

def document_body(tex)
  tex[/\\begin\{document\}(.*)\\end\{document\}/m, 1] || tex
end

def normalize_text(text)
  text.gsub(/\s+/, " ").strip
end

def html_escape(text)
  CGI.escapeHTML(text)
end

def inline_tex_to_html(text)
  output = +""
  index = 0

  while index < text.length
    char = text[index]
    if char == "\\"
      command_start = index + 1
      command_end = command_start
      command_end += 1 while command_end < text.length && text[command_end].match?(/[A-Za-z]/)
      command = text[command_start...command_end]

      if command.empty?
        escaped = text[command_start]
        if escaped == "\\"
          output << "<br>"
        elsif escaped && escaped.match?(/[%$#_&{}]/)
          output << html_escape(escaped)
        end
        index += 2
      elsif %w[link href].include?(command)
        index = command_end
        url, index = parse_balanced_group(text, index)
        label, index = parse_balanced_group(text, index)
        output << %(<a href="#{html_escape(normalize_text(url))}">#{inline_tex_to_html(label)}</a>)
      elsif command == "email"
        index = command_end
        email, index = parse_balanced_group(text, index)
        normalized = normalize_text(email)
        output << %(<a href="mailto:#{html_escape(normalized)}">#{html_escape(normalized)}</a>)
      elsif command == "website"
        index = command_end
        website, index = parse_balanced_group(text, index)
        normalized = normalize_text(website)
        output << %(<a href="https://#{html_escape(normalized)}/">#{html_escape(normalized)}</a>)
      elsif %w[emph textit].include?(command)
        index = command_end
        value, index = parse_balanced_group(text, index)
        output << "<em>#{inline_tex_to_html(value)}</em>"
      elsif command == "textbf"
        index = command_end
        value, index = parse_balanced_group(text, index)
        output << "<strong>#{inline_tex_to_html(value)}</strong>"
      elsif command == "cvparagraph"
        index = command_end
        value, index = parse_balanced_group(text, index)
        output << inline_tex_to_html(value)
      else
        escaped = text[command_start]
        if escaped && escaped.match?(/[%$#_&{}]/)
          output << html_escape(escaped)
          index += 2
        else
          index = command_end
        end
      end
    elsif char == "{"
      output << html_escape(char)
      index += 1
    elsif char == "}"
      output << html_escape(char)
      index += 1
    else
      output << html_escape(char)
      index += 1
    end
  end

  normalize_text(output)
    .gsub("---", "&mdash;")
    .gsub("--", "&ndash;")
end

def paragraphs_from_tex(text)
  paragraphs = []
  buffer = +""
  index = 0

  while index < text.length
    if text[index] == "\\" && text[index + 1, CVPARAGRAPH.length] == CVPARAGRAPH
      paragraph = normalize_text(buffer)
      paragraphs << paragraph unless paragraph.empty?
      buffer.clear
      value, index = parse_balanced_group(text, index + 1 + CVPARAGRAPH.length)
      paragraphs << normalize_text(value)
    else
      buffer << text[index]
      index += 1
    end
  end

  trailing = normalize_text(buffer)
  paragraphs << trailing unless trailing.empty?
  paragraphs
end

def paragraph_html(text)
  "<p>\n    #{inline_tex_to_html(text)}\n  </p>"
end

def render_entry(name, date, role, location, body)
  paragraphs = paragraphs_from_tex(body).map { |paragraph| paragraph_html(paragraph) }.join("\n  ")
  <<~HTML.rstrip
    <section class="cv-entry">
      <div class="cv-entry-header">
        <h3>#{inline_tex_to_html(name)}</h3>
        <span class="cv-entry-date">#{inline_tex_to_html(date)}</span>
      </div>
      <p class="cv-role">#{inline_tex_to_html(role)} / #{inline_tex_to_html(location)}</p>
      #{paragraphs}
    </section>
  HTML
end

def render_talk(title, date, link)
  <<~HTML.rstrip
    <section class="cv-entry">
      <div class="cv-entry-header">
        <h3>#{inline_tex_to_html(title)}</h3>
        <span class="cv-entry-date">#{inline_tex_to_html(date)}</span>
      </div>
      <p>
        #{inline_tex_to_html(link)}
      </p>
    </section>
  HTML
end

tex = File.read(TEX_PATH)
commands = TexParser.new(document_body(tex)).each_command
body = []

commands.each do |command, args|
  case command
  when "cvheading"
    body << <<~HTML.rstrip
      <header class="cv-intro">
        <div>
          <h2>#{inline_tex_to_html(args[0])}</h2>
          <p>#{inline_tex_to_html(args[1])}</p>
        </div>
        <p class="cv-contact">#{inline_tex_to_html(args[2])}</p>
      </header>
    HTML
  when "cvsection"
    body << "<h2>#{inline_tex_to_html(args[0])}</h2>"
  when "cvtext"
    body << paragraph_html(args[0])
  when "cvjob", "cveducation"
    body << render_entry(*args)
  when "cvtalk"
    body << render_talk(*args)
  end
end

html = <<~HTML
  ---
  layout: default
  title: CV
  description: Robert Kuska's software engineering CV.
  permalink: /cv/
  ---

  <!-- Generated from _cv/robert-kuska-cv.tex by scripts/render-cv-html.rb. -->

  <p class="cv-actions">
    <a href="{{ '/assets/cv/robert-kuska-cv.pdf' | relative_url }}">Open the PDF version</a>.
  </p>

  #{body.join("\n\n")}
HTML

File.write(HTML_PATH, html)
