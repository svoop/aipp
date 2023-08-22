gem 'minitest'

require 'pathname'

require 'minitest/autorun'
require Pathname(__dir__).join('..', 'lib', 'aipp')

require 'minitest/flash'
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
