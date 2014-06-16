language 'SCSS', extension: 'scss' do
    rule 'Indentation' do
        match chars: '{' do
            indent
        end
        match chars: '}' do
            outdent
        end
    end
    rule 'Comments', type: :control do
        match words: '//', padding: false do
            next_line
        end
    end
end
