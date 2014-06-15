require 'pry'

class RBLinter
    def initialize str, indent: '    '
        @string = str
        @indent_char = indent
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
                    # Indentation
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
                    # String Handling
                    elsif '"\''.include? char
                        is_string = true
                        string_type = char
                    elsif char == '#'
                        pos = line.length
                    elsif line[pos, 3] == '%r{'
                        is_string = true
                        string_type = '%r{'
                    # Padding
                    elsif ',' == char
                        if pos != 0 && line[pos - 1] == " "
                           line = line[0...(pos - 1)] + line[(pos)..-1]
                           pos -= 1
                        end
                        if !is_end && line[pos + 1] != " "
                            line.insert(pos + 1, " ")
                            pos += 1
                        end
                    elsif '+-='.include?(char)
                        if pos != 0 && line[pos - 1] != " "
                           line = line[0...(pos - 1)] + line[(pos)..-1]
                           pos -= 1
                        end
                        n = '1234567890'
                        # TODO
                        if !is_end && line[pos + 1] != " "
                            line.insert(pos + 1, " ")
                            pos += 1
                        end
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
                line = @indent_char*capped + line
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
        p = self.new(str)
        p.walk
    end
end
parts = ARGF.filename.split('.')
outname = parts[0...-1].join('.')+'-linted.'+parts.last
File.write(outname, RBLinter.parse(ARGF.read))
