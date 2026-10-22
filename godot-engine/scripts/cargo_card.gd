extends Button
const Symbols=preload("res://scripts/item_symbols.gd")
var model
var item_id:int=-1
func _ready():
 custom_minimum_size=Vector2(156,78)
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _draw():
 var item:Dictionary=model.item_by_id(item_id)
 if item.is_empty():return
 var font:Font=get_theme_default_font()
 Symbols.paint(self,item.kind,Rect2(10,15,30,30))
 draw_string(font,Vector2(48,30),model.CATALOG[item.kind].name,HORIZONTAL_ALIGNMENT_LEFT,100,15,Color("e4e9df"))
 var footprint:Vector2i=model.footprint(item)
 draw_string(font,Vector2(48,53),"%d格%s"%[footprint.x*footprint.y,"  ×%d"%item.amount if model.CATALOG[item.kind].has("max") else ""],HORIZONTAL_ALIGNMENT_LEFT,100,13,Color("a4b7a8"))
