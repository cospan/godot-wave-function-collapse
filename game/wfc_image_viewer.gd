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
                print ("Entropy: %d" % entropy)
                if entropy != 1:
                    #print ("Entropy: %d" % entropy)
                    var pos = Vector2(i * m_tile_size.x + float(m_tile_size.x) / 2, j * m_tile_size.y + float(m_tile_size.y) / 2)
                    draw_string(m_font, pos, str(entropy), HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
