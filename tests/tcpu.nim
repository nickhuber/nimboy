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
      check(not cpu.registers.f.zero)
      check(not cpu.registers.f.carry)
      check(not cpu.registers.f.half_carry)
      check(not cpu.registers.f.subtract)

  suite "NOP instruction (0x00)":
    setup:
      init(cpu, [Instruction.NOP.ord().uint8])

    test "increases PC by 1":
      cpu.step()
      check(cpu.registers.pc == 1)

    test "flags aren't modified":
      cpu.registers.f.zero = true
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.step()
      check(cpu.registers.f.zero)
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)

  suite "LD_BC_NN instruction (0x01)":
    setup:
      init(cpu, [Instruction.LD_BC_NN.ord().uint8, 0x12, 0x34])

    test "increases PC by 3":
      cpu.step()
      check(cpu.registers.pc == 3)

    test "BC register is set, little endian":
      cpu.step()
      check(cpu.registers.get_bc() == 0x3412)

    test "flags aren't modified":
      cpu.registers.f.zero = true
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.step()
      check(cpu.registers.f.zero)
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)

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
      cpu.registers.f.zero = true
      cpu.registers.f.carry = true
      cpu.registers.f.half_carry = true
      cpu.registers.f.subtract = true
      cpu.step()
      check(cpu.registers.f.zero)
      check(cpu.registers.f.carry)
      check(cpu.registers.f.half_carry)
      check(cpu.registers.f.subtract)