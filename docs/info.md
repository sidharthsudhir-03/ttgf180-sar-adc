## How it works

8-bit SAR ADC with a differential input (VINP on ua[0], VINN on ua[1]).
The SAR logic performs a binary search using a capacitive DAC and a comparator. Work in progress.

## How to test

Apply a differential input on ua[0]/ua[1], pulse START (ui[0]), and read D7..D0 on uo_out
once BUSY (uio[0]) goes low.

## External hardware

None.
