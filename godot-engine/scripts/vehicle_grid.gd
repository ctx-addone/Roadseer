extends Control
signal item_selected(id:int)
signal placement_requested(id:int, floor_id:int, position:Vector2i, rotated:bool)
signal canceled
var model
var selected_id:int=-1
var rotated:bool=false
var cell:float=52.0
var origin=Vector2(35,32)
var hover=Vector2i(-1,-1)
var font:Font
var highlighted:Array=[]

func _ready():
 mouse_filter=Control.MOUSE_FILTER_STOP
 custom_minimum_size=Vector2(310,460)
 font=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC"])
 mouse_exited.connect(func():hover=Vector2i(-1,-1);queue_redraw())
 resized.connect(queue_redraw)

func _gui_input(event:InputEvent):
 if model==null or not model.editable():return
 if event is InputEventMouseMotion:
  hover=Vector2i(floor((event.position.x-origin.x)/cell),floor((event.position.y-origin.y)/cell));queue_redraw()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_RIGHT:canceled.emit();accept_event();return
  if event.button_index!=MOUSE_BUTTON_LEFT:return
  var p=Vector2i(floor((event.position.x-origin.x)/cell),floor((event.position.y-origin.y)/cell))
  if selected_id>=0:placement_requested.emit(selected_id,0,p,rotated)
  else:
   for item in model.items:
    if item.floor==0 and Rect2i(item.pos,model.footprint(item)).has_point(p):item_selected.emit(item.id);break
  accept_event()

func _draw():
 if model==null or font==null:return
 cell=minf(57,minf((size.x-34)/model.width,(size.y-60)/model.height))
 origin=Vector2((size.x-model.width*cell)/2,30)
 draw_string(font,Vector2(origin.x,19),"车头 ↑   %d × %d    占用 %d/%d格"%[model.width,model.height,model.used_cells(),model.width*model.height],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b9ccda"))
 for y in range(model.height):
  for x in range(model.width):
   var r=Rect2(origin+Vector2(x,y)*cell,Vector2.ONE*(cell-3))
   draw_style_box(box(Color("25343c") if y>=model.height-2 else Color("1c2b35")),r)
   draw_string(font,r.position+Vector2(4,13),"%d"%(y*model.width+x+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("526572"))
 for item in model.items:
  if item.floor!=0:continue
  var s:Vector2i=model.footprint(item)
  var r=Rect2(origin+Vector2(item.pos)*cell,Vector2(s)*cell-Vector2(3,3))
  var c=Color(model.CATALOG[item.kind].color)
  if selected_id==item.id:c=c.darkened(0.35)
  draw_style_box(box(c),r.grow(-2))
  if item.id in highlighted:draw_rect(r.grow(-1),Color("ffdc91"),false,3)
  var title:String=model.CATALOG[item.kind].name
  var cols:int=1 if s.x==1 else 4
  for k in range(title.length()):
   draw_string(font,r.position+Vector2(8+(k%cols)*17,23+(k/cols)*20),title[k],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f4f6ef"))
  if model.CATALOG[item.kind].has("max"):
   draw_string(font,r.end-Vector2(43,10),"%d/%d"%[item.amount,model.CATALOG[item.kind].max],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffffff"))
  elif model.CATALOG[item.kind].get("fixed",false):
   draw_string(font,r.end-Vector2(32,10),"保留",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c4d1da"))
 if selected_id>=0 and hover.x>=0 and hover.y>=0:
  var item=model.item_by_id(selected_id).duplicate()
  if item.is_empty():return
  item.rotated=rotated
  var valid:bool=model.placement_error(item,0,hover).is_empty()
  var merge_possible:bool=false
  for other in model.items:
   if other.id!=item.id and other.floor==0 and other.kind==item.kind and model.CATALOG[item.kind].has("max") and other.amount<model.CATALOG[item.kind].max and Rect2i(other.pos,model.footprint(other)).has_point(hover):merge_possible=true
  var r=Rect2(origin+Vector2(hover)*cell,Vector2(model.footprint(item))*cell-Vector2(3,3))
  draw_rect(r,Color(0.4,0.9,0.75,0.3) if valid or merge_possible else Color(1,0.3,0.3,0.3))
  draw_rect(r,Color("8be6bd") if valid or merge_possible else Color("f08282"),false,2)
 if not model.editable():
  draw_string(font,origin+Vector2(0,model.height*cell+20),"战斗锁定布局" if model.phase=="combat" else "本局已结算",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e6c079"))

func box(color:Color)->StyleBoxFlat:
 var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(5);return b
