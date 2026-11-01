extends RefCounted
## Disposable 21-day cycle prototype. Cargo and ingredients always occupy grid cells.
const BASE_CATALOG = {
 "driver":{"name":"驾驶位","size":Vector2i.ONE,"color":"566d85","desc":"占1格，容纳1人。主角默认在此驾驶；移动座位时成员随座位移动。","fixed":true},
 "seat":{"name":"客座","size":Vector2i.ONE,"color":"43576d","desc":"占1格，容纳1人。开局为空座，不代表已有乘员。可搬移，本轮保留。","fixed":true},
 "bed":{"name":"单人床","size":Vector2i(1,2),"color":"8f8caa","desc":"占2格，可旋转。每床供1人睡眠；夜间自动安排。无热伤且水粮充足时，有床休息恢复2健康，无床不恢复。"},
 "gun":{"name":"机枪","size":Vector2i(1,2),"color":"bc8352","desc":"每2拍自动射击：消耗1弹药，造成6伤害，受装甲减免。"},
 "cannon":{"name":"穿甲炮","size":Vector2i(2,3),"color":"bb6752","desc":"每4拍自动射击：消耗2弹药，造成16伤害，无视装甲。占6格。"},
 "collector":{"name":"集水器","size":Vector2i(2,2),"color":"368e99","desc":"每天夜间收集1水；三日凌空期间空气干燥，产量为0。"},
 "kitchen":{"name":"厨房","size":Vector2i(2,2),"color":"b59554","desc":"每晚消耗1原料，产2口粮；没有空间则暂停。"},
 "battery":{"name":"蓄电池","size":Vector2i(1,2),"color":"7e82ba","desc":"每战可用电量+4。基础电容每战3电；此片段整备时由车载电源充满。"},
 "interceptor":{"name":"拦截器","size":Vector2i(1,2),"color":"528fab","desc":"每次敌方攻击自动消耗1电，最多拦截3伤害；本片段只计算一套。"},
 "armor":{"name":"装甲板","size":Vector2i(1,2),"color":"7f929c","desc":"每次受到攻击减伤1；本片段只计算一套。"},
 "water":{"name":"饮水","size":Vector2i(1,2),"color":"397b9b","max":12,"desc":"每箱最多12水；夜间按余热耗水，灾难行驶每小时另耗1水。缺水损伤乘员健康。"},
 "food":{"name":"口粮","size":Vector2i(1,2),"color":"8b8551","max":12,"desc":"每箱最多12份。每晚消耗1份；缺粮损伤乘员健康。"},
 "fuel":{"name":"燃油","size":Vector2i(1,2),"color":"9f7049","max":12,"desc":"每桶最多12。行驶每小时准备期1油、灾难期2油；发电制冷每晚1油。无油仍可驻车。"},
 "ammo":{"name":"弹药","size":Vector2i(1,2),"color":"a79364","max":12,"desc":"每箱最多12。机枪每次耗1，穿甲炮每次耗2。点击同类箱可合并堆叠。"},
 "scrap":{"name":"金属","size":Vector2i(2,1),"color":"778577","max":8,"desc":"制作与扩容材料，每箱最多8。必须先装车才能使用。"},
 "raw":{"name":"原料","size":Vector2i(1,2),"color":"698c59","max":6,"desc":"每箱最多6。厨房每晚用1份加工2份口粮。"},
 "bench":{"name":"制作台","size":Vector2i(2,2),"color":"9c784e","desc":"制作隔热、发电与制冷设备的前提。安装后才生效；占4格。"},
 "shade":{"name":"隔热层","size":Vector2i(2,2),"color":"bd985e","desc":"被动降低2级热强度，不耗油；只计算一套。占位代表隔热物料与内部支架。"},
 "generator":{"name":"发电机","size":Vector2i(1,2),"color":"948261","desc":"与制冷机配套，高温夜间耗1油支持制冷；只运行一套。"},
 "cooler":{"name":"制冷机","size":Vector2i(2,2),"color":"569d9d","desc":"启用时需发电机与1油/晚，降低3级热强度；只计算一套。"},
 "cloth":{"name":"布料","size":Vector2i(1,2),"color":"a78a78","max":8,"desc":"制作隔热层和设备使用，每箱最多8。"},
 "electronics":{"name":"元件","size":Vector2i(1,2),"color":"7f89b1","max":8,"desc":"发电机与制冷机的材料，每箱最多8。"},
 "repair":{"name":"修理包","size":Vector2i(1,2),"color":"ac6473","max":2,"desc":"停车时点击使用，消耗1份恢复10耐久。每箱最多2。"}
}
var CATALOG:Dictionary=BASE_CATALOG.duplicate(true)
const BASE_RECIPES = {
 "bench":{"cost":{"scrap":2},"bench":false},
 "bed":{"cost":{"scrap":2,"cloth":2},"bench":false},
 "shade":{"cost":{"scrap":2,"cloth":4},"bench":true},
 "generator":{"cost":{"scrap":3,"electronics":2},"bench":true},
 "cooler":{"cost":{"scrap":2,"electronics":2,"cloth":1},"bench":true},
 "armor":{"cost":{"scrap":3},"bench":true},
 "repair":{"cost":{"scrap":2,"cloth":1},"bench":true}
}
var RECIPES:Dictionary=BASE_RECIPES.duplicate(true)
const HEAT = [3,3,4,5,5,4,3]
const BASE_ROUTES = {
 "supply":{"name":"生活补给线","hint":"水6 / 粮4 / 油3；准备期安全，灾难期遭遇热兽。","loot":[["water",6],["food",4],["fuel",3]]},
 "salvage":{"name":"废车拆解线","hint":"金属4 / 布料3 / 弹药4；自动击退掠食兽。","loot":[["scrap",4],["cloth",3],["ammo",4]]},
 "tech":{"name":"电站遗址线","hint":"元件3 / 金属2 / 油4；遭遇守卫，首次学会发电机与制冷机图纸。","loot":[["electronics",3],["scrap",2],["fuel",4]]},
 "arms":{"name":"武装物资箱","hint":"弹药10 / 修理包1 / 布料2；装甲守卫，先战斗再开箱。","loot":[["ammo",10],["repair",1],["cloth",2]]}
}
var ROUTES:Dictionary=BASE_ROUTES.duplicate(true)
var width:int=4
var height:int=6
var floor_index:int=0
var items:Array=[]
var next_id:int=1
var logs:Array[String]=[]
var day:int=1
const DAY_MINUTES:float=360.0
const MINUTES_PER_SECOND:float=5.0
const CACHE_SPACING:float=20.0
const SITE_SPACING:float=60.0
var CACHE_LOOT:Array=[["water",2],["food",2],["fuel",1],["scrap",2],["ammo",3],["cloth",2]]
const SITE_ORDER=["salvage","tech","supply","arms"]
var minutes_left:float=DAY_MINUTES
var engine_level:int=0
var distance_km:float=0.0
var day_distance:float=0.0
var fuel_minutes:float=0.0
var next_cache:int=1
var next_site:int=1
var caches_today:int=0
var sites_today:int=0
var last_pickup:String=""
var pickup_serial:int=0
var members:Array=[]
var health:int=60
var max_health:int=60
var cooling_enabled:bool=true
var learned:Array[String]=["bench","bed","shade","armor","repair"]
var pending_route:String=""
var day_reports:Array[String]=[]
var variant:int=0
var phase:String="stop"
var hull:int=40
var max_hull:int=40
var route:String=""
var expansion_level:int=0
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
 var driver_id:int=add_item("driver",1,0,Vector2i(0,0))
 for x in range(1,4):add_item("seat",1,0,Vector2i(x,0))
 add_item("gun",1,0,Vector2i(0,2))
 add_item("ammo",10,0,Vector2i(1,2))
 add_item("water",6,0,Vector2i(2,2))
 add_item("food",6,0,Vector2i(3,2))
 add_item("fuel",8,0,Vector2i(0,4))
 add_item("scrap",4,0,Vector2i(1,4))
 var bed_id:int=add_item("bed",1,0,Vector2i(0,1))
 item_by_id(bed_id).rotated=true
 members=[{"id":1,"name":"主角","seat_id":driver_id}]
 choice_done=true
 note("目标：第1～14天准备，活过第15～21天的三日凌空。")
 note("每天6小时。速度决定行驶距离；每20km自动搜集，每60km发现大型地点。制作/探索各1小时，整理免费。")
 note("先上路搜集或搭建制作台；点击制作台可提升车速。电站探索可取得能源图纸。")

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

