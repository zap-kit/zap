# The sound card through WASAPI in shared mode: the default render endpoint (IMMDeviceEnumerator,
# IMMDevice), an IAudioClient started event-driven in the endpoint's mix format (its rate and
# channels; float, or 16/24/32-bit integers converted here), a buffer of about 20 ms, and the
# IAudioRenderClient the mixed blocks are written through. COM is called through the objects'
# tables of methods as rhi/d3d12 does (std/win): each method an `extern loaded fn` bound to its
# slot. A failed call never stops the program: the device is closed and opened again later
# (unplugged headphones, a changed default device, no device at all).

import win

extern "ole32.dll" fn CoInitializeEx(reserved i64, flags i64) i32
extern "ole32.dll" fn CoUninitialize()
extern "ole32.dll" fn CoCreateInstance(
	clsid u8[],
	outer i64,
	context i64,
	riid u8[],
	out object i64
) i32
extern "ole32.dll" fn CoTaskMemFree(p i64)

# ---------- IMMDeviceEnumerator ----------
extern loaded fn enumeratorGetDefaultAudioEndpoint(
	object i64,
	flow i64,
	role i64,
	out device i64
) i32
# ---------- IMMDevice ----------
extern loaded fn deviceActivate(
	object i64,
	riid u8[],
	context i64,
	params i64,
	out client i64
) i32
extern loaded fn deviceGetId(object i64, out id i64) i32
# ---------- IAudioClient ----------
extern loaded fn clientInitialize(
	object i64,
	shareMode i64,
	flags i64,
	duration i64,
	periodicity i64,
	format u8[],
	session i64
) i32
extern loaded fn clientGetBufferSize(object i64, out frames u32) i32
extern loaded fn clientGetCurrentPadding(object i64, out frames u32) i32
extern loaded fn clientGetMixFormat(object i64, out format i64) i32
extern loaded fn clientStart(object i64) i32
extern loaded fn clientStop(object i64) i32
extern loaded fn clientSetEventHandle(object i64, event i64) i32
extern loaded fn clientGetService(object i64, riid u8[], out service i64) i32
# ---------- IAudioClient3 (Windows 10 on): shared mode with the engine's smallest periods ----------
extern loaded fn client3GetSharedModeEnginePeriod(
	object i64,
	format u8[],
	out defaultPeriod u32,
	out fundamental u32,
	out minPeriod u32,
	out maxPeriod u32
) i32
extern loaded fn client3InitializeSharedAudioStream(
	object i64,
	flags i64,
	period i64,
	format u8[],
	session i64
) i32
# ---------- IAudioRenderClient ----------
extern loaded fn renderGetBuffer(object i64, frames i64, out data i64) i32
extern loaded fn renderReleaseBuffer(object i64, frames i64, flags i64) i32

clsctxAll = 0x17
streamFlagsEventCallback = 0x0004_0000
streamFlagsAutoConvertPcm = 0x8000_0000
streamFlagsSrcDefaultQuality = 0x0800_0000
bufferDuration = 100_000   # 10 ms, in 100 ns units

clsidDeviceEnumerator = win.guid("bcde0395-e52f-467c-8e3d-c4579291692e")
iidDeviceEnumerator = win.guid("a95664d2-9614-4f35-a746-de8db63617e6")
iidAudioClient = win.guid("1cb9ad4c-dbfa-4c32-b178-c2f568a703b2")
iidAudioRenderClient = win.guid("f294acfc-3146-4483-a7bf-addca7c260e2")
iidAudioClient3 = win.guid("7ed4ee07-8e67-4cd4-8c1a-2b7a5987ad42")

# The endpoint's output: the objects, the format written, and the buffer.
pub type OutputDevice:
	enumerator i64 = 0
	endpoint i64 = 0
	client i64 = 0
	render i64 = 0
	event i64 = 0
	rate i64 = 48_000
	channels i64 = 2
	isFloat bool = true
	bits i64 = 32   # per sample written
	bufferFrames i64 = 0
	period i64 = 0   # the engine's period, when IAudioClient3 set it (0: the default)
	endpointId u8[] = []   # the endpoint's id, to see when the default one changes
	failure str = ""   # why the last open failed
	bytes u8[] = []   # a block converted to an integer format

# The last HRESULT of a failed call, kept for the report.
fn failed(hr i32):
	hr < 0

fn failure(what str, hr i32):
	"{what} failed ({win.hresultText(hr)})"

# the id of the default endpoint's device (empty when there is none)
fn defaultEndpointId(enumerator i64):
	bindExtern(enumeratorGetDefaultAudioEndpoint, win.method(enumerator, 4))
	if failed(enumeratorGetDefaultAudioEndpoint(enumerator, 0, 0, out device)): return []
	id = endpointIdOf(device)
	win.release(device)
	id

# a device's id string, its UTF-16 bytes
fn endpointIdOf(device i64):
	bindExtern(deviceGetId, win.method(device, 5))
	if failed(deviceGetId(device, out text)) or text == 0: return []
	id = []
	pair u8[] = [0, 0]
	for k in 0..512:
		win.memoryAt(text + 2 * k, 2).read(0, pair)
		if pair[0] == 0 and pair[1] == 0: break
		id.push(pair[0])
		id.push(pair[1])
	CoTaskMemFree(text)
	id

