/* brainfudge: an interpreter of the eight-instruction tape language running mandel.b, stopped after n lines of output. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

enum { ADD, MOVE, OUT, IN, OPEN, CLOSE };

typedef struct {
    int op;
    int arg; /* the run's length (ADD, MOVE, signed) or the matching bracket's index */
} Op;

static size_t compile(const char *text, size_t len, Op *ops) {
    size_t n = 0, *stack = malloc(len * sizeof(size_t)), depth = 0;
    for (size_t i = 0; i < len; i++) {
        char c = text[i];
        int op = c == '+' || c == '-' ? ADD : c == '<' || c == '>' ? MOVE : c == '.' ? OUT : c == ',' ? IN
               : c == '[' ? OPEN : c == ']' ? CLOSE : -1;
        if (op < 0) continue;
        int step = c == '+' || c == '>' ? 1 : -1;
        if (op == ADD || op == MOVE) {
            if (n > 0 && ops[n - 1].op == op) ops[n - 1].arg += step;
            else ops[n++] = (Op){op, step};
        } else if (op == OPEN) {
            stack[depth++] = n;
            ops[n++] = (Op){OPEN, 0};
        } else if (op == CLOSE) {
            size_t open = stack[--depth];
            ops[open].arg = (int)n;
            ops[n++] = (Op){CLOSE, (int)open};
        } else {
            ops[n++] = (Op){op, 0};
        }
    }
    free(stack);
    return n;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); /* the runner compares bytes: no CRLF translation */
#endif
    long long lines = argc > 1 ? atoll(argv[1]) : 1;
    FILE *f = fopen("tests/benchmarks/mandel.b", "rb");
    if (!f) return 1;
    fseek(f, 0, SEEK_END);
    size_t len = (size_t)ftell(f);
    fseek(f, 0, SEEK_SET);
    char *text = malloc(len);
    if (fread(text, 1, len, f) != len) return 1;
    fclose(f);
    Op *ops = malloc(len * sizeof(Op));
    size_t count = compile(text, len, ops);

    static uint8_t tape[1 << 20];
    size_t head = 0;
    char *out = malloc(1 << 20);
    size_t outLen = 0;
    for (size_t pc = 0; pc < count; pc++) {
        Op op = ops[pc];
        switch (op.op) {
        case ADD: tape[head] += (uint8_t)op.arg; break;
        case MOVE: head += op.arg; break;
        case OUT:
            out[outLen++] = (char)tape[head];
            if (tape[head] == '\n' && --lines == 0) pc = count;
            break;
        case IN: tape[head] = 0; break;
        case OPEN: if (tape[head] == 0) pc = op.arg; break;
        case CLOSE: if (tape[head] != 0) pc = op.arg; break;
        }
    }
    fwrite(out, 1, outLen, stdout);
    return 0;
}
