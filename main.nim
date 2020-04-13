
import os
import bitops

import strutils

import opcodes
import memory

const ROM_NAME_OFFSET = 0x134
const ROM_TYPE_OFFSET = 0x147
const ROM_ROM_SIZE_OFFSET = 0x148
const ROM_RAM_SIZE_OFFSET = 0x149


type
  FlagRegister = object
    zero {.bitsize:1.}: uint8
    subtract {.bitsize:1.}: uint8
    half_carry {.bitsize:1.}: uint8
    carry {.bitsize:1.}: uint8


type
  Registers = object
    a: uint8
    b: uint8
    c: uint8
    d: uint8
    e: uint8
    f: FlagRegister
    h: uint8
    l: uint8
    sp: uint16
    pc: uint16


proc get_bc(this: Registers): uint16 =
  return (cast[uint16](this.c) * 256) + cast[uint16](this.b)


proc set_bc(this: var Registers, bc: uint16): void =
  this.c = cast[uint8]((bc and 0xFF00) div 256)
  this.b = cast[uint8](bc and 0x00FF)


proc get_de(this: Registers): uint16 =
  return (cast[uint16](this.e) * 256) + cast[uint16](this.d)


proc set_de(this: var Registers, de: uint16): void =
  this.e = cast[uint8]((de and 0xFF00) div 256)
  this.d = cast[uint8](de and 0x00FF)


proc get_hl(this: Registers): uint16 =
  return (cast[uint16](this.l) * 256) + cast[uint16](this.h)


proc set_hl(this: var Registers, hl: uint16): void =
  this.l = cast[uint8]((hl and 0xFF00) div 256)
  this.h = cast[uint8](hl and 0x00FF)


type
  CPU = object
    registers: Registers
    bus: MemoryBus


proc handleRotate(this: var CPU, value: uint8): uint8 =
  var carry: uint8 = if this.registers.f.carry == 1:
    1
  else:
    0
  this.registers.f.carry = if bitand(value, 0x80) == 0x80:
    1
  else:
    0
  var ret: uint8 = value shl 1
  ret += carry
  this.registers.f.zero = if value == 0:
    1
  else:
    0
  this.registers.f.subtract = 0
  this.registers.f.half_carry = 0
  return ret


proc handleXor(this: var CPU, value: uint8): void =
  this.registers.a = this.registers.a xor value
  this.registers.f.zero = if this.registers.a == 0:
    1
  else:
    0

  this.registers.f.carry = 0
  this.registers.f.half_carry = 0
  this.registers.f.subtract = 0


proc handleInc(this: var CPU, value: uint8): uint8 =
  this.registers.f.half_carry = if bitand(value, 0x0F) == 0x0F:
    1
  else:
    0

  this.registers.f.subtract = 0

  this.registers.f.zero = if value + 1 == 0:
    1
  else:
    0

  return value + 1


proc handleDec(this: var CPU, value: uint8): uint8 =
  this.registers.f.half_carry = if bitand(value, 0x0F) == 0x0F:
    0
  else:
    1

  this.registers.f.subtract = 1

  this.registers.f.zero = if value - 1 == 0:
    1
  else:
    0

  return value - 1


proc executeExtendedOperation(this: var CPU, operation: ExtendedOperation): void =
  echo "Performing extended operation ", operation
  case operation:
    of ExtendedOperation.BIT_7_H:  # 0x7C, Test bit 7 of H
      if bitand(this.registers.h, 0b10000000) == 0b10000000:
        this.registers.f.zero = 0
      else:
        this.registers.f.zero = 1
      this.registers.f.subtract = 0
      this.registers.f.half_carry = 1
      return
    of ExtendedOperation.RL_C:  # 0x11, Rotate C left
      this.registers.c = this.handleRotate(this.registers.c)
      return
    else:
      echo "UNHANDLED EXTENDED OPERATION ", operation, " 0x", toHex(cast[uint8](operation))
      quit(2)


