require_relative '../lib/librelint'

describe 'Linting' do
    it 'should not affect code execution' do
        files = Dir.glob(File.dirname(__FILE__)+"/test_cases/*")
        langs = { rb: 'ruby', js: 'node'}
        files.each do |file|
            f = File.new(file)
            extension = file.split('.').last
            code = f.read
            linted = LibreLint.lint code
            temp = Tempfile.new('librelinter')
            temp.write linted
            temp.close
            executable = langs[extension.to_sym]
            `#{executable} #{f.path}`.should eq(`#{executable} #{temp.path}`)
        end
    end
end
