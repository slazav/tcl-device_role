# DeviceRole library -- standard drivers for devices
---

## Main idea

This is a tcl library for implementing some basic interfaces for
measurement devices. The lower level, device server (
https://github.com/slazav/device2 ) knows only device names and
connection details, it can transfer messages to the devices and get
answers, but it knows nothing about their command sets and capabilities.

This library implements interfaces (roles) and checks that
a device can use it. For example, a standard generator can work in a few
simple roles: `ac_source`, `dc_source`, `noise_source`. Interface for
each role has a few basic methods, like `set_volt` and `get_volt` for
`ac_source` role. A high-level measurement program can use this
interface without any knowledge about device model. In this case it's
easy to use different devices without changing code.

DeviceRole interfaces are very simple, they cover only a few basic
operations supported by all devices of this type. On the other hand,
real devices have many different capabilities, they do not fit into
these interfaces. There are two mechanisms for configuring non-standard
device properties:

* When creating a DeviceRole interface, some parameters can be passed to
the driver to configure the device.

* Some reles have a widget, which can be embedded into a measurement
program. Specific drivers can add their controls to this widget.

If more exotec beheviour is needed, then device can be used directly,
without the DeviceRole library.


#### Test devices

Some roles have a TEST device which is not connected to any phisycal
device and produce some fake data. You can use it for testing:

```tcl
set dev [DeviceRole TEST power_supply]
```

---
## Existing roles:

#### power_supply -- a power supply with constant current and constant voltage modes

Parameters and commands (see `power_supply.tcl`):

```tcl
variable max_i; # max current
variable min_i; # min current
variable max_v; # max voltage
variable min_v; # min voltage
variable min_i_step; # min step in current
variable min_v_step; # min step in voltage

set_volt {val}; # set maximum voltage
set_curr {val}; # set current
set_ovp  {val}; # set/unset overvoltage protaction
set_ocp  {val}; # set/unset overcurrent protection
get_curr {};    # measure actual value of voltage
get_volt {};    # measure actual value of current
cc_reset {};    # bring the device into a controlled state in a constant current mode
get_stat {};    # get device status (short string to be shown in the user)
```

Supported devices:

* Keysight N6700B frame with N6731B, N6761A, N6762A modules. Channel (1-4) and range
(<channel>H or <channel>L) for N6761A/N6762A can be selected: ps:1L.
Polarity switch is supported (channel ps:1L:P<n><m>)

* Korad/Velleman/Tenma 72-2550 power supply.

* Korad/Velleman/Tenma 72-2540 power supply.

* TEST

---
#### dc_source -- a simple DC voltage source

Parameters and commands (see `dc_source.tcl`):
```tcl
variable max_v; # max voltage
variable min_v; # min voltage
variable min_v_step; # min step in voltage

set_volt {val}; # set voltage
get_volt {};    # get voltage value
off {};         # turn the output off
```

Supported devices:

* Korad/Velleman/Tenma 72-2535, 72-2540, 72-2550 power supplies.

* SR844 lock-in (auxilary outputs). Use channels 1 or 2 to select the output.

* Keysight/Agilent/HP 33509B, 33511B, 33520A 1-channel generators.

* Keysight/Agilent/HP 33510B and 33522A 2-channel generators. Use
channels 1 or 2 to select the output.

* TEST

---
#### ac_source -- AC voltage source

Parameters and commands (see `ac_source.tcl`):
```tcl
variable max_v; # max voltage
variable min_v; # min voltage

set_ac {freq volt {offs 0}};      # reconfigure the output and set frequency, voltage, offset
get_volt  {};     # get voltage value (Vpp)
get_freq  {};     # get frequency value (Hz)
get_offs  {};     # get offset value (V)
get_phase {};     # get phase value (degrees)

set_volt  {v};    # set voltage value (Vpp)
set_freq  {v};    # set frequency value (Hz)
set_offs  {v};    # set offset value (V)
set_phase {v};    # set phase value (degrees)

set_sync {state}; # set state of front-panel sync connector (0 or 1)
off {};           # turn the output off
```

Supported devices:

* Keysight/Agilent/HP 33509B, 33511B, 33520A, 33220A 1-channel generators.

* Keysight/Agilent/HP 33510B and 33522A 2-channel generators. Use
channels 1 or 2 to select the output. set_ac command sets sync signal to
follow the current channel.

* TEST

---
#### dgen -- double AC voltage source

It is a special role used for making excitation+compensation signals
by 2-channel generators. It consists of two ac_source devices
with a single frequency setting.

---
#### noise_source -- noise source

Parameters and commands (see `noise_source.tcl`):
```tcl
variable max_v; # max voltage
variable min_v; # min voltage

set_noise {bw volt {offs 0}}; # reconfigure the output, set bandwidth, voltage and offset
get_volt  {};    # get voltage value
get_bw    {};    # get bandwidth value
get_offs  {};    # get offset value
off {};          # turn the output off
```

Supported devices:

* Keysight/Agilent/HP 33509B, 33511B, 33520A, 33220A 1-channel generators.

* Keysight/Agilent/HP 33510B and 33522A 2-channel generators. Use channels 1 or 2 to select the output.

* TEST

---
#### burst_source -- burst source

Parameters and commands (see `burst_source.tcl`):
```tcl
variable max_v; # max voltage
variable min_v; # min voltage

set_burst {freq volt cycles {offs 0}};
do_burst  {};

get_volt  {};    # get voltage value
get_freq  {};    # get frequency value
get_offs  {};    # get offset value
get_cycl  {};    # get cycles value
get_phase {};    # get burst phase value

set_volt  {v};    # get voltage value
set_freq  {v};    # get frequency value
set_offs  {v};    # get offset value
set_cycl  {v};    # get cycles value
set_phase {v};    # get burst phase value
```

Supported devices:

* Keysight/Agilent/HP 33509B, 33511B, 33520A, 33220A 1-channel generators.

* Keysight/Agilent/HP 33510B, 33522A, 2-channel generators. Use channels 1 or 2 to select the output.

* TEST

---
#### gauge -- a gauge device

Parameters and commands (see `gauge.tcl`):
```tcl
get {} {}; # do the measurement, return one or more numbers

get_auto {} {}; # set the range automatically, do the measurement

list_ranges  {} {}; # get list of possible range settings
list_tconsts {} {}; # get list of possible time constant settings

set_range  {val} {}; # set the range
set_tconst {val} {}; # set the time constant
get_range  {} {}; # get current range setting
get_tconst {} {}; # get current time constant setting
```

Supported devices:

* Keysight 34401A, 34461A, Keythley-2000 multimeters. Use channels ACI,
DCI, ACV, DCV, R2, R4. Only autorange measurements are supported.

* Keysight 34972A multiplexer. Use space-separaded list of channel settings
<prefix>(<channels>) where <prefix> is ACI, DCI, ACV, DCV, R2, R4 and
channels are comma-separated lists, or colon-separated ranges:
101:105,109 etc.

* SRS SR844, SR840 lock-in amplifiers. Use channels 1 or 2 to select
auxilary input, use channels XY, RT, FXY, FRT to get X, Y, R, Theta,
Frequency combinations. Full range/tconst/autorange support.

* PicoScope, lockin and DC measurements with pico_rec+pico_filter program.
Channels: lockin(<channels>):XY, lockin(<channels>):FXY, DC(<channels>)

* PicoADC with pico_adc program. Channels: comma-separated list of
<channal><mode><range> values. Where channel is 1,2,3 etc., mode is `s`
for single-ended measurement, `d` for double-ended measurement, range is
2500, 1250, 625, 312.5, 156.25, 78.125, or 39.0625 (in millivolts).

* Agilent VS leak detector. Returns three values: leak rate,
output pressure (mbar), input pressure (mbar)

* Pfeiffer Adixen ASM340 leak detector. Returns two values:
leak rate (mbar*l/s), input pressure (mbar).

* Phoenix L300i leak detector. Returns two values:
leak rate (mbar*l/s), input pressure (mbar).

* TEST. Channels R<N>... for N random numbers, T<N> for N increasing values
