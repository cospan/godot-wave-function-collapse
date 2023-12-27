extends VBoxContainer

@onready var m_right_socket = $GridContainerSocket/LabelRightValue
@onready var m_left_socket = $GridContainerSocket/LabelLeftValue
@onready var m_top_socket = $GridContainerSocket/LabelTopValue
@onready var m_bottom_socket = $GridContainerSocket/LabelBottomValue

@onready var m_hard_constraint_grid = $GridContainerHard
@onready var m_soft_constraint_grid = $GridContainerSoft

var m_tile_dict = {}

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.

func initialize(tile_dict:Dictionary):
    #This is a dictionary of the form:
    #{
        #"image": image of the tile
        #"sockets": [top, right, bottom, left]
    #}
    # We will keep a reference to this dictionary so when we recieve a list
    # of tiles we can populate the grid with the correct images
    m_tile_dict = tile_dict
    #clear()

func update_data(sockets:Array, hard_constraint:Array, soft_constraint:Array):
    #This is a list of the form:
    #[
        #{
            #"image": image of the tile
            #"sockets": [top, right, bottom, left]
        #},
        #{
            #"image": image of the tile
            #"sockets": [top, right, bottom, left]
        #},
        #...
    #]
    # We will keep a reference to this dictionary so when we recieve a list
    # of tiles we can populate the grid with the correct images
    clear()
    set_sockets(sockets[0], sockets[1], sockets[2], sockets[3])
    populate_hard_constraint(hard_constraint)
    populate_soft_constraint(soft_constraint)
    queue_redraw()

func clear():
    m_right_socket.text = "---"
    m_left_socket.text = "---"
    m_top_socket.text = "---"
    m_bottom_socket.text = "---"

    for child in m_hard_constraint_grid.get_children():
        child.queue_free()
    for child in m_soft_constraint_grid.get_children():
        child.queue_free()

func set_sockets(top, right, bottom, left):
    m_top_socket.text = str(top)
    m_right_socket.text = str(right)
    m_bottom_socket.text = str(bottom)
    m_left_socket.text = str(left)

func populate_hard_constraint(tiles:Array):
    #Each of these tiles is an image, we need to convert them into ImageTextures and add them to the grid
    for tile in tiles:
        var label = Label.new()
        label.text = str(tile)
        m_hard_constraint_grid.add_child(label)
        var label_sockets = Label.new()
        label_sockets.text = str(m_tile_dict[tile]["sockets"])
        m_hard_constraint_grid.add_child(label_sockets)
        #var t = ImageTexture.create_from_image(m_tile_dict[tile]["image"])
        #m_hard_constraint_grid.add_child(t)

func populate_soft_constraint(tiles:Array):
    #Each of these tiles is an image, we need to convert them into ImageTextures and add them to the grid
    for tile in tiles:
        var texture = ImageTexture.create_from_image(m_tile_dict[tile]["image"])
        m_soft_constraint_grid.add_child(texture)
