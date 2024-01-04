extends Control

@export var DEFAULT_TILE_COUNT_WIDTH = 10
@export var DEFAULT_TILE_COUNT_HEIGHT = 10

@export var MIN_TILE_COUNT_WIDTH = 5
@export var MIN_TILE_COUNT_HEIGHT = 5

@export var MAX_TILE_COUNT_WIDTH = 20
@export var MAX_TILE_COUNT_HEIGHT = 20
@export var ENABLE_EDGE = true

#@export var DEFAULT_ENABLE_STEP = true
@export var DEFAULT_ENABLE_STEP = false


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
    END,
    END_90,
    END_180,
    END_270
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
# Create a dictionary of textures, along with their socketss (top, right, bottom, left)
var m_tile_dict = Dictionary()
var m_tile_map = null
var m_entropy_dict = Dictionary()
var m_processing = true
var m_finished = false
var m_priority_tile_pos = null
var m_wfc = null
var m_debug_property_view = null
var m_debug_props = {}

var m_step_enabled = DEFAULT_ENABLE_STEP
var m_step:bool = false

var m_tile_count_width = DEFAULT_TILE_COUNT_WIDTH
var m_tile_count_height = DEFAULT_TILE_COUNT_HEIGHT

# Called when the node enters the scene tree for the first time.
func _ready():
    # find the size of an individual tile
    m_debug_property_view = $hbox/DictProperty
    m_wfc_image_viewer = $hbox/wfc_image_viewer
    m_wfc = $WFC
    m_debug_props["start_button"] = {"type": "Button", "name": "Start"}
    m_debug_props["enable_step"] = {"type": "CheckBox", "value": DEFAULT_ENABLE_STEP, "name": "Enable Step"}
    m_debug_props["step_button"] = {"type": "Button", "name": "Step"}
    m_debug_props["enable debug data"] = {"type": "CheckBox", "value": false, "name": "Enable Debug Data"}
    m_debug_props["current_ports"] = {"type": "Label", "name":"Current Ports", "value":"XXXX", "visible": false}
    m_debug_props["possible_tiles"] = {"type": "ItemList", "name":"Possible Tiles", "size": Vector2(100, 200), "visible": false}
    #m_debug_props["tile width count"] = {"type": "HSlider", "min": MIN_TILE_COUNT_WIDTH, "max": MAX_TILE_COUNT_WIDTH, "step": 1, "value": m_tile_count_width, "name": "Tile Width Count"}
    #m_debug_props["tile_width_count_view"] = {"type":"LineEdit", "value": str(m_tile_count_width), "name": "", "readonly": true}
    #m_debug_props["tile height count"] = {"type": "HSlider", "min": MIN_TILE_COUNT_WIDTH, "max": MAX_TILE_COUNT_HEIGHT, "step": 1, "value": m_tile_count_height, "name": "Tile Height Count"}
    #m_debug_props["tile_height_count_view"] = {"type":"LineEdit", "value": str(m_tile_count_height), "name": "", "readonly": true}
    m_debug_property_view.update_dict(m_debug_props)
    print ("Debug Property: %s" % str(m_debug_property_view))
    m_tile_dict = create_tile_dictionary()
    MAX_ENTROPY = len(m_tile_dict.keys()) - 1
    start_wfc()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if m_step_enabled:
        if m_step:
            m_step = false
            m_processing = m_wfc.step(m_priority_tile_pos)
            m_priority_tile_pos = null
            update_all_wfc_tiles()
            m_wfc_image_viewer.highlight_neighbors(m_wfc.m_dbg_tile_neighbors)
            m_wfc_image_viewer.highlight_box(m_wfc.m_dbg_tile_position)
            m_debug_property_view.set_value("current_ports", str(m_wfc.m_dbg_tile_sockets))
            # Create a list with both the strings and images
            var possible_tiles = Array()
            for tile in m_wfc.m_dbg_valid_tiles:
                possible_tiles.append([tile, m_tile_dict[tile]["image"]])
            print ("Possible Children: %s" % str(m_wfc.m_dbg_valid_tiles))
            #m_debug_property_view.set_value("possible_tiles", m_wfc.m_dbg_valid_tiles)
            m_debug_property_view.set_value("possible_tiles", possible_tiles)
    elif m_processing:
        m_processing = m_wfc.step(m_priority_tile_pos)
        m_priority_tile_pos = null
        update_all_wfc_tiles()
    elif not m_finished:
        m_finished = true
        print ("Finished!")

