
import strutils

import instructions
import extended
import memory
import registers


type
  CPU* = ref object
    registers*: Registers
    bus*: MemoryBus
    stopped*: bool
    cycles*: uint64


proc getOperand(this: var CPU): uint8 =
  return this.bus.retrieve(this.registers.pc + 1)

proc getOperand16(this: var CPU): uint16 =
  return this.bus.retrieve16(this.registers.pc + 1)

# On 8 bit operations, a half-carry happens on the 3rd bit
func hasHalfCarryAdd(value1: uint8, value2: uint8): bool {.inline.} =
  return ((value1 and 0x0F) + (value2 and 0x0F) and 0x10) == 0x10

# On 8 bit operations, a half-carry happens on the 3rd bit
func hasHalfCarrySubtract(value1: uint8, value2: uint8): bool {.inline.} =
  return ((value1 and 0x0F) - (value2 and 0x0F) and 0x10) == 0x10

# On 16 bit operations, a half-carry happens on the 11th bit
func hasHalfCarryAdd16(value1: uint16, value2: uint16): bool {.inline.} =
  return ((value1 and 0x0FFF) + (value2 and 0x0FFF) and 0x1000) == 0x1000

func genericRelativeJump(this: var CPU, jump: uint8): uint16 =
  let offset: int8 = cast[int8](jump)
  # This is some crazy looking nonsense but is why you shouldn't mix signed
  # and unsigned types
  return cast[uint16](cast[int16](this.registers.pc) + cast[int16](offset)) + 2

# Add value into register A
proc genericAdd(this: var CPU, value: uint8): void =
  let ret: uint16 = cast[uint16](this.registers.a) + cast[uint16](value)
  this.registers.a = cast[uint8](ret)
  this.registers.f.carry = ret >= 0x00FF
  this.registers.f.half_carry = hasHalfCarryAdd(this.registers.a, value)
  this.registers.f.subtract = false
  this.registers.f.zero = this.registers.a == 0

proc genericAdd16(this: var CPU, value1: uint16, value2: uint16): uint16 =
  let ret: uint32 = cast[uint32](value1) + cast[uint32](value2)
  this.registers.f.carry = ret > 0xFFFF
  this.registers.f.half_carry = hasHalfCarryAdd16(value1, value2)
  this.registers.f.subtract = false
  return cast[uint16](ret)

proc genericAnd(this: var CPU, value: uint8): void =
  this.registers.a = this.registers.a and value
  this.registers.f.zero = this.registers.a == 0
  this.registers.f.carry = false
  this.registers.f.subtract = false
  this.registers.f.half_carry = true

proc genericSubtract(this: var CPU, value: uint8): void =
  this.registers.f.subtract = true
  this.registers.f.carry = this.registers.a < value
  this.registers.f.half_carry = (this.registers.a and 0x0F) < (value and 0x0F)
  this.registers.a -= value
  this.registers.f.zero = this.registers.a == 0

proc genericRotate(this: var CPU, value: uint8): uint8 =
  let carry = this.registers.f.carry
  this.registers.f.carry = (value and 0x80) == 0x80
  var ret: uint8 = value shl 1
  if carry:
    ret += 1
  this.registers.f.zero = value == 0
  this.registers.f.subtract = false
  this.registers.f.half_carry = false
  return ret

proc genericXor(this: var CPU, value: uint8): void =
  this.registers.a = this.registers.a xor value
  this.registers.f.zero = this.registers.a == 0
  this.registers.f.carry = false
  this.registers.f.half_carry = false
  this.registers.f.subtract = false

proc genericINC(this: var CPU, value: uint8): uint8 =
  let ret = value + 1
  this.registers.f.zero = ret == 0
  this.registers.f.subtract = false
  this.registers.f.half_carry = (ret and 0xF0) != (value and 0xF0)
  return ret

proc genericDEC(this: var CPU, value: uint8): uint8 =
  let ret = value - 1
  this.registers.f.zero = ret == 0
  this.registers.f.subtract = true
  this.registers.f.half_carry = (ret and 0xF0) != (value and 0xF0)
  return ret

proc executeExtendedOperation(this: var CPU, operation: ExtendedOperation): void =
  # echo "Performing extended operation ", operation
  case operation:
    of ExtendedOperation.BIT_7_H:  # 0x7C, Test bit 7 of H
      this.registers.f.zero = (this.registers.h and 0b10000000) != 0b10000000
      this.registers.f.subtract = false
      this.registers.f.half_carry = true
      this.cycles += 2
    of ExtendedOperation.RL_C:  # 0x11, Rotate C left
      this.cycles += 2
      this.registers.c = this.genericRotate(this.registers.c)
    else:
      echo "UNHANDLED EXTENDED OPERATION ", operation, " 0x", toHex(cast[uint8](operation))
      quit(2)

proc handleNOP(this: var CPU): void =
  this.cycles += 1
  this.registers.pc += 1

proc handleLD_BC_NN(this: var CPU): void =
  this.registers.set_bc(this.getOperand16())
  this.cycles += 3
  this.registers.pc += 3

proc handleLD_BCP_A(this: var CPU): void =
  this.bus.assign(this.registers.get_bc(), this.registers.a)
  this.cycles += 2
  this.registers.pc += 1

# Increment 16-bit BC
proc handleINC_BC(this: var CPU): void =
  this.registers.set_bc(this.registers.get_bc() + 1)
  this.cycles += 2
  this.registers.pc += 1

# Increment B
proc handleINC_B(this: var CPU): void =
  this.registers.b = this.genericInc(this.registers.b)
  this.cycles += 1
  this.registers.pc += 1

# Decrement B
proc handleDEC_B(this: var CPU): void =
  this.registers.b = this.genericDec(this.registers.b)
  this.cycles += 1
  this.registers.pc += 1

proc handleLD_B_N(this: var CPU): void =
  this.registers.b = this.getOperand()
  this.cycles += 2
  this.registers.pc += 2

# Rotate A left with carry
proc handleRLCA(this: var CPU): void =
  this.registers.f.carry = (this.registers.a and 0x80) == 0x80
  this.registers.a = (this.registers.a shl 1)
  if this.registers.f.carry:
    this.registers.a += 1
  this.registers.f.half_carry = false
  this.registers.f.zero = false
  this.registers.f.subtract = false
  this.cycles += 1
  this.registers.pc += 1

# Save SP to given address
proc handleLD_NNP_SP(this: var CPU): void =
  this.bus.assign16(this.getOperand16(), this.registers.sp)
  this.cycles += 5
  this.registers.pc += 3

# Add 16-bit BC to HL
proc handleADD_HL_BC(this: var CPU): void =
  this.registers.set_hl(this.genericAdd16(this.registers.get_hl(), this.registers.get_bc()))
  this.cycles += 2
  this.registers.pc += 1

# Load A from address pointed to by BC
proc handleLD_A_BCP(this: var CPU): void =
  this.registers.a = this.bus.retrieve(this.registers.get_bc())
  this.cycles += 2
  this.registers.pc += 1

# Decrement 16-bit BC
proc handleDEC_BC(this: var CPU): void =
  this.registers.set_bc(this.registers.get_bc() - 1)
  this.cycles += 2
  this.registers.pc += 1

