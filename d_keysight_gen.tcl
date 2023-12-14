## Common functions for Keysight/Agilent/HP generators
##
## id examples:
## Agilent Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
## Agilent Technologies,33522A,MY50005619,2.03-1.19-2.00-52-00
## Agilent
## Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
## Agilent Technologies,33521B,MY52701054,2.09-1.19-2.00-52-00

# id regexp -- model -- channels -- arb.waveforms -- Fmax -- Vmin -- Vmax
# Arb.waveforms and Fmax can be upgraded?
# Vmin/Vmax given for HighZ mode
set keysight_gen_table {
  {{,33220A,} {33220A} 1 1 20e6  0.020 20.00}
  {{,33250A,} {33250A} 1 1 80e6  0.020 20.00}
  {{,33509B,} {33509B} 1 0 20e6  0.002 20.00}
  {{,33510B,} {33510B} 2 0 20e6  0.002 20.00}
  {{,33511B,} {33511B} 1 1 20e6  0.002 20.00}
  {{,33512B,} {33512B} 2 1 20e6  0.002 20.00}
  {{,33519B,} {33519B} 1 0 30e6  0.002 20.00}
  {{,33520A,} {33520A} 1 0 30e6  0.002 20.00}
  {{,33520B,} {33520B} 2 0 30e6  0.002 20.00}
  {{,33521A,} {33521A} 1 1 30e6  0.002 20.00}
  {{,33521B,} {33521B} 1 1 30e6  0.002 20.00}
  {{,33522A,} {33522A} 2 1 30e6  0.002 20.00}
  {{,33522B,} {33522B} 1 1 30e6  0.002 20.00}
  {{,33611A,} {33611A} 1 1 80e6  0.002 20.00}
  {{,33612A,} {33612A} 2 1 80e6  0.002 20.00}
  {{,33621A,} {33621A} 1 1 120e6 0.002 20.00}
  {{,33622A,} {33622A} 2 1 120e6 0.002 20.00}
}

# Return model name for known generator id.
proc keysight_gen_model {id} {
  foreach g $::keysight_gen_table {
    set re  [lindex $g 0]
    if {[regexp $re $id]} {return [lindex $g 1]}
  }
  return {}
}

# Return source prefix for a given model and channel number.
# 2-channel generators need SOUR1 or SOUR2 prefix for some commends,
# for 1-ch generators it is better to have it empty instead of SOUR
# to support old models.
proc keysight_gen_spref {model chan} {
  foreach g $::keysight_gen_table {
    set m  [lindex $g 1]
    set c  [lindex $g 2]
    if {$m ne $model} {continue}
    if {$c==1} {
      if {$chan!={}} {error "non-empty channel for device $model"}
      return {}
    }
    else {
      if {$chan!=1 && $chan!=2} {
        error "bad channel for device $model: $chan (1 or 2 expected)"
      }
      return "SOUR${chan}:"
    }
  }
  error "keysight_gen_spref: unknown model: $model"
}
