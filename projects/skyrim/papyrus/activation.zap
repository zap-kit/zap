# The game's events that reach the scripts from the world: an activation (the default of
# game/sim's activate, then OnActivate sent to every script bound to the reference with the
# actor as akActionRef), a reference entering a trigger (OnTriggerEnter), and the quests whose
# scripts the dialogue hands to a script (a quest bound like a reference, by its VMAD).

import skyrim
import skyrim.esm
import game.sim

# Activates the reference by the actor and sends its scripts OnActivate, the threads run to their
# waits: what the default did and how many scripts had the event.
pub fn activateRef(mut vm Vm, refId i64, actorRef i64) (sim.Activation, i64):
	a = vm.rt.world.activate(refId, actorRef)
	if a is Refused: return (a, 0)
	actorObject = vm.lib.objectFor(vm.rt, actorRef, "objectreference")
	sent = vm.sendFormEvent(refId, "OnActivate", [.Object(actorObject)])
	vm.runThreads()
	(a, sent)

# the reference enters the trigger: its scripts get OnTriggerEnter; how many had the event
pub fn enterTrigger(mut vm Vm, trigger i64, refId i64) i64:
	entering = vm.lib.objectFor(vm.rt, refId, "objectreference")
	sent = vm.sendFormEvent(trigger, "OnTriggerEnter", [.Object(entering)])
	vm.runThreads()
	sent

# Binds every script of the quest by its VMAD (the properties its record sets), once: an object
# of the script already made for the quest (a property naming it) takes the properties. The
# objects bound to the quest.
pub fn bindQuestScripts(mut vm Vm, mut plugin esm.Esm, quest i64) i64[]:
	if (vm.rt.world.forms.get(quest) ?? return vm.bindQuestFirst(plugin, quest)).kind != "QUST":
		return vm.bindQuestFirst(plugin, quest)
	vm.objectsOf(quest)

fn objectsOf(vm Vm, form i64):
	out = []
	for k in 1..vm.rt.objects.len:
		if vm.rt.objects[k].form == form: out.push(k)
	out

fn bindQuestFirst(mut vm Vm, mut plugin esm.Esm, quest i64):
	vm.rt.world.addForm(quest)
	vm.rt.world.forms[quest].kind = "QUST"
	r = plugin.recordOf(quest) ?? return []
	vmad, _ = r.vmadOf() ?? return []
	for s in vmad.scripts:
		if s.status == 3: continue
		if vm.objectsOf(quest).find(vm.rt.objects[it].script == s.name.lower()) is made:
			vm.setProperties(made, s.properties)
		else:
			vm.bindScript(quest, s.name, s.properties)
	vm.objectsOf(quest)

# Binds the scripts of the quest with this editor id (bindQuestScripts): the object of the script
# with this name, none when the quest or the script is missing.
pub fn bindQuest(mut vm Vm, mut plugin esm.Esm, questId str, script str) i64?:
	quest = try plugin.formByEditorId("QUST", questId)
	vm.bindQuestScripts(plugin, quest)
	vm.boundObject(quest, script)

# the object bound to the form whose script is or extends this one, none when there is none
pub fn boundObject(vm Vm, form i64, script str) i64?:
	for k in 1..vm.rt.objects.len:
		o = vm.rt.objects[k]
		if o.form == form and
			(o.script == script.lower() or vm.lib.extendsScript(o.script, script)):
			return k
	none

# A VM over the world of the interior cell as a new game finds it (game/sim), its scripts bound
# and their OnInit run; or why the plugin cannot give the cell.
pub fn cellVm(
	move install skyrim.Install,
	mut plugin esm.Esm,
	names skyrim.Strings,
	cellId str
) Vm ? str:
	w = try install.worldOfCell(plugin, names, cellId)
	vm = newVm(install)
	vm.rt.world = w
	vm.bindCell(plugin.cellBindings(cellId) ?? [])
	vm.tick(0.0)
	vm

# The VM and plugin of the interior cell over the install's archives, none (and a line saying so)
# without the install: where a check of the world with its scripts starts.
pub fn archivesCellVm(cellId str) (esm.Esm, Vm)?:
	install = try skyrim.installOfArchives()
	plugin = esm.openEsm(install.installPlugin("Skyrim.esm")) ?? fail
	names = install.readNames("Skyrim.esm") ?? fail
	vm = cellVm(install, plugin, names, cellId) ?? fail
	(plugin, vm)
