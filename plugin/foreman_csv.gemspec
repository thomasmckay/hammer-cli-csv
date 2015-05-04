$LOAD_PATH.push File.expand_path('../lib', __FILE__)

require 'foreman_csv/version'

Gem::Specification.new do |s|
  s.name        = 'foreman_csv'
  s.version     = ForemanCSV::VERSION
  s.authors     = ['Red Hat']
  s.email       = ['foreman-dev@googlegroups.com']
  s.homepage    = 'http://katello.org'
  s.summary     = 'CSV import/export utility'
  s.description = 'CSV import/export utility'

  s.files = Dir['{app,config,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.add_dependency 'katello'

  s.add_development_dependency 'rubocop-checkstyle_formatter'
end
