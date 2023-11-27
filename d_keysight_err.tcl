## Common functions for devices
## with *STB? and SYST:ERR? commads.

# clear device error
proc dev_err_clear {dev} {
  while {1} {
    set stb [Device2::ask $dev *STB?]
    if {($stb&4) == 0} {break}
    Device2::ask $dev SYST:ERR?
  }
}

# throw device error if any:
proc dev_err_check {dev {msg {}}} {
  set stb [Device2::ask $dev *STB?]
  if {($stb&4) != 0} {
    set err [Device2::ask $dev SYST:ERR?]
    error "Device error: $msg $err"
  }
}

# execute a command and check error status
proc dev_check {dev cmd} {
  dev_err_clear $dev
  set ret [Device2::ask $dev $cmd]
  dev_err_check $dev "can't do $cmd:"
  return $ret
}

# read parameter, set new value if it is different
proc dev_set_par {dev par val} {
  set old [Device2::ask $dev "$par?"]

  # on some generators LOAD? command shows a
  # large number 9.9E37 instead of INF
  if {$val == "INF" && $old > 1e30} {set old "INF"}

  if {$old != $val} { dev_check $dev "$par $val" }
}
