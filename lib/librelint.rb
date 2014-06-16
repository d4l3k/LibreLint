module LibreLint
    attr_accessor :languages, :indent_str, :quiet, :fix
    @@languages = {}
    @@indent_str = '  '
    @@quiet = false
    @@fix = true
    def self.fix
        @@fix
    end
    def self.fix= n
        @@fix = n
    end
    def self.quiet
        @@quiet
    end
    def self.quiet= n
        @@quiet = n
    end
    def self.indent_str
        @@indent_str
    end
    class Language
        attr_reader :name, :rules, :indent, :extension, :extend
        def initialize name, block, indent: true, extension: nil, extend: []
            @name = name.to_s
            @indent = indent
            @rules = {}
            @extension = extension
            @extend = [extend].flatten
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
    def self.lint_file file
        extension = file.path.split(".").last
        language = nil
        @@languages.each do |name, lang|
            if !lang.extension.nil? && lang.extension.downcase == extension.downcase
                language = lang
            end
        end
        raise "Unable to detect language of file #{file.path}. Extension: #{extension}" if language.nil?
        linter = Linter.new(file.read, language: language)
        linter.lint
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
                if !finished
                    langs = language.extend.map{|l| LibreLint.languages[l]} + [language]
                    langs.each do |lang|
                        lang.rules.each do |name, rule|
                            @padding = true
                            self.instance_exec(&rule)
                        end
                    end
                end
                if char == "\n" && language.indent && LibreLint.fix
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

                    # This is to make sure that the first line indentation doesn't change.
                    if !@line_pos.empty?
                        @text = @text[0...insert] + insert_str + @text[end_pos..-1]
                        @pos += insert_str.length - (end_pos - insert)
                    end
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
        def next_line
            @pos = @text.index("\n", @pos ) - 1
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
        def match chars: nil, words: nil, padding: @padding
            @_matched = nil
            if !words.nil?
                if padding
                    @_matched = multi_gap(words)
                else
                    [words].flatten.each do |word|
                        @_matched = word if @text[@pos, word.length] == word
                    end
                end
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
        def line_start
            @line_pos.last || 0
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
        def issue msg, pos: @pos
            return if LibreLint.quiet
            column = @pos - line_start
            puts "Issue[#{@line_pos.length + 1}:#{column}]: #{msg}"
            line = @text[line_start..@text.index("\n", line_start + 1)]
            white = line.length - line.lstrip.length
            lang = language.name.split(":")[0]
            pretty_out = CodeRay.scan(line.lstrip, lang).term
            puts '    '+pretty_out
            caret_pos = (column - white + 4) % (IO.console.winsize[1])
            puts ' '*caret_pos + '^'
        end
        def fix
            if LibreLint.fix
                yield
            end
        end
        def no_space loc
            before = " \n".include?(@text[@pos - 1])
            after = " \n".include?(@text[@pos + matched.length])
            if loc == :before && before || loc == :after && after || loc == :around && before && after
                issue "There should not be a space #{loc.to_s} a '#{matched}'.", pos: @pos
                fix do
                    if [:before, :around].include?(loc) && before
                        @text = @text[0...@pos - 1] + @text[@pos..-1]
                        @pos -= 1
                    end
                    if [:after, :around].include?(loc) && after
                        @text = @text[0..@pos] + @text[@pos+2..-1]
                    end
                end
            end
        end
        def space loc
            before = !" \n".include?(@text[@pos - 1])
            after = !" \n".include?(@text[@pos + matched.length])
            if loc == :before && before || loc == :after && after || loc == :around && before && after
                issue "There should be a space #{loc.to_s} a '#{matched}'.", pos: @pos
                fix do
                    if [:before, :around].include?(loc) && before
                        @text.insert(@pos, ' ')
                        @pos += 1
                    end
                    if [:after, :around].include?(loc) && after
                        @text.insert(@pos + matched.length, ' ')
                    end
                end
            end
        end
    end
    def self.lint text
        linter = Linter.new text
        linter.lint
    end
end

def language name, indent: true, extension: nil, extend: [], &block
    LibreLint::Language.new(name, block, indent: indent, extension: extension, extend: extend)
end
path = File.join(File.dirname(__FILE__), 'librelint/languages/*.rb')
Dir.glob(path).each do |file|
    require_relative file
end
require 'io/console'
require 'pry'
