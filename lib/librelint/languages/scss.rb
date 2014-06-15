language 'SCSS', extension: 'scss' do
    rule 'Indentation' do
        match chars: '{' do
            indent
        end
        match chars: '}' do
            outdent
        end
    end
end
