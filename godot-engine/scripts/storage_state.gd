extends "res://scripts/vehicle_state.gd"
## Opt-in storage experiment. The baseline model and default launch keep their rules.
const STORAGE_DEMO=true

func _init():
 super()
 CATALOG["wood"]={"name":"原木","size":Vector2i.ONE,"color":"92734d","max":8,"desc":"沿途木托盘回收。1原木加工4木板，耗时10分钟。"}
 CATALOG["plank"]={"name":"木板","size":Vector2i.ONE,"color":"ab895b","max":32,"desc":"制作台、小木箱和长木箱的共同材料。"}
 CATALOG["chest"]={"name":"小木箱","size":Vector2i.ONE,"color":"ad8651","slots":9,"desc":"外部1格，内部9槽；可放空客座。装载物资，不能装箱子或设备。"}
 CATALOG["long_chest"]={"name":"长木箱","size":Vector2i(2,1),"color":"b18a56","slots":18,"desc":"外部2格，内部18槽；可旋转。与两只小箱容量相同，适合集中储备。"}
 for kind in ["ammo","water","food","cloth","electronics","raw"]:CATALOG[kind].size=Vector2i.ONE
 CATALOG.ammo.max=60;CATALOG.ammo.desc="每包60发，占1格。机枪每次点射耗3发，穿甲炮耗6发。邻接储备支持自动装填。"
 CATALOG.water.max=6;CATALOG.water.desc="密封饮水，每份约1升，每组6升。散放1格，入箱占2槽。"
 CATALOG.food.max=6;CATALOG.food.desc="干口粮，每组6份，占1格或箱内1槽。"
 CATALOG.seat.desc="空客座可承载一件1×1物资或小木箱。载货座位不可坐人；不安装设备。"
 CATALOG.gun.desc="每2拍点射3发，造成6伤害。内置弹匣18发；共边弹药包或箱子支持自动补给，斜角不算。"
 CATALOG.cannon.desc="每4拍射击耗6发，造成16伤害；内置弹匣36发，同样要求邻接补给。"
 RECIPES.bench={"cost":{"plank":4},"bench":false,"minutes":30}
 RECIPES["plank"]={"cost":{"wood":1},"bench":false,"minutes":10,"amount":4}
 RECIPES["chest"]={"cost":{"plank":8},"bench":true,"minutes":30}
 RECIPES["long_chest"]={"cost":{"plank":16},"bench":true,"minutes":60}
 learned.append_array(["plank","chest","long_chest"])
 for item in items:
  if item.kind=="ammo":item.amount*=3
 for loot in CACHE_LOOT:
  if loot[0]=="ammo":loot[1]*=3
 for site in ROUTES.values():
  for loot in site.loot:
   if loot[0]=="ammo":loot[1]*=3
 ROUTES.salvage.hint="金属4 / 布料3 / 弹药12发；自动击退掠食兽。"
 ROUTES.arms.hint="弹药30发 / 修理包1 / 布料2；装甲守卫，先战斗再开箱。"
 # Keep initial cargo legally within the smaller six-unit stacks.
 for item in items:
  if item.kind in ["gun","cannon"]:item["loaded"]=0
 note("收纳实验：首个20km托盘提供3原木。加工木板→制作台→9槽小木箱；空座可载货。")

func is_box(item:Dictionary)->bool:
 return not item.is_empty() and CATALOG[item.kind].has("slots")

func is_carried(item:Dictionary)->bool:
 if item.floor==0:return true
 if item.floor==-2:
  var parent:Dictionary=item_by_id(int(item.get("parent_id",-1)))
  return is_box(parent) and parent.floor==0
 return false

func contents(box_id:int)->Array:
 return items.filter(func(i):return i.floor==-2 and int(i.get("parent_id",-1))==box_id)

func slot_cost(kind:String)->int:
 return 2 if kind in ["water","fuel"] else 1

func slots_used(box_id:int)->int:
 var result:int=0
 for child in contents(box_id):result+=slot_cost(child.kind)
 return result

func quantity(kind:String)->int:
 var total:int=0
 for item in items:
  if item.kind==kind and is_carried(item):total+=item.amount
 return total

func ground()->Array:
 return items.filter(func(i):return i.floor==-1)

func used_cells()->int:
 var count:int=super.used_cells()
 for item in items:
  if item.floor==0 and int(item.get("seat_id",-1))>=0:count-=1
 return count

func cargo_on_seat(seat_id:int)->Dictionary:
 for item in items:
  if item.floor==0 and int(item.get("seat_id",-1))==seat_id:return item
 return {}

func seat_at(p:Vector2i)->Dictionary:
 for item in items:
  if item.floor==0 and item.kind=="seat" and item.pos==p:return item
 return {}

