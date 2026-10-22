extends Control
signal item_selected(id:int)
signal placement_requested(id:int,floor_id:int,position:Vector2i,rotated:bool)
signal canceled
const Symbols=preload("res://scripts/item_symbols.gd")
var model
var selected_id:int=-1
var rotated:bool=false
var moving:bool=false
var dragging:bool=false
var cell:float=72.0
var origin=Vector2.ZERO
var hover=Vector2i(-1,-1)
var font:Font
var highlighted:Array=[]

func _ready():
 mouse_filter=Control.MOUSE_FILTER_STOP
 custom_minimum_size=Vector2(280,384)
 font=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC"])
 mouse_exited.connect(func():hover=Vector2i(-1,-1);queue_redraw())
 resized.connect(queue_redraw)

func screen_cell(p:Vector2)->Vector2i:
 var visual:Vector2i=Vector2i(floor((p.x-origin.x)/cell),floor((p.y-origin.y)/cell))
 return visual

func cell_center(p:Vector2i)->Vector2:
 return origin+Vector2(p.x+0.5,p.y+0.5)*cell

func item_at(p:Vector2i)->int:
 for item in model.items:
  if item.floor==0 and Rect2i(item.pos,model.footprint(item)).has_point(p):return item.id
 return -1

func _gui_input(event:InputEvent):
 if model==null:return
 if event is InputEventMouseMotion:
  hover=screen_cell(event.position)
  var id:int=item_at(hover)
  if id>=0:
   var item:Dictionary=model.item_by_id(id)
   var footprint:Vector2i=model.footprint(item)
   tooltip_text="%s · %d×%d格\n点击查看 · 拖动整理"%[model.CATALOG[item.kind].name,footprint.x,footprint.y]
   if item.kind in ["driver","seat"]:tooltip_text+="\n"+("空座" if model.seat_occupant(id).is_empty() else model.seat_occupant(id)+" · 已入座")
   if item.kind=="bed":tooltip_text+="\n1人床 · "+("空闲" if model.bed_occupant(id).is_empty() else model.bed_occupant(id)+"夜间使用")
  else:tooltip_text=""
  queue_redraw()
 if not model.editable():return
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_RIGHT:canceled.emit();accept_event();return
  if event.button_index!=MOUSE_BUTTON_LEFT:return
  var p:Vector2i=screen_cell(event.position)
  if moving and selected_id>=0:placement_requested.emit(selected_id,0,p,rotated)
  else:
   var id:int=item_at(p)
   if id>=0:item_selected.emit(id)
   else:canceled.emit()
  accept_event()

func box(color:Color,radius:int=7)->StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius);return s

func visual_rect(p:Vector2i,s:Vector2i)->Rect2:
 return Rect2(origin+Vector2(p.x,p.y)*cell,Vector2(s.x,s.y)*cell-Vector2(4,4))

