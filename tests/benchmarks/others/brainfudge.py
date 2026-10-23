# brainfudge: an interpreter of the eight-instruction tape language running mandel.b, stopped after n lines of output
import sys

ADD, MOVE, OUT, IN, OPEN, CLOSE = range(6)


def compile_program(text):
    ops = []   # [kind, arg]: a run's length (ADD, MOVE, signed) or the matching bracket's index
    stack = []
    for c in text:
        if c in "+-":
            step = 1 if c == "+" else -1
            if ops and ops[-1][0] == ADD:
                ops[-1][1] += step
            else:
                ops.append([ADD, step])
        elif c in "<>":
            step = 1 if c == ">" else -1
            if ops and ops[-1][0] == MOVE:
                ops[-1][1] += step
            else:
                ops.append([MOVE, step])
        elif c == ".":
            ops.append([OUT, 0])
        elif c == ",":
            ops.append([IN, 0])
        elif c == "[":
            stack.append(len(ops))
            ops.append([OPEN, 0])
        elif c == "]":
            start = stack.pop()
            ops[start][1] = len(ops)
            ops.append([CLOSE, start])
    return ops


def run(ops, lines):
    tape = bytearray(1 << 20)
    out = bytearray()
    head = 0
    pc = 0
    count = len(ops)
    while pc < count:
        kind, arg = ops[pc]
        if kind == ADD:
            tape[head] = (tape[head] + arg) & 255
        elif kind == MOVE:
            head += arg
        elif kind == OPEN:
            if tape[head] == 0:
                pc = arg
        elif kind == CLOSE:
            if tape[head] != 0:
                pc = arg
        elif kind == OUT:
            out.append(tape[head])
            if tape[head] == 10:
                lines -= 1
                if lines == 0:
                    break
        else:
            tape[head] = 0
        pc += 1
    return out


lines = int(sys.argv[1]) if len(sys.argv) > 1 else 1
with open("tests/benchmarks/mandel.b") as f:
    program = compile_program(f.read())
sys.stdout.buffer.write(run(program, lines))   # bytes: no CRLF translation, the runner compares bytes
