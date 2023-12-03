extends Control
class_name WFCTile

var m_image_texture:ImageTexture = null
var m_entropy:int = 100

#@onready var m_label:Label = $EntropyLabel
var m_label:Label = null

# Called when the node enters the scene tree for the first time.
func _ready():
    m_label = Label.new()
    m_label.set_text(str(m_entropy))
    m_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
    m_label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
    m_label.set_anchors_preset(LayoutPreset.PRESET_FULL_RECT)
    m_label.set_visible(false)
    add_child(m_label)
    if size.x == 0 or size.y == 0:
        size.x = 100
        size.y = 100

    var image = Image.create(floori(size.x), floori(size.y), false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 1))
    m_image_texture = ImageTexture.create_from_image(image)

func set_entropy(entropy:int):
    m_entropy = entropy
    m_label.text = str(m_entropy)

func set_tile(tile:Image):
    m_image_texture = ImageTexture.create_from_image(tile)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func _draw():
    if m_entropy > 0:
        m_label.set_visible(true)
        m_label.set_text(str(m_entropy))
    else:
        m_label.set_visible(false)
        draw_texture(m_image_texture, Vector2(0, 0))


