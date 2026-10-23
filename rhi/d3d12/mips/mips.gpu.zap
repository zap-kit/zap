# The pixel stage Direct3D 12's mip levels are made with (resources.zap there): a screen pass over a
# level, each texel the bilinear sample of the level above at its center (for a halving, the
# average of the 2 x 2 texels it covers), as Vulkan's linear blit makes them. The level above is
# one layer of one level, seen as an array of one layer (a view of any texture), sampled at layer 0.

# the level above, as an array of one layer
pub type MipParams:
	above TextureArray

# the level above, sampled at the texel's center
pub fn pixel(uv Vec2, p MipParams) Vec4:
	p.above.sample(uv, 0.0)
