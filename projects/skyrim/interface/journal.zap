# What the journal's system page asks of the game (quest_journal.swf's GameDelegate calls) that the
# game answers by writing into the movie's own objects: the version it shows, the help topics and
# their texts. The lists of saved games are saves.zap's; the quit list's platform and the Kinect
# option are the canned answers openJournal gives.

import engine.swf.avm1
import skyrim.esm
import skyrim

# the executable's file version (SkyrimSE.exe of the player's install), the text the system page
# shows in its corner
gameVersion = "1.7.104.0"

# a help topic: its title and its text
pub type HelpTopic:
	title str
	text str

# whether a message record of the plugin is a topic of the help list: the long text of the PC's
# keys, not the popups of the moment (short texts, tutorials, low meters) nor the gamepad's copy
fn isHelpTopic(editorId str):
	if not editorId.startsWith("Help") or editorId.startsWith("HelpBars"): return false
	for word in ["Short", "Console", "Tutorial"]:
		if editorId.indexOf(word) != none: return false
	true

# The help topics in the order the list shows them, by title: the plugin's help messages (MESG
# whose editor id starts with Help) of the PC, the longest text of each title.
pub fn helpTopics(mut t GameTexts) HelpTopic[]:
	g = t.plugin.topGroup("MESG") ?? return []
	d, records = t.plugin.topRecords(g)
	best {str: HelpTopic} = {}
	for h in records:
		body = esm.recordBody(d, h.at, h.flags, h.span) ?? continue
		fields = esm.fieldsOf(body)
		if not isHelpTopic(esm.textOf(body, fields, "EDID")): continue
		r = esm.Record(kind = "MESG", formId = h.formId, flags = h.flags, body = body.copy(),
			fields = fields.copy())
		title = t.names.localText(r, "FULL")
		text = t.descriptions.localText(r, "DESC")
		if title.isEmpty or text.isEmpty: continue
		if best.get(title) is old and old.text.len >= text.len: continue
		best[title.copy()] = HelpTopic(title = title.copy(), text)
	best.values().sortedBy(.title.lower())

# What the game writes into the objects the system page hands it, answered at once as the page's
# code goes on from the call (it sorts the help list the call filled and starts its state): the
# version in its corner and the help list and its texts.
pub fn answerSystemPage(mut p avm1.Player, mut t GameTexts):
	topics = t.helpTopics()
	rows = []
	for k, topic in topics:
		rows.push(avm1.Row(members = [avm1.Member("text", .Str(topic.title.copy())),
			avm1.Member("index", .Num(f64(k)))]))
	p.m.replies["SetVersionText"] = [.Text(0, gameVersion.copy())]
	p.m.replies["PopulateHelpTopics"] = [.Fill(0, rows)]
	# RequestHelpText's arguments are the topic's index, the title's field and the text's
	p.m.replies["RequestHelpText"] = [.TextAt(1, 0, topics.map(.title.copy())),
		.TextAt(2, 0, topics.map(.text.copy()))]
