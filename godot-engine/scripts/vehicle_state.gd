extends RefCounted
## Slice 1, in-memory. All cargo quantities live in physical grid items.
const CATALOG = {
 "driver":{"name":"驾驶位","size":Vector2i(1,2),"color":"566d85","desc":"固定保留的驾驶位。此片段不模拟乘员。","fixed":true},
 "seat":{"name":"客座","size":Vector2i(1,2),"color":"43576d","desc":"四个座位的占位验证；可搬移，不可丢弃。","fixed":true},
 "gun":{"name":"机枪","size":Vector2i(1,2),"color":"bc8352","desc":"每2拍自动射击：消耗1弹药，造成6伤害，受装甲减免。"},
 "cannon":{"name":"穿甲炮","size":Vector2i(2,3),"color":"bb6752","desc":"每4拍自动射击：消耗2弹药，造成16伤害，无视装甲。占6格。"},
 "collector":{"name":"集水器","size":Vector2i(2,2),"color":"368e99","desc":"每段行驶生成2水，先补已有水箱，再尝试空位。装不下会明确报告溢出。"},
 "kitchen":{"name":"厨房","size":Vector2i(2,2),"color":"b59554","desc":"每段行驶消耗1原料，产2口粮；至少有1口粮容量才加工。"},
 "battery":{"name":"蓄电池","size":Vector2i(1,2),"color":"7e82ba","desc":"每战可用电量+4。基础电容每战3电；此片段整备时由车载电源充满。"},
 "interceptor":{"name":"拦截器","size":Vector2i(1,2),"color":"528fab","desc":"每次敌方攻击自动消耗1电，最多拦截3伤害；本片段只计算一套。"},
 "armor":{"name":"装甲板","size":Vector2i(1,2),"color":"7f929c","desc":"每次受到攻击减伤1；本片段只计算一套。"},
 "water":{"name":"饮水","size":Vector2i(1,2),"color":"397b9b","max":6,"desc":"每箱最多6水。普通路段耗1水，干旱路段耗2水；缺1水损失4耐久。"},
 "food":{"name":"口粮","size":Vector2i(1,2),"color":"8b8551","max":6,"desc":"每箱最多6份。每段行驶耗1份；缺1份损失4耐久。"},
 "fuel":{"name":"燃油","size":Vector2i(1,2),"color":"9f7049","max":8,"desc":"每桶最多8。普通路段耗1，水站绕路耗2；燃油耗尽则本局失败。"},
 "ammo":{"name":"弹药","size":Vector2i(1,2),"color":"a79364","max":12,"desc":"每箱最多12。机枪每次耗1，穿甲炮每次耗2。点击同类箱可合并堆叠。"},
 "scrap":{"name":"材料","size":Vector2i(2,1),"color":"778577","max":6,"desc":"每箱最多6。水站维修营花6材料扩容一次，也可花2材料修复6耐久。"},
 "raw":{"name":"原料","size":Vector2i(1,2),"color":"698c59","max":6,"desc":"每箱最多6。厨房每段行驶用1份加工2份口粮。"},
 "repair":{"name":"修理包","size":Vector2i(1,2),"color":"ac6473","max":2,"desc":"停车时点击使用，消耗1份恢复10耐久。每箱最多2。"}
}
const NODE_NAMES = ["启程","路边车库","兽群","预警信号","维修营","补给残骸","最后整备","出口守卫"]
var width:int=4
var height:int=6
var floor_index:int=0
var items:Array=[]
var next_id:int=1
var logs:Array[String]=[]
var node:int=0
var variant:int=0
var phase:String="stop"
var hull:int=40
var max_hull:int=40
var route:String=""
var expanded:bool=false
var choice_done:bool=false
var outcome:String=""
var won:bool=false
var combat:Dictionary={}
var effects:Array=[]
var battle_reports:Array[String]=[]
var metrics={"placed":0,"discarded":0,"shots":0,"ammo":0,"blocked":0,"damage":0,"produced":0}
var last_report:String=""