func enable_debug_view(enable:bool):
    m_debug_property_view.set_prop_visible("current_ports", enable)
    m_debug_property_view.set_prop_visible("possible_tiles", enable)

func update_all_wfc_tiles():
    for i in range(m_tile_count_width):
        for j in range(m_tile_count_height):
            var tile_name = m_wfc.m_tile_map[i][j]["type"]
            var model_entropy = m_wfc.m_tile_map[i][j]["entropy"]
            var view_entropy = m_wfc_image_viewer.get_tile_entropy(i, j)
            if view_entropy != model_entropy:
                #print ("Updating Tile to new entropy: %s" % str([i, j, tile_name, view_entropy, model_entropy]))
                # We should update
                m_wfc_image_viewer.set_tile(i, j, m_tile_dict[tile_name]["image"], model_entropy)

func apply_soft_constraints(tiles:Array):
    # We have a list of tiles, we need to apply the soft constraints to them

    # First check if there are any tiles that have more than one path socket
    # If there are then we need to pick one of those tiles
    var path_tiles = Array()
    for tile in tiles:
        var sockets = m_tile_dict[tile]["sockets"]
        var path_count = 0
        for socket in sockets:
            if socket == SocketType.PATH:
                path_count += 1
        if path_count > 1:
            path_tiles.append(tile)

    if len(path_tiles) > 0:
        tiles = path_tiles

    var weighted_tiles = Array()
    for tile in tiles:
        var sockets = m_tile_dict[tile]["sockets"]
        var weight = 1 # Need this or there will never be any blank tiles
        for socket in sockets:
            if socket == SocketType.PATH:
                weight += 1
        weighted_tiles.append(weight)

    var collapsed_tile = tiles[weighted_random_select(weighted_tiles)]
    #print ("Tiles: %s" % str(tiles, weighted_tiles, collapsed_tile))
    #print ("Tile: %s" % str(collapsed_tile))
    return collapsed_tile

func weighted_random_select(weights:Array) -> int:
    # We have an array of weights, we need to pick a random index based on the weights
    # We can do this by creating a cumulative sum array and then picking a random number between 0 and the sum
    # Then we can find the index of the cumulative sum array that is greater than the random number
    var cumulative_sum = Array()
    var sum = 0
    for i in range(weights.size()):
        sum += weights[i]
        cumulative_sum.append(sum)
    var rand = randf_range(0, sum)
    for i in range(cumulative_sum.size()):
        if rand < cumulative_sum[i]:
            return i
    return cumulative_sum.size() - 1