func seat_occupant(id:int)->String:
 for member in members:
  if member.seat_id==id:return member.name
 return ""

func rest_assignments()->Array:
 var beds:Array=items.filter(func(item):return item.floor==0 and item.kind=="bed")
 var assignments:Array=[]
 for i in range(mini(members.size(),beds.size())):
  assignments.append({"member":members[i].name,"bed_id":beds[i].id})
 return assignments

func bed_occupant(id:int)->String:
 for assignment in rest_assignments():
  if assignment.bed_id==id:return assignment.member
 return ""

func rest_recovery()->int:
 return 2 if not members.is_empty() and rest_assignments().size()==members.size() else 0

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

func placement_error(item:Dictionary,f:int,p:Vector2i,check_state:bool=true)->String:
 if check_state and not editable():return "行驶、战斗或结算时不能整理"
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
 if not editable() or hull>=max_hull or minutes_left<30:return false
 var item=item_by_id(id)
 if item.is_empty() or item.kind!="repair" or item.floor!=0:return false
 item.amount-=1
 if item.amount==0:items.erase(item)
 var gain:int=mini(10,max_hull-hull);hull+=gain;minutes_left-=30;note("使用修理包：耐久+%d，耗时30分钟"%gain)
 return true

func heat_on(d:int)->int:
 return HEAT[d-15] if d>=15 and d<=21 else 0