func _init(run_variant:int=0):
 variant=run_variant%2
 add_item("driver",1,0,Vector2i(0,0))
 for x in range(1,4):add_item("seat",1,0,Vector2i(x,0))
 add_item("gun",1,0,Vector2i(0,2))
 add_item("ammo",10,0,Vector2i(1,2))
 add_item("water",4,0,Vector2i(2,2))
 add_item("food",4,0,Vector2i(3,2))
 add_item("fuel",8,0,Vector2i(0,4))
 add_item("scrap",4,0,Vector2i(1,4))
 choice_done=true
 note("任务：穿过7段公路，击败出口守卫。所有物资必须装进车内。")
 note("路线样本%s：无局外成长。整理时不推进时间。"%["A","B"][variant])

func add_item(kind:String,amount:int=1,floor_id:int=-1,pos:Vector2i=Vector2i.ZERO)->int:
 var id:int=next_id;next_id+=1
 items.append({"id":id,"kind":kind,"floor":floor_id,"pos":pos,"rotated":false,"amount":amount})
 return id

func item_by_id(id:int)->Dictionary:
 for item in items:
  if item.id==id:return item
 return {}

func footprint(item:Dictionary)->Vector2i:
 var s:Vector2i=CATALOG[item.kind].size
 return Vector2i(s.y,s.x) if item.rotated else s

func count_active(kind:String)->int:
 var n:int=0
 for item in items:
  if item.kind==kind and item.floor==0:n+=1
 return n

func quantity(kind:String)->int:
 var n:int=0
 for item in items:
  if item.kind==kind and item.floor==0:n+=item.amount
 return n

func ground()->Array:
 return items.filter(func(i):return i.floor<0)

func used_cells()->int:
 var n:int=0
 for i in items:
  if i.floor==0:
   var s:Vector2i=footprint(i);n+=s.x*s.y
 return n

func editable()->bool:return phase=="stop" and outcome.is_empty()
func floor_unlocked(f:int)->bool:return f==0

func placement_error(item:Dictionary,f:int,p:Vector2i)->String:
 if not editable():return "行驶、战斗或结算时不能整理"
 if f!=0:return "片段一只使用车内一层"
 var s:Vector2i=footprint(item)
 if p.x<0 or p.y<0 or p.x+s.x>width or p.y+s.y>height:return "超出车厢边界"
 for other in items:
  if other.id!=item.id and other.floor==f and Rect2i(p,s).intersects(Rect2i(other.pos,footprint(other))):return "与现有物品重叠；同类物资可点击合并"
 return ""

func place(id:int,f:int,p:Vector2i,rotated:bool)->bool:
 var item=item_by_id(id)
 if item.is_empty():return false
 var candidate=item.duplicate();candidate.rotated=rotated
 var error:String=placement_error(candidate,f,p)
 if not error.is_empty():note(error);return false
 item.floor=f;item.pos=p;item.rotated=rotated
 metrics.placed+=1
 note("装车：%s%s"%[CATALOG[item.kind].name," ×%d"%item.amount if CATALOG[item.kind].has("max") else ""])
 return true

func merge_at(id:int,p:Vector2i)->bool:
 if not editable():return false
 var source=item_by_id(id)
 if source.is_empty() or not CATALOG[source.kind].has("max"):return false
 for target in items:
  if target.id==id or target.floor!=0 or target.kind!=source.kind:continue
  if not Rect2i(target.pos,footprint(target)).has_point(p):continue
  var moved:int=mini(source.amount,int(CATALOG[target.kind].max)-int(target.amount))
  if moved<=0:note("这箱物资已经装满");return false
  target.amount+=moved;source.amount-=moved
  note("合并%d份%s；剩余仍保留在原处"%[moved,CATALOG[target.kind].name])
  if source.amount==0:items.erase(source)
  metrics.placed+=1
  return true
 return false

