# The sockets on Linux (`zap build --target android`): each declaration takes the place of the
# Winsock one of the same name (the compiler's target.zap), done with Linux's system calls, which
# answer -1 and keep the error where WSAGetLastError finds it, as Winsock does.

extern "syscall socket" fn sysSocket(family i64, kind i64, protocol i64) i64
extern "syscall bind" fn sysBind(s i64, addr SockAddrIn, length i64) i64
extern "syscall listen" fn sysListen(s i64, backlog i64) i64
extern "syscall connect" fn sysConnect(s i64, addr SockAddrIn, length i64) i64
extern "syscall getsockname" fn sysGetsockname(s i64, mut addr SockAddrIn, length i32[]) i64
extern "syscall sendto" fn sysSendto(s i64, buf u8[], n i64, flags i64, to i64, length i64) i64
extern "syscall sendto" fn sysSendtoAddr(
	s i64,
	buf u8[],
	n i64,
	flags i64,
	to SockAddrIn,
	length i64
) i64
extern "syscall recvfrom" fn sysRecvfrom(
	s i64,
	buf u8[],
	n i64,
	flags i64,
	source i64,
	length i64
) i64
extern "syscall recvfrom" fn sysRecvfromAddr(
	s i64,
	buf u8[],
	n i64,
	flags i64,
	mut source SockAddrIn,
	length i32[]
) i64
extern "syscall setsockopt" fn sysSetsockopt(
	s i64,
	level i64,
	name i64,
	value i32[],
	length i64
) i64
extern "syscall shutdown" fn sysShutdown(s i64, how i64) i64
extern "syscall getsockopt" fn sysGetsockopt(
	s i64,
	level i64,
	name i64,
	value i32[],
	length i32[]
) i64
extern "syscall accept4" fn sysAccept4(s i64, addr i64, length i64, flags i64) i64
extern "syscall ppoll" fn sysPpoll(fds u8[], n i64, timeout u8[], mask i64, size i64) i64

# MSG_NOSIGNAL: a send to a closed connection fails instead of ending the process (SIGPIPE)
noSignal = 0x4000

# an answer of a system call as Winsock gives it: -1 for an error
fn answer(r i64) i32:
	i32.wrap(-1 if rt.failed(r) else r)   # (a count, which fits)

fn wSAStartup(version i64, info u8[]) i32:
	_ = version
	_ = info
	0

# Winsock's code of the last error, from Linux's number
fn wSAGetLastError() i32:
	match rt.lastErrno():
		111: 10_061   # ECONNREFUSED
		98: 10_048   # EADDRINUSE
		11: 10_035   # EAGAIN: WSAEWOULDBLOCK
		115: 10_036   # EINPROGRESS
		114: 10_037   # EALREADY
		103: 10_053   # ECONNABORTED
		104: 10_054   # ECONNRESET
		32, 108: 10_058   # EPIPE, ESHUTDOWN
		4: 10_004   # EINTR
		9, 88: 10_038   # EBADF, ENOTSOCK
		e: i32.wrap(e)   # (another: its own number)

fn socket(family i64, kind i64, protocol i64) i64:
	answer(sysSocket(family, kind | 0x8_0000, protocol))   # SOCK_CLOEXEC

fn bind(s i64, addr SockAddrIn, length i64):
	answer(sysBind(s, addr, length))

fn listen(s i64, backlog i64):
	answer(sysListen(s, backlog))

fn accept(s i64, addr i64, length i64) i64:
	answer(sysAccept4(s, addr, length, 0x8_0000))

fn connect(s i64, addr SockAddrIn, length i64):
	answer(sysConnect(s, addr, length))

fn send(s i64, buf u8[], n i64, flags i64):
	answer(sysSendto(s, buf, n, flags | noSignal, 0, 0))

fn recv(s i64, buf u8[], n i64, flags i64):
	answer(sysRecvfrom(s, buf, n, flags, 0, 0))

fn sendto(s i64, buf u8[], n i64, flags i64, to SockAddrIn, length i64):
	answer(sysSendtoAddr(s, buf, n, flags | noSignal, to, length))

fn recvfrom(s i64, buf u8[], n i64, flags i64, mut source SockAddrIn, sourceLen i32[]):
	answer(sysRecvfromAddr(s, buf, n, flags, source, sourceLen))

fn getsockname(s i64, mut addr SockAddrIn, length i32[]):
	answer(sysGetsockname(s, addr, length))

fn closesocket(s i64):
	answer(rt.sysClose(s))

# Windows' SOL_SOCKET (65535) is Linux's 1; SO_EXCLUSIVEADDRUSE (-5) is what a Linux socket
# does already
fn setsockopt(s i64, level i64, name i64, value i32[], length i64) i32:
	if level == 65_535 and name == -5: return 0
	answer(sysSetsockopt(s, 1 if level == 65_535 else level, name, value, length))

# FIONBIO, the one request the module makes
fn ioctlsocket(s i64, cmd i64, arg i32[]):
	_ = cmd
	answer(rt.sysIoctl(s, 0x5421, arg))

# SD_SEND (1) is Linux's SHUT_WR (1) too
fn shutdown(s i64, how i64):
	answer(sysShutdown(s, how))

# the socket waited on until it can be read (or written, when forWrite), a fifth of a second at
# most: a ppoll of POLLIN or POLLOUT
fn waitFor(s i64, forWrite bool):
	fds = rt.zeroBytes(8)
	fds.setU32le(0, u32.wrap(s))   # (a descriptor fits: never a stop)
	fds.setU16le(4, 4 if forWrite else 1)
	timeout = rt.zeroBytes(16)
	timeout.setU64le(8, 200_000_000)
	rt.blockingBegin()
	sysPpoll(fds, 1, timeout, 0, 8)
	rt.blockingEnd()

# whether a receive on the socket would answer at once: a ppoll of POLLIN that does not wait
fn readable(s i64):
	fds = rt.zeroBytes(8)
	fds.setU32le(0, u32.wrap(s))   # (a descriptor fits: never a stop)
	fds.setU16le(4, 1)   # POLLIN
	sysPpoll(fds, 1, rt.zeroBytes(16), 0, 8) > 0

# 1 when a connecting socket is connected, -1 when the attempt failed, 0 while in progress: a
# poll of POLLOUT that does not wait, then the socket's SO_ERROR
fn connectState(s i64):
	fds = rt.zeroBytes(8)
	fds.setU32le(0, u32.wrap(s))   # (a descriptor fits: never a stop)
	fds.setU16le(4, 4)   # POLLOUT
	if sysPpoll(fds, 1, rt.zeroBytes(16), 0, 8) <= 0: return 0
	err i32[] = [0]
	length i32[] = [4]
	sysGetsockopt(s, 1, 4, err, length)   # SOL_SOCKET, SO_ERROR
	1 if err[0] == 0 and fds.u16le(6) & 24 == 0 else -1   # no POLLERR, no POLLHUP
