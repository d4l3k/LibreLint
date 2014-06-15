language 'ERB', extension: 'erb', extend: 'HTML' do
    rule "Inline Ruby", type: :control do
        match words: '<%', padding: false do
            @pos += matched.length
            outdent
            if char == "="
                @pos += 1
            end
            handle_by 'Ruby', {} do
                match words: '%>', padding: false do
                    @pos += 1
                    true
                end
            end
        end
    end
end
