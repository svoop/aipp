require 'debug/session'
require 'singleton'
require 'optparse'
require 'yaml'
require 'json'
require 'pathname'
require 'fileutils'
require 'tmpdir'
require 'securerandom'
require 'tsort'
require 'ostruct'
require 'date'

require 'colorize'
require 'excon'
require 'graphql/client'
require 'graphql/client/http'
require 'nokogiri'
require 'csv'
require 'roo'
require 'pdf-reader'
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
require_relative 'aipp/downloader/file'
require_relative 'aipp/downloader/http'
require_relative 'aipp/downloader/graphql'
require_relative 'aipp/patcher'
require_relative 'aipp/parser'

require_relative 'aipp/environment'
require_relative 'aipp/border'
require_relative 'aipp/pdf'
require_relative 'aipp/t_hash'

require_relative 'aipp/executable'
require_relative 'aipp/runner'

require_relative 'aipp/scopes/aip/executable'
require_relative 'aipp/scopes/aip/runner'
require_relative 'aipp/scopes/aip/parser'

require_relative 'aipp/scopes/notam/executable'
require_relative 'aipp/scopes/notam/runner'
require_relative 'aipp/scopes/notam/parser'

