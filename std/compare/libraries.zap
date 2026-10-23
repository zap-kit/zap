# The C libraries the other languages' programs link (`-l<name>` in a problem's flags) that the
# machine may lack: GMP for pidigits. What a library needs that the machine does not have is a
# package of MSYS2's UCRT64 repository (headers, static and import libraries, DLLs, programs),
# fetched once a machine (fs.cacheDir("zap")) and given to what builds and runs the programs through
# the variables they read: gcc's and g++'s C_INCLUDE_PATH, CPLUS_INCLUDE_PATH and LIBRARY_PATH
# (cargo links through gcc), PKG_CONFIG_PATH, and PATH for the programs and the DLL Python loads.

import fs

msysPackages = "https://mirror.msys2.org/mingw/ucrt64/"

# a package of MSYS2's, and the command that succeeds when the machine has what it brings
type Package:
	name str
	probe str
	input str = ""   # the probe's stdin

# the packages a library needs
fn packagesOf(library str) Package[]:
	match library:
		"gmp", "gmpxx":
			[
				Package(name = "gmp", probe = "gcc -E -x c -", input = "#include <gmp.h>\n"),
				# cargo's gmp-mpfr-sys (use-system-libs) finds the library by pkg-config
				Package(name = "pkgconf", probe = "pkg-config --version")
			]
		_: []

# the packages of the libraries of flags each found, or fetched and given to this process's builds
# and runs (once a process); Linux's are the system's own (its package manager's)
fn provideLibraries(flags str):
	if not onWindows(): return
	for word in flags.split(" "):
		if not word.startsWith("-l"): continue
		for package in packagesOf(word[2..]):
			if package.name in librariesGiven: continue
			librariesGiven.push(package.name.copy())
			if Process.output(package.probe, input = package.input).code == 0: continue
			dir = "{fs.cacheDir("zap")}/{package.name}"
			if not fs.isFetched(dir) and not fetchPackage(package.name, dir):
				eprint("note: {package.name} could not be fetched into {dir}")
				continue
			for name, sub in packageVariables:
				before = env.get(name) ?? ""
				env[name] = "{dir}/{sub}" if before == "" else "{before};{dir}/{sub}"

# each variable a package's dir is added to, and the dir of the package it names
packageVariables = {
	"C_INCLUDE_PATH": "include",
	"CPLUS_INCLUDE_PATH": "include",
	"LIBRARY_PATH": "lib",
	"PKG_CONFIG_PATH": "lib/pkgconfig",
	"PATH": "bin"
}

mut librariesGiven str[] = []

# the package's latest build for UCRT64 unpacked into dir (what its ucrt64/ holds); whether it was
fn fetchPackage(package str, dir str):
	prefix = "mingw-w64-ucrt-x86_64-{package}-"
	names = fs
		.fetchText(msysPackages)
		.split("\"")
		.filter(
		.startsWith(prefix) and .len > prefix.len and it[prefix.len].isDigit() and
		.endsWith(".pkg.tar.zst")
		)
	name = names.sorted().last ?? return false
	eprint("note: fetching {package} from MSYS2 into {dir} (once a machine)")
	fs.fetchUnpacked("{msysPackages}{name}", "ucrt64", dir)
