# A module in several files and dirs: `parts` names the files (sums.zap) and dirs (shapes/, with
# its subfolders) beside the file that are its own, their names seen bare. `import tiny` finds the
# file tiny.zap when there is no dir tiny/; a dir's subfolder outside parts is a module nested in
# it (geo.units).
parts sums, shapes
import tiny
import geo
import geo.units

test "parts share the module's names; a file alone is a module":
	s = Square(3)
	expect s.area() == 9
	expect twice(s.perimeter()) == 24
	expect tiny.half(42) == 21
	expect geo.origin() == 0
	expect units.meters(2) == "2 m"
