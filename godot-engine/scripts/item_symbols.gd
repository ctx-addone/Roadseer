extends RefCounted
## Small engine-drawn symbols keep cargo recognizable before final art exists.
static func paint(canvas:CanvasItem,kind:String,rect:Rect2,color:Color=Color("e2e8df")):
 var c:Vector2=rect.get_center()
 var u:float=minf(rect.size.x,rect.size.y)/2.4
 var stroke:float=2.0
 match kind:
  "wood","plank":
   for y in [-0.6,0.1]:
    canvas.draw_rect(Rect2(c+Vector2(-u,y*u),Vector2(2*u,u*0.5)),color,false,stroke)
  "chest","long_chest":
   canvas.draw_rect(Rect2(c-Vector2(u,u*0.8),Vector2(2*u,1.6*u)),color,false,stroke)
   canvas.draw_line(c+Vector2(-u,-u*0.2),c+Vector2(u,-u*0.2),color,stroke)
   canvas.draw_rect(Rect2(c-Vector2(u*0.15,u*0.1),Vector2(u*0.3,u*0.5)),color)
  "water":
   canvas.draw_colored_polygon(PackedVector2Array([c+Vector2(0,-u),c+Vector2(-u*0.7,u*0.15),c+Vector2(-u*0.5,u*0.8),c+Vector2(u*0.5,u*0.8),c+Vector2(u*0.7,u*0.15)]),color)
  "food","raw":
   canvas.draw_arc(c+Vector2(0,-u*0.2),u,0,PI,18,color,stroke)
   canvas.draw_line(c+Vector2(-u,-u*0.2),c+Vector2(u,-u*0.2),color,stroke)
   for x in [-0.4,0.4]:canvas.draw_line(c+Vector2(x*u,-u),c+Vector2(x*u,-u*0.5),color,stroke)
  "bench":
   canvas.draw_rect(Rect2(c+Vector2(-u,-u*0.3),Vector2(2*u,u*0.4)),color)
   for x in [-0.65,0.65]:canvas.draw_line(c+Vector2(x*u,0),c+Vector2(x*u,u),color,3)
   canvas.draw_line(c+Vector2(-u*0.4,-u*0.8),c+Vector2(u*0.4,-u*0.8),color,3)
  "gun","cannon":
   canvas.draw_rect(Rect2(c+Vector2(-u,-u*0.45),Vector2(u*1.4,u*0.7)),color)
   canvas.draw_line(c+Vector2(0,-u*0.1),c+Vector2(u,-u*0.1),color,4)
   canvas.draw_line(c+Vector2(-u*0.4,0),c+Vector2(-u*0.6,u*0.8),color,4)
  "ammo":
   for x in [-0.65,0.0,0.65]:
    canvas.draw_rect(Rect2(c+Vector2(x*u-u*0.15,-u*0.45),Vector2(u*0.3,u*1.2)),color)
    canvas.draw_line(c+Vector2(x*u,-u*0.9),c+Vector2(x*u,-u*0.4),color,3)
  "person":
   canvas.draw_circle(c+Vector2(0,-u*0.5),u*0.38,color)
   canvas.draw_arc(c+Vector2(0,u*0.8),u*0.65,PI,TAU,16,color,4)
  "bed":
   canvas.draw_rect(Rect2(c+Vector2(-u,-u*0.7),Vector2(u*2,u*1.3)),color,false,stroke)
   canvas.draw_rect(Rect2(c+Vector2(-u*0.8,-u*0.5),Vector2(u*0.5,u*0.9)),color)
   for x in [-1,1]:canvas.draw_line(c+Vector2(x*u,-u),c+Vector2(x*u,u),color,stroke)
  "driver":
   canvas.draw_arc(c,u,0,TAU,24,color,stroke)
   for a in [0.0,2.1,4.2]:canvas.draw_line(c,c+Vector2.from_angle(a)*u,color,stroke)
  "seat":
   canvas.draw_rect(Rect2(c+Vector2(-u*0.65,-u),Vector2(u*1.3,u*1.2)),color,false,stroke)
   canvas.draw_line(c+Vector2(-u*0.65,u*0.6),c+Vector2(u*0.65,u*0.6),color,4)
  "cooler","collector":
   canvas.draw_circle(c,u*0.18,color)
   for a in [0.0,PI/2,PI,PI*1.5]:
    canvas.draw_arc(c+Vector2.from_angle(a)*u*0.55,u*0.4,a,a+PI,10,color,3)
  "generator","battery","electronics":
   canvas.draw_rect(Rect2(c-Vector2.ONE*u,Vector2.ONE*u*2),color,false,stroke)
   canvas.draw_polyline(PackedVector2Array([c+Vector2(u*0.3,-u*0.8),c+Vector2(-u*0.3,0),c+Vector2(u*0.3,0),c+Vector2(-u*0.3,u*0.8)]),color,3)
  "shade","armor","interceptor":
   canvas.draw_polyline(PackedVector2Array([c+Vector2(-u,-u*0.7),c+Vector2(0,-u),c+Vector2(u,-u*0.7),c+Vector2(u*0.7,u*0.4),c+Vector2(0,u),c+Vector2(-u*0.7,u*0.4),c+Vector2(-u,-u*0.7)]),color,stroke)
  "repair":
   canvas.draw_rect(Rect2(c-Vector2.ONE*u,Vector2.ONE*u*2),color,false,stroke)
   canvas.draw_line(c-Vector2(u*0.6,0),c+Vector2(u*0.6,0),color,4)
   canvas.draw_line(c-Vector2(0,u*0.6),c+Vector2(0,u*0.6),color,4)
  "cloth":
   canvas.draw_rect(Rect2(c-Vector2.ONE*u*0.8,Vector2.ONE*u*1.6),color,false,stroke)
   canvas.draw_line(c+Vector2(-u*0.4,-u*0.8),c+Vector2(-u*0.4,u*0.8),color,1)
   canvas.draw_line(c+Vector2(-u*0.8,u*0.4),c+Vector2(u*0.8,u*0.4),color,1)
  "fuel":
   canvas.draw_rect(Rect2(c+Vector2(-u*0.7,-u*0.6),Vector2(u*1.4,u*1.5)),color,false,stroke)
   canvas.draw_rect(Rect2(c+Vector2(-u*0.35,-u),Vector2(u*0.7,u*0.4)),color,false,stroke)
  _:
   canvas.draw_line(c+Vector2(-u,u*0.5),c+Vector2(u,-u*0.5),color,5)
   canvas.draw_line(c+Vector2(-u,-u*0.5),c+Vector2(u,u*0.5),color,5)
