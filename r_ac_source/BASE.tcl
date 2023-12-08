######################################################################
# ac_source interface

package require Itcl
package require xBlt; # parse_options
namespace eval device_role::ac_source {

itcl::class base {
  inherit device_role::base
  proc test_id {id} {}
  constructor {args} { chain {*}$args }

  # variables which should be filled by driver:
  public variable max_v; # max voltage
  public variable min_v; # min voltage

  # Interface values: variables to hold values in the tk interface.
  # Should be filled in set/get methods!
  public variable volt
  public variable freq
  public variable offs
  public variable phase
  public variable out


  # methods which should be defined by driver:

  # Reconfigure output, set frequency, voltage, offset
  # If phase is not empty, set phase as well:
  method set_ac {f v {o 0} {p {}}} {
    set volt $v
    set freq $f
    set offs $o
    if {$p ne {}} {set phase $p}
  };

  method get_volt  {} {return $volt};  # get voltage value
  method get_freq  {} {return $freq};  # get frequency value
  method get_offs  {} {return $offs};  # get offset value
  method get_phase {} {return $phase}; # get phase
  method get_out   {} {return $out};   # get output state

  method set_volt {v}  {set volt $v}
  method set_freq {v}  {set freq $v}
  method set_offs {v}  {set offs $v}
  method set_phase {v} {set phase $v}
  method set_out {v}   {set out [expr {$v?1:0}]}; # turn output on/off (without affecting other set/get commands)

  method get_device_info {} {return $dev_info}

  # Non-zero AC shift. I use it to implement self-compensation
  # when using with Femto lock-ins + input transformers. 
  public variable ac_shift 0
  method get_ac_shift {v}  {return $ac_shift}
  method set_ac_shift {v}  {
    set ac_shift $v
    set volt  [get_volt]
  }

  # update/apply interface values
  method on_apply {} {
    set_ac  $freq $volt $offs $phase
    on_update
  }
  method on_update {} {
    set volt  [get_volt]
    set freq  [get_freq]
    set offs  [get_offs]
    set phase [get_phase]
    set out   [get_out]
  }

  # Set state of front-panel sync connector (1|0)
  # This may be useful for 2-channel devices where sync can follow
  # only one of the channels.
  method set_sync  {state} {}; # set state of front-panel sync connector

  ##############################################
  # Make Tk widget
  method make_widget {tkroot args} {
    # Parse options.
    set options [list \
      {-t -title}    title     {}\
      {-show_ac_shift}  show_ac_shift 0\
    ]
    xblt::parse_options "w_ac_source" $args $options

    # Main frame:
    set root $tkroot
    labelframe $root -text "$title: [get_device_info]" -font {-weight bold -size 10}

    # On/Off button, generator label
    checkbutton $root.out -text "Output ON"\
       -variable [itcl::scope out] -command "$this set_out $[itcl::scope out]"
    grid $root.out -padx 5 -pady 2 -sticky w -columnspan 4

    # separator
#    frame $root.sep -relief groove -borderwidth 1 -height 2
#    grid $root.sep -padx 5 -pady 1 -columnspan 4 -sticky ew

    # Frequency/amplitude/offset/phase entries
    label $root.freq_l -text "freq,Hz:"
    entry $root.freq -width 10 -textvariable [itcl::scope freq]
    label $root.volt_l -text "volt,Vpp:"
    entry $root.volt -width 10 -textvariable [itcl::scope volt]
    grid $root.freq_l $root.freq $root.volt_l $root.volt -padx 2 -pady 1 -sticky e

    label $root.offs_l -text "offs,Vpp:"
    entry $root.offs -width 10 -textvariable [itcl::scope offs]
    label $root.phase_l -text "phase,d:"
    entry $root.phase -width 10 -textvariable [itcl::scope phase]
    grid $root.offs_l $root.offs $root.phase_l $root.phase -padx 2 -pady 1 -sticky e

    if {$show_ac_shift} {
      label $root.ac_shift_l -text "AC shift:"
      label $root.ac_shift -width 12 -textvariable [itcl::scope ac_shift]
      grid $root.ac_shift_l $root.ac_shift -padx 2 -pady 1 -sticky e
    }

    # Apply/Update buttons
    button $root.abtn -text "Apply"  -command "$this on_apply"
    button $root.ubtn -text "Update" -command "$this on_update"
    grid $root.abtn $root.ubtn -padx 1 -pady 1 -columnspan 2
    on_update
  }
  ##############################################

}

}; # namespace
