extends Node

var m_tile_map:Array
var m_tile_dict:Dictionary
var m_entropy_dict:Dictionary = Dictionary()
var m_soft_constraint_callback:Callable
var m_enable_edge:bool = false
var MAX_ENTROPY:int = -1
const WILD_TILE:int = 0

##############################################################################
# Debug Members
##############################################################################
var m_dbg_tile_sockets:Array = Array()
var m_dbg_tile_position:Vector2i = Vector2i(-1, -1)
var m_dbg_tile_neighbors:Array = Array()
var m_dbg_hard_constraints:Array = Array()

signal soft_constraint

##############################################################################
# WFC Public Functions
##############################################################################
func initialize(width:int, height:int, depth:int, tile_dict:Dictionary, empty_tile_index:int = 0, enable_edge = true, soft_constraint_callback = null):
    # Create a tilemap
    m_enable_edge = enable_edge
    MAX_ENTROPY = len(tile_dict.keys()) - 1 # -1 because the first tile is the empty tile
    m_soft_constraint_callback = soft_constraint_callback
    m_tile_dict = tile_dict
    m_tile_map = Array()
    m_tile_map.resize(width)
    # How to make this seamlessly transition between 2D and 3D?

    for x in range(width):
        m_tile_map[x] = Array()
        m_tile_map[x].resize(height)
        for y in range(height):
            if depth == 0:
                # 2D Tilemap
                var tile_name = tile_dict.keys()[empty_tile_index]
                #var tile_name = tile_dict[tile_dict.keys()[empty_tile_index]]
                m_tile_map[x][y] = {"type": tile_name, "entropy": MAX_ENTROPY}
                update_entropy_dict(Vector2i(x, y), -1, MAX_ENTROPY)
            else:
                # 3D Design
                m_tile_map[x][y] = Array()
                m_tile_map[x][y].resize(depth)
                for z in range(depth):
                    var tile_name = tile_dict.keys()[empty_tile_index]
                    m_tile_map[x][y][z] = {"type": tile_name, "entropy": MAX_ENTROPY}
                    update_entropy_dict(Vector3i(x, y, z), -1, MAX_ENTROPY)


'''
Every iteration analyze a tile, if there are no more tiles to analyze, return false
If the user gives a priority tile, we will only analyze that tile otherwise we will analyze the tile with the lowest entropy
'''
func step(priority_tile = null) -> bool:
    # If a priority tile is given, we will only update that tile
    var tile_pos = priority_tile
    if priority_tile == null:
        tile_pos = find_lowest_entropy_tile_pos()

    while tile_pos != null:
        if tile_pos.x == -1 and tile_pos.y == -1:
            return false
        var adjacent_tile_positions = get_adjacent_tile_positions(tile_pos)
        var adjacent_tile_sockets = get_sockets_from_tile_positions(tile_pos, adjacent_tile_positions)
        var valid_tiles = get_valid_tiles_from_sockets(adjacent_tile_sockets)
        if len(valid_tiles) == 0:
            assert (false, "Contradiction found, no valid tiles for tile at position: " + str(tile_pos))

        var collapsed_tile_name
        if m_soft_constraint_callback:
            collapsed_tile_name = m_soft_constraint_callback.call(valid_tiles)
        else:
            collapsed_tile_name = valid_tiles[randi() % len(valid_tiles)]

        m_dbg_tile_position = tile_pos
        m_dbg_tile_neighbors = adjacent_tile_positions
        m_dbg_tile_sockets = adjacent_tile_sockets
        m_dbg_hard_constraints = valid_tiles

        if tile_pos is Vector2i:
            m_tile_map[tile_pos.x][tile_pos.y] = {"type": collapsed_tile_name, "entropy": 1}
        elif tile_pos is Vector3i:
            m_tile_map[tile_pos.x][tile_pos.y][tile_pos.z] = {"type": collapsed_tile_name, "entropy": 1}


        tile_pos = propagate_entropy(tile_pos)
    return true

##############################################################################
# WFC Utility Functions
##############################################################################
func propagate_entropy(tile_pos:Vector2i):
    #print ("Tile Pos: %s" % str(tile_pos))
    var adjacent_tile_positions = get_adjacent_tile_positions(tile_pos)
    for adjacent_tile_pos in adjacent_tile_positions:
        var adjacent_tile = m_tile_map[adjacent_tile_pos.x][adjacent_tile_pos.y]
        var current_entropy = adjacent_tile["entropy"]
        if current_entropy == 1:
            continue
        if current_entropy == 0:
            assert (false, "Contradiction found, no valid tiles for tile at position: " + str(adjacent_tile_pos))

        var new_entropy = calculate_entropy(adjacent_tile_pos)
        if new_entropy == 1:
            return adjacent_tile_pos

        if new_entropy != current_entropy:
            m_tile_map[adjacent_tile_pos.x][adjacent_tile_pos.y]["entropy"] = new_entropy
            update_entropy_dict(adjacent_tile_pos, current_entropy, new_entropy)
            if (propagate_entropy(adjacent_tile_pos) != null):
                return adjacent_tile_pos
    return null

func calculate_entropy(tile_pos) -> int:
    var adjacent_tile_positions = get_adjacent_tile_positions(tile_pos)
    var adjacent_sockets = get_sockets_from_tile_positions(tile_pos, adjacent_tile_positions)
    var valid_tiles = get_valid_tiles_from_sockets(adjacent_sockets)
    return len(valid_tiles)

func update_entropy_dict(pos, current_entropy:int, new_entropy:int):
    if current_entropy in m_entropy_dict:
        m_entropy_dict[current_entropy].erase(pos)
        if len(m_entropy_dict[current_entropy]) == 0:
            m_entropy_dict.erase(current_entropy)
    if new_entropy in m_entropy_dict:
        m_entropy_dict[new_entropy].append(pos)
    else:
        m_entropy_dict[new_entropy] = Array()
        m_entropy_dict[new_entropy].append(pos)

