# The loading of libraries on Linux (`zap build --target linux`): each declaration takes the place
# of the one of the same name (the compiler's target.zap; a Windows function by the one named with
# its first letter lowered). The C library's dlopen and dlsym stand
# for LoadLibraryA and GetProcAddress, so a library is named by its file ("libvulkan.so.1").

extern "libc.so.6" fn dlopen(name str, flags i64) i64
extern "libc.so.6" fn dlsym(library i64, name str) i64

# RTLD_NOW
loadNow = 2

pub fn loadLibraryA(name str) i64:
	dlopen(name, loadNow)

pub fn getProcAddress(module i64, name str) i64:
	dlsym(module, name)
