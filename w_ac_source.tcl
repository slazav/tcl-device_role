# Configurable interface for ac_source DeviceRole
#
# Constructor: w_ac_source <name> <device> <tkroot> <options>
# Options:
#  -t, -title  -- frame title (default: {})
#  -show_offs  -- show offset entry (default: 0)
#  -show_phase -- show phase entry (default: 0)
#
# Methods:
#
#   set_freq <v>
#   get_freq
#   set_volt <v>
#   get_volt
#   set_offs <v>
#   get_offs
#   set_phase <v>
#   get_phase
#   set_out 0|1   -- set generator output state (on/off)
#   get_out
#   set_ac <freq> <volt> [<offs>] [<phase>]

package require xBlt
package require itcl

namespace eval device_role::ac_source {

##########################################################
itcl::class w_ac_source {

  variable show_offs  {}; # show offset entry
  variable show_phase {}; # show phase entry
  variable title      {}; # frame title

  variable dev      {}; # DeviceRole object
  variable root     {}; # root widget path

  variable freq  0
  variable volt  0
  variable offs  0
  variable phase 0
  variable out   1

  # Constructor: parse options, build interface
  constructor {d tkroot args} {
    set dev $d

    # Parse options.
    set options [list \
      {-t -title}    title     {}\
      {-show_offs}   show_offs  0\
      {-show_phase}  show_phase 0\
    ]
    xblt::parse_options "w_ac_source" $args $options

    # Main frame:
    set root $tkroot
    labelframe $root -text $title -font {-weight bold -size 10}

    # On/Off button, generator label
    checkbutton $root.out -text "Output ON"\
       -variable [itcl::scope out] -command "$this set_out $[itcl::scope out]"
    label $root.gen -text "Device: [$dev get_device]"
    grid $root.out $root.gen -padx 5 -pady 2 -sticky e


    # separator
    frame $root.sep -relief groove -borderwidth 1 -height 2
    grid $root.sep -padx 5 -pady 1 -columnspan 2 -sticky ew

    # Frequency/amplitude/offset/phase entries
    foreach n {freq volt offs phase}\
            t {"Frequency, Hz:" "Voltage, Vpp:" "Offset, V" "Phase, deg:"}\
            e [list 1 1 $show_offs $show_phase] {
      if {!$e} continue
      label $root.${n}_l -text $t
      entry $root.${n} -width 12 -textvariable [itcl::scope $n]
      grid $root.${n}_l $root.${n} -padx 5 -pady 2 -sticky e
    }

    # Apply/Update buttons
    button $root.abtn -text "Apply"  -command "$this on_apply"
    button $root.ubtn -text "Update" -command "$this on_update"
    grid $root.abtn $root.ubtn -padx 3 -pady 3
    on_update

  }

  # write settings to the device
  method on_apply {} {
    $dev set_ac  $freq $volt $offs $phase
    on_update
  }

  # read settings from the device
  method on_update {} {
    set volt  [$dev get_volt]
    set freq  [$dev get_freq]
    set offs  [$dev get_offs]
    set phase [$dev get_phase]
    set out   [$dev get_out]
  }

  # Other methods are just wrappers for DeviceRole
  # All set/get commands also modify values in the interface

  method get_volt {} {
    set volt [$dev get_volt]
    return $volt
  }

  method get_freq {} {
    set freq [$dev get_freq]
    return $freq
  }

  method get_offs {} {
    set offs [$dev get_offs]
    return $offs
  }

  method get_phase {} {
    set phase [$dev get_phase]
    return $phase
  }

  method get_out {} {
    set out [$dev get_out]
    return $out
  }


  method set_ac {f v {o 0} {p {}}} {
    $dev set_ac $f $v $o $p
    on_update
  }

  method set_volt {v} {
    $dev set_volt $v
    get_volt
  }

  method set_freq {v} {
    $dev set_freq $v
    get_freq
  }

  method set_offs {v} {
    $dev set_offs $v
    get_offs
  }

  method set_phase {v} {
    $dev set_phase $v
    get_phase
  }

  method set_out {v} {
    set out $v
    $dev set_out $out
    get_out
  }

}

################
}; # namespace