# Adjacent Tile Functions
func get_adjacent_tile_positions(tile_pos) -> Array:
    var adjacent_positions = Array()
    if tile_pos is Vector2i:
        if tile_pos.x > 0:
            adjacent_positions.append(Vector2i(tile_pos.x - 1, tile_pos.y))
        if tile_pos.x < len(m_tile_map) - 1:
            adjacent_positions.append(Vector2i(tile_pos.x + 1, tile_pos.y))
        if tile_pos.y > 0:
            adjacent_positions.append(Vector2i(tile_pos.x, tile_pos.y - 1))
        if tile_pos.y < len(m_tile_map[0]) - 1:
            adjacent_positions.append(Vector2i(tile_pos.x, tile_pos.y + 1))
    elif tile_pos is Vector3i:
        if tile_pos.x > 0:
            adjacent_positions.append(Vector3i(tile_pos.x - 1, tile_pos.y, tile_pos.z))
        if tile_pos.x < len(m_tile_map) - 1:
            adjacent_positions.append(Vector3i(tile_pos.x + 1, tile_pos.y, tile_pos.z))
        if tile_pos.y > 0:
            adjacent_positions.append(Vector3i(tile_pos.x, tile_pos.y - 1, tile_pos.z))
        if tile_pos.y < len(m_tile_map[0]) - 1:
            adjacent_positions.append(Vector3i(tile_pos.x, tile_pos.y + 1, tile_pos.z))
        if tile_pos.z > 0:
            adjacent_positions.append(Vector3i(tile_pos.x, tile_pos.y, tile_pos.z - 1))
        if tile_pos.z < len(m_tile_map[0][0]) - 1:
            adjacent_positions.append(Vector3i(tile_pos.x, tile_pos.y, tile_pos.z + 1))
    return adjacent_positions

func get_sockets_from_tile_positions(tile_pos, adjacent_positions:Array) -> Array:
    # We can make this more flexible by finding the lengths of sockets from the tilemap
    var adjacent_sockets = m_tile_dict[m_tile_dict.keys()[0]]["sockets"].duplicate()

    for adjacent_pos in adjacent_positions:
        if adjacent_pos is Vector2i:
            var adjacent_tile_type = m_tile_map[adjacent_pos.x][adjacent_pos.y]["type"]
            var adjacent_tile_sockets = m_tile_dict[adjacent_tile_type]["sockets"]

            # This adjacent tile should be oriented correctly now
            var top = (tile_pos.y < adjacent_pos.y)
            var right = (tile_pos.x > adjacent_pos.x)
            var left = (tile_pos.x < adjacent_pos.x)
            var bottom = (tile_pos.y > adjacent_pos.y)

            if top:
                adjacent_sockets[2] = adjacent_tile_sockets[0]
            elif right:
                adjacent_sockets[3] = adjacent_tile_sockets[1]
            elif bottom:
                adjacent_sockets[0] = adjacent_tile_sockets[2]
            elif left:
                adjacent_sockets[1] = adjacent_tile_sockets[3]


        elif adjacent_pos is Vector3i:
            var adjacent_tile_type = m_tile_map[adjacent_pos.x][adjacent_pos.y][adjacent_pos.z]["type"]
            var adjacent_tile_sockets = m_tile_dict[adjacent_tile_type]["sockets"]

            # This adjacent tile should be oriented correctly now
            var top = (tile_pos.x < adjacent_pos.x)
            var right = (tile_pos.y > adjacent_pos.y)
            var left = (tile_pos.y < adjacent_pos.y)
            var bottom = (tile_pos.x > adjacent_pos.x)
            var front = (tile_pos.z < adjacent_pos.z)
            var back = (tile_pos.z > adjacent_pos.z)

            if top:
                adjacent_sockets[0] = adjacent_tile_sockets[2]
            elif right:
                adjacent_sockets[1] = adjacent_tile_sockets[3]
            elif bottom:
                adjacent_sockets[2] = adjacent_tile_sockets[0]
            elif left:
                adjacent_sockets[3] = adjacent_tile_sockets[1]
            elif front:
                adjacent_sockets[4] = adjacent_tile_sockets[5]
            elif back:
                adjacent_sockets[5] = adjacent_tile_sockets[4]

    return adjacent_sockets

func get_valid_tiles_from_sockets(sockets:Array) -> Array:
    # We have an array of sockets that is populated with either SocketType.PATH or SocketType.BLANK or SocketType.WILD
    var valid_tile_types = m_tile_dict.keys().slice(1)
    #valid_tile_types.remove_at(0)
    for i in range(len(sockets)):
        var s = sockets[i]
        if s == WILD_TILE:
            continue
        var keys = valid_tile_types.duplicate()
        for tile_type in keys:
            var socket_type = m_tile_dict[tile_type]["sockets"][i]
            if s != socket_type:
                valid_tile_types.erase(tile_type)
    return valid_tile_types


##############################################################################
# Entropy Dictionary Functions
##############################################################################
func find_lowest_entropy_tile_pos():
    var lowest_entropy = MAX_ENTROPY
    var lowest_entropy_pos = Vector2i(-1, -1)
    var keys = m_entropy_dict.keys()
    keys.sort()
    for key in keys:
        if key < lowest_entropy:
            lowest_entropy = key

    if lowest_entropy not in m_entropy_dict:
        return Vector2i(-1, -1)

    lowest_entropy_pos = m_entropy_dict[lowest_entropy].pop_back()
    if m_entropy_dict[lowest_entropy].size() == 0:
        m_entropy_dict.erase(lowest_entropy)
    return lowest_entropy_pos
