class_name ChildFilter extends Node


## Returns every descendant of [param node] that is an instance of [param type],
## in depth-first order. [param type] may be a native class (Sprite2D), a
## [Script] / [code]class_name[/code], or anything else [method @GDScript.is_instance_of] accepts.
##
## The result is an untyped [Array] because the element type is only known at
## runtime. Callers wanting a typed array should use [method Array.assign]:
## [codeblock]
## var sprites : Array[ Sprite2D ] = []
## sprites.assign( ChildFilter.get_desendants_of_type( self, Sprite2D ) )
## [/codeblock]
static func get_desendants_of_type(node: Node, type: Variant) -> Array:
	var decendants : Array = [ ]
	for child in node.get_children():
		if is_instance_of(child, type):
			decendants.append( child )
		# Keep descending: a match can still have matching children of its own.
		decendants.append_array( get_desendants_of_type(child, type) )

	return decendants
