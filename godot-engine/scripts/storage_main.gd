extends "res://scripts/main.gd"
const StorageModel=preload("res://scripts/storage_state.gd")

func _init():
 model=StorageModel.new()

func _ready():
 super._ready()
 get_window().title="Roadseer · 收纳与供弹 DEMO"
 toast("收纳实验：20km回收原木 → 加工木板 → 制作台 → 木箱。点击右侧合成。")

func reset_run():
 super.reset_run()
 model=StorageModel.new();grid.model=model;road_view.model=model
 refresh();toast("收纳实验重新开始；首个20km回收木材。")

func source_for(kind:String)->String:
 if kind=="wood":return "20km起，每120km的路边木托盘，回收3原木"
 if kind=="plank":return "加工原木；1原木→4木板，无需制作台"
 return super.source_for(kind)

func craft(kind:String):
 if model.craft(kind):
  if tracked_recipe==kind:tracked_recipe=""
  if kind=="plank":
   selected_id=-1;moving=false;panel="storage_craft"
  else:
   selected_id=model.next_id-1;selected_rotation=false;moving=true;panel="item"
 toast();refresh()

func deposit_all(box_id:int):
 for item in model.items.duplicate():
  if item.floor in [-1,0] and model.CATALOG[item.kind].has("max"):model.insert(item.id,box_id)
 toast();refresh()

func withdraw(id:int):
 if model.unload(id):
  selected_id=id;selected_rotation=model.item_by_id(id).rotated;moving=true;panel="item"
 toast();refresh()

func render_storage_crafting():
 wipe(panel_body);panel_back.visible=true;panel_title.text="木工与收纳"
 text_block("原木 → 木板 → 制作台 → 木箱",GOLD)
 text_block("小木箱：1格／9槽\n长木箱：2格／18槽\n水与燃油每组占2槽，其余小件每组1槽。",MUTED)
 for kind in ["plank","bench","chest","long_chest"]:
  var recipe:Dictionary=model.RECIPES[kind]
  var parts:PackedStringArray=[]
  for ingredient in recipe.cost:parts.append("%s%d/%d"%[model.CATALOG[ingredient].name,model.quantity(ingredient),recipe.cost[ingredient]])
  text_block(model.CATALOG[kind].name+(" ×4" if kind=="plank" else ""),GOLD)
  text_block(" / ".join(parts)+" · %d分钟"%recipe.get("minutes",60),MUTED)
  var error:String=model.recipe_error(kind)
  action("加工4木板" if kind=="plank" else "搭建制作台" if kind=="bench" else "制作"+model.CATALOG[kind].name,craft.bind(kind),error.is_empty(),true)
  if not error.is_empty():text_block(error,MUTED)

