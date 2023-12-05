extends Control

@export var TILE_COUNT_WIDTH = 10
@export var TILE_COUNT_HEIGHT = 10
@export var ENABLE_EDGE = true


@export var texture_empty = preload("res://assets/wfc_empty.png")
@export var texture_nothing = preload("res://assets/wfc_nothing.png")
@export var texture_straight = preload("res://assets/wfc_straight.png")
@export var texture_turn = preload("res://assets/wfc_turn.png")
@export var texture_t = preload("res://assets/wfc_t.png")
@export var texture_cross = preload("res://assets/wfc_cross.png")
@export var texture_end = preload("res://assets/wfc_end.png")

enum TileType {
    EMPTY,
    NOTHING,
    STRAIGHT,
    STRAIGHT_90,
    TURN,
    TURN_90,
    TURN_180,
    TURN_270,
    T,
    T_90,
    T_180,
    T_270,
    CROSS,
    END
}

enum SocketType {
    WILD,
    BLANK,
    PATH
}

var WILD_SOCKET = SocketType.WILD
var COLLAPSED_SOCKETS = [SocketType.BLANK, SocketType.PATH]
var MAX_ENTROPY = 0

var m_wfc_image_viewer = null
var m_wfc_tile_grid_view = null
var m_image_size = Vector2i(0, 0)
# Create a dictionary of textures, along with their socketss (top, right, bottom, left)
var m_texture_dict = Dictionary()
var m_tile_map = null
var m_entropy_dict = Dictionary()
var m_finished = false
var m_priority_tile_pos = null


# Called when the node enters the scene tree for the first time.
func _ready():
    # find the size of an individual tile
    var tile_size = texture_nothing.get_size()
    m_texture_dict = create_texture_dictionary()
    MAX_ENTROPY = len(m_texture_dict.keys()) - 1
    print ("Size: %s" % tile_size)
    m_image_size = Vector2i(tile_size.x * TILE_COUNT_WIDTH, tile_size.y * TILE_COUNT_HEIGHT)
    print ("Image Size: %s" % m_image_size)
    m_wfc_image_viewer = $wfc_image_viewer
    m_wfc_image_viewer.set_texture_and_image_sizes(tile_size, TILE_COUNT_WIDTH, TILE_COUNT_HEIGHT)
    m_wfc_tile_grid_view = $WFCTileGrid
    m_wfc_tile_grid_view.configure_grid(TILE_COUNT_WIDTH, TILE_COUNT_HEIGHT)
    wfc_init()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if m_finished == false:
        wfc_step()

# Entropy Dictionary Functions
func add_tile_pos_to_entropy_dict(entropy:int, pos:Vector2i):
    if m_entropy_dict.has(entropy) == false:
        m_entropy_dict[entropy] = Array()
    m_entropy_dict[entropy].append(pos)

func find_lowest_entropy_tile_pos() -> Vector2i:
    var lowest_entropy = MAX_ENTROPY
    var lowest_entropy_pos = Vector2i(-1, -1)
    var keys = m_entropy_dict.keys()
    keys.sort()
    for key in keys:
        if key < lowest_entropy:
            lowest_entropy = key
            lowest_entropy_pos = m_entropy_dict[key].pop_back()
            if len(m_entropy_dict[key]) == 0:
                m_entropy_dict.erase(key)
            break
    return lowest_entropy_pos

func update_entropy_dict(pos:Vector2i, current_entropy:int, new_entropy:int):
    # Remove the position from the old entropy
    m_entropy_dict[current_entropy].erase(pos)
    # check if that entropy is empty, if so remove it
    if len(m_entropy_dict[current_entropy]) == 0:
        m_entropy_dict.erase(current_entropy)
    # Add the position to the new entropy
    if m_entropy_dict.has(new_entropy) == false:
        m_entropy_dict[new_entropy] = Array()
    m_entropy_dict[new_entropy].append(pos)

func wfc_init():
    # Get the starting position
    # Initialize Tile Map 2D Array
    m_tile_map = Array()
    m_tile_map.resize(TILE_COUNT_WIDTH)
    for i in range(m_tile_map.size()):
        m_tile_map[i] = Array()
        m_tile_map[i].resize(TILE_COUNT_HEIGHT)
        for j in range(m_tile_map[i].size()):
            # XXX Do I need the 'collapsed' flag?  I think I can just check entropy to see if it is '1'
            m_tile_map[i][j] = {"type": "EMPTY", "entropy": MAX_ENTROPY, "collapsed": false}
            add_tile_pos_to_entropy_dict(MAX_ENTROPY, Vector2i(i, j))
    # Populate the tile map with empty tiles
    update_all_wfc_tiles()

    # Pick a random tile to start with
    m_priority_tile_pos = Vector2i(randi_range(0, (TILE_COUNT_WIDTH - 1)), randi_range(0, (TILE_COUNT_HEIGHT - 1)))
    m_finished = false

