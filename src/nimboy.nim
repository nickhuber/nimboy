import os

import sdl2

import cpu
import memory

const ROM_NAME_SIZE = 17
const ROM_NAME_OFFSET = 0x134
const ROM_TYPE_OFFSET = 0x147
const ROM_ROM_SIZE_OFFSET = 0x148
const ROM_RAM_SIZE_OFFSET = 0x149

type
  CartridgeType = enum
    ROM_ONLY = (0x00, "ROM ONLY")
    MBC1 = (0x01, "MBC1")
    MBC1_RAM = (0x02, "MBC1+RAM")
    MBC1_RAM_BATTERY = (0x03, "MBC1+RAM+BATTERY")
    MBC2 = (0x05, "MBC2")
    MBC2_BATTERY = (0x06, "MBC2+BATTERY")
    ROM_RAM = (0x08, "ROM+RAM")
    ROM_RAM_BATTERY = (0x09, "ROM+RAM+BATTERY")
    MMM01 = (0x0B, "MMM01")
    MMM01_RAM = (0x0C, "MMM01+RAM")
    MMM01_RAM_BATTERY = (0x0D, "MMM01+RAM+BATTERY")
    MBC3_TIMER_BATTERY = (0x0F, "MBC3+TIMER+BATTERY")
    MBC3_TIMER_RAM_BATTERY = (0x10, "MBC3+TIMER+RAM+BATTERY")
    MBC3 = (0x11, "MBC3")
    MBC3_RAM = (0x12, "MBC3+RAM")
    MBC3_RAM_BATTERY = (0x13, "MBC3+RAM+BATTERY")
    MBC5 = (0x19, "MBC5")
    MBC5_RAM = (0x1A, "MBC5+RAM")
    MBC5_RAM_BATTERY = (0x1B, "MBC5+RAM+BATTERY")
    MBC5_RUMBLE = (0x1C, "MBC5+RUMBLE")
    MBC5_RUMBLE_RAM = (0x1D, "MBC5+RUMBLE+RAM")
    MBC5_RUMBLE_RAM_BATTERY = (0x1E, "MBC5+RUMBLE+RAM+BATTERY")
    MBC6 = (0x20, "MBC6")
    MBC7_SENSOR_RUMBLE_RAM_BATTERY = (0x22, "MBC7+SENSOR+RUMBLE+RAM+BATTERY")
    POCKET_CAMERA = (0xFC, "POCKET CAMERA")
    BANDAI_TAMA5 = (0xFD, "BANDAI TAMA5")
    HUC3 = (0xFE, "HuC3")
    HUC1_RAM_BATTERY = (0xFF, "HuC1+RAM+BATTERY")

type
  ROMSizeType = enum
    BANKS_0 = (0x00, "32KByte (no ROM banking)")
    BANKS_4 = (0x01, "64KByte (4 banks)")
    BANKS_8 = (0x02, "128KByte (8 banks)")
    BANKS_16 = (0x03, "256KByte (16 banks)")
    BANKS_32 = (0x04, "512KByte (32 banks)")
    BANKS_64 = (0x05, "1MByte (64 banks)  - only 63 banks used by MBC1")
    BANKS_128 = (0x06, "2MByte (128 banks) - only 125 banks used by MBC1")
    BANKS_256 = (0x07, "4MByte (256 banks)")
    BANKS_512 = (0x08, "8MByte (512 banks)")
    BANKS_72 = (0x52, "1.1MByte (72 banks)")
    BANKS_80 = (0x53, "1.2MByte (80 banks)")
    BANKS_96 = (0x54, "1.5MByte (96 banks)")

type
  RAMSizeType = enum
    KBYTES_0 = (0x00, "None")
    KBYTES_2 = (0x01, "2 KBytes")
    KBYTES_8 = (0x02, "8 Kbytes")
    KBYTES_32 = (0x03, "32 KBytes (4 banks of 8KBytes each)")
    KBYTES_128 = (0x04, "128 KBytes (16 banks of 8KBytes each)")
    KBYTES_64 = (0x05, "64 KBytes (8 banks of 8KBytes each)")


proc main() =
  var window: WindowPtr = createWindow("Nimboy", 100, 100, 160 , 144, SDL_WINDOW_SHOWN)
  var render: RendererPtr = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)

  var cpu = CPU()
  var romPath: string = os.paramStr(1)
  var romFile = open(romPath)
  var romData = romFile.readAll()
  echo "ROM name: ", romData[ROM_NAME_OFFSET..ROM_NAME_OFFSET + ROM_NAME_SIZE]
  echo "ROM type: ", CartridgeType(cast[uint8](romData[ROM_TYPE_OFFSET]))
  echo "ROM size: ", ROMSizeType(cast[uint8](romData[ROM_ROM_SIZE_OFFSET]))
  echo "RAM size: ", RAMSizeType(cast[uint8](romData[ROM_RAM_SIZE_OFFSET]))
  cpu.bus.initializeCartridgeData(romData)
  cpu.reset()

  while true:
    if cpu.stopped:
      render.setDrawColor(255, 255, 255, 255)
      render.clear()
      for t in 0..383:
        for x in 0..7:
          for y in 0..7:
            if cpu.bus.tiles[t][x][y] == 0:
              render.setDrawColor(255, 255, 255, 255)
            elif cpu.bus.tiles[t][x][y] == 1:
              render.setDrawColor(255, 0, 0, 255)
            elif cpu.bus.tiles[t][x][y] == 2:
              render.setDrawColor(0, 255, 0, 255)
            elif cpu.bus.tiles[t][x][y] == 3:
              render.setDrawColor(0, 0, 255, 255)
            render.drawPoint(
              cast[cint](x + ((t * 8) mod 160)),
              cast[cint](y + ((t div 19) * 8))
            )
      render.present()
    else:
      cpu.step()

main()
