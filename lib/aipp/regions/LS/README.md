# LS – Switzerland

## Database

The database connection is read from the `AIPP_MYSQL_URL` environment variable and must comply with the following structure:

```
[USERNAME[:PASSWORD]@HOST[:PORT]/TABLE
```

Make sure you have installed the `ruby-mysql` gem either manually or by adding the following line to the `Gemfile` or `gems.rb`:

```ruby
gem 'ruby-mysql', '~> 3'
```

## References

* [skybriefing](https://www.skybriefing.com)
* [AIM Data Catalogue](https://www.aerodatacat.ch)
* [DABS](https://www.skybriefing.com/de/dabs)
* [NOTAM Info](https://notaminfo.com/switzerlandmap)
