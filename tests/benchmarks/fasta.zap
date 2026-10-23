# fasta: DNA sequences, one repeated and two drawn from weighted alphabets with a linear
# congruential generator.

import fs
import problems

alu = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"
lineLen = 60
roundLen = 64 * lineLen   # the draws sent at a time
im u32 = 139_968   # the generator: s -> (s * ia + ic) % im
ia u32 = 3877
ic u32 = 29_573

# the running sums of the probabilities
fn cumulative(probs f64[]):
	total = 0.0
	sums = []
	for p in probs:
		total += p
		sums.push(total)
	sums

# the ALU repeated to n characters: alu.len lines end where they began, so one block of them
# is written again and again
fn writeRepeat(header str, n i64, out Stream):
	out.print(header)
	twice = alu + alu
	block = []
	for line in 0..alu.len:
		at = line * lineLen % alu.len
		block.extend(twice[at..at + lineLen].bytes())
		block.push('\n')
	left = n
	while left > 0:
		chars = left.min(alu.len * lineLen)
		lines = chars / lineLen
		out.writeBytes(block[..lines * (lineLen + 1)])
		if chars % lineLen != 0:
			at = lines * (lineLen + 1)
			out.writeBytes(block[at..at + chars % lineLen])
			out.print("")
		left -= chars

# the letter of every draw: the first whose running sum reaches draw / im
fn letterTable(letters str, sums f64[]):
	table u8[] = []
	table.reserve(i64(im))
	for d in 0..i64(im):
		r = d / 139968.0
		k = 0
		while sums[k] < r:
			k += 1
		table.push(letters[k])
	table

# the generator's numbers from 42 for sequences of the counts, in order, sent in rounds of at
# most roundLen, a sequence's last one cut at its end
fn drawRounds(counts i64[], rounds Channel<u32[]>):
	sends = rounds
	s = 42
	for n in counts:
		for done in 0..n step roundLen:
			count = roundLen.min(n - done)
			draws u32[] = []
			draws.reserve(count)
			loop count:
				s = (s * ia + ic) % im
				draws.push(s)
			sends.send(draws)
	true

# a sequence of n characters, each draw's letter read from the table, its rounds of draws
# taken in order from the drawer
fn writeRandom(header str, letters str, probs f64[], n i64, rounds Channel<u32[]>, out Stream):
	table = letterTable(letters, cumulative(probs))
	out.print(header)
	takes = rounds
	line u8[] = []
	line.reserve(roundLen + roundLen / lineLen + 1)
	left = n
	while left > 0:
		draws = takes.receive() ?? return
		left -= draws.len
		line.clear()
		for at in 0..draws.len step lineLen:
			for d in draws[at..(at + lineLen).min(len)]:
				line.push(table[d])
			line.push('\n')
		out.writeBytes(line)

n = arg(0, 1000)
out = stdout
rounds = Channel<u32[]>(4)
background((): drawRounds([n * 3, n * 5], rounds))
writeRepeat(">ONE Homo sapiens alu", n * 2, out)
writeRandom(
	">TWO IUB ambiguity codes",
	"acgtBDHKMNRSVWY",
	[0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02],
	n * 3,
	rounds,
	out
)
writeRandom(
	">THREE Homo sapiens frequency",
	"acgt",
	[0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008],
	n * 5,
	rounds,
	out
)

test "the DNA sequences repeat and draw from their alphabets as the reference's":
	main()
	prints fs.readFile("tests/benchmarks/fasta.expected") ?? ""

test "the C, Rust and Python programs print the same bytes":
	expect problems.agree("fasta")
