######################################################################
# lock_in role

package require Itcl
package require xBlt
namespace eval device_role::lock-in {

######################################################################
## Interface class.
itcl::class base {
  inherit ::device_role::base

  ##########################################################
  # Methods required by DeviceRole library:
  proc test_id {id} {};

  # pass constructor parameters to the base class
  constructor {args} { chain {*}$args }

  ##########################################################
  # Role-specific methods which should be defined by each driver:

  # Do the measurement, return two numbers, X and Y, [Vrms or Irms]
  # and status string (OK or error):
  method get {} {};

  # Time constant [s]
  method get_tconst {} {return 0};

  # Range, same units as X,Y [Vrms or Irms]
  # This method is usedto update interface in every measurement.
  method get_range {} {return 0};

  # Not all lock-in devices support setting range and time constant.
  # Setting of these (and others) parameters should be done via
  # channel, options, or widget.

  ##########################################################
  # Role-specific Tk widget.
  # It can be modified/replaced in drivers if needed.
  variable root {}

  method make_widget {tkroot args} {
    xblt::parse_options "lock-in widget" $args\
    [list\
      {-bar_w}       bar_w    200\
      {-bar_h}       bar_h    10\
      {-title}       title    {Lock-in}
    ]

    # Main frame:
    set root $tkroot
    labelframe $root -text "$title: $dev_info" -font {-weight bold -size 10}

    # Measurement result
    frame $root.xy
    label $root.xy.x -font {-weight bold -size 10}
    label $root.xy.y -font {-weight bold -size 10}
    pack $root.xy.x $root.xy.y -side right -expand 1
    grid $root.xy -sticky we

    # Measurement bar
    set w1 [expr $bar_w+1]
    set w2 [expr $bar_w/2+1]
    set h1 [expr $bar_h+1]
    set h2 [expr $bar_h/2+1]
    canvas $root.bar -width $w1 -height $h1
    $root.bar create rectangle 1 1 $w1 $h1 -fill white -outline grey
    $root.bar create polygon $w2 1 $w2 $h1 -outline grey
    $root.bar create polygon 1 $h2 $w1 $h2 -outline grey
    grid $root.bar -padx 5 -pady 2 -sticky we

    # Status text
    label $root.status -font {-weight bold -size 10}
    grid $root.status -padx 5 -pady 2 -sticky w
  }

  # Is the widget used?
  method has_widget {} {
    return [expr {$root ne {} && [winfo exists $root.bar]}]
  }

  # called in the get command
  method update_widget {X Y status} {
    if {![has_widget]} return
    set R [get_range]

    set bar_w [expr [$root.bar cget -width] - 1]
    set bar_h [expr [$root.bar cget -height] - 1]
    set w0 [expr $bar_w/2+1]
    set wx [expr int((1.0+$X/$R)*0.5*$bar_w)]
    set wy [expr int((1.0+$Y/$R)*0.5*$bar_w)]
    set h1 [expr $bar_h+1]
    set h2 [expr $bar_h/2+1]
    $root.bar delete data
    $root.bar create rectangle $w0 2   $wx [expr $bar_h/2+1]\
              -fill darkgreen -width 0 -tags data
    $root.bar create rectangle $w0 [expr $bar_h/2+2] $wy $h1\
              -fill darkcyan -width 0 -tags data
    # Format values for the interface and status
    $root.xy.x configure -text [format "%8.3e" $X]
    $root.xy.y configure -text [format "%8.3e" $Y]
    $root.status configure -text $status -fg [expr {$status eq "OK"? "darkgreen":"red"}]
  }

}

######################################################################
} # namespace
