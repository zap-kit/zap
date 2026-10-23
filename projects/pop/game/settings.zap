# SDLPoP.cfg (SDLPoP's menu.c save_ingame_settings and load_ingame_settings): what the menu changed
# is kept in the settings' directory when the menu closes, and read over SDLPoP.ini's at the start.
# The file is this port's own text (SDLPoP's is a dump of its structs, valid only for its own
# executable's checksum).

import fs

pub fn saveSettings(mut g Game):
	g.options.values["is_sound_on"] = [1 if g.soundOn else 0]
	_ = fs.writeBytes("{g.settingsDir}/SDLPoP.cfg", g.options.cfgText().bytes().copy())

# the options a game starts with: the ini's and the cfg's
pub fn useOptions(mut g Game, o Options):
	g.options = o.copy()
	g.soundOn = o.isOn("is_sound_on")
