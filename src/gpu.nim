import cpu
import memory

import sdl2


# See http://www.codeslinger.co.uk/pages/projects/gameboy/graphics.html for details

type
  LCDControlRegisters = enum
    LCDC = 0xFF40
    STAT = 0xFF41
    SCY = (0xFF42, "The Y Position of the BACKGROUND where to start drawing the viewing area from")
    SCX = (0xFF43, "The X Position of the BACKGROUND to start drawing the viewing area from")
    LY = 0xFF44
    LYC = 0xFF45
    DMA = 0xFF46
    BGP = 0xFF47
    OBP0 = 0xFF48
    OBP1 = 0xFF49
    WY = (0xFF4A, "The Y Position of the VIEWING AREA to start drawing the window from")
    WX = (0xFF4B, "The X Positions -7 of the VIEWING AREA to start drawing the window from ")


type
  GPU* = object
    window: WindowPtr
    renderer: RendererPtr
    cpu: CPU


proc newGPU*(cpu: CPU): GPU =
  var gpu = GPU()
  gpu.window = createWindow(
    "Nimboy",
    100,
    100,
    160,
    144,
    SDL_WINDOW_SHOWN
  )
  gpu.renderer = createRenderer(
    gpu.window,
    -1,
    Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture
  )
  gpu.cpu = cpu
  return gpu


proc renderTileSet(this: var GPU): void =
  # Maybe useful for debugging, this renders a bunch of the tiles
  this.renderer.setDrawColor(255, 255, 255, 255)
  this.renderer.clear()
  for t in 0..383:
    for x in 0..7:
      for y in 0..7:
        if this.cpu.bus.tiles[t][x][y] == 0:
          this.renderer.setDrawColor(255, 255, 255, 255)
        elif this.cpu.bus.tiles[t][x][y] == 1:
          this.renderer.setDrawColor(255, 0, 0, 255)
        elif this.cpu.bus.tiles[t][x][y] == 2:
          this.renderer.setDrawColor(0, 255, 0, 255)
        elif this.cpu.bus.tiles[t][x][y] == 3:
          this.renderer.setDrawColor(0, 0, 255, 255)
        this.renderer.drawPoint(
          cast[cint](x + ((t * 8) mod 160)),
          cast[cint](y + ((t div 19) * 8))
        )


proc render(this: var GPU): void =
  let lcdControl: uint8 = this.cpu.bus.retrieve(LCDC.ord().uint16)
  if ((lcdControl and 0x80) == 0x80):
    # The LCD is enabled
    this.renderTileSet()
    this.renderer.present()


proc step*(this: var GPU): void =
  this.render()
