# LS – Switzerland

## Neway API

The NOTAM messages are fetched from the Neway API which is a non-public
GraphQL API.

You have to set the following environment variables:

* `NEWAY_API_URL` – API endpoint
* `NEWAY_API_AUTHORIZATION` – the bearer authentication token

The following query object shows all parameters and columns:

```
{
  queryNOTAMs(
    filter: {
      country: "CHE",       # country as detected by ICAO
      series: ["W", "B"],   # NOTAM series (first letter of name)
      region: "LS",         # FIR region (extracted from name)
      start: 1651449600,    # time window begins (UTC timestamp)
      end: 1651535999       # time window ends (UTC timestamp)
    }
  ) {
    id                      # internal ID
    name                    # NOTAM name
    notamRaw                # raw NOTAM message
    series                  # NOTAM series (first letter of name)
    region                  # FIR region (extracted from name)
    country                 # country as detected by ICAO
    area                    # NOTAM topic area
    effectiveFrom           # validity begins (UTC timestamp)
    validUntil              # validity ends (UTC timestamp)
  }
}
```

## Asynchronous Use

### Command Line Arguments

When used asynchronously, the following command line arguments should be considered:

* `-c` – clear cache (mandatory to create builds more often than once per hour)
* `-f` – continue on non-fatal errors such as if the validation fails
* `-q` – suppress all informational output

### Monitoring

Any output on STDERR should trigger an alert.

## References

* [skybriefing](https://www.skybriefing.com)
* [AIM Data Catalogue](https://www.aerodatacat.ch)
* [DABS](https://www.skybriefing.com/de/dabs)
* [NOTAM Info](https://notaminfo.com/switzerlandmap)
