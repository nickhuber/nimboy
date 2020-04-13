import os

import cpu
import memory


const ROM_NAME_OFFSET = 0x134
const ROM_TYPE_OFFSET = 0x147
const ROM_ROM_SIZE_OFFSET = 0x148
const ROM_RAM_SIZE_OFFSET = 0x149


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