func create_tile_dictionary() -> Dictionary:
    var tile_dict = Dictionary()
    # Convert the images to RGBA8 format
    for key in TileType:
        tile_dict[key] = {}
        match(key):
            "EMPTY":
                var image = texture_empty.get_image()
                image.convert(Image.FORMAT_RGBA8)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.WILD,  SocketType.WILD,  SocketType.WILD,  SocketType.WILD]
            "NOTHING":
                var image = texture_nothing.get_image()
                image.convert(Image.FORMAT_RGBA8)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.BLANK, SocketType.BLANK, SocketType.BLANK, SocketType.BLANK]
            "STRAIGHT":
                var image = texture_straight.get_image()
                image.convert(Image.FORMAT_RGBA8)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.BLANK, SocketType.PATH,  SocketType.BLANK, SocketType.PATH]
            "STRAIGHT_90":
                var image = texture_straight.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(CLOCKWISE)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.PATH,  SocketType.BLANK, SocketType.PATH,  SocketType.BLANK]
            "TURN":
                var image = texture_turn.get_image()
                image.convert(Image.FORMAT_RGBA8)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.BLANK, SocketType.PATH,  SocketType.PATH,  SocketType.BLANK]
            "TURN_90":
                var image = texture_turn.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(CLOCKWISE)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.BLANK,  SocketType.BLANK, SocketType.PATH, SocketType.PATH]
            "TURN_180":
                var image = texture_turn.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_180()
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.PATH, SocketType.BLANK,  SocketType.BLANK,  SocketType.PATH]
            "TURN_270":
                var image = texture_turn.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(COUNTERCLOCKWISE)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.PATH,  SocketType.PATH, SocketType.BLANK, SocketType.BLANK]
            "T":
                var image = texture_t.get_image()
                image.convert(Image.FORMAT_RGBA8)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.PATH,  SocketType.PATH,  SocketType.PATH,  SocketType.BLANK]
            "T_90":
                var image = texture_t.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(CLOCKWISE)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.BLANK, SocketType.PATH,  SocketType.PATH,  SocketType.PATH]
            "T_180":
                var image = texture_t.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_180()
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.PATH,  SocketType.BLANK,  SocketType.PATH,  SocketType.PATH]
            "T_270":
                var image = texture_t.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(COUNTERCLOCKWISE)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.PATH, SocketType.PATH,  SocketType.BLANK,  SocketType.PATH]
            "CROSS":
                var image = texture_cross.get_image()
                image.convert(Image.FORMAT_RGBA8)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.PATH,  SocketType.PATH,  SocketType.PATH,  SocketType.PATH]
            "END":
                var image = texture_end.get_image()
                image.convert(Image.FORMAT_RGBA8)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.BLANK, SocketType.PATH,  SocketType.BLANK, SocketType.BLANK]
            "END_90":
                var image = texture_end.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(CLOCKWISE)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.BLANK, SocketType.BLANK, SocketType.PATH,  SocketType.BLANK]
            "END_180":
                var image = texture_end.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_180()
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.BLANK,  SocketType.BLANK, SocketType.BLANK, SocketType.PATH]
            "END_270":
                var image = texture_end.get_image()
                image.convert(Image.FORMAT_RGBA8)
                image.rotate_90(COUNTERCLOCKWISE)
                tile_dict[key]["image"] = image
                tile_dict[key]["sockets"] = [SocketType.PATH, SocketType.BLANK, SocketType.BLANK, SocketType.BLANK]
            _:
                print ("Unrecognized Tile Type!")
    return tile_dict

func _on_dict_property_property_changed(property_name, property_value):
    match (property_name):
        "start_button":
            print ("Start!")
            start_wfc()
        "enable_step":
            m_step_enabled = property_value
        "step_button":
            m_step = true
        "enable debug data":
            print ("Eanble Debug: %s" % str(property_value))
            enable_debug_view(property_value)
            #m_wfc_image_viewer.enable_shrink(property_value)
        "tile width count":
            m_tile_count_width = property_value
            m_debug_property_view.set_value("tile_width_count_view", str(m_tile_count_width))
        "tile height count":
            m_tile_count_height = property_value
            m_debug_property_view.set_value("tile_height_count_view", str(m_tile_count_height))
        _:
            pass

func start_wfc():
    m_processing = true
    m_finished = false
    m_wfc_image_viewer.set_texture_and_image_sizes(texture_nothing.get_size(), m_tile_count_width, m_tile_count_height)
    m_priority_tile_pos = Vector2i(randi_range(0, (m_tile_count_width - 1)), randi_range(0, (m_tile_count_height - 1)))
    m_wfc.initialize(m_tile_count_width, m_tile_count_height, 0, m_tile_dict, 0, ENABLE_EDGE, apply_soft_constraints)
    update_all_wfc_tiles()
    #m_wfc_image_viewer.set_size(m_wfc_image_viewer.m_texture_size)

    #m_wfc_image_viewer.highlight_neighbors(m_wfc.m_dbg_tile_neighbors)
    #m_wfc_image_viewer.highlight_box(m_wfc.m_dbg_tile_position)
    call_deferred("update_hbox_size")

func update_hbox_size():
    #var hbox = $hbox
    m_wfc_image_viewer.custom_minimum_size = m_wfc_image_viewer.m_texture_size
    #m_wfc_image_viewer.set_size(m_wfc_image_viewer.m_texture_size)

func _on_wfc_image_viewer_tile_selected(pos):
    m_priority_tile_pos = pos
    m_step = true

func _on_gui_input(event):
    if event is InputEventMouseButton:
        print ("Game Input Mouse Event: %s" % str(event))
