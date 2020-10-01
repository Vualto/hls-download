# coding: utf-8
require_relative 'lib/version'

Gem::Specification.new do |spec|
  spec.name          = 'hls-download'
  spec.version       = HLSDownload::VERSION
  spec.authors       = ['Roger Pales']
  spec.email         = %w(roger.pales@vualto.com)
  spec.summary       = %q{Download HLS streams}
  spec.description   = %q{Download HLS streams}
  spec.homepage      = 'http://www.vualto.com'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.rb'] + Dir['bin/*'] + Dir['[A-Z]*']
  spec.require_paths = ['lib']
end
