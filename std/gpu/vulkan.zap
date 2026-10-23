# The Vulkan functions and structures a compute device calls (gpu.zap), declared as C has them:
# each function found once the loader (vulkan-1.dll) is loaded, so a machine without it runs the
# program and only gpu.available() says no. A handle is an i64; a structure goes as its address
# (`mut` where Vulkan writes it), an array as a list; what Vulkan writes starts as zeros.

extern loaded fn vkCreateInstance(info InstanceCreateInfo, allocator i64, out instance i64) i32
extern loaded fn vkEnumeratePhysicalDevices(instance i64, mut count Count, devices i64[]) i32
extern loaded fn vkGetPhysicalDeviceProperties(device i64, mut properties DeviceProperties)
extern loaded fn vkGetPhysicalDeviceQueueFamilyProperties(
	device i64,
	mut count Count,
	properties QueueFamily[]
)
extern loaded fn vkGetPhysicalDeviceMemoryProperties(device i64, mut properties MemoryProperties)
extern loaded fn vkCreateDevice(
	physical i64,
	info DeviceCreateInfo,
	allocator i64,
	out device i64
) i32
extern loaded fn vkGetDeviceQueue(device i64, family i64, index i64, out queue i64)
extern loaded fn vkCreateBuffer(
	device i64,
	info BufferCreateInfo,
	allocator i64,
	out buffer i64
) i32
extern loaded fn vkDestroyBuffer(device i64, buffer i64, allocator i64)
extern loaded fn vkGetBufferMemoryRequirements(
	device i64,
	buffer i64,
	mut requirements MemoryRequirements
)
extern loaded fn vkAllocateMemory(
	device i64,
	info MemoryAllocateInfo,
	allocator i64,
	out memory i64
) i32
extern loaded fn vkFreeMemory(device i64, memory i64, allocator i64)
extern loaded fn vkBindBufferMemory(device i64, buffer i64, memory i64, offset i64) i32
extern loaded fn vkMapMemory(
	device i64,
	memory i64,
	offset i64,
	size i64,
	flags i64,
	out at i64
) i32
extern loaded fn vkCreateShaderModule(
	device i64,
	info ShaderModuleCreateInfo,
	allocator i64,
	out module i64
) i32
extern loaded fn vkCreateDescriptorSetLayout(
	device i64,
	info DescriptorSetLayoutCreateInfo,
	allocator i64,
	out layout i64
) i32
extern loaded fn vkCreatePipelineLayout(
	device i64,
	info PipelineLayoutCreateInfo,
	allocator i64,
	out layout i64
) i32
extern loaded fn vkCreateComputePipelines(
	device i64,
	cache i64,
	count i64,
	info ComputePipelineCreateInfo,
	allocator i64,
	out pipeline i64
) i32
extern loaded fn vkCreateDescriptorPool(
	device i64,
	info DescriptorPoolCreateInfo,
	allocator i64,
	out pool i64
) i32
extern loaded fn vkResetDescriptorPool(device i64, pool i64, flags i64) i32
extern loaded fn vkAllocateDescriptorSets(
	device i64,
	info DescriptorSetAllocateInfo,
	out set i64
) i32
extern loaded fn vkUpdateDescriptorSets(
	device i64,
	writeCount i64,
	writes WriteDescriptorSet[],
	copyCount i64,
	copies i64
)
extern loaded fn vkCreateCommandPool(
	device i64,
	info CommandPoolCreateInfo,
	allocator i64,
	out pool i64
) i32
extern loaded fn vkAllocateCommandBuffers(
	device i64,
	info CommandBufferAllocateInfo,
	out buffer i64
) i32
extern loaded fn vkResetCommandBuffer(buffer i64, flags i64) i32
extern loaded fn vkBeginCommandBuffer(buffer i64, info CommandBufferBeginInfo) i32
extern loaded fn vkEndCommandBuffer(buffer i64) i32
extern loaded fn vkCreateFence(device i64, info FenceCreateInfo, allocator i64, out fence i64) i32
extern loaded fn vkWaitForFences(device i64, count i64, fences i64[], waitAll i64, timeout i64) i32
extern loaded fn vkResetFences(device i64, count i64, fences i64[]) i32
extern loaded fn vkQueueSubmit(queue i64, count i64, submit SubmitInfo, fence i64) i32
extern loaded fn vkCmdPipelineBarrier(
	buffer i64,
	srcStage i64,
	dstStage i64,
	dependency i64,
	memoryCount i64,
	memory MemoryBarrier[],
	bufferCount i64,
	buffers i64,
	imageCount i64,
	images i64
)
extern loaded fn vkCmdBindPipeline(buffer i64, bindPoint i64, pipeline i64)
extern loaded fn vkCmdBindDescriptorSets(
	buffer i64,
	bindPoint i64,
	layout i64,
	first i64,
	count i64,
	sets i64[],
	dynamicCount i64,
	dynamicOffsets i64
)
extern loaded fn vkCmdDispatch(buffer i64, x i64, y i64, z i64)
extern loaded fn vkCmdCopyBuffer(buffer i64, src i64, dst i64, count i64, region BufferCopy)
extern loaded fn vkCmdFillBuffer(buffer i64, dst i64, offset i64, size i64, value i64)

# a count Vulkan reads and writes (the room of the list asked with, then the length given)
extern type Count:
	n u32 = 0

extern type ApplicationInfo:
	sType u32 = 0
	next i64 = 0
	name ref str
	version u32
	engineName ref str
	engineVersion u32
	apiVersion u32

