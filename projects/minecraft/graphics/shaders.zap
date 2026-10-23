# The game's programs, their Zap shaders kept in shaders/ (GPU files) and built with the game.
# Light is computed in linear color and written to a half float target (values above 1 are
# bright enough to bloom); the last pass maps it to the screen. The sky's color is one function
# (shared.gpu.zap's skyColor) for the sky, the fog and the water's reflections, so the far land
# melts into the sky behind it.

import engine
import graphics.shaders

fn worldProgram():
	engine.newProgram(shader(shaders.worldVertex, shaders.worldPixel))

fn shadowProgram():
	engine.newProgram(shader(shaders.shadowVertex, shaders.shadowPixel))

fn skyViewPass():
	engine.newScreenPass(shader(shaders.skyViewPixel))

fn skyPass():
	engine.newScreenPass(shader(shaders.skyPixel))

fn finalPass():
	engine.newScreenPass(shader(shaders.finalPixel))
