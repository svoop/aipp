# AIPP NOTAM Module

## Cache Time Window

The default time window for NOTAM is the hour of day. This means:

* Source data is downloaded and cached based on the hour of the day.
* The effective date and time is rounded down to the previous full hour.

To force a rebuild within this time window, you have to clean the cache using the `-c` command line argument.

### Soft Fail and Crossload

Malformed NOTAM which cannot be processed normally cause the build to fail. The `-f` command line argument changes this behaviour to skip the malformed NOTAM, issue a warning and continue.

To fix broken NOTAM, you can set a crossload directory with `-x`. The contents of this directory must adhere to the following convention:

```
/                          ⬅︎ custom crossload directory
├── LS                     ⬅︎ region
│   └── W2479_22.txt       ⬅︎ NOTAM ID (replace "/" with "_")
└── ED                     ⬅︎ other region
```

If a matching file is found in the crossload directory, it will be used in place of the original, malformed NOTAM.
