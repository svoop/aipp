[![Version](https://img.shields.io/gem/v/aipp.svg?style=flat)](https://rubygems.org/gems/aipp)
[![Tests](https://img.shields.io/github/workflow/status/svoop/aipp/Test.svg?style=flat&label=tests)](https://github.com/svoop/aipp/actions?workflow=Test)
[![Donorbox](https://img.shields.io/badge/donate-on_donorbox-yellow.svg)](https://donorbox.org/bitcetera)

# AIPP

Parser for Aeronautical Information Publication (AIP) available online.

This gem incluces two executables to download and parse aeronautical data as HTML, PDF, XSLX, ODS and CSV, then build and export is as [AIXM](https://github.com/svoop/aixm) or [OFMX](https://github.com/openflightmaps/ofmx/wiki).

* [Homepage](https://github.com/svoop/aipp)
* [Rubydoc](https://www.rubydoc.info/gems/aipp/AIPP)
* Author: [Sven Schwyn - Bitcetera](http://www.bitcetera.com)

## Table of Contents

[Install](#install)<br>
[Usage](#usage)<br>
[Storage](#storage)<br>
[Regions](#regions)<br>
[AIRAC Date Calculations](#airac-date-calculations)<br>
[References](#references)<br>
[Development](#development)

## Install

### Security

This gem is [cryptographically signed](https://guides.rubygems.org/security/#using-gems) in order to assure it hasn't been tampered with. Unless already done, please add the author's public key as a trusted certificate now:

```
gem cert --add <(curl -Ls https://raw.github.com/svoop/aipp/main/certs/svoop.pem)
```

### Standalone

Make sure to have the [latest version of Ruby](https://www.ruby-lang.org/en/documentation/installation/) and then install this gem:

```
gem install aipp --trust-policy MediumSecurity
```

### Bundler

If you're familiar with [Bundler](https://bundler.io) powered Ruby projects, you might prefer to add the following to your <tt>Gemfile</tt> or <tt>gems.rb</tt>:

```ruby
gem aipp
```

And then install the bundle:

```
bundle install --trust-policy MediumSecurity
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

The manifest is a CSV which lists every feature on a separate line along with its hashes, AIP and comment. You can `diff` or `git diff` two manifests:

```diff
$ git diff -U0 2019-09-12/manifest.csv 2019-10-10/manifest.csv

--- a/2019-09-12/manifest.csv
+++ b/2019-10-10/manifest.csv
@@ -204 +204 @@ AD-1.3,Ahp,9e9f031e,d6f22057,Airport: LFLJ COURCHEVEL
-AD-1.3,Ahp,9f1eed18,37ddbbde,Airport: LFQD ARRAS ROCLINCOURT
+AD-1.3,Ahp,9f1eed18,f0e60105,Airport: LFQD ARRAS ROCLINCOURT
@@ -312 +312 @@ AD-2,Aha,4250c9ee,04d49dc7,Address: RADIO for LFHV
-AD-2,Aha,6b381b32,fb947716,Address: RADIO for LFPO
+AD-2,Aha,6b381b32,b9723b7e,Address: RADIO for LFPO
@@ -664 +663,0 @@ AD-2,Ser,3920a7fd,4545c5eb,Service: AFIS by LFGA TWR
-AD-2,Ser,39215774,1f13f2cf,Service: APP by LFCR APP
@@ -878 +876,0 @@ AD-2,Ser,bb5228d7,7cfb4572,Service: TWR by LFMH TWR
-AD-2,Ser,bc72caf2,0a15b39c,Service: FIS by LFCR FIC
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

    end
  end
end
```

The class has to implement some methods either in the class itself or in a [helper](#Helpers) included by the class.

⚠️ Parser files usually follow AIP naming conventions such as `ENR-4.3`. However, you're free to use arbitrary naming for parser files e.g. if you're working with one big data source which contains the full AIP dataset.

#### Mandatory `parse` Method

The class must implement the `parse` method which contains the code to read, parse and write the data:

```ruby
module AIPP
  module LF
    class ENR43 < AIP

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
          html = read("#{aip}.#{part}")   # read with a non-standard name
          support_html = read('AD-0.6')   # maybe read necessary support documents
          (...)
        end
      end

    end
  end
end
```

Inside the `parse` method, you have access to the following methods:

Method | Description
-------|------------
[`read`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#read-instance_method) | download and read an AIP file
[`add`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#add-instance_method) | add a [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)
[`find`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#find-instance_method) | find previously written [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)s by object
[`find_by`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#find_by-instance_method) | find previously written [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)s by class and attribute values
[`unique`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#unique-instance_method) | prevent duplicate [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)s
[`given`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#given-instance_method) | inline condition for assignments
[`link_to`](https://www.rubydoc.info/gems/aipp/AIPP/AIP#link_to-instance_method) | optionally checked Markdown link
[`Object#blank`](https://www.rubydoc.info/gems/activesupport/Object#blank%3F-instance_method) and [`String`](https://www.rubydoc.info/gems/activesupport/String) | some core extensions from ActiveSupport
[`aip`](https://www.rubydoc.info/gems/aipp/AIPP%2FAIP:aip) | AIP name (equal to the parser file name without its file extension such as "ENR-2.1" implemented in the file "ENR-2.1.rb")
[`aip_file`](https://www.rubydoc.info/gems/aipp/AIPP%2FAIP:aip_file) | AIP file as passed and possibly renamed by `url_for`
[`options`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#options-instance_method) | arguments read from <tt>aip2aixm</tt> or <tt>aip2ofmx</tt> respectively
[`config`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#config-instance_method) | configuration read from <tt>config.yml</tt>
[`borders`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#borders-instance_method) | borders defined as GeoJSON read from the region (see below)
[`cache`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#cache-instance_method) | `OStruct` instance to make objects available across AIPs

To make the parser code more readable, this gem provides a few useful core extensions as well:

* [`NilClass`](https://www.rubydoc.info/gems/aipp/NilClass)
* [`Integer`](https://www.rubydoc.info/gems/aipp/Integer)
* [`String`](https://www.rubydoc.info/gems/aipp/String)
* [`Hash`](https://www.rubydoc.info/gems/aipp/Hash)
* [`Enumerable`](https://www.rubydoc.info/gems/aipp/Enumerable)
* [`Nokogiri`](https://www.rubydoc.info/gems/aipp/Nokogiri)

#### Mandatory `url_for` Method

The class must implement the `url_for` method which returns the URL from where to download the AIP file:

```ruby
module AIPP
  module LF
    class AD2 < AIP

      def url_for(aip_file)
        # build and return the download URL for the aip file
      end

    end
  end
end
```

There are a few things to note about `url_for`:

* If the returned string begins with a protocol like `https:`, the downloader will fetch the file from there.
* If the returned string is just a file name, the downloader will look for this exact file in the current local directory.
* The passed `aip_file` will be used as the file name for the local copy in the sources directory. You can rename it on the fly by assigning a new value to this variable.

#### Optional `setup` Method

The class may implement the `setup` method. If present, it will be called when this parser is instantiated:


```ruby
module AIPP
  module LF
    class AD2 < AIP

      def setup
        AIXM.config.voice_channel_separation = :any
        cache.setup_at ||= Time.now
      end

    end
  end
end
```

### Borders

AIXM knows named borders for country boundaries. However, you might need additional borders which don't exist as named borders.

You can define additional borders as [`AIPP::Border`](https://www.rubydoc.info/gems/aipp/AIPP/Border) objects in two ways.

#### From GeoJSON

Create simple GeoJSON files in the <tt>lib/aipp/regions/{REGION}/borders/</tt> directory, for example this `my_border_1.geojson`:

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
    },
    {
      "type": "LineString",
      "coordinates": [
        [4.896732957592112, 43.95662950764992],
        [4.005739165537195, 44.10769266295027]
      ]
    }
  ]
}
```

⚠️ The GeoJSON file must consist of exactly one `GeometryCollection` which may contain any number of `LineString` geometries. Only `LineString` geometries are recognized! To define a closed polygon, the first coordinates of a `LineString` must be identical to the last coordinates.

#### From Coordinates

It's also possible to create a [`AIPP::Border`](https://www.rubydoc.info/gems/aipp/AIPP/Border) objects on the fly:

```ruby
my_border_2 = AIPP::Border.from_array(
  [
    ["6.009531650000042 45.12013319700009", "6.015747738000073 45.12006702600007"],
    ["4.896732957592112 43.95662950764992", "4.005739165537195 44.10769266295027"]
  ]
)
```

The coordinate pairs must be separated with whitespaces and/or commas. If you want to use this border everywhere, make sure you add it to the others:

```ruby
  borders["my_border_2"] = my_border_2
```

#### Usage in Parsers

In the parser, the [`borders`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#borders-instance_method) method gives you access to all borders read from GeoJSON files:

```ruby
borders   # => { "my_border_1" => #<AIPP::Border>, "my_border_2" => #<AIPP::Border> }
```

The border object implements simple nearest point and segment calculations to create arrays of [`AIXM::XY`](https://www.rubydoc.info/gems/aixm/AIXM/XY) which can be used with [`AIXM::Component::Geometry`](https://www.rubydoc.info/gems/aixm/AIXM/Component/Geometry).

See [`AIPP::Border`](https://www.rubydoc.info/gems/aipp/AIPP/Border) for more on this.

### Helpers

Helpers are modules defined in the <tt>lib/aipp/regions/{REGION}/helpers/</tt> directory. All helper modules are required automatically in alphabetic order.

### Fixtures and Patches

Fixtures are static YAML data files in the <tt>lib/aipp/regions/{REGION}/fixtures/</tt> directory. All fixtures are read automatically. Please note that the name of the AIP parser (e.g. `AD-1.3.rb`) must match the name of the corresponding fixture (e.g. `fixtures/AD-1.3.yml`).

When parsed data is faulty or missing, you may fall back to such static data instead. This is where patches come in. You can patch any AIXM attribute setter by defining a patch block inside the AIP parser and accessing the static data via `parser.fixture`:

```ruby
module AIPP
  module LF
    class AD2 < AIP

      patch AIXM::Feature::Airport, :z do |parser, object, value|
        throw(:abort) unless value.nil?
        throw(:abort, 'fixture missing') unless z = parser.fixture.dig(object.id, 'z')
        AIXM.z(z, :qnh)
      end

    end
  end
end
```

The patch receives the object and the value which is about to be assigned. It should implement something along these lines:

* If the value is okay, `throw(:abort)` to leave the patch block without touching anything.
* Otherwise, try to fetch a better value e.g. from the fixtures. If no better value can be found (e.g. outdated fixtures), `throw(:abort, "reason")` to leave the patch block and fail with a useful error message which contains the reason thrown.
* At last, build and return the value object which will be assigned instead of the original value.

In case the `object` does not carry enough details, you can access instance variables of the parser like so:

```ruby
parser.instance_variable_get(:@instance_variable)
```

### Source File Line Numbers

In order to reference the source of an AIXM/OFMX feature, it's necessary to know the line number where a particular node occurs in the HTML source file. You can ask any HTML element as follows:

```ruby
tr.line
```

### Errors

You should `fail` on fatal problems which must be fixed. The `--debug-on-error` command line argument will open a debug session when such an error occurs. Issue errors as usual:

```ruby
fail "my message"
```

### Warnings

You should `warn` on non-fatal problems which should be fixed (default) or might be ignored (`severe: false`). The `--debug-on-warning ID` command line argument will open a debug session when then warning with the given ID occurs. To issue a warning:

```ruby
warn("my message")
warn("my message", severe: false)   # show warning only when --unsevere-warn argument is set
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

#### debug

The [default Ruby debugger](https://github.com/ruby/debug#debug-command-on-the-debug-console) is enabled by default, you can add a breakpoint as usual with:

```ruby
debugger
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
