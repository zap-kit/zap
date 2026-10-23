# Where the game keeps its compiled scripts: "Skyrim - Misc.bsa" under scripts/, one PEX a
# script, named by the script in lower case.

import skyrim

pub scriptDir = "scripts/"

# the archive key of the script with this name (any case)
pub fn scriptKey(name str) str:
	"{scriptDir}{name.lower()}.pex"

# the script with this name read from the install, or why it cannot be had
pub fn loadScript(install skyrim.Install, name str) Script ? str:
	key = scriptKey(name)
	bytes = install.installRead(key) ?? return "no script {name} ({key})"
	readPex(bytes)