func discard_loose():
 for item in ground():metrics.discarded+=item.amount;items.erase(item)

func recipe_error(kind:String)->String:
 if not editable():return "当前无法制作"
 if not RECIPES.has(kind):return "未知配方"
 if minutes_left<float(RECIPES[kind].get("minutes",60)):return "今天剩余时间不足"
 if kind not in learned:return "尚未学会：探索电站遗址可保证获得图纸"
 if RECIPES[kind].bench and count_active("bench")==0:return "需要先把制作台装进车厢"
 for ingredient in RECIPES[kind].cost:
  if quantity(ingredient)<RECIPES[kind].cost[ingredient]:return "车内%s不足"%CATALOG[ingredient].name
 return ""

func craft(kind:String)->bool:
 var error:String=recipe_error(kind)
 if not error.is_empty():note(error);return false
 for ingredient in RECIPES[kind].cost:spend(ingredient,RECIPES[kind].cost[ingredient])
 minutes_left-=float(RECIPES[kind].get("minutes",60))
 add_item(kind,int(RECIPES[kind].get("amount",1)))
 note("制作完成：%s，已放在地面。请装车；耗时%d分钟。"%[CATALOG[kind].name,RECIPES[kind].get("minutes",60)])
 return true

func upgrade()->bool:
 if not editable() or minutes_left<60 or expansion_level>=2:return false
 if count_active("bench")==0:note("扩容需要车内制作台");return false
 var cost:int=6+2*expansion_level
 if not spend("scrap",cost):note("扩容需要车内%d金属"%cost);return false
 height+=2;expansion_level+=1;minutes_left-=60
 note("车厢扩容到4×%d；增加8格，耗时1小时。"%height)
 return true

func vehicle_speed()->int:
 return 40+20*engine_level

func time_text()->String:
 var minutes:int=ceili(minutes_left)
 return "%d小时%02d分"%[minutes/60,minutes%60]

func engine_error()->String:
 if not editable():return "停车后才能改装"
 if engine_level>=2:return "发动机已达本轮上限"
 if count_active("bench")==0:return "需要车内制作台"
 if minutes_left<60:return "今天不足1小时"
 if quantity("scrap")<4+engine_level*2:return "车内金属不足"
 return ""

