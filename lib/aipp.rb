require 'forwardable'
require 'colorize'
require 'pry'
require 'pry-rescue'
require 'optparse'
require 'yaml'
require 'pathname'
require 'open-uri'
require 'securerandom'
require 'tsort'
require 'ostruct'
require 'date'
require 'nokogiri'
require 'nokogumbo'
require 'aixm'

require_relative 'aipp/version'
require_relative 'aipp/refinements'
require_relative 'aipp/t_hash'
require_relative 'aipp/executable'
require_relative 'aipp/progress'
require_relative 'aipp/airac'
require_relative 'aipp/aip'
require_relative 'aipp/parser'

# Disable "did you mean?" suggestions
module DidYouMean::Correctable
  remove_method :to_s
end
