Gem::Specification.new do |s|
    s.name        = 'librelint'
    s.version     = '0.0.1'
    s.licenses    = ['MIT']
    s.summary     = "A general purpose code and template linter and style enforcer."
    s.description = s.summary
    s.authors     = ["Tristan Rice"]
    s.email       = 'rice@outerearth.net'
    s.files       = [
        "librelint.gemspec"
    ].concat( Dir.glob('lib/*/*/*') )
    s.extra_rdoc_files = ['README.md']
    s.homepage    = 'https://github.com/d4l3k/librelint'
    s.require_paths = ['lib']
    s.bindir = 'bin'
end
