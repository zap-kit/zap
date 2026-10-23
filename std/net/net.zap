# TCP and UDP over the system sockets (Winsock on Windows): a listener accepts connections, a
# connection sends and receives bytes or lines; a UDP socket sends and receives datagrams.
# Addresses are IPv4 ("127.0.0.1", "localhost", "0.0.0.0"). What fails gives a Error. A module
# of the standard library: `import net`, then `listener = try net.tcpListen(port)`, net.TcpConn,
# net.udpBind(host, port).

# why a connection or a socket failed
pub type Error:
	Refused   # nobody listens at that address and port
	InUse   # the port is another socket's
	Closed   # the connection or the socket was closed, by this side or the other
	Malformed   # the peer sent bytes the protocol does not allow
	TimedOut   # nothing came within the time a wait was given
	Failed(code i64)   # another reason: the system's error code

# A listener, a connection and a UDP socket each close their socket when they go, or earlier by
# close().
pub type TcpListener:
	sock i64

	# The port it listens on (the one the system picked for port 0).
	fn port() i64:
		addr = sockAddr("0.0.0.0", 0)
		length i32[] = [16]
		getsockname(sock, addr, length)
		netOrder16(addr.port)

	# Waits for the next connection, `within` milliseconds at most (0: as long as it takes);
	# TimedOut when none came in time, Closed when the listener was closed.
	fn accept(within i64 = 0) TcpConn ? Error:
		since = clockMs()
		s = acceptSocket(sock)
		while s == -1 and wouldBlock():
			if within > 0 and clockMs() - since >= within: return Error.TimedOut
			waitFor(sock, false)
			s = acceptSocket(sock)
		if s == -1: return lastNetError()
		newConn(s)

	# The next connection if one is waiting, without waiting for one.
	fn poll() TcpConn?:
		s = acceptSocket(sock)
		if s == -1: return none
		newConn(s)

	fn close():
		sock = closeSocket(sock)

	mut fn drop():
		close()

