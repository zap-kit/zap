# The HUD as hud.c and print.c draw it: 16 x 16 glyphs on the console's 320 x 240 screen
# (scaled to the window), Mario's lives at the top left, the stars at the top right, the
# camera's state at the bottom right. Text is a glyph every 12 units, its top at 224 - y.

import engine
import stage

pub type Hud:
	glyphs engine.GpuTexture[]

hudTopY = 209
starsX = 78

pub fn newHud(st stage.Stage) Hud:
	Hud(
		glyphs = st.hud.map(g:
			g.newTexture(engine.sharpClamped)
		)
	)

# the HUD over what is drawn, on a w x h screen
pub fn drawHud(mut r engine.Renderer, h Hud, w i64, hh i64, lives i64, stars i64):
	if h.glyphs.len < 15: return
	r.beginOverlay(w, hh, engine.Camera())
	kx = f32(w) / 320.0
	ky = f32(hh) / 240.0
	# lives: Mario's head, x, the count
	r.label(h, kx, ky, 22, hudTopY, [stage.hudMarioHead])
	r.label(h, kx, ky, 38, hudTopY, [stage.hudMultiply])
	r.label(h, kx, ky, 54, hudTopY, digits(lives))
	# stars: the star, x (under 100), the count
	right = 320 - starsX
	r.label(h, kx, ky, right, hudTopY, [stage.hudStar])
	if stars < 100:
		r.label(h, kx, ky, right + 16, hudTopY, [stage.hudMultiply])
	r.label(h, kx, ky, (14 if stars < 100 else 0) + 320 - (starsX - 16), hudTopY, digits(stars))
	# the camera: its icon and Lakitu's head (render_hud_tex_lut: the top left at x, y)
	r.glyph(h, kx, ky, 320 - 54, 205, stage.hudCameraIcon)
	r.glyph(h, kx, ky, 320 - 54 + 16, 205, stage.hudLakitu)

fn digits(n i64):
	"{n}".bytes().map(i64(it) - i64('0'))

# a text label: glyph j at x + 12 j, its top at 224 - y
fn label(mut r engine.Renderer, h Hud, kx f32, ky f32, x i64, y i64, glyphs i64[]):
	for j, glyph in glyphs:
		r.glyph(h, kx, ky, x + j * 12, 224 - y, glyph)

fn glyph(mut r engine.Renderer, h Hud, kx f32, ky f32, x i64, y i64, g i64):
	r.drawQuad(h.glyphs[g].texture(), f32(x) * kx, f32(y) * ky, 16.0 * kx, 16.0 * ky)