func drop(id:int)->bool:
 if not editable():return false
 var item=item_by_id(id)
 if item.is_empty() or item.floor<0:return false
 if CATALOG[item.kind].get("fixed",false):note("座位在本片段必须保留，可搬移");return false
 item.floor=-1
 note("%s放到地面；出发会丢弃，停靠期间可重新装回"%CATALOG[item.kind].name)
 return true

func spend(kind:String,amount:int)->bool:
 if quantity(kind)<amount:return false
 var remaining:int=amount
 for item in items.duplicate():
  if item.floor!=0 or item.kind!=kind:continue
  var take:int=mini(remaining,item.amount)
  item.amount-=take;remaining-=take
  if item.amount==0:items.erase(item)
  if remaining==0:break
 return true

func use_repair(id:int)->bool:
 if not editable() or hull>=max_hull:return false
 var item=item_by_id(id)
 if item.is_empty() or item.kind!="repair" or item.floor!=0:return false
 item.amount-=1
 if item.amount==0:items.erase(item)
 var gain:int=mini(10,max_hull-hull);hull+=gain;note("使用修理包：耐久+%d"%gain)
 return true

func upgrade()->bool:
 if not editable() or node!=4 or expanded:return false
 if not spend("scrap",6):note("扩容需要车内6材料；地面材料须先装车");return false
 height=8;expanded=true
 note("扩容完成：4×6 → 4×8，增加8格。原布局保持不变。")
 return true

func workshop_repair()->bool:
 if not editable() or node!=4 or hull>=max_hull:return false
 if not spend("scrap",2):note("维修需要车内2材料");return false
 hull=mini(max_hull,hull+6);note("维修营：花2材料，恢复最多6耐久");return true

func offers()->Array:
 if not editable() or choice_done:return []
 match node:
  1:
   return [{"title":"集水器 · 2×2","hint":"之后每段生成2水；供给占4格。","bundle":[["collector",1]]},
    {"title":"穿甲炮 · 2×3","hint":"每4拍16穿甲伤害，但一次消耗2弹药。","bundle":[["cannon",1]]},
    {"title":"防护补给","hint":"装甲板1×2 + 修理包1×2，先保住车体。","bundle":[["armor",1],["repair",1]]}]
  3:
   return [{"title":"拦截器 · 1×2","hint":"每次用1电拦截3伤害；基础电容3电/战。","bundle":[["interceptor",1]]},
    {"title":"蓄电池与弹药","hint":"电量+4（需拦截器发挥作用）；弹药补6。","bundle":[["battery",1],["ammo",6]]},
    {"title":"弹药与修理包","hint":"补8弹药 + 修理包1份。","bundle":[["ammo",8],["repair",1]]}]
  5:
   return [{"title":"厨房与原料","hint":"厨房2×2 + 原料1×2（3份）；之后每段原料转口粮。","bundle":[["kitchen",1],["raw",3]]},
    {"title":"装甲与弹药" if variant==0 else "能源防护组合","hint":"装甲板1×2 + 8弹药。" if variant==0 else "拦截器1×2 + 蓄电池1×2 + 6弹药。","bundle":[["armor",1],["ammo",8]] if variant==0 else [["interceptor",1],["battery",1],["ammo",6]]},
    {"title":"轻装补给","hint":"6水 + 4口粮 + 6弹药；每类物资一箱。","bundle":[["water",6],["food",4],["ammo",6]]}]
  6:
   return [{"title":"终点弹药包","hint":"12弹药 + 2口粮；为出口守卫留出货位。","bundle":[["ammo",12],["food",2]]},
    {"title":"生存包","hint":"6水 + 2口粮 + 修理包1份。","bundle":[["water",6],["food",2],["repair",1]]},
    {"title":"维修与弹药","hint":"8弹药 + 修理包1份。","bundle":[["ammo",8],["repair",1]]}]
 return []

func choose_reward(index:int)->bool:
 var choices:Array=offers()
 if index<0 or index>=choices.size():return false
 var choice:Dictionary=choices[index]
 for pair in choice.bundle:add_item(pair[0],pair[1])
 choice_done=true;note("选择奖励：%s。物资在地面，装车后才生效。"%choice.title)
 return true

