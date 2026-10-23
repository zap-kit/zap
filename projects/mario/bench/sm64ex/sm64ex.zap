# The PC port the rewrite is measured and traced against: sm64ex built with the harness
# (projects/mario/bench/README.md).

import fs

fn portVariable():
	EnvVariable(
		"SM64EX",
		"the sm64ex build the bench runs against (default: projects/mario/bench/pc/sm64ex/build/us_pc)"
	)

# the dir of the port's build
pub fn dir() str:
	portVariable().value() ?? "projects/mario/bench/pc/sm64ex/build/us_pc"

# the port's executable, named whole (it runs from its own dir) as the system names one
pub fn exe() str:
	fs.join(currentDir(), "{dir()}/sm64.us.f3dex2e{exeSuffix()}")
