# Where a response's voice lies: sound/voice/<plugin>/<the speaker's voice type>/<quest>_<topic>_
# <INFO's form id, its plugin's index dropped>_<response number>.fuz, in lower case, the INFO
# being the one whose responses are said (a shared INFO's). The quest's and the topic's editor ids
# share 25 letters: when they are longer together, the quest keeps its first 10 and the topic the
# rest (the rule the archives' keys bear out, tests.zap).

import skyrim
import skyrim.esm
import engine.audio.xwma

pub voiceDir = "sound/voice/skyrim.esm"

# the quest and topic part of a voice file's name
pub fn voiceStem(quest str, topic str) str:
	q = quest.lower()
	tp = topic.lower()
	if q.len + tp.len > 25:
		q = q[..q.len.min(10)].copy()
		tp = tp[..tp.len.min(25 - q.len)].copy()
	"{q}_{tp}"

# the key of the voice file of response number `n` of the INFO in the topic of the quest, for a
# voice type
pub fn voiceKey(voiceType str, quest str, topic str, info i64, n i64) str:
	"{voiceDir}/{voiceType.lower()}/{voiceStem(quest, topic)}_{info & 0xFF_FFFF:08x}_{n}.fuz"

# the voice key of the response for the speaker's voice type: the INFO said's (shared or its own)
pub fn responseKey(mut t Talk, speaker i64, info Info, r Response) str:
	said = t.dialogue.infos[t.dialogue.spokenId(info)]
	topic = t.dialogue.topics.get(said.topic)?.editorId ?? ""
	quest = t.dialogue.quests.get(said.quest)?.editorId ?? ""
	voice = t.people.get(speaker)?.voice ?? 0
	voiceType = t.plugin.baseRecord(voice)?.editorId ?? ""
	voiceKey(voiceType, quest, topic, said.formId, r.number)

# a voice file read through: its lip frames and its sound decoded
pub type VoiceFile:
	lip skyrim.Lip
	seconds f64   # the sound's length decoded

# The voice file with this key, its lip data read and its sound decoded to the end, or why it
# cannot be had.
pub fn readVoice(install skyrim.Install, key str) VoiceFile ? str:
	bytes = install.installRead(key) ?? return "{key} is in no archive"
	fuz = skyrim.readFuz(bytes) ?? return "{key}: {error}"
	lip = skyrim.readLip(fuz.lip) ?? return "{key}: {error}"
	format = xwma.readXwmaFormat(fuz.sound) ?? return "{key}: its sound is no xWMA"
	stream = xwma.openXwma(fuz.sound.copy()) ?? return "{key}: its xWMA does not open"
	samples = []
	frames = 0
	loop 100_000:
		n = stream.readXwma(samples)
		if n == 0: break
		frames += n
		samples.clear()
	if frames == 0: return "{key}: its sound decodes to nothing"
	VoiceFile(lip, seconds = f64(frames) / f64(format.sampleRate.max(1)))
