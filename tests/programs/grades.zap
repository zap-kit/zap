# Student grade report: structs, lists of structs, sorting, averages and padded output.
type Student:
	name str
	scores i64[]

	fn average():
		if scores.isEmpty: return 0.0
		total = 0
		for s in scores:
			total += s
		f64(total) / f64(scores.len)

	fn letter():
		avg = average()
		if avg >= 90.0:
			return "A"
		elif avg >= 80.0:
			return "B"
		elif avg >= 70.0:
			return "C"
		"F"
students = [
	Student(name = "Ana", scores = [90, 95, 100]),
	Student(name = "Bruno", scores = [70, 65, 80]),
	Student(name = "Carla", scores = [85, 80, 90]),
	Student(name = "Davi", scores = []),
]
ranked = students.sortedBy(-.average())
for s in ranked:
	print("{s.name:<8} {s.average():>6.1}  {s.letter()}")
best = ranked.first
match best:
	s: print("best: {s.name}")
	none: print("no students")
total = students.map(.scores.len).sum()
print("total scores: {total}")

test "the grade report sorts, averages and pads its rows":
	main()
	prints """
	    Ana        95.0  A
	    Carla      85.0  B
	    Bruno      71.7  C
	    Davi        0.0  F
	    best: Ana
	    total scores: 9
	    """
