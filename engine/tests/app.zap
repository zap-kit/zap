# What the frames cost: intervals and work logged, summed up, and the late frames found.

import engine

test "frames logged: intervals from the second on, work from each":
	t = engine.FrameTimes()
	# frames beginning at 0, 16, 32 and 72 ms, working 5, 8, 12 and 5 ms of each
	for (began, work) in [(0.0, 5.0), (0.016, 8.0), (0.032, 12.0), (0.072, 5.0)]:
		t.logFrame(began, began + work / 1000.0)
	expect t.intervals.len == 3
	expect t.work.len == 4
	expect engine.timesText("frame interval", t.intervals.map(.round())) == "frame interval: mean 24.00 ms, deviation 11.31, median 16.00, 95% 40.00, 99% 40.00, worst 40.00"
	expect engine.timesText("work", t.work.map(.round())) ==
		"work: mean 7.50 ms, deviation 2.87, median 8.00, 95% 12.00, 99% 12.00, worst 12.00"

test "the report: the late frames past those skipped":
	t = engine.FrameTimes(intervals = [100.0, 16.0, 36.0, 16.0], work = [50.0, 4.0, 4.0, 4.0, 4.0])
	t.printTimes(skip = 1)
	prints """
		frame interval: mean 22.67 ms, deviation 9.43, median 16.00, 95% 36.00, 99% 36.00, worst 36.00
		work: mean 4.00 ms, deviation 0.00, median 4.00, 95% 4.00, 99% 4.00, worst 4.00
		late frames: 1 of 3, frames [3]
		"""

test "no frames: a summary that says so":
	expect engine.timesText("work", []) == "work: none"
