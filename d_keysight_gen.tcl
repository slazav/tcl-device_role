## Common functions for keysight generators
##
## id examples:
## Agilent Technologies,33510B,MY52201807,3.05-1.19-2.00-52-00
## Agilent Technologies,33522A,MY50005619,2.03-1.19-2.00-52-00
## Agilent
## Technologies,33511B,MY52300310,2.03-1.19-2.00-52-00
## Agilent Technologies,33521B,MY52701054,2.09-1.19-2.00-52-00

# Return model name for known generator id.
proc keysight_gen_model {id} {
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
  return {}
}

# Return source prefix for a given model and channel number.
# 2-channel generators need SOUR1 or SOUR2 prefix for some commends,
# for 1-ch generators it is better to have it empty instead of SOUR
# to support old models.
proc keysight_gen_spref {model ch} {
  switch -exact -- $model {
    33220A -
    33509B -
    33511B -
    33520A -
    33521A -
    33521B {
      if {$ch!={}} {error "non-empty channel for device $model"}
      return {}
    }
    33510B -
    33522A {
      if {$ch!=1 && $ch!=2} {
        error "bad channel for device $model: $ch (1 or 2 expected)"
      }
      return "SOUR${ch}:"
    }
    default { error "keysight_gen_spref: unknown model: $model" }
  }
}