# Increment C
proc handleINC_C(this: var CPU): void =
  this.registers.c = this.genericINC(this.registers.c)
  this.cycles += 1
  this.registers.pc += 1

# Decrement C
proc handleDEC_C(this: var CPU): void =
  this.registers.c = this.genericDEC(this.registers.c)
  this.cycles += 1
  this.registers.pc += 1

proc handleLD_C_N(this: var CPU): void =
  this.registers.c = this.getOperand()
  this.cycles += 1
  this.registers.pc += 1

# Rotate A right with carry
proc handleRRCA(this: var CPU): void =
  this.registers.f.carry = (this.registers.a and 0x01) == 0x01
  this.registers.a = (this.registers.a shr 1)
  if this.registers.f.carry:
    this.registers.a += 0x80
  this.registers.f.half_carry = false
  this.registers.f.zero = false
  this.registers.f.subtract = false
  this.cycles += 1
  this.registers.pc += 1

# Stop processor "STOP"
# Should continue once a button is pressed
proc handleSTOP(this: var CPU): void =
  this.stopped = true
  this.cycles += 1
  this.registers.pc += 1

proc handleLD_DE_NN(this: var CPU): void =
  this.registers.set_de(this.getOperand16())
  this.cycles += 3
  this.registers.pc += 3

# Increment D
proc handleINC_D(this: var CPU): void =
  this.registers.d = this.genericINC(this.registers.d)
  this.cycles += 1
  this.registers.pc += 1

# Decrement D
proc handleDEC_D(this: var CPU): void =
  this.registers.d = this.genericDEC(this.registers.d)
  this.cycles += 1
  this.registers.pc += 1

# Load 8-bit immediate into D
proc handleLD_D_N(this: var CPU): void =
  this.registers.d = this.getOperand()
  this.cycles += 1
  this.registers.pc += 2

# Rotate A left
proc handleRLA(this: var CPU): void =
  this.registers.f.carry = (this.registers.a and 0x80) == 0x80
  this.registers.f.zero = false
  this.registers.f.half_carry = false
  this.registers.f.subtract = false
  this.registers.a = (this.registers.a shl 1)
  if this.registers.f.carry:
    this.registers.a += 1
  this.cycles += 1
  this.registers.pc += 1

# Relative jump by signed immediate
proc handleJR_N(this: var CPU): void =
  this.cycles += 3
  this.registers.pc = this.genericRelativeJump(this.getOperand())

# Add 16-bit DE to HL
proc handleADD_HL_DE(this: var CPU): void =
  this.registers.set_hl(
    this.genericAdd16(
      this.registers.get_hl(),
      this.registers.get_de()
    )
  )
  this.cycles += 2
  this.registers.pc += 1

proc handleLD_A_DEP(this: var CPU): void =
  this.registers.a = this.bus.retrieve(this.registers.get_de())
  this.cycles += 2
  this.registers.pc += 1

# Load 8-bit immediate into E
proc handleLD_E_N(this: var CPU): void =
  this.registers.e = this.getOperand()
  this.cycles += 1
  this.registers.pc += 2

proc handleJR_NZ_N(this: var CPU): void =
  if not this.registers.f.zero:
    this.cycles += 3
    this.registers.pc = this.genericRelativeJump(this.getOperand())
  else:
    this.cycles += 2
    this.registers.pc += 2

proc handleLD_HL_NN(this: var CPU): void =
  this.registers.set_hl(this.getOperand16())
  this.cycles += 3
  this.registers.pc += 3

proc handleLDI_HLP_A(this: var CPU): void =
  let hl = this.registers.get_hl()
  this.bus.assign(hl, this.registers.a)
  this.registers.set_hl(hl + 1)
  this.cycles += 2
  this.registers.pc += 1

proc handleINC_HL(this: var CPU): void =
  this.registers.set_hl(this.registers.get_hl() + 1)
  this.cycles += 2
  this.registers.pc += 1

# Increment H
proc handleINC_H(this: var CPU): void =
  this.registers.h = this.genericINC(this.registers.h)
  this.cycles += 1
  this.registers.pc += 1

# Decrement H
proc handleDEC_H(this: var CPU): void =
  this.registers.h = this.genericDEC(this.registers.h)
  this.cycles += 1
  this.registers.pc += 1

# Relative jump by signed immediate if last result was zero
proc handleJR_Z_N(this: var CPU): void =
  if this.registers.f.zero:
    this.cycles += 3
    this.registers.pc = this.genericRelativeJump(this.getOperand())
  else:
    this.cycles += 2
    this.registers.pc += 2

proc handleINC_DE(this: var CPU): void =
  this.registers.set_de(this.registers.get_de() + 1)
  this.cycles += 2
  this.registers.pc += 1

proc handleLD_SP_NN(this: var CPU): void =
  this.registers.sp = this.getOperand16()
  this.cycles += 3
  this.registers.pc += 3

# Increment L
proc handleINC_L(this: var CPU): void =
  this.registers.l = this.genericINC(this.registers.l)
  this.cycles += 1
  this.registers.pc += 1

# Decrement L
proc handleDEC_L(this: var CPU): void =
  this.registers.l = this.genericDEC(this.registers.l)
  this.cycles += 1
  this.registers.pc += 1

# Load 8-bit immediate into L
proc handleLD_L_N(this: var CPU): void =
  this.registers.l = this.getOperand()
  this.cycles += 1
  this.registers.pc += 1

# Relative jump by signed immediate if last result caused no carry
proc handleJR_NC_N(this: var CPU): void =
  if not this.registers.f.carry:
    this.cycles += 3
    this.registers.pc = this.genericRelativeJump(this.getOperand())
  else:
    this.cycles += 2
    this.registers.pc += 3

# Save A to address pointed by HL, and decrement HL
proc handleLDD_HLP_A(this: var CPU): void =
  let hl = this.registers.get_hl()
  this.bus.assign(hl, this.registers.a)
  this.registers.set_hl(hl - 1)
  this.cycles += 2
  this.registers.pc += 1

# Increment A
proc handleINC_A(this: var CPU): void =
  this.registers.a = this.genericINC(this.registers.a)
  this.cycles += 1
  this.registers.pc += 1

# Decrement A
proc handleDEC_A(this: var CPU): void =
  this.registers.a = this.genericDEC(this.registers.a)
  this.cycles += 1
  this.registers.pc += 1

proc handleLD_A_N(this: var CPU): void =
  this.registers.a = this.getOperand()
  this.cycles += 1
  this.registers.pc += 2

# Copy C to B
proc handleLD_B_C(this: var CPU): void =
  this.registers.b = this.registers.c
  this.cycles += 1
  this.registers.pc += 1

# Copy D to B
proc handleLD_B_D(this: var CPU): void =
  this.registers.b = this.registers.d
  this.cycles += 1
  this.registers.pc += 1

# Copy E to B
proc handleLD_B_E(this: var CPU): void =
  this.registers.b = this.registers.e
  this.cycles += 1
  this.registers.pc += 1

# Copy H to B
proc handleLD_B_H(this: var CPU): void =
  this.registers.b = this.registers.h
  this.cycles += 1
  this.registers.pc += 1

