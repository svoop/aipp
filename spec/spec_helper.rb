gem 'minitest'

require 'pathname'

require 'minitest/autorun'
require Pathname(__dir__).join('..', 'lib', 'aipp')

require 'minitest/sound'
Minitest::Sound.success = Pathname(__dir__).join('sounds', 'success.mp3').to_s
Minitest::Sound.failure = Pathname(__dir__).join('sounds', 'failure.mp3').to_s

require 'minitest/focus'

module AIPP
  def self.root
    Pathname(__dir__).join('..')
  end
end

class Minitest::Spec
  class << self
    alias_method :context, :describe
  end
end

def fixtures_path
  Pathname(__dir__).join('fixtures')
end