extern type InstanceCreateInfo:
	sType u32 = 1
	next i64 = 0
	flags u32 = 0
	app ref ApplicationInfo
	layerCount u32 = 0
	layers i64 = 0
	extensionCount u32 = 0
	extensions i64 = 0

extern type DeviceProperties:
	apiVersion u32 = 0
	driverVersion u32 = 0
	vendor u32 = 0
	device u32 = 0
	deviceType u32 = 0
	name u8[256]
	uuid u8[16]
	rest u8[532]   # the limits and the sparse properties

extern type QueueFamily:
	flags u32 = 0
	count u32 = 0
	timestampBits u32 = 0
	granularity u32[3]

extern type MemoryType:
	flags u32 = 0
	heap u32 = 0

extern type MemoryHeap:
	size i64 = 0
	flags u32 = 0

extern type MemoryProperties:
	typeCount u32 = 0
	types MemoryType[32] = fill(32, MemoryType())
	heapCount u32 = 0
	heaps MemoryHeap[16] = fill(16, MemoryHeap())

extern type DeviceQueueCreateInfo:
	sType u32 = 2
	next i64 = 0
	flags u32 = 0
	family u32
	count u32 = 1
	priorities ref f32[]

extern type DeviceCreateInfo:
	sType u32 = 3
	next i64 = 0
	flags u32 = 0
	queueCount u32 = 1
	queue ref DeviceQueueCreateInfo
	layerCount u32 = 0
	layers i64 = 0
	extensionCount u32 = 0
	extensions i64 = 0
	features i64 = 0

extern type BufferCreateInfo:
	sType u32 = 12
	next i64 = 0
	flags u32 = 0
	size i64
	usage u32
	sharing u32 = 0
	familyCount u32 = 0
	families i64 = 0

extern type MemoryRequirements:
	size i64 = 0
	alignment i64 = 0
	typeBits u32 = 0

extern type MemoryAllocateInfo:
	sType u32 = 5
	next i64 = 0
	size i64
	typeIndex u32

extern type ShaderModuleCreateInfo:
	sType u32 = 16
	next i64 = 0
	flags u32 = 0
	codeSize i64
	code ref str

extern type DescriptorSetLayoutBinding:
	binding u32
	kind u32
	count u32 = 1
	stages u32 = 0x20   # COMPUTE
	samplers i64 = 0

extern type DescriptorSetLayoutCreateInfo:
	sType u32 = 32
	next i64 = 0
	flags u32 = 0
	count u32
	bindings ref DescriptorSetLayoutBinding[]

extern type PipelineLayoutCreateInfo:
	sType u32 = 30
	next i64 = 0
	flags u32 = 0
	setCount u32 = 1
	sets ref i64[]
	rangeCount u32 = 0
	ranges i64 = 0

# a compute pipeline: its one stage inline (a VkPipelineShaderStageCreateInfo: its fields laid
# where C lays the nested struct, from the pad on) and its layout
extern type ComputePipelineCreateInfo:
	sType u32 = 29
	next i64 = 0
	flags u32 = 0
	pad u32 = 0
	stageType u32 = 18
	stageNext i64 = 0
	stageFlags u32 = 0
	stage u32 = 0x20   # COMPUTE
	module i64
	name ref str
	specialization i64 = 0
	layout i64
	basePipeline i64 = 0
	baseIndex i32 = -1

extern type DescriptorPoolSize:
	kind u32
	count u32

extern type DescriptorPoolCreateInfo:
	sType u32 = 33
	next i64 = 0
	flags u32 = 0
	maxSets u32
	sizeCount u32
	sizes ref DescriptorPoolSize[]

extern type DescriptorSetAllocateInfo:
	sType u32 = 34
	next i64 = 0
	pool i64
	count u32 = 1
	layouts ref i64[]

extern type DescriptorBufferInfo:
	buffer i64
	offset i64
	range i64

extern type WriteDescriptorSet:
	sType u32 = 35
	next i64 = 0
	set i64
	binding u32
	element u32 = 0
	count u32 = 1
	kind u32
	image i64 = 0
	buffer ref DescriptorBufferInfo
	texelView i64 = 0

extern type CommandPoolCreateInfo:
	sType u32 = 39
	next i64 = 0
	flags u32
	family u32

extern type CommandBufferAllocateInfo:
	sType u32 = 40
	next i64 = 0
	pool i64
	level u32 = 0
	count u32 = 1

extern type CommandBufferBeginInfo:
	sType u32 = 42
	next i64 = 0
	flags u32
	inheritance i64 = 0

extern type FenceCreateInfo:
	sType u32 = 8
	next i64 = 0
	flags u32 = 0

extern type SubmitInfo:
	sType u32 = 4
	next i64 = 0
	waitCount u32 = 0
	waits i64 = 0
	waitStages i64 = 0
	bufferCount u32 = 1
	buffers ref i64[]
	signalCount u32 = 0
	signals i64 = 0

extern type MemoryBarrier:
	sType u32 = 46
	next i64 = 0
	srcAccess u32
	dstAccess u32

extern type BufferCopy:
	src i64
	dst i64
	size i64

# usage of a buffer: copied from, copied into, a uniform block, a storage buffer
usageTransferSrc = 1
usageTransferDst = 2
usageUniform = 0x10
usageStorage = 0x20

# memory properties
memDeviceLocal = 1
memHostVisible = 2
memHostCoherent = 4
memHostCached = 8

descUniformBuffer = 6
descStorageBuffer = 7

bindCompute = 1
stageAllCommands = 0x1_0000
accessMemoryRead = 0x8000
accessMemoryWrite = 0x1_0000
queueCompute = 2
