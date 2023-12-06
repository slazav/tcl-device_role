######################################################################
# Siglent SDG 2-channel generators

package require Itcl
package require Device2
namespace eval device_role::dc_source {

itcl::class siglent_gen {
  inherit base
  proc test_id {id} {
    if {[regexp {,SDG1032X,} $id]} {return {SDG1032X}}
    if {[regexp {,SDG1062X,} $id]} {return {SDG1062X}}; # not tested
  }

  constructor {args} {
    chain {*}$args
    set max_v 20
    set min_v -20
    if {$dev_chan=={}} { error "empty channel (use :1 or :2)" }
    if {$dev_chan!=1 && $dev_chan!=2} { error "unsupported channel: $dev_chan" }

    # basic sine output, HiZ
    Device2::ask $dev_name "C${dev_chan}:BSWV WVTP,DC"
    Device2::ask $dev_name "C${dev_chan}:MDWV STATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:SWWV STATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:BTWV STATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:ARWV STATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:HARM HARMSTATE,OFF"
    Device2::ask $dev_name "C${dev_chan}:CMBN OFF"
    Device2::ask $dev_name "C${dev_chan}:INVT OFF"
    Device2::ask $dev_name "C${dev_chan}:OUTP LOAD,HZ"
    Device2::ask $dev_name "C${dev_chan}:OUTP PLRT,NOR"
  }

  method set_volt {v} {
    # check if output is off:
    set l [Device2::ask $dev_name "C${dev_chan}:OUTP?"]
    regexp {OUTP (ON|OFF),} $l tmp o
    if {$o eq {OFF}} { Device2::ask $dev_name "C${dev_chan}:OUTP ON" }
    Device2::ask $dev_name "C${dev_chan}:BSWV OFST,$v"
  }
  method off {} {
    Device2::ask $dev_name "C${dev_chan}:BSWV OFST,0"
    Device2::ask $dev_name "C${dev_chan}:OUTP OFF"
  }
  method get_volt {} {
    set l [Device2::ask $dev_name "C${dev_chan}:BSWV?"]
    regexp {,OFST,([0-9\.]+)V} $l tmp v
    return $v
  }
}

}; # namespace
