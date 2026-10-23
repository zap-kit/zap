# The bench suite of this repository: every problem of tests/benchmarks/ against the same
# problem in C, C++, Rust and Python (others/), raced by std/compare; zap test keeps the ratios in
# bench.baseline (spec 13.1).
#
#   zap test --only bench [--full] [problem]
import compare
import problems

compare.suite(problems.problems(), mode: problems.inputFor(mode), args)