func choose_route(value:String)->bool:
 if not editable() or node!=3 or value not in ["short","water"]:return false
 route=value
 note("已选%s：下段耗%d油；敌情与奖励已在路线说明中显示。"%["干河床" if route=="short" else "旧水站",1 if route=="short" else 2])
 return true

func travel_cost()->Dictionary:
 return {"fuel":2 if node==3 and route=="water" else 1,"water":2 if node>=4 or (node==3 and route=="short") else 1,"food":1}

func departure_error()->String:
 if not editable():return "当前不能出发"
 if not choice_done:return "先选择本节点的一组奖励"
 if node==3 and route.is_empty():return "先选择接下来的路线"
 if node>=7:return "已到终点"
 return ""

func depart(discard_ground:bool=false)->bool:
 var error:String=departure_error()
 if not error.is_empty():note(error);return false
 if not ground().is_empty() and not discard_ground:note("地面还有物品：装车或确认丢弃后出发");return false
 var cost:Dictionary=travel_cost()
 if quantity("fuel")<cost.fuel:
  lose("燃油不足：未能抵达下一节点。下次为行驶保留燃油货位。")
  return true
 for item in ground():
  metrics.discarded+=item.amount;items.erase(item)
 spend("fuel",cost.fuel)
 produce()
 for kind in ["water","food"]:
  var available:int=mini(quantity(kind),cost[kind])
  spend(kind,available)
  var shortage:int=int(cost[kind])-available
  if shortage>0:
   hull-=shortage*4;metrics.damage+=shortage*4
   note("%s短缺%d：耐久-%d"%[CATALOG[kind].name,shortage,shortage*4])
 note("行驶消耗：%d燃油 / %d水 / 1口粮"%[cost.fuel,cost.water])
 node+=1;choice_done=false
 if hull<=0:lose("途中补给耗尽，车辆无法继续。查看记录中的短缺原因。");return true
 match node:
  2:start_battle("swarm")
  4:start_battle("heavy" if route=="short" else "swarm")
  7:start_battle("boss")
  _:phase="stop"
 note("抵达：%s"%NODE_NAMES[node])
 return true

func store_generated(kind:String,amount:int)->int:
 var left:int=amount
 for item in items:
  if item.floor==0 and item.kind==kind:
   var put:int=mini(left,int(CATALOG[kind].max)-int(item.amount))
   item.amount+=put;left-=put
   if left==0:return amount
 while left>0:
  var placed:bool=false
  var candidate={"id":-99,"kind":kind,"rotated":false}
  for rotation in [false,true]:
   candidate.rotated=rotation
   for y in range(height):
    for x in range(width):
     if placement_error(candidate,0,Vector2i(x,y)).is_empty():
      var put:int=mini(left,CATALOG[kind].max)
      var id:int=add_item(kind,put,0,Vector2i(x,y));item_by_id(id).rotated=rotation
      left-=put;placed=true;break
    if placed:break
   if placed:break
  if not placed:break
 return amount-left

func cargo_has_room(kind:String)->bool:
 for item in items:
  if item.floor==0 and item.kind==kind and item.amount<CATALOG[kind].max:return true
 var candidate={"id":-99,"kind":kind,"rotated":false}
 for rotation in [false,true]:
  candidate.rotated=rotation
  for y in range(height):
   for x in range(width):
    if placement_error(candidate,0,Vector2i(x,y)).is_empty():return true
 return false

func produce():
 if count_active("collector")>0:
  var expected:int=2*count_active("collector")
  var actual:int=store_generated("water",expected);metrics.produced+=actual
  note("集水器：产%d水，入舱%d，容量不足溢出%d"%[expected,actual,expected-actual])
 if count_active("kitchen")>0:
  if quantity("raw")==0:note("厨房停机：车内没有原料")
  elif not cargo_has_room("food"):note("厨房暂停：口粮无处存放，未消耗原料")
  else:
   spend("raw",1)
   var actual:int=store_generated("food",2);metrics.produced+=actual
   note("厨房：消耗1原料，入舱%d口粮，溢出%d"%[actual,2-actual])