# Opens the default render endpoint; on failure the device holds why (and nothing to release).
pub fn openOutput() OutputDevice:
	d = OutputDevice()
	hr = CoCreateInstance(clsidDeviceEnumerator, 0, clsctxAll, iidDeviceEnumerator, out enumerator)
	if failed(hr):
		d.failure = failure("CoCreateInstance(MMDeviceEnumerator)", hr)
		return d
	d.enumerator = enumerator
	bindExtern(enumeratorGetDefaultAudioEndpoint, win.method(enumerator, 4))
	hr2 = enumeratorGetDefaultAudioEndpoint(enumerator, 0, 0, out endpoint)
	if failed(hr2):
		d.failure = failure("no default audio endpoint: GetDefaultAudioEndpoint", hr2)
		d.closeOutput()
		return d
	d.endpoint = endpoint
	d.endpointId = endpointIdOf(endpoint)
	bindExtern(deviceActivate, win.method(endpoint, 3))
	hr3 = deviceActivate(endpoint, iidAudioClient, clsctxAll, 0, out client)
	if failed(hr3):
		d.failure = failure("IMMDevice::Activate(IAudioClient)", hr3)
		d.closeOutput()
		return d
	d.client = client
	bindClient(client)
	hr4 = clientGetMixFormat(client, out mixAt)
	if failed(hr4) or mixAt == 0:
		d.failure = failure("IAudioClient::GetMixFormat", hr4)
		d.closeOutput()
		return d
	mix = win.memoryAt(mixAt, 40).bytes(0, 40)
	CoTaskMemFree(mixAt)
	mixFormat = parseMixFormat(mix)
	d.rate = mixFormat.rate
	d.channels = mixFormat.channels
	d.isFloat = mixFormat.isFloat
	d.bits = mixFormat.bits
	flags = streamFlagsEventCallback
	format = waveFormat(d.rate, d.channels, d.isFloat, d.bits, mixFormat.channelMask)
	if not mixFormat.known:
		# a format this file does not write: the system converts float stereo to it
		d.channels = 2
		d.isFloat = true
		d.bits = 32
		format = waveFormat(d.rate, 2, true, 32, 3)
		flags |= streamFlagsAutoConvertPcm | streamFlagsSrcDefaultQuality
	hr5 = -i32(1)
	if mixFormat.known:
		hr5 = d.initializeLowLatency(format)
	if failed(hr5):
		bindClient(d.client)
		hr5 = clientInitialize(d.client, 0, flags, bufferDuration, 0, format, 0)
	client2 = d.client
	if failed(hr5):
		d.failure = failure("IAudioClient::Initialize", hr5)
		d.closeOutput()
		return d
	d.event = win.CreateEventA(0, false, false, 0)
	clientSetEventHandle(client2, d.event)
	clientGetBufferSize(client2, out frames)
	d.bufferFrames = frames
	hr6 = clientGetService(client2, iidAudioRenderClient, out render)
	if failed(hr6):
		d.failure = failure("IAudioClient::GetService(IAudioRenderClient)", hr6)
		d.closeOutput()
		return d
	d.render = render
	bindExtern(renderGetBuffer, win.method(render, 3))
	bindExtern(renderReleaseBuffer, win.method(render, 4))
	# silence first, the whole buffer, so the start is clean; then the stream runs
	if not failed(renderGetBuffer(render, d.bufferFrames, out data)):
		renderReleaseBuffer(render, d.bufferFrames, 2)   # AUDCLNT_BUFFERFLAGS_SILENT
		_ = data
	hr7 = clientStart(client2)
	if failed(hr7):
		d.failure = failure("IAudioClient::Start", hr7)
		d.closeOutput()
		return d
	d

# IAudioClient3's stream at the engine's smallest period that is a whole number of its
# fundamental steps and at least 5 ms (the client becomes the IAudioClient3); an error when the
# system has no IAudioClient3 or refuses
fn initializeLowLatency(mut d OutputDevice, format u8[]) i32:
	client3 = win.queryInterface(d.client, iidAudioClient3)
	if client3 == 0: return -1
	bindExtern(client3GetSharedModeEnginePeriod, win.method(client3, 18))
	bindExtern(client3InitializeSharedAudioStream, win.method(client3, 20))
	hr2 = client3GetSharedModeEnginePeriod(
		client3,
		format,
		out defaultPeriod,
		out fundamental,
		out minPeriod,
		out maxPeriod
	)
	if failed(hr2):
		win.release(client3)
		return hr2
	_ = maxPeriod
	step = i64(fundamental).max(1)
	wanted = d.rate / 200   # 5 ms
	period = i64(minPeriod).max(step)
	while period < wanted and period + step <= defaultPeriod:
		period += step
	hr3 = client3InitializeSharedAudioStream(client3, streamFlagsEventCallback, period, format, 0)
	if failed(hr3):
		win.release(client3)
		return hr3
	win.release(d.client)
	d.client = client3
	d.period = period
	bindClient(client3)
	0

