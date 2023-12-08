######################################################################
# lock-in interface

package require Itcl
package require xBlt; # parse_options
namespace eval device_role::lock-in {

itcl::class base {
  inherit device_role::base
  proc test_id {id} {}
  constructor {args} { chain {*}$args }

  ##################
  # variables to hold measured values (for interface)
  variable M; # range
  variable status {OK}; # status

  ##################
  # methods which should be defined by driver:
  method get {} {}; # do the measurement, return two numbers, X and Y, Vrms
  method get_tconst {} {return 0};      # Time constant, in seconds!
  method get_range  {} {return 0};      # Range in Vrms, same units as X,Y

  # Device status. For some devices $status variable is updated
  # during get command. Use get_status after get to get correct status of
  # the last operation.
  method get_status {} {return $status}; # Device status (text)

  method get_device_info {} {return $dev_info}

  ##################
  # Role-specific Tk widget.
  # It can be modified/replaced in drivers if needed.
  variable root {}

  # create widget
  method make_widget {tkroot args} {
    set widget_options [list\
      {-bar_w}       bar_w    200\
      {-bar_h}       bar_h    10\
      {-title}       title    {Lock-in}
    ]
    xblt::parse_options "lock-in widget" $args $widget_options

    # Main frame:
    set root $tkroot
    labelframe $root -text "$title: [get_device_info]" -font {-weight bold -size 10}

    # Measurement result
    label $root.xy -font {-weight bold -size 10}
    grid $root.xy -columnspan 2 -padx 5 -pady 2 -sticky w

    # Measurement bar
    set w1 [expr $bar_w+1]
    set w2 [expr $bar_w/2+1]
    set h1 [expr $bar_h+1]
    set h2 [expr $bar_h/2+1]
    canvas $root.bar -width $w1 -height $h1
    $root.bar create rectangle 1 1 $w1 $h1 -fill white -outline grey
    $root.bar create polygon $w2 1 $w2 $h1 -outline grey
    $root.bar create polygon 1 $h2 $w1 $h2 -outline grey
    grid $root.bar -padx 5 -pady 2 -sticky we -columnspan 2

    # Status text
    label $root.status -font {-weight bold -size 10}
    grid $root.status -columnspan 2 -padx 5 -pady 2 -sticky w
  }

  # is the widget used?
  method has_widget {} {
    return [expr {$root ne {} && [winfo exists $root.bar]}]
  }

  # this should be called in the get command
  method update_interface {X Y status} {
    if {![has_widget]} return

    set bar_w [expr [$root.bar cget -width] - 1]
    set bar_h [expr [$root.bar cget -height] - 1]
    set w0 [expr $bar_w/2+1]
    set wx [expr int((1.0+$X/$M)*0.5*$bar_w)]
    set wy [expr int((1.0+$Y/$M)*0.5*$bar_w)]
    set h1 [expr $bar_h+1]
    set h2 [expr $bar_h/2+1]
    $root.bar delete data
    $root.bar create rectangle $w0 2   $wx [expr $bar_h/2+1]\
              -fill darkgreen -width 0 -tags data
    $root.bar create rectangle $w0 [expr $bar_h/2+2] $wy $h1\
              -fill darkcyan -width 0 -tags data
    # Format values for the interface
    $root.xy configure -text [format "%8.3e, %8.3e Vrms" $X $Y]
    $root.status configure -text $status -fg [expr {$status eq "OK"? "darkgreen":"red"}]
  }

}

}; # namespace
