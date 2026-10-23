# The CPU's side of the texture the mip stage reads (mips.gpu.zap): a texture array as the packer
# names it, by its id (the RHI binds the view itself).
pub type TextureArray:
	id i64