func enemy(name_text:String,hp:int,armor:int,damage:int,interval:int)->Dictionary:
 return {"name":name_text,"hp":hp,"max_hp":hp,"armor":armor,"damage":damage,"interval":interval}

func start_battle(kind:String):
 phase="combat"
 var enemies:Array=[]
 if kind=="swarm":
  for i in range(3):enemies.append(enemy("掠食兽 %d"%(i+1),8+(2 if variant==1 else 0),0,2,3+i))
 elif kind=="heavy":enemies.append(enemy("装甲拦路车",30,2,5,3))
 else:
  enemies.append(enemy("出口装甲守卫",48,2,5,3))
  enemies.append(enemy("护卫无人机",10,0,2,4))
 var energy:int=3+4*count_active("battery")
 combat={"kind":kind,"enemies":enemies,"tick":0,"energy":energy,"max_energy":energy,"ammo_start":quantity("ammo"),"hull_start":hull,"shots":0,"ammo":0,"blocked":0,"damage":0,"dealt":0,"contribution":{},"dry_warned":false}
 effects=[];last_report=""
 note("自动战斗开始：%s。车内布局已锁定；可暂停观察或加速。"%{"swarm":"兽群","heavy":"装甲车","boss":"出口守卫"}[kind])

func first_enemy()->int:
 for i in range(combat.enemies.size()):
  if combat.enemies[i].hp>0:return i
 return -1

func combat_step():
 if phase!="combat":return
 combat.tick+=1;effects=[]
 for weapon in items.duplicate():
  if weapon.floor!=0 or weapon.kind not in ["gun","cannon"]:continue
  var interval:int=2 if weapon.kind=="gun" else 4
  if combat.tick%interval!=0:continue
  var index:int=first_enemy()
  if index<0:break
  var ammo_cost:int=1 if weapon.kind=="gun" else 2
  if not spend("ammo",ammo_cost):
   effects.append({"type":"dry","id":weapon.id,"target":index})
   if not combat.dry_warned:note("弹药不足：武器停火；每3拍应急撞击，车体也会受损。");combat.dry_warned=true
   continue
  var target:Dictionary=combat.enemies[index]
  var raw_damage:int=6 if weapon.kind=="gun" else 16
  var damage:int=maxi(1,raw_damage-(int(target.armor) if weapon.kind=="gun" else 0))
  target.hp=maxi(0,int(target.hp)-damage)
  combat.shots+=1;combat.ammo+=ammo_cost;combat.dealt+=damage
  combat.contribution[weapon.kind]=int(combat.contribution.get(weapon.kind,0))+damage
  effects.append({"type":"shot","id":weapon.id,"target":index,"damage":damage})
  note("%s → %s：%d伤害%s，弹药-%d"%[CATALOG[weapon.kind].name,target.name,damage,"（装甲减免%d）"%target.armor if weapon.kind=="gun" and target.armor>0 else "",ammo_cost])
  if target.hp==0:note("击破：%s"%target.name)
 if first_enemy()<0:end_battle();return
 var can_shoot:bool=(count_active("gun")>0 and quantity("ammo")>=1) or (count_active("cannon")>0 and quantity("ammo")>=2)
 if not can_shoot and combat.tick%3==0:
  var target:Dictionary=combat.enemies[first_enemy()]
  target.hp=maxi(0,int(target.hp)-3);hull-=2;combat.damage+=2
  note("无可用火力，应急撞击：敌方-3，车体-2")
  effects.append({"type":"ram","target":first_enemy()})
  if hull<=0:lose("应急撞击耗尽耐久。保留武器与足够弹药再试。");return
  if first_enemy()<0:end_battle();return
 for i in range(combat.enemies.size()):
  var target:Dictionary=combat.enemies[i]
  if target.hp<=0 or combat.tick%int(target.interval)!=0:continue
  var damage:int=target.damage
  var intercepted:int=0
  if count_active("interceptor")>0 and combat.energy>0:
   intercepted=mini(3,damage);combat.energy-=1;damage-=intercepted
  var armored:int=mini(damage,1 if count_active("armor")>0 else 0)
  damage-=armored;hull-=damage;combat.damage+=damage;combat.blocked+=intercepted+armored
  effects.append({"type":"hit","target":i,"damage":damage,"blocked":intercepted+armored})
  note("%s攻击%d → 拦截%d / 装甲%d / 车体-%d%s"%[target.name,target.damage,intercepted,armored,damage,"（电量耗尽）" if count_active("interceptor")>0 and combat.energy==0 else ""])
  if hull<=0:lose("车体被击毁。查看战斗记录：缺弹、防护或火力不足。");return
 if combat.tick>=80:lose("战斗超时：未能突破敌方，下一局调整火力和补给。")

