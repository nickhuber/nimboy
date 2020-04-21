import strutils

import algorithm
import random

# https://gbdev.gg8.se/wiki/articles/Gameboy_Bootstrap_ROM
const bootROM: array[0x100, uint8] = [
  0x31'u8, 0xFE'u8, 0xFF'u8, 0xAF'u8, 0x21'u8, 0xFF'u8, 0x9F'u8, 0x32'u8, 0xCB'u8, 0x7C'u8, 0x20'u8, 0xFB'u8, 0x21'u8, 0x26'u8, 0xFF'u8, 0x0E'u8,
  0x11'u8, 0x3E'u8, 0x80'u8, 0x32'u8, 0xE2'u8, 0x0C'u8, 0x3E'u8, 0xF3'u8, 0xE2'u8, 0x32'u8, 0x3E'u8, 0x77'u8, 0x77'u8, 0x3E'u8, 0xFC'u8, 0xE0'u8,
  0x47'u8, 0x11'u8, 0x04'u8, 0x01'u8, 0x21'u8, 0x10'u8, 0x80'u8, 0x1A'u8, 0xCD'u8, 0x95'u8, 0x00'u8, 0xCD'u8, 0x96'u8, 0x00'u8, 0x13'u8, 0x7B'u8,
  0xFE'u8, 0x34'u8, 0x20'u8, 0xF3'u8, 0x11'u8, 0xD8'u8, 0x00'u8, 0x06'u8, 0x08'u8, 0x1A'u8, 0x13'u8, 0x22'u8, 0x23'u8, 0x05'u8, 0x20'u8, 0xF9'u8,
  0x3E'u8, 0x19'u8, 0xEA'u8, 0x10'u8, 0x99'u8, 0x21'u8, 0x2F'u8, 0x99'u8, 0x0E'u8, 0x0C'u8, 0x3D'u8, 0x28'u8, 0x08'u8, 0x32'u8, 0x0D'u8, 0x20'u8,
  0xF9'u8, 0x2E'u8, 0x0F'u8, 0x18'u8, 0xF3'u8, 0x67'u8, 0x3E'u8, 0x64'u8, 0x57'u8, 0xE0'u8, 0x42'u8, 0x3E'u8, 0x91'u8, 0xE0'u8, 0x40'u8, 0x04'u8,
  0x1E'u8, 0x02'u8, 0x0E'u8, 0x0C'u8, 0xF0'u8, 0x44'u8, 0xFE'u8, 0x90'u8, 0x20'u8, 0xFA'u8, 0x0D'u8, 0x20'u8, 0xF7'u8, 0x1D'u8, 0x20'u8, 0xF2'u8,
  0x0E'u8, 0x13'u8, 0x24'u8, 0x7C'u8, 0x1E'u8, 0x83'u8, 0xFE'u8, 0x62'u8, 0x28'u8, 0x06'u8, 0x1E'u8, 0xC1'u8, 0xFE'u8, 0x64'u8, 0x20'u8, 0x06'u8,
  0x7B'u8, 0xE2'u8, 0x0C'u8, 0x3E'u8, 0x87'u8, 0xE2'u8, 0xF0'u8, 0x42'u8, 0x90'u8, 0xE0'u8, 0x42'u8, 0x15'u8, 0x20'u8, 0xD2'u8, 0x05'u8, 0x20'u8,
  0x4F'u8, 0x16'u8, 0x20'u8, 0x18'u8, 0xCB'u8, 0x4F'u8, 0x06'u8, 0x04'u8, 0xC5'u8, 0xCB'u8, 0x11'u8, 0x17'u8, 0xC1'u8, 0xCB'u8, 0x11'u8, 0x17'u8,
  0x05'u8, 0x20'u8, 0xF5'u8, 0x22'u8, 0x23'u8, 0x22'u8, 0x23'u8, 0xC9'u8, 0xCE'u8, 0xED'u8, 0x66'u8, 0x66'u8, 0xCC'u8, 0x0D'u8, 0x00'u8, 0x0B'u8,
  0x03'u8, 0x73'u8, 0x00'u8, 0x83'u8, 0x00'u8, 0x0C'u8, 0x00'u8, 0x0D'u8, 0x00'u8, 0x08'u8, 0x11'u8, 0x1F'u8, 0x88'u8, 0x89'u8, 0x00'u8, 0x0E'u8,
  0xDC'u8, 0xCC'u8, 0x6E'u8, 0xE6'u8, 0xDD'u8, 0xDD'u8, 0xD9'u8, 0x99'u8, 0xBB'u8, 0xBB'u8, 0x67'u8, 0x63'u8, 0x6E'u8, 0x0E'u8, 0xEC'u8, 0xCC'u8,
  0xDD'u8, 0xDC'u8, 0x99'u8, 0x9F'u8, 0xBB'u8, 0xB9'u8, 0x33'u8, 0x3E'u8, 0x3C'u8, 0x42'u8, 0xB9'u8, 0xA5'u8, 0xB9'u8, 0xA5'u8, 0x42'u8, 0x3C'u8,
  0x21'u8, 0x04'u8, 0x01'u8, 0x11'u8, 0xA8'u8, 0x00'u8, 0x1A'u8, 0x13'u8, 0xBE'u8, 0x20'u8, 0xFE'u8, 0x23'u8, 0x7D'u8, 0xFE'u8, 0x34'u8, 0x20'u8,
  0xF5'u8, 0x06'u8, 0x19'u8, 0x78'u8, 0x86'u8, 0x23'u8, 0x05'u8, 0x20'u8, 0xFB'u8, 0x86'u8, 0x20'u8, 0xFE'u8, 0x3E'u8, 0x01'u8, 0xE0'u8, 0x50'u8,
]


