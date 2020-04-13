
import bitops
import strutils

import instructions
import extended
import memory
import registers


type
  CPU = object
    registers: Registers
    bus*: MemoryBus


proc getOperand(this: var CPU): uint8 =
  return this.bus.retrieve(this.registers.pc + 1)


proc getOperand16(this: var CPU): uint16 =
  return this.bus.retrieve16(this.registers.pc + 1)


proc genericRotate(this: var CPU, value: uint8): uint8 =
  let carry: uint8 = if this.registers.f.carry == 1: 1 else: 0
  this.registers.f.carry = if bitand(value, 0x80) == 0x80: 1 else: 0
  var ret: uint8 = value shl 1
  ret += carry
  this.registers.f.zero = if value == 0: 1 else: 0
  this.registers.f.subtract = 0
  this.registers.f.half_carry = 0
  return ret


proc genericXor(this: var CPU, value: uint8): void =
  this.registers.a = this.registers.a xor value
  this.registers.f.zero = if this.registers.a == 0: 1 else: 0
  this.registers.f.carry = 0
  this.registers.f.half_carry = 0
  this.registers.f.subtract = 0


proc genericInc(this: var CPU, value: uint8): uint8 =
  this.registers.f.half_carry = if bitand(value, 0x0F) == 0x0F: 1 else: 0
  this.registers.f.subtract = 0
  this.registers.f.zero = if value + 1 == 0: 1 else: 0

  return value + 1


proc genericDec(this: var CPU, value: uint8): uint8 =
  this.registers.f.half_carry = if bitand(value, 0x0F) == 0x0F: 0 else: 1
  this.registers.f.subtract = 1
  this.registers.f.zero = if value - 1 == 0: 1 else: 0

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
      this.registers.c = this.genericRotate(this.registers.c)
      return
    else:
      echo "UNHANDLED EXTENDED OPERATION ", operation, " 0x", toHex(cast[uint8](operation))
      quit(2)


proc handleNOP(this: var CPU): uint16 =
  return this.registers.pc + 1


proc handleLD_BC_NN(this: var CPU): uint16 =
  this.registers.set_bc(this.getOperand16())
  return this.registers.pc + 3


proc handleLD_BCP_A(this: var CPU): uint16 = 
  this.bus.assign(this.registers.get_bc, this.registers.a)
  return this.registers.pc + 1


proc handleDEC_B(this: var CPU): uint16 = 
  this.registers.b = this.genericDec(this.registers.b)
  return this.registers.pc + 1


proc handleLD_B_N(this: var CPU): uint16 =
  this.registers.b = this.getOperand()
  return this.registers.pc + 2


proc handleINC_C(this: var CPU): uint16 =
  this.registers.c = this.genericInc(this.registers.c)
  return this.registers.pc + 1


proc handleLD_C_N(this: var CPU): uint16 =
  this.registers.c = this.getOperand()
  return this.registers.pc + 1


proc handleLD_DE_NN(this: var CPU): uint16 =
  this.registers.set_de(this.getOperand16())
  return this.registers.pc + 3


proc handleRLA(this: var CPU): uint16 =
  this.registers.a = this.genericRotate(this.registers.a)
  return this.registers.pc + 1


proc handleLD_A_DEP(this: var CPU): uint16 =
  this.registers.a = this.bus.retrieve(this.registers.get_de())
  return this.registers.pc + 1


proc handleJR_NZ_N(this: var CPU): uint16 =
  if this.registers.f.zero == 0:
    let offset: int8 = cast[int8](this.getOperand())
    # This is some crazy looking nonsense but is why you shouldn't mix signed and unsigned types
    return cast[uint16](cast[int16](this.registers.pc) + cast[int16](offset)) + 2
  else:
    return this.registers.pc + 2


proc handleLD_HL_NN(this: var CPU): uint16 =
  this.registers.set_hl(this.getOperand16())
  return this.registers.pc + 3


