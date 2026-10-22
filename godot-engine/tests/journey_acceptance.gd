extends "res://tests/cycle_rules.gd"
## Additional acceptance cases for the staged journey and sleep forecast.
func state_of(m)->Dictionary:
 return {"items":m.items.duplicate(true),"day":m.day,"actions":m.actions,"health":m.health,"phase":m.phase,"combat":m.combat.duplicate(true)}
func run():
 for day_number in [1,15]:
  for key in Model.ROUTES:
   var m=Model.new();m.day=day_number
   check(m.begin_journey(key),"departure %d %s"%[day_number,key])
   check(m.phase=="travel" and not m.editable(),"travel locks inventory")
   check(m.actions==1 and m.quantity("fuel")==8-(2 if day_number==15 else 1),"journey charges once")
   check(m.quantity("water")==6-(1 if day_number==15 else 0),"heat water cost")
   var before:Dictionary=state_of(m)
   check(not m.begin_journey(key) and not m.depart() and not m.collect_encounter(),"invalid transitions rejected")
   check(state_of(m)==before,"repeated departure preserves resources and state")
   m.arrive()
   before=state_of(m);m.arrive()
   check(state_of(m)==before,"arrival is not applied twice")
   if day_number==1 and key=="supply":
    check(m.phase=="encounter" and m.ground().is_empty(),"safe crate waits for interaction")
    check(m.collect_encounter(),"safe crate collects")
   else:
    check(m.phase=="combat","hostile route starts combat")
    var ticks:int=0
    while m.phase=="combat" and ticks<100:m.combat_step();ticks+=1
    check(m.phase=="stop","hostile route completes")
   check(m.ground().size()==3,"one set of three physical rewards")
   for reward in Model.ROUTES[key].loot:
    var total:int=0
    for item in m.ground():
     if item.kind==reward[0]:total+=item.amount
    check(total==reward[1],"exact route reward amount")
   before=state_of(m);m.arrive();m.collect_encounter();m.combat_step()
   check(state_of(m)==before,"completed encounter cannot duplicate rewards")
   if key=="tech":check("generator" in m.learned and "cooler" in m.learned,"technology blueprints awarded")
 var lethal=Model.new();lethal.day=15;lethal.health=2
 check(lethal.begin_journey("supply") and lethal.phase=="ended","fatal heat exposure terminates journey")
 lethal.arrive();lethal.collect_encounter()
 check(lethal.ground().is_empty(),"failed journey cannot grant loot")
 for keep_bed in [true,false]:
  var m=play(true,15)
  if not keep_bed:
   for item in m.items.duplicate():
    if item.kind=="bed":m.drop(item.id)
  var expected:Dictionary=m.forecast()
  var snapshot:Dictionary=state_of(m)
  m.forecast()
  check(state_of(m)==snapshot,"forecast does not mutate state")
  while m.editable():m.depart(true)
  check(m.health==expected.projected_health,"sleep forecast matches seven actual night settlements")
  print("SLEEP FORECAST bed=",keep_bed," predicted=",expected.projected_health," actual=",m.health)
 print("JOURNEY ACCEPTANCE failures=",failures)
 quit(1 if failures else 0)
