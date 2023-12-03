extends Control

var m_image_texture:ImageTexture = null
var m_image:Image = null
var m_entropy_2darray:Array
var m_font
var m_font_size
var m_tile_size:Vector2i
var m_tile_count:Vector2i

# Called when the node enters the scene tree for the first time.
func _ready():
    #m_font = ThemeDB.fallback_fon
    #m_font = get_theme_font("font")
    #XXXm_font = get_default_font()
    m_font = theme.default_font
    m_font_size = theme.default_font_size
    #print ("Font Name: %s" % m_font.get_name())

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


func get_tile_entropy(tile_x:int, tile_y:int) -> int:
    if m_entropy_2darray == null:
        return -1
    return m_entropy_2darray[tile_x][tile_y]

func set_tile(tile_x:int, tile_y:int, tile:Image, entropy:int) -> void:

    if m_entropy_2darray == null:
        return
    if m_image_texture == null:
        return

    m_entropy_2darray[tile_x][tile_y] = entropy

    var x:int = tile_x * tile.get_width()
    var y:int = tile_y * tile.get_height()

    m_image.blit_rect(tile, Rect2(0, 0, tile.get_width(), tile.get_height()), Vector2(x, y))
    #print ("Tile Size: %s" % str(tile.get_size()))
    # if the entropy is not 0, then we need to draw a tile with the entropy value on it
    #if entropy != 0:
    #    m_image.draw_string(m_font, Vector2(x + float(tile_x) / 2, y + float(tile_y) / 2), str(entropy), HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))

    #m_image.draw_string(m_font, Vector2(10, 10), "TEST", HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1)

    m_image_texture.set_image(m_image)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if m_image_texture == null:
        return

func _draw():
    if m_image_texture != null:
        draw_texture(m_image_texture, Vector2(0, 0))
        for i in range(m_entropy_2darray.size()):
            for j in range(m_entropy_2darray[i].size()):
                if m_entropy_2darray[i][j] != 0:
                    draw_string(m_font, Vector2(i * m_tile_size.x + m_tile_size.x / 2, j * m_tile_size.y + m_tile_size.y / 2), str(m_entropy_2darray[i][j]), HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
        #draw_rect(Rect2(0, 0, get_size().x, get_size().y), Color(1, 1, 1, 1), false)