func wfc_step():

    # Check if the user requested a tile to be placed over the entropy rules
    var m_tile_pos = m_priority_tile_pos
    m_priority_tile_pos = null

    # Get the lowest entropy tile
    if m_tile_pos == null:
        m_tile_pos = find_lowest_entropy_tile_pos()

    if m_tile_pos.x == -1 and m_tile_pos.y == -1:
        m_finished = true
        return

    # The entropy has been updated from a previous step

    # Get a list of possible types
    var adjacent_tile_positions = get_adjacent_positions(m_tile_pos)
    var adjacent_sockets = get_sockets_from_position(m_tile_pos, adjacent_tile_positions)
    var valid_tiles = get_valid_tiles_from_sockets(adjacent_sockets)
    if len(valid_tiles) == 0:
        # We have a contradiction, we need to backtrack, or just bail!
        assert(false, "Contradiction at %s" % m_tile_pos)

    # Collapse the tile to a single type (Pick a random tile from the list of valid tiles)
    var rand_tile_name = valid_tiles[randi_range(0, valid_tiles.size() - 1)]
    #var rand_tile_name = TileType.keys()[rand_tile]
    #var rand_tile_name = TileType.values()[rand_tile]
    m_tile_map[m_tile_pos.x][m_tile_pos.y] = {"type":  rand_tile_name, "entropy": 1, "collapsed": true}

    # Propagate the entropy until it is stable
    propagate_entropy(m_tile_pos)
    update_all_wfc_tiles()

func propagate_entropy(pos:Vector2i):
    #XXX An optimization is to keep a list of tiles that have changed entropy so we do not need to re-check them
    #XXX we can also keep a list of the tiles with the lowest entropy so we can start with those on the next step, perhaps a dictionary of lists where we can order the keys by entropy
    # We need to propagate the entropy to all adjacent tiles
    # Get a list of adjacent tiles
    var adjacent_tile_positions = get_adjacent_positions(pos)
    # For each adjacent tile, get the sockets
    for tile_pos in adjacent_tile_positions:
        # Get the entropy of the current tile
        var current_entropy = m_tile_map[tile_pos.x][tile_pos.y]["entropy"]
        if m_tile_map[tile_pos.x][tile_pos.y]["collapsed"] == true:
            continue

        var new_entropy = get_entropy(tile_pos)
        # if the entropy has not changed and we are out of tiles to check then we are done
        if new_entropy != current_entropy:
            # Update the entropy
            m_tile_map[tile_pos.x][tile_pos.y]["entropy"] = new_entropy
            update_entropy_dict(tile_pos, current_entropy, new_entropy)
            # If we have more tiles to check then recurse
            propagate_entropy(tile_pos)

func get_entropy(tile_pos:Vector2i) -> int:
    var adjacent_tile_positions = get_adjacent_positions(tile_pos)
    var adjacent_sockets = get_sockets_from_position(tile_pos, adjacent_tile_positions)
    var valid_tiles = get_valid_tiles_from_sockets(adjacent_sockets)
    return len(valid_tiles)

func find_empty_tile():
    # Go through each tile and if it is empty return the position
    for i in range(TILE_COUNT_WIDTH):
        for j in range(TILE_COUNT_HEIGHT):
            if m_tile_map[i][j]["type"] == "EMPTY":
                return Vector2i(i, j)
    # after going through all the tiles if the stack is empty then we are done, return null
    return null

func update_all_wfc_tiles():
    for i in range(TILE_COUNT_WIDTH):
        for j in range(TILE_COUNT_HEIGHT):
            var tile_name = m_tile_map[i][j]["type"]
            var model_entropy = m_tile_map[i][j]["entropy"]
            var view_entropy = m_wfc_image_viewer.get_tile_entropy(i, j)
            #var tile_entropy = m_wfc_image_viewer.get_tile_entropy(i, j)
            if view_entropy != model_entropy:
                #print ("Updating Tile to new entropy: %s" % str([i, j, tile_name, view_entropy, model_entropy]))
                # We should update
                m_wfc_image_viewer.set_tile(i, j, m_texture_dict[tile_name]["image"], model_entropy)

func get_adjacent_positions(tile_pos:Vector2i) -> Array:
    var tile_pos_x = tile_pos.x
    var tile_pos_y = tile_pos.y
    var adjacent_positions = Array()

    # Do not add adjacent positions that are outside the bounds of the tile map
    if tile_pos_x > 0:
        adjacent_positions.append(Vector2i(tile_pos_x - 1, tile_pos_y))
    if tile_pos_x < TILE_COUNT_WIDTH - 1:
        adjacent_positions.append(Vector2i(tile_pos_x + 1, tile_pos_y))
    if tile_pos_y > 0:
        adjacent_positions.append(Vector2i(tile_pos_x, tile_pos_y - 1))
    if tile_pos_y < TILE_COUNT_HEIGHT - 1:
        adjacent_positions.append(Vector2i(tile_pos_x, tile_pos_y + 1))

    # XXX Below is a more general way to do this, but it is slower
    ## Make sure that the adjacent positions are within the bounds of the tile map
    #var remove_list = Array()
    #for i in range(adjacent_positions.size()):
    #    if adjacent_positions[i].x < 0 or adjacent_positions[i].x >= TILE_COUNT_WIDTH \
    #    or adjacent_positions[i].y < 0 or adjacent_positions[i].y >= TILE_COUNT_HEIGHT:
    #        remove_list.append(adjacent_positions[i])

    #for i in range(remove_list.size()):
    #    adjacent_positions.erase(remove_list[i])

    return adjacent_positions

