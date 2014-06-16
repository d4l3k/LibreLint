language "Ruby", extension: 'rb' do
    rule "Indentation", type: :indentation do
        match chars: '{([', words: %w{do class begin def module} do
            indent
            #binding.pry if @line_pos.length > 12
        end
        match chars: '})]', words: 'end' do
            outdent
        end
        match words: 'if' do
            indent if start_of_line
        end
        match chars: '#' do
            next_line
        end
    end
    rule "Whitespace", type: :style do
        @padding = false
        match chars: ',{' do
            space :after
        end
        match chars: ':' do
            if !' :({['.include?(@text[@pos - 1]) && @text[@pos + 1] != ':'
                space :after
            end
        end
        match chars: '[(' do
            no_space :after
        end
        match chars: '])' do
            no_space :before
        end
        match words: %w(== != || && >= <= => ||=) do
            space :around
        end
        match chars: '}' do
            space :before
        end
        match chars: '+' do
            if @text[@pos + 1] != '='
                space :around
            end
        end
        match chars: '-' do
            if !'0987654321='.include?(@text[@pos +1])
                space :around
            end
        end
        match chars: '*' do
            if !'*='.include?(@text[@pos + 1]) && @text[pos - 1] != '*'
                space :around
            end
        end
    end
    rule "String Handling", type: :control do
        match chars: '"\'`' do
            @pos += matched.length
            matched_letter = matched
            handle_by 'Ruby:String', {type: matched} do
                match chars: matched_letter do
                    @text[@pos - 1] != '\\'
                end
            end
        end
        match words: ['%w', '%r'] do
            @pos += matched.length + 1
            paren = Hash[*%w({ } ( ) { })]
            end_paren = paren[@text[@pos -1]]
            handle_by 'Ruby:String', {type: matched} do
                match chars: end_paren do
                    @text[@pos - 1] != '\\'
                end
            end
        end
    end
    rule "Line Length", type: :style do
        match chars: "\n" do
            if @pos - line_start > 90
                issue 'Line is longer than 90 characters.'
            end
        end
    end
    language "Ruby:String", indent: false do
        rule "Ruby sub", type: :control do
            match words: '#{', padding: false do
                @pos += matched.length
                handle_by 'Ruby', {} do
                    match chars: '}', padding: false do
                        @text[@pos - 1] != '\\'
                    end
                end
            end
        end
    end
end
