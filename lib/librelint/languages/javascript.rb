language 'JavaScript', extension: 'js' do
    rule 'Indentation' do
        match chars: '{' do
            indent
        end
        match chars: '}' do
            outdent
        end
    end
    rule 'String Handling', type: :control do
        match chars: '"\'' do
            @pos += matched.length
            matched_letter = matched
            handle_by 'JavaScript:String', {} do
                match chars: matched_letter do
                    @text[@pos - 1] != '\\'
                end
            end
        end
    end
    rule 'Comments', type: :control do
        match words: '//', padding: false do
            next_line
        end
    end
    language "JavaScript:String", indent: false do
        rule 'none' do

        end
    end
    rule 'fixjsstyle', type: :external do
        # TODO: Implement this
    end
end
