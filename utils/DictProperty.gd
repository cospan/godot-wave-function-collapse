extends GridContainer

class_name DebugDictProperty

signal property_changed(property_name, property_value)

var m_widget_dict = {}

func _init(property_dict = null):
    if property_dict != null:
        update_dict(property_dict)

func update_dict(property_dict = {}):
    for key in property_dict:
        if key in m_widget_dict:
            m_widget_dict[key]["label"].queue_free()
            m_widget_dict[key]["widget"].queue_free()
            m_widget_dict.erase(key)

    for key in property_dict:
        var label = Label.new()
        label.text = property_dict[key]["name"]
        add_child(label)
        match property_dict[key]["type"]:
            "Button":
                #print ("Button")
                label.text = ""
                var prop = Button.new()
                prop.text = property_dict[key]["name"]
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("pressed", func() : _property_update(key, true))
            "CheckBox":
                #print ("BOOL")
                var prop = CheckBox.new()
                prop.button_pressed = property_dict[key]["value"]
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("pressed", func() : _property_update(key, prop.button_pressed))
            "OptionButton":
                #print ("OPTION")
                var prop = OptionButton.new()
                for option in property_dict[key]["options"]:
                    prop.add_item(option)
                prop.selected = property_dict[key]["value"]
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("item_selected", func(_val) : _property_update(key, m_widget_dict[key]["widget"].get_item_text(_val)))
            "SpinBox":
                #print("FLOAT")
                if "value" in property_dict[key]:
                    if property_dict[key]["value"] is Vector2 or property_dict[key]["value"] is Vector2i:
                        add_child(add_vector2_spinbox(key, property_dict[key], label))
                        continue
                    elif property_dict[key]["value"] is Vector3 or property_dict[key]["value"] is Vector3i:
                        add_child(add_vector3_spinbox(key, property_dict[key], label))
                        continue
                    else:
                        add_child(add_float_spinbox(key, property_dict[key], label))

            "HSlider":
                #print("FLOAT")
                var prop = HSlider.new()
                prop.custom_minimum_size = Vector2(200, 0) # Set minimum size
                prop.min_value = property_dict[key]["min"]
                prop.max_value = property_dict[key]["max"]
                prop.value = property_dict[key]["value"]
                if "step" in property_dict[key]:
                    prop.step = property_dict[key]["step"]
                else:
                    prop.step = 1.0
                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("value_changed", func(_val) : _property_update(key, _val))
            "LineEdit":
                #print("STRING")
                var prop = LineEdit.new()
                prop.text = property_dict[key]["value"]
                if "readonly" in property_dict[key]:
                    prop.editable = !property_dict[key]["readonly"]

                add_child(prop)
                m_widget_dict[key] = {"type": property_dict[key]["type"], "label": label, "widget": prop}
                prop.connect("text_submitted", func(_val) : _property_update(key, _val))

# Called when the node enters the scene tree for the first time.
func _ready():
    columns = 2

func set_label(n, text):
    m_widget_dict[n]["label"].text = text

func set_value(n, value):
    if !m_widget_dict.has(n):
        print ("No such property: %s" % n)
        return

    match(m_widget_dict[n]["type"]):
        "CheckBox":
            m_widget_dict[n]["widget"].button_pressed = value
        "SpinBox":
            if value is Vector2 or value is Vector2i:
                set_spinbox_vector2_value(n, value)
                return
            elif value is Vector3 or value is Vector3i:
                set_spinbox_vector3_value(n, value)
                return
            else:
                #print ("Name: %s, Value: %s" % [n, value])
                var v:SpinBox = m_widget_dict[n]["widget"]
                if value < v.min_value:
                    v.min_value = value
                if value > v.max_value:
                    v.max_value = value
                v.value = value
        "LineEdit":
            m_widget_dict[n]["widget"].text = value
        "HSlider":
            m_widget_dict[n]["widget"].value = value
        "Button":
            m_widget_dict[n]["widget"].text = value
        "OptionButton":
            m_widget_dict[n]["widget"].selected = value

func _property_update(property_name, property_value):
    property_changed.emit(property_name, property_value)

func set_spinbox_vector2_value(n, value):
    var v:SpinBox = m_widget_dict[n]["widget"].get_child(0)
    if value.x < v.min_value:
        v.min_value = value.x
    if value.x > v.max_value:
        v.max_value = value.x
    v.value = value.x
    v = m_widget_dict[n]["widget"].get_child(1)
    if value.y < v.min_value:
        v.min_value = value.y
    if value.y > v.max_value:
        v.max_value = value.y
    v.value = value.y

