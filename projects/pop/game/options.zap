# SDLPoP's options (options.c, replay.c): SDLPoP.ini read by option name, and the options as the
# sections a replay file embeds. Each option is a list of numbers (one for most) of a byte width,
# negative when signed; the sections are the lists of options below in the order of replay.c's
# options_process_* functions, so a replay's bytes read here and these write there.

import fs

# what an option is: its name, the bytes of a number, and the defaults (one number each)
type OptionField:
	name str
	size i64
	defaults i64[]

type Section:
	fields OptionField[]

fn one(name str, size i64, v i64):
	OptionField(name.copy(), size, [v])

fn flag(name str, on bool):
	OptionField(name.copy(), 1, [1 if on else 0])

fn array(name str, size i64, v i64[]):
	OptionField(name.copy(), size, v.copy())

vgaDefault = [
	0, 0, 0, 0, 0, 42, 0, 42, 0, 0, 42, 42, 42, 0, 0, 42, 0, 42, 42, 21, 0, 42, 42, 42,
	21, 21, 21, 21, 21, 63, 21, 63, 21, 21, 63, 63, 63, 21, 21, 63, 21, 63, 63, 63, 21, 63, 63, 63
]

featureFields = [
	flag("enable_copyprot", false),
	flag("enable_quicksave", true),
	flag("enable_quicksave_penalty", true)
]

enhancementFields = [
	flag("use_fixes_and_enhancements", false),
	flag("enable_crouch_after_climbing", true),
	flag("enable_freeze_time_during_end_music", true),
	flag("enable_remember_guard_hp", true),
	flag("enable_super_high_jump", true),
	flag("enable_jump_grab", true)
]

# read and written under SDLPoP.ini's names but acting on nothing: the fixes stay off
fixNames = [
	"fix_gate_sounds",
	"fix_two_coll_bug",
	"fix_infinite_down_bug",
	"fix_gate_drawing_bug",
	"fix_bigpillar_climb",
	"fix_jump_distance_at_edge",
	"fix_edge_distance_check_when_climbing",
	"fix_painless_fall_on_guard",
	"fix_wall_bump_triggers_tile_below",
	"fix_stand_on_thin_air",
	"fix_press_through_closed_gates",
	"fix_grab_falling_speed",
	"fix_skeleton_chomper_blood",
	"fix_move_after_drink",
	"fix_loose_left_of_potion",
	"fix_guard_following_through_closed_gates",
	"fix_safe_landing_on_spikes",
	"fix_glide_through_wall",
	"fix_drop_through_tapestry",
	"fix_land_against_gate_or_tapestry",
	"fix_unintended_sword_strike",
	"fix_retreat_without_leaving_room",
	"fix_running_jump_through_tapestry",
	"fix_push_guard_into_wall",
	"fix_jump_through_wall_above_gate",
	"fix_chompers_not_starting",
	"fix_feather_interrupted_by_leveldoor",
	"fix_offscreen_guards_disappearing",
	"fix_move_after_sheathe",
	"fix_hidden_floors_during_flashing",
	"fix_hang_on_teleport",
	"fix_exit_door",
	"fix_quicksave_during_feather",
	"fix_caped_prince_sliding_through_gate",
	"fix_doortop_disabling_guard",
	"fix_jumping_over_guard",
	"fix_drop_2_rooms_climbing_loose_tile",
	"fix_falling_through_floor_during_sword_strike"
]

# the fixes SDLPoP.ini has that a replay does not hold
laterFixNames = [
	"fix_register_quick_input",
	"fix_turn_running_near_wall",
	"fix_feather_fall_affects_guards",
	"fix_one_hp_stops_blinking",
	"fix_dead_floating_in_air"
]

