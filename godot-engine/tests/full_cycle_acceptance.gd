extends "res://tests/cycle_rules.gd"
## Normal starting model; no resource, time, health, equipment or blueprint injection.
var ledger:Array=[]

func pack(m):
 for item in m.items.duplicate():
  if item.floor==0 and not m.CATALOG[item.kind].get("fixed",false):m.drop(item.id)
 for kind in ["bed","bench","shade","cooler","generator","armor","gun","fuel","food","water","ammo","scrap","cloth","electronics","repair"]:
  for item in m.ground().duplicate():
   if item.kind!=kind:continue
   if m.CATALOG[kind].has("max") and m.count_active(kind)>=(2 if kind in ["water","food"] else 1):
    for target in m.items.duplicate():
     if target.floor==0 and target.kind==kind:m.merge_at(item.id,target.pos)
   else:fit(m,item.id)

func equipped(m, kind:String)->bool:
 return m.count_active(kind)>0

func ready(m, cooling:bool)->bool:
 if not equipped(m,"shade"):return false
 if cooling and (not equipped(m,"generator") or not equipped(m,"cooler")):return false
 var forecast:Dictionary=m.forecast()
 var preparation:int=maxi(0,15-m.day)
 return m.quantity("water")>=preparation+forecast.water and m.quantity("food")>=preparation+forecast.food and m.quantity("fuel")>=forecast.fuel

func improve(m, cooling:bool)->bool:
 if m.expansion_level<2 and m.upgrade():return true
 for kind in (["shade","generator","cooler"] if cooling else ["shade"]):
  if not equipped(m,kind) and m.recipe_error(kind).is_empty():
   check(m.craft(kind),"legal craft "+kind)
   pack(m)
   check(equipped(m,kind),"crafted equipment installed "+kind)
   return true
 if m.engine_level<2 and m.upgrade_engine():return true
 if m.hull<=30:
  for item in m.items.duplicate():
   if item.floor==0 and item.kind=="repair" and m.use_repair(item.id):return true
  if m.recipe_error("repair").is_empty():
   m.craft("repair");pack(m)
   return true
 return false

func record_day(m, strategy:String, before:Dictionary):
 ledger.append({"strategy":strategy,"settled_day":m.day_reports.size(),"next_day":m.day,"start":before,"km":m.distance_km,"minutes_left":m.minutes_left,"health":m.health,"hull":m.hull,"water":m.quantity("water"),"food":m.quantity("food"),"fuel":m.quantity("fuel"),"ammo":m.quantity("ammo"),"scrap":m.quantity("scrap"),"cloth":m.quantity("cloth"),"electronics":m.quantity("electronics"),"shade":equipped(m,"shade"),"generator":equipped(m,"generator"),"cooler":equipped(m,"cooler"),"forecast":m.forecast(),"report":m.last_report})

func legal_layout(m):
 for item in m.items:
  if item.floor==0:
   check(m.placement_error(item,0,item.pos).is_empty(),"daily layout valid")
   check(item.amount>0 and item.amount<=int(m.CATALOG[item.kind].get("max",1)),"daily stack bounds")
 check(m.minutes_left>=0 and m.minutes_left<=360,"daily time bounds")

func run():
 for cooling in [false,true]:
  var strategy:String="powered_cooling" if cooling else "passive_insulation"
  var m=Model.new()
  check(m.craft("bench"),"normal opening workbench")
  pack(m)
  for day_index in range(1,22):
   check(m.day==day_index and m.outcome.is_empty(),strategy+" starts day "+str(day_index))
   if not m.outcome.is_empty():break
   var before:Dictionary={"health":m.health,"hull":m.hull,"km":m.distance_km,"water":m.quantity("water"),"food":m.quantity("food"),"fuel":m.quantity("fuel")}
   var guard:int=0
   while m.minutes_left>0 and m.outcome.is_empty() and guard<2000:
    guard+=1
    if m.phase=="combat":battle(m);pack(m)
    elif m.phase=="landmark":
     var site:String=m.pending_route
     var wanted:bool=site=="supply" or (site=="tech" and (m.quantity("fuel")<10 or (cooling and not equipped(m,"cooler")))) or (site=="salvage" and (not equipped(m,"shade") or m.quantity("ammo")<4))
     if wanted and m.minutes_left>=60:m.explore_site()
     else:m.skip_site()
    elif m.editable():
     pack(m)
     if improve(m,cooling):continue
     if ready(m,cooling):break
     if not m.begin_journey("",true):break
    else:m.advance_travel(5)
   check(guard<2000,"day simulation terminates")
   if m.phase=="travel":m.stop_driving()
   if m.phase=="landmark":m.skip_site();m.stop_driving()
   if m.phase=="combat":battle(m)
   pack(m)
   legal_layout(m)
   check(m.depart(true),strategy+" night "+str(day_index))
   record_day(m,strategy,before)
   print(strategy," NIGHT ",day_index," health=",m.health," hull=",m.hull," water=",m.quantity("water")," food=",m.quantity("food")," fuel=",m.quantity("fuel")," km=",m.distance_km)
   if not m.outcome.is_empty():break
  check(m.won and m.day==21,strategy+" full 21-day victory")
  check(m.day_reports.size()==21,"exactly 21 settlements")
  check(equipped(m,"shade") and (equipped(m,"cooler") and equipped(m,"generator") if cooling else not equipped(m,"cooler")),"distinct installed anti-disaster strategies")
  var terminal_items:Array=m.items.duplicate(true)
  check(not m.depart(true) and m.items==terminal_items,"terminal state cannot settle again")
 var output:String=OS.get_environment("ROADSEER_TEST_OUTPUT_DIR")
 if not output.is_empty():
  DirAccess.make_dir_recursive_absolute(output)
  var file=FileAccess.open(output.path_join("full-cycle-ledger.json"),FileAccess.WRITE)
  check(file!=null,"ledger writable")
  if file!=null:file.store_string(JSON.stringify(ledger,"  "))
 print("FULL CYCLE ACCEPTANCE failures=",failures)
 quit(1 if failures else 0)
