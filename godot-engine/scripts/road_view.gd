extends Control
## Persistent road presentation. Gameplay remains in VehicleState.
signal encounter_clicked
signal route_chosen(route:String)
var route_buttons:Dictionary={}
var model
var font:Font
var paused:bool=false
var reduced_motion:bool=false
var speed:int=1
var progress:float=0.0
var preview_route:String=""
var last_route:String=""
var age:float=2.0
var scroll:float=0.0
var encounter_rect:Rect2
const PALE=Color("e7e6ce")
const GOLD=Color("e0be7d")
const ROUTE_NAMES={"supply":"路边物资箱","salvage":"破损车辆","tech":"电站遗址","arms":"武装物资车"}

func _ready():
 custom_minimum_size=Vector2(280,320)
 clip_contents=true
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 font=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC"])
 for key in ROUTE_NAMES:
  var sign=Button.new();sign.name="Route_"+key;sign.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  sign.add_theme_font_size_override("font_size",14)
  sign.pressed.connect(func():route_chosen.emit(key))
  add_child(sign);route_buttons[key]=sign
 resized.connect(sync_routes)
 sync_routes()

func _process(delta:float):
 if not paused:age+=delta*speed
 if model!=null and not paused and not reduced_motion and model.phase in ["travel","combat"]:
  scroll=fmod(scroll+delta*speed*(90 if model.phase=="travel" else 20),1200)
 queue_redraw()

func choosing_route()->bool:
 return model!=null and model.editable() and not model.explored

func route_rect(index:int)->Rect2:
 var sign_height:float=clampf((size.y*0.65-70)/2,64,90)
 var sign_width:float=(size.x-36)/2
 return Rect2(Vector2(12+(index%2)*(sign_width+12),52+(index/2)*(sign_height+16)),Vector2(sign_width,sign_height))

func sync_routes():
 var summaries={"supply":"水 / 粮 / 油","salvage":"金属 / 布料 / 弹药","tech":"元件 / 能源图纸","arms":"弹药 / 修理包"}
 var i:int=0
 for key in route_buttons:
  var sign:Button=route_buttons[key]
  sign.visible=choosing_route()
  var rect:Rect2=route_rect(i);sign.position=rect.position;sign.size=rect.size;i+=1
  var selected:bool=preview_route==key
  var risk:String="安全" if key=="supply" and model.day<15 else "强敌" if key=="arms" else "战斗"
  sign.text=("✓ " if selected else "")+ROUTE_NAMES[key]+"\n"+summaries[key]+" · "+risk
  sign.tooltip_text=model.ROUTES[key].hint+"\n点击选择，在道路下方确认出发"
  for state in ["normal","hover","pressed","focus"]:
   var style=StyleBoxFlat.new();style.bg_color=Color("3f5140") if selected or state=="hover" else Color("1c3127")
   style.border_color=GOLD if selected or state=="focus" else Color("71836b");style.set_border_width_all(2 if selected else 1);style.set_corner_radius_all(7)
   sign.add_theme_stylebox_override(state,style)
  sign.add_theme_color_override("font_color",GOLD if selected else PALE)
 queue_redraw()

func pulse():age=0;queue_redraw()
func _gui_input(event:InputEvent):
 if not choosing_route() and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and encounter_rect.has_point(event.position):
  encounter_clicked.emit();accept_event()

func plate(r:Rect2,c:Color,radius:int=6,border:Color=Color.TRANSPARENT):
 var s=StyleBoxFlat.new();s.bg_color=c;s.set_corner_radius_all(radius)
 if border.a>0:s.border_color=border;s.set_border_width_all(1)
 draw_style_box(s,r)
func word(at:Vector2,text:String,fs:int=14,c:Color=PALE,width:float=-1):
 draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,width,fs,c)
func tag(at:Vector2,text:String,c:Color=GOLD):
 var w:float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+22
 plate(Rect2(at-Vector2(w/2,23),Vector2(w,31)),Color("14231e"),5,c.darkened(0.45))
 word(at+Vector2(-w/2+11,-2),text,14,c)
func bar(at:Vector2,w:float,ratio:float,c:Color):
 plate(Rect2(at,Vector2(w,5)),Color("101c18"),2)
 plate(Rect2(at,Vector2(w*clampf(ratio,0,1),5)),c,2)

