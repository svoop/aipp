require 'forwardable'
require 'colorize'
require 'pry'
require 'pry-rescue'
require 'pry-stack_explorer'
require 'optparse'
require 'yaml'
require 'csv'
require 'roo'
require 'pathname'
require 'tmpdir'
require 'open-uri'
require 'securerandom'
require 'tsort'
require 'ostruct'
require 'date'
require 'nokogiri'
require 'pdf-reader'
require 'json'
require 'zip'
require 'aixm'

require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string'
require_relative 'core_ext/object'
require_relative 'core_ext/integer'
require_relative 'core_ext/string'
require_relative 'core_ext/nil_class'
require_relative 'core_ext/enumerable'
require_relative 'core_ext/hash'

require_relative 'aipp/version'
require_relative 'aipp/pdf'
require_relative 'aipp/border'
require_relative 'aipp/t_hash'
require_relative 'aipp/executable'
require_relative 'aipp/airac'
require_relative 'aipp/patcher'
require_relative 'aipp/aip'
require_relative 'aipp/parser'
require_relative 'aipp/downloader'

# Init globals
$UNSEVERE_WARN = $VERBOSE_INFO = $PRY_ON_WARN = $PRY_ON_ERROR = false

# Disable "did you mean?" suggestions
#
# @!visibility private
module DidYouMean::Correctable
  remove_method :to_s
end
