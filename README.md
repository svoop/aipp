[![Version](https://img.shields.io/gem/v/aipp.svg?style=flat)](https://rubygems.org/gems/aipp)
[![Tests](https://img.shields.io/github/workflow/status/svoop/aipp/Test.svg?style=flat&label=tests)](https://github.com/svoop/aipp/actions?workflow=Test)
[![Donorbox](https://img.shields.io/badge/donate-on_donorbox-yellow.svg)](https://donorbox.org/bitcetera)

# AIPP

Parser for aeronautical information available online.

This gem incluces executables to download and parse aeronautical information (HTML, PDF, XSLX, ODS and CSV), then build and export is as [AIXM](https://github.com/svoop/aixm) or [OFMX](https://github.com/openflightmaps/ofmx/wiki).

* [Homepage](https://github.com/svoop/aipp)
* [Rubydoc](https://www.rubydoc.info/gems/aipp/AIPP)
* Author: [Sven Schwyn - Bitcetera](https://bitcetera.com)

## Table of Contents

[Install](#label-Install) <br>
[Usage](#label-Usage) <br>
[Regions](#label-Regions) <br>
[Storage](#label-Storage) <br>
[References](#label-References) <br>
[Development](#label-Development)

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

If you're familiar with [Bundler](https://bundler.io) powered Ruby projects, you might prefer to add the following to your <samp>Gemfile</samp> or <samp>gems.rb</samp>:

```ruby
gem aipp
```

And then install the bundle:

```
bundle install --trust-policy MediumSecurity
```

## Usage

AIPP parses different kind of information sources. The parsers are organized in three levels:

```
region            ⬅︎ aeronautical region such as "LF" (France)
└── module        ⬅︎ subject area such as "AIP" or "NOTAM"
    └── section   ⬅︎ part of the subject area such as "ENR-2.1" or "aerodromes"
```

The following modules are currently available:

Module | Content | Executables | Cache
-------|---------|-------------|------
AIP | aeronautical information publication | `aip2aixm` and `aip2ofmx` | by AIRAC cycle
NOTAM | notice to airmen | `notam2aixm` and `notam2ofmx` | by effective date and time

To list all available regions and sections for a given module:

```
aip2aixm --list
```

See the built-in help for all options:

```
notam2aixm --help
```

Example: You wish to build the complete OFMX file for the current AIRAC cycle AIP of the region LF:

```
aip2ofmx -r LF
```

You'll find the OFMX file in the current directory if the binary exits successfully.

## Regions

To implement a region, you have to create a directory <samp>lib/aipp/regions/{REGION}/</samp> off the gem root and then subdirectories for each module as well as for support files. Here's a simplified overview for the region "LF" (France):

```
LF/                         ⬅︎ region "LF"
├── README.md
├── aip                     ⬅︎ module "AIP"
│   ├── AD-2.rb             ⬅︎ section "AD-2"
│   └── ENR-4.3.rb          ⬅︎ section "ENR-4.3"
├── notam                   ⬅︎ module "NOTAM"
│   ├── AD.rb               ⬅︎ section "AD"
│   └── ENR.rb              ⬅︎ section "ENR"
├── borders
│   ├── france_atlantic_coast.geojson
│   └── france_atlantic_territorial_sea.geojson
├── fixtures
│   └── aerodromes.yml
└── helpers
    ├── base.rb
    └── surface.rb
```

:warning: All paths from here on forward are relative to the region directory.

### Parsers

Say, you want to parse AIP ENR-4.1. You have to create the file <samp>aip/ENR-4.1.rb</samp> which defines the class `ENR41` as follows:

```ruby
module AIPP::LF::AIP
  class ENR41 < AIPP::AIP::Parser
    depends_on :ENR21, :ENR22   # declare dependencies to other parsers
    (...)
  end
end
```

Another parser might target en-route NOTAM and therefore has to go to <samp>notam/ENR.rb</samp> like so:

```ruby
module AIPP::LF::NOTAM
  class ENR < AIPP::NOTAM::Parser
    (...)
  end
end
```

<table>
  <tr>
    <td>⚠️</td>
    <td>Parser files and classes may follow AIP naming conventions such as <samp>ENR-4.1.rb</samp>. However, you're free to use arbitrary naming for parser files like <samp>navaids.rb</samp> (e.g. if you're working with one big data source which contains the full AIP dataset you'd like to split into smaller parts).</td>
  </tr>
</table>

The class has to implement some methods either in the class itself or in a [helper](#Helpers) included by the class.

#### Mandatory `parse` Method

The class must implement the `parse` method which contains the code to read, parse and write the data:

```ruby
module AIPP::LF::AIP
  class ENR41 < AIPP::AIP::Parser

    def parse
      html = read             # read the Nokogiri::HTML5 document
      feature = (...)         # build the feature
      add(feature: feature)   # add the feature to AIXM::Document
    end

  end
end
```

Some AIP may be split over several files which require a little more code to load the individual HTML source files:

```ruby
module AIPP::LF::AIP
  class AD2 < AIPP::AIP::Parser

    def parse
      %i(one two three).each do |part|
        html = read("#{aip}.#{part}")   # read with a non-standard name
        support_html = read('AD-0.6')   # maybe read necessary support documents
        (...)
      end
    end

  end
end
```

The parser has access to the following methods:

Method | Description
-------|------------
[`section`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#section-instance_method) | current section (e.g. `ENR-2.1` or `aerodromes`)
[`read`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#read-instance_method) | download, cache and read a document from source
[`add`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#add-instance_method) | add a [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)
[`find`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#find-instance_method) | find previously written [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)s by object
[`find_by`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#find_by-instance_method) | find previously written [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)s by class and attribute values
[`unique`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#unique-instance_method) | prevent duplicate [`AIXM::Feature`](https://www.rubydoc.info/gems/aixm/AIXM/Feature)s
[`given`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#given-instance_method) | inline condition for assignments
[`link_to`](https://www.rubydoc.info/gems/aipp/AIPP/Parser#link_to-instance_method) | optionally checked Markdown link

Equally available is the current runtime environment. All of the following objects behave like `OpenStruct`:

Method | Description
-------|------------
[`AIPP.cache`](https://www.rubydoc.info/gems/aipp/AIPP/Enrivonment/Cache) | cache to make transient objects available across AIPs
[`AIPP.borders`](https://www.rubydoc.info/gems/aipp/AIPP/Enrivonment/Borders) | [borders](#Borders) of the current region
[`AIPP.fixtures`](https://www.rubydoc.info/gems/aipp/AIPP/Enrivonment/Fixtures) | [fixtures](#Fixtures) of the current region
[`AIPP.options`](https://www.rubydoc.info/gems/aipp/AIPP/Environment/Options) | arguments read from <samp>aip2aixm</samp> or <samp>aip2ofmx</samp> respectively
[`AIPP.config`](https://www.rubydoc.info/gems/aipp/AIPP/Environment/Config) | configuration read from <samp>config.yml</samp>

To make the parser code more readable, a few core extensions are provided:

* [`Object#blank` (ActiveSupport)](https://www.rubydoc.info/gems/activesupport/Object#blank%3F-instance_method)
* [`NilClass`](https://www.rubydoc.info/gems/aipp/NilClass)
* [`Integer`](https://www.rubydoc.info/gems/aipp/Integer)
* [`String` (ActiveSupport)](https://www.rubydoc.info/gems/activesupport/String)
* [`String`](https://www.rubydoc.info/gems/aipp/String)
* [`Array`](https://www.rubydoc.info/gems/aipp/Array)
* [`Hash`](https://www.rubydoc.info/gems/aipp/Hash)
* [`Enumerable`](https://www.rubydoc.info/gems/aipp/Enumerable)
* [`DateTime` (ActiveSupport)](https://www.rubydoc.info/gems/activesupport/DateTime)
* [`Nokogiri`](https://www.rubydoc.info/gems/aipp/Nokogiri)

#### Mandatory `url_for` Method

The class must implement the `url_for` method which returns the URL from where to download a specific document (e.g. AIP file):

```ruby
module AIPP::LF::AIP
  class AD2 < AIPP::AIP::Parser

    def url_for(document)
      # build and return the download URL for the aip file
    end

  end
end
```

There are a few things to note about `url_for`:

* If the returned string begins with a protocol like `https:`, the downloader will fetch the file from there.
* If the returned string begins with `postgresql:` or `mysql:`, the downloader will perform a SELECT query on the database, convert the result to XML.
* If the returned string is just a file name, the downloader will look for this exact file in the current local directory.

See [Downloader](https://www.rubydoc.info/gems/aipp/AIPP/Downloader) for more on protocols and recognized file types.

For performance, downloads are cached and subsequent runs will use the cached data rather than fetching the sources anew. Each module defines a cache scope, see the [table of modules above](#label-Usage). You can discard existing and rebuild caches by use of the `--clean` CLI option.

#### Optional `setup` Method

The class may implement the `setup` method. If present, it will be called when this parser is instantiated:

```ruby
module AIPP::LF::AIP
  class AD2 < AIPP::AIP::Parser

    def setup
      AIXM.config.voice_channel_separation = :any
      AIPP.cache.setup_at ||= Time.now
    end

  end
end
```

### Helpers

Helpers are mixins defined in the <samp>helpers/</samp> subdirectory. All helpers are required automatically in alphabetic order.

### Borders

AIXM knows named borders for country boundaries. However, you might need additional borders which don't exist as named borders.

You can define additional borders as [`AIPP::Border`](https://www.rubydoc.info/gems/aipp/AIPP/Border) objects in two ways.

#### From GeoJSON

Create simple GeoJSON files in the <samp>borders/</samp> subdirectory, for example this `my_border_1.geojson`:

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

<table>
  <tr>
    <td>⚠️</td>
    <td>The GeoJSON file must consist of exactly one `GeometryCollection` which may contain any number of `LineString` geometries. Only `LineString` geometries are recognised! To define a closed polygon, the first coordinates of a `LineString` must be identical to the last coordinates.</td
  </tr>
</table>

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

### Fixtures

Fixtures are static YAML data files in the <samp>fixtures/</samp> subdirectory. All fixtures are read automatically, e.g. the contents of the <samp>lib/aipp/regions/{REGION}/fixtures/aerodromes.yml</samp> will be available from `AIPP.fixtures.aerodromes`.

Read on for how to best use fixtures.

### Patches

When parsed data is faulty or missing, you may fall back to fixtures instead. This is where patches come in. You can patch any AIXM attribute setter by defining a patch block inside the AIP parser and accessing the static data via `parser.fixture`:

```ruby
module AIPP::LF::AIP
  class AD2 < AIP

    patch AIXM::Feature::Airport, :z do |object, value|
      throw(:abort) unless value.nil?
      throw(:abort, 'fixture missing') unless z = AIPP.fixtures.aerodromes.dig(object.id, 'z')
      AIXM.z(z, :qnh)
    end

  end
end
```

The patch receives the object and the value which is about to be assigned. It should implement something along these lines:

* If the value is okay, `throw(:abort)` to leave the patch block without touching anything.
* Otherwise, try to fetch a better value e.g. from the fixtures. If no better value can be found (e.g. outdated fixtures), `throw(:abort, "reason")` to leave the patch block and fail with a useful error message which contains the reason thrown.
* At last, build and return the value object which will be assigned instead of the original value.

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
```

Less important warnings are only shown if the `--verbose` mode is set:

```ruby
warn("my message", severe: false)
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

## Storage

AIPP uses a storage directory for configuration, caching and in order to keep the results of previous runs. The default location is `~/.aipp`, however, you can pass a different directory with the `--storage` argument.

You'll find a directory for each region and module which contains the following items:

* `sources/`<br>ZIP archives which cache all source files used to build.
* `builds/`<br>ZIP archives of successful builds containing:
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

The advantage of `git diff` is its ability to highlight exactly which part of a line has changed. [Check out this post to learn how](https://www.viget.com/articles/dress-up-your-git-diffs-with-word-level-highlights/).

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

To contribute code, fork the project on GitHub, add your code and submit a pull request:

https://help.github.com/articles/fork-a-repo

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
