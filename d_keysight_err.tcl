## Common functions for devices
## with *STB? and SYST:ERR? commads.

# clear device error
proc dev_err_clear {dev} {
  while {1} {
    set stb [$dev cmd *STB?]
    if {($stb&4) == 0} {break}
    $dev cmd SYST:ERR?
  }
}

# throw device error if any:
proc dev_err_check {dev {msg {}}} {
  set stb [$dev cmd *STB?]
  if {($stb&4) != 0} {
    set err [$dev cmd SYST:ERR?]
    error "Device error: $msg $err"
  }
}

# execute a command and check error status
proc dev_check {dev cmd} {
  dev_err_clear $dev
  set ret [$dev cmd $cmd]
  dev_err_check $dev "can't do $cmd:"
  return $ret
}


proc dev_set_par {dev cmd val} {
  #set verb 1
  set old [$dev cmd "$cmd?"]
  #if {$verb} {puts "get $cmd: $old"}

  # on some generators LOAD? command shows a
  # large number 9.9E37 instead of INF
  if {$val == "INF" && $old > 1e30} {set old "INF"}

  if {$old != $val} {
    #if {$verb} {puts "set $cmd: $val"}
    dev_check $dev "$cmd $val"
  }
}
