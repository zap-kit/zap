# The VGA screen as SDLPoP draws it (seg009.c method_6_blit_img_to_scr, method_3_blit_mono,
# blit_xor, method_5_rect, peels, flip_screen): an offscreen picture of the room's 192 lines the
# tables are drawn on, the onscreen one of 200 lines (with the status line) it is copied to, and
# the 256 colours of the VGA's DAC that the monochrome blits and the rectangles take theirs from.

import dos
import dos.pop
import image

pub screenWidth = 320
pub screenHeight = 200
pub gameplayHeight = 192

# the blitters
pub blitNoTransp = 0
pub blitOr = 2
pub blitXor = 3
pub blitBlack = 9
pub blitTransp = 0x10
pub blitMono = 0x40

pub type Palette:
	colors image.Rgba8[]   # 256: the DAC's rows of 16

	# set_pal: a DAC colour from 6-bit components
	pub mut fn setPal(index i64, r i64, g i64, b i64):
		colors[index] = dos.vgaColor(r & 63, g & 63, b & 63)

	# set_loaded_palette for one row: the 16 colours of a palette resource
	pub mut fn setRow(row i64, p dos.Palette):
		for i in 0..16:
			colors[row * 16 + i] = p.colors[i]

pub type Screen:
	offscreen image.Image
	onscreen image.Image
	toOnscreen bool = true   # current_target_surface: the displayed screen but while the tables draw
	toOverlay bool = false   # the menu's translucent layer, drawn over the display
	overlay image.Image = image.Image(screenWidth, screenHeight, fill = image.Rgba8(0, 0, 0, 0))
	clip Rect = Rect(0, 0, 200, 320)

	fn pixelAt(x i64, y i64):
		if toOnscreen: return onscreen[x, y]
		offscreen[x, y]

	mut fn put(x i64, y i64, c image.Rgba8):
		if x < clip.left or x >= clip.right or y < clip.top or y >= clip.bottom: return
		if toOverlay:
			if x >= 0 and x < screenWidth and y >= 0 and y < screenHeight:
				overlay[x, y] = c
		elif toOnscreen:
			if x >= 0 and x < screenWidth and y >= 0 and y < screenHeight:
				onscreen[x, y] = c
		elif x >= 0 and x < screenWidth and y >= 0 and y < offscreen.height:
			offscreen[x, y] = c

	fn height():
		screenHeight if toOnscreen else gameplayHeight

	# the drawing of an image of a sprite table at (x, y) by blitter `blit`, mirrored when `flip`;
	# a blitter 0x40..0x4F draws the opaque pixels in the DAC's colour blit & 0xBF
	pub mut fn drawPicture(pal Palette,
		table pop.SpriteTable,
		p pop.Picture,
		x i64,
		y i64,
		blit i64,
		flip bool
	):
		for py in 0..p.height:
			for px in 0..p.width:
				sx = p.width - 1 - px if flip else px
				index = p.indices[py * p.width + sx]
				tx = x + px
				ty = y + py
				if tx < 0 or tx >= screenWidth or ty < 0 or ty >= self.height(): continue
				if blit == blitNoTransp:
					self.put(tx, ty, black if index == 0 else table.palette.colors[index])
				elif index == 0:
					continue
				elif blit == blitXor:
					c = table.palette.colors[index]
					old = self.pixelAt(tx, ty)
					self.put(tx, ty, image.Rgba8(old.r ^ c.r, old.g ^ c.g, old.b ^ c.b, 255))
				elif blit == blitBlack:
					self.put(tx, ty, pal.colors[0])
				elif blit >= blitMono and blit < blitMono + 0x40:
					self.put(tx, ty, pal.colors[blit & 0xBF])
				else:
					self.put(tx, ty, table.palette.colors[index])

	# method_3_blit_mono: a picture's opaque pixels in the DAC's colour `color`
	pub mut fn drawMono(pal Palette, p pop.Picture, x i64, y i64, color i64):
		for py in 0..p.height:
			for px in 0..p.width:
				if p.indices[py * p.width + px] != 0:
					self.put(x + px, y + py, pal.colors[color])

	# draw_rect: a rectangle in a DAC colour
	pub mut fn drawRect(pal Palette, r Rect, color i64):
		for y in r.top..r.bottom:
			for x in r.left..r.right:
				self.put(x, y, pal.colors[color & 255])

	# read_peel_from_screen
	pub fn readPeel(r Rect) Peel:
		w = (r.right - r.left).max(0)
		h = (r.bottom - r.top).max(0)
		pixels = image.Image(w.max(1), h.max(1), fill = black)
		for y in 0..h:
			for x in 0..w:
				sx = r.left + x
				sy = r.top + y
				if sx >= 0 and sx < screenWidth and sy >= 0 and sy < self.height():
					pixels[x, y] = self.pixelAt(sx, sy)
		Peel(rect = r, pixels)

	# restore_peel: the saved pixels laid back
	pub mut fn restorePeel(p Peel):
		w = p.rect.right - p.rect.left
		h = p.rect.bottom - p.rect.top
		for y in 0..h:
			for x in 0..w:
				self.put(p.rect.left + x, p.rect.top + y, p.pixels[x, y])

	# copy_screen_rect: a rectangle of the offscreen picture onto the screen; upside down (the
	# potion's) the picture is flipped and the rectangle with it
	pub mut fn copyRect(r Rect, upsideDown bool):
		h = offscreen.height
		top = r.top
		bottom = r.bottom
		if upsideDown:
			top = h - r.bottom
			bottom = h - r.top
		for y in top.max(0)..bottom.min(h).min(screenHeight):
			sy = h - 1 - y if upsideDown else y
			for x in r.left.max(0)..r.right.min(screenWidth):
				onscreen[x, y] = offscreen[x, sy]

	# the gameplay's 192 lines copied whole
	pub mut fn copyToOnscreen(upsideDown bool):
		self.copyRect(Rect(0, 0, gameplayHeight, screenWidth), upsideDown)

	# the picture kept off the display made `height` lines high (192 in play, 200 for the title and
	# the cutscenes after an ending), black
	pub mut fn makeOffscreen(height i64):
		offscreen = image.Image(screenWidth, height, fill = black)

	# a fade's step: the display the picture off it darkened by `pos` steps of 4 (fade_in_frame,
	# fade_out_frame)
	pub mut fn fadeOnscreen(pos i64):
		d = pos * 4
		for y in 0..offscreen.height.min(screenHeight):
			for x in 0..screenWidth:
				c = offscreen[x, y]
				onscreen[x, y] = image.Rgba8(
					u8((c.r - d).max(0)),
					u8((c.g - d).max(0)),
					u8((c.b - d).max(0)),
					255
				)

	pub mut fn resetClip():
		clip = Rect(0, 0, 200, 320)

# what a peel saved of the screen under a character
pub type Peel:
	rect Rect
	pixels image.Image

black = image.Rgba8(0, 0, 0, 255)

pub fn newScreen() Screen:
	Screen(
		offscreen = image.Image(screenWidth, gameplayHeight, fill = black),
		onscreen = image.Image(screenWidth, screenHeight, fill = black)
	)

pub fn newPalette() Palette:
	Palette(colors = fill(256, black))

# ---------- pixels ----------
