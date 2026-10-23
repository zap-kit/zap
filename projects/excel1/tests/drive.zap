# The floppy drive and its controller: a track's bits read as the IWM's data register gives them,
# turn after turn, and cells with no flux transition for more than three cells read as noise.

import disk
import mac

motorOn = 0xDF_E1FF + 9 * 0x200
dataRegister = 0xDF_E1FF + 12 * 0x200

# drive 1 holding one track of the nibbles' bits
fn insert(nibbles u8[]):
	track = disk.Track(bits = nibbles.copy(), count = nibbles.len * 8)
	mac.drives[1] = mac.Drive(tracks = [track], track = 0, at = 0, zeros = 0)
	mac.iwmSwitch(motorOn)

fn read(count i64):
	out = []
	loop count:
		out.push(u8(mac.iwmRead(dataRegister)))
	out

test "the data register gives the track's nibbles, turn after turn":
	insert([0xD5, 0xAA, 0x96, 0xFF, 0xFE])
	expect read(7).map("{it:02x}").join(" ") == "d5 aa 96 ff fe d5 aa"

test "cells past three without a transition read as noise, the rest as written":
	# 0x81 holds six cells without a transition
	insert([0xD5, 0xAA, 0x81, 0x81, 0x81, 0x81, 0xFF, 0xFF])
	first = read(64)
	second = read(64)
	print("{first[..2]} {first != second}")
	prints "[213, 170] true"

test "the tracks prepare.zap writes read back":
	moof = disk.Moof(tracks = [disk.Track(bits = [0xD5, 0xAA], count = 15)])
	tracks = disk.readTracks(moof.tracksBytes())
	print("{tracks.len} {tracks[0].count} {tracks[0].bits}")
	prints "1 15 [213, 170]"