func report_battle()->String:
 if combat.is_empty():return ""
 var contribution:PackedStringArray=[]
 for kind in combat.contribution:contribution.append("%s %d伤害"%[CATALOG[kind].name,combat.contribution[kind]])
 return "耗弹 %d · 拦截/减伤 %d · 车损 %d\n%s"%[combat.ammo,combat.blocked,combat.damage," / ".join(contribution)]

func record_battle():
 last_report=report_battle();battle_reports.append("%s：%s"%[NODE_NAMES[node],last_report])
 for key in ["shots","ammo","blocked","damage"]:metrics[key]+=combat[key]

func end_battle():
 record_battle();phase="stop";choice_done=true
 note("战斗胜利。"+last_report.replace("\n","；"))
 if node==2:
  add_item("ammo",8 if variant==0 else 6);add_item("scrap",2)
 elif node==4:
  add_item("scrap",4);add_item("food",2);add_item("water",6 if route=="water" else 4)
  note("抵达维修营：可以花6材料扩容，或花2材料维修；补给已卸在地面。")
 elif node==7:
  won=true;phase="ended";outcome="抵达下一世界"
  note("通关！这趟旅程的车辆与物资不带入下一局。可以用另一组掉落再试。")

func lose(reason:String):
 if phase=="combat":record_battle()
 phase="ended";hull=maxi(0,hull);outcome="旅程结束："+reason;note(outcome)

func description()->String:
 if not outcome.is_empty():return outcome+"\n本局摆放%d次 / 放弃%d份 / 生产入舱%d份。"%[metrics.placed,metrics.discarded,metrics.produced]
 match node:
  0:return "你有一辆4×6小车，前方是7段公路。第5段起耗水翻倍。先检查车内物资，再出发寻找设备。每段行驶推进一次生产与消耗；整理不耗时。"
  1:return "车库只能带走一组奖励。先选奖励，再把地面物品放进车厢。穿甲炮很大，集水器则能减轻后半程的饮水压力。"
  2:return "兽群正在逼近。" if phase=="combat" else "第一次战斗结束。检查耗弹与车损，把掉落装车；同类物资点击现有箱子可合并，超出上限仍留原处。"
  3:return "预警：维修营之后持续干旱（每段耗2水）。干河床：1油/2水，装甲车，营地得4水；旧水站：2油/1水，兽群，营地得6水。两路都抵达同一维修营。"
  4:return "接近维修营，必须突破阻拦。" if phase=="combat" else "安全停靠。6材料扩成4×8；2材料修复6耐久。扩容与维修使用车内材料，地面物资请先装入或合并。后续每段耗2水。"
  5:return "残骸里有三组物资。现在的供给能否撑到终点？生产、火力和现成补给只能优先选一组。"
  6:return "最后整备：下一段耗1油、2水、1口粮。终点为48生命/2装甲的守卫和10生命无人机。检查弹药、耐久与防护；缺补给每份损失4耐久。"
  _:return "出口守卫：普通武器受装甲减免，穿甲炮无视装甲。先击破装甲车，再清理无人机。"

func note(message:String):
 logs.push_front(message)
 if logs.size()>120:logs.resize(120)
