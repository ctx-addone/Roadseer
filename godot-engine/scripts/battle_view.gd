extends Control
## Engine-rendered combat feedback, independent from the fixed-step simulation.
var model
var font:Font
var age:float=2.0

func _ready():
 custom_minimum_size=Vector2(430,235)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 font=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC"])

func _process(delta:float):
 age+=delta
 if model!=null:queue_redraw()

func pulse():age=0;queue_redraw()

func word(at:Vector2,text:String,point_size:int=16,color:Color=Color("dde6e8")):
 draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,color)

func bar(at:Vector2,width:float,ratio:float,color:Color):
 draw_rect(Rect2(at,Vector2(width,7)),Color("243340"))
 draw_rect(Rect2(at,Vector2(width*clampf(ratio,0,1),7)),color)

func _draw():
 if model==null or font==null:return
 draw_style_box(panel(),Rect2(Vector2.ZERO,size))
 var lane_y:float=size.y*0.52
 draw_rect(Rect2(8,lane_y-45,size.x-16,98),Color("23313c"))
 for x in range(20,int(size.x),45):draw_line(Vector2(x,lane_y+12),Vector2(x+23,lane_y+12),Color("66717a"),2)
 var car=Rect2(22,lane_y-32,108,65)
 draw_style_box(vehicle(Color("467a89")),car)
 draw_rect(Rect2(car.position+Vector2(72,8),Vector2(26,44)),Color("a5c5ca"))
 word(car.position+Vector2(8,28),"房车",19)
 word(Vector2(22,28),"自动作战" if model.phase=="combat" else "公路整备",20)
 bar(Vector2(22,lane_y+45),108,float(model.hull)/model.max_hull,Color("84bd9a"))
 word(Vector2(22,lane_y+76),"耐久 %d/%d"%[model.hull,model.max_hull],14)
 if model.combat.is_empty():
  word(Vector2(157,lane_y-8),"先配置，再出发",19,Color("e8c583"))
  word(Vector2(157,lane_y+20),"武器自动攻击；弹药必须装车",14)
  word(Vector2(22,size.y-17),"第5段起持续干旱 · 注意供水与火力的空间竞争",13,Color("9cafbc"))
  return
 var enemies:Array=model.combat.enemies
 var enemy_x:float=size.x-166
 for i in range(enemies.size()):
  var e:Dictionary=enemies[i]
  var y:float=58+i*57
  var c=Color("a56551") if e.hp>0 else Color("3b454c")
  draw_style_box(vehicle(c),Rect2(enemy_x,y,140,37))
  word(Vector2(enemy_x+7,y+24),e.name,14)
  bar(Vector2(enemy_x,y+40),140,float(e.hp)/e.max_hp,Color("d88d6d"))
  word(Vector2(enemy_x-72,y+24),"%d/%d"%[e.hp,e.max_hp],13)
 word(Vector2(22,50),"第%d拍 · 弹药%d · 电量%d/%d"%[model.combat.tick,model.quantity("ammo"),model.combat.energy,model.combat.max_energy],14,Color("e8c583"))
 if age<0.65:
  for effect in model.effects:
   var target_y:float=76+maxi(0,int(effect.target))*57
   if effect.type=="shot":
    var start=Vector2(132,lane_y)
    var end=Vector2(enemy_x,target_y)
    draw_line(start,end,Color("bfa374"),1)
    draw_circle(start.lerp(end,minf(age/0.3,1)),4,Color("ffe2a0"))
    word(Vector2(enemy_x-35,target_y-14),"-%d"%effect.damage,18,Color("ffda91"))
   elif effect.type=="hit":
    draw_line(Vector2(enemy_x,target_y),Vector2(128,lane_y),Color("e57e6a"),2)
    if effect.blocked>0:
     draw_arc(Vector2(115,lane_y),48,-1.1,1.1,18,Color("86d6eb"),4)
     word(Vector2(140,lane_y+57),"防护挡下%d"%effect.blocked,14,Color("86d6eb"))
    if effect.damage>0:word(Vector2(36,lane_y-43),"车体 -%d"%effect.damage,19,Color("ff9b8a"))
   elif effect.type=="dry":word(Vector2(24,lane_y-43),"弹药不足 / 停火",17,Color("ff9b8a"))
 word(Vector2(22,size.y-17),"%s · 耗弹%d / 减伤%d / 车损%d"%["进行中" if model.phase=="combat" else "战斗记录",model.combat.ammo,model.combat.blocked,model.combat.damage],14)

func panel()->StyleBoxFlat:
 var b=StyleBoxFlat.new();b.bg_color=Color("14222c");b.set_corner_radius_all(9);return b
func vehicle(color:Color)->StyleBoxFlat:
 var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(5);return b
