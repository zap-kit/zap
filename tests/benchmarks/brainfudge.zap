# brainfudge: an interpreter of the eight-instruction tape language running mandel.b (Erik Bosman's
# mandelbrot viewer), stopped after n lines of output. The program is compiled once to a list of
# operations: runs of + and - or of < and > folded into one, each bracket knowing its partner.
import fs
import problems

type Kind:
	Add
	Move
	Out
	In
	Open
	Close

type Op:
	kind Kind
	arg i32

# the operations of the program's text; `arg` of a bracket is the index of its partner
fn compile(text ref str):
	ops Op[] = []
	open = []
	for c in text.bytes():
		match c:
			'+', '-':
				by = 1 if c == '+' else -1
				if not ops.isEmpty and ops[len - 1].kind == .Add: ops[len - 1].arg += by
				else: ops.push(Op(.Add, by))
			'>', '<':
				by = 1 if c == '>' else -1
				if not ops.isEmpty and ops[len - 1].kind == .Move: ops[len - 1].arg += by
				else: ops.push(Op(.Move, by))
			'.': ops.push(Op(.Out, 0))
			',': ops.push(Op(.In, 0))
			'[':
				open.push(ops.len)
				ops.push(Op(.Open, 0))
			']':
				start = open.pop() ?? 0
				ops[start].arg = i32(ops.len)
				ops.push(Op(.Close, i32(start)))
			_: pass
	ops
# the program run until it has written n lines: what it wrote
fn run(ops Op[], n i64):
	tape u8[] = zeros(1 << 20)
	out = []
	head = 0
	lines = n
	pc = 0
	while pc < ops.len:
		op = ops[pc]
		match op.kind:
			Add: tape[head] += u8(op.arg & 255)
			Move: head += op.arg
			Out:
				out.push(tape[head])
				if tape[head] == '\n':
					lines -= 1
					if lines == 0: break
			In: tape[head] = 0
			Open:
				if tape[head] == 0: pc = op.arg
			Close:
				if tape[head] != 0: pc = op.arg
		pc += 1
	out

n = i64.parse(args.first ?? "2") ?? 2
stdout.writeBytes(run(compile(fs.readFile("tests/benchmarks/mandel.b") ?? ""), n))

test "the interpreter runs mandel.b to the lines it is asked for":
	main()
	prints fs.readFile("tests/benchmarks/brainfudge.expected") ?? ""

test "the C, Rust and Python programs print the same bytes":
	expect problems.agree("brainfudge")
