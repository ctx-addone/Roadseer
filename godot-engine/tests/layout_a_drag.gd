extends SceneTree
var app
var failures:int=0
func check(ok:bool,why:String):
 if not ok:failures+=1;push_error(why)
func _initialize():call_deferred("run")
func find_button(node:Node,prefix:String):
 if node is Button and node.text.begins_with(prefix) and node.is_visible_in_tree():return node
 for child in node.get_children():
  var found=find_button(child,prefix)
  if found!=null:return found
 return null
func click_at(point:Vector2):
 var input_viewport=app.discard_dialog if app!=null and app.discard_dialog.visible else root
 var motion=InputEventMouseMotion.new();motion.position=point;input_viewport.push_input(motion,true)
 var down=InputEventMouseButton.new();down.position=point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;input_viewport.push_input(down,true)
 var up=InputEventMouseButton.new();up.position=point;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;input_viewport.push_input(up,true)
 await process_frame;await process_frame
func click(prefix:String):
 await process_frame;await process_frame
 await process_frame
 var target=find_button(app,prefix)
 check(target!=null,"button exists: "+prefix)
 if target==null:return
 var parent=target.get_parent()
 while parent!=null:
  if parent is ScrollContainer:parent.ensure_control_visible(target)
  parent=parent.get_parent()
 await process_frame;await process_frame
 await process_frame
 print("CLICK ",prefix," ",target.get_global_rect()," window ",root.size," final ",root.get_final_transform())
 await click_at(target.get_global_rect().get_center())
func key(code:int):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true)
 await process_frame
 event=InputEventKey.new();event.keycode=code;event.pressed=false;root.push_input(event,true)
 await process_frame
func grid_click(x:int,y:int):
 await click_at(app.grid.global_position+app.grid.cell_center(Vector2i(x,y)))
func capture(_name:String):
 await process_frame
func tile_for(node:Node,id:int):
 if node.get_script()==load("res://scripts/cargo_card.gd") and node.item_id==id:return node
 for child in node.get_children():
  var found=tile_for(child,id)
  if found!=null:return found
 return null
func click_tile(id:int):
 await process_frame;await process_frame;await process_frame
 var tile=tile_for(app,id);check(tile!=null,"tile exists")
 if tile==null:return
 var parent=tile.get_parent()
 while parent!=null:
  if parent is ScrollContainer:parent.ensure_control_visible(tile)
  parent=parent.get_parent()
 await process_frame;await process_frame
 await click_at(tile.get_global_rect().get_center())
func drag(from:Vector2,to:Vector2):
 var motion=InputEventMouseMotion.new();motion.position=from;root.push_input(motion,true)
 var press=InputEventMouseButton.new();press.position=from;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true)
 await process_frame
 var previous:Vector2=from
 for step in range(1,9):
  var point:Vector2=from.lerp(to,step/8.0)
  motion=InputEventMouseMotion.new();motion.position=point;motion.relative=point-previous;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
  previous=point;await process_frame
 var release=InputEventMouseButton.new();release.position=to;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;root.push_input(release,true)
 await process_frame;await process_frame
func run():
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 await process_frame;await process_frame;await process_frame
 var source:Vector2=app.grid.global_position+app.grid.cell_center(Vector2i(0,2))
 var target:Vector2=app.grid.global_position+app.grid.cell_center(Vector2i(3,4))
 await drag(source,target)
 check(app.model.item_by_id(5).pos==Vector2i(3,4),"drag installed weapon to empty cells")
 # A failed drop must keep the original object at its prior location.
 source=app.grid.global_position+app.grid.cell_center(Vector2i(3,4))
 target=app.grid.global_position+app.grid.cell_center(Vector2i(0,0))
 await drag(source,target)
 check(app.model.item_by_id(5).pos==Vector2i(3,4),"invalid drag preserves item")
 app.model.drop(5);app.refresh()
 await process_frame;await process_frame;await process_frame
 var tile=tile_for(app,5)
 check(tile!=null,"ground card for dragged cargo")
 source=tile.get_global_rect().get_center()
 target=app.grid.global_position+app.grid.cell_center(Vector2i(0,2))
 await drag(source,target)
 check(app.model.item_by_id(5).floor==0 and app.model.item_by_id(5).pos==Vector2i(0,2),"drag ground cargo onto vehicle")
 check(not app.ground_box.visible,"empty cargo tray collapses")
 await capture("drag-finished")
 # Drag from the second occupied cell preserves the grab offset.
 source=app.grid.global_position+app.grid.cell_center(Vector2i(0,3))
 target=app.grid.global_position+app.grid.cell_center(Vector2i(3,5))
 await drag(source,target)
 check(app.model.item_by_id(5).pos==Vector2i(3,4),"grab offset preserved")
 source=app.grid.global_position+app.grid.cell_center(Vector2i(3,4))
 var motion=InputEventMouseMotion.new();motion.position=source;root.push_input(motion,true)
 var press=InputEventMouseButton.new();press.position=source;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true)
 motion=InputEventMouseMotion.new();motion.position=source+Vector2(-40,-40);motion.relative=Vector2(-40,-40);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
 await process_frame
 check(app.drag_id==5,"cancel scenario entered drag")
 await key(KEY_ESCAPE)
 check(app.drag_id==-1 and app.model.item_by_id(5).pos==Vector2i(3,4),"Escape cancels drag without moving")
 var release=InputEventMouseButton.new();release.position=source;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;root.push_input(release,true)
 # A scroll viewport must accept visible rear-cell drops and reject clipped cells.
 app.model.height=10;app.model.expansion_level=2;app.model.drop(5);app.model.add_item("cloth",1);app.clear_selection();app.refresh()
 await process_frame;await process_frame
 app.grid_scroll.scroll_vertical=10000
 await process_frame;await process_frame
 tile=tile_for(app,5)
 source=tile.get_global_rect().get_center()
 target=app.grid.global_position+app.grid.cell_center(Vector2i(3,8))
 check(app.grid_scroll.get_global_rect().has_point(target),"rear destination visible after scroll")
 await drag(source,target)
 check(app.model.item_by_id(5).floor==0 and app.model.item_by_id(5).pos==Vector2i(3,8),"ground cargo drags into scrolled rear cells")
 app.grid_scroll.scroll_vertical=10000
 await process_frame;await process_frame
 source=app.grid.global_position+app.grid.cell_center(Vector2i(3,8))
 target=app.grid.global_position+app.grid.cell_center(Vector2i(2,0))
 check(not app.grid_scroll.get_global_rect().has_point(target),"clipped front cell outside viewport")
 await drag(source,target)
 check(app.model.item_by_id(5).pos==Vector2i(3,8),"drop on clipped front cell cancels rather than moving")
 print("DRAG VERIFICATION failures=",failures)
 quit(1 if failures else 0)