type
  color = uint8


type
  MemoryBus* = object
    boot: array[0x100, uint8]
    cartridge: array[0x8000, uint8]
    sram: array[0x2000, uint8]
    io: array[0x100, uint8]
    vram: array[0x2000, uint8]
    oam: array[0xFFFF, uint8]
    wram: array[0x2000, uint8]
    hram: array[0x80, uint8]
    # TODO: This is more GPU related than memory bus
    tiles*: array[384, array[8, array[8, color]]]


proc reset*(this: var MemoryBus): void =
  this.boot = bootROM
  this.sram.fill(0)
  this.vram.fill(0)
  this.oam.fill(0)
  this.wram.fill(0)
  this.hram.fill(0)
  this.io.fill(0)
  for t in 0..383:
    for x in 0..7:
      this.tiles[t][x].fill(0)


proc initializeCartridgeData*(this: var MemoryBus, cartridgeData: string): void =
  for i, b in cartridgeData:
    this.cartridge[i] = cast[uint8](b)


proc initializeCartridgeData*(this: var MemoryBus, cartridgeData: openArray[uint8]): void =
  for i, b in cartridgeData:
    this.cartridge[i] = b


proc retrieve*(this: MemoryBus, address: uint16): uint8 =
  # Writing a 1 to 0x50 in the io memory removed the bootrom from being accessed again.
  # This is the last thing that the bootrom does
  if this.io[0x50] == 0 and address < 0x100:
    return this.boot[address]
  elif address <= 0x7FFF:
    return this.cartridge[address]

  elif address >= 0xA000 and address <= 0xBFFF:
    return this.sram[address - 0xA000]

  elif address >= 0x8000 and address <= 0x9FFF:
    return this.vram[address - 0x8000]

  elif address >= 0xC000 and address <= 0xDFFF:
    return this.wram[address - 0xC000]

  elif address >= 0xE000 and address <= 0xFDFF:
    return this.wram[address - 0xE000]

  elif address >= 0xFE00 and address <= 0xFEFF:
    return this.oam[address - 0xFE00]

  elif address == 0xFF04:
    # TODO: Should return a div timer to be properly accurate
    return cast[uint8](rand(255))

  elif address >= 0xFF80 and address <= 0xFFFE:
    return this.hram[address - 0xFF80]
  elif address >= 0xFF00 and address <= 0xFF7F:
    return this.io[address - 0xFF00]
  else:
    echo "UHANDLED MEMORY READ EVENT FOR 0x", toHex(address)
    # quit()
  return 0


proc retrieve16*(this: MemoryBus, address: uint16): uint16 =
  var ret: uint16 = cast[uint16](this.retrieve(address))
  ret += cast[uint16](this.retrieve(address + 1)) * 256
  return ret


proc updateTile(this: var MemoryBus, address: uint16, value: uint8): void =
  let f = address and 0x1FFE
  let tile = (address shr 4) and 0x1FF
  let y = (address shr 1) and 0x7

  for x in 0'u8..7'u8:
    let bitIndex: uint8 = 1'u8 shl (0x7'u8 - x)
    this.tiles[tile][y][x] = 0
    if (this.vram[f] and bitIndex) == bitIndex:
      this.tiles[tile][y][x] = 1
    if (this.vram[f + 1] and bitIndex) == bitIndex:
      this.tiles[tile][y][x] += 2


proc assign*(this: var MemoryBus, address: uint16, value: uint8): void =
  if address >= 0xA000 and address <= 0xBFFF:
    this.sram[address - 0xA000] = value;
  elif address >= 0x8000 and address <= 0x9FFF:
    this.vram[address - 0x8000] = value
    if address < 0x97FF:
      this.updateTile(address, value)
  elif address >= 0xC000 and address <= 0xDFFF:
    this.wram[address - 0xC000] = value
  elif address >= 0xE000 and address <= 0xFDFF:
    this.wram[address - 0xE000] = value
  elif address >= 0xFE00 and address <= 0xFEFF:
    this.oam[address - 0xFE00] = value
  elif address >= 0xFF80 and address <= 0xFFFE:
    this.hram[address - 0xFF80] = value
  elif address >= 0xFF00 and address <= 0xFF7F:
    this.io[address - 0xFF00] = value;
  else:
    echo "UHANDLED MEMORY WRITE EVENT FOR 0x", toHex(value), " => 0x", toHex(address)
    quit()


proc assign16*(this: var MemoryBus, address: uint16, value: uint16): void =
  this.assign(address, cast[uint8](value and 0x00FF))
  this.assign(address + 1, cast[uint8]((value and 0xFF00) div 256))
