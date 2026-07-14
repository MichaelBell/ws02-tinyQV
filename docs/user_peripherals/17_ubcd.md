<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# Universal Segmented LED Driver

Author: Rebecca G. Bettencourt

Peripheral index: 17

## What it does

This peripheral can be used to drive a variety of segmented LED displays using a variety of encodings:

* BCD on a seven segment display with a wide variety of options for customizing the appearance of digits
* ASCII on a seven segment display with two different “fonts”
* BCD on a [Cistercian numeral](https://en.wikipedia.org/wiki/Cistercian_numerals) display
* BCV (binary-coded *vigesimal*) on a [Kaktovik numeral](https://en.wikipedia.org/wiki/Kaktovik_numerals) display

### BCD mode

This mode displays a decimal digit in BCD on a standard seven segment display. There are registers that affect the display of the digits 6, 7, and 9, and eight different options for handling out-of-range values. These registers allow this peripheral to match the behavior of just about any BCD to seven segment decoder, making it *universal*.

![](23_ubcd.svg)

The registers used in this mode are:

* **/AL** - Active low. If 1, outputs will be HIGH when lit. If 0, outputs will be LOW when lit.
* **/BI** - Blanking input. If 0, all segments will be blank regardless of other inputs, including **/LT**.
* **/LT** - Lamp test. When **/BI** is 1 and **/LT** is 0, all segments will be lit.
* **/RBI** - Ripple blanking input. If the BCD value is zero and **/RBI** is 0, all segments will be blank.
* **V0**, **V1**, **V2** - Selects the output when the BCD value is out of range.
* **X6** - When 1, the extra segment **a** will be lit on the digit 6.
* **X7** - When 1, the extra segment **f** will be lit on the digit 7.
* **X9** - When 1, the extra segment **d** will be lit on the digit 9.
* **/RBO** - Ripple blanking output. 1 when BCD value is nonzero or **/RBI** is 1.

### ASCII mode

This mode displays an ASCII character on a standard seven segment display. Like with the BCD mode, there are registers that affect the display of the digits 6, 7, and 9. There are also two choices of “font” and the option to display lowercase letters as uppercase or as lowercase.

![](23_ascii_f0.svg)

![](23_ascii_f1.svg)

The registers used in this mode are:

* **/AL** - Active low. If 1, outputs will be HIGH when lit. If 0, outputs will be LOW when lit.
* **/BI** - Blanking input. If 0, all segments will be blank regardless of other inputs.
* **FS** - Font select. Selects one of two “fonts.”
* **LC** - Lower case. If 0, lowercase letters will appear as uppercase.
* **X6** - When 1, the extra segment **a** will be lit on the digit 6.
* **X7** - When 1, the extra segment **f** will be lit on the digit 7.
* **X9** - When 1, the extra segment **d** will be lit on the digit 9.
* **/LTR** - Letter. 0 when the input is a letter (A...Z or a...z).

### Cistercian mode

This mode displays a decimal digit in BCD on one quarter of the segmented display for [Cistercian numerals](https://en.wikipedia.org/wiki/Cistercian_numerals) shown below.

![](23_cistercian_display.svg)

The patterns produced for each input value are shown below.

![](23_cistercian_decoder.svg)

The registers used in this mode are:

* **/AL** - Active low. If 1, outputs will be HIGH when lit. If 0, outputs will be LOW when lit.
* **/BI** - Blanking input. If 0, all segments will be blank regardless of other inputs, including **/LT**.
* **/LT** - Lamp test. When **/BI** is 1 and **/LT** is 0, all segments will be lit.

### Kaktovik mode

This mode displays a *vigesimal* (base 20) digit in BCV (binary-coded vigesimal) on the segmented display for [Kaktovik numerals](https://en.wikipedia.org/wiki/Kaktovik_numerals) shown below.

![](23_kaktovik_display.svg)

The patterns produced for each input value are shown below.

![](23_kaktovik_decoder.svg)

The registers used in this mode are:

* **/AL** - Active low. If 1, outputs will be HIGH when lit. If 0, outputs will be LOW when lit.
* **/BI** - Blanking input. If 0, all segments will be blank regardless of other inputs, including **/LT**.
* **/LT** - Lamp test. When **/BI** is 1 and **/LT** is 0, all segments will be lit.
* **/RBI** - Ripple blanking input. If the BCV value is zero and **/RBI** is 0, all segments will be blank.
* **/VBI** - Overflow blanking input. If the BCV value is out of range and **/VBI** is 0, all segments will be blank.
* **/RBO** - Ripple blanking output. 1 when BCV value is nonzero or **/RBI** is 1.
* **V** - Overflow. 1 when BCV value is out of range (greater than or equal to 20).

## Register map

| Address | Name  | Access | Description                                                         |
|---------|-------|--------|---------------------------------------------------------------------|
| 0x00    | DATA  | R/W    | The value to display in BCD, ASCII, or BCV format.
| 0x01    | DCR   | R/W    | Display control register. Contains **/AL**, **/BI**, **/LT**, **/RBI**.
| 0x02    | VCR   | R/W    | Variant control register. Controls the display of digits, letters, and out-of-range values.
| 0x03    | PCR   | R/W    | Peripheral control register. Selects the mode of operation.
| 0x04    | OUT   | R      | Output register. Returns the state of the segmented display.
| 0x05    | STAT  | R      | Status register. Contains **/LTR**, **V**, **/RBO**.

### Display control register format

Used for address 0x01.

| Bit | Mask | Name | Description |
|-----|------|------|-------------|
| 0   | 0x01 | dp0  | Decimal point for BCD units digit or ASCII.
| 1   | 0x02 | dp1  | Decimal point for BCD tens digit.
| 4   | 0x10 | /AL  | Active low. If 1, outputs will be HIGH when lit. If 0, outputs will be LOW when lit.
| 5   | 0x20 | /BI  | Blanking input. If 0, all segments will be blank regardless of other inputs, including **/LT**.
| 6   | 0x40 | /LT  | Lamp test. When **/BI** is 1 and **/LT** is 0, all segments will be lit.
| 7   | 0x80 | /RBI | Ripple blanking input. If the input value is zero and **/RBI** is 0, all segments will be blank.

### Variant control register format

Used for address 0x02.

| Bit | Mask | Name | Description |
|-----|------|------|-------------|
| 0   | 0x01 | V0   | Selects the output when the BCD value is out of range.
| 1   | 0x02 | V1   | Selects the output when the BCD value is out of range.
| 2   | 0x04 | V2   | Selects the output when the BCD value is out of range.
| 3   | 0x08 | FS   | Font select. Selects one of two “fonts” for ASCII input.
| 4   | 0x10 | LC   | Lower case. If 0, lowercase letters will appear as uppercase.
| 5   | 0x20 | X6   | When 1, the extra segment **a** will be lit on the digit 6.
| 6   | 0x40 | X7   | When 1, the extra segment **f** will be lit on the digit 7.
| 7   | 0x80 | X9   | When 1, the extra segment **d** will be lit on the digit 9.

### Peripheral control register format

Used for address 0x03.

| Bit | Mask | Name | Description |
|-----|------|------|-------------|
| 0-2 | 0x07 | MODE | Selects the mode of operation.
| 6   | 0x40 | /OE  | Output enable. If 0, output will be sent to `uo_out`. If 1, output will only be available through address 0x04.
| 7   | 0x80 | /LE  | Latch enable. If 0, input will be taken from the data register. If 1, input will be taken from `ui_in`.

The modes of operation are:

| Mode | Description |
|------|-------------|
| 0    | BCD mode, units digit (low nibble of data register).
| 1    | BCD mode, tens digit (high nibble of data register).
| 2    | ASCII mode.
| 3    | Passthrough mode.
| 4    | Cistercian mode, units digit (low nibble of data register).
| 5    | Cistercian mode, tens digit (high nibble of data register).
| 6    | Kaktovik mode.
| 7    | Passthrough mode.

In passthrough mode, the individual bits of the data register correspond directly to the segments of the display.

### Status register format

Used for address 0x05.

| Bit | Mask | Name | Description |
|-----|------|------|-------------|
| 5   | 0x20 | /LTR | Letter. 0 when ASCII input is a letter (A...Z or a...z).
| 6   | 0x40 | V    | Overflow. 1 when input value is out of range.
| 7   | 0x80 | /RBO | Ripple blanking output. 1 when input value is nonzero or **/RBI** is 1.

## External hardware

For the BCD and ASCII modes, a standard seven-segment display is used.

For the Cistercian mode, a segmented display like the one below is used. There are design files for such a display [here](https://github.com/RebeccaRGB/buck/tree/main/cistercian-display).

![](23_cistercian_display.svg)

For the Kaktovik mode, a segmented display like the one below is used. There are design files for such a display [here](https://github.com/RebeccaRGB/buck/tree/main/kaktovik-display).

![](23_kaktovik_display.svg)