func render_box(item:Dictionary):
 wipe(panel_body);panel_back.visible=true;panel_title.text=model.CATALOG[item.kind].name
 text_block("外部%d格 · 内部%d/%d槽"%[model.footprint(item).x*model.footprint(item).y,model.slots_used(item.id),model.CATALOG[item.kind].slots],GOLD)
 text_block("点击箱内物资取出，随后放入车厢或空座。拖动外部物资到箱子上可收纳。",MUTED)
 var slots=GridContainer.new();slots.columns=3;slots.add_theme_constant_override("h_separation",4);slots.add_theme_constant_override("v_separation",4);panel_body.add_child(slots)
 var occupied:int=0
 for child in model.contents(item.id):
  var b=button("%s\n×%d"%[model.CATALOG[child.kind].name,child.amount],withdraw.bind(child.id))
  b.custom_minimum_size=Vector2(88,58);b.size_flags_horizontal=SIZE_EXPAND_FILL;b.disabled=not model.editable();slots.add_child(b);occupied+=1
  if model.slot_cost(child.kind)==2:
   var reserve=button("体积\n占2槽",func():pass);reserve.disabled=true;reserve.custom_minimum_size=Vector2(88,58);slots.add_child(reserve);occupied+=1
 while occupied<int(model.CATALOG[item.kind].slots):
  var empty=button("空",func():pass);empty.disabled=true;empty.custom_minimum_size=Vector2(88,58);slots.add_child(empty);occupied+=1
 var root_installed:bool=item.floor==0
 action("收纳车内和待装物资",deposit_all.bind(item.id),root_installed and model.editable(),true)
 action("自动拾取："+("只收弹药" if item.get("filter","")=="ammo" else "所有物资"),func():item["filter"]="" if item.get("filter","")=="ammo" else "ammo";refresh(),root_installed and model.editable())
 text_block("箱内物资可参与制作与消耗。只有共边武器能自动取得箱内弹药；不允许箱子套箱子。",MUTED)
 if int(item.get("seat_id",-1))>=0:text_block("放在空客座上 · 座位已用于载货",GOLD)
 for weapon in model.items:
  if weapon.floor==0 and weapon.kind in ["gun","cannon"] and root_installed and model.adjacent(weapon,item):text_block("共边连接 → "+model.CATALOG[weapon.kind].name,GOLD)
 item_actions(item)
 if int(item.get("seat_id",-1))>=0:action("查看下方座位",select_item.bind(item.seat_id))

func render_panel():
 if panel=="storage_craft" and model.editable():render_storage_crafting();return
 if panel in ["item","workshop"] and model.editable():
  var item:Dictionary=model.item_by_id(selected_id)
  if model.is_box(item):render_box(item);return
 if panel=="home" and model.editable():
  wipe(panel_body);panel_back.visible=false;panel_title.text="收纳与供弹实验"
  text_block("把车变成能用的移动仓库",GOLD)
  text_block("① 行驶20km，回收3原木\n② 加工3次，获得12木板\n③ 旋转金属，在右下装制作台\n④ 用8木板做9槽木箱",MUTED)
  action("木工与收纳合成",func():panel="storage_craft";render_panel(),true,true)
  text_block("空客座可放1格货物或小箱。拖到箱子上收纳；点击箱子管理内容。",MUTED)
  text_block("机枪：每次点射3发，内置弹匣18发。邻接弹药包或箱子可自动补给；远处储备只能停车手动装填。",MUTED)
  action("查看抗灾准备",func():open_panel("forecast"))
  if not model.last_pickup.is_empty():text_block(model.last_pickup,GOLD)
  return
 super.render_panel()
 if panel in ["item","workshop"] and model.editable():
  var item:Dictionary=model.item_by_id(selected_id)
  if item.is_empty():return
  if item.kind=="bench" and item.floor==0:action("木工与收纳合成",func():panel="storage_craft";render_panel(),true,true)
  if item.kind in ["gun","cannon"] and item.floor==0:
   text_block("弹匣 %d/%d发\n邻接可补给 %d发\n全车储备 %d发"%[item.get("loaded",0),model.magazine_capacity(item),model.reachable_ammo(item),model.quantity("ammo")],GOLD)
   action("停车手动装填",func():model.reload_weapon(item.id);toast();refresh(),int(item.get("loaded",0))<model.magazine_capacity(item) and model.quantity("ammo")>0)
  if item.kind=="seat":
   var cargo:Dictionary=model.cargo_on_seat(item.id)
   if not cargo.is_empty():action("查看座上货物 · "+model.CATALOG[cargo.kind].name,select_item.bind(cargo.id))
  if model.CATALOG[item.kind].has("max"):
   for box in model.items:
    if model.is_box(box) and box.floor==0:
     action("放入%s #%d"%[model.CATALOG[box.kind].name,box.id],func():model.insert(item.id,box.id);toast();refresh())
 if panel=="recipe":
  # Base recipe presentation remains shared; explain the actual experiment duration.
  text_block("本实验配方实际耗时：%d分钟"%model.RECIPES[recipe_kind].get("minutes",60),GOLD)