# The bytes received and not yet taken are buf[start..stop], the bytes queued to send (a response,
# a frame: see http.zap, websocket.zap) are out, sent before the connection waits for more input.
pub type TcpConn:
	sock i64
	owns bool   # false for the sending half of a split: it never closes the socket
	buf u8[]
	start i64
	stop i64
	out u8[]

	# Sends every byte.
	fn send(bytes u8[]) ? Error:
		try sendAll(sock, bytes)

	fn sendStr(text str) ? Error:
		try sendAll(sock, text.bytes())

	fn sendLine(text str) ? Error:
		try sendStr("{text}\n")

	# Sends one message as a frame: a u32 length, then the bytes (`value.toBytes()`).
	fn sendFrame(bytes u8[]) ? Error:
		header = []
		rt.pushLe(header, bytes.len, 4)
		try sendAll(sock, header)
		try sendAll(sock, bytes)

	# Sends what was queued (see http.zap and websocket.zap).
	fn flush() ? Error:
		if not out.isEmpty:
			try sendAll(sock, out)
			out.truncate(0)
		return

	# The next frame's bytes (`Type.fromBytes(frame)`); Closed when the connection closed first.
	# No frame stops the program: what the peer sends is read, not trusted.
	fn receiveFrame() u8[] ? Error:
		try self.fillAtLeast(4)
		n = i64(buf.u32le(start))
		try self.fillAtLeast(4 + n)
		head = start   # (checked as the field is not: never out, for noStops)
		if head < 0 or head >= buf.len: return Error.Closed
		at = head + 4
		if at > buf.len: return Error.Closed
		frame = buf[at..].copy()
		if frame.len < n: return Error.Closed
		frame.truncate(n)
		start = at + n
		frame

	# receives until at least n bytes are held
	mut fn fillAtLeast(n i64) ? Error:
		while u64(stop) - u64(start) < u64(n):   # (stop is never below start: unsigned, no stop)
			try self.fill()
		return

	# Receives into the free end of the buffer (the queued output goes first, and the buffer is
	# compacted or doubled for room, up to 4 MiB: Malformed beyond); Closed when the other side did.
	# Unless it waits, nothing arrived leaves the buffer as it was.
	fn fill(wait bool = true) ? Error:
		if not out.isEmpty: try self.flush()
		if start == stop:
			start = 0
			stop = 0
		if buf.isEmpty:
			buf = zeros(16_384)
		from, to = start, stop   # (checked once as the fields are not: never out, for noStops)
		if from < 0 or to < from or to > buf.len: return Error.Malformed
		if to == buf.len:
			if from > 0 and from < buf.len:
				size = buf.len
				kept = buf[from..].copy()   # the unread bytes to the front, the room after them
				kept.truncate(to - from)
				kept.copyBytesTo(buf)
				buf.extend(zeros((size - kept.len).max(0)))
				stop = kept.len
				start = 0
			elif buf.len >= 4_194_304:
				return Error.Malformed
			else:
				buf.extend(zeros(buf.len))
		at = stop
		if at < 0 or at >= buf.len: return Error.Malformed
		if not wait and not readable(sock): return
		if wait: rt.blockingBegin()   # (the receive waits in the system: another job may run meanwhile)
		n = recvSocket(sock, buf[at..], buf.len - at)
		if wait: rt.blockingEnd()
		if n < 0 and wouldBlock() and not wait: return
		while n < 0 and wouldBlock():
			waitFor(sock, false)
			n = recvSocket(sock, buf[at..], buf.len - at)
		if n < 0: return lastNetError()
		if n == 0 or n > buf.len - at: return Error.Closed
		stop = at + n
		return

	# Up to max bytes as they arrive; Closed when the connection is closed.
	mut fn receive(max i64) u8[] ? Error:
		if stop == start:
			try self.fill()
		self.taken(max)

	# The bytes that have arrived, up to max, without waiting: empty when none has; Closed when the
	# connection is closed. A server that polls its connections and other sources in one loop reads
	# them by this.
	mut fn poll(max i64) u8[] ? Error:
		if stop == start:
			try self.fill(false)
		self.taken(max)

	# up to max of the bytes held, taken off the front
	fn taken(max i64):
		n = max.min(stop - start)
		bytes = buf[start..start + n].copy()
		start += n
		bytes

	# The next frame (sendFrame's) if it has arrived whole, without waiting; none while it has not.
	mut fn pollFrame() (u8[]?) ? Error:
		try self.fill(false)
		if not self.frameHeld(): return none
		try self.receiveFrame()

	# whether a whole frame is held (its length and its bytes)
	fn frameHeld():
		held = u64(stop) - u64(start)   # (stop is never below start)
		held >= 4 and held >= 4 + u64(buf.u32le(start))

	# The next line without its newline; a last unterminated line is returned too, then Closed.
	fn receiveLine() str ? Error:
		seen = 0   # bytes of the window already searched
		loop:
			for i in start + seen..stop:
				if buf[i] == 10:
					line = str(buf[start..i])
					start = i + 1
					return line
			seen = stop - start
			match self.fill():
				ok: pass
				error:
					if stop == start: return error
					line = str(buf[start..stop])
					start = stop
					return line

	# The sending half of the connection, for another job to send while this one receives: its
	# sends and flush work, it never closes the socket, and shuts the sending side down when it
	# goes (the other side then reads Closed). Keep the receiving half until the writer is done.
	fn writer():
		TcpConn(sock, owns = false, buf = [], start = 0, stop = 0, out = [])

	fn close():
		if owns:
			if sock != 0:
				shutdown(sock, 2)   # SD_BOTH: a receive another job waits in ends (Linux's close alone would not end it)
			sock = closeSocket(sock)
		elif sock != 0:
			shutdown(sock, 1)   # SD_SEND
			sock = 0

	mut fn drop():
		close()

# sockaddr_in: family 2 (IPv4), the port and the address in network order, then zeros
extern type SockAddrIn:
	family u16
	port u16
	addr u32
	zero u64

# an fd_set of one socket: the count (a u32 and its padding) and the socket
extern type FdSet:
	count i64
	sock i64

