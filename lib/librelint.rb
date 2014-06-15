module LibreLint
    attr_accessor :languages, :indent_str
    @@languages = {}
    @@indent_str = '    '
    def self.indent_str
        @@indent_str
    end
    class Language
        attr_reader :name, :rules, :indent
        def initialize name, block, indent: true
            @name = name.to_s
            @indent = indent
            @rules = {}
            LibreLint.languages[@name] = self
            instance_eval(&block)
        end
        def rule name, type: nil, &block
            @rules[name.to_s] = block
        end
    end
    def self.languages
        @@languages
    end
    class Linter
        attr_reader :pos, :language, :text, :line_pos, :indent_level, :start_indent
        def initialize text, language: 'Ruby', meta: {}, indent_level: 0, done: nil
            @pos = 0
            @exit = done
            @language = language
            @indent_level = indent_level
            @start_indent = @indent_level
            @text = text
            @line_pos = []
            @done = done
            @meta = meta
        end
        def language
            if @language.class == String
                LibreLint.languages[@language]
            else
                @language
            end
        end
        def lint
            while @pos < @text.length
                finished = @done && self.instance_exec(&@done)
                if char != "\n" && !finished
                    language.rules.each do |name, rule|
                        self.instance_exec(&rule)
                    end
                elsif language.indent
                    # Change indentation
                    insert = @line_pos.last || 0
                    end_pos = insert
                    while " \t".include?(@text[end_pos]) && end_pos < @text.length
                        end_pos += 1
                    end
                    to_indent = @indent_level < @start_indent ? @indent_level : @start_indent
                    indent_amount = to_indent >= 0 ? to_indent : 0
                    insert_str = LibreLint.indent_str*indent_amount
                    #insert_str  = "#{indent_amount} #{insert_str}"
                    @text = @text[0...insert] + insert_str + @text[end_pos..-1]
                    @pos += insert_str.length - (end_pos - insert)
                    @line_pos << @pos + 1
                    @start_indent = @indent_level
                    # binding.pry if indent_amount > 0
                end
                @pos += 1
                if finished
                    break
                end
            end
            return @text
        end
        def char
            @text[@pos]
        end
        def multi_gap tokens
            [tokens].flatten.each do |token|
                if gapped(token)
                    return token
                end
            end
            nil
        end
        def gapped token
            return false if token.nil?
            match = @text[@pos, token.length] == token
            okay = " \n\t.()[]{}%=+-&|!"
            before = (@pos - 1) < 0 || okay.include?(@text[@pos - 1]) ||
                okay.include?(token[0])
            after = (@pos + token.length) >= @text.length ||
                okay.include?(@text[@pos + token.length]) ||
                okay.include?(token[-1])
            match && before && after
        end
        def match chars: nil, words: nil
            @_matched = nil
            if !words.nil?
                @_matched = multi_gap(words)
            end
            if !@_matched.nil? || !chars.nil? && chars.include?(char) && @_matched = char
                def matched
                    @_matched
                end
                yield
            end
        end
        def pos
            @pos
        end
        def start_of_line
            @pos == 0 || @text[@line_pos.last...@pos].strip.empty?
        end
        def handle_by language, meta, &block
            linter = Linter.new @text[@pos..-1], language: language, meta: meta, indent_level: @indent_level, done: block
            @text = @text[0...@pos] + linter.lint
            @pos += linter.pos - 1
            @indent_level = linter.indent_level
        end
        def indent count: 1
            @indent_level += count
        end
        def outdent count: 1
            indent(count: -count)
        end
    end
    def self.lint text
        linter = Linter.new text
        linter.lint
    end
end

def language name, indent: true, &block
    LibreLint::Language.new(name, block, indent: indent)
end

require_relative 'librelint/languages/ruby.rb'
require 'pry'

parts = ARGF.filename.split('.')
outname = parts[0...-1].join('.')+'-linted.'+parts.last
File.write(outname, LibreLint.lint(ARGF.read))