func vehicle(at:Vector2,scale_value:float=1.0,hostile:bool=false,wreck:bool=false):
 var s:float=scale_value
 var r=Rect2(at-Vector2(28,49)*s,Vector2(56,98)*s)
 var body_color=Color("8c6350") if hostile else Color("819081")
 if wreck:body_color=Color("5c6558")
 plate(Rect2(r.position+Vector2(5,7)*s,r.size),Color(0,0,0,0.3),9)
 for y in [-29,26]:
  for x in [-32,26]:plate(Rect2(at+Vector2(x,y)*s,Vector2(6,21)*s),Color("121a18"),2)
 plate(r,body_color,10,body_color.lightened(0.15))
 plate(Rect2(at+Vector2(-23,-44)*s,Vector2(46,18)*s),Color("283e3d"),5)
 draw_line(at+Vector2(-19,-40)*s,at+Vector2(17,-40)*s,Color("7eaaa3"),2)
 plate(Rect2(at+Vector2(-21,-20)*s,Vector2(42,55)*s),body_color.darkened(0.12),4)
 draw_line(at+Vector2(-18,29)*s,at+Vector2(18,29)*s,body_color.darkened(0.35),2)
 for x in [-20,15]:
  draw_rect(Rect2(at+Vector2(x,-49)*s,Vector2(5,4)*s),GOLD)
  draw_rect(Rect2(at+Vector2(x,45)*s,Vector2(5,4)*s),Color("bb7356"))
 if hostile:
  draw_circle(at,10*s,Color("303d36"));draw_line(at,at+Vector2(0,28)*s,Color("a3a28a"),5)
 if wreck:
  draw_line(at+Vector2(-17,-15)*s,at+Vector2(15,12)*s,Color("343b31"),3)
  draw_line(at+Vector2(-13,28)*s,at+Vector2(11,8)*s,Color("343b31"),2)

func crate(at:Vector2,opened:bool=false):
 plate(Rect2(at-Vector2(25,19)+Vector2(5,5),Vector2(50,38)),Color(0,0,0,0.35),4)
 plate(Rect2(at-Vector2(25,19),Vector2(50,38)),Color("8d7447"),4,GOLD)
 for x in [-16,12]:draw_rect(Rect2(at+Vector2(x,-18),Vector2(5,36)),Color("c9ad70"))
 draw_line(at+Vector2(-25,-8),at+Vector2(25,-8),Color("493e2a"),2)
 if opened:plate(Rect2(at+Vector2(-23,-34),Vector2(46,16)),Color("a08657"),3)
 else:draw_rect(Rect2(at-Vector2(4,5),Vector2(8,10)),PALE)

func beast(at:Vector2,alive:bool):
 var c=Color("b89069") if alive else Color("5c6558")
 draw_circle(at+Vector2(4,7),27,Color(0,0,0,0.2))
 draw_colored_polygon(PackedVector2Array([at+Vector2(-14,-30),at+Vector2(12,-24),at+Vector2(21,3),at+Vector2(11,23),at+Vector2(-5,30),at+Vector2(-20,12)]),c)
 for x in [-1,1]:
  draw_line(at+Vector2(x*12,-10),at+Vector2(x*29,4),c.darkened(0.1),7)
  draw_line(at+Vector2(x*10,15),at+Vector2(x*23,31),c.darkened(0.2),7)
  draw_circle(at+Vector2(x*5,19),2,Color("ffe2a0"))