extern type TimeVal:
	sec i32
	usec i32

extern "ws2_32.dll" fn WSAStartup(version i64, info u8[]) i32
extern "ws2_32.dll" fn WSAGetLastError() i32
extern "ws2_32.dll" fn socket(family i64, kind i64, protocol i64) i64
extern "ws2_32.dll" fn bind(s i64, addr SockAddrIn, length i64) i32
extern "ws2_32.dll" fn listen(s i64, backlog i64) i32
extern "ws2_32.dll" fn accept(s i64, addr i64, length i64) i64
extern "ws2_32.dll" fn connect(s i64, addr SockAddrIn, length i64) i32
extern "ws2_32.dll" fn send(s i64, buf u8[], n i64, flags i64) i32
extern "ws2_32.dll" fn recv(s i64, buf u8[], n i64, flags i64) i32
extern "ws2_32.dll" fn sendto(s i64, buf u8[], n i64, flags i64, to SockAddrIn, length i64) i32
extern "ws2_32.dll" fn recvfrom(
	s i64,
	buf u8[],
	n i64,
	flags i64,
	mut source SockAddrIn,
	sourceLen i32[]
) i32
extern "ws2_32.dll" fn getsockname(s i64, mut addr SockAddrIn, length i32[]) i32
extern "ws2_32.dll" fn closesocket(s i64) i32
extern "ws2_32.dll" fn setsockopt(s i64, level i64, name i64, value i32[], length i64) i32
extern "ws2_32.dll" fn ioctlsocket(s i64, cmd i64, arg i32[]) i32
extern "ws2_32.dll" fn shutdown(s i64, how i64) i32
extern "ws2_32.dll" fn select(
	n i64,
	mut readable FdSet,
	mut writable FdSet,
	mut failed FdSet,
	timeout TimeVal
) i32

# the socket calls named like the methods that wrap them (a bare call inside a method would
# be ambiguous)
fn acceptSocket(s i64):
	accept(s, 0, 0)

fn recvSocket(s i64, buf u8[], max i64):
	recv(s, buf, max, 0)

# the Error of the last failed socket call
fn lastNetError() Error:
	code = i64(WSAGetLastError())
	match code:
		10_061: .Refused   # WSAECONNREFUSED
		10_048: .InUse   # WSAEADDRINUSE
		# aborted, reset, shut down, interrupted, not a socket (closed here)
		10_053, 10_054, 10_058, 10_004, 10_038: .Closed
		_: .Failed(code)

# Winsock started for the calling thread's use: it counts its starts, so any thread may start it
# again, and no module variable records it (a background job may open sockets)
fn netInit():
	info u8[] = zeros(512)
	WSAStartup(514, info)

fn netOrder16(v i64) u16:
	((v & 255) << 8) | ((v >> 8) & 255)

# the four bytes of a dotted address, in network order as stored little-endian
fn ipv4(host str) u32:
	if host == "localhost": return u32(127 | (1 << 24))
	parts = host.split(".")
	if parts.len != 4: return 0
	v = 0
	for i in 0..4:
		v |= (i64.parse(parts[i]) ?? 0) << (8 * i)
	u32(v)

fn sockAddr(host str, port i64):
	SockAddrIn(family = 2, port = netOrder16(port), addr = ipv4(host), zero = 0)

# Listens on a port of one interface: the loopback one unless `host` says another, so no
# firewall asks ("0.0.0.0" for every one, so other machines can connect; Windows then asks the
# firewall once per program). Port 0 asks the system for a free one (`listener.port()` says
# which).
pub fn tcpListen(port i64, host str = "127.0.0.1") TcpListener ? Error:
	netInit()
	s = socket(2, 1, 0)
	if s == -1: return lastNetError()
	# SO_EXCLUSIVEADDRUSE: the port is this listener's alone (Windows' SO_REUSEADDR would let
	# another program bind it too and take its connections)
	exclusive i32[] = [1]
	setsockopt(s, 65_535, -5, exclusive, 4)
	if bind(s, sockAddr(host, port), 16) != 0 or listen(s, 16) != 0:
		why = lastNetError()
		closesocket(s)
		return why
	setNonBlocking(s)
	TcpListener(sock = s)