proc handleLDI_HLP_A(this: var CPU): uint16 =
  this.bus.assign(this.registers.get_hl(), this.registers.a)
  this.registers.set_hl(this.registers.get_hl() + 1)
  return this.registers.pc + 1


proc handleINC_HL(this: var CPU): uint16 =
  this.registers.set_hl(this.registers.get_hl() + 1)
  return this.registers.pc + 1


proc handleINC_DE(this: var CPU): uint16 =
  this.registers.set_de(this.registers.get_de() + 1)
  return this.registers.pc + 1


proc handleLD_SP_NN(this: var CPU): uint16 =
  this.registers.sp = this.getOperand16()
  return this.registers.pc + 3


proc handleLDD_HLP_A(this: var CPU): uint16 =
  this.bus.assign(this.bus.retrieve(this.registers.get_hl()), this.registers.a)
  this.registers.set_hl(this.registers.get_hl() - 1)
  return this.registers.pc + 1


proc handleLD_A_N(this: var CPU): uint16 =
  this.registers.a = this.getOperand()
  return this.registers.pc + 2


proc handleLD_C_A(this: var CPU): uint16 =
  this.registers.c = this.registers.a
  return this.registers.pc + 1


proc handleLD_D_B(this: var CPU): uint16 =
  this.registers.d = this.registers.b
  return this.registers.pc + 1


proc handleLD_HLP_A(this: var CPU): uint16 =
  this.bus.assign(this.registers.get_hl(), this.registers.a)
  return this.registers.pc + 1


proc handleLD_A_E(this: var CPU): uint16 =
  this.registers.a = this.registers.e
  return this.registers.pc + 1


proc handleXOR_A(this: var CPU): uint16 =
  this.genericXor(this.registers.a)
  return this.registers.pc + 1


proc handlePOP_BC(this: var CPU): uint16 =
  this.registers.set_bc(this.bus.retrieve16(this.registers.sp))
  this.registers.sp += 2
  return this.registers.pc + 1


proc handleJP_NN(this: var CPU): uint16 =
  echo "Jumping to 0x", this.getOperand16().toHex()
  return this.getOperand16()


proc handlePUSH_BC(this: var CPU): uint16 =
  this.registers.sp -= 2
  this.bus.assign16(this.registers.sp, this.registers.get_bc())
  return this.registers.pc + 1


proc handleRET(this: var CPU): uint16 =
  let ret = this.bus.retrieve16(this.registers.sp)
  this.registers.sp += 2
  return ret + 3


proc handleCB_N(this: var CPU): uint16 =
  this.executeExtendedOperation(ExtendedOperation(this.getOperand()))
  return this.registers.pc + 2


proc handleCALL_NN(this: var CPU): uint16 =
  this.registers.sp -= 2
  this.bus.assign16(this.registers.sp, this.registers.pc)
  return this.getOperand()