func _draw():
 if model==null or font==null:return
 var w:float=size.x;var h:float=size.y
 var hot:bool=model.day>=15
 draw_rect(Rect2(Vector2.ZERO,size),Color("56543b") if hot else Color("3a493b"))
 # Sparse deterministic roadside scenery; only the world scrolls, never the HUD.
 for i in range(42):
  var x:float=fmod(i*79.3,w)
  if x>w*0.25 and x<w*0.71:continue
  var y:float=fmod(i*113.7+scroll,h+80)-40
  var r:float=3+fmod(i*5.7,8)
  draw_circle(Vector2(x+3,y+4),r,Color(0,0,0,0.1))
  draw_circle(Vector2(x,y),r,Color("66634b") if i%3==0 else Color("4d6049"))
  if i%4==0:
   draw_line(Vector2(x,y+9),Vector2(x,y-10),Color("293b2c"),2)
   draw_line(Vector2(x,y),Vector2(x-5,y-5),Color("8a8b62"),2)
 var cx:float=w*0.47;var rw:float=w*0.39
 # An upcoming branch is a route-selection cue, not an unimplemented service shop.
 var fork=PackedVector2Array([Vector2(cx+rw*0.4,h*0.3),Vector2(w*0.79,h*0.13),Vector2(w+15,h*0.08)])
 draw_polyline(fork,Color("666857"),rw*0.42,true)
 draw_polyline(fork,Color("303a35"),rw*0.34,true)
 draw_rect(Rect2(cx-rw/2-9,0,rw+18,h),Color("747661"))
 draw_rect(Rect2(cx-rw/2,0,rw,h),Color("303a35"))
 for x in [cx-rw/2+6,cx+rw/2-6]:draw_line(Vector2(x,0),Vector2(x,h),Color("8b8d72"),2)
 for i in range(-1,int(h/70)+2):
  var y:float=i*70+fmod(scroll,70)
  draw_line(Vector2(cx,y),Vector2(cx,y+28),Color("aaa68a"),3)
 for i in range(14):
  var y:float=fmod(i*79+scroll,h+50)-25
  var x:float=cx+sin(i*4.1)*rw*0.32
  draw_polyline(PackedVector2Array([Vector2(x,y),Vector2(x+8,y+9),Vector2(x+3,y+17)]),Color("252f2b"),1)
 for x in [cx-rw/2-16,cx+rw/2+16]:
  draw_line(Vector2(x,0),Vector2(x,h),Color("687260"),2)
  for i in range(-1,int(h/70)+2):draw_circle(Vector2(x,i*70+fmod(scroll,70)),2,Color("aaa98c"))
 var active:String=preview_route if not preview_route.is_empty() and not model.explored else last_route
 var route_name:String=ROUTE_NAMES.get(active,"前方岔路")
 var event_y:float=h*0.33
 if model.phase=="travel":event_y=lerpf(h*0.1,h*0.34,progress)
 var ep=Vector2(cx,event_y)
 var pp=Vector2(cx,h*(0.81 if choosing_route() else 0.77))
 encounter_rect=Rect2(ep-Vector2(75,60),Vector2(150,120))
 if choosing_route():
  for index in range(route_buttons.size()):
   var rect:Rect2=route_rect(index)
   var path=PackedVector2Array([pp-Vector2(0,50),Vector2(cx,rect.end.y+17),Vector2(rect.get_center().x,rect.end.y)])
   var selected:bool=preview_route==route_buttons.keys()[index]
   draw_polyline(path,Color("7e886a") if selected else Color("4e604d"),5 if selected else 3,true)
 elif model.phase=="combat" and not model.combat.is_empty():
  var enemies:Array=model.combat.enemies
  for i in range(enemies.size()):
   var e:Dictionary=enemies[i];var p=ep+Vector2(i*66,0)
   if model.combat.kind=="heavy":vehicle(p,0.76,true,e.hp<=0)
   else:beast(p,e.hp>0)
   tag(p-Vector2(0,54),e.name,Color("e5b298"))
   bar(p+Vector2(-42,43),84,float(e.hp)/e.max_hp,Color("d79170"))
   word(p+Vector2(-28,64),"%d / %d"%[e.hp,e.max_hp],13)
 elif not active.is_empty():
  if active=="salvage" or active=="arms":vehicle(ep,0.68,active=="arms",active=="salvage")
  elif active=="tech":
   plate(Rect2(ep-Vector2(32,29),Vector2(64,58)),Color("657069"),3)
   for x in [-18,10]:plate(Rect2(ep+Vector2(x,-22),Vector2(12,41)),Color("283b35"),2)
  else:crate(ep,model.explored and model.phase=="stop")
  tag(ep-Vector2(0,57),route_name)
 else:
  tag(Vector2(cx,h*0.28),"选择路线后出发")
  draw_line(Vector2(cx,h*0.38),Vector2(cx,h*0.34),GOLD,2)
  draw_polyline(PackedVector2Array([Vector2(cx-6,h*0.35),Vector2(cx,h*0.34),Vector2(cx+6,h*0.35)]),GOLD,2)
 if not choosing_route():tag(Vector2(w*0.80,h*0.11),"岔路",Color("bac9a9"))
 vehicle(pp,0.75 if choosing_route() else 0.9)
 bar(pp+Vector2(-34,55),68,float(model.hull)/model.max_hull,Color("99bd91"))
 if model.phase=="combat" and age<0.65:
  for effect in model.effects:
   if effect.type=="shot":
    var start=pp-Vector2(0,43);var end=ep+Vector2(0,24)
    draw_line(start,end,Color("8b805c"),1)
    draw_circle(start.lerp(end,minf(age/0.25,1)),4,GOLD)
    word(ep+Vector2(36,-6),"−%d"%effect.damage,22,GOLD)
   elif effect.type=="hit":
    draw_line(ep+Vector2(0,30),pp-Vector2(0,40),Color("da8b71"),2)
    if effect.blocked>0:draw_arc(pp,53,PI,TAU,24,Color("89c1c2"),3)
    if effect.damage>0:word(pp+Vector2(38,0),"−%d"%effect.damage,22,Color("f0a18a"))
   elif effect.type=="dry":tag(pp-Vector2(0,69),"缺弹 · 应急撞击",Color("e5a28a"))
   elif effect.type=="ram":tag(pp-Vector2(0,69),"撞击 · 车体−2",Color("e5a28a"))
 var status:String="点击前方路牌选择目的地" if choosing_route() else "停靠整备 · 不消耗时间"
 if model.phase=="travel":status="行进中 · %d%%"%int(progress*100)
 elif model.phase=="encounter":status="已抵达 · 点击物资箱"
 elif model.phase=="combat":status="自动作战 · 第%d拍"%model.combat.tick
 elif model.phase=="ended":status="本次旅程结束"
 elif model.explored:status="已停靠 · 整理战利品"
 if paused and model.phase in ["travel","combat"]:status="已暂停 · Space 继续"
 plate(Rect2(8,8,w-16,34),Color("182820"),6)
 word(Vector2(20,31),status,14,GOLD,w-40)
 if hot:
  for i in range(3):draw_circle(Vector2(22+i*19,h-22),6,Color("e4a762"))
  word(Vector2(81,h-17),"三日凌空 · 暴晒",13,GOLD)
 else:word(Vector2(14,h-17),"↑ 前进方向",13,Color("c1c9ac"))
