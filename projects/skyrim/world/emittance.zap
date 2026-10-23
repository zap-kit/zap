# The color the parts lit by their reference's emittance source (XEMI) take: a light's color, or a
# region's weather's effect lighting color blended by the hour as the executable blends it
# (TESObjectCELL 0x1402ba000 fills TESRegion+0x40 by Sky::FillColorBlend 0x140416760 and
# Sky::SetColor 0x140414cf0, the weather given as both the current and the outgoing one).

# A source's weathers (a light's: none) and their colors at each time of day (sunrise, day, sunset,
# night; four a weather, a light's four of its one color), and the hours its blend turns at: the
# climate's sunrise begin and end and sunset begin and end, the first and last widened by
# fDaytimeColorExtension.
pub type Emittance:
	weathers i64[]
	colors Vec3[]
	hours Vec4

# a source of no color: the parts keep theirs
pub noEmittance = Emittance(
	weathers = [],
	colors = fill(4, Vec3(1.0, 1.0, 1.0)),
	hours = Vec4(6.0, 8.0, 18.0, 20.0)
)

# The weather outside while no exterior sky runs: the region's is the sky's current one, and every
# capture of the inn shows SkyrimClear's (its day effect lighting, 105 114 118).
pub capturedWeather = 0x81A

sunrise = 0
day = 1
sunset = 2
night = 3

# the two times of day the hour falls between and the first one's share (Sky::FillColorBlend 0x140416760)
pub fn timeShares(h Vec4, hour f32) Tuple3<i64, i64, f32>:
	if h.x < hour and hour < h.y:
		half = (h.y - h.x) * 0.5
		middle = h.x + half
		toward = day if middle <= hour else night
		return (sunrise, toward, 1.0 - (hour - middle).abs() * (1.0 / half))
	if hour >= h.y and hour <= h.z: return (day, day, 1.0)
	if h.z < hour and hour < h.w:
		half = (h.w - h.z) * 0.5
		middle = h.z + half
		toward = night if middle <= hour else day
		return (sunset, toward, 1.0 - (hour - middle).abs() * (1.0 / half))
	(night, night, 1.0)

# the source's color at this hour with this weather outside (its first when it has not that one)
pub fn emittanceAt(e Emittance, weather i64, hour f32) Vec3:
	k = e.weathers.indexOf(weather) ?? 0
	first, second, share = e.hours.timeShares(hour)
	e.colors[k * 4 + first] * share + e.colors[k * 4 + second] * (1.0 - share)
