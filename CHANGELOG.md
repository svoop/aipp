## Main

#### Additions
* CLI option to set a custom output file

## 2.0.0.pre9

#### Changes
* LS NOTAM: Complete naming, remarks and timesheets

## 2.0.0.pre8

#### Additions
* LS NOTAM: Cross check against DABS
* LS NOTAM: Parse detailed geometry from NOTAM E item

## 2.0.0.pre7

#### Additions
* Region LS NOTAM

#### Breaking Changes
* Drop support for Ruby 3.0
* Rename `url_for` to `origin_for` and introduce origin structures which allow
  for more complex download scenarios such as HTTPS with session or GraphQL.
* Overhaul file/class layout to accommodate other than AIP, implement NOTAM.
* Cache, borders, fixtures, options and config are now dedicated objects
  accessible on `AIPP`.
* Patches are no longer passed the parser instance.

## 1.0.0

#### Breaking Changes
* Switch from individual AIP HTML files to the comprehensive AIP XML
  database dump for the LF region reference implementation.
* Drop the mandatory `URL` helper in favour of a mandatory `url_for` method.
* Renamed default git branch to `main`
* Improve calculation of short feature hash in manifest in order to include
  e.g. geometries of airspaces.

#### Changes
* Switch from `pry` to `debug`

#### Additions
* Unsevere warnings
* Support for .xlsx, .ods and .csv files

## 0.2.6

#### Additions
* Detect duplicate features

#### Changes
* Require Ruby 2.7

## 0.2.5

#### Additions
* LF/AD-2>2.19 (AD navigational aids relevant to VFR)
* Write build and manifest to `~/.aipp/<region>/builds`

#### Changes
* Renamed `~/.aipp/<region>/archive` to `~/.aipp/<region>/sources`

## 0.2.4

#### Additions
* LF/AD-3.1
* Automatically load fixtures for patches

## 0.2.3

#### Additons
* Borders defined as GeoJSON (used by LF/ENR-2.1)
* LF/AD-5.5

#### Breaking Changes
* Renamed `AIPP::AIP#write` method to `AIPP::AIP#add`

## 0.2.2

#### Changes
* Helper modules instead of one monolythic `helper.rb`

#### Additions
* LF/AD-1.3
* LF/AD-1.6
* LF/AD-2

## 0.2.1

#### Changes
* Require Ruby 2.6
* Fix broken downloader

#### Additions
* Support for PDF files

## 0.2.0

#### Changes
* Complete rewrite of the framework in order to allow cross-AIP parsing made necessary due to recent changes in LF AIP.

#### Additions
* LF/ENR-2.1
* Handling of errors and warnings optimized for parser development

#### Removals
* LF/AD-1.5

## 0.1.3

#### Changes
* Summary at end of run

#### Additions
* LF/AD-1.5
* Source file line number evaluation

## 0.1.2

#### Additions:
* LF/ENR-4.3

## 0.1.1

#### Additions:
* LF/ENR-4.1
* Helper modules

## 0.1.0

#### Initial Implementation
* Require Ruby 2.5
* Framework and aip2aixm executable
* LF/ENR-5.1
