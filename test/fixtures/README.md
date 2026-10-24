# Test fixtures

Real SML telegrams as hex dumps, one per file. They were collected by users of
[SmlLib](https://github.com/spacemanspiff2007/SmlLib) (`tests/test_frames.py`)
from their meters.

| File | Meter | Notes |
| --- | --- | --- |
| `dzg.hex` | DZG (`DZG`) | padding count 4, no power value |
| `holley.hex` | Holley (`HLY`) | many values incl. voltages, currents, frequency |
| `holley_kermit.hex` | Holley (`HLY`) | CRC-16/Kermit instead of X-25, historic `*96`..`*100` values |
| `ebz_anonymized.hex` | EBZ | server ID zeroed, so message CRCs no longer match |
| `emh_signature.hex` | EMH | only `1-0:1.17.0`, a list-typed value |
| `emh.hex` | EMH | import, export and power |
| `iskra.hex` | ISKRA | 48 byte public key (multi-byte TL) |
| `iskra_bare.hex` | ISKRA | messages without transport framing |
