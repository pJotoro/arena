package allocators

import "core:mem"

Arena :: struct {
    data: []byte,
    end: rawptr,
    temp_count: int,
}

init :: proc(arena: ^Arena, data: []byte) -> mem.Allocator_Error {
    arena.data = data
    arena.end = raw_data(arena.data)
    return .None
}

allocator :: proc(arena: ^Arena) -> mem.Allocator {
    return {procedure, arena}
}

procedure :: proc(data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, loc := #caller_location) -> ([]byte, mem.Allocator_Error) {
    arena := (^Arena)(data)

    #partial switch mode {
        case .Alloc, .Alloc_Non_Zeroed:
            arena.end = mem.align_forward(arena.end, uintptr(alignment))
            ptr := arena.end
            arena.end = rawptr(uintptr(arena.end) + uintptr(size))
            assert(uintptr(arena.end) + uintptr(size) < uintptr(&arena.data[len(arena.data)-1]))
            return ([^]byte)(ptr)[:size], .None
        
        case .Free_All:
            arena.end = raw_data(arena.data)
            return nil, .None
            
        case .Query_Features:
            set := (^mem.Allocator_Mode_Set)(old_memory)
            if set != nil {
                set^ = {.Alloc, .Alloc_Non_Zeroed, .Free_All, .Query_Features}
            }
            return nil, nil
    }

    return nil, .Mode_Not_Implemented
}

Temp_Memory :: struct {
	arena:    ^Arena,
	prev_end: rawptr,
}

@(require_results)
begin_temp_memory :: proc(a: ^Arena) -> Temp_Memory {
	tmp: Temp_Memory
	tmp.arena = a
	tmp.prev_end = a.end
	a.temp_count += 1
	return tmp
}

end_temp_memory :: proc(tmp: Temp_Memory) {
	assert(uintptr(tmp.arena.end) >= uintptr(tmp.prev_end))
	assert(tmp.arena.temp_count > 0)
	tmp.arena.end = tmp.prev_end
	tmp.arena.temp_count -= 1
}