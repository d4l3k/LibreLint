language 'HTML', extension: 'html' do
    rule 'Indentation', type: :indentation do
        ignore_list = %w(br)
        match chars: '<' do
            ignore = false
            ignore_list.each do |tag|
                ignore = true if @text[@pos + 1, tag.length].downcase == tag.downcase
            end
            tag_start = @text[@pos + 1] == '/' ? @pos + 2 : @pos + 1
            tag_end = [@text.index(' ', @pos) || 10**10, @text.index('>', @pos) || 10**10].min
            @tag = @text[tag_start...tag_end]
            puts @tag
            if !ignore
                if @text[@pos + 1] == '/'
                    outdent
                else
                    indent
                end
            end
        end
    end
    rule 'CSS', type: :control do
        match chars: '>' do
            if @tag == 'style'
                handle_by 'SCSS', {} do
                    match words: '</style>', padding: false do
                        @pos += matched.length
                        outdent
                        true
                    end
                end
            end
        end
    end
end