customFields = [
	one("start_minutes_left", 2, 60),
	one("start_ticks_left", 2, 719),
	one("start_hitp", 2, 3),
	one("max_hitp_allowed", 2, 10),
	one("saving_allowed_first_level", 2, 3),
	one("saving_allowed_last_level", 2, 13),
	flag("start_upside_down", false),
	flag("start_in_blind_mode", false),
	one("copyprot_level", 2, 2),
	one("drawn_tile_top_level_edge", 1, 1),
	one("drawn_tile_left_level_edge", 1, 20),
	one("level_edge_hit_tile", 1, 20),
	flag("allow_triggering_any_tile", false),
	flag("enable_wda_in_palace", false),
	array("vga_palette", 1, vgaDefault),
	one("first_level", 2, 1),
	flag("skip_title", false),
	one("shift_L_allowed_until_level", 2, 4),
	one("shift_L_reduced_minutes", 2, 15),
	one("shift_L_reduced_ticks", 2, 719),
	one("demo_hitp", 2, 4),
	one("demo_end_room", 2, 24),
	one("intro_music_level", 2, 1),
	one("checkpoint_level", 2, 3),
	one("checkpoint_respawn_dir", -1, -1),
	one("checkpoint_respawn_room", 1, 2),
	one("checkpoint_respawn_tilepos", 1, 6),
	one("checkpoint_clear_tile_room", 1, 7),
	one("checkpoint_clear_tile_col", 1, 4),
	one("checkpoint_clear_tile_row", 1, 0),
	one("skeleton_level", 2, 3),
	one("skeleton_room", 1, 1),
	one("skeleton_trigger_column_1", 1, 2),
	one("skeleton_trigger_column_2", 1, 3),
	one("skeleton_column", 1, 5),
	one("skeleton_row", 1, 1),
	flag("skeleton_require_open_level_door", true),
	one("skeleton_skill", 1, 2),
	one("skeleton_reappear_room", 1, 3),
	one("skeleton_reappear_x", 1, 133),
	one("skeleton_reappear_row", 1, 1),
	one("skeleton_reappear_dir", 1, 0),
	one("mirror_level", 2, 4),
	one("mirror_room", 1, 4),
	one("mirror_column", 1, 4),
	one("mirror_row", 1, 0),
	one("mirror_tile", 1, 13),
	flag("show_mirror_image", true),
	one("falling_exit_level", 2, 6),
	one("falling_exit_room", 1, 1),
	one("falling_entry_level", 2, 7),
	one("falling_entry_room", 1, 17),
	one("mouse_level", 2, 8),
	one("mouse_room", 1, 16),
	one("mouse_delay", 2, 150),
	one("mouse_object", 1, 24),
	one("mouse_start_x", 1, 200),
	one("loose_tiles_level", 2, 13),
	one("loose_tiles_room_1", 1, 23),
	one("loose_tiles_room_2", 1, 16),
	one("loose_tiles_first_tile", 1, 22),
	one("loose_tiles_last_tile", 1, 27),
	one("jaffar_victory_level", 2, 13),
	one("jaffar_victory_flash_time", 1, 18),
	one("hide_level_number_from_level", 2, 14),
	one("level_13_level_number", 1, 12),
	one("victory_stops_time_level", 2, 13),
	one("win_level", 2, 14),
	one("win_room", 1, 5),
	one("loose_floor_delay", 1, 11),
	one("shadow_steal_level", 1, 5),
	one("shadow_steal_room", 1, 24),
	one("shadow_step_level", 1, 6),
	one("shadow_step_room", 1, 1)
]

