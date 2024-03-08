# LS – Switzerland

## NOTAM API

The NOTAM messages are fetched from the Neway API which is a **non-public**
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

## SHOOT API

Geometries and most shooting details are available on the [geoinformation portal](https://geo.admin.ch) managed by GKG/swisstopo. However, all details as well as a list of active shooting ranges is only available in the original `schiessanzeigen.csv` file compiled by the Swiss army and distributed on the portal as well:

* [geo.admin.ch JSON API](https://api.geo.admin.ch/services/sdiservices.html) [(example)](https://api3.geo.admin.ch/rest/services/api/MapServer/ch.vbs.schiessanzeigen/1201.050?sr=4326&geometryFormat=geojson)
* [schiessanzeigen.csv](https://data.geo.admin.ch/ch.vbs.schiessanzeigen/schiessanzeigen/schiessanzeigen.csv)

As of Feburary 2023, the structure of the CSV is as follows:

### Shooting Ground Description Records

Row | Col | Attribute  | Content   | Mand | Remarks
----|-----|------------|-----------|------|--------
SPL | 0   | Row        | text(3)   | yes  | **"SPL" (aka: Schiessplatz Stammdaten)**
SPL | 1   | Belplan ID | text(8)   | yes  | **ID of the shooting ground from Belplan as "nnnn.nnn" (equal to module# and object#) e.g. "3104.010"**
SPL | 2   | arimmo ID  | text(10)  | yes  | ID of the shooting ground from arimmo e.g. "04.203"
SPL | 3   | Name       | text(50)  | yes  | **Name of the shooting ground, e.g. "DAMMASTOCK / SUSTENHORN"**
SPL | 4   | URL DE     | text(100) | yes  | Info URL in DE from CMS-VBS
SPL | 5   | URL FR     | text(100) | yes  | Info URL in FR from CMS-VBS
SPL | 6   | URL IT     | text(100) | yes  | Info URL in IT from CMS-VBS
SPL | 7   | URL EN     | text(100) | yes  | **Info URL in EN from CMS-VBS**
SPL | 8   | Info name  | text(100) | yes  | Name of the info point e.g. "Koordinationsstelle Terreg 3, Altdorf"
SPL | 9   | Info phone | text(20)  | yes  | **Phone of the info point**
SPL | 10  | Info email | text(100) | no   | **Email of the info point**

### Shooting Ground Activity Records

Row | Col | Attribute      | Content        | Mand | Remarks
----|-----|----------------|----------------|------|--------
BSZ | 0   | Row            | text(3)        | yes  | **"BSZ" (aka: Belegungszeiten eines SPL)**
BSZ | 1   | Belplan ID     | text(8)        | yes  | **ID of the shooting ground from Belplan as "nnnn.nnn" (equal to module# and object#) e.g. "3104.010"**
BSZ | 2   | Act date       | date(yyyymmdd) | yes  | **Datum of activity**
BSZ | 3   | Act time from  | time(hhmm)     | no   | **Time when activity begins**
BSZ | 4   | Act time until | time(hhmm)     | no   | **Time when activity ends**
BSZ | 5   | Locations      | text(50)       | no   | Locations of shooting activity [R2,  (max 50 char)]
BSZ | 6   | Remarks        | text(100)      | no   | Remarks [R2]
BSZ | 7   | URL DE         | text(200)      | no   | Announcement URL DE [R2]
BSZ | 8   | URL FR         | text(200)      | no   | Announcement URL FR [R2]
BSZ | 9   | URL IT         | text(200)      | no   | Announcement URL IT [R2]
BSZ | 10  | URL EN         | text(200)      | no   | **Announcement URL EN [R2]**
BSZ | 11  | Unit           | text(120)      | no   | Military unit involved [R2]
BSZ | 12  | Weapons        | text(50)       | no   | Weapons and ammunition involved [R2]
BSZ | 13  | Positions      | text(50)       | no   | Shooting positions [R2]
BSZ | 14  | Coordinates    | text(25)       | no   | Shooting coordinates [R2]
BSZ | 15  | Vertex height  | number         | no   | **Max height of activity [R2]**
BSZ | 16  | DABS           | boolean        | no   | **Relevant for DABS (formerly KOSIF): 0=no, 1=yes [R2]**
BSZ | 17  | No shooting    | boolean        | no   | **0=no, 1=yes [R2]**

### Total Records

Row | Col | Attribute  | Content                   | Mand | Remarks
----|-----|------------|---------------------------|------|--------
TOT | 0   | Row        | text(3)                   | yes  | "TOT" (aka: Total)
TOT | 1   | Created at | datetime(yyyymmddhhmmss)  | yes  | Date and time of CSV creation
TOT | 2   | SPL count  | number                    | yes  | Number of SPL records

### Safety Margins

The max height (BSZ col 15) has to be treated as an advisory value, not a guarantee:

If no value is given, the ammunition *should* not exceed 250m above ground. However, regulations for certain ammunition types allow for higher peaks. As of March 2023, 6cm mortars *may* reach up to 500m and future weapon systems *may* even go beyond that.

To account for this, the two constants `DEFAULT_Z` and `SAFETY` should be revisited from time to time.

## Asynchronous Use

### Command Line Arguments

When used asynchronously, the following command line arguments should be considered:

* `-c` – clear cache (mandatory to create builds more often than once per hour)
* `-f` – continue on non-fatal errors such as if the validation fails
* `-q` – suppress all informational output
* `-x` – crossload fixed versions of malformed NOTAM

### Monitoring

Any output on STDERR should trigger an alert.

## References

* [skybriefing](https://www.skybriefing.com)
* [skybriefing contact (aka: LS NOF)](https://www.skybriefing.com/support)
* [AIM Data Catalogue](https://www.aerodatacat.ch)
* [DABS](https://www.skybriefing.com/de/dabs)
* [NOTAM Info](https://notaminfo.com/switzerlandmap)
