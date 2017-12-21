# Use HP/Agilent/Keysight 2-channel generators
# as an ac_source.
#
# ID string:
# Agilent Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
# Agilent Technologies,33522A,MY50005619,2.03-1.19-2.00-52-00
#
# Use channels 1 or 2 to set output

package require Itcl

itcl::class device_role::ac_source::keysight_2ch {
  inherit device_role::ac_source::interface

  variable chan;  # channel to use (1..2)

  proc id_regexp {} {return {,(33510B|33522A),}}

  constructor {d ch} {
    if {$ch!=1 && $ch!=2} {
      error "$this: bad channel setting: $ch"}
    set chan $ch

    set dev $d
    set max_v 20
    set min_v 0.002
  }

  method set_ac {freq volt {offs 0}} {
    $dev cmd SOUR${chan}:FUNC SIN
    $dev cmd OUTP${chan}:LOAD INF
    $dev cmd SOUR${chan}:VOLT:UNIT VPP
    $dev cmd SOUR${chan}:VOLT $volt
    $dev cmd SOUR${chan}:VOLT:OFFS $offs
    $dev cmd SOUR${chan}:FREQ $freq
    $dev cmd OUTP:SYNC:SOUR CH${chan}
  }

  method set_ac_fast {freq volt {offs 0}} {
    $dev cmd SOUR${chan}:APPLY:SIN $freq,$volt,$offs
  }

  method off {} {
    $dev cmd SOUR${chan}:APPLY:SIN 1,$min_v,0
    $dev cmd OUTP${chan} OFF
  }

  method get_volt {} { return [$dev cmd "SOUR${chan}:VOLT?"] }
  method get_freq {} { return [$dev cmd "SOUR${chan}:FREQ?"] }
  method get_offs {} { return [$dev cmd "SOUR${chan}:VOLT:OFFS?"] }


}
