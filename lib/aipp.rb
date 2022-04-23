require 'debug/session'
require 'singleton'
require 'colorize'
require 'optparse'
require 'yaml'
require 'pathname'
require 'tmpdir'
require 'net/http'
require 'open-uri'
require 'cgi'
require 'securerandom'
require 'tsort'
require 'ostruct'
require 'date'
require 'nokogiri'
require 'csv'
require 'roo'
require 'pdf-reader'
require 'pg'
require 'mysql'
require 'json'
require 'zip'
require 'airac'
require 'aixm'
require 'notam'

require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string'
require 'active_support/core_ext/date_time'

require_relative 'core_ext/nil_class'
require_relative 'core_ext/integer'
require_relative 'core_ext/string'
require_relative 'core_ext/array'
require_relative 'core_ext/enumerable'
require_relative 'core_ext/hash'
require_relative 'core_ext/nokogiri'

require_relative 'aipp/version'
require_relative 'aipp/debugger'
require_relative 'aipp/downloader'
require_relative 'aipp/patcher'
require_relative 'aipp/parser'

require_relative 'aipp/environment'
require_relative 'aipp/border'
require_relative 'aipp/pdf'
require_relative 'aipp/t_hash'

require_relative 'aipp/executable'
require_relative 'aipp/runner'

require_relative 'aipp/aip/executable'
require_relative 'aipp/aip/runner'
require_relative 'aipp/aip/parser'

require_relative 'aipp/notam/executable'
require_relative 'aipp/notam/runner'
require_relative 'aipp/notam/parser'

# Disable "did you mean?" suggestions
#
# @!visibility private
module DidYouMean::Correctable
  remove_method :to_s
end
