language "Ruby" do
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
            @pos = @text.index("\n", @pos ) - 1
        end
    end
    rule "String Handling", type: :selection do
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
    language "Ruby:String", indent: false do
        rule "Ruby sub", type: :selection do
            match words: '#{' do
                handle_by 'Ruby', {} do
                    match chars: '}' do
                        @text[@pos - 1] != '\\'
                    end
                end
            end
        end
    end
end
