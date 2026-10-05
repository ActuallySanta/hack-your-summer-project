@abstract
class_name TextSelection extends TextElement

var current : Array = []
var items : Array[ String ]
var label : String

@abstract
func make_selection(culled_input: int) -> String
