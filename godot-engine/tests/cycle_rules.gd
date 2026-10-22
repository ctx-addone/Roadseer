extends SceneTree
const Model=preload("res://scripts/vehicle_state.gd")
var failures:int=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func fit(m,id:int)->bool:
 var item=m.item_by_id(id)
 if item.is_empty():return true
 if m.CATALOG[item.kind].has("max"):
  for target in m.items.duplicate():
   if target.floor==0 and target.kind==item.kind:
    m.merge_at(id,target.pos);item=m.item_by_id(id)
    if item.is_empty():return true
 for rotation in [false,true]:
  var candidate=item.duplicate();candidate.rotated=rotation
  for y in range(m.height):
   for x in range(m.width):
    if m.placement_error(candidate,0,Vector2i(x,y)).is_empty():return m.place(id,0,Vector2i(x,y),rotation)
 return false
func pack(m):
 for item in m.items.duplicate():
  if item.floor==0 and not m.CATALOG[item.kind].get("fixed",false):m.drop(item.id)
 for kind in ["bed","bench","shade","cooler","generator","armor","gun","fuel","food","water","ammo","scrap","cloth","electronics","repair"]:
  for item in m.ground().duplicate():
   if item.kind!=kind:continue
   # Carry at most two water crates and one crate of other materials; leave surplus visibly on ground.
   if m.CATALOG[kind].has("max") and m.count_active(kind)>=(2 if kind=="water" else 1):
    for target in m.items.duplicate():
     if target.floor==0 and target.kind==kind:m.merge_at(item.id,target.pos)
   else:fit(m,item.id)
func battle(m):
 var ticks:int=0
 while m.phase=="combat" and ticks<100:m.combat_step();ticks+=1
 check(ticks<100,"battle terminates")
func outing(m,route:String):
 check(m.explore(route,true),"outing %d %s"%[m.day,route]);battle(m);pack(m)
func craft(m,kind:String):
 check(m.craft(kind),"craft day%d %s: %s"%[m.day,kind,m.recipe_error(kind)]);pack(m)
func play(powered:bool,stop_day:int=22):
 var m=Model.new()
 while m.editable() and m.day<stop_day:
  match m.day:
   1:craft(m,"bench");outing(m,"salvage")
   2:
    check(m.upgrade(),"first expansion");pack(m);outing(m,"salvage")
   3:
    outing(m,"tech" if powered else "salvage");craft(m,"generator" if powered else "shade")
   4:
    outing(m,"tech" if powered else "salvage")
    if powered:craft(m,"cooler")
    else:check(m.upgrade(),"passive second expansion");pack(m)
   5,6:
    outing(m,"salvage")
    if powered and m.expansion_level<2 and m.quantity("scrap")>=8:check(m.upgrade(),"power second expansion");pack(m)
    elif m.count_active("armor")==0 and m.quantity("scrap")>=3:craft(m,"armor")
   _:
    if m.day<15:outing(m,"supply")
  for item in m.items.duplicate():
   if item.kind=="repair" and item.floor==0:m.use_repair(item.id)
  if m.day==14:print("PREP power=",powered," health=",m.health," hull=",m.hull," forecast=",m.forecast())
  check(m.count_active("bed")==1,"bed kept installed throughout journey")
  check(m.depart(true),"end day")
  if m.phase=="ended":break
 print("RESULT powered=",powered," day=",m.day," health=",m.health," hull=",m.hull," ",m.outcome)
 if stop_day==22:check(m.won,"legal 21-day route survives")
 return m
func run():
 var initial=Model.new()
 var snapshot=initial.items.duplicate(true)
 check(not initial.craft("cooler"),"unknown blueprint rejected")
 check(initial.items==snapshot and initial.actions==2,"failed craft is atomic")
 check(not initial.place(5,0,Vector2i(0,0),false),"overlap rejected")
 check(initial.items==snapshot,"failed placement preserves inventory")
 var f=initial.forecast();check(initial.items==snapshot and initial.day==1,"forecast is pure")
 check(f.damage==108,"naked heat preview")
 craft(initial,"bench")
 check(initial.actions==1 and initial.count_active("bench")==1,"bench crafted and installed")
 initial.add_item("cloth",2)
 check(not initial.depart() and initial.day==1,"ground confirmation required for end day")
 check(not initial.explore("salvage") and initial.actions==1,"ground confirmation required for outing")
 check(initial.explore("salvage",true),"outing")
 check(not initial.drop(5) and not initial.craft("repair"),"combat locks changes")
 battle(initial)
 check(not initial.explore("supply",true),"one outing per day")
 check(initial.actions==0,"craft and outing exhaust actions")
 check(not initial.craft("bench"),"no unlimited daily craft")
 var passive=play(false)
 var powered=play(true)
 var emergency=play(true,15)
 # Spend actual stored supplies to force a real post-day-15 resupply decision.
 emergency.spend("water",emergency.quantity("water")-1)
 var before_health:int=emergency.health
 var before_oil:int=emergency.quantity("fuel")
 outing(emergency,"supply")
 check(emergency.health==before_health-2,"heat exposure")
 check(emergency.quantity("fuel")==mini(12,before_oil-2+3),"heat fuel charge and loot")
 check(emergency.quantity("water")>=6,"emergency water recovered")
 check(emergency.depart(true),"emergency day ends")
 outing(emergency,"salvage")
 check(emergency.craft("repair"),"emergency craft allowed with actual gathered ingredients")
 pack(emergency)
 for item in emergency.items.duplicate():
  if item.kind=="repair" and item.floor==0:emergency.use_repair(item.id)
 while emergency.editable():
  if not emergency.explored and emergency.quantity("water")<4:outing(emergency,"supply")
  emergency.depart(true)
 check(emergency.won,"emergency recovery survives remaining disaster")
 var dry=play(true,15)
 dry.spend("fuel",dry.quantity("fuel"))
 check(not dry.night_plan(15,0).powered and dry.night_plan(15,0).damage==12,"cooler stops without fuel")
 check(not dry.explore("supply",true),"zero fuel blocks outing without instant defeat")
 check(dry.depart(true) and dry.day==16,"zero fuel allows camping")
 var unprepared=Model.new()
 while unprepared.editable() and unprepared.day<15:
  outing(unprepared,"supply");unprepared.depart(true)
 check(unprepared.health==60 and unprepared.quantity("water")>=23,"unprotected scenario is fully provisioned")
 while unprepared.editable():unprepared.depart(true)
 check(not unprepared.won and unprepared.day>=15 and "热伤" in unprepared.outcome,"heat alone causes explained failure")
 var dry_ammo=Model.new();dry_ammo.spend("ammo",10)
 outing(dry_ammo,"arms")
 check(dry_ammo.hull<20 and dry_ammo.metrics.ammo==0,"dry weapons use costly finite emergency ramming")
 var stacked=Model.new();var extra=stacked.add_item("water",10)
 check(stacked.merge_at(extra,Vector2i(2,2)),"stack merge")
 check(stacked.quantity("water")==12 and stacked.item_by_id(extra).amount==4,"overflow retained")
 var before=stacked.items.duplicate(true)
 check(not stacked.place(extra,0,Vector2i(4,6),false) and stacked.items==before,"out of bounds preserves cargo")
 print("CYCLE VERIFICATION failures=",failures)
 quit(1 if failures else 0)