func set_spinbox_vector3_value(n, value):
    var v:SpinBox = m_widget_dict[n]["widget"].get_child(0)
    if value.x < v.min_value:
        v.min_value = value.x
    if value.x > v.max_value:
        v.max_value = value.x
    v.value = value.x
    v = m_widget_dict[n]["widget"].get_child(1)
    if value.y < v.min_value:
        v.min_value = value.y
    if value.y > v.max_value:
        v.max_value = value.y
    v.value = value.y
    v = m_widget_dict[n]["widget"].get_child(2)
    if value.z < v.min_value:
        v.min_value = value.z
    if value.z > v.max_value:
        v.max_value = value.z
    v.value = value.z

func add_float_spinbox(key: String, property_dict: Dictionary, label:Label) -> SpinBox:
    var val = property_dict["value"]
    var min_value = -100
    var max_value = 100
    var step = 1.0
    var editable = true

    if "min" in property_dict:
        min_value = property_dict["min"]
    if "max" in property_dict:
        max_value = property_dict["max"]
    if "step" in property_dict:
        step = property_dict["step"]
    if "readonly" in property_dict:
        editable = !property_dict["readonly"]

    var prop = SpinBox.new()
    prop.value = val
    prop.min_value = min_value
    prop.max_value = max_value
    prop.step = step
    prop.editable = editable
    prop.connect("value_changed", func(_val) : _property_update(key, _val))
    m_widget_dict[key] = {"type": property_dict["type"], "label": label, "widget": prop}
    return prop

func add_vector2_spinbox(key: String, property_dict: Dictionary, label:Label) -> HBoxContainer:
    var hbox = HBoxContainer.new()
    hbox.custom_minimum_size = Vector2(200, 0) # Set minimum size

    var val1 = property_dict["value"][0]
    var val2 = property_dict["value"][1]
    var min_value = -100
    var max_value = 100
    var step = 1.0
    var editable = true

    if "min" in property_dict:
        min_value = property_dict["min"]
    if "max" in property_dict:
        max_value = property_dict["max"]
    if "step" in property_dict:
        step = property_dict["step"]
    if "readonly" in property_dict:
        editable = !property_dict["readonly"]

    # Create the first spinbox
    var prop1 = SpinBox.new()
    var prop2 = SpinBox.new()

    prop1.value = val1
    prop1.min_value = min_value
    prop1.max_value = max_value
    prop1.step = step
    prop1.editable = editable
    prop1.connect("value_changed", func(_val) : _property_update(key, [_val, prop2.value]))
    hbox.add_child(prop1)

    # Create the second spinbox
    prop2.value = val2
    prop2.min_value = min_value
    prop2.max_value = max_value
    prop2.step = step
    prop2.editable = editable
    hbox.add_child(prop2)
    prop2.connect("value_changed", func(_val) : _property_update(key, [prop1.value, _val]))
    m_widget_dict[key] = {"type": property_dict["type"], "label": label, "widget": hbox}
    return hbox

func add_vector3_spinbox(key: String, property_dict: Dictionary, label:Label) -> HBoxContainer:
    var hbox = HBoxContainer.new()
    hbox.custom_minimum_size = Vector2(200, 0) # Set minimum size

    var val1 = property_dict["value"][0]
    var val2 = property_dict["value"][1]
    var val3 = property_dict["value"][2]

    var min_value = -100
    var max_value = 100
    var step = 1.0
    var editable = true

    if "min" in property_dict:
        min_value = property_dict["min"]
    if "max" in property_dict:
        max_value = property_dict["max"]
    if "step" in property_dict:
        step = property_dict["step"]
    if "readonly" in property_dict:
        editable = !property_dict["readonly"]

    # Create the first spinbox
    var prop1 = SpinBox.new()
    var prop2 = SpinBox.new()
    var prop3 = SpinBox.new()

    prop1.value = val1
    prop1.min_value = min_value
    prop1.max_value = max_value
    prop1.step = step
    prop1.editable = editable
    prop1.connect("value_changed", func(_val) : _property_update(key, [_val, prop2.value, prop3.value]))
    hbox.add_child(prop1)

    # Create the second spinbox
    prop2.value = val2
    prop2.min_value = min_value
    prop2.max_value = max_value
    prop2.step = step
    prop2.editable = editable
    prop2.connect("value_changed", func(_val) : _property_update(key, [prop1.value, _val, prop3.value]))
    hbox.add_child(prop2)

    # Create the third spinbox
    prop3.value = val3
    prop3.min_value = min_value
    prop3.max_value = max_value
    prop3.step = step
    prop3.editable = editable
    prop3.connect("value_changed", func(_val) : _property_update(key, [prop1.value, prop2.value, _val]))
    hbox.add_child(prop3)
    m_widget_dict[key] = {"type": property_dict["type"], "label": label, "widget": hbox}
    return hbox