# Connects to host:port.
pub fn tcpConnect(host str, port i64) TcpConn ? Error:
	netInit()
	s = socket(2, 1, 0)
	if s == -1: return lastNetError()
	setNonBlocking(s)
	ok = connect(s, sockAddr(host, port), 16)
	if ok != 0 and wouldBlock():
		# the connection is in progress: wait until the socket is writable (connected) or
		# reports an exception (refused)
		state = 0
		while state == 0:
			waitFor(s, true)
			state = connectState(s)
		if state > 0:
			ok = 0
		elif state < 0:
			closesocket(s)
			return Error.Refused
	if ok != 0:
		why = lastNetError()
		closesocket(s)
		return why
	newConn(s)

# the socket closed (none for 0): 0, what a closed one holds
fn closeSocket(s i64):
	if s != 0:
		closesocket(s)
	0

# the socket never blocks the process: a call that would block returns -1 with error 10035
# (WSAEWOULDBLOCK) and the thread waits a millisecond at a time, so a poll never blocks (a
# listener's, a connecting one's, a UDP one's)
fn setNonBlocking(s i64):
	on i32[] = [1]
	ioctlsocket(s, 2_147_772_030, on)   # FIONBIO

# a connected socket's calls wait in the system: a receive that waits is one call, not one that
# fails, a wait and another (a poll asks first: readable)
fn setBlocking(s i64):
	off i32[] = [0]
	ioctlsocket(s, 2_147_772_030, off)   # FIONBIO

# whether a receive on the socket would answer at once (bytes, or the end), asked without waiting
fn readable(s i64):
	readers = FdSet(count = 1, sock = s)
	nobody = FdSet(count = 0, sock = 0)
	failed = FdSet(count = 0, sock = 0)
	select(0, readers, nobody, failed, TimeVal(sec = 0, usec = 0)) > 0

# 1 when a connecting socket is connected, -1 when the attempt failed, 0 while in progress
fn connectState(s i64):
	writable = FdSet(count = 1, sock = s)
	failed = FdSet(count = 1, sock = s)
	nobody = FdSet(count = 0, sock = 0)
	r = select(0, nobody, writable, failed, TimeVal(sec = 0, usec = 0))   # a zero timeout: poll
	if r < 0 or (failed.count & 4_294_967_295) > 0: return -1
	if r > 0 and (writable.count & 4_294_967_295) > 0: return 1
	0

fn wouldBlock():
	e = WSAGetLastError()
	e in [10_035, 10_036, 10_037]

# Waits until the socket can be read (or written, when forWrite), at most a fifth of a second: the
# caller tries again, so a socket closed meanwhile fails its next call.
fn waitFor(s i64, forWrite bool):
	readable = FdSet(count = 0 if forWrite else 1, sock = s)
	writable = FdSet(count = 1 if forWrite else 0, sock = s)
	failed = FdSet(count = 1 if forWrite else 0, sock = s)
	rt.blockingBegin()
	select(0, readable, writable, failed, TimeVal(sec = 0, usec = 200_000))
	rt.blockingEnd()

# every byte of bytes, waiting while the system's buffer is full
fn sendAll(s i64, bytes u8[]) ? Error:
	n = bytes.len
	done = 0
	while done < n:
		at = done   # (bounded by a check, as a mutable variable is not: never false, for noStops)
		if at < 0 or at >= bytes.len: return Error.Closed
		rt.blockingBegin()   # (a full buffer waits in the system: another job may run meanwhile)
		w = send(s, bytes[at..], n - at, 0)
		rt.blockingEnd()
		if w < 0 and wouldBlock():
			waitFor(s, true)
		elif w < 0:
			return lastNetError()
		elif w == 0 or w > n - at:   # none sent, or more than it was given: not to be trusted
			return Error.Closed
		else:
			done = at + w
	return

