# What EA's formats share beside their byte reading (std's bytes module): the asset ids written
# as the game names them, and offsets rounded up to an alignment.

# a 64-bit id as 16 hexadecimal digits, as the game names its assets
pub fn hex64(v i64) str:
	"{u64(v):016X}"
