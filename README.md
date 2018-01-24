[![Version](https://img.shields.io/gem/v/aipp.svg?style=flat)](https://rubygems.org/gems/aipp)
[![Continuous Integration](https://img.shields.io/travis/svoop/aipp/master.svg?style=flat)](https://travis-ci.org/svoop/aipp)
[![Code Climate](https://img.shields.io/codeclimate/github/svoop/aipp.svg?style=flat)](https://codeclimate.com/github/svoop/aipp)
[![Gitter](https://img.shields.io/gitter/room/svoop/aipp.svg?style=flat)](https://gitter.im/svoop/aipp)
[![Donorbox](https://img.shields.io/badge/donate-on_donorbox-yellow.svg)](https://donorbox.org/bitcetera)

# AIPP

Parser for Aeronautical Information Publication (AIP) available online.

This gem incluces an executable to download and parse aeronautical data, then
export is as [AIXM](https://github.com/svoop/aixm) which can be consumed by
[Open Flightmaps](https://openflightmaps.org).

* [Homepage](https://github.com/svoop/aipp)
* Author: [Sven Schwyn - Bitcetera](http://www.bitcetera.com)

## Install

Add this to your <tt>Gemfile</tt>:

```ruby
gem aipp
```

## Usage

```
aip2aixm --help
```

## Parsers

Parsers are defined as modules and named +lib/aipp/parser/{FIR}/{AIP}.rb+. For
them to plug in, you have to define the following public methods:

* `url`<br>Must return the download URL of the AIP HTML as a string.
* `convert!`<br>Takes `html` ([Nokogiri document](https://github.com/sparklemotion/nokogiri)) to parse and populate `aixm` ([AIXM document](https://github.com/svoop/aixm))

You should read and honor the following attributes passed in from `aip2aixm`
arguments:

* `@fir`
* `@aip`
* `@airac`
* `@limit`

You should `fail` on fatal and `warn` on non-fatal problems. If `$DEBUG` is
+true+ (e.g. by use of the `-D` option), a Pry session will open if you use
`warn` as follows:

```ruby
warn("my message", binding)
```

## AIRAC date calculations

```ruby
airac = AIPP::AIRAC.new(Date.parse('2017-12-24'))
airac.date        # => 2018-12-07
airac.id          # => 1713
airac.next_date   # => 2018-01-04
airac.next_id     # => 1801
```

## References

* AIP authorities
  * [LF: SIA](https://www.sia.aviation-civile.gouv.fr)
* [Open Flightmaps](https://openflightmaps.org)

## Development

To install the development dependencies and then run the test suite:

```
bundle install
bundle exec rake    # run tests once
bundle exec guard   # run tests whenever files are modified
```

Please submit issues on:

https://github.com/svoop/aipp/issues

To contribute code, fork the project on Github, add your code and submit a
pull request:

https://help.github.com/articles/fork-a-repo

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
