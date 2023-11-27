## Common functions for all keysight generators
## In inherit statement this class should go before interface class
## to override dev variable
##
## This class is used in ac_source, dc_source, noise_source, pulse_source roles.
##
## id examples:
## Agilent Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
## Agilent Technologies,33522A,MY50005619,2.03-1.19-2.00-52-00
## Agilent
## Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
## Agilent Technologies,33521B,MY52701054,2.09-1.19-2.00-52-00


itcl::class keysight_gen {

  protected variable chan;      # Channel to use (1,2 or empty).
  protected variable sour_pref; # 2-channel generators need SOUR1 or SOUR2
                                # prefix for some commends, for 1-ch generators
                                # it is better to have it empty instead of SOUR
                                # to support old models.
  protected variable dev;
  protected variable model;

  # redefine lock/unlock methods with our dev
  method lock {} {Device2::lock $dev}
  method unlock {} {Devie2::unlock $dev}

  # Check channel setting and set "chan" and "sour_pref" variables
  constructor {d ch id} {
    # Get the model name from id (using test_id function).
    # Set number of channels for this model.
    set model [test_id $id]
    switch -exact -- $model {
      33220A -
      33509B -
      33511B -
      33520A -
      33521A -
      33521B { set nch 1 }
      33510B -
      33522A { set nch 2 }
      default { error "keysight_gen::get_nch: unknown model: $model" }
    }
    # check channel setting and set "chan" and "sour_pref" variables
    if {$nch == 1} {
      if {$ch!={}} {error "channels are not supported for the device $d"}
      set sour_pref {}
      set chan {}
    }\
    else {
      if {$ch!=1 && $ch!=2} {
        error "$this: bad channel setting: $ch"}
      set sour_pref "SOUR${ch}:"
      set chan $ch
    }
    set dev $d
  }

  # return model name for known generator id
  proc test_id {id} {
    # 1-channel
    if {[regexp {,33220A,} $id]} {return {33220A}}
    if {[regexp {,33509B,} $id]} {return {33509B}}
    if {[regexp {,33511B,} $id]} {return {33511B}}
    if {[regexp {,33520A,} $id]} {return {33520A}}
    if {[regexp {,33521A,} $id]} {return {33521A}}
    if {[regexp {,33521B,} $id]} {return {33521B}}
    # 2-channel
    if {[regexp {,33510B,} $id]} {return {33510B}}
    if {[regexp {,33522A,} $id]} {return {33522A}}
  }

}
