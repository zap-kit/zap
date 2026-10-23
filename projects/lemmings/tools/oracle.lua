-- The DOS game played inside BizHawk's DOSBox-X core by the route oracle.zap writes (its path in
-- ZAP_ORACLE_ROUTE): the keys that boot it to a level, then clicks at the game's own iterations,
-- read from its iteration counter in memory. Each iteration's last picture is kept as
-- dos-NNNNN.png (the iteration's number), the frame before the counter moves on.
--
-- The route's lines:
--   out DIR                 where the pictures and log.txt go
--   key FRAME NAME...       a key held 6 frames from that emulator frame ("key 300 Key Enter")
--   level FRAME             the level starts being followed from that frame
--   click ITER X Y HELD     the cursor at the game's (X, Y) from ITER - 2, the button held
--                           through iterations ITER .. ITER + HELD - 1
--   iterations N            the run ends once iteration N has been kept
--   shot FRAME              the screen at that emulator frame kept as screen-FRAME.png (the
--                           menus and the screens around a level)
--   hover ITER X Y HELD     like click, with the button up
--   dump ITER               the conventional memory at that iteration kept as mem-ITER.bin
--   end FRAME               the run ends at that frame whatever the iterations

local counterAddress = 0x12622   -- the iteration counter, a byte that wraps, 0 when a level starts
local cursorX, cursorY = 0x125E0, 0x125E2   -- the game's cursor, 8..328 by 8..200
local domain = "Conventional Memory"
local park = { 200, 196 }   -- the cursor on the panel when nothing is clicked

local route = { dumps = {}, keys = {}, clicks = {}, shots = {}, iterations = 100, out = ".", level = 1000, last = 1e9 }
for line in io.lines(os.getenv("ZAP_ORACLE_ROUTE")) do
  local w = {}
  for word in line:gmatch("%S+") do w[#w + 1] = word end
  if w[1] == "out" then route.out = w[2]
  elseif w[1] == "key" then route.keys[tonumber(w[2])] = table.concat(w, " ", 3)
  elseif w[1] == "level" then route.level = tonumber(w[2])
  elseif w[1] == "iterations" then route.iterations = tonumber(w[2])
  elseif w[1] == "shot" then route.shots[tonumber(w[2])] = true
  elseif w[1] == "dump" then route.dumps[tonumber(w[2])] = true
  elseif w[1] == "end" then route.last = tonumber(w[2])
  elseif w[1] == "click" then
    route.clicks[#route.clicks + 1] = { at = tonumber(w[2]), x = tonumber(w[3]), y = tonumber(w[4]), held = tonumber(w[5]), button = true }
  elseif w[1] == "hover" then
    route.clicks[#route.clicks + 1] = { at = tonumber(w[2]), x = tonumber(w[3]), y = tonumber(w[4]), held = tonumber(w[5]), button = false }
  end
end

-- the mouse position axes the core maps to the game's cursor (x = 0.8 px - 2, y = 0.331 py)
local px, py = 250, 600
local function steer(x, y)
  local gx, gy = memory.read_u16_le(cursorX, domain), memory.read_u16_le(cursorY, domain)
  -- far: a jump by the slope; near: one step at a time, as the core rounds
  local function towards(err, slope, limit)
    if err == 0 then return 0 end
    if math.abs(err) <= 3 then return err > 0 and 1 or -1 end
    return math.max(-limit, math.min(limit, math.floor(err * slope)))
  end
  px = px + towards(x - gx, 1.25, 40)
  py = py + towards(y - gy, 3, 90)
  px, py = math.max(0, math.min(1024, px)), math.max(0, math.min(768, py))
  -- the core moves the cursor only on a frame with some speed
  joypad.setanalog({ ["Mouse Position X"] = px, ["Mouse Position Y"] = py, ["Mouse Speed X"] = (gx ~= x or gy ~= y) and 1 or 0 })
end

local log = io.open(route.out .. "/log.txt", "w")
client.speedmode(1600)
-- the iterations since the level started: the counter's byte with its wraps counted
local wraps, lastByte = 0, -1
local function iteration()
  local b = memory.read_u8(counterAddress, domain)
  if lastByte >= 250 and b < 5 then wraps = wraps + 1 end
  lastByte = b
  return wraps * 256 + b
end

local frame, last, kept = 0, -1, 0
local changed = 0   -- the frame the counter last moved on: still for 5 seconds, the level is over
-- where the cursor went while the iteration's picture was drawn: the game draws it where it was
-- at its own drawing, so the whole span is left out of the comparison
local box = { 1e9, 1e9, -1e9, -1e9 }
local function spanCursor()
  local x, y = memory.read_u16_le(cursorX, domain), memory.read_u16_le(cursorY, domain)
  box = { math.min(box[1], x), math.min(box[2], y), math.max(box[3], x), math.max(box[4], y) }
  return x, y
end
local shot = route.out .. "/frame.png"

-- the AdLib driver (adlib.dat) where the game loaded it: found by its signature, then its song
-- and the effects its channels 5..8 start are logged with the iteration ("effect N", "song N")
local driver = nil
local effects = {}   -- the effects' first bytes, from the driver's table at 0x55E3
local effectState = { 0, 0, 0, 0 }
local song = -1
local function findDriver()
  local bytes = memory.read_bytes_as_array(0, 655360, domain)
  local sig = { string.byte("AdLib Music by Sound", 1, -1) }
  for i = 1, #bytes - #sig do
    local match = true
    for k = 1, #sig do
      if bytes[i + k - 1] ~= sig[k] then match = false; break end
    end
    if match then
      driver = i - 1 - 0xF1
      for e = 1, 18 do effects[e] = memory.read_u16_le(driver + 0x55E3 + e * 2, domain) end
      return
    end
  end
end
local function logSound(iteration)
  if driver == nil then return end
  local playing = memory.read_u8(driver + 0xEE, domain)
  if playing ~= song then
    log:write(string.format("song %d iteration %d\n", playing, iteration))
    song = playing
  end
  for c = 5, 8 do
    local record = driver + 0x5AC + c * 0x14
    local state = memory.read_u8(record + 0x10, domain)
    if state == 2 and effectState[c - 4] ~= 2 then
      -- the pattern has moved past the first note: the effect is the last one starting before
      local at, best = memory.read_u16_le(record + 0x0C, domain), 0
      for e = 1, 18 do
        if effects[e] <= at and (best == 0 or effects[e] > effects[best]) then best = e end
      end
      log:write(string.format("effect %d iteration %d\n", best, iteration))
    end
    effectState[c - 4] = state
  end
end
-- an error of the script is written to the log, else BizHawk would wait with it on screen
local ok, err = pcall(function()
while true do
  frame = frame + 1
  for k = 0, 5 do
    if route.keys[frame - k] then joypad.set({ [route.keys[frame - k]] = true }) end
  end
  local target, down = park, false
  local counter = last
  if frame >= route.level then
    for _, c in ipairs(route.clicks) do
      if counter >= c.at - 2 and counter < c.at + c.held then target = { c.x, c.y } end
      if c.button and counter >= c.at and counter < c.at + c.held then down = true end
    end
  end
  steer(target[1], target[2])
  if os.getenv("ZAP_ORACLE_DEBUG") then
    log:write(string.format("frame %d counter %d target %d %d pos %d %d game %d %d down %s\n", frame, counter, target[1], target[2], px, py,
      memory.read_u16_le(cursorX, domain), memory.read_u16_le(cursorY, domain), tostring(down)))
  end
  if down then joypad.set({ ["Mouse Left Button"] = true }) end
  emu.frameadvance()
  if route.shots[frame] then client.screenshot(string.format("%s/screen-%05d.png", route.out, frame)) end
  if frame >= route.last then break end
  if frame == route.level then findDriver() end
  if frame >= route.level then logSound(last) end
  if frame >= route.level then
    local now = iteration()
    if now == last and changed > 0 and frame - changed > 350 and route.last >= 1e9 then
      log:write("level over\n")
      break
    end
    if now ~= last then
      if last >= 0 and last == now - 1 then
        os.rename(shot, string.format("%s/dos-%05d.png", route.out, last))
        kept = last
        log:write(string.format("iteration %d frame %d cursor %d %d %d %d\n", last, frame - 1,
          box[1], box[2], box[3], box[4]))
        local x, y = memory.read_u16_le(cursorX, domain), memory.read_u16_le(cursorY, domain)
        box = { x, y, x, y }
      end
      last = now
      if route.dumps[now] then
        local f = io.open(string.format("%s/mem-%d.bin", route.out, now), "wb")
        local bytes = memory.read_bytes_as_array(0, 655360, domain)
        for i = 1, #bytes, 4096 do
          f:write(string.char(table.unpack(bytes, i, math.min(i + 4095, #bytes))))
        end
        f:close()
      end
      changed = frame
      if kept >= route.iterations then break end
    end
    os.remove(shot)
    client.screenshot(shot)
    spanCursor()
  end
end
end)
if not ok then log:write("error " .. tostring(err) .. "\n") end
log:close()
client.exit()
