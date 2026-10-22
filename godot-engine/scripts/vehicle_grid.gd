extends Control
signal item_selected(id:int)
signal placement_requested(id:int, floor_id:int, position:Vector2i, rotated:bool)
signal canceled
var model
var selected_id:int=-1
var rotated:bool=false
var cell:float=58.0
var origin=Vector2(35,45)
var hover=Vector2i(-1,-1)
var font:Font

func _ready():
 mouse_filter=Control.MOUSE_FILTER_STOP
 custom_minimum_size=Vector2(470,560)
 font=SystemFont.new()
 font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC"])
 mouse_exited.connect(func(): hover=Vector2i(-1,-1);queue_redraw())

func _gui_input(event:InputEvent):
 if model==null:return
 if event is InputEventMouseMotion:
  hover=Vector2i(floor((event.position.x-origin.x)/cell),floor((event.position.y-origin.y)/cell));queue_redraw()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_RIGHT:canceled.emit();accept_event();return
  if event.button_index!=MOUSE_BUTTON_LEFT:return
  var p=Vector2i(floor((event.position.x-origin.x)/cell),floor((event.position.y-origin.y)/cell))
  if selected_id>=0:
   placement_requested.emit(selected_id,model.floor_index,p,rotated)
  else:
   for item in model.items:
    if item.floor==model.floor_index and Rect2i(item.pos,model.footprint(item)).has_point(p):
     item_selected.emit(item.id);break
  accept_event()

func _draw():
 if model==null:return
 draw_string(font,Vector2(35,27),"%s  ·  %d × %d"%[["车内一层","车内二层","车顶"][model.floor_index],model.width,model.height],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("d6e0e5"))
 if not model.floor_unlocked(model.floor_index):
  draw_string(font,Vector2(35,100),"升级车辆以解锁这一层",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("b9a56b"));return
 for y in range(model.height):
  for x in range(model.width):
   var r=Rect2(origin+Vector2(x,y)*cell,Vector2.ONE*(cell-3))
   var trunk:bool=model.floor_index==0 and y>=model.height-2
   draw_style_box(box(Color("263641") if trunk else Color("1c2935")),r)
 if model.floor_index==0:
  draw_string(font,origin+Vector2(0,(model.height+0.45)*cell),"后两排为后备箱标识区 · 当前不限制设备放置",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8a9ba8"))
 for item in model.items:
  if item.floor!=model.floor_index:continue
  var s:Vector2i=model.footprint(item)
  var r=Rect2(origin+Vector2(item.pos)*cell,Vector2(s)*cell-Vector2(3,3))
  var c=Color(model.CATALOG[item.kind].color)
  if selected_id==item.id:c=c.darkened(0.45)
  draw_style_box(box(c),r.grow(-2))
  var title:String=model.CATALOG[item.kind].name
  for k in range(title.length()):
   var row:int=k/3
   var col:int=k%3
   if s.x==1:row=k;col=0
   draw_string(font,r.position+Vector2(8+col*17,25+row*21),title[k],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
 if selected_id>=0 and hover.x>=0 and hover.y>=0:
  var item=model.item_by_id(selected_id).duplicate()
  if item.is_empty():return
  item.rotated=rotated
  var valid:bool=model.placement_error(item,model.floor_index,hover).is_empty()
  var r=Rect2(origin+Vector2(hover)*cell,Vector2(model.footprint(item))*cell-Vector2(3,3))
  draw_rect(r,Color(0.4,0.9,0.75,0.35) if valid else Color(1,0.3,0.3,0.35))
  draw_rect(r,Color("8be6bd") if valid else Color("f08282"),false,2)

func box(color:Color)->StyleBoxFlat:
 var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(5);return b
