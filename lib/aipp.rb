require 'pry' if $DEBUG

require 'tmpdir'
require 'pathname'
require 'open-uri'
require 'date'
require 'nokogiri'
require 'nokogumbo'
require 'aixm'

require_relative 'aipp/version'
require_relative 'aipp/airac'
require_relative 'aipp/refinements'
require_relative 'aipp/loader'
