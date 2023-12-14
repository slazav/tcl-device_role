######################################################################
# gauge interface

package require Itcl
package require xBlt
namespace eval device_role::gauge {

itcl::class base {
  inherit device_role::base
  proc test_id {id} {}
  constructor {args} { chain {*}$args }


  ##########################################################
  # variables to be set in the driver:
  variable valnames; # Names of returned values (list)

  # Number of values returned by get command
  method get_val_num {} {
    return [llength valnames]
  }

  # Return text name of the n-th value
  # For lockin it can be X or Y,
  # For multi-channel ADC it could be CH1, CH2, etc.
  method get_val_name {n} {
    if {$n<0 || $n>=[llength valnames]} {
      error "get_val_name: value number $n is out of range 0..[llength valnames]"}
    return [lindex $valnames $n]
  }

  ##########################################################
  # methods which should be defined by driver:
  method get {} {}; # do the measurement, return one or more numbers

  method get_auto {} {}; # set the range automatically, do the measurement

  method list_ranges  {} {}; # get list of possible range settings
  method list_tconsts {} {}; # get list of possible time constant settings

  method set_range  {val} {}; # set the range
  method set_tconst {val} {}; # set the time constant
  method get_range  {} {}; # get current range setting
  method get_tconst {} {}; # get current time constant setting

  method get_status {} {return ""}; # get current status
  method get_status_raw {} {return 0};

  ##########################################################
  # Role-specific Tk widget.
  # It can be modified/replaced in drivers if needed.
  variable root {}
  variable fmts {}

  method make_widget {tkroot args} {
    xblt::parse_options "gauge widget" $args\
    [list\
      {-title}       title    {Gauge}\
      {-fmts}        fmts     {}\
    ]

    # Main frame:
    set root $tkroot
    labelframe $root -text "$title: $dev_info" -font {-weight bold -size 10}

    # Measurement result
    for {set i 0} {$i<[llength $valnames]} {incr i} {
      label $root.l$i -font {-weight bold -size 12} -text "[lindex $valnames $i]:"
      label $root.v$i -font {-weight bold -size 12}
      grid $root.l$i $root.v$i -padx 2 -pady 1 -sticky we
    }
  }

  # Is the widget used?
  method has_widget {} {
    return [expr {$root ne {} && [winfo exists $root]}]
  }

  # this should be called in the get command
  method update_widget {vals} {
    if {![has_widget]} return
    for {set i 0} {$i<[llength $valnames]} {incr i} {
      if {[llength $vals] <= $i} {
        $root.v$i configure -text "-"
        continue
      }
      set v [lindex $vals $i]
      if {[llength $fmts]>$i && $v==$v} {
        set v [format [lindex $fmts $i] $v]
      }
      $root.v$i configure -text "$v"
    }
  }

}
}; # namespace