# Copy L to B
proc handleLD_B_L(this: var CPU): void =
  this.registers.b = this.registers.l
  this.cycles += 1
  this.registers.pc += 1

proc handleLD_B_HLP(this: var CPU): void =
  this.registers.b = this.bus.retrieve(this.registers.get_hl())
  this.cycles += 2
  this.registers.pc += 1

# Copy A to B
proc handleLD_B_A(this: var CPU): void =
  this.registers.b = this.registers.a
  this.cycles += 1
  this.registers.pc += 1

# Copy B to C
proc handleLD_C_B(this: var CPU): void =
  this.registers.c = this.registers.b
  this.cycles += 1
  this.registers.pc += 1

# Copy D to C
proc handleLD_C_D(this: var CPU): void =
  this.registers.c = this.registers.d
  this.cycles += 1
  this.registers.pc += 1

# Copy E to C
proc handleLD_C_E(this: var CPU): void =
  this.registers.c = this.registers.e
  this.cycles += 1
  this.registers.pc += 1

# Cp[y H to C
proc handleLD_C_H(this: var CPU): void =
  this.registers.c = this.registers.h
  this.cycles += 1
  this.registers.pc += 1

# Copy L to C
proc handleLD_C_L(this: var CPU): void =
  this.registers.c = this.registers.l
  this.cycles += 1
  this.registers.pc += 1

# Copy value pointed by HL to C
proc handleLD_C_HLP(this: var CPU): void =
  this.registers.c = this.bus.retrieve(this.registers.get_hl())
  this.cycles += 2
  this.registers.pc += 1

proc handleLD_C_A(this: var CPU): void =
  this.registers.c = this.registers.a
  this.cycles += 1
  this.registers.pc += 1

proc handleLD_D_B(this: var CPU): void =
  this.registers.d = this.registers.b
  this.cycles += 1
  this.registers.pc += 1

# Copy C to D
proc handleLD_D_C(this: var CPU): void =
  this.registers.d = this.registers.c
  this.cycles += 1
  this.registers.pc += 1

# Copy E to D
proc handleLD_D_E(this: var CPU): void =
  this.registers.d = this.registers.e
  this.cycles += 1
  this.registers.pc += 1

# Copy H to D
proc handleLD_D_H(this: var CPU): void =
  this.registers.d = this.registers.h
  this.cycles += 1
  this.registers.pc += 1

# Copy L to D
proc handleLD_D_L(this: var CPU): void =
  this.registers.d = this.registers.l
  this.cycles += 1
  this.registers.pc += 1

# Copy value pointed by HL to D
proc handleLD_D_HLP(this: var CPU): void =
  this.registers.d = this.bus.retrieve(this.registers.get_hl())
  this.cycles += 2
  this.registers.pc += 1

# Copy A to D
proc handleLD_D_A(this: var CPU): void =
  this.registers.d = this.registers.a
  this.cycles += 1
  this.registers.pc += 1

# Copy B to E
proc handleLD_E_B(this: var CPU): void =
  this.registers.e = this.registers.b
  this.cycles += 1
  this.registers.pc += 1

# Copy C to E
proc handleLD_E_C(this: var CPU): void =
  this.registers.e = this.registers.c
  this.cycles += 1
  this.registers.pc += 1

# Copy D to E
proc handleLD_E_D(this: var CPU): void =
  this.registers.e = this.registers.d
  this.cycles += 1
  this.registers.pc += 1

# Copy H to E
proc handleLD_E_H(this: var CPU): void =
  this.registers.e = this.registers.h
  this.cycles += 1
  this.registers.pc += 1

# Copy L to E
proc handleLD_E_L(this: var CPU): void =
  this.registers.e = this.registers.l
  this.cycles += 1
  this.registers.pc += 1

# Copy value pointed by HL to E
proc handleLD_E_HLP(this: var CPU): void =
  this.registers.e = this.bus.retrieve(this.registers.get_hl())
  this.cycles += 2
  this.registers.pc += 1

# Copy A to E
proc handleLD_E_A(this: var CPU): void =
  this.registers.e = this.registers.a
  this.cycles += 1
  this.registers.pc += 1

# Copy B to H
proc handleLD_H_B(this: var CPU): void =
  this.registers.h = this.registers.b
  this.cycles += 1
  this.registers.pc += 1

# Copy C to H
proc handleLD_H_C(this: var CPU): void =
  this.registers.h = this.registers.c
  this.cycles += 1
  this.registers.pc += 1

# Copy D to H
proc handleLD_H_D(this: var CPU): void =
  this.registers.h = this.registers.d
  this.cycles += 1
  this.registers.pc += 1

# Copy E to H
proc handleLD_H_E(this: var CPU): void =
  this.registers.h = this.registers.e
  this.cycles += 1
  this.registers.pc += 1

# Copy L to H
proc handleLD_H_L(this: var CPU): void =
  this.registers.h = this.registers.l
  this.cycles += 1
  this.registers.pc += 1

# Copy value pointed by HL to H
proc handleLD_H_HLP(this: var CPU): void =
  this.registers.h = this.bus.retrieve(this.registers.get_hl())
  this.cycles += 2
  this.registers.pc += 1

# Copy A to H
proc handleLD_H_A(this: var CPU): void =
  this.registers.h = this.registers.a
  this.cycles += 1
  this.registers.pc += 1

# Copy B to L
proc handleLD_L_B(this: var CPU): void =
  this.registers.l = this.registers.b
  this.cycles += 1
  this.registers.pc += 1

# Copy C to L
proc handleLD_L_C(this: var CPU): void =
  this.registers.l = this.registers.c
  this.cycles += 1
  this.registers.pc += 1

# Copy D to L
proc handleLD_L_D(this: var CPU): void =
  this.registers.l = this.registers.d
  this.cycles += 1
  this.registers.pc += 1

# Copy E to L
proc handleLD_L_E(this: var CPU): void =
  this.registers.l = this.registers.e
  this.cycles += 1
  this.registers.pc += 1

# Copy H to L
proc handleLD_L_H(this: var CPU): void =
  this.registers.l = this.registers.h
  this.cycles += 1
  this.registers.pc += 1

# Copy value pointed by HL to L
proc handleLD_L_HLP(this: var CPU): void =
  this.registers.l = this.bus.retrieve(this.registers.get_hl())
  this.cycles += 2
  this.registers.pc += 1

# Copy A to L
proc handleLD_L_A(this: var CPU): void =
  this.registers.l = this.registers.a
  this.cycles += 1
  this.registers.pc += 1


proc handleLD_HLP_A(this: var CPU): void =
  this.bus.assign(this.registers.get_hl(), this.registers.a)
  this.cycles += 2
  this.registers.pc += 1

proc handleLD_A_E(this: var CPU): void =
  this.registers.a = this.registers.e
  this.cycles += 1
  this.registers.pc += 1

# Copy value pointed by HL to A
proc handleLD_A_HLP(this: var CPU): void =
  this.registers.a = this.bus.retrieve(this.registers.get_hl())
  this.cycles += 2
  this.registers.pc += 1

# Add B to A
proc handleADD_A_B(this: var CPU): void =
  this.genericAdd(this.registers.b)
  this.cycles += 1
  this.registers.pc += 1

