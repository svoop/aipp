# AIPP AIP Module

## Cache Time Window

The default time window for AIP is the AIRAC cycle. This means:

* Source data is downloaded and cached once for every AIRAC cycle.
* The effective date and time is rounded down to the first day midnight of the AIRAC cycle.

To force a rebuild within this time window, you have to clean the cache using the `-c` command line argument.