func _draw():
 if model==null or font==null:return
 cell=minf(78,minf((size.x-74)/model.width,(size.y-90)/model.height))
 origin=Vector2((size.x-model.width*cell)/2,52)
 var body=Rect2(origin-Vector2(16,40),Vector2(model.width*cell+28,model.height*cell+55))
 draw_style_box(box(Color("0d1713"),22),Rect2(body.position+Vector2(6,7),body.size))
 draw_style_box(box(Color("57695a"),22),body)
 draw_style_box(box(Color("283c34"),12),body.grow(-6))
 # Windshield, mirrors and wheels establish the upright vehicle silhouette.
 draw_style_box(box(Color("72958c"),8),Rect2(origin+Vector2(5,-30),Vector2(model.width*cell-14,22)))
 draw_line(origin+Vector2(model.width*cell/2,-28),origin+Vector2(model.width*cell/2,-10),Color("364d42"),3)
 for x in [body.position.x-8,body.end.x-1]:
  for y in [origin.y+cell*0.6,origin.y+cell*(model.height-1.3)]:
   draw_style_box(box(Color("09130f"),4),Rect2(Vector2(x,y),Vector2(9,cell*0.9)))
 for x in [origin.x,origin.x+model.width*cell-14]:
  draw_style_box(box(Color("bd7d5b"),3),Rect2(Vector2(x,body.end.y-10),Vector2(10,5)))
 for y in range(model.height):
  for x in range(model.width):
   draw_style_box(box(Color("1c2d2b") if y<2 else Color("233531"),4),visual_rect(Vector2i(x,y),Vector2i.ONE))
 for item in model.items:
  if item.floor!=0:continue
  var r:Rect2=visual_rect(item.pos,model.footprint(item))
  var color=Color(model.CATALOG[item.kind].color)
  draw_style_box(box(color.darkened(0.45)),r.grow(-1))
  draw_rect(Rect2(r.position+Vector2(2,5),Vector2(3,r.size.y-10)),color)
  if selected_id==item.id:draw_rect(r.grow(-1),Color("ddc08c"),false,2)
  if item.id in highlighted:draw_rect(r.grow(-1),Color("ffe6ac"),false,3)
  var compact:bool=model.footprint(item)==Vector2i.ONE
  if compact:
   var occupant:String=model.seat_occupant(item.id)
   var mark:String="person" if not occupant.is_empty() else item.kind
   Symbols.paint(self,mark,Rect2(r.get_center().x-10,r.position.y+7,20,20),Color("e5c790") if not occupant.is_empty() else Color("a2b6ac"))
   var caption:String=occupant if not occupant.is_empty() else "空座"
   draw_string(font,Vector2(r.position.x+4,r.end.y-7),caption,HORIZONTAL_ALIGNMENT_CENTER,r.size.x-8,12,Color("edf0e7"))
   continue
  var wide:bool=model.footprint(item).y==1 and model.footprint(item).x>=2
  var icon_rect:Rect2=Rect2(r.position+Vector2(13,(r.size.y-30)/2),Vector2(30,30)) if wide else Rect2(Vector2(r.get_center().x-14,r.position.y+10),Vector2(28,28))
  Symbols.paint(self,item.kind,icon_rect,Color("d5dfd5"))
  var title:String=model.CATALOG[item.kind].name
  var text_pos:Vector2=r.position+Vector2(53,r.size.y/2+4) if wide else Vector2(r.position.x+6,r.position.y+58)
  var available:float=r.size.x-(59 if wide else 12)
  var fs:int=14 if available>=title.length()*14 else 12
  draw_string(font,text_pos,title,HORIZONTAL_ALIGNMENT_LEFT,available,fs,Color("edf0e7"))
  if model.CATALOG[item.kind].has("max"):
   var value:String=str(item.amount)
   draw_string(font,r.end-Vector2(value.length()*9+8,7),value,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f4d99d"))
 if (moving or dragging) and selected_id>=0 and hover.x>=0 and hover.y>=0:
  var candidate:Dictionary=model.item_by_id(selected_id).duplicate()
  if not candidate.is_empty():
   candidate.rotated=rotated
   var valid:bool=model.placement_error(candidate,0,hover).is_empty()
   var other_id:int=item_at(hover)
   if other_id>=0 and other_id!=selected_id:
    var other:Dictionary=model.item_by_id(other_id)
    if other.kind==candidate.kind and model.CATALOG[candidate.kind].has("max") and other.amount<model.CATALOG[candidate.kind].max:valid=true
   var r:Rect2=visual_rect(hover,model.footprint(candidate))
   draw_rect(r,Color(0.45,0.85,0.68,0.25) if valid else Color(1,0.3,0.3,0.22))
   draw_rect(r,Color("92d8b6") if valid else Color("df8b76"),false,2)
 draw_string(font,Vector2(origin.x,origin.y+model.height*cell+37),"车内一层 · %d / %d格"%[model.used_cells(),model.width*model.height],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("a2b3a3"))
