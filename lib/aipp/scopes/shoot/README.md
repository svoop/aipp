# AIPP Shoot Module

## Cache Time Window

The default time window for SHOOT is the day. This means:

* Source data is downloaded and cached based on the day.
* The effective date and time is rounded down to the previous midnight.

To force a rebuild within this time window, you have to clean the cache using the `-c` command line argument.
