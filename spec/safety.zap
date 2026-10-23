# 4.5 Rules the compiler enforces
#
# Four rules make memory safe without a collector, each error naming both places, so the fix is a
# reordering, never a copy: no use after move (4.1); any number of `ref` borrows or one `mut ref`,
# the owner not changed while one lives (4.3); no reference outliving its origin (4.4); what a job
# or a channel carries owns all it holds (9).
