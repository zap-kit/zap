// brainfudge: an interpreter of the eight-instruction tape language running mandel.b, stopped after n lines of output.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

enum Kind : uint8_t { Add, Move, Out, In, Open, Close };

struct Op {
    Kind kind;
    int arg; // the run's length (Add, Move, signed) or the matching bracket's index
};

static std::vector<Op> compile(const std::string &text) {
    std::vector<Op> ops;
    std::vector<size_t> open;
    for (char c : text) {
        int step = c == '+' || c == '>' ? 1 : -1;
        switch (c) {
        case '+': case '-':
            if (!ops.empty() && ops.back().kind == Add) ops.back().arg += step;
            else ops.push_back({Add, step});
            break;
        case '>': case '<':
            if (!ops.empty() && ops.back().kind == Move) ops.back().arg += step;
            else ops.push_back({Move, step});
            break;
        case '.': ops.push_back({Out, 0}); break;
        case ',': ops.push_back({In, 0}); break;
        case '[': open.push_back(ops.size()); ops.push_back({Open, 0}); break;
        case ']': {
            size_t start = open.back();
            open.pop_back();
            ops[start].arg = static_cast<int>(ops.size());
            ops.push_back({Close, static_cast<int>(start)});
            break;
        }
        }
    }
    return ops;
}

int main(int argc, char **argv) {
#ifdef _WIN32
    _setmode(1, _O_BINARY); // the runner compares bytes: no CRLF translation
#endif
    long long lines = argc > 1 ? atoll(argv[1]) : 1;
    std::ifstream file("tests/benchmarks/mandel.b", std::ios::binary);
    std::string text((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    std::vector<Op> ops = compile(text);

    std::vector<uint8_t> tape(1 << 20);
    std::string out;
    size_t head = 0;
    for (size_t pc = 0; pc < ops.size(); pc++) {
        Op op = ops[pc];
        switch (op.kind) {
        case Add: tape[head] += static_cast<uint8_t>(op.arg); break;
        case Move: head += op.arg; break;
        case Out:
            out.push_back(static_cast<char>(tape[head]));
            if (tape[head] == '\n' && --lines == 0) pc = ops.size();
            break;
        case In: tape[head] = 0; break;
        case Open: if (tape[head] == 0) pc = op.arg; break;
        case Close: if (tape[head] != 0) pc = op.arg; break;
        }
    }
    fwrite(out.data(), 1, out.size(), stdout);
    return 0;
}