fn bindClient(client i64):
	bindExtern(clientInitialize, win.method(client, 3))
	bindExtern(clientGetBufferSize, win.method(client, 4))
	bindExtern(clientGetCurrentPadding, win.method(client, 6))
	bindExtern(clientGetMixFormat, win.method(client, 8))
	bindExtern(clientStart, win.method(client, 10))
	bindExtern(clientStop, win.method(client, 11))
	bindExtern(clientSetEventHandle, win.method(client, 13))
	bindExtern(clientGetService, win.method(client, 14))

pub fn isOpen(d OutputDevice) bool:
	d.render != 0

# Releases what is open; the device then holds nothing.
pub fn closeOutput(mut d OutputDevice):
	if d.client != 0:
		bindClient(d.client)
		clientStop(d.client)
	win.release(d.render)
	win.release(d.client)
	win.release(d.endpoint)
	win.release(d.enumerator)
	if d.event != 0:
		win.CloseHandle(d.event)
	d.render = 0
	d.client = 0
	d.endpoint = 0
	d.enumerator = 0
	d.event = 0

# whether the system's default endpoint is another one than the open one now
pub fn hasDefaultChanged(d OutputDevice) bool:
	if d.enumerator == 0: return false
	id = defaultEndpointId(d.enumerator)
	not id.isEmpty and id != d.endpointId

# ---------- formats ----------

type MixFormat:
	rate i64
	channels i64
	isFloat bool
	bits i64
	channelMask i64
	known bool   # one this file writes

# a WAVEFORMATEX (or WAVEFORMATEXTENSIBLE) the system gave
fn parseMixFormat(b u8[]):
	tag = b.u16le(0)
	channels = b.u16le(2)
	rate = b.u32le(4)
	bits = b.u16le(14)
	mask = 4 if channels == 1 else 3
	if tag == 0xFFFE and b.u16le(16) >= 22:
		mask = b.u32le(20)
		tag = b.u16le(24)
	isFloat = tag == 3
	known = (isFloat and bits == 32 or tag == 1 and (bits in [16, 24, 32])) and channels >= 1 and
		channels <= 8 and rate > 0
	MixFormat(rate, channels, isFloat, bits, channelMask = mask, known)

# a WAVEFORMATEXTENSIBLE of the format the stream is written in
fn waveFormat(rate i64, channels i64, isFloat bool, bits i64, mask i64):
	b = []
	block = channels * bits / 8
	b.pushU16le(0xFFFE)
	b.pushU16le(channels)
	b.pushU32le(rate)
	b.pushU32le(rate * block)
	b.pushU16le(block)
	b.pushU16le(bits)
	b.pushU16le(22)
	b.pushU16le(bits)
	b.pushU32le(mask)
	b.extend(
		win.guid(
			"00000003-0000-0010-8000-00aa00389b71" if isFloat
			else "00000001-0000-0010-8000-00aa00389b71"
		)
	)
	b

# ---------- writing ----------

# Frames the device has room for now (-1: the device is gone).
pub fn framesFree(mut d OutputDevice) i64:
	bindClient(d.client)
	if failed(clientGetCurrentPadding(d.client, out padding)): return -1
	d.bufferFrames - padding

# Waits for the device to ask for more, at most `ms`.
pub fn waitForDevice(d OutputDevice, ms i64):
	_ = win.WaitForSingleObject(d.event, ms)

# Writes n frames of stereo floats (out[0 .. 2n]) in the device's format (deviceBytes). False
# when the device is gone.
pub fn writeFrames(mut d OutputDevice, out f32[], n i64) bool:
	if n <= 0: return true
	if failed(renderGetBuffer(d.render, n, out data)): return false
	room = win.memoryAt(data, n * d.channels * d.bits / 8)
	if d.channels == 2 and d.isFloat:
		room.write(0, out[..2 * n])
	else:
		deviceBytes(out, n, d.channels, d.isFloat, d.bits, d.bytes)
		room.write(0, d.bytes)
	not failed(renderReleaseBuffer(d.render, n, 0))

# n frames of stereo floats as a device of `channels` takes them, into `into` (replaced):
# stereo to the first two channels and the others silent, the mean of both to a mono device;
# floats as they are, integers of 16, 24 or 32 bits scaled to full scale and rounded.
pub fn deviceBytes(out f32[], n i64, channels i64, isFloat bool, bits i64, mut into u8[]):
	into.clear()
	for f in 0..n:
		l = out[2 * f]
		r = out[2 * f + 1]
		for c in 0..channels:
			x = (l + r) * 0.5 if channels == 1 else l if c == 0 else r if c == 1 else 0.0
			if isFloat:
				into.pushF32le(x)
			else:
				v = f64(x.clamp(-1.0, 1.0))
				full = 32767.0 if bits == 16 else 8388607.0 if bits == 24 else 2147483647.0
				s = i64((v * full).round())
				for k in 0..bits / 8:
					into.push(s >> (8 * k) & 255)