func seat_eligible(item:Dictionary)->bool:
 return footprint(item)==Vector2i.ONE and (is_box(item) or CATALOG[item.kind].has("max"))

func placement_error(item:Dictionary,f:int,p:Vector2i,check_state:bool=true)->String:
 if check_state and not editable():return "停车后才能整理"
 if f!=0:return "本实验只使用车内一层"
 var size:Vector2i=footprint(item)
 if p.x<0 or p.y<0 or p.x+size.x>width or p.y+size.y>height:return "超出车厢边界"
 for other in items:
  if other.floor!=0 or other.id==item.id:continue
  if int(other.get("seat_id",-1))==item.id:continue
  if not Rect2i(p,size).intersects(Rect2i(other.pos,footprint(other))):continue
  if other.kind=="seat" and seat_eligible(item) and seat_occupant(other.id).is_empty():continue
  return "位置被占用；空客座只可承载1格货物"
 return ""

func place(id:int,f:int,p:Vector2i,rotated:bool)->bool:
 var item:Dictionary=item_by_id(id)
 if item.is_empty():return false
 if not super.place(id,f,p,rotated):return false
 item["parent_id"]=-1;item["seat_id"]=-1
 var seat:Dictionary=seat_at(p)
 if not seat.is_empty() and seat.id!=id:item.seat_id=seat.id
 if item.kind=="seat":
  var cargo:Dictionary=cargo_on_seat(id)
  if not cargo.is_empty():cargo.pos=p
 return true

func drop(id:int)->bool:
 var item:Dictionary=item_by_id(id)
 if not super.drop(id):return false
 item["seat_id"]=-1
 return true

func insert(source_id:int,box_id:int)->int:
 if not editable() or source_id==box_id:return 0
 var source:Dictionary=item_by_id(source_id)
 var target:Dictionary=item_by_id(box_id)
 if source.is_empty() or not is_box(target) or target.floor!=0:return 0
 if not CATALOG[source.kind].has("max") or is_box(source):return 0
 if int(source.get("parent_id",-1))==box_id:return 0
 if target.get("filter","")!="" and source.kind!=target.filter:return 0
 var before:int=source.amount
 var limit:int=CATALOG[source.kind].max
 for child in contents(box_id):
  if child.kind!=source.kind:continue
  var transfer:int=mini(source.amount,limit-child.amount)
  child.amount+=transfer;source.amount-=transfer
  if source.amount==0:items.erase(source);return before
 if slots_used(box_id)+slot_cost(source.kind)<=int(CATALOG[target.kind].slots):
  source.floor=-2;source["parent_id"]=box_id;source["seat_id"]=-1
  note("收纳：%s ×%d → %s"%[CATALOG[source.kind].name,source.amount,CATALOG[target.kind].name])
  return before
 var moved:int=before-source.amount
 note("箱内空间不足；未装部分保留原处" if moved==0 else "部分合并，剩余保留原处")
 return moved

func unload(id:int)->bool:
 if not editable():return false
 var item:Dictionary=item_by_id(id)
 if item.is_empty() or item.floor!=-2:return false
 item.floor=-1;item.parent_id=-1
 note("取出到待装区；请放入车厢或空座")
 return true

func merge_at(id:int,p:Vector2i)->bool:
 if not editable():return false
 for other in items.duplicate():
  if other.floor==0 and other.id!=id and is_box(other) and Rect2i(other.pos,footprint(other)).has_point(p):
   return insert(id,other.id)>0
 return super.merge_at(id,p)

func spend(kind:String,amount:int)->bool:
 if quantity(kind)<amount:return false
 var remaining:int=amount
 for item in items.duplicate():
  if item.kind!=kind or not is_carried(item):continue
  var taken:int=mini(remaining,item.amount)
  item.amount-=taken;remaining-=taken
  if item.amount==0:items.erase(item)
  if remaining==0:break
 return true

func discard_loose():
 for root_item in ground().duplicate():
  for child in contents(root_item.id):metrics.discarded+=child.amount;items.erase(child)
  metrics.discarded+=root_item.amount;items.erase(root_item)

