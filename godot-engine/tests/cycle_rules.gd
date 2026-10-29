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
func run():
 var m=Model.new()
 var before=m.items.duplicate(true)
 check(not m.craft("cooler") and m.items==before and m.minutes_left==360,"failed craft atomic")
 check(not m.place(5,0,Vector2i.ZERO,false) and m.items==before,"overlap preserves cargo")
 check(m.forecast().damage==108 and m.items==before,"forecast pure")
 check(m.craft("bench"),"craft workbench");pack(m)
 check(m.count_active("bench")==1 and m.minutes_left==300,"bench installed and costs hour")
 for d in range(1,4):
  var steps:int=0
  while m.minutes_left>60 and m.outcome.is_empty() and steps<1000:
   steps+=1
   if m.phase=="landmark":
    if m.pending_route in ["salvage","tech"] and m.minutes_left>=120:m.explore_site()
    else:m.skip_site()
   elif m.phase=="combat":battle(m);pack(m)
   elif m.editable():
    pack(m)
    if m.expansion_level<2 and m.quantity("scrap")>=6+2*m.expansion_level:
     check(m.upgrade(),"expand using gathered metal");pack(m)
    if not m.begin_journey("",true):break
   else:m.advance_travel(5)
  if m.phase=="travel":m.stop_driving()
  if m.phase=="landmark":m.skip_site();m.stop_driving()
  if m.phase=="combat":battle(m)
  pack(m)
  check(m.depart(true),"settle legal early day")
 check(m.day==4 and m.distance_km>120 and "cooler" in m.learned,"three-day driving/crafting/tech loop")
 print("EARLY LOOP day=",m.day," km=",m.distance_km," hull=",m.hull," height=",m.height)
 # Explicit configured disaster fixtures: verify settlement arithmetic, not a full-run solution.
 for bed in [true,false]:
  m=Model.new();m.height=16;m.day=15;m.health=30
  if not bed:m.drop(11);m.discard_loose()
  for kind in ["generator","cooler","shade"]:
   var id:int=m.add_item(kind);check(fit(m,id),"fixture equipment fits")
  for pair in [["water",24],["food",12],["fuel",12]]:m.store_generated(pair[0],pair[1])
  var inventory=m.items.duplicate(true)
  var forecast=m.forecast()
  check(m.items==inventory,"forecast never consumes inventory")
  for d in range(15,22):check(m.depart(true),"night settlement")
  check(m.won and m.health==forecast.projected_health,"seven nights match forecast")
  var ended=m.items.duplicate(true)
  check(not m.depart(true) and m.items==ended,"ended run cannot settle twice")
 m=Model.new();m.day=15;m.spend("fuel",8)
 check(not m.begin_journey() and m.depart(),"no fuel still permits camp")
 print("CYCLE VERIFICATION failures=",failures)
 quit(1 if failures else 0)