# Add C to A
proc handleADD_A_C(this: var CPU): void =
  this.genericAdd(this.registers.c)
  this.cycles += 1
  this.registers.pc += 1

# Add D to A
proc handleADD_A_D(this: var CPU): void =
  this.genericAdd(this.registers.d)
  this.cycles += 1
  this.registers.pc += 1

# Add E to A
proc handleADD_A_E(this: var CPU): void =
  this.genericAdd(this.registers.e)
  this.cycles += 1
  this.registers.pc += 1

# Add H to A
proc handleADD_A_H(this: var CPU): void =
  this.genericAdd(this.registers.h)
  this.cycles += 1
  this.registers.pc += 1

# Add L to A
proc handleADD_A_L(this: var CPU): void =
  this.genericAdd(this.registers.l)
  this.cycles += 1
  this.registers.pc += 1

# Add A to A
proc handleADD_A_A(this: var CPU): void =
  this.genericAdd(this.registers.a)
  this.cycles += 1
  this.registers.pc += 1

# Subtract B from A
proc handleSUB_B(this: var CPU): void =
  this.genericSubtract(this.registers.b)
  this.cycles += 1
  this.registers.pc += 1

# Subtract C from A
proc handleSUB_C(this: var CPU): void =
  this.genericSubtract(this.registers.c)
  this.cycles += 1
  this.registers.pc += 1

# Subtract D from A
proc handleSUB_D(this: var CPU): void =
  this.genericSubtract(this.registers.d)
  this.cycles += 1
  this.registers.pc += 1

# Subtract E from A
proc handleSUB_E(this: var CPU): void =
  this.genericSubtract(this.registers.e)
  this.cycles += 1
  this.registers.pc += 1

# Subtract H from A
proc handleSUB_H(this: var CPU): void =
  this.genericSubtract(this.registers.h)
  this.cycles += 1
  this.registers.pc += 1

# Subtract L from A
proc handleSUB_L(this: var CPU): void =
  this.genericSubtract(this.registers.l)
  this.cycles += 1
  this.registers.pc += 1

# Logical AND B against A
proc handleAND_B(this: var CPU): void =
  this.genericAnd(this.registers.b)
  this.cycles += 1
  this.registers.pc += 1

# Logical AND C against A
proc handleAND_C(this: var CPU): void =
  this.genericAnd(this.registers.c)
  this.cycles += 1
  this.registers.pc += 1

# Logical AND D against A
proc handleAND_D(this: var CPU): void =
  this.genericAnd(this.registers.d)
  this.cycles += 1
  this.registers.pc += 1

# Logical AND E against A
proc handleAND_E(this: var CPU): void =
  this.genericAnd(this.registers.e)
  this.cycles += 1
  this.registers.pc += 1

# Logical AND H against A
proc handleAND_H(this: var CPU): void =
  this.genericAnd(this.registers.h)
  this.cycles += 1
  this.registers.pc += 1

# Logical AND L against A
proc handleAND_L(this: var CPU): void =
  this.genericAnd(this.registers.l)
  this.cycles += 1
  this.registers.pc += 1

proc handleXOR_A(this: var CPU): void =
  this.genericXor(this.registers.a)
  this.cycles += 1
  this.registers.pc += 1

# Return if last result was not zero
proc handleRET_NZ(this: var CPU): void =
  if not this.registers.f.zero:
    let ret = this.bus.retrieve16(this.registers.sp)
    this.registers.sp += 2
    this.cycles += 5
    this.registers.pc = ret
  else:
    this.cycles += 2
    this.registers.pc += 1

proc handlePOP_BC(this: var CPU): void =
  this.registers.set_bc(this.bus.retrieve16(this.registers.sp))
  this.registers.sp += 2
  this.cycles += 3
  this.registers.pc += 1

proc handleJP_NN(this: var CPU): void =
  echo "Jumping to 0x", this.getOperand16().toHex()
  this.cycles += 1
  this.registers.pc = this.getOperand16()

proc handlePUSH_BC(this: var CPU): void =
  this.registers.sp -= 2
  this.bus.assign16(this.registers.sp, this.registers.get_bc())
  this.cycles += 4
  this.registers.pc += 1

# Return if last result was zero
proc handleRET_Z(this: var CPU): void =
  if this.registers.f.zero:
    let ret = this.bus.retrieve16(this.registers.sp)
    this.registers.sp += 2
    this.cycles += 5
    this.registers.pc = ret
  else:
    this.cycles += 2
    this.registers.pc += 1

proc handleRET(this: var CPU): void =
  let ret = this.bus.retrieve16(this.registers.sp)
  this.registers.sp += 2
  this.cycles += 4
  this.registers.pc = ret

proc handleCB_N(this: var CPU): void =
  this.executeExtendedOperation(ExtendedOperation(this.getOperand()))
  # Note that this is only the time for this instruction, not for the actual
  # extended operation which should increase the cycle count further
  this.cycles += 1
  this.registers.pc += 2

proc handleCALL_NN(this: var CPU): void =
  this.registers.sp -= 2
  this.bus.assign16(this.registers.sp, this.registers.pc + 3)
  this.cycles += 6
  this.registers.pc = this.getOperand()

# Pop 16-bit value from stack into DE
proc handlePOP_DE(this: var CPU): void =
  this.registers.set_de(this.bus.retrieve16(this.registers.sp))
  this.registers.sp += 2
  this.cycles += 3
  this.registers.pc += 1

# Push 16-bit DE onto stack
proc handlePUSH_DE(this: var CPU): void =
  this.registers.sp -= 2
  this.bus.assign16(this.registers.sp, this.registers.get_de())
  this.cycles += 4
  this.registers.pc += 1