func upgrade_engine()->bool:
 var error:String=engine_error()
 if not error.is_empty():note(error);return false
 spend("scrap",4+engine_level*2)
 engine_level+=1;minutes_left-=60
 note("发动机升级：%d km/h，同样时间驶过更远。耗时1小时。"%vehicle_speed())
 return true

func outing_error(_value:String="")->String:
 if not editable():return "当前无法出发"
 if members.is_empty():return "没有驾驶成员"
 var driver:Dictionary=item_by_id(members[0].seat_id)
 if driver.is_empty() or driver.floor!=0 or driver.kind!="driver":return "主角需要坐在驾驶位上才能出发"
 if minutes_left<=0.00001:return "今天时间已用完，请结束当天"
 if fuel_minutes<=0.00001:
  if quantity("fuel")<(2 if day>=15 else 1):return "燃油不足，可以驻车度过今天"
  if day>=15 and quantity("water")<1:return "高温行驶需要1水"
 return ""

func begin_journey(_value:String="",discard_ground:bool=false)->bool:
 var error:String=outing_error()
 if not error.is_empty():note(error);return false
 if not ground().is_empty() and not discard_ground:note("继续行驶会放弃待装物资，请先装车或确认");return false
 discard_loose()
 combat={};effects=[];phase="travel"
 note("继续行驶：%d km/h，今日剩余%s。"%[vehicle_speed(),time_text()])
 return true

func stop_driving():
 if phase!="travel":return
 phase="stop";note("靠边停车：整理不耗时，里程与已付燃油保留。")

func advance_travel(minutes:float):
 # Advance to exact distance/time boundaries. No event can be skipped by a large frame.
 var remaining:float=maxf(0,minutes)
 while phase=="travel" and remaining>0.000001:
  if distance_km+0.000001>=next_cache*CACHE_SPACING:
   collect_cache();continue
  if distance_km+0.000001>=next_site*SITE_SPACING:
   pending_route=SITE_ORDER[(next_site-1)%SITE_ORDER.size()]
   next_site+=1;phase="landmark"
   note("发现%s：可花1小时探索，也可略过。"%ROUTES[pending_route].name)
   break
  if minutes_left<=0.000001:
   minutes_left=0;phase="stop";note("今天6小时已用完，整理后结束当天。");break
  if fuel_minutes<=0.000001:
   var cost:int=2 if day>=15 else 1
   if quantity("fuel")<cost or (day>=15 and quantity("water")<1):
    phase="stop";note("行驶补给不足，已安全停车。可整理补给或结束当天。");break
   spend("fuel",cost);fuel_minutes=60
   if day>=15:
    spend("water",1);health=maxi(0,health-2)
    note("高温行驶预付1小时：2油、1水，暴晒健康−2。")
    if health==0:lose("高温行驶时主角倒下");break
  var to_event:float=(minf(next_cache*CACHE_SPACING,next_site*SITE_SPACING)-distance_km)*60.0/vehicle_speed()
  var step:float=minf(remaining,minf(minutes_left,minf(fuel_minutes,to_event)))
  distance_km+=step*vehicle_speed()/60.0;day_distance+=step*vehicle_speed()/60.0
  minutes_left=maxf(0,minutes_left-step);fuel_minutes=maxf(0,fuel_minutes-step);remaining-=step
  # Process reached events even when the supplied time ends exactly on a boundary.
  if distance_km+0.000001>=next_cache*CACHE_SPACING:collect_cache()
  if phase=="travel" and distance_km+0.000001>=next_site*SITE_SPACING:
   pending_route=SITE_ORDER[(next_site-1)%SITE_ORDER.size()];next_site+=1;phase="landmark"
   note("发现%s：可花1小时探索，也可略过。"%ROUTES[pending_route].name)
  if phase=="travel" and minutes_left<=0.000001:
   minutes_left=0;phase="stop";note("今天6小时已用完，整理后结束当天。")

