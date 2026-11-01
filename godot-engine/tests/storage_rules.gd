extends SceneTree
const Model=preload("res://scripts/storage_state.gd")
var failures:int=0
var checks:int=0

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)

func goods(m,kind:String)->int:
 var count:int=0
 for item in m.items:
  if item.kind==kind:count+=item.amount
 return count

func _initialize():
 var m=Model.new()
 check(m.items.size()==11 and m.quantity("ammo")==30,"normal starting cargo, ammo converted to rounds")
 check(m.footprint(m.item_by_id(6))==Vector2i.ONE,"small ammo package")
 check(m.quantity("wood")==0 and m.quantity("plank")==0,"no free crafting materials")
 m.begin_journey();m.advance_travel(30);m.stop_driving()
 check(m.distance_km==20 and m.quantity("wood")==3,"first road pallet supplies legitimate wood")
 for i in range(3):check(m.craft("plank"),"process wood into boards")
 check(m.quantity("wood")==0 and m.quantity("plank")==12 and m.minutes_left==300,"3 logs to 12 planks with processing time")
 check(m.craft("bench"),"craft wooden workbench")
 var bench:int=m.next_id-1
 check(m.place(10,0,Vector2i(1,4),true),"rotate metal to make workbench space")
 check(m.place(bench,0,Vector2i(2,4),false),"workbench installs in legal free space")
 if failures>0:quit(1);return
 check(m.craft("chest"),"craft first nine-slot chest from remaining boards")
 var chest:int=m.next_id-1
 check(m.place(chest,0,Vector2i(2,0),false),"small box mounts empty seat")
 check(m.cargo_on_seat(3).id==chest and m.used_cells()<=24,"seat load shares one footprint")
 check(m.place(3,0,Vector2i(3,1),false) and m.item_by_id(chest).pos==Vector2i(3,1),"moving seat carries its box")
 check(not m.place(chest,0,Vector2i.ZERO,false),"driver seat unavailable for cargo")
 check(m.place(chest,0,Vector2i(2,0),false),"box detaches from moved seat")
 var ammo:int=6
 var total:int=goods(m,"ammo")
 check(m.insert(ammo,chest)==30 and goods(m,"ammo")==total and m.quantity("ammo")==30,"insert conserves ammo and global reserve")
 check(m.slots_used(chest)==1,"ammo stack uses one slot")
 check(m.insert(chest,chest)==0 and m.insert(bench,chest)==0,"no recursive containers or equipment inside")
 var second_box:int=m.add_item("chest")
 check(m.insert(second_box,chest)==0,"no box inside another box")
 # Use explicit fixtures below to isolate full/partial capacity and transactional rejection.
 for i in range(4):
  var id:int=m.add_item("water",6)
  check(m.insert(id,chest)==6,"two-slot water groups fit")
 check(m.slots_used(chest)==9,"nine-slot volume limit reached")
 var extra:int=m.add_item("food",6)
 check(m.insert(extra,chest)==0 and m.item_by_id(extra).floor==-1,"full box retains rejected stack")
 var water_id:int=m.contents(chest)[1].id
 check(m.unload(water_id) and m.item_by_id(water_id).floor==-1 and m.slots_used(chest)==7,"unload frees actual volume")
 check(m.insert(extra,chest)==6,"freed capacity reusable")
 check(m.drop(chest) and m.quantity("ammo")==0,"ground container cannot supply carried inventory")
 check(m.place(chest,0,Vector2i(1,2),false) and m.quantity("ammo")==30,"loaded box remount preserves contents")
 var weapon:Dictionary=m.item_by_id(5)
 check(m.reachable_ammo(weapon)==30,"common-edge box is reachable")
 check(m.place(chest,0,Vector2i(3,0),false) and m.reachable_ammo(weapon)==0,"distant reserve does not auto supply")
 check(not m.spend_weapon_ammo(weapon,3),"empty magazine cannot shoot from distant reserve")
 check(m.reload_weapon(5) and int(weapon.loaded)==18 and m.quantity("ammo")==12,"manual load transfers 18 existing rounds")
 for i in range(6):check(m.spend_weapon_ammo(weapon,3),"magazine supports six bursts")
 check(not m.spend_weapon_ammo(weapon,3) and m.quantity("ammo")==12,"distant reserve stays unavailable after magazine empty")
 check(m.place(chest,0,Vector2i(1,2),false) and m.spend_weapon_ammo(weapon,3),"adjacent reserve reloads and fires")
 check(int(weapon.loaded)==9 and m.quantity("ammo")==0,"auto reload conserves remaining rounds")
 # Moving away with remaining magazine is permitted; diagonal contact is not a feed connection.
 check(not m.adjacent(weapon,{"kind":"chest","pos":Vector2i(1,1),"rotated":false}),"diagonal corner does not count")
 var id:int=m.add_item("ammo",55)
 m.insert(id,chest)
 id=m.add_item("ammo",10)
 var before:int=goods(m,"ammo")
 m.insert(id,chest)
 check(goods(m,"ammo")==before,"partial merges preserve all rounds")
 m.begin_journey("",true)
 var snapshot:Array=m.items.duplicate(true)
 check(not m.unload(m.contents(chest)[0].id) and m.items==snapshot,"cannot reorganize containers while driving")
 m.stop_driving()
 m.drop(chest);m.discard_loose()
 check(m.contents(chest).is_empty() and m.item_by_id(chest).is_empty(),"discarded box removes contents without orphan stacks")
 m=Model.new()
 check(m.CATALOG.chest.slots==9 and m.CATALOG.long_chest.slots==18,"container capacities")
 check(m.RECIPES.long_chest.cost.plank==16 and m.RECIPES.chest.cost.plank==8,"equal storage density and material cost")
 var box:int=m.add_item("chest",1,0,Vector2i(2,0))
 m.item_by_id(box)["seat_id"]=3
 var stack:int=m.add_item("ammo",55)
 m.insert(stack,box)
 for i in range(8):m.insert(m.add_item("cloth",8),box)
 check(m.slots_used(box)==9,"full-capacity fixture")
 stack=m.add_item("ammo",10)
 before=goods(m,"ammo")
 check(m.insert(stack,box)==5 and m.item_by_id(stack).amount==5 and m.item_by_id(stack).floor==-1 and goods(m,"ammo")==before,"partial merge into full box leaves exact remainder")
 m.item_by_id(box)["filter"]="ammo"
 check(m.insert(m.add_item("food",1),box)==0,"ammo-only box rejects unrelated manual insert")
 # Box stock is available for crafting and night consumption, not merely the HUD.
 m=Model.new()
 box=m.add_item("long_chest",1,0,Vector2i(2,4))
 check(m.insert(m.add_item("plank",16),box)==16,"boards can be stored inside chest")
 var bench_fixture:int=m.add_item("bench",1,0,Vector2i(2,0))
 check(m.craft("long_chest") and m.quantity("plank")==0,"long chest consumes sixteen stored boards")
 check(m.CATALOG[m.item_by_id(m.next_id-1).kind].slots==18,"crafted output is eighteen-slot chest")
 var food:int=m.add_item("food",6)
 m.insert(food,box)
 var food_before:int=m.quantity("food")
 check(m.spend("food",7) and m.quantity("food")==food_before-7,"resource spending reaches container contents")
 var packed_before:int=m.slots_used(box)
 m.item_by_id(box)["filter"]="ammo"
 m.store_generated("wood",3)
 check(m.slots_used(box)==packed_before,"auto pickup respects ammo-only filter")
 var stored_food:int=0
 for child in m.contents(box):
  if child.kind=="food":stored_food+=child.amount
 m.store_generated("food",1)
 var stored_food_after:int=0
 for child in m.contents(box):
  if child.kind=="food":stored_food_after+=child.amount
 check(stored_food==stored_food_after,"ammo-only filter also prevents topping up old non-ammo contents")
 var model_other=preload("res://scripts/vehicle_state.gd").new()
 check(model_other.CATALOG.ammo.max==12 and model_other.CATALOG.ammo.size==Vector2i(1,2) and model_other.RECIPES.bench.cost.has("scrap"),"experiment data cannot leak into baseline")
 print("STORAGE RULES checks=",checks," failures=",failures)
 quit(1 if failures else 0)
