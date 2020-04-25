import unittest

import ../src/[cpu, instructions, memory, registers]

# Instructions must set 0xFF50 to 1 to unmap the boot ROM
proc init(cpu: var CPU, rom: openArray[uint8]): void =
    cpu.reset()
    cpu.bus.initializeCartridgeData(rom)
    cpu.bus.assign(0xFF50, 1)


suite "CPU test suite":
  var cpu = CPU()

  suite "reset":
    setup:
      init(cpu, [])

    test "register pc is 0":
      check(cpu.registers.pc == 0)

    test "flags are all false":
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

  suite "NOP instruction (0x00)":
    setup:
      init(cpu, [Instruction.NOP.ord().uint8])

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "flags aren't modified":
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

  suite "LD_BC_NN instruction (0x01)":
    setup:
      init(cpu, [Instruction.LD_BC_NN.ord().uint8, 0x34, 0x12])

    test "increases PC by 3":
      cpu.step()
      check(cpu.registers.pc == 3)

    test "BC register is set, little endian":
      cpu.step()
      check(cpu.registers.get_bc() == 0x1234)
      check(cpu.registers.b == 0x12)
      check(cpu.registers.c == 0x34)

    test "flags aren't modified":
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

  suite "LD_BCP_A instruction (0x02)":
    setup:
      init(cpu, [Instruction.LD_BCP_A.ord().uint8])
      cpu.registers.set_bc(0xE000)
      cpu.registers.a = 0x42

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "register A is assigned to BC's memory pointer":
      cpu.step()
      check(cpu.bus.retrieve(cpu.registers.get_bc()) == cpu.registers.a)

    test "flags aren't modified":
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

  suite "INC_BC instruction (0x03)":
    setup:
      init(cpu, [Instruction.INC_BC.ord().uint8])
      cpu.registers.set_bc(0x1234)

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "increases BC by 1":
      cpu.step()
      check(cpu.registers.get_bc() == 0x1235)
      check(cpu.registers.b == 0x12)
      check(cpu.registers.c == 0x35)

    test "flags aren't modified":
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

  suite "INC_B instruction (0x04)":
    setup:
      init(cpu, [Instruction.INC_B.ord().uint8])
      cpu.registers.b = 0x08

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "increases B by 1":
      cpu.step()
      check(cpu.registers.b == 0x09)

    test "overflows to 0x00":
      cpu.registers.b = 0xFF
      cpu.step()
      check(cpu.registers.b == 0x00)

    test "flags correct on high bit carry":
      cpu.registers.b = 0xFF
      cpu.step()
      check(not cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

    test "flags correct on low bit carry":
      cpu.registers.b = 0x0F
      cpu.step()
      check(not cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "flags correct on near-half carry":
      cpu.registers.b = 0x1E
      cpu.step()
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "flags correct on no carry":
      cpu.registers.b = 0x00
      cpu.step()
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "subtract flag is cleared":
      cpu.registers.f.subtract = true
      cpu.step()
      check(not cpu.registers.f.subtract)

  suite "DEC_B instruction (0x05)":
    setup:
      init(cpu, [Instruction.DEC_B.ord().uint8])
      cpu.registers.b = 0x08

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "decreases B by 1":
      cpu.step()
      check(cpu.registers.b == 0x07)

    test "overflows to 0xFF":
      cpu.registers.b = 0x00
      cpu.step()
      check(cpu.registers.b == 0xFF)

    test "flags correct on high bit carry":
      cpu.registers.b = 0x00
      cpu.step()
      check(not cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "flags correct on low bit carry":
      cpu.registers.b = 0xF0
      cpu.step()
      check(not cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "flags correct on near-half carry":
      cpu.registers.b = 0xF1
      cpu.step()
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "flags correct on no carry":
      cpu.registers.b = 0xFF
      cpu.step()
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

  suite "LD_B_N instruction (0x06)":
    setup:
      init(cpu, [Instruction.LD_B_N.ord().uint8, 0x42])

    test "increases PC by 2":
      cpu.step()
      check(cpu.registers.pc == 2)

    test "operand is saved to B":
      cpu.step()
      check(cpu.registers.b == 0x42)

    test "flags aren't modified":
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

  suite "RLCA instruction (0x07)":
    setup:
      init(cpu, [Instruction.RLCA.ord().uint8])

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "A is rotated left":
      cpu.registers.a = 0b00100000
      cpu.step()
      check(cpu.registers.a == 0b01000000)

    test "bit 7 rotates to bit 0":
      cpu.registers.a = 0b10000000
      cpu.step()
      check(cpu.registers.a == 0b00000001)

    test "clears all flags if no carry happens":
      cpu.registers.a = 0b01000000
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "sets carry flag if a carry happens":
      cpu.registers.a = 0b10000000
      cpu.step()
      check(cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "doesn't set zero even if A is zero":
      cpu.registers.a = 0b00000000
      cpu.step()
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

  suite "LD_NNP_SP instruction (0x08)":
    setup:
      init(cpu, [Instruction.LD_NNP_SP.ord().uint8, 0x50, 0xE0])

    test "increases PC by 3":
      cpu.step()
      check(cpu.registers.pc == 3)

    test "SP is saved to address pointed to by operand16":
      cpu.registers.sp = 0x1234
      cpu.step()
      check(cpu.bus.retrieve16(0xE050) == 0x1234)

    test "flags aren't modified":
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

  suite "ADD_HL_BC instruction (0x09)":
    setup:
      init(cpu, [Instruction.ADD_HL_BC.ord().uint8])

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "HL has BC added to it":
      cpu.registers.set_hl(0x0020)
      cpu.registers.set_bc(0x0010)
      cpu.step()
      check(cpu.registers.get_hl() == 0x0030)
      check(cpu.registers.get_bc() == 0x0010)

    test "zero flag isn't changed, even if HL becomes 0 (initial false)":
      cpu.registers.set_hl(0x0000)
      cpu.registers.set_bc(0x0000)
      cpu.registers.f.zero = false
      cpu.step()
      check(not cpu.registers.f.zero)

    test "zero flag isn't changed, even if HL becomes 0 (initial true)":
      cpu.registers.set_hl(0x0000)
      cpu.registers.set_bc(0x0000)
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.zero)

    test "subtract flag is cleared":
      cpu.registers.f.subtract = true
      cpu.step()
      check(not cpu.registers.f.subtract)

    test "carry is set when most significant bit overflows":
      cpu.registers.f.carry = false
      cpu.registers.set_hl(0xFFFF)
      cpu.registers.set_bc(0x0002)
      cpu.step()
      check(cpu.registers.get_hl() == 0x0001)
      check(cpu.registers.f.carry)

    test "carry is cleared when most significant bit does not overflow":
      cpu.registers.f.carry = true
      cpu.registers.set_hl(0x00FF)
      cpu.registers.set_bc(0x002)
      cpu.step()
      check(cpu.registers.get_hl() == 0x0101)
      check(not cpu.registers.f.carry)

    test "half carry is set when 11th bit overflows":
      cpu.registers.f.half_carry = false
      cpu.registers.set_hl(0x0FFF)
      cpu.registers.set_bc(0x0002)
      cpu.step()
      check(cpu.registers.get_hl() == 0x1001)
      check(cpu.registers.f.half_carry)

    test "half carry is cleared when 11th bit doesn't overflow":
      cpu.registers.f.half_carry = true
      cpu.registers.set_hl(0x00FF)
      cpu.registers.set_bc(0x0002)
      cpu.step()
      check(cpu.registers.get_hl() == 0x0101)
      check(not cpu.registers.f.half_carry)

  suite "LD_A_BCP instruction (0x0A)":
    setup:
      init(cpu, [Instruction.LD_A_BCP.ord().uint8])
      cpu.registers.set_bc(0xE050)
      cpu.bus.assign(0xE050, 0x42)

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "A has the memory pointed to by BC assigned to it":
      cpu.step()
      check(cpu.registers.a == 0x42)

    test "flags aren't modified":
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

  suite "DEC_BC instruction (0x0B)":
    setup:
      init(cpu, [Instruction.DEC_BC.ord().uint8])
      cpu.registers.set_bc(0x3412)

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "BC is reduced by 1":
      cpu.step()
      check(cpu.registers.get_bc() == 0x3411)

    test "flags aren't modified":
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)
      check(cpu.registers.f.zero)

  suite "RLCA instruction (0x0F)":
    setup:
      init(cpu, [Instruction.RRCA.ord().uint8])

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "A is rotated right":
      cpu.registers.a = 0b00100000
      cpu.step()
      check(cpu.registers.a == 0b00010000)

    test "bit 0 rotates to bit 7":
      cpu.registers.a = 0b00000001
      cpu.step()
      check(cpu.registers.a == 0b10000000)

    test "clears all flags if no carry happens":
      cpu.registers.a = 0b00000010
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.registers.f.zero = true
      cpu.step()
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "sets carry flag if a carry happens":
      cpu.registers.a = 0b00000001
      cpu.step()
      check(cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)

    test "doesn't set zero even if A is zero":
      cpu.registers.a = 0b00000000
      cpu.step()
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)
      check(not cpu.registers.f.zero)
