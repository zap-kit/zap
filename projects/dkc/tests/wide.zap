# The widescreen picture (console/wide.zap): jungle.txt played with --wide, the 342-pixel picture's
# hash taken every frame. The native 256x224 picture stays Mesen 2's (routes.zap plays the same
# route without --wide); this baseline moves when the wide composition does, and `zap test
# --update` keeps the new one.
#   needs: projects/dkc/rom/dkc1.sfc (the player's dump, never committed)

import digest
import playing

test "jungle.txt played wide keeps its wide picture":
	playing.preparedAndBuilt()
	lines = playing.wideLines("jungle", 3300)
	expect lines.len == 3300
	for k in 0..33:
		print(lines[k * 100])
	print("drawn wide: {lines.filter(.endsWith(" 1")).len} of {lines.len}")
	print("all: {digest.fnv1a(lines.join(" ").bytes()):08x}")
	prints """
		1 3e5838c5 0 0000000000 1
		101 3ed495b8 0 0000000000 1
		201 8258794b 0 0000000000 1
		301 82b7f376 0 0000000000 1
		401 85acca0b 0 0000000000 2
		501 be27e7ac 0 0000000000 2
		601 be27e7ac 0 0000000000 2
		701 fa5bc1db 0 0000000000 2
		801 cca0db1b 0 0000000000 2
		901 750fb138 0 0000000000 2
		1001 13140bf7 0 0000000000 2
		1101 55fa0660 0 0000000000 2
		1201 92c52e05 0 0000000000 2
		1301 8190fe52 0 0000000000 2
		1401 6f4063bd 0 0000000000 2
		1501 a4ff381c 0 0000000000 2
		1601 3e5838c5 0 0000000000 1
		1701 afd8e9cc 0 0000000000 2
		1801 b1383c02 0 0000000000 2
		1901 7101df45 0 0000000000 2
		2001 1e4a184b 0 0000000000 2
		2101 bfe5c3ab 0 0000000000 2
		2201 ea8aa5fa 0 0000000000 2
		2301 bfe5c3ab 0 0000000000 2
		2401 3e5838c5 0 0000000000 1
		2501 48f5bb7d 1 d90000a3c0 0
		2601 43556901 1 d90000a3c0 0
		2701 3cd54963 1 d90000a3c0 0
		2801 a53eae54 1 d90000a3c0 0
		2901 744bf863 1 d90000a3c0 0
		3001 3489c72f 1 d90000a3c0 0
		3101 68c83e5d 1 d90000a3c0 0
		3201 7feaf175 0 0000000000 2
		drawn wide: 549 of 3300
		all: 046f790c
		"""
