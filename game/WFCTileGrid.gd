extends GridContainer

var rows:int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.


func configure_grid(width: int, height: int):
    columns = width
    rows = height
    for i in range(width):
        for j in range(height):
            var tile = WFCTile.new()
            self.add_child(tile)

func set_tile(tile_x:int, tile_y:int, image, entropy):
    var pos = columns * tile_y + tile_x
    if entropy == 0:
        self.children[pos].set_image(image)
    else:
        self.children[pos].set_entropy(entropy)