proc handleLD_FF_N_AP(this: var CPU): uint16 =
  this.bus.assign(0xFF00'u16 + this.getOperand(), this.registers.a)
  return this.registers.pc + 2


proc handleLD_FF_C_A(this: var CPU): uint16 =
  this.bus.assign(0xFF00'u16 + this.registers.c, this.registers.a)
  return this.registers.pc + 1


proc handleCP_N(this: var CPU): uint16 =
  let operand = this.getOperand()
  this.registers.f.subtract = 0
  this.registers.f.zero = if this.registers.a == operand: 1 else: 0
  this.registers.f.carry = if this.registers.a < operand: 1 else: 0
  this.registers.f.half_carry = if bitand(this.registers.a, 0x0F) < bitand(operand, 0x0F): 1 else: 0
  return this.registers.pc + 2


proc execute(this: var CPU, instruction: Instruction): uint16 =
  echo "OPCODE: ", instruction, " PC: 0x", this.registers.pc.toHex()
  echo this.registers
  case instruction:
    of Instruction.NOP: this.registers.pc = this.handleNOP() # 0x00
    of Instruction.LD_BC_NN: this.registers.pc = this.handle_LD_BC_NN() # 0x01
    of Instruction.LD_BCP_A: this.registers.pc = this.handleLD_BCP_A() # 0x02
    of Instruction.DEC_B: this.registers.pc = this.handleDEC_B() # 0x05
    of Instruction.LD_B_N: this.registers.pc = this.handleLD_B_N() # 0x06
    of Instruction.INC_C: this.registers.pc = this.handleINC_C() # 0x0C
    of Instruction.LD_C_N: this.registers.pc = this.handleLD_C_N() # 0x0E
    of Instruction.LD_DE_NN: this.registers.pc = this.handleLD_DE_NN() # 0x11
    of Instruction.RLA: this.registers.pc = this.handleRLA() # 0x17, Rotate A left
    of Instruction.LD_A_DEP: this.registers.pc = this.handleLD_A_DEP() # 0x1A, Load A from address pointed to by DE
    of Instruction.JR_NZ_N: this.registers.pc = this.handleJR_NZ_N() # 0x20
    of Instruction.LD_HL_NN: this.registers.pc = this.handleLD_HL_NN() # 0x21
    of Instruction.LDI_HLP_A: this.registers.pc = this.handleLDI_HLP_A() # 0x22, Save A to address pointed by HL, and increment HL
    of Instruction.INC_HL: this.registers.pc = this.handleINC_HL() # 0x23, Increment 16-bit HL
    of Instruction.INC_DE: this.registers.pc = this.handleINC_DE() # 0x2E, Increment 16-bit DE
    of Instruction.LD_SP_NN: this.registers.pc = this.handleLD_SP_NN() # 0x31
    of Instruction.LDD_HLP_A: this.registers.pc = this.handleLDD_HLP_A() # 0x32
    of Instruction.LD_A_N: this.registers.pc = this.handleLD_A_N() # 0x3E, Load 8-bit immediate into A
    of Instruction.LD_C_A: this.registers.pc = this.handleLD_C_A() # 0x4F, Copy A to C
    of Instruction.LD_D_B: this.registers.pc = this.handleLD_D_B() # 0x50
    of Instruction.LD_HLP_A: this.registers.pc = this.handleLD_HLP_A() #0x77, Copy A to address pointed by HL
    of Instruction.LD_A_E: this.registers.pc = this.handleLD_A_E() #0x7B Copy E to A
    of Instruction.XOR_A: this.registers.pc = this.handleXOR_A() # 0xAF
    of Instruction.POP_BC: this.registers.pc = this.handlePOP_BC() # 0xC1, Pop 16-bit value from stack into BC
    of Instruction.JP_NN: this.registers.pc = this.handleJP_NN() # 0xC3
    of Instruction.PUSH_BC: this.registers.pc = this.handlePUSH_BC() # 0xC5, Push 16-bit BC onto stack
    of Instruction.RET: this.registers.pc = this.handleRET() # 0xC9, Return to calling routine
    of Instruction.CB_N: this.registers.pc = this.handleCB_N() # 0xCB
    of Instruction.CALL_NN: this.registers.pc = this.handleCALL_NN() # 0xCD, Call routine at 16-bit location
    of Instruction.LD_FF_N_AP: this.registers.pc = this.handleLD_FF_N_AP() # 0xE0, Save A at address pointed to by (FF00h + 8-bit immediate)
    of Instruction.LD_FF_C_A: this.registers.pc = this.handleLD_FF_C_A() # 0xE2, Save A at address pointed to by (FF00h + C)
    of Instruction.CP_N: this.registers.pc = this.handleCP_N() # 0xFE, Compare 8-bit immediate against A
    else:
      echo "UNHANDLED OPCODE ", instruction, " 0x", toHex(cast[uint8](instruction))
      echo this.registers
      quit(1)
  return this.registers.pc


proc reset*(this: var CPU): void = 
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


proc step*(this: var CPU): void =
  let instruction_byte = this.bus.retrieve(this.registers.pc)
  this.registers.pc = this.execute(Instruction(instruction_byte))


export CPU