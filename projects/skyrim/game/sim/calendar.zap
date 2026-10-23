# The game's calendar, after UESP's Skyrim:Calendar: the plugin's globals GameYear, GameMonth (0
# for Morning Star), GameDay and GameHour give the day the game begins on, 17 Last Seed 4E 201; the
# clock (GameWorld.daysPassed, from midnight of that day) moves the date on through months of the
# Gregorian lengths. That first day is a Sundas (the game's own captures say so) and the week goes
# on from it.

globalYear = 0x35
globalMonth = 0x36
globalDay = 0x37
monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

pub type Date:
	year i64
	month i64   # 0 Morning Star
	day i64   # 1 the first of the month
	weekday i64   # 0 Sundas
	hour i64
	minute i64

# the date and time the world's clock reads
pub fn dateOf(w GameWorld) Date:
	days = i64(w.daysPassed.floor())
	minutes = i64(((w.daysPassed - days) * 24.0 * 60.0).floor())
	d = Date(
		year = i64(w.globals.get(globalYear) ?? 201.0),
		month = i64(w.globals.get(globalMonth) ?? 7.0),
		day = i64(w.globals.get(globalDay) ?? 17.0) + days,
		weekday = days % 7,
		hour = minutes / 60,
		minute = minutes % 60
	)
	while d.day > monthDays[d.month]:
		d.day -= monthDays[d.month]
		d.month += 1
		if d.month == monthDays.len:
			d.month = 0
			d.year += 1
	d
