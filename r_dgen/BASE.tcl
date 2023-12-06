######################################################################
# dgen -- 2-channel generator used for excitation and compenasation
# not used, not tested

package require Itcl
namespace eval device_role::dgen {

itcl::class base {
  inherit device_role::base

  # Two DeviceRole objects, ac_sources.
  # Some interaction between them may be needed.
  variable dev_ac1
  variable dev_ac2

  # same as ac_source!
  proc test_id {id} {}

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # methods for thee first channel (same as ac_source):
  method set_ac {fre amp {offs 0}} { $dev_ac1 set_ac fre amp offs }
  method off {} { $dev_ac1 off }
  method on {} { $dev_ac1 on }
  method get_volt {}  { $dev_ac1 get_volt }
  method get_freq  {} { $dev_ac1 get_freq }
  method get_offs  {} { $dev_ac1 get_offs }
  method get_phase {} { $dev_ac1 get_phase }
  method set_volt {v}  { $dev_ac1 set_volt $v}
  method set_freq {v}  { $dev_ac1 set_freq $v
                         $dev_ac2 set_freq $v}
  method set_offs {v}  { $dev_ac1 set_offs $v}
  method set_phase {v} { $dev_ac1 set_phase [fix_phase $v]}
  method set_sync {state} { $dev_ac1 set_sync $state }

  ## methods for the second channel
  ## there is no set_ac2,set_freq2,get_freq2 methods
  ## because frequency is same for both channels
  method off2 {} { $dev_ac1 off }
  method on2  {} { $dev_ac1 on }
  method get_volt2 {}  { $dev_ac2 get_volt }
  method get_offs2  {} { $dev_ac2 get_offs }
  method get_phase2 {} { $dev_ac2 get_phase }
  method set_volt2 {v}  { $dev_ac2 sel_volt $v}
  method set_offs2 {v}  { $dev_ac2 sel_offs $v}
  method set_phase2 {v} { $dev_ac2 sel_phase [fix_phase $v]}
  method set_sync2 {state} { $dev_ac2 set_sync $state }

  ## Change amplitude and phase in the first channel,
  ## Do corresponding changes in the second channel.
  method change_amp {amp1 ph1} {
    # get old values of excitation amplitude and phase:
    set oamp1 [$dev_ac1 get_volt]
    set oamp2 [$dev_ac2 get_volt]
    set oph1  [$dev_ac1 get_phase]
    set oph2  [$dev_ac2 get_phase]
    # change compensation amplitude and phase
    set amp2 [format "%.4f" [expr {$oamp2/$oamp1*$amp1}]]
    set ph1  [format "%.4f" $ph1
    set ph2  [format "%.4f" [expr {$oph2-$oph1+$ph1}]
    $dev_ac1 set_volt $amp1
    $dev_ac2 set_volt $amp2
    $dev_ph1 set_phase $ph1
    $dev_ph2 set_phase $ph2
  }

}

}; # namespace
