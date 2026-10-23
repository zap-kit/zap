# Where the prepared files live, and making them: the district's world (district.zap) and the
# skater (skater.zap), decoded from the user's disc image into projects/skate3/assets/.

import ea
import xbox
import fs

pub defaultDistrict = "DIST_University"
pub isoOption = ArgOption("--iso", true, "the disc image")
pub districtOption = ArgOption("--district", true, "the district to work on")
pub assetsDir = "projects/skate3/assets"

# the prepared skater
pub skaterFile = "projects/skate3/assets/skater.bin"

# the dir of a district's prepared files
pub fn districtDir(district str) str:
	"{assetsDir}/{district}"

# What a tool looking into a district works on, from the command line: the disc (--iso, or the
# one found), the district (--district, or the default) and the BIG archive of its streams; stops
# with the reason when one cannot be opened.
pub fn openToolDistrict() (xbox.Disc, str, ea.Big):
	disc = xbox.openUserDisc(args.option("--iso")) ?? fail
	district = args.option("--district") ?? defaultDistrict
	big = disc.openDistrictBig(district) ?? fail
	(disc, district, big)

# whether the district's world and the skater are prepared
pub fn isPrepared(district str) bool:
	fs.exists("{districtDir(district)}/world.bin") and
		fs.exists("{districtDir(district)}/collision.bin") and fs.exists(skaterFile)

# Decodes the district and the skater from the disc into projects/skate3/assets/; none when done, else why
# not.
pub fn prepareAll(given str?, district str) str?:
	disc = xbox.openUserDisc(given) ?? return error
	started = clockSeconds()
	report = (line str): print("  {line} ({(clockSeconds() - started):.1} s)")
	print("Preparing {district} and the skater from {disc.path} into {assetsDir}/ (once)")
	_ = fs.createDir(assetsDir)
	world = disc.decodeWorld(district, report) ?? return error
	world.saveWorld(districtDir(district)) ??
		return "cannot write {districtDir(district)}: {error}"
	report("{district} written")
	skater = disc.decodeSkater() ?? return error
	skater.saveSkater(skaterFile) ?? return "cannot write {skaterFile}: {error}"
	report("the skater: {skater.meshes.len} meshes, {skater.textures.len} textures")
	none