fn newConn(s i64):
	setBlocking(s)
	TcpConn(sock = s, owns = true, buf = [], start = 0, stop = 0, out = [])

# ---------- UDP ----------

# where a datagram goes or came from: an IPv4 address and a port, as the system stores them
pub type Endpoint:
	addr u32   # network order, as stored little-endian
	wirePort u16   # network order: port() is its number

	# one number per endpoint, a key for a table of the peers a server talks to
	fn id():
		(i64(addr) << 16) | wirePort

	fn port() i64:
		netOrder16(wirePort)

# a datagram received: its bytes and who sent them (the place to reply to)
pub type Datagram:
	sender Endpoint
	bytes u8[]

pub type UdpSocket:
	sock i64
	buffer u8[]   # the largest datagram, received into before its bytes are copied out

	# The port the socket is bound to (the one the system picked for port 0).
	fn port() i64:
		addr = sockAddr("0.0.0.0", 0)
		length i32[] = [16]
		getsockname(sock, addr, length)
		netOrder16(addr.port)

	# Sends one datagram (a message: `value.toBytes()`); Failed when the system refuses it (too
	# large, no route).
	fn sendTo(to Endpoint, bytes u8[]) ? Error:
		sent = sendto(sock, bytes, bytes.len, 0, to.endpointAddr(), 16)
		while sent < 0 and wouldBlock():
			sleepMs(1)
			sent = sendto(sock, bytes, bytes.len, 0, to.endpointAddr(), 16)
		if sent < 0: return lastNetError()
		return

	# The next datagram, waiting for one; Closed when the
	# socket was closed.
	fn receiveFrom() Datagram ? Error:
		source = sockAddr("0.0.0.0", 0)
		n = self.receiveInto(source)
		while n == -1:
			sleepMs(1)
			n = self.receiveInto(source)
		if n < 0: return lastNetError()
		source.datagramOf(buffer, n)

	# The next datagram if one has arrived, without waiting; none when none has (or the socket
	# failed).
	fn poll() Datagram?:
		source = sockAddr("0.0.0.0", 0)
		n = self.receiveInto(source)
		source.datagramOf(buffer, n) if n >= 0 else none

	fn close():
		sock = closeSocket(sock)

	mut fn drop():
		close()

largestDatagram = 65_536

# the endpoint of host:port, to send to
pub fn endpoint(host str, port i64) Endpoint:
	Endpoint(addr = ipv4(host), wirePort = netOrder16(port))

# A UDP socket on host:port (port 0: one the system picks, see port()). "127.0.0.1" reaches
# only this machine; "0.0.0.0" every interface (Windows then asks the firewall once per
# program).
pub fn udpBind(host str, port i64) UdpSocket ? Error:
	netInit()
	s = socket(2, 2, 17)   # AF_INET, SOCK_DGRAM, IPPROTO_UDP
	if s == -1: return lastNetError()
	if bind(s, sockAddr(host, port), 16) != 0:
		why = lastNetError()
		closesocket(s)
		return why
	setNonBlocking(s)
	UdpSocket(sock = s, buffer = zeros(largestDatagram))

# one datagram into the socket's buffer: its length, -1 when none has arrived, -2 when the
# socket failed
fn receiveInto(mut socket UdpSocket, mut source SockAddrIn) i64:
	sourceLen i32[] = [16]
	going = true
	while going:
		n = recvfrom(socket.sock, socket.buffer, largestDatagram, 0, source, sourceLen)
		if n >= 0: return n
		e = WSAGetLastError()
		# a datagram sent earlier to a port nobody listens on comes back as a reset: skipped
		going = e == 10_054
		if not going and (e in [10_035, 10_036, 10_037]): return -1
	-2

fn endpointAddr(e Endpoint):
	SockAddrIn(family = 2, port = e.wirePort, addr = e.addr, zero = 0)

fn datagramOf(source SockAddrIn, buffer u8[], n i64):
	Datagram(
		sender = Endpoint(addr = source.addr, wirePort = source.port),
		bytes = buffer[..n].copy()
	)
