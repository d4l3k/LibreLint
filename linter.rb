require 'pry'

class RBParser
    def initialize str
        @string = str
        @indent_char = '    '
    end
    def walk
        lines = @string.split("\n")
        indent = 0
        is_string = false
        string_type = ''
        lines.each_with_index do |line, index|
            line = line.strip
            pos = 0
            start_string = is_string
            start_indent = indent
            while pos < line.length
                char = line[pos]
                is_end = pos == line.length - 1
                inner_type = string_type.split(":").last
                if !is_string
                    if "{([".include? char
                        indent += 1
                    elsif "})]".include? char
                        indent -= 1
                    elsif multi_gap(line, pos, ['do', 'class', 'begin', 'def', 'module'])
                        indent += 1
                    elsif gapped(line, pos, 'if') && pos == 0
                        indent += 1
                    elsif gapped(line, pos, 'end')
                        indent -= 1
                    elsif multi_gap(line, pos, ['else', 'elsif'])
                        start_indent = indent - 1
                    elsif '"\''.include? char
                        is_string = true
                        string_type = char
                    elsif char == '#'
                        pos = line.length
                    elsif line[pos, 3] == '%r{'
                        is_string = true
                        string_type = '%r{'
                    end
                else
                    if !inner_type
                        binding.pry
                    end
                    if ['"', '%r{'].include?(inner_type) && line[pos, 2] == '#{'
                        string_type += ':#{'
                    elsif '"\''.include? inner_type
                        if char == inner_type && !(pos - 1 >= 0 && line[pos - 1]=='\\')
                            string_type = string_type.split(":")[0...-1].join(":")
                            is_string = string_type != ''
                        end
                    elsif ['%r{', '#{'].include?(inner_type) && char == '}'
                        string_type = string_type.split(":")[0...-1].join(":")
                        is_string = string_type != ''
                    end
                end
                pos += 1
            end
            if !start_string
                less = start_indent < indent ? start_indent : indent
                capped = less > 0 ? less : 0
                line = "#{less} " + @indent_char*capped + line
            end

            lines[index] = line
        end
        lines.join("\n")
    end
    def gapped line, pos, token
        match = line[pos, token.length] == token
        okay = " \t."
        before = (pos - 1) < 0 || okay.include?(line[pos - 1])
        after = (pos + token.length) >= line.length || okay.include?(line[pos + token.length])
        match && before && after
    end
    def multi_gap line, pos, tokens
        tokens.each do |token|
            if gapped(line, pos, token)
                return true
            end
        end
        false
    end
    def self.parse str
        p = RBParser.new(str)
        p.walk
    end
end
File.write('foo.rb', RBParser.parse(ARGF.read))
