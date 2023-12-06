######################################################################
# Siglent generators

package require Itcl
package require Device2
namespace eval device_role::burst_source {

itcl::class siglent {
  inherit base
  proc test_id {id} {
    if {[regexp {,SDG1032X,} $id]} {return {SDG1032X}}
    if {[regexp {,SDG1062X,} $id]} {return {SDG1062X}}; # not tested
  }

  variable chan
  variable ch2sync 0; # use ch2 for TTL sync signal
  constructor {d ch id args} {
    set dev $d
    set max_v 20
    set min_v 0.002

    if {$ch!=1 && $ch!=2} { error "unsupported channel: $ch" }
    set chan $ch

    # basic sine output, HiZ
    Device2::ask $dev "C${chan}:BSWV WVTP,SINE"
    Device2::ask $dev "C${chan}:MDWV STATE,OFF"
    Device2::ask $dev "C${chan}:SWWV STATE,OFF"
    Device2::ask $dev "C${chan}:BTWV STATE,OFF"
    Device2::ask $dev "C${chan}:ARWV STATE,OFF"
    Device2::ask $dev "C${chan}:HARM HARMSTATE,OFF"
    Device2::ask $dev "C${chan}:CMBN OFF"
    Device2::ask $dev "C${chan}:INVT OFF"
    Device2::ask $dev "C${chan}:OUTP LOAD,HZ"
    Device2::ask $dev "C${chan}:OUTP PLRT,NOR"

    # set burst mode
    Device2::ask $dev "C${chan}:BTWV CARR,WVTP,SIN"  # carrier waveform
    Device2::ask $dev "C${chan}:BTWV GATE_NCYC,NCYC" # mode (GATE, NCYC)
    Device2::ask $dev "C${chan}:BTWV TRSR,MAN" # trigger (EXT, INT, MAN)
    Device2::ask $dev "C${chan}:BTWV DLAY,0"   # trigger delay,s
    Device2::ask $dev "C${chan}:BTWV TRMD,RISE"  # Trigger out mode
    Device2::ask $dev "C${chan}:BTWV STATE,ON"
  }

  method set_burst {fre amp ncyc {offs 0} {ph 0}} {
    Device2::ask $dev "C${chan}:BTWV CARR,FRQ,$fre"  # carrier frequency
    Device2::ask $dev "C${chan}:BTWV CARR,AMP,$amp"
    Device2::ask $dev "C${chan}:BTWV CARR,OFST,$offs"
    Device2::ask $dev "C${chan}:BTWV TIME,$ncyc"
    Device2::ask $dev "C${chan}:BTWV STPS,$ph"
  }

  method do_burst {} {
    Device2::ask $dev "C${chan}:BTWV MTRIG" # send manual trigger
  }

  method get_volt {}  {
    set l [Device2::ask $dev "C${chan}:BTWV?"]
    regexp {,AMP,([0-9\.]+)V,} $l tmp v
    return $v
  }
  method get_freq {} {
    set l [Device2::ask $dev "C${chan}:BTWV?"]
    regexp {,FRQ,([0-9\.]+)HZ,} $l tmp v
    return $v
  }
  method get_offs {} {
    set l [Device2::ask $dev "C${chan}:BTWV?"]
    regexp {,OFST,([0-9\.]+)V,} $l tmp v
    return $v
  }
  method get_phase {} {
    set l [Device2::ask $dev "C${chan}:BTWV?"]
    regexp {,STPS,([0-9\.]+)} $l tmp v
    return $v
  }
  method get_cycl {} {
    set l [Device2::ask $dev "C${chan}:BTWV?"]
    regexp {,TIME,([0-9\.]+)} $l tmp v
    return $v
  }

  method set_volt {v} { Device2::ask $dev "C${chan}:BTWV CARR,AMP,$v" }
  method set_freq {v} { Device2::ask $dev "C${chan}:BTWV CARR,FRQ,$v" }
  method set_offs {v} { Device2::ask $dev "C${chan}:BTWV CARR,OFST,$v" }
  method set_sycl {v} { Device2::ask $dev "C${chan}:BTWV TIME,$v" }
  method set_phase {v} {
    set v [expr $v-int($v/360.0)*360]
    Device2::ask $dev "C${chan}:BTWV STPS,$v"
  }

}

}; # namespace
