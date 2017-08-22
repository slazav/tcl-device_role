# Use generator Keysight 33511B (1 channel) as a noise_source.
#
# ID string:
#Agilent
#Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
#
# No channels supported

package require Itcl

itcl::class device_role::noise_source::keysight_33511B {
  inherit device_role::noise_source::interface

  proc id_regexp {} {return {,33511B,}}

  constructor {d ch} {
    if {$ch!={}} {error "channels are not supported for the device $d"}
    set dev $d
    set max_v 20
    set min_v 0.002
  }

  method set_noise {bw volt {offs 0}} {
    $dev cmd SOUR:FUNC NOISE
    $dev cmd OUTP:LOAD INF
    $dev cmd SOUR:VOLT:UNIT VPP
    $dev cmd SOUR:VOLT $volt
    $dev cmd SOUR:VOLT:OFFS $offs
    $dev cmd SOUR:FUNC:NOISE:BANDWIDTH $bw
    $dev cmd OUTP ON
  }
  method set_noise_fast {bw volt {offs 0}} {
    $dev cmd SOUR:VOLT $volt
    $dev cmd SOUR:VOLT:OFFS $offs
    $dev cmd SOUR:FUNC:NOISE:BANDWIDTH $bw
  }
  method get_volt {} { return [$dev cmd "SOUR:VOLT?"] }
  method get_bw   {} { return [$dev cmd "SOUR:FUNC:NOISE:BANDWIDTH?"] }
  method get_offs {} { return [$dev cmd "SOUR:VOLT:OFFS?"] }
}