levelFields = [
	array("tbl_level_type", 1, [0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0]),
	array("tbl_level_color", 2, [0, 0, 0, 1, 0, 0, 0, 1, 2, 2, 0, 0, 3, 3, 4, 0]),
	array("tbl_guard_type", -2, [0, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 0, 4, 3, -1, -1]),
	array("tbl_guard_hp", 1, [4, 3, 3, 3, 3, 4, 5, 4, 4, 5, 5, 5, 4, 6, 0, 0]),
	array("tbl_cutscenes_by_index", 1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
	array("tbl_entry_pose", 1, [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0]),
	array("tbl_seamless_exit", -1, [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 23, -1, -1, -1])
]

# what the ini sets and the replay does not keep
otherFields = [
	array("strikeprob", 2, [61, 100, 61, 61, 61, 40, 100, 220, 0, 48, 32, 48]),
	array("restrikeprob", 2, [0, 0, 0, 5, 5, 175, 16, 8, 0, 255, 255, 150]),
	array("blockprob", 2, [0, 150, 150, 200, 200, 255, 200, 250, 0, 255, 255, 255]),
	array("impblockprob", 2, [0, 61, 61, 100, 100, 145, 100, 250, 0, 145, 255, 175]),
	array("advprob", 2, [255, 200, 200, 200, 255, 255, 200, 0, 0, 255, 100, 100]),
	array("refractimer", 2, [16, 16, 16, 16, 8, 8, 8, 8, 0, 8, 0, 0]),
	array("extrastrength", 2, [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]),
	one("have_sword_from_level", 2, 2),
	one("base_speed", 1, 5),
	one("fight_speed", 1, 6),
	one("chomper_speed", 1, 15),
	flag("no_mouse_in_ending", false),
	flag("use_custom_options", true),
	flag("enable_replay", true),
	flag("enable_pause_menu", true),
	flag("is_sound_on", true),
	flag("enable_info_screen", true),
	flag("enable_music", true),
	flag("enable_controller_rumble", true),
	one("joystick_threshold", 4, 8000),
	flag("joystick_only_horizontal", true),
	flag("start_fullscreen", false),
	one("use_hardware_acceleration", 1, 2),
	flag("use_correct_aspect_ratio", false),
	flag("use_integer_scaling", false),
	one("scaling_type", 1, 0),
	flag("enable_fade", true),
	flag("enable_flash", true),
	flag("enable_lighting", false)
]

# the keys of the controls settings, by the engine's virtual-key codes (SDLPoP's are SDL scancodes)
keyFields = [
	one("key_left", 4, 37),
	one("key_right", 4, 39),
	one("key_up", 4, 38),
	one("key_down", 4, 40),
	one("key_jump_left", 4, 36),
	one("key_jump_right", 4, 33),
	one("key_action", 4, 16),
	one("key_enter", 4, 13),
	one("key_esc", 4, 27)
]

fn fixFields():
	fixNames.map(flag(it, true))

# the five sections of a replay's options, in the file's order
fn replaySections():
	[
		Section(featureFields),
		Section(enhancementFields),
		Section(fixFields()),
		Section(customFields),
		Section(levelFields)
	]

fn defaultValues():
	m {str: i64[]} = {}
	for section in replaySections():
		for f in section.fields:
			m[f.name.copy()] = f.defaults.copy()
	for f in otherFields:
		m[f.name.copy()] = f.defaults.copy()
	for f in keyFields:
		m[f.name.copy()] = f.defaults.copy()
	for n in laterFixNames:
		m[n.copy()] = [1]
	m

# the options of SDLPoP's `custom` struct: the ones use_custom_options switches to their defaults
fn customNames():
	names = []
	for f in customFields:
		names.push(f.name.copy())
	for f in levelFields:
		names.push(f.name.copy())
	for n in [
		"strikeprob",
		"restrikeprob",
		"blockprob",
		"impblockprob",
		"advprob",
		"refractimer",
		"extrastrength",
		"have_sword_from_level",
		"base_speed",
		"fight_speed",
		"chomper_speed",
		"no_mouse_in_ending"
	]:
		names.push(n.copy())
	names

pub type Options:
	values {str: i64[]} = defaultValues()
	saved {str: i64[]} = {}   # custom_saved while use_custom_options is off: `custom` is the defaults

	# the first number of an option
	pub fn opt(name str) i64:
		values[name][0]

	pub fn optAt(name str, i i64) i64:
		values[name][i]

	pub fn isOn(name str) bool:
		values[name][0] != 0

	# a fix or an enhancement, in force only when the master option is on (SDLPoP's `fixes`)
	pub fn hasFix(name str) bool:
		values["use_fixes_and_enhancements"][0] == 1 and values[name][0] != 0

	# an option's numbers: custom_saved's while the customization is off
	fn stored(name str):
		if not self.isOn("use_custom_options") and name in self.saved:
			return self.saved[name].copy()
		self.values[name].copy()

	# turn_custom_options_on_off: the customization switched, its options kept while it is off
	pub mut fn setCustomOn(on bool):
		if on == self.isOn("use_custom_options"): return
		defaults = defaultValues()
		for name in customNames():
			if on:
				if name in self.saved: self.values[name.copy()] = self.saved[name].copy()
			else:
				saved[name.copy()] = self.values[name].copy()
				values[name.copy()] = defaults[name].copy()
		values["use_custom_options"] = [1 if on else 0]

	fn sectionBytes(fields OptionField[]):
		out u8[] = []
		for f in fields:
			for v in self.stored(f.name):
				out.pushNumber(v, f.size)
		out

	# the options of a section set from its bytes (the ones past its end keep what they were)
	fn setSection(fields OptionField[], b u8[]):
		at = 0
		for f in fields:
			nums = []
			loop values[f.name].len:
				size = f.size.abs()
				if at + size > b.len: return
				v = 0
				for k in 0..size:
					v |= i64(b[at + k]) << (8 * k)
				if f.size < 0 and v >= (1 << (8 * size - 1)):
					v -= 1 << (8 * size)
				nums.push(v)
				at += size
			values[f.name.copy()] = nums

	# the bytes of a replay's options section, 0..4
	pub fn replayBytes(section i64) u8[]:
		self.sectionBytes(replaySections()[section].fields)

	pub mut fn setReplayBytes(section i64, b u8[]):
		self.setSection(replaySections()[section].fields, b)

	# one ini entry (ini_load's report): `section` as written, `name` and `value` trimmed
	fn setEntry(section str, name str, value str):
		if value.lower() == "default": return
		key = name.lower().copy()
		target = key.copy()
		at = 0
		sec = section.lower()
		if sec.startsWith("level "):
			level = i64.parse(sec[6..].trimmed()) ?? -1
			if level < 0 or level > 15 or not (key in levelKeys): return
			target = levelKeys[key.copy()].copy()
			at = level
		elif sec.startsWith("skill "):
			skill = i64.parse(sec[6..].trimmed()) ?? -1
			if skill < 0 or skill > 11: return
			at = skill
		elif key.startsWith("vga_color_"):
			n = i64.parse(key[10..]) ?? -1
			if n < 0 or n > 15: return
			parts = value.split(",").map((i64.parse(.trimmed()) ?? 0) / 4)
			for k in 0..3:
				if k < parts.len: values["vga_palette"][n * 3 + k] = parts[k]
			return
		if not (target in values): return
		if value.lower() == "true":
			values[target][at] = 1
		elif value.lower() == "false":
			values[target][at] = 0
		elif namedValue(value) is named:
			values[target][at] = named
		elif i64.parse(value) is n:
			values[target][at] = n

	# ini_load: every `name = value` of the text, comments from `;` on dropped
	pub mut fn readIni(text str):
		section = ""
		for raw in text.lines():
			line = raw.split(";")[0].trimmed()
			if line == "": continue
			if line.startsWith("["):
				section = line[1..line.len - 1].trimmed().copy()
				continue
			eq = line.indexOf("=") ?? -1
			if eq < 0: continue
			self.setEntry(section, line[..eq].trimmed(), line[eq + 1..].trimmed())
		self.settleCustom()

	# the customization read as off leaves `custom` at the defaults and its values in custom_saved
	fn settleCustom():
		if not self.isOn("use_custom_options"):
			values["use_custom_options"] = [1]
			self.setCustomOn(false)

	# the options the menu changes, which SDLPoP.cfg keeps (process_ingame_settings_*)
	fn cfgNames():
		names = [
			"enable_pause_menu",
			"enable_info_screen",
			"is_sound_on",
			"enable_music",
			"enable_controller_rumble",
			"joystick_threshold",
			"joystick_only_horizontal",
			"enable_replay",
			"start_fullscreen",
			"use_hardware_acceleration",
			"use_correct_aspect_ratio",
			"use_integer_scaling",
			"scaling_type",
			"enable_fade",
			"enable_flash",
			"enable_lighting",
			"enable_copyprot",
			"enable_quicksave",
			"enable_quicksave_penalty",
			"use_fixes_and_enhancements",
			"use_custom_options"
		]
		for f in keyFields:
			names.push(f.name.copy())
		for f in enhancementFields:
			names.push(f.name.copy())
		for n in fixNames:
			names.push(n.copy())
		for n in laterFixNames:
			names.push(n.copy())
		for n in customNames():
			names.push(n.copy())
		names

	# the text of SDLPoP.cfg: a line `name = numbers` for each option the menu changes
	pub fn cfgText() str:
		text = ""
		for name in self.cfgNames():
			numbers = []
			for v in self.stored(name):
				numbers.push("{v}")
			text = "{text}{name} = {numbers.join(",")}\n"
		text

	# the options of an SDLPoP.cfg's text set
	pub mut fn readCfg(text str):
		known = self.cfgNames()
		for line in text.lines():
			eq = line.indexOf("=") ?? -1
			if eq < 0: continue
			name = line[..eq].trimmed()
			if not (name in known): continue
			nums = []
			for part in line[eq + 1..].trimmed().split(","):
				nums.push(i64.parse(part.trimmed()) ?? 0)
			if nums.len == self.values[name].len: self.values[name.copy()] = nums
		self.settleCustom()

fn pushNumber(mut out u8[], v i64, size i64):
	for k in 0..size.abs():
		out.push(u8.wrap((v >> (8 * k)) & 0xFF))

tileNames = [
	"empty", "floor", "spike", "pillar", "gate", "stuck", "closer", "doortop_with_floor",
	"bigpillar_bottom", "bigpillar_top", "potion", "loose", "doortop", "mirror", "debris", "opener",
	"level_door_left", "level_door_right", "chomper", "torch", "wall", "skeleton", "sword",
	"balcony_left", "balcony_right", "lattice_pillar", "lattice_down", "lattice_small",
	"lattice_left", "lattice_right", "torch_with_debris"
]

# the names an ini value may have instead of a number
fn namedValue(text str) i64?:
	t = text.lower()
	for i in 0..tileNames.len:
		if tileNames[i] == t: return i
	match t:
		"top": 0
		"middle": 1
		"bottom": 2
		"left": -1
		"right", "turning": 0
		"falling": 1
		"running": 2
		"dungeon": 0
		"palace": 1
		"none": -1
		"guard": 0
		"fat": 1
		"skel": 2
		"vizier": 3
		"shadow": 4
		"never": 16
		_: none

# the ini keys of a [Level n] section, as the tables they set
levelKeys = {
	"level_type": "tbl_level_type",
	"level_color": "tbl_level_color",
	"guard_type": "tbl_guard_type",
	"guard_hp": "tbl_guard_hp",
	"cutscene": "tbl_cutscenes_by_index",
	"entry_pose": "tbl_entry_pose",
	"seamless_exit": "tbl_seamless_exit"
}

# the options of the SDLPoP.ini in a directory, the defaults when it has none
pub fn loadOptions(dir str) Options:
	o = Options()
	if fs.readFile("{dir}/SDLPoP.ini") is text: o.readIni(text)
	# SDLPoP.cfg (the menu's settings) overrides the ini, unless the ini is newer
	ini = fs.modified("{dir}/SDLPoP.ini") ?? 0
	cfg = fs.modified("{dir}/SDLPoP.cfg") ?? 0
	if cfg != 0 and ini <= cfg:
		if fs.readFile("{dir}/SDLPoP.cfg") is text: o.readCfg(text)
	o
