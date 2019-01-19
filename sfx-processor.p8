pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- step 1: set cart filename
target = 'yourcart.p8'

function process()
  -- step 2: write code here
  -- (see next tabs for api)

  -- example: increase volume
  -- of all existing notes
  for s = max_sfx_instrument + 1, max_sfx do
    for n = 0, max_note do
      local note = get_note(s, n)
      local vol = note:get_volume()

      if vol > 0 then
        note:set_volume(vol + 1)
      end
    end
  end

  -- example: move sfx out of
  -- sfx instrument slots (e.g.
  -- because you forgot to keep
  -- those slots free) but
  -- don't mess up any music
  --for s = 0, max_sfx_instrument do
  --  if not sfx_is_empty(s) then
  --    -- find a spare slot
  --    local dst = find_empty_sfx(max_sfx_instrument + 1)

  --    if dst then
  --      print('moving sfx ' .. s .. ' to ' .. dst)
  --      -- move this sfx to the spare slot
  --      swap_sfx(s, dst, true)
  --    else
  --      print('no more empty slots')
  --    end
  --  end
  --end
end

function _init()
  print('loading ' .. target)
  load_music_and_sfx()

  print('processing')
  process()

  print('writing')
  write_music_and_sfx()

  print('done')
end

-->8
-- api: useful functions

-- swaps sfx slots, optionally
-- updating music pattern
-- references
function swap_sfx(a, b, updatemusic)
  local addr1 = sfx_addr(a)
  local addr2 = sfx_addr(b)
  local tmp = 0x4300
  local len = 68

  -- swap sfx slots
  memcpy(tmp, addr1, len)
  memcpy(addr1, addr2, len)
  memcpy(addr2, tmp, len)

  if updatemusic then
    -- update music pattern refs
    for i = 0, 63 do
      local p = get_pattern(i)
      for ch = 0, 3 do
        local ref = p:get_sfx(ch)

        if ref == a then
          p:set_sfx(ch, b)
        elseif ref == b then
          p:set_sfx(ch, a)
        end
      end
    end
  end
end

function sfx_is_empty(s)
  for n = 0, max_note do
    local note = get_note(s, n)
    if note:get_volume() > 0 then
      return false
    end
  end
  return true
end

-- returns the index of the first
-- empty sfx slot
function find_empty_sfx(start)
  start = start or 0
  assert(start >= 0 and start <= max_sfx)

  for s = start, max_sfx do
    if sfx_is_empty(s) then
      return s
    end
  end
end

-->8
-- api: note/pattern classes

-- start note class
note = {}
note.__index = note
note.volume_mask = 0b00001110
-- constructor
function get_note(sfx, n)
  local n = {
    sfx = sfx,
    addr = note_addr(sfx, n)
  }
  setmetatable(n, note)
  return n
end
function note:get_instrument()
  local byte1 = peek(self.addr)
  local byte2 = peek(self.addr + 1)
  local r = shr(band(byte1, 0b11000000), 6)
  local l = shl(band(byte2, 0b00000001), 2)
  local issfxinst = (band(byte2, 0b10000000) > 0)
  return bor(l, r), issfxinst
end
function note:get_volume()
  local byte2 = peek(self.addr + 1)
  return shr(band(byte2, note.volume_mask), 1)
end
function note:set_volume(v)
  v = mid(0, v, 7)

  local byte2 = peek(self.addr + 1)

  -- clear the existing volume bits
  byte2 = band(byte2, bnot(note.volume_mask))

  -- add new volume bits
  byte2 = bor(byte2, shl(v, 1))

  poke(self.addr + 1, byte2)
end
-- end note class

-- start pattern class
pattern = {}
pattern.__index = pattern
-- constructor
function get_pattern(n)
  assert(n >= 0 and n <= max_pattern)
  local p = {
    addr = pattern_addr(n)
  }
  setmetatable(p, pattern)
  return p
end
function pattern:get_sfx(ch)
  assert(ch >= 0 and ch <= max_channel)
  local byte = peek(self.addr + ch)
  return band(byte, 0b00111111)
end
function pattern:set_sfx(ch, ref)
  assert(ch >= 0 and ch <= max_channel)
  assert(ref >= 0 and ref <= max_sfx)
  local byte = peek(self.addr + ch)

  -- remove the current sfx index
  byte = band(byte, 0b11000000)

  -- add the new sfx index
  byte = bor(byte, ref)

  -- poke the byte back in
  poke(self.addr + ch, byte)
end
-- end pattern class

-->8
-- constants and address functions

-- constants
memory_start = 0x3100
memory_len = 0x1200
max_channel = 3
max_sfx = 63
max_note = 31
max_pattern = 63
max_sfx_instrument = 7

function sfx_addr(n)
  return 0x3200 + (68 * n)
end

function note_addr(sfx, n)
  return sfx_addr(sfx) + (2 * n)
end

function pattern_addr(n)
  return 0x3100 + (4 * n)
end

function load_music_and_sfx()
  -- zero existing data
  memset(memory_start, 0, memory_len)

  -- load from external cart
  reload(memory_start, memory_start, memory_len, target)

  local hasdata = false
  for s = 0, max_sfx do
    if not sfx_is_empty(s) then
      hasdata = true
      break
    end
  end

  if not hasdata then
    print('error: no data was loaded')
    print('check filename')
    stop()
  end
end

function write_music_and_sfx()
  cstore(0x3100, 0x3100, 0x1200, target)
end