func collect_cache():
 var loot:Array=CACHE_LOOT[(next_cache-1)%CACHE_LOOT.size()]
 next_cache+=1;caches_today+=1;pickup_serial+=1
 var stored:int=store_generated(loot[0],loot[1])
 var overflow:int=int(loot[1])-stored
 last_pickup="%s +%d入舱"%[CATALOG[loot[0]].name,stored]
 if overflow>0:
  add_item(loot[0],overflow);phase="stop"
  last_pickup+=" · %d待装，已停车"%overflow
 note("沿途宝箱："+last_pickup)

func site_error()->String:
 if phase!="landmark" or pending_route.is_empty():return "没有待探索地点"
 if minutes_left+0.00001<60:return "探索需要1小时，今日时间不足"
 return ""

func explore_site()->bool:
 var error:String=site_error()
 if not error.is_empty():note(error);return false
 minutes_left=maxf(0,minutes_left-60);sites_today+=1
 if pending_route=="supply" and day<15:
  phase="stop";grant_loot()
 else:start_battle("heavy" if pending_route=="arms" else "swarm")
 return true

func skip_site()->bool:
 if phase!="landmark":return false
 note("略过%s，继续赶路。"%ROUTES[pending_route].name)
 pending_route="";phase="stop"
 if minutes_left>0:begin_journey()
 return true

func grant_loot():
 if pending_route.is_empty():return
 var chosen:Dictionary=ROUTES[pending_route]
 for pair in chosen.loot:add_item(pair[0],pair[1])
 if pending_route=="tech" and "cooler" not in learned:
  learned.append("generator");learned.append("cooler")
  note("学会图纸：发电机、制冷机。图纸收录配方册，不占车格。")
 note("打开%s物资箱：战利品在地面，装车后可使用。"%chosen.name)
 pending_route=""

func night_plan(d:int,available_fuel:int)->Dictionary:
 var heat:int=heat_on(d)
 var shade:int=2 if count_active("shade")>0 else 0
 var powered:bool=heat>0 and cooling_enabled and count_active("cooler")>0 and count_active("generator")>0 and available_fuel>0
 var residual:int=maxi(0,heat-shade-(3 if powered else 0))
 return {"heat":heat,"residual":residual,"water":1+ceili(residual/2.0),"food":1,"fuel":1 if powered else 0,"damage":residual*4,"powered":powered}

func forecast()->Dictionary:
 # Intentionally assumes no future exploration, production or changes in layout.
 var result={"water":0,"food":0,"fuel":0,"damage":0,"from":maxi(15,day),"cooling_nights":0}
 var oil:int=quantity("fuel")
 var water:int=quantity("water")
 var food:int=quantity("food")
 var projected:int=health
 for d in range(maxi(15,day),22):
  var plan:Dictionary=night_plan(d,oil)
  oil-=int(plan.fuel)
  for kind in ["water","food","fuel","damage"]:result[kind]+=int(plan[kind])
  if plan.powered:result.cooling_nights+=1
  var loss:int=int(plan.damage)+maxi(0,int(plan.water)-water)*6+maxi(0,1-food)*4
  water=maxi(0,water-int(plan.water));food=maxi(0,food-1)
  if projected>0:projected=maxi(0,mini(max_health,projected-loss+(rest_recovery() if loss==0 else 0)))
 result.water_gap=maxi(0,int(result.water)-quantity("water"))
 result.food_gap=maxi(0,int(result.food)-quantity("food"))
 result.health_loss=maxi(0,health-projected)
 result.projected_health=projected
 return result

func departure_error()->String:
 return "当前无法结束当天" if not editable() else ""

