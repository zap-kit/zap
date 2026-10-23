# The sound's two sample FIFOs (A and B): 32 bytes each, filled by the game's DMA, played a
# sample at each overflow of the timer SOUNDCNT_H picks; at 16 bytes or fewer the DMA set to
# the FIFO's timing fills it again.

mut fifos u8[2, ] = [[], []]
pub mut samples i8[2] = [0, 0]

pub fn fifoPush(which i64, half i64, v u16):
	if fifos[which].len > 28: return
	fifos[which].push(v & 0xFF)
	fifos[which].push(v >> 8)

# timer 0 or 1 overflowed at cycle `at`: the FIFOs it times play their next sample
pub fn soundTimerOverflow(timer i64, at i64):
	soundTo(at)
	control = ioHalf(0x82)
	for which in 0..2:
		if ((control >> u32(10 + 4 * which)) & 1) != timer: continue
		if not fifos[which].isEmpty:
			samples[which] = i8.wrap(fifos[which].remove(0))
		if fifos[which].len <= 16: fifoDma(which)

fn fifoReset(which i64):
	fifos[which].clear()
	samples[which] = 0

fn fifoDma(which i64):
	target = 0x0400_00A0 + 4 * which
	for ch in 1..3:
		if dmaEnabled(ch) and dmaTiming(ch) == 3 and io.u32le(dmaBase(ch) + 4) == target:
			runDma(ch)
