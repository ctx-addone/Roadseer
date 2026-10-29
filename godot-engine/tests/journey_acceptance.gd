extends SceneTree
const Model=preload("res://scripts/vehicle_state.gd")
var failures:int=0
func check(ok:bool,why:String):
 if not ok:failures+=1;push_error(why)
func drive_day(level:int,step:float):
 var m=Model.new();m.engine_level=level;m.height=40
 m.store_generated("fuel",24)
 m.begin_journey()
 var guard:int=0
 while guard<10000:
  guard+=1
  if m.phase=="landmark":m.skip_site()
  elif m.phase=="travel":m.advance_travel(step)
  else:break
 check(guard<10000,"simulation terminates")
 return m
func _initialize():
 for level in [0,1,2]:
  var m=drive_day(level,7)
  var n=drive_day(level,0.37)
  check(is_equal_approx(m.distance_km,240+120*level),"six-hour distance follows real speed")
  check(m.caches_today==12+6*level,"faster car finds more distance-based boxes")
  check(is_equal_approx(m.distance_km,n.distance_km) and m.caches_today==n.caches_today and m.quantity("fuel")==n.quantity("fuel"),"frame size and playback cannot alter rewards")
  print("SPEED ",m.vehicle_speed()," km/h: ",m.distance_km," km, boxes=",m.caches_today)
 var m=Model.new()
 m.begin_journey();m.advance_travel(15);m.stop_driving()
 check(m.quantity("fuel")==7 and m.fuel_minutes==45,"hour prepaid once")
 var time:float=m.minutes_left
 for i in range(5):m.begin_journey();m.stop_driving()
 check(m.quantity("fuel")==7 and m.minutes_left==time and m.distance_km==10,"stop/resume does not consume fuel/time or award loot")
 m.begin_journey();m.advance_travel(15)
 check(m.caches_today==1 and m.quantity("water")==8 and m.minutes_left==330,"exact boundary auto collects")
 m.stop_driving();m.depart()
 check(m.distance_km==20 and m.next_cache==2 and m.minutes_left==360 and m.fuel_minutes==30,"day reset preserves distance and prepaid fuel")
 m.begin_journey();m.advance_travel(15)
 check(m.quantity("fuel")==7 and m.caches_today==0,"next day cannot refarm prior box")
 m=Model.new();m.height=4 # Full legal four-row grid without starter items below it.
 for item in m.items.duplicate():
  if item.pos.y>=4:m.items.erase(item)
 m.item_by_id(7).amount=11
 m.add_item("fuel",3,0,Vector2i(2,1));m.item_by_id(m.next_id-1).rotated=true
 check(m.used_cells()==16,"overflow fixture completely full")
 m.begin_journey();m.advance_travel(30)
 check(m.phase=="stop" and m.quantity("water")==12 and m.ground().size()==1 and m.ground()[0].amount==1,"partial merge retains overflow and stops")
 var snapshot=m.items.duplicate(true)
 check(not m.begin_journey() and m.items==snapshot,"loose cargo requires explicit discard")
 check(m.begin_journey("",true),"confirmed discard permits departure")
 m.advance_travel(1)
 check(m.caches_today==1,"resuming overflow cannot duplicate box")
 m=Model.new();m.begin_journey();m.advance_travel(90)
 check(m.phase=="landmark" and m.pending_route=="salvage" and m.distance_km==60,"site reached from actual distance")
 time=m.minutes_left
 check(m.explore_site() and m.minutes_left==time-60 and m.phase=="combat","site charges one hour including battle")
 check(not m.explore_site(),"site cannot charge twice")
 while m.phase=="combat":m.combat_step()
 check(m.ground().size()==3,"battle yields three physical stacks")
 snapshot=m.items.duplicate(true);m.combat_step()
 check(m.items==snapshot,"battle cannot reward twice")
 m=Model.new();m.begin_journey();m.advance_travel(90);m.minutes_left=59
 check(not m.explore_site() and m.minutes_left==59,"insufficient site time is atomic")
 check(m.skip_site() and m.phase=="travel" and m.next_site==2,"skip continues without charge")
 m=Model.new();m.spend("fuel",7);m.begin_journey();m.advance_travel(120)
 check(m.phase=="stop" and m.distance_km==40 and m.minutes_left==300,"runs out of fuel exactly after purchased hour")
 m=Model.new();m.day=15;m.health=2;m.begin_journey();m.advance_travel(10)
 check(m.phase=="ended" and m.distance_km==0 and m.caches_today==0,"heat death cannot move or collect")
 m=Model.new();m.day=15;m.begin_journey();m.advance_travel(15);m.stop_driving()
 check(m.quantity("fuel")==6 and m.quantity("water")==5 and m.health==58,"heat hourly charge")
 m.begin_journey();m.advance_travel(1)
 check(m.health==58 and m.quantity("fuel")==6,"restarting in heat cannot double charge")
 m=Model.new();m.day=14;m.begin_journey();m.advance_travel(10);m.stop_driving();m.depart()
 check(m.day==15 and m.fuel_minutes==0,"heat cannot reuse cool-day fuel allowance")
 m=Model.new();m.height=10;m.add_item("bench",1,0,Vector2i(0,6));m.store_generated("scrap",10)
 check(m.upgrade_engine() and m.vehicle_speed()==60 and m.minutes_left==300,"engine upgrade consumes resources/time")
 check(m.upgrade_engine() and m.vehicle_speed()==80,"second engine upgrade")
 snapshot=m.items.duplicate(true);time=m.minutes_left
 check(not m.upgrade_engine() and m.items==snapshot and m.minutes_left==time,"engine cap is atomic")
 m.minutes_left=59;snapshot=m.items.duplicate(true)
 check(not m.craft("bench") and m.items==snapshot and m.minutes_left==59,"craft requires full hour")
 m=Model.new();m.add_item("repair",1,0,Vector2i(2,1));m.hull=30
 check(m.use_repair(m.next_id-1) and m.minutes_left==330 and m.hull==40,"repair consumes half hour")
 print("JOURNEY ACCEPTANCE failures=",failures)
 quit(1 if failures else 0)
