[![Version](https://img.shields.io/gem/v/aipp.svg?style=flat)](https://rubygems.org/gems/aipp)
[![Tests](https://github.com/svoop/aipp/workflows/Test/badge.svg)](https://github.com/svoop/aipp/actions?workflow=Test)
[![Donorbox](https://img.shields.io/badge/donate-on_donorbox-yellow.svg)](https://donorbox.org/bitcetera)

# AIPP

Parser for Aeronautical Information Publication (AIP) available online.

This gem incluces two executables to download and parse aeronautical data as HTML or PDF, then build and export is as [AIXM](https://github.com/svoop/aixm) or [OFMX](https://github.com/openflightmaps/ofmx/wiki).

* [Homepage](https://github.com/svoop/aipp)
* [Rubydoc](https://www.rubydoc.info/gems/aipp/AIPP)
* Author: [Sven Schwyn - Bitcetera](http://www.bitcetera.com)

## Table of Contents

[Install](#install)<br>
[Usage](#usage)<br>
[Storage](#storage)<br>
[Regions](#regions)<br>
[AIP Parsers](#aip-parsers)<br>
[References](#references)<br>
[AIRAC Date Calculations](#airac-date-calculations)<br>
[Development](#development)

## Install

Add this to your <tt>Gemfile</tt> or <tt>gems.rb</tt>:

```ruby
gem aipp
```

## Usage

See the built-in help for all options:

```
aip2aixm --help
aip2ofmx --help
```

Say, you with to build the complete OFMX file for the current AIRAC cycle of the region LF:

```
aip2ofmx -r LF
```

You'll find the OFMX file in the current directory if the binary exits successfully.

## Storage

AIPP uses a storage directory for configuration, caching and in order to keep the results of previous runs. The default location is `~/.aipp`, however, you can pass a different directory with the `--storage` argument.

You'll find a directory for each region which contains the following items:

* `sources/`<br>This directory contains one ZIP archive per AIRAC cycle which incrementially caches all source files used to build the AIXM/OFMX file. Therefore, to make sure it contains all source files for a region, you have to build at least one complete AIXM/OFMX file for that region.
* `builds/`<br>This directory contains one ZIP archive per AIRAC cycle which is overwritten on every run. Therefore, to make sure it contains the complete build for a region, you have to make sure that your last run builds the complete AIXM/OFMX for that region. This archive contains:
  * the built AIXM/OFMX file
  * `build.yaml` – context of the build process
  * `manifest.csv` – diffable manifest (see below)
* `config.yml`<br>This file contains configuration which will be read on subsequent runs, most notably the namespace UUID used to identify the creator of OFMX files.

The manifest is a CSV which lists every feature on a separate line along with its hashes and comment. You can `diff` or `git diff` two manifests:

```diff
$ git diff -U0 2019-09-12/manifest.csv 2019-10-10/manifest.csv

--- a/2019-09-12/manifest.csv
+++ b/2019-10-10/manifest.csv
@@ -89,0 +90 @@ Aha,449f4791,d6d4bff8,Address: PHONE for LFF958FC61
+Aha,44b9a044,cf55a3cf,Address: PHONE for LF49929DD6
@@ -134 +135 @@ Aha,6acfbcc5,c4f57e3f,Address: FAX for LF897E1A6F
-Aha,6b381b32,fb947716,Address: RADIO for LFPO
+Aha,6b381b32,b9723b7e,Address: RADIO for LFPO
@@ -253,0 +255 @@ Aha,d01c4282,7cc8db7f,Address: PHONE for LF0C413AE2
+Aha,d05cfbff,74fb76bc,Address: FAX for LF49929DD6
@@ -327 +329 @@ Ahp,068f4f01,1dc2fb5c,Airport: LFEA BELLE ILE
-Ahp,06d04910,e18af958,Airport: LFFDE9077D TONNERRE CENTRE HOSPITALIER
+Ahp,06d04910,cc522711,Airport: LFFDE9077D TONNERRE CENTRE HOSPITALIER
(...)
```

The advantage of `git diff` is it's ability to hightlight exactly which part of a line has changed. [Check out this post to learn how](https://www.viget.com/articles/dress-up-your-git-diffs-with-word-level-highlights/).

## Regions

The reference implementation is region "LF" (France).

To implement a region, you have to create a new directory <tt>lib/aipp/regions/{REGION}/</tt> and place the following files there:

### AIP Parsers

Say, you want to parse ENR-4.3, you have to create the file <tt>ENR-4.3.rb</tt> which defines the class `AIPP::LF::ENR43` as follows:

```ruby
module AIPP
  module LF
    class ENR43 < AIP

      DEPENDS = %w(ENR-2.1 ENR-2.2)   # declare dependencies to other AIPs

      def parse
        html = read             # read the Nokogiri::HTML5 document
        feature = (...)         # build the feature
        add(feature: feature)   # add the feature to AIXM::Document
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
          html = read(aip_file: "#{aip}.#{part}")   # read with a non-standard name
          support_html = read(aip_file: 'AD-0.6')        # maybe read necessary support documents
          (...)
        end
      end

    end
  end
end
```

Inside the `parse` method, you have access to the following methods:

* [`read`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#read-instance_method) – download and read an AIP file
* [`add`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#add-instance_method) – add a [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)
* [`select`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#find-instance_method) – search previously written [`AIXM::Feature`s](https://www.rubydoc.info/gems/aixm/AIXM/Feature)
* some core extensions from ActiveSupport – [`Object#blank`](https://www.rubydoc.info/gems/activesupport/Object#blank%3F-instance_method) and [`String`](https://www.rubydoc.info/gems/activesupport/String)
* core extensions from this gem – [`Object`](https://www.rubydoc.info/gems/aipp/Object), [`NilClass`](https://www.rubydoc.info/gems/aipp/NilClass), [`Integer`](https://www.rubydoc.info/gems/aipp/Integer), [`String`](https://www.rubydoc.info/gems/aipp/String), [`Hash`](https://www.rubydoc.info/gems/aipp/Hash) and [`Enumerable`](https://www.rubydoc.info/gems/aipp/Enumerable)

As well as the following methods:

* [`options`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#options-instance_method) – arguments read from <tt>aip2aixm</tt> or <tt>aip2ofmx</tt> respectively
* [`config`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#config-instance_method) – configuration read from <tt>config.yml</tt>
* [`borders`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#borders-instance_method) – borders defined as GeoJSON read from the region (see below)
* [`cache`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#cache-instance_method) – virgin `OStruct` instance to make objects available across AIPs

### Borders

AIXM knows named borders for country boundaries. However, you might need additional borders which don't exist as named boarders.

To define additional borders, create simple GeoJSON files in the <tt>lib/aipp/regions/{REGION}/borders/</tt> directory, for example this `custom_border.geojson`:

```json
{
  "type": "GeometryCollection",
  "geometries": [
    {
      "type": "LineString",
      "coordinates": [
        [6.009531650000042, 45.12013319700009],
        [6.015747738000073, 45.12006702600007]
      ]
    }
  ]
}
```

⚠️ The GeoJSON file must consist of exactly one `GeometryCollection` which may contain any number of `LineString` geometries. Only `LineString` geometries are recognized! To define a closed polygon, the first coordinates of a `LineString` must be identical to the last coordinates.

The [`borders`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#borders-instance_method) method gives you access to a map from the border name (upcased file name) to the corresponding [`AIPP::Border`](https://www.rubydoc.info/gems/aipp/AIPP/Border) object:

```ruby
borders   # => { "CUSTOM_BORDER" => #<AIPP::Border file=custom_border.geojson> }
```

The border object implements simple nearest point and segment calculations to create arrays of [`AIXM::XY`](https://www.rubydoc.info/gems/aixm/AIXM/XY) which can be used with [`AIXM::Component::Geometry`](https://www.rubydoc.info/gems/aixm/AIXM/Component/Geometry).

See [`AIPP::Border`](https://www.rubydoc.info/gems/aipp/AIPP/Border) for more on this.

### Helpers

Helpers are modules defined in the <tt>lib/aipp/regions/{REGION}/helpers/</tt> directory. All helper modules are required automatically in alphabetic order.

There is one mandatory helper called `URL.rb` which must define the following method to build URLs from which to download AIPs:

```ruby
module AIPP
  module LF
    module Helpers
      module URL

        def url_for(aip_file)
          # build and return the download URL for the aip file
        end

      end
    end
  end
end
```

Feel free to add more helpers to DRY code which is shared by multiple AIP parsers. Say you want to extract methods which are used by all AIP parsers:

```ruby
module AIPP
  module LF
    module Helpers
      module Base

        def source(position:, aip_file: nil)
          (...)
        end

      end
    end
  end
end
```

To use this `source` method, simply include the helper module in the AIP parser:

```ruby
module AIPP
  module LF
    class AD2 < AIP

      include AIPP::LF::Helpers::Base

    end
  end
end
```

### Fixtures and Patches

Fixtures is static data defined as YAML in the <tt>lib/aipp/regions/{REGION}/fixtures/</tt> directory. All fixtures are read automatically. Please note that the name of the AIP parser (e.g. `AD-1.3.rb`) must match the name of the corresponding fixture (e.g. `fixtures/AD-1.3.yml`).

When parsed data is faulty or missing, you may fall back to such static data instead. This is where patches come in. You can patch any AIXM attribute setter by defining a patch block inside the AIP parser and accessing the static data via `parser.fixture`:

```ruby
module AIPP
  module LF
    class AD2 < AIP

      patch AIXM::Component::Runway::Direction, :xy do |parser, object, value|
        throw :abort unless value.nil?
        @fixtures ||= YAML.load_file(Pathname(__FILE__).dirname.join('AD-1.3.yml'))
        airport_id = parser.instance_variable_get(:@airport).id
        direction_name = object.name.to_s
        throw :abort if (xy = parser.fixture.dig('runways', airport_id, direction_name, 'xy')).nil?
        lat, long = xy.split(/\s+/)
        AIXM.xy(lat: lat, long: long)
      end

    end
  end
end
```

The patch block receives the object and the current value. If this value is okay, `throw :abort` to leave the patch block without touching anything. Otherwise, have the patch block return a new value which will be used instead.

### Source File Line Numbers

In order to reference the source of an AIXM/OFMX feature, it's necessary to know the line number where a particular node occurs in the HTML source file. You can ask any HTML element as follows:

```ruby
tr.line
```

⚠️ Make sure you have build Nokogumbo `--with-libxml2`. Otherwise, all elements will report line number `0` and therefore render OFMX documents invalid. See the [Nokogumbo README](https://github.com/rubys/nokogumbo/blob/master/README.md#flavors-of-nokogumbo) for more on this.

### Errors

You should `fail` on fatal problems. The `-e` command line argument will open a Pry session when such an error occurs. Issue errors as usual:

```ruby
fail "my message"
```

### Warnings

You should `warn` on non-fatal problems. The `-w ID` command line argument will open a Pry session when then warning with the given ID occurs. To issue a warning:

```ruby
warn("my message", pry: binding)   # open Pry attached to the binding
warn("my message", pry: error)     # open Pry attached to the error
```

### Messages

#### info

Use `info` for essential info messages:

```ruby
info("my message")                  # displays "my message" in black
info("my message", color: :green)   # displays "my message" in green
```

#### verbose info

Use `verbose_info` for in-depth info messages which are only shown if the `--verbose` mode is set:

```ruby
verbose_info("my message")   # displays "my message" in blue
```

### Pry

Pry is loaded with stack explorer support. Type `help` in the Pry console to see all available commands. The most useful command in the context of this gem is `up` which beams you one frame up in the caller stack.

Note: It's not currently possible to use pry-byebug at this time since it [interferes with pry-rescue](https://github.com/ConradIrwin/pry-rescue/issues/71).

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
* [open flightmaps – open-source aeronautical maps](https://openflightmaps.org)
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
