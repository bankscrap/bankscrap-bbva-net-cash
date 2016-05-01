# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bankscrap/bbva-net-cash/version'

Gem::Specification.new do |spec|
  spec.name          = 'bankscrap-bbva-net-cash'
  spec.version       = Bankscrap::BBVANetCash::VERSION
  spec.authors       = ['Javier Cuevas']
  spec.email         = ['javier@diacode.com']
  spec.summary       = 'BBVA Net Cash adapter for Bankscrap'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'bankscrap', '~> 1.0.2'
  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
end
