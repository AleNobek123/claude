--[[
	BeeCodec
	Packs bee task changes into one buffer per server tick. A task says where a bee goes
	and when; clients interpolate the flight themselves, so the server never streams
	per-frame positions.

	Record layout (32 bytes):
	  0  u8  hive index (owner)     1  u8  slot      2  u8  task type   3  u8  (pad)
	  4  u16 target id (monster for Attack)          6  u16 (pad)
	  8  f32 x   12 f32 y   16 f32 z                 target position
	  20 f64 start (workspace:GetServerTimeNow())
	  28 f32 duration (seconds)
]]

local BeeCodec = {}

BeeCodec.RECORD_SIZE = 32

BeeCodec.Task = {
	Follow = 0, -- orbit the owner (no target)
	FlyTo = 1, -- fly to a flower
	Gather = 2, -- hover on a flower
	ToHive = 3, -- carry pollen to the owner's hive cell
	ToOwner = 4, -- fly back to the (moving) owner
	Attack = 5, -- dive at a monster (target id)
	Rest = 6, -- sit in the hive cell
}

export type TaskRecord = {
	Hive: number,
	Slot: number,
	Task: number,
	Target: Vector3,
	Start: number,
	Duration: number,
	TargetId: number,
}

function BeeCodec.Encode(records: { TaskRecord }): buffer
	local size = BeeCodec.RECORD_SIZE
	local buf = buffer.create(#records * size)
	for i, r in records do
		local o = (i - 1) * size
		buffer.writeu8(buf, o, r.Hive)
		buffer.writeu8(buf, o + 1, r.Slot)
		buffer.writeu8(buf, o + 2, r.Task)
		buffer.writeu16(buf, o + 4, r.TargetId or 0)
		buffer.writef32(buf, o + 8, r.Target.X)
		buffer.writef32(buf, o + 12, r.Target.Y)
		buffer.writef32(buf, o + 16, r.Target.Z)
		buffer.writef64(buf, o + 20, r.Start)
		buffer.writef32(buf, o + 28, r.Duration)
	end
	return buf
end

function BeeCodec.Decode(buf: buffer): { TaskRecord }
	local size = BeeCodec.RECORD_SIZE
	local count = buffer.len(buf) // size
	local out = table.create(count)
	for i = 1, count do
		local o = (i - 1) * size
		out[i] = {
			Hive = buffer.readu8(buf, o),
			Slot = buffer.readu8(buf, o + 1),
			Task = buffer.readu8(buf, o + 2),
			TargetId = buffer.readu16(buf, o + 4),
			Target = Vector3.new(buffer.readf32(buf, o + 8), buffer.readf32(buf, o + 12), buffer.readf32(buf, o + 16)),
			Start = buffer.readf64(buf, o + 20),
			Duration = buffer.readf32(buf, o + 28),
		}
	end
	return out
end

return BeeCodec