func store_generated(kind:String,amount:int)->int:
 var remaining:int=amount
 # Existing partial stacks first, including carried containers.
 for item in items:
  if item.kind!=kind or not is_carried(item):continue
  if item.floor==-2:
   var parent:Dictionary=item_by_id(int(item.get("parent_id",-1)))
   if parent.get("filter","")!="" and parent.filter!=kind:continue
  var moved:int=mini(remaining,int(CATALOG[kind].max)-item.amount)
  item.amount+=moved;remaining-=moved
  if remaining==0:return amount
 # Containers use volume slots. Failed pickup never destroys the remainder.
 for box in items.duplicate():
  if not is_box(box) or box.floor!=0:continue
  if box.get("filter","")!="" and box.filter!=kind:continue
  while remaining>0 and slots_used(box.id)+slot_cost(kind)<=int(CATALOG[box.kind].slots):
   var moved:int=mini(remaining,int(CATALOG[kind].max))
   var id:int=add_item(kind,moved,-2)
   item_by_id(id)["parent_id"]=box.id;remaining-=moved
 if remaining==0:return amount
 # Prefer free seats for small loose cargo, then ordinary floor slots.
 for seat in items.duplicate():
  if seat.kind!="seat" or seat.floor!=0 or not cargo_on_seat(seat.id).is_empty() or not seat_occupant(seat.id).is_empty():continue
  var candidate={"id":-99,"kind":kind,"rotated":false}
  if not seat_eligible(candidate):continue
  var moved:int=mini(remaining,int(CATALOG[kind].max))
  var id:int=add_item(kind,moved,0,seat.pos);item_by_id(id)["seat_id"]=seat.id;remaining-=moved
  if remaining==0:return amount
 return amount-remaining+super.store_generated(kind,remaining)

func collect_cache():
 var serial:int=next_cache
 super.collect_cache()
 if serial%6==1:
  var stored:int=store_generated("wood",3)
  if stored<3:add_item("wood",3-stored);phase="stop"
  last_pickup+=" · 木托盘回收原木3"
  note(last_pickup)

func craft(kind:String)->bool:
 if not super.craft(kind):return false
 # Processed boards are automatically stored; equipment and containers stay on ground.
 if kind=="plank":
  var output:Dictionary=item_by_id(next_id-1)
  var count:int=output.amount;items.erase(output)
  var stored:int=store_generated("plank",count)
  if stored<count:add_item("plank",count-stored)
  note("加工4木板，已自动收纳；无法装下的部分保留在待装区。")
 return true

func adjacent(a:Dictionary,b:Dictionary)->bool:
 var ra=Rect2i(a.pos,footprint(a));var rb=Rect2i(b.pos,footprint(b))
 return ((ra.end.x==rb.position.x or rb.end.x==ra.position.x) and maxi(ra.position.y,rb.position.y)<mini(ra.end.y,rb.end.y)) or ((ra.end.y==rb.position.y or rb.end.y==ra.position.y) and maxi(ra.position.x,rb.position.x)<mini(ra.end.x,rb.end.x))

func ammo_sources(weapon:Dictionary)->Array:
 var result:Array=[]
 for item in items:
  if item.kind!="ammo" or not is_carried(item):continue
  var root_item:Dictionary=item_by_id(int(item.get("parent_id",-1))) if item.floor==-2 else item
  if not root_item.is_empty() and adjacent(weapon,root_item):result.append(item)
 return result

func magazine_capacity(weapon:Dictionary)->int:
 return 18 if weapon.kind=="gun" else 36

func reachable_ammo(weapon:Dictionary)->int:
 var total:int=0
 for source in ammo_sources(weapon):total+=source.amount
 return total

func reload_weapon(id:int)->bool:
 if not editable():return false
 var weapon:Dictionary=item_by_id(id)
 if weapon.is_empty() or weapon.kind not in ["gun","cannon"] or weapon.floor!=0:return false
 var load_count:int=mini(quantity("ammo"),magazine_capacity(weapon)-int(weapon.get("loaded",0)))
 if load_count<=0:return false
 spend("ammo",load_count);weapon["loaded"]=int(weapon.get("loaded",0))+load_count
 note("停车手动装填%d发；作战时只有共边储备能自动补给"%load_count)
 return true

func weapon_ammo_cost(weapon:Dictionary)->int:
 return 3 if weapon.kind=="gun" else 6

func weapon_has_ammo(weapon:Dictionary,cost:int)->bool:
 return int(weapon.get("loaded",0))+reachable_ammo(weapon)>=cost

func spend_weapon_ammo(weapon:Dictionary,cost:int)->bool:
 if not weapon_has_ammo(weapon,cost):return false
 var loaded:int=int(weapon.get("loaded",0))
 if loaded<cost:
  var remaining:int=magazine_capacity(weapon)-loaded
  for source in ammo_sources(weapon).duplicate():
   var taken:int=mini(remaining,source.amount)
   var source_root:int=int(source.get("parent_id",source.id)) if source.floor==-2 else source.id
   source.amount-=taken;loaded+=taken;remaining-=taken
   effects.append({"type":"supply","id":source_root})
   if source.amount==0:items.erase(source)
   if remaining==0:break
  note("邻接自动补弹：%s弹匣%d发"%[CATALOG[weapon.kind].name,loaded])
 weapon["loaded"]=loaded-cost
 return true
