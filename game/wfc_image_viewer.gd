extends Control

var m_image_texture:ImageTexture = null
var m_image:Image = null
var m_entropy_2darray:Array
var m_font
var m_font_size
var m_tile_size:Vector2i
var m_tile_count:Vector2i

var m_highlight_pos:Vector2i = Vector2i(-1, -1)
var m_highlight_neighbor_positions:Array = []
var m_original_size:Vector2 = Vector2(-1, -1)
var m_scale:Vector2 = Vector2(-1, -1)
var m_shrink_scale:Vector2 = Vector2(-1, -1)
var m_shrink_flag:bool = false

const SHRINK_SCALE = 0.75

signal tile_selected(pos:Vector2i)

# Called when the node enters the scene tree for the first time.
func _ready():
    m_font = theme.default_font
    m_font_size = theme.default_font_size
    pass

func set_texture_and_image_sizes(tile_size:Vector2i, count_x:int, count_y:int) -> void:
    var texture_size = Vector2i(tile_size.x * count_x, tile_size.y * count_y)
    m_tile_size = tile_size
    m_tile_count = Vector2i(count_x, count_y)
    m_entropy_2darray = []
    m_entropy_2darray.resize(count_x)
    for i in range(count_x):
        m_entropy_2darray[i] = []
        m_entropy_2darray[i].resize(count_y)
        for j in range(count_y):
            m_entropy_2darray[i][j] = -1

    m_image = Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
    m_image.fill(Color(0, 0, 0, 1))
    m_image_texture = ImageTexture.create_from_image(m_image)
    set_size(texture_size)
    if m_original_size.x == -1:
        m_original_size = texture_size
    else:
        m_scale = Vector2(float(m_original_size.x) / float(texture_size.x), float(m_original_size.y) / float(texture_size.y))
        m_shrink_scale = Vector2(m_scale.x * SHRINK_SCALE, m_scale.y * SHRINK_SCALE)
        if m_shrink_flag:
            scale = m_shrink_scale
        else:
            scale = m_scale

func enable_shrink(enable:bool):
    m_shrink_flag = enable
    if m_shrink_flag:
        scale = m_shrink_scale
    else:
        scale = m_scale
    

func highlight_box(pos:Vector2i):
    m_highlight_pos = pos
    queue_redraw()

func highlight_neighbors(neighbor_positions:Array):
    m_highlight_neighbor_positions = neighbor_positions
    queue_redraw()

func get_tile_entropy(tile_x:int, tile_y:int) -> int:
    if m_entropy_2darray == null:
        return -1
    return m_entropy_2darray[tile_x][tile_y]

func set_tile(tile_x:int, tile_y:int, tile:Image, entropy:int) -> void:
    m_highlight_pos = Vector2i(-1, -1)
    m_highlight_neighbor_positions = []

    if m_entropy_2darray == null:
        print ("Warning: m_entropy_2darray is not ready")
        return
    if m_image_texture == null:
        print ("Warning: m_image_texture is not ready")
        return

    m_entropy_2darray[tile_x][tile_y] = entropy

    var x:int = tile_x * tile.get_width()
    var y:int = tile_y * tile.get_height()

    m_image.blit_rect(tile, Rect2(0, 0, tile.get_width(), tile.get_height()), Vector2(x, y))
    m_image_texture.set_image(m_image)
    queue_redraw()

func _draw():
    if m_image_texture != null:
        draw_texture(m_image_texture, Vector2(0, 0))
        for i in range(m_entropy_2darray.size()):
            for j in range(m_entropy_2darray[i].size()):
                var entropy = m_entropy_2darray[i][j]
                if entropy != 1:
                    var pos = Vector2(i * m_tile_size.x + float(m_tile_size.x) / 2, j * m_tile_size.y + float(m_tile_size.y) / 2)
                    draw_string(m_font, pos, str(entropy), HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
        if m_highlight_neighbor_positions.size() > 0:
            for i in range(m_highlight_neighbor_positions.size()):
                var pos = m_highlight_neighbor_positions[i]
                var pos2 = Vector2(pos.x * m_tile_size.x, pos.y * m_tile_size.y)
                draw_rect(Rect2(pos2, Vector2(m_tile_size.x, m_tile_size.y)), Color(0, 1, 0, 0.5))
        if m_highlight_pos.x != -1:
            var pos = Vector2(m_highlight_pos.x * m_tile_size.x, m_highlight_pos.y * m_tile_size.y)
            draw_rect(Rect2(pos, Vector2(m_tile_size.x, m_tile_size.y)), Color(1, 0, 0, 0.5))

        #get_global_rect()


func _on_gui_input(event:InputEvent):
    var pos = Vector2i(-1, -1)
    #print ("HI!")
    if event is InputEventMouseButton:
        #print ("Mouse Event")
        if event.button_index == 1 && event.pressed == true:
          pos.x = (event.position.x / m_tile_size.x) * m_scale.x
          pos.y = (event.position.y / m_tile_size.y) * m_scale.y
          print ("pos: ", pos)
          emit_signal("tile_selected", pos)

        print ("Global Rects: %s" % str(get_global_rect()))
        #print ("Full Screen Size: %s" % str(get_))