proc execute(this: var CPU, instruction: Instruction): uint16 =
  echo "OPCODE: ", instruction, " PC: 0x", this.registers.pc.toHex()
  case instruction:
    of Instruction.NOP:  # 0x00
      return this.registers.pc + 1
    of Instruction.LD_BC_NN:  # 0x01
      this.registers.set_bc(this.bus.at16(this.registers.pc + 1))
      return this.registers.pc + 3
    of Instruction.LD_BCP_A:  # 0x02
      this.bus.set(this.registers.get_bc, this.registers.a)
      return this.registers.pc + 1
    of Instruction.DEC_B: # 0x05
      this.registers.b = this.handleDec(this.registers.b)
      return this.registers.pc + 1
    of Instruction.LD_B_N:  # 0x06
      this.registers.b = this.bus.at(this.registers.pc + 1)
      return this.registers.pc + 2
    of Instruction.INC_C:  # 0x0C
      this.registers.c = this.handleInc(this.registers.c)
      return this.registers.pc + 1
    of Instruction.LD_C_N:  # 0x0E
      this.registers.c = this.bus.at(this.registers.pc + 1)
      return this.registers.pc + 1
    of Instruction.LD_DE_NN:  # 0x11
      this.registers.set_de(this.bus.at16(this.registers.pc + 1))
      return this.registers.pc + 3
    of Instruction.RLA:  # 0x17, Rotate A left
      this.registers.a = this.handleRotate(this.registers.a)
      return this.registers.pc + 1
    of Instruction.LD_A_DEP:  # 0x1A, Load A from address pointed to by DE
      this.registers.a = this.bus.at(this.registers.get_de())
      return this.registers.pc + 1
    of Instruction.JR_NZ_N:  # 0x20
      if this.registers.f.zero == 0:
        var offset: int8 = cast[int8](this.bus.at(this.registers.pc + 1))
        # This is some crazy looking nonsense but is why you shouldn't mix signed and unsigned types
        return cast[uint16](cast[int16](this.registers.pc) + cast[int16](offset)) + 2
      else:
        return this.registers.pc + 2
    of Instruction.LD_HL_NN:  # 0x21
      this.registers.set_hl(this.bus.at16(this.registers.pc + 1))
      return this.registers.pc + 3
    of Instruction.LD_SP_NN:  # 0x31
      this.registers.sp = this.bus.at16(this.registers.pc + 1)
      return this.registers.pc + 3
    of Instruction.LDD_HLP_A:  # 0x32
      this.bus.set(this.bus.at(this.registers.get_hl()), this.registers.a)
      this.registers.set_hl(this.registers.get_hl() - 1)
      return this.registers.pc + 1
    of Instruction.LD_A_N:  # 0x3E, Load 8-bit immediate into A
      this.registers.a = this.bus.at(this.registers.pc + 1)
      return this.registers.pc + 2
    of Instruction.LD_C_A:  # 0x4F, Copy A to C
      this.registers.c = this.registers.a
      return this.registers.pc + 1
    of Instruction.LD_D_B: # 0x50
      this.registers.d = this.registers.b
      return this.registers.pc + 1
    of Instruction.LD_HLP_A:  #0x77, Copy A to address pointed by HL
      this.bus.set(this.registers.get_hl(), this.registers.a)
      return this.registers.pc + 1
    of Instruction.XOR_A:  # 0xAF
      this.handleXor(this.registers.a)
      return this.registers.pc + 1
    of Instruction.POP_BC:  # 0xC1, Pop 16-bit value from stack into BC
      this.registers.set_bc(this.bus.at16(this.registers.sp))
      this.registers.sp += 2
      return this.registers.pc + 1
    of Instruction.JP_NN:  # 0xC3
      echo "Jumping to 0x", this.bus.at16(this.registers.pc + 1).toHex()
      return this.bus.at16(this.registers.pc + 1)
    of Instruction.PUSH_BC:  # 0xC5, Push 16-bit BC onto stack
      this.registers.sp -= 2
      this.bus.set16(this.registers.sp, this.registers.get_bc())
      return this.registers.pc + 1
    of Instruction.CB_N:  # 0xCB
      this.executeExtendedOperation(ExtendedOperation(this.bus.at(this.registers.pc + 1)))
      return this.registers.pc + 2
    of Instruction.CALL_NN:  # 0xCD, Call routine at 16-bit location
      this.registers.sp -= 2
      this.bus.set16(this.registers.sp, this.registers.pc)
      return this.bus.at(this.registers.pc + 1)
    of Instruction.LD_FF_N_AP:  # 0xE0, Save A at address pointed to by (FF00h + 8-bit immediate)
      this.bus.set(0xFF00'u16 + this.bus.at(this.registers.pc + 1), this.registers.a)
      return this.registers.pc + 2
    of Instruction.LD_FF_C_A:  # 0xE2, Save A at address pointed to by (FF00h + C)
      this.bus.set(0xFF00'u16 + this.registers.c, this.registers.a)
      return this.registers.pc + 1
    else:
      echo "UNHANDLED OPCODE ", instruction, " 0x", toHex(cast[uint8](instruction))
      echo this.registers
      quit(1)
  return this.registers.pc


proc reset(this: var CPU): void = 
  this.bus.reset()

  this.registers.a = 0;
  this.registers.f.zero = 0
  this.registers.f.subtract = 0
  this.registers.f.half_carry = 0
  this.registers.f.carry = 0
  this.registers.b = 0
  this.registers.c = 0
  this.registers.d = 0
  this.registers.e = 0
  this.registers.h = 0
  this.registers.l = 0
  this.registers.sp = 0
  this.registers.pc = 0


proc step(this: var CPU): void =
  var instruction_byte = this.bus.at(this.registers.pc)
  var new_pc = this.execute(Instruction(instruction_byte))
  this.registers.pc = new_pc


proc main() =
  var cpu = CPU()
  var romPath: string = os.paramStr(1)
  var romFile = open(romPath)
  var romData = romFile.readAll()
  echo "ROM name: ", romData[ROM_NAME_OFFSET..ROM_NAME_OFFSET + 17]
  cpu.bus.initializeCartridgeData(romData)
  cpu.reset()
  while true:
    cpu.step()


main()
