// brainfudge: an interpreter of the eight-instruction tape language running mandel.b, stopped after n lines of output.
use std::io::Write;

#[derive(Clone, Copy, PartialEq)]
enum Kind {
    Add,
    Move,
    Out,
    In,
    Open,
    Close,
}

#[derive(Clone, Copy)]
struct Op {
    kind: Kind,
    arg: i32, // the run's length (Add, Move, signed) or the matching bracket's index
}

fn compile(text: &[u8]) -> Vec<Op> {
    let mut ops: Vec<Op> = Vec::new();
    let mut open: Vec<usize> = Vec::new();
    for &c in text {
        let step = if c == b'+' || c == b'>' { 1 } else { -1 };
        match c {
            b'+' | b'-' | b'>' | b'<' => {
                let kind = if c == b'+' || c == b'-' { Kind::Add } else { Kind::Move };
                match ops.last_mut() {
                    Some(last) if last.kind == kind => last.arg += step,
                    _ => ops.push(Op { kind, arg: step }),
                }
            }
            b'.' => ops.push(Op { kind: Kind::Out, arg: 0 }),
            b',' => ops.push(Op { kind: Kind::In, arg: 0 }),
            b'[' => {
                open.push(ops.len());
                ops.push(Op { kind: Kind::Open, arg: 0 });
            }
            b']' => {
                let start = open.pop().unwrap();
                ops[start].arg = ops.len() as i32;
                ops.push(Op { kind: Kind::Close, arg: start as i32 });
            }
            _ => {}
        }
    }
    ops
}

fn main() {
    let mut lines: i64 = std::env::args().nth(1).and_then(|a| a.parse().ok()).unwrap_or(1);
    let text = std::fs::read("tests/benchmarks/mandel.b").unwrap();
    let ops = compile(&text);

    let mut tape = vec![0u8; 1 << 20];
    let mut out: Vec<u8> = Vec::new();
    let mut head: usize = 0;
    let mut pc = 0;
    while pc < ops.len() {
        let op = ops[pc];
        match op.kind {
            Kind::Add => tape[head] = tape[head].wrapping_add(op.arg as u8),
            Kind::Move => head = head.wrapping_add(op.arg as isize as usize),
            Kind::Out => {
                out.push(tape[head]);
                if tape[head] == b'\n' {
                    lines -= 1;
                    if lines == 0 {
                        break;
                    }
                }
            }
            Kind::In => tape[head] = 0,
            Kind::Open => {
                if tape[head] == 0 {
                    pc = op.arg as usize;
                }
            }
            Kind::Close => {
                if tape[head] != 0 {
                    pc = op.arg as usize;
                }
            }
        }
        pc += 1;
    }
    std::io::stdout().lock().write_all(&out).unwrap();
}