func get_sockets_from_position(tile_pos:Vector2i, adjacent_tile_positions:Array) -> Array:
    #var tile_types = [TileType.NOTHING, TileType.STRAIGHT, TileType.TURN, TileType.T, TileType.CROSS, TileType.END]
    var sockets = [SocketType.WILD, SocketType.WILD, SocketType.WILD, SocketType.WILD]
    # Go through each of the adjacent tiles and see if they have an appropriate sockets
    for adjacent_tile in adjacent_tile_positions:
        var adjacent_tile_type = m_tile_map[adjacent_tile.x][adjacent_tile.y]["type"]
        var adjacent_tile_sockets = m_texture_dict[adjacent_tile_type]["sockets"]

        # This adjacent tile should be oriented correctly now
        var top = (tile_pos.x < adjacent_tile.x)
        var right = (tile_pos.y > adjacent_tile.y)
        var left = (tile_pos.y < adjacent_tile.y)
        var bottom = (tile_pos.x > adjacent_tile.x)


        if top:
            sockets[0] = adjacent_tile_sockets[2]
        elif right:
            sockets[1] = adjacent_tile_sockets[3]
        elif bottom:
            sockets[2] = adjacent_tile_sockets[0]
        elif left:
            sockets[3] = adjacent_tile_sockets[1]
    return sockets

func get_valid_tiles_from_sockets(sockets:Array) -> Array:

    # We have an array of sockets that is populated with either SocketType.PATH or SocketType.BLANK or SocketType.WILD
    var valid_tile_types = TileType.keys().slice(1)
    #valid_tile_types.remove_at(0)
    for i in range(len(sockets)):
        var s = sockets[i]
        if s == WILD_SOCKET:
            continue
        for tile_type in valid_tile_types:
            if s != m_texture_dict[tile_type]["sockets"][i]:
                valid_tile_types.erase(tile_type)
    return valid_tile_types


func create_texture_dictionary() -> Dictionary:
    var texture_dict = Dictionary()
    # Convert the images to RGBA8 format
    for key in TileType:
        texture_dict[key] = {}
        match(key):
            "EMPTY":
                var image = texture_empty.get_image()
                image.convert(Image.FORMAT_RGBA8)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.WILD,  SocketType.WILD,  SocketType.WILD,  SocketType.WILD]
            "NOTHING":
                var image = texture_nothing.get_image()
                image.convert(Image.FORMAT_RGBA8)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.PATH, SocketType.PATH, SocketType.PATH, SocketType.PATH]
            "STRAIGHT":
                var image = texture_straight.get_image()
                image.convert(Image.FORMAT_RGBA8)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.PATH, SocketType.BLANK,  SocketType.PATH, SocketType.BLANK]
            "STRAIGHT_90":
                var image = texture_straight.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(CLOCKWISE)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.BLANK,  SocketType.PATH, SocketType.BLANK,  SocketType.PATH]
            "TURN":
                var image = texture_turn.get_image()
                image.convert(Image.FORMAT_RGBA8)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.PATH, SocketType.BLANK,  SocketType.BLANK,  SocketType.PATH]
            "TURN_90":
                var image = texture_turn.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(CLOCKWISE)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.BLANK,  SocketType.PATH, SocketType.PATH, SocketType.BLANK]
            "TURN_180":
                var image = texture_turn.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_180()
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.PATH, SocketType.BLANK,  SocketType.BLANK,  SocketType.PATH]
            "TURN_270":
                var image = texture_turn.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(COUNTERCLOCKWISE)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.BLANK,  SocketType.PATH, SocketType.PATH, SocketType.BLANK]
            "T":
                var image = texture_t.get_image()
                image.convert(Image.FORMAT_RGBA8)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.BLANK,  SocketType.BLANK,  SocketType.BLANK,  SocketType.PATH]
            "T_90":
                var image = texture_t.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(CLOCKWISE)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.PATH, SocketType.BLANK,  SocketType.BLANK,  SocketType.BLANK]
            "T_180":
                var image = texture_t.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_180()
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.BLANK,  SocketType.BLANK,  SocketType.BLANK,  SocketType.PATH]
            "T_270":
                var image = texture_t.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(COUNTERCLOCKWISE)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.PATH, SocketType.BLANK,  SocketType.BLANK,  SocketType.BLANK]
            "CROSS":
                var image = texture_cross.get_image()
                image.convert(Image.FORMAT_RGBA8)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.BLANK,  SocketType.BLANK,  SocketType.BLANK,  SocketType.BLANK]
            "END":
                var image = texture_end.get_image()
                image.convert(Image.FORMAT_RGBA8)
                texture_dict[key]["image"] = image
                texture_dict[key]["sockets"] = [SocketType.PATH, SocketType.BLANK,  SocketType.PATH, SocketType.PATH]
            _:
                print ("Unrecognized Tile Type!")
    return texture_dict
