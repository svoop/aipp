[![Version](https://img.shields.io/gem/v/aipp.svg?style=flat)](https://rubygems.org/gems/aipp)
[![Continuous Integration](https://img.shields.io/travis/svoop/aipp/master.svg?style=flat)](https://travis-ci.org/svoop/aipp)
[![Code Climate](https://img.shields.io/codeclimate/github/svoop/aipp.svg?style=flat)](https://codeclimate.com/github/svoop/aipp)
[![Gitter](https://img.shields.io/gitter/room/svoop/aipp.svg?style=flat)](https://gitter.im/svoop/aipp)
[![Donorbox](https://img.shields.io/badge/donate-on_donorbox-yellow.svg)](https://donorbox.org/bitcetera)

# AIPP

Parser for Aeronautical Information Publication (AIP) available online.

This gem incluces two executables to download and parse aeronautical data,
then export is as [AIXM](https://github.com/svoop/aixm) or
[OFMX](https://github.com/openflightmaps/ofmx/wiki).

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
aip2ofmx --help
```

## Storage

AIPP uses a storage directory for configuration, caching and in order to keep
the results of previous runs. The default location is `~/.aipp`, however, you
can pass a different directory with the `--storage` argument.

## Regions

To implement a region, you have to create a new directory
<tt>lib/aipp/regions/{REGION}</tt> and place the following files there:

### helper.rb

Create the file <tt>helper.rb</tt> which defines the module

```ruby
module AIPP
  module LF
    module Helper

      AIPS = %w(
        ENR-4.3
      ).freeze

      def url(aip:)
        # build and return the download URL
      end

    end
  end
end
```

### Parser Classes

The reference implementation is region "LF" (France).

Say, you want to parse ENR-4.3, you have to create the file <tt>ENR-4.3.rb</tt>
which defines the class `AIPP::LF::ENR43` as follows:

```ruby
module AIPP
  module LF
    class ENR43 < AIP

      def parse
        # read from "html" and write to "aixm"
      end

    end
  end
end
```

Inside the `parse` method, you have access to the following objects:

* `html` – source: instance of `Nokogiri::HTML::Document`
* `aixm` – target: instance of `AIXM::Document` (see [AIXM Rubygem](https://github.com/svoop/aixm))
* `config` – configuration read from <tt>config.yml</tt>
* `options` – arguments read from `aip2aixm` or `aip2ofmx` respectively

In order to reference the source of an AIXM/OFMX feature, it's necessary to
know the line number where a particular node occurs in the HTML source file.
Unfortunately, due to limitations of the underlying parser, Nokogiri/Nokogumbo
do not report the line number. As a workaround, you can use the `line` method
which works if and only if the node contains enough child-CDATA to be unique:

```ruby
line(node: tr)
```

Furthermore, you have access to any method defined in <tt>helper.rb</tt>.

You should `fail` on fatal and `warn` on non-fatal problems. If `$DEBUG` is
*true* (e.g. by use of the `-D` option), a Pry session will open provided you
use `warn` as follows:

```ruby
warn("my message", binding)
```

## AIRAC Date Calculations

The `AIPP::AIRAC` class is used to calculate AIRAC cycles:

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
* [AIXM Rubygem](https://github.com/svoop/aixm)

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