proc handleLD_FF_N_AP(this: var CPU): void =
  this.bus.assign(0xFF00'u16 + this.getOperand(), this.registers.a)
  this.cycles += 3
  this.registers.pc += 2

# Pop 16-bit value from stack into HL
proc handlePOP_HL(this: var CPU): void =
  this.registers.set_hl(this.bus.retrieve16(this.registers.sp))
  this.registers.sp += 2
  this.cycles += 3
  this.registers.pc += 1

proc handleLD_FF_C_A(this: var CPU): void =
  this.bus.assign(0xFF00'u16 + this.registers.c, this.registers.a)
  this.cycles += 2
  this.registers.pc += 1

# Jump to 16-bit value pointed by HL
proc handleJP_HL(this: var CPU): void =
  this.cycles += 1
  this.registers.pc = this.registers.get_hl()

# Save A at given 16-bit address
proc handleLD_NNP_A(this: var CPU): void =
  this.registers.a = this.bus.retrieve(this.getOperand16())
  this.cycles += 4
  this.registers.pc += 3

# Call routine at address 0028h
proc handleRST_28(this: var CPU): void =
  this.registers.sp -= 2
  this.bus.assign16(this.registers.sp, this.registers.pc + 1)
  this.cycles += 4
  this.registers.pc = 0x0028'u16

# Load A from address pointed to by (FF00h + 8-bit immediate)
proc handleLD_FF_AP_N(this: var CPU): void =
  this.registers.a = this.bus.retrieve(0xFF00'u16 + this.getOperand())
  this.cycles += 3
  this.registers.pc += 2

# Add signed 8-bit immediate to SP and save result in HL
proc handleLD_HL_SP_N(this: var CPU): void =
  this.registers.f.zero = false
  this.registers.f.subtract = false
  this.registers.set_hl(this.genericAdd16(this.registers.sp, this.getOperand()))
  this.cycles += 3
  this.registers.pc += 2

# Compare 8-bit immediate against A
proc handleCP_N(this: var CPU): void =
  let operand = this.getOperand()
  this.registers.f.subtract = false
  this.registers.f.zero = this.registers.a == operand
  this.registers.f.carry = this.registers.a < operand
  this.registers.f.half_carry = (this.registers.a and 0x0F) < (operand and 0x0F)
  this.cycles += 2
  this.registers.pc += 2

# Call routine at address 0038h
proc handleRST_38(this: var CPU): void =
  this.registers.sp -= 2
  this.bus.assign16(this.registers.sp, this.registers.pc + 1)
  this.cycles += 4
  this.registers.pc = 0x0038'u16

proc execute(this: var CPU, instruction: Instruction): void =
  # echo "OPCODE: ", instruction, " PC: 0x", this.registers.pc.toHex()
  # echo this.registers
  case instruction:
    of Instruction.NOP: this.handleNOP() # No Operation "NOP"
    of Instruction.LD_BC_NN: this.handleLD_BC_NN() # Load 16-bit immediate into BC "LD BC,nn"
    of Instruction.LD_BCP_A: this.handleLD_BCP_A() # Save A to address pointed by BC "LD (BC),A"
    of Instruction.INC_BC: this.handleINC_BC() # Increment 16-bit BC "INC BC"
    of Instruction.INC_B: this.handleINC_B() # Increment B "INC B"
    of Instruction.DEC_B: this.handleDEC_B() # Decrement B "DEC B"
    of Instruction.LD_B_N: this.handleLD_B_N() # Load 8-bit immediate into B "LD B,n"
    of Instruction.RLCA: this.handleRLCA() # Rotate A left with carry "RLC A"
    of Instruction.LD_NNP_SP: this.handleLD_NNP_SP() # Save SP to given address "LD (nn),SP"
    of Instruction.ADD_HL_BC: this.handleADD_HL_BC() # Add 16-bit BC to HL "ADD HL,BC"
    of Instruction.LD_A_BCP: this.handleLD_A_BCP() # Load A from address pointed to by BC "LD A,(BC)"
    of Instruction.DEC_BC: this.handleDEC_BC() # Decrement 16-bit BC "DEC BC"
    of Instruction.INC_C: this.handleINC_C() # Increment C "INC C"
    of Instruction.DEC_C: this.handleDEC_C() # Decrement C "DEC C"
    of Instruction.LD_C_N: this.handleLD_C_N() # Load 8-bit immediate into C "LD C,n"
    of Instruction.RRCA: this.handleRRCA() # Rotate A right with carry "RRC A"
    of Instruction.STOP: this.handleSTOP() # Stop processor "STOP"
    of Instruction.LD_DE_NN: this.handleLD_DE_NN() # Load 16-bit immediate into DE "LD DE,nn"
    # of Instruction.LD_DEP_A: this.handleLD_DEP_A() # Save A to address pointed by DE "LD (DE),A"
    of Instruction.INC_DE: this.handleINC_DE() # Increment 16-bit DE "INC DE"
    of Instruction.INC_D: this.handleINC_D() # Increment D "INC D"
    of Instruction.DEC_D: this.handleDEC_D() # Decrement D "DEC D"
    of Instruction.LD_D_N: this.handleLD_D_N() # Load 8-bit immediate into D "LD D,n"
    of Instruction.RLA: this.handleRLA() # Rotate A left "RL A"
    of Instruction.JR_N: this.handleJR_N() # Relative jump by signed immediate "JR n"
    of Instruction.ADD_HL_DE: this.handleADD_HL_DE() # Add 16-bit DE to HL "ADD HL,DE"
    of Instruction.LD_A_DEP: this.handleLD_A_DEP() # Load A from address pointed to by DE "LD A,(DE"
    # of Instruction.DEC_DE: this.handleDEC_DE() # Decrement 16-bit DE "DEC DE"
    # of Instruction.INC_E: this.handleINC_E() # Increment E "INC E"
    # of Instruction.DEC_E: this.handleDEC_E() # Decrement E "DEC E"
    of Instruction.LD_E_N: this.handleLD_E_N() # Load 8-bit immediate into E "LD E,n"
    # of Instruction.RRA: this.handleRRA() # Rotate A right "RR A"
    of Instruction.JR_NZ_N: this.handleJR_NZ_N() # Relative jump by signed immediate if last result was not zero "JR NZ,n"
    of Instruction.LD_HL_NN: this.handleLD_HL_NN() # Load 16-bit immediate into HL "LD HL,nn"
    of Instruction.LDI_HLP_A: this.handleLDI_HLP_A() # Save A to address pointed by HL, and increment HL "LDI (HL),A"
    of Instruction.INC_HL: this.handleINC_HL() # Increment 16-bit HL "INC HL"
    of Instruction.INC_H: this.handleINC_H() # Increment H "INC H"
    of Instruction.DEC_H: this.handleDEC_H() # Decrement H "DEC H"
    # of Instruction.LD_H_N: this.handleLD_H_N() # Load 8-bit immediate into H "LD H,n"
    # of Instruction.DAA: this.handleDAA() # Adjust A for BCD addition "DAA"
    of Instruction.JR_Z_N: this.handleJR_Z_N() # Relative jump by signed immediate if last result was zero "JR Z,n"
    # of Instruction.ADD_HL_HL: this.handleADD_HL_HL() # Add 16-bit HL to HL "ADD HL,HL"
    # of Instruction.LDI_A_HLP: this.handleLDI_A_HLP() # Load A from address pointed to by HL, and increment HL "LDI A,(HL"
    # of Instruction.DEC_HL: this.handleDEC_HL() # Decrement 16-bit HL "DEC HL"
    of Instruction.INC_L: this.handleINC_L() # Increment L "INC L"
    of Instruction.DEC_L: this.handleDEC_L() # Decrement L "DEC L"
    of Instruction.LD_L_N: this.handleLD_L_N() # Load 8-bit immediate into L "LD L,n"
    # of Instruction.LOG_NOT: this.handleLOG_NOT() # Complement (logical NOT) on A "CPL"
    of Instruction.JR_NC_N: this.handleJR_NC_N() # Relative jump by signed immediate if last result caused no carry "JR NC,n"
    of Instruction.LD_SP_NN: this.handleLD_SP_NN() # Load 16-bit immediate into SP "LD SP,nn"
    of Instruction.LDD_HLP_A: this.handleLDD_HLP_A() # Save A to address pointed by HL, and decrement HL "LDD (HL),A"
    # of Instruction.INC_SP: this.handleINC_SP() # Increment 16-bit HL "INC SP"
    # of Instruction.INC_HLP: this.handleINC_HLP() # Increment value pointed by HL "INC (HL"
    # of Instruction.DEC_HLP: this.handleDEC_HLP() # Decrement value pointed by HL "DEC (HL"
    # of Instruction.LD_HLP_N: this.handleLD_HLP_N() # Load 8-bit immediate into address pointed by HL "LD (HL),n"
    # of Instruction.SCF: this.handleSCF() # Set carry flag "SCF"
    # of Instruction.JR_C_N: this.handleJR_C_N() # Relative jump by signed immediate if last result caused carry "JR C,n"
    # of Instruction.ADD_HL_SP: this.handleADD_HL_SP() # Add 16-bit SP to HL "ADD HL,SP"
    # of Instruction.LDD_A_HLP: this.handleLDD_A_HLP() # Load A from address pointed to by HL, and decrement HL "LDD A,(HL"
    # of Instruction.DEC_SP: this.handleDEC_SP() # Decrement 16-bit SP "DEC SP"
    of Instruction.INC_A: this.handleINC_A() # Increment A "INC A"
    of Instruction.DEC_A: this.handleDEC_A() # Decrement A "DEC A"
    of Instruction.LD_A_N: this.handleLD_A_N() # Load 8-bit immediate into A "LD A,n"
    # of Instruction.CCF: this.handleCCF() # Clear carry flag "CCF"
    of Instruction.LD_B_B: this.handleNOP() # Copy B to B "LD B,B"
    of Instruction.LD_B_C: this.handleLD_B_C() # Copy C to B "LD B,C"
    of Instruction.LD_B_D: this.handleLD_B_D() # Copy D to B "LD B,D"
    of Instruction.LD_B_E: this.handleLD_B_E() # Copy E to B "LD B,E"
    of Instruction.LD_B_H: this.handleLD_B_H() # Copy H to B "LD B,H"
    of Instruction.LD_B_L: this.handleLD_B_L() # Copy L to B "LD B,L"
    of Instruction.LD_B_HLP: this.handleLD_B_HLP() # Copy value pointed by HL to B "LD B,(HL"
    of Instruction.LD_B_A: this.handleLD_B_A() # Copy A to B "LD B,A"
    of Instruction.LD_C_B: this.handleLD_C_B() # Copy B to C "LD C,B"
    of Instruction.LD_C_C: this.handleNOP() # Copy C to C "LD C,C"
    of Instruction.LD_C_D: this.handleLD_C_D() # Copy D to C "LD C,D"
    of Instruction.LD_C_E: this.handleLD_C_E() # Copy E to C "LD C,E"
    of Instruction.LD_C_H: this.handleLD_C_H() # Copy H to C "LD C,H"
    of Instruction.LD_C_L: this.handleLD_C_L() # Copy L to C "LD C,L"
    of Instruction.LD_C_HLP: this.handleLD_C_HLP() # Copy value pointed by HL to C "LD C,(HL"
    of Instruction.LD_C_A: this.handleLD_C_A() # Copy A to C "LD C,A"
    of Instruction.LD_D_B: this.handleLD_D_B() # Copy B to D "LD D,B"
    of Instruction.LD_D_C: this.handleLD_D_C() # Copy C to D "LD D,C"
    of Instruction.LD_D_D: this.handleNOP() # Copy D to D "LD D,D"
    of Instruction.LD_D_E: this.handleLD_D_E() # Copy E to D "LD D,E"
    of Instruction.LD_D_H: this.handleLD_D_H() # Copy H to D "LD D,H"
    of Instruction.LD_D_L: this.handleLD_D_L() # Copy L to D "LD D,L"
    of Instruction.LD_D_HLP: this.handleLD_D_HLP() # Copy value pointed by HL to D "LD D,(HL"
    of Instruction.LD_D_A: this.handleLD_D_A() # Copy A to D "LD D,A"
    of Instruction.LD_E_B: this.handleLD_E_B() # Copy B to E "LD E,B"
    of Instruction.LD_E_C: this.handleLD_E_C() # Copy C to E "LD E,C"
    of Instruction.LD_E_D: this.handleLD_E_D() # Copy D to E "LD E,D"
    of Instruction.LD_E_E: this.handleNOP() # Copy E to E "LD E,E"
    of Instruction.LD_E_H: this.handleLD_E_H() # Copy H to E "LD E,H"
    of Instruction.LD_E_L: this.handleLD_E_L() # Copy L to E "LD E,L"
    of Instruction.LD_E_HLP: this.handleLD_E_HLP() # Copy value pointed by HL to E "LD E,(HL"
    of Instruction.LD_E_A: this.handleLD_E_A() # Copy A to E "LD E,A"
    of Instruction.LD_H_B: this.handleLD_H_B() # Copy B to H "LD H,B"
    of Instruction.LD_H_C: this.handleLD_H_C() # Copy C to H "LD H,C"
    of Instruction.LD_H_D: this.handleLD_H_D() # Copy D to H "LD H,D"
    of Instruction.LD_H_E: this.handleLD_H_E() # Copy E to H "LD H,E"
    of Instruction.LD_H_H: this.handleNOP() # Copy H to H "LD H,H"
    of Instruction.LD_H_L: this.handleLD_H_L() # Copy L to H "LD H,L"
    of Instruction.LD_H_HLP: this.handleLD_H_HLP() # Copy value pointed by HL to H "LD H,(HL"
    of Instruction.LD_H_A: this.handleLD_H_A() # Copy A to H "LD H,A"
    of Instruction.LD_L_B: this.handleLD_L_B() # Copy B to L "LD L,B"
    of Instruction.LD_L_C: this.handleLD_L_C() # Copy C to L "LD L,C"
    of Instruction.LD_L_D: this.handleLD_L_D() # Copy D to L "LD L,D"
    of Instruction.LD_L_E: this.handleLD_L_E() # Copy E to L "LD L,E"
    of Instruction.LD_L_H: this.handleLD_L_H() # Copy H to L "LD L,H"
    of Instruction.LD_L_L: this.handleNOP() # Copy L to L "LD L,L"
    of Instruction.LD_L_HLP: this.handleLD_L_HLP() # Copy value pointed by HL to L "LD L,(HL"
    of Instruction.LD_L_A: this.handleLD_L_A() # Copy A to L "LD L,A"
    # of Instruction.LD_HLP_B: this.handleLD_HLP_B() # Copy B to address pointed by HL "LD (HL),B"
    # of Instruction.LD_HLP_C: this.handleLD_HLP_C() # Copy C to address pointed by HL "LD (HL),C"
    # of Instruction.LD_HLP_D: this.handleLD_HLP_D() # Copy D to address pointed by HL "LD (HL),D"
    # of Instruction.LD_HLP_E: this.handleLD_HLP_E() # Copy E to address pointed by HL "LD (HL),E"
    # of Instruction.LD_HLP_H: this.handleLD_HLP_H() # Copy H to address pointed by HL "LD (HL),H"
    # of Instruction.LD_HLP_L: this.handleLD_HLP_L() # Copy L to address pointed by HL "LD (HL),L"
    # of Instruction.HALT: this.handleHALT() # Halt processor "HALT"
    of Instruction.LD_HLP_A: this.handleLD_HLP_A() # Copy A to address pointed by HL "LD (HL),A"
    # of Instruction.LD_A_B: this.handleLD_A_B() # Copy B to A "LD A,B"
    # of Instruction.LD_A_C: this.handleLD_A_C() # Copy C to A "LD A,C"
    # of Instruction.LD_A_D: this.handleLD_A_D() # Copy D to A "LD A,D"
    of Instruction.LD_A_E: this.handleLD_A_E() # Copy E to A "LD A,E"
    # of Instruction.LD_A_H: this.handleLD_A_H() # Copy H to A "LD A,H"
    # of Instruction.LD_A_L: this.handleLD_A_L() # Copy L to A "LD A,L"
    of Instruction.LD_A_HLP: this.handleLD_A_HLP() # Copy value pointed by HL to A "LD A,(HL"
    # of Instruction.LD_A_A: this.handleLD_A_A() # Copy A to A "LD A,A"
    of Instruction.ADD_A_B: this.handleADD_A_B() # Add B to A "ADD A,B"
    of Instruction.ADD_A_C: this.handleADD_A_C() # Add C to A "ADD A,C"
    of Instruction.ADD_A_D: this.handleADD_A_D() # Add D to A "ADD A,D"
    of Instruction.ADD_A_E: this.handleADD_A_E() # Add E to A "ADD A,E"
    of Instruction.ADD_A_H: this.handleADD_A_H() # Add H to A "ADD A,H"
    of Instruction.ADD_A_L: this.handleADD_A_L() # Add L to A "ADD A,L"
    # of Instruction.ADD_A_HLP: this.handleADD_A_HLP() # Add value pointed by HL to A "ADD A,(HL"
    of Instruction.ADD_A_A: this.handleADD_A_A() # Add A to A "ADD A,A"
    # of Instruction.ADC_B: this.handleADC_B() # Add B and carry flag to A "ADC A,B"
    # of Instruction.ADC_C: this.handleADC_C() # Add C and carry flag to A "ADC A,C"
    # of Instruction.ADC_D: this.handleADC_D() # Add D and carry flag to A "ADC A,D"
    # of Instruction.ADC_E: this.handleADC_E() # Add E and carry flag to A "ADC A,E"
    # of Instruction.ADC_H: this.handleADC_H() # Add H and carry flag to A "ADC A,H"
    # of Instruction.ADC_L: this.handleADC_L() # Add and carry flag L to A "ADC A,L"
    # of Instruction.ADC_HLP: this.handleADC_HLP() # Add value pointed by HL and carry flag to A "ADC A,(HL"
    # of Instruction.ADC_A: this.handleADC_A() # Add A and carry flag to A "ADC A,A"
    of Instruction.SUB_B: this.handleSUB_B() # Subtract B from A "SUB A,B"
    of Instruction.SUB_C: this.handleSUB_C() # Subtract C from A "SUB A,C"
    of Instruction.SUB_D: this.handleSUB_D() # Subtract D from A "SUB A,D"
    of Instruction.SUB_E: this.handleSUB_E() # Subtract E from A "SUB A,E"
    of Instruction.SUB_H: this.handleSUB_H() # Subtract H from A "SUB A,H"
    of Instruction.SUB_L: this.handleSUB_L() # Subtract L from A "SUB A,L"
    # of Instruction.SUB_HLP: this.handleSUB_HLP() # Subtract value pointed by HL from A "SUB A,(HL"
    # of Instruction.SUB_A: this.handleSUB_A() # Subtract A from A "SUB A,A"
    # of Instruction.SBC_B: this.handleSBC_B() # Subtract B and carry flag from A "SBC A,B"
    # of Instruction.SBC_C: this.handleSBC_C() # Subtract C and carry flag from A "SBC A,C"
    # of Instruction.SBC_D: this.handleSBC_D() # Subtract D and carry flag from A "SBC A,D"
    # of Instruction.SBC_E: this.handleSBC_E() # Subtract E and carry flag from A "SBC A,E"
    # of Instruction.SBC_H: this.handleSBC_H() # Subtract H and carry flag from A "SBC A,H"
    # of Instruction.SBC_L: this.handleSBC_L() # Subtract and carry flag L from A "SBC A,L"
    # of Instruction.SBC_HLP: this.handleSBC_HLP() # Subtract value pointed by HL and carry flag from A "SBC A,(HL"
    # of Instruction.SBC_A: this.handleSBC_A() # Subtract A and carry flag from A "SBC A,A"
    of Instruction.AND_B: this.handleAND_B() # Logical AND B against A "AND B"
    of Instruction.AND_C: this.handleAND_C() # Logical AND C against A "AND C"
    of Instruction.AND_D: this.handleAND_D() # Logical AND D against A "AND D"
    of Instruction.AND_E: this.handleAND_E() # Logical AND E against A "AND E"
    of Instruction.AND_H: this.handleAND_H() # Logical AND H against A "AND H"
    of Instruction.AND_L: this.handleAND_L() # Logical AND L against A "AND L"
    # of Instruction.AND_HLP: this.handleAND_HLP() # Logical AND value pointed by HL against A "AND (HL"
    # of Instruction.AND_A: this.handleAND_A() # Logical AND A against A "AND A"
    # of Instruction.XOR_B: this.handleXOR_B() # Logical XOR B against A "XOR B"
    # of Instruction.XOR_C: this.handleXOR_C() # Logical XOR C against A "XOR C"
    # of Instruction.XOR_D: this.handleXOR_D() # Logical XOR D against A "XOR D"
    # of Instruction.XOR_E: this.handleXOR_E() # Logical XOR E against A "XOR E"
    # of Instruction.XOR_H: this.handleXOR_H() # Logical XOR H against A "XOR H"
    # of Instruction.XOR_L: this.handleXOR_L() # Logical XOR L against A "XOR L"
    # of Instruction.XOR_HLP: this.handleXOR_HLP() # Logical XOR value pointed by HL against A "XOR (HL"
    of Instruction.XOR_A: this.handleXOR_A() # Logical XOR A against A "XOR A"
    # of Instruction.OR_B: this.handleOR_B() # Logical OR B against A "OR B"
    # of Instruction.OR_C: this.handleOR_C() # Logical OR C against A "OR C"
    # of Instruction.OR_D: this.handleOR_D() # Logical OR D against A "OR D"
    # of Instruction.OR_E: this.handleOR_E() # Logical OR E against A "OR E"
    # of Instruction.OR_H: this.handleOR_H() # Logical OR H against A "OR H"
    # of Instruction.OR_L: this.handleOR_L() # Logical OR L against A "OR L"
    # of Instruction.OR_HLP: this.handleOR_HLP() # Logical OR value pointed by HL against A "OR (HL"
    # of Instruction.OR_A: this.handleOR_A() # Logical OR A against A "OR A"
    # of Instruction.CP_B: this.handleCP_B() # Compare B against A "CP B"
    # of Instruction.CP_C: this.handleCP_C() # Compare C against A "CP C"
    # of Instruction.CP_D: this.handleCP_D() # Compare D against A "CP D"
    # of Instruction.CP_E: this.handleCP_E() # Compare E against A "CP E"
    # of Instruction.CP_H: this.handleCP_H() # Compare H against A "CP H"
    # of Instruction.CP_L: this.handleCP_L() # Compare L against A "CP L"
    # of Instruction.CP_HLP: this.handleCP_HLP() # Compare value pointed by HL against A "CP (HL"
    # of Instruction.CP_A: this.handleCP_A() # Compare A against A "CP A"
    of Instruction.RET_NZ: this.handleRET_NZ() # Return if last result was not zero "RET NZ"
    of Instruction.POP_BC: this.handlePOP_BC() # Pop 16-bit value from stack into BC "POP BC"
    # of Instruction.JP_NZ_NN: this.handleJP_NZ_NN() # Absolute jump to 16-bit location if last result was not zero "JP NZ,nn"
    of Instruction.JP_NN: this.handleJP_NN() # Absolute jump to 16-bit location "JP nn"
    # of Instruction.CALL_NZ_NN: this.handleCALL_NZ_NN() # Call routine at 16-bit location if last result was not zero "CALL NZ,nn"
    of Instruction.PUSH_BC: this.handlePUSH_BC() # Push 16-bit BC onto stack "PUSH BC"
    # of Instruction.ADD_A_N: this.handleADD_A_N() # Add 8-bit immediate to A "ADD A,n"
    # of Instruction.RST_0: this.handleRST_0() # Call routine at address 0000h "RST 0"
    of Instruction.RET_Z: this.handleRET_Z() # Return if last result was zero "RET Z"
    of Instruction.RET: this.handleRET() # Return to calling routine "RET"
    # of Instruction.JP_Z_NN: this.handleJP_Z_NN() # Absolute jump to 16-bit location if last result was zero "JP Z,nn"
    of Instruction.CB_N: this.handleCB_N() # Extended operations (two-byte instruction code) "Ext ops"
    # of Instruction.CALL_Z_NN: this.handleCALL_Z_NN() # Call routine at 16-bit location if last result was zero "CALL Z,nn"
    of Instruction.CALL_NN: this.handleCALL_NN() # Call routine at 16-bit location "CALL nn"
    # of Instruction.ADC_N: this.handleADC_N() # Add 8-bit immediate and carry to A "ADC A,n"
    # of Instruction.RST_08: this.handleRST_08() # Call routine at address 0008h "RST 8"
    # of Instruction.RET_NC: this.handleRET_NC() # Return if last result caused no carry "RET NC"
    of Instruction.POP_DE: this.handlePOP_DE() # Pop 16-bit value from stack into DE "POP DE"
    # of Instruction.JP_NC_NN: this.handleJP_NC_NN() # Absolute jump to 16-bit location if last result caused no carry "JP NC,nn"
    # of Instruction.CALL_NC_NN: this.handleCALL_NC_NN() # Call routine at 16-bit location if last result caused no carry "CALL NC,nn"
    of Instruction.PUSH_DE: this.handlePUSH_DE() # Push 16-bit DE onto stack "PUSH DE"
    # of Instruction.SUB_N: this.handleSUB_N() # Subtract 8-bit immediate from A "SUB A,n"
    # of Instruction.RST_10: this.handleRST_10() # Call routine at address 0010h "RST 10"
    # of Instruction.RET_C: this.handleRET_C() # Return if last result caused carry "RET C"
    # of Instruction.RETURNFROMINTERRUPT: this.handleRETURNFROMINTERRUPT() # Enable interrupts and return to calling routine "RETI"
    # of Instruction.JP_C_NN: this.handleJP_C_NN() # Absolute jump to 16-bit location if last result caused carry "JP C,nn"
    # of Instruction.CALL_C_NN: this.handleCALL_C_NN() # Call routine at 16-bit location if last result caused carry "CALL C,nn"
    # of Instruction.SBC_N: this.handleSBC_N() # Subtract 8-bit immediate and carry from A "SBC A,n"
    # of Instruction.RST_18: this.handleRST_18() # Call routine at address 0018h "RST 18"
    of Instruction.LD_FF_N_AP: this.handleLD_FF_N_AP() # Save A at address pointed to by (FF00h + 8-bit immediate) "LDH (n),A"
    of Instruction.POP_HL: this.handlePOP_HL() # Pop 16-bit value from stack into HL "POP HL"
    of Instruction.LD_FF_C_A: this.handleLD_FF_C_A() # Save A at address pointed to by (FF00h + C) "LDH (C),A"
    # of Instruction.PUSH_HL: this.handlePUSH_HL() # Push 16-bit HL onto stack "PUSH HL"
    # of Instruction.AND_N: this.handleAND_N() # Logical AND 8-bit immediate against A "AND n"
    # of Instruction.RST_20: this.handleRST_20() # Call routine at address 0020h "RST 20"
    # of Instruction.ADD_SP_N: this.handleADD_SP_N() # Add signed 8-bit immediate to SP "ADD SP,d"
    of Instruction.JP_HL: this.handleJP_HL() # Jump to 16-bit value pointed by HL "JP (HL"
    of Instruction.LD_NNP_A: this.handleLD_NNP_A() # Save A at given 16-bit address "LD (nn),A"
    # of Instruction.XOR_N: this.handleXOR_N() # Logical XOR 8-bit immediate against A "XOR n"
    of Instruction.RST_28: this.handleRST_28() # Call routine at address 0028h "RST 28"
    of Instruction.LD_FF_AP_N: this.handleLD_FF_AP_N() # Load A from address pointed to by (FF00h + 8-bit immediate) "LDH A,(n)"
    # of Instruction.POP_AF: this.handlePOP_AF() # Pop 16-bit value from stack into AF "POP AF"
    # of Instruction.LD_A_FF_C: this.handleLD_A_FF_C() # Operation removed in this CPU "XX"
    # of Instruction.DI_INST: this.handleDI_INST() # DIsable interrupts "DI"
    # of Instruction.PUSH_AF: this.handlePUSH_AF() # Push 16-bit AF onto stack "PUSH AF"
    # of Instruction.OR_N: this.handleOR_N() # Logical OR 8-bit immediate against A "OR n"
    # of Instruction.RST_30: this.handleRST_30() # Call routine at address 0030h "RST 30"
    of Instruction.LD_HL_SP_N: this.handleLD_HL_SP_N() # Add signed 8-bit immediate to SP and save result in HL "LDHL SP,d"
    # of Instruction.LD_SP_HL: this.handleLD_SP_HL() # Copy HL to SP "LD SP,HL"
    # of Instruction.LD_A_NNP: this.handleLD_A_NNP() # Load A from given 16-bit address "LD A,(nn)"
    # of Instruction.EI: this.handleEI() # Enable interrupts "EI"
    of Instruction.CP_N: this.handleCP_N() # Compare 8-bit immediate against A "CP n"
    of Instruction.RST_38: this.handleRST_38() # Call routine at address 0038h "RST 38"
    else:
      echo "UNHANDLED OPCODE ", instruction, " 0x", toHex(cast[uint8](instruction))
      echo this.registers
      quit(1)


proc reset*(this: var CPU): void =
  this.bus.reset()
  this.stopped = false
  this.registers.a = 0;
  this.registers.f.zero = false
  this.registers.f.subtract = false
  this.registers.f.half_carry = false
  this.registers.f.carry = false
  this.registers.b = 0
  this.registers.c = 0
  this.registers.d = 0
  this.registers.e = 0
  this.registers.h = 0
  this.registers.l = 0
  this.registers.sp = 0
  this.registers.pc = 0


proc step*(this: var CPU): void =
  let instruction_byte = this.bus.retrieve(this.registers.pc)
  this.execute(Instruction(instruction_byte))
