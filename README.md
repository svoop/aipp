[![Version](https://img.shields.io/gem/v/aipp.svg?style=flat)](https://rubygems.org/gems/aipp)
[![Continuous Integration](https://img.shields.io/travis/svoop/aipp/master.svg?style=flat)](https://travis-ci.org/svoop/aipp)
[![Code Climate](https://img.shields.io/codeclimate/github/svoop/aipp.svg?style=flat)](https://codeclimate.com/github/svoop/aipp)
[![Gitter](https://img.shields.io/gitter/room/svoop/aipp.svg?style=flat)](https://gitter.im/svoop/aipp)
[![Donorbox](https://img.shields.io/badge/donate-on_donorbox-yellow.svg)](https://donorbox.org/bitcetera)

# AIPP

Parser for Aeronautical Information Publication (AIP) available online.

This gem incluces two executables to download and parse aeronautical data, then export is as [AIXM](https://github.com/svoop/aixm) or [OFMX](https://github.com/openflightmaps/ofmx/wiki).

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

AIPP uses a storage directory for configuration, caching and in order to keep the results of previous runs. The default location is `~/.aipp`, however, you can pass a different directory with the `--storage` argument.

## Regions

The reference implementation is region "LF" (France).

To implement a region, you have to create a new directory <tt>lib/aipp/regions/{REGION}</tt> and place the following files there:

### helper.rb

Create the file <tt>helper.rb</tt> which defines the module `AIPP::LF::Helper` and usually contains the URL builder method `url_for` used by all AIP parsers:

```ruby
module AIPP
  module LF
    module Helper

      def url_for(aip_file)
        # build and return the download URL for the aip file
      end

    end
  end
end
```

### AIP Parsers

Say, you want to parse ENR-4.3, you have to create the file <tt>ENR-4.3.rb</tt> which defines the class `AIPP::LF::ENR43` as follows:

```ruby
module AIPP
  module LF
    class ENR43 < AIP

      DEPENDS = %w(ENR-2.1 ENR-2.2)   # declare dependencies to other AIPs

      def parse
        html = load_html
        # read from "html" (Nokogiri::HTML::Document) and write to "aixm"
      end

    end
  end
end
```

Some AIP may be split over several files which require a little more code to load the individual HTML source files:

```ruby
module AIPP
  module LF
    class AD2 < AIP

      def parse
        %i(one two three).each do |part|
          html = load_html(aip_file: "#{aip}.#{part}")
          # read from "html" (Nokogiri::HTML::Document) and write to "aixm"
        end
      end

    end
  end
end
```

Inside the `parse` method, you have access to the following objects:

* `aixm` – target: instance of `AIXM::Document` (see [AIXM Rubygem](https://github.com/svoop/aixm))
* `options` – arguments read from <tt>aip2aixm</tt> or <tt>aip2ofmx</tt> respectively
* `config` – configuration read from <tt>config.yml</tt>
* `cache` – virgin `OStruct` instance to make objects available across AIPs

Furthermore, you have access to any method defined in <tt>helper.rb</tt> and you can overwrite any of them if need be (most notably `url_for`).

### Source File Line Numbers

In order to reference the source of an AIXM/OFMX feature, it's necessary to know the line number where a particular node occurs in the HTML source file. You can ask any HTML element as follows:

```ruby
tr.line
```

:warning: Make sure you have build Nokogumbo `--with-libxml2`. Otherwise, all elements will report line number `0` and therefore render OFMX documents invalid. See the [Nokogumbo README](https://github.com/rubys/nokogumbo/blob/master/README.md#flavors-of-nokogumbo) for more on this.

### Errors

You should `fail` on fatal problems. The `-E` command line argument will open a Pry session when such an error occurs. Issue errors as usual:

```ruby
fail "my message"
```

### Warnings

You should `warn` on non-fatal problems. The `-W ID` command line argument will open a Pry session when then warning with the given ID occurs. To issue a warning:

```ruby
warn("my message", context: binding)   # open Pry with binding context
warn("my message", context: error)     # open Pry with error context
```

### Informational Messages

You may `info` any other useful information:

```ruby
info("my message")                  # show info only in verbose mode (-V)
info("my message", force: true)     # always show info
info("my message", color: :green)   # show info with this color
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

* LF - France
  * [SIA – AIP publisher](https://www.sia.aviation-civile.gouv.fr)
  * [OpenData – public data files](https://www.data.gouv.fr)
  * [Protected Planet – protected area data files](https://www.protectedplanet.net)
* [Geo Maps – programmatically generated GeoJSON maps](https://github.com/simonepri/geo-maps)
* [Open Flightmaps – open-source aeronautical maps](https://openflightmaps.org)
* [AIXM Rubygem – AIXM/OFMX generator for Ruby](https://github.com/svoop/aixm)

## Development

To install the development dependencies and then run the test suite:

```
bundle install
bundle exec rake    # run tests once
bundle exec guard   # run tests whenever files are modified
```

Please submit issues on:

https://github.com/svoop/aipp/issues

To contribute code, fork the project on Github, add your code and submit a pull request:

https://help.github.com/articles/fork-a-repo

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
