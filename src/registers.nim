type
  FlagRegister = object
    carry*: bool
    half_carry*: bool
    subtract*: bool
    zero*: bool


type
  Registers* = object
    a*: uint8
    b*: uint8
    c*: uint8
    d*: uint8
    e*: uint8
    f*: FlagRegister
    h*: uint8
    l*: uint8
    sp*: uint16
    pc*: uint16


func get_bc*(this: Registers): uint16 =
  return (cast[uint16](this.b) shl 8) + cast[uint16](this.c)


proc set_bc*(this: var Registers, bc: uint16): void =
  this.b = cast[uint8]((bc and 0xFF00) shr 8)
  this.c = cast[uint8](bc and 0x00FF)


func get_de*(this: Registers): uint16 =
  return (cast[uint16](this.d) shl 8) + cast[uint16](this.e)


proc set_de*(this: var Registers, de: uint16): void =
  this.d = cast[uint8]((de and 0xFF00) shr 8)
  this.e = cast[uint8](de and 0x00FF)


func get_hl*(this: Registers): uint16 =
  return (cast[uint16](this.h) shl 8) + cast[uint16](this.l)


proc set_hl*(this: var Registers, hl: uint16): void =
  this.h = cast[uint8]((hl and 0xFF00) shr 8)
  this.l = cast[uint8](hl and 0x00FF)