func depart(discard_ground:bool=false)->bool:
 # Kept as the UI's end-day entrypoint; one settlement only, never per rearrangement.
 if not editable():return false
 if not ground().is_empty() and not discard_ground:note("结束当天将离开停靠点，请先装车或确认放弃地面物资");return false
 discard_loose()
 produce()
 var plan:Dictionary=night_plan(day,quantity("fuel"))
 spend("fuel",plan.fuel)
 var loss:int=plan.damage
 var shortages:PackedStringArray=[]
 for kind in ["water","food"]:
  var paid:int=mini(quantity(kind),int(plan[kind]))
  spend(kind,paid)
  var missing:int=int(plan[kind])-paid
  if missing>0:
   loss+=missing*(6 if kind=="water" else 4)
   shortages.append("缺%s%d"%[CATALOG[kind].name,missing])
 var recovered:int=mini(rest_recovery(),maxi(0,max_health-health)) if loss==0 else 0
 health=maxi(0,mini(max_health,health-loss+recovered))
 var summary:String="第%d天：耗水%d / 粮1 / 制冷油%d；余热%d，热伤%d，健康损失%d%s"%[day,plan.water,plan.fuel,plan.residual,plan.damage,loss,"；"+"、".join(shortages) if not shortages.is_empty() else ""]
 var resting:Array=rest_assignments()
 summary+="；%s，休息恢复%d"%["主角在单人床休息" if not resting.is_empty() else "没有可用床位",recovered]
 summary+="；行驶%.1fkm，宝箱%d个，探索%d处"%[day_distance,caches_today,sites_today]
 day_reports.append(summary);note(summary);last_report=summary
 if health<=0:lose("乘员无法继续："+summary);return true
 if day==21:
  won=true;phase="ended";outcome="挺过三日凌空！第一个21天周期完成。"
  note(outcome);return true
 day+=1;minutes_left=DAY_MINUTES;day_distance=0;caches_today=0;sites_today=0;combat={};effects=[]
 if day==15:fuel_minutes=0
 note("第%d天 / %s：%s"%[day,"准备期" if day<=14 else "炎热地狱","距离灾难%d天"%(15-day) if day<=14 else "行驶每小时2油/1水，暴晒健康-2"])
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
     if placement_error(candidate,0,Vector2i(x,y),false).is_empty():
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
    if placement_error(candidate,0,Vector2i(x,y),false).is_empty():return true
 return false

func produce():
 if count_active("collector")>0:
  var expected:int=1 if day<15 else 0
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
  enemies.append(enemy("热浪掠食兽" if day>=15 else "公路掠食兽",18 if day>=15 else 12,0,3 if day>=15 else 2,3))
 elif kind=="heavy":enemies.append(enemy("装甲物资守卫",30 if day>=15 else 24,1,4 if day>=15 else 3,3))
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

func weapon_has_ammo(_weapon:Dictionary,cost:int)->bool:
 return quantity("ammo")>=cost

func weapon_ammo_cost(weapon:Dictionary)->int:
 return 1 if weapon.kind=="gun" else 2

func spend_weapon_ammo(_weapon:Dictionary,cost:int)->bool:
 return spend("ammo",cost)

func combat_step():
 if phase!="combat":return
 combat.tick+=1;effects=[]
 for weapon in items.duplicate():
  if weapon.floor!=0 or weapon.kind not in ["gun","cannon"]:continue
  var interval:int=2 if weapon.kind=="gun" else 4
  if combat.tick%interval!=0:continue
  var index:int=first_enemy()
  if index<0:break
  var ammo_cost:int=weapon_ammo_cost(weapon)
  if not spend_weapon_ammo(weapon,ammo_cost):
   effects.append({"type":"dry","id":weapon.id,"target":index})
   if not combat.dry_warned:note("可用弹药不足：武器停火；检查弹匣与补给。每3拍应急撞击，车体也会受损。");combat.dry_warned=true
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
 var can_shoot:bool=false
 for weapon in items:
  if weapon.floor==0 and weapon.kind in ["gun","cannon"] and weapon_has_ammo(weapon,weapon_ammo_cost(weapon)):can_shoot=true
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
 last_report=report_battle();battle_reports.append("第%d天：%s"%[day,last_report])
 for key in ["shots","ammo","blocked","damage"]:metrics[key]+=combat[key]

func end_battle():
 record_battle();phase="stop"
 note("战斗胜利。"+last_report.replace("\n","；"))
 grant_loot()

func lose(reason:String):
 if phase=="combat":record_battle()
 phase="ended";hull=maxi(0,hull);outcome="旅程结束："+reason;note(outcome)

func description()->String:
 return "第%d天 · 剩余%s · %d km/h · %.1f km"%[day,time_text(),vehicle_speed(),distance_km]

func note(message:String):
 logs.push_front(message)
 if logs.size()>120:logs.resize(120)
