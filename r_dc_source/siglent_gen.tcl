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
  variable chan
  constructor {d ch id} {
    set dev $d
    set max_v 20
    set min_v -20
    if {$ch=={}} { error "empty channel (use :1 or :2)" }
    if {$ch!=1 && $ch!=2} { error "unsupported channel: $ch" }
    set chan $ch

    # basic sine output, HiZ
    Device2::ask $dev "C${chan}:BSWV WVTP,DC"
    Device2::ask $dev "C${chan}:MDWV STATE,OFF"
    Device2::ask $dev "C${chan}:SWWV STATE,OFF"
    Device2::ask $dev "C${chan}:BTWV STATE,OFF"
    Device2::ask $dev "C${chan}:ARWV STATE,OFF"
    Device2::ask $dev "C${chan}:HARM HARMSTATE,OFF"
    Device2::ask $dev "C${chan}:CMBN OFF"
    Device2::ask $dev "C${chan}:INVT OFF"
    Device2::ask $dev "C${chan}:OUTP LOAD,HZ"
    Device2::ask $dev "C${chan}:OUTP PLRT,NOR"
  }

  method set_volt {v} {
    # check if output is off:
    set l [Device2::ask $dev "C${chan}:OUTP?"]
    regexp {OUTP (ON|OFF),} $l tmp o
    if {$o eq {OFF}} { Device2::ask $dev "C${chan}:OUTP ON" }
    Device2::ask $dev "C${chan}:BSWV OFST,$v"
  }
  method off {} {
    Device2::ask $dev "C${chan}:BSWV OFST,0"
    Device2::ask $dev "C${chan}:OUTP OFF"
  }
  method get_volt {} {
    set l [Device2::ask $dev "C${chan}:BSWV?"]
    regexp {,OFST,([0-9\.]+)V} $l tmp v
    return $v
  }
}

}; # namespace
