extends Control
const Model=preload("res://scripts/vehicle_state.gd")
const Grid=preload("res://scripts/vehicle_grid.gd")
const RoadView=preload("res://scripts/road_view.gd")
const CargoCard=preload("res://scripts/cargo_card.gd")
const INK=Color("e4e9df")
const MUTED=Color("9aaea2")
const GOLD=Color("ddbd84")
var model=Model.new()
var grid
var road_view
var road_action:Button
var crew_button:Button
var grid_scroll:ScrollContainer
var journey_elapsed:float=0.0
const JOURNEY_SECONDS:float=3.0
var reduced_motion:bool=false
var day_label:Label
var phase_label:Label
var resource_labels:Dictionary={}
var board_title:Label
var board_hint:Label
var panel_title:Label
var panel_back:Button
var panel_body:VBoxContainer
var panel_scroll:ScrollContainer
var ground_box:PanelContainer
var ground_list:HBoxContainer
var ground_heading:Label
var night_label:Label
var feedback:Label
var travel_button:Button
var battle_controls:HBoxContainer
var pause_button:Button
var speed_button:Button
var selected_id:int=-1
var selected_rotation:bool=false
var moving:bool=false
var drag_candidate:int=-1
var drag_id:int=-1
var drag_start:Vector2
var drag_pointer:Vector2
var battle_summary:Label
var drag_offset:Vector2i=Vector2i.ZERO
var panel:String="home"
var recipe_kind:String=""
var route_selected:String=""
var tracked_recipe:String=""
var settlement:Dictionary={}
var paused:bool=false
var speed:int=1
var clock_accum:float=0.0
var toast_time:float=0.0
var discard_dialog:ConfirmationDialog
var restart_dialog:ConfirmationDialog
var pending_action:String="end"
var restart_was_paused:bool=false

func _ready():
 get_tree().root.gui_embed_subwindows=true
 get_window().min_size=Vector2i(1280,820)
 var skin=Theme.new()
 var font=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC"])
 skin.default_font=font;skin.default_font_size=16
 skin.set_color("font_color","Label",INK)
 for state in ["normal","hover","pressed","disabled","focus"]:
  var style=box({"normal":Color("263a33"),"hover":Color("344e42"),"pressed":Color("405b4b"),"disabled":Color("202d28"),"focus":Color(0,0,0,0)}[state],8,12)
  if state=="focus":style.set_border_width_all(1);style.border_color=GOLD
  skin.set_stylebox(state,"Button",style)
 skin.set_color("font_color","Button",INK);skin.set_color("font_disabled_color","Button",Color("687b6e"))
 theme=skin
 var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
 add_child(margin)
 var page=VBoxContainer.new();page.add_theme_constant_override("separation",14);margin.add_child(page)
 var header=HBoxContainer.new();header.add_theme_constant_override("separation",18);page.add_child(header)
 day_label=label("",26);header.add_child(day_label)
 phase_label=label("",16,GOLD);phase_label.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(phase_label)
 crew_button=button("成员 1人",func():open_panel("crew"));header.add_child(crew_button)
 header.add_child(button("记录",func():open_panel("log")))
 header.add_child(button("菜单",func():open_panel("menu")))
 var resource_panel=PanelContainer.new();resource_panel.add_theme_stylebox_override("panel",box(Color("182822"),10,12));page.add_child(resource_panel)
 var resources=HBoxContainer.new();resources.add_theme_constant_override("separation",28);resource_panel.add_child(resources)
 for entry in [["health","主角健康"],["hull","车体"],["water","饮水"],["food","口粮"],["fuel","燃油"],["ammo","弹药"]]:
  var group=HBoxContainer.new();group.add_theme_constant_override("separation",10);group.size_flags_horizontal=SIZE_EXPAND_FILL;resources.add_child(group)
  group.add_child(label(entry[1],14,MUTED));var value=label("",20);group.add_child(value);resource_labels[entry[0]]=value
 var body=HBoxContainer.new();body.add_theme_constant_override("separation",12);body.size_flags_vertical=SIZE_EXPAND_FILL;page.add_child(body)
 var road=card(body);road.get_parent().size_flags_horizontal=SIZE_EXPAND_FILL;road.get_parent().size_flags_stretch_ratio=0.96
 var road_header=HBoxContainer.new();road.add_child(road_header)
 road_header.add_child(label("前方道路",20));var road_spacer=Control.new();road_spacer.size_flags_horizontal=SIZE_EXPAND_FILL;road_header.add_child(road_spacer)
 road_header.add_child(label("N ↑",14,GOLD))
 road_view=RoadView.new();road_view.model=model;road_view.size_flags_vertical=SIZE_EXPAND_FILL;road.add_child(road_view)
 road_view.encounter_clicked.connect(road_interact)
 road_view.route_chosen.connect(choose_road_route)
 battle_controls=HBoxContainer.new();road.add_child(battle_controls)
 pause_button=button("暂停 Space",toggle_pause);pause_button.size_flags_horizontal=SIZE_EXPAND_FILL;battle_controls.add_child(pause_button)
 speed_button=button("速度 ×1",func():speed=2 if speed==1 else 1;refresh(false));battle_controls.add_child(speed_button)
 road_action=button("请先点击上方路牌",road_interact,true);road.add_child(road_action)
 var left=VBoxContainer.new();left.size_flags_horizontal=SIZE_EXPAND_FILL;left.size_flags_stretch_ratio=1.04;left.add_theme_constant_override("separation",10);body.add_child(left)
 var stage=card(left);stage.size_flags_vertical=SIZE_EXPAND_FILL
 var board_header=HBoxContainer.new();stage.add_child(board_header)
 board_title=label("我的车辆",20);board_title.size_flags_horizontal=SIZE_EXPAND_FILL;board_header.add_child(board_title)
 board_header.add_child(button("抗灾预报",func():open_panel("forecast")))
 grid_scroll=ScrollContainer.new();grid_scroll.size_flags_vertical=SIZE_EXPAND_FILL;grid_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;stage.add_child(grid_scroll)
 grid=Grid.new();grid.model=model;grid.size_flags_vertical=SIZE_EXPAND_FILL;grid.size_flags_horizontal=SIZE_EXPAND_FILL;grid_scroll.add_child(grid)
 grid.item_selected.connect(select_item)
 grid.placement_requested.connect(place_item);grid.canceled.connect(clear_selection)
 board_hint=label("",13,MUTED);board_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;stage.add_child(board_hint)
 ground_box=PanelContainer.new();ground_box.add_theme_stylebox_override("panel",box(Color("182822"),10,12));left.add_child(ground_box)
 var ground_layout=VBoxContainer.new();ground_layout.add_theme_constant_override("separation",8);ground_box.add_child(ground_layout)
 ground_heading=label("",14,MUTED);ground_layout.add_child(ground_heading)
 var ground_scroll=ScrollContainer.new();ground_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;ground_scroll.custom_minimum_size.y=94;ground_layout.add_child(ground_scroll)
 ground_list=HBoxContainer.new();ground_list.add_theme_constant_override("separation",8);ground_scroll.add_child(ground_list)
 var side=card(body);side.custom_minimum_size.x=280
 var panel_header=HBoxContainer.new();side.add_child(panel_header)
 panel_title=label("",21);panel_title.size_flags_horizontal=SIZE_EXPAND_FILL;panel_header.add_child(panel_title)
 panel_back=button("返回",func():clear_selection());panel_header.add_child(panel_back)
 panel_scroll=ScrollContainer.new();panel_scroll.size_flags_vertical=SIZE_EXPAND_FILL;panel_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;side.add_child(panel_scroll)
 panel_body=VBoxContainer.new();panel_body.size_flags_horizontal=SIZE_EXPAND_FILL;panel_body.add_theme_constant_override("separation",12);panel_scroll.add_child(panel_body)
 var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",18);page.add_child(footer)
 var night=VBoxContainer.new();night.size_flags_horizontal=SIZE_EXPAND_FILL;footer.add_child(night)
 night_label=label("",16);night_label.clip_text=true;night.add_child(night_label)
 feedback=label("",13,MUTED);feedback.clip_text=true;night.add_child(feedback)
 travel_button=button("结束当天",request_departure,true);travel_button.custom_minimum_size=Vector2(210,54);footer.add_child(travel_button)
 discard_dialog=ConfirmationDialog.new();discard_dialog.title="还有物品未装车";discard_dialog.ok_button_text="放弃这些物品并继续";discard_dialog.cancel_button_text="返回整理";discard_dialog.dialog_autowrap=true;add_child(discard_dialog)
 discard_dialog.confirmed.connect(func():perform_action(true))
 restart_dialog=ConfirmationDialog.new();restart_dialog.title="重新开始";restart_dialog.dialog_text="本局车辆、物资与进度将清空。当前原型没有存档。";restart_dialog.ok_button_text="开始新一局";restart_dialog.cancel_button_text="继续本局";add_child(restart_dialog)
 restart_dialog.confirmed.connect(reset_run)
 restart_dialog.canceled.connect(func():paused=restart_was_paused;refresh(false))
 refresh()
 print("ROADSEER_LAYOUT_A_READY: persistent road, upright inventory, contextual equipment")

func box(color:Color,radius:int=10,padding:int=0)->StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius)
 s.content_margin_left=padding;s.content_margin_right=padding;s.content_margin_top=padding;s.content_margin_bottom=padding
 return s
func card(parent:Node)->VBoxContainer:
 var shell=PanelContainer.new();shell.add_theme_stylebox_override("panel",box(Color("14231e"),12,16));parent.add_child(shell)
 if parent is VBoxContainer:shell.size_flags_vertical=SIZE_EXPAND_FILL
 var content=VBoxContainer.new();content.add_theme_constant_override("separation",12);shell.add_child(content)
 return content
func label(text:String,font_size:int=16,color:Color=INK)->Label:
 var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);return l
func paragraph(text:String,color:Color=INK)->Label:
 var l=label(text,15,color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x=280;l.size_flags_horizontal=SIZE_EXPAND_FILL;return l
func button(text:String,action:Callable,primary:bool=false)->Button:
 var b=Button.new();b.text=text;b.pressed.connect(action);b.mouse_default_cursor_shape=CURSOR_POINTING_HAND
 if primary:
  for state in ["normal","hover","pressed"]:b.add_theme_stylebox_override(state,box(GOLD.lightened(0.12) if state=="hover" else GOLD,8,12))
  b.add_theme_color_override("font_color",Color("203128"));b.add_theme_color_override("font_hover_color",Color("203128"));b.add_theme_color_override("font_pressed_color",Color("203128"))
 return b
func wipe(container:Node):
 for child in container.get_children():container.remove_child(child);child.queue_free()
func text_block(text:String,color:Color=INK):panel_body.add_child(paragraph(text,color))
func action(text:String,callback:Callable,enabled:bool=true,primary:bool=false)->Button:
 var b=button(text,callback,primary);b.disabled=not enabled;panel_body.add_child(b);return b
func toast(text:String=""):
 feedback.text=text if not text.is_empty() else model.logs[0] if not model.logs.is_empty() else ""
 toast_time=5.0

func _process(delta:float):
 if toast_time>0:
  toast_time-=delta
  if toast_time<=0:feedback.text="整理不耗行动；外出和日结会离开当前停靠点。"
 if drag_id>=0:
  var mouse:Vector2=drag_pointer
  var viewport_rect:Rect2=grid_scroll.get_global_rect()
  if viewport_rect.has_point(mouse):
   if mouse.y<viewport_rect.position.y+30:grid_scroll.scroll_vertical-=maxi(1,int(300*delta))
   elif mouse.y>viewport_rect.end.y-30:grid_scroll.scroll_vertical+=maxi(1,int(300*delta))
   grid.hover=grid.screen_cell(mouse-grid.global_position)-drag_offset;grid.queue_redraw()
 if paused:return
 if model.phase=="travel":
  journey_elapsed+=delta*speed
  road_view.progress=minf(1,journey_elapsed/JOURNEY_SECONDS)
  if journey_elapsed>=JOURNEY_SECONDS:
   model.arrive();clock_accum=0;panel="home";refresh()
   toast("已抵达，点击道路物资箱或右侧按钮领取。" if model.phase=="encounter" else "遭遇敌人，小爱已接管自动作战。")
  return
 if model.phase!="combat":return
 if road_view.age>0.65 and not grid.highlighted.is_empty():grid.highlighted=[];grid.queue_redraw()
 clock_accum+=delta*speed
 if clock_accum>=0.85:
  clock_accum-=0.85;model.combat_step();road_view.pulse();grid.highlighted=[]
  for effect in model.effects:
   if effect.has("id"):grid.highlighted.append(effect.id)
  if model.phase!="combat":grid.highlighted=[];panel="home";toast("战斗结束，战利品已放在车厢下方。" if model.won or model.editable() else model.outcome)
  refresh(model.phase!="combat")

func _input(event:InputEvent):
 if grid==null or not model.editable() or discard_dialog.visible or restart_dialog.visible:return
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and drag_id>=0:
  cancel_drag();get_viewport().set_input_as_handled();return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and drag_id>=0:
  cancel_drag();get_viewport().set_input_as_handled();return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   drag_candidate=-1;drag_offset=Vector2i.ZERO;drag_start=event.position;drag_pointer=event.position
   if grid.visible and grid_scroll.get_global_rect().has_point(event.position) and grid.get_global_rect().has_point(event.position) and not moving:
    var p:Vector2i=grid.screen_cell(event.position-grid.global_position)
    drag_candidate=grid.item_at(p)
    if drag_candidate>=0:drag_offset=p-model.item_by_id(drag_candidate).pos
   elif ground_box.visible and ground_box.get_global_rect().has_point(event.position):
    for tile in ground_list.get_children():
     if tile.get_global_rect().has_point(event.position):drag_candidate=tile.item_id;break
  else:
   drag_candidate=-1
   if drag_id>=0:
    var id:int=drag_id;drag_id=-1;grid.dragging=false
    if grid_scroll.get_global_rect().has_point(event.position) and grid.get_global_rect().has_point(event.position):place_item(id,0,grid.screen_cell(event.position-grid.global_position)-drag_offset,selected_rotation)
    else:cancel_drag()
    get_viewport().set_input_as_handled()
 if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
  drag_pointer=event.position
  if drag_id<0 and drag_candidate>=0 and event.position.distance_to(drag_start)>8:
   drag_id=drag_candidate;prepare_drag(drag_id);grid.dragging=true
  if drag_id>=0:
   grid.hover=grid.screen_cell(event.position-grid.global_position)-drag_offset;grid.queue_redraw()
   get_viewport().set_input_as_handled()

func cancel_drag():
 drag_candidate=-1;drag_id=-1;grid.dragging=false;moving=false;grid.hover=Vector2i(-1,-1)
 var item:Dictionary=model.item_by_id(selected_id)
 panel="workshop" if not item.is_empty() and item.kind=="bench" and item.floor==0 else "item" if not item.is_empty() else "home"
 refresh()

func select_item(id:int):
 if not model.editable():return
 var item:Dictionary=model.item_by_id(id)
 if item.is_empty():return
 selected_id=id;selected_rotation=item.rotated;moving=item.floor<0
 panel="workshop" if item.kind=="bench" and item.floor==0 else "item"
 panel_scroll.scroll_vertical=0;refresh(false);render_panel()
func prepare_drag(id:int):
 var item:Dictionary=model.item_by_id(id)
 if item.is_empty():return
 selected_id=id;selected_rotation=item.rotated;moving=false
 refresh(false)
func start_move():
 if selected_id<0 or not model.editable():return
 moving=true;refresh(false);toast("选择目标位置；R旋转，Esc取消。")
func place_item(id:int,f:int,p:Vector2i,r:bool):
 var success:bool=model.merge_at(id,p)
 if not success:success=model.place(id,f,p,r)
 if success:
  moving=false
  if model.item_by_id(id).is_empty():selected_id=-1;panel="home"
  else:
   selected_id=id
   var placed:Dictionary=model.item_by_id(id)
   selected_rotation=placed.rotated
   panel="workshop" if placed.kind=="bench" and placed.floor==0 else "item"
 toast();refresh()
func clear_selection():
 drag_candidate=-1;drag_id=-1;grid.dragging=false;grid.hover=Vector2i(-1,-1)
 selected_id=-1;moving=false;panel="home";panel_scroll.scroll_vertical=0;refresh(false);render_panel()
func rotate_selection():
 if selected_id>=0 and model.editable():selected_rotation=not selected_rotation;moving=drag_id<0;drag_offset=Vector2i.ZERO;refresh(false)
func drop_selection():
 if model.drop(selected_id):moving=false;panel="item"
 toast();refresh()
func open_panel(value:String):
 panel=value;selected_id=-1;moving=false;panel_scroll.scroll_vertical=0;refresh(false);render_panel()
func toggle_pause():
 if model.phase in ["combat","travel"]:
  paused=not paused;refresh(false)
  if panel=="home" and model.phase=="travel":render_panel()
func _unhandled_key_input(event:InputEvent):
 if discard_dialog.visible or restart_dialog.visible:return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_R:rotate_selection()
  elif event.keycode==KEY_ESCAPE:clear_selection()
  elif event.keycode==KEY_SPACE:toggle_pause()
func craft(kind:String):
 if model.craft(kind):
  if tracked_recipe==kind:tracked_recipe=""
  selected_id=model.next_id-1;selected_rotation=false;moving=true;panel="item"
 toast();refresh()
func show_recipe(kind:String):
 recipe_kind=kind;panel="recipe";panel_scroll.scroll_vertical=0;render_panel()
func request_departure():
 if not model.editable():return
 pending_action="end";confirm_action()
func request_outing(value:String):
 var error:String=model.outing_error(value)
 if not error.is_empty():toast(error);return
 pending_action=value;confirm_action()
func confirm_action():
 if model.ground().is_empty():perform_action(false);return
 var names:PackedStringArray=[]
 for item in model.ground():names.append("%s ×%d"%[Model.CATALOG[item.kind].name,item.amount])
 discard_dialog.dialog_text="%s将离开当前停靠点。\n\n尚未装车：%s\n\n这些物品无法在离开后取回。"%["结束当天" if pending_action=="end" else "外出","、".join(names)]
 discard_dialog.popup_centered(Vector2i(560,240))
func perform_action(discard:bool):
 var before_health:int=model.health
 var completed_day:int=model.day
 var plan:Dictionary=model.night_plan(model.day,model.quantity("fuel"))
 var changed:bool=model.depart(discard) if pending_action=="end" else model.begin_journey(pending_action,discard)
 if changed:
  selected_id=-1;moving=false;paused=false;clock_accum=0;grid.highlighted=[]
  if pending_action=="end":
   settlement={"day":completed_day,"health_delta":model.health-before_health,"plan":plan,"report":model.day_reports[-1] if not model.day_reports.is_empty() else model.outcome};panel="settlement"
   route_selected="";road_view.last_route="";road_view.progress=0
  else:
   panel="home";journey_elapsed=0;road_view.progress=0;road_view.last_route=pending_action
 toast();refresh()
func ask_restart():
 restart_was_paused=paused;paused=true;refresh(false);restart_dialog.popup_centered(Vector2i(500,180))
func reset_run():
 model=Model.new();grid.model=model;road_view.model=model
 drag_candidate=-1;drag_id=-1;grid.dragging=false;grid.hover=Vector2i(-1,-1)
 selected_id=-1;moving=false;paused=false;clock_accum=0;journey_elapsed=0;road_view.progress=0;road_view.last_route="";panel="home";tracked_recipe="";route_selected="";settlement={};grid.highlighted=[]
 grid_scroll.scroll_vertical=0;panel_scroll.scroll_vertical=0
 refresh();toast("先搭建制作台，再规划你的抗灾方案。")

func refresh(rebuild:bool=true):
 if grid==null:return
 if model.item_by_id(selected_id).is_empty():selected_id=-1;moving=false
 day_label.text="第 %02d 天"%model.day
 phase_label.text=("准备期  /  距三日凌空 %d 天"%(15-model.day) if model.day<15 else "三日凌空  /  第 %d / 7 天"%(model.day-14))+"     ·     行动 %d / 2"%model.actions
 for kind in resource_labels:
  resource_labels[kind].text="%d/%d"%[model.health,model.max_health] if kind=="health" else "%d/%d"%[model.hull,model.max_hull] if kind=="hull" else str(model.quantity(kind))
  resource_labels[kind].add_theme_color_override("font_color",Color("e8a27e") if (kind=="health" and model.health<20) or (kind=="hull" and model.hull<12) or (kind in ["water","food","fuel","ammo"] and model.quantity(kind)==0) else INK)
 grid.selected_id=selected_id;grid.rotated=selected_rotation;grid.moving=moving;grid.queue_redraw()
 var fighting:bool=model.phase=="combat"
 grid.visible=true;road_view.visible=true
 grid.custom_minimum_size.y=model.height*48+90
 battle_controls.visible=model.phase in ["combat","travel"]
 road_view.paused=paused;road_view.speed=speed;road_view.reduced_motion=reduced_motion;road_view.preview_route=route_selected;road_view.sync_routes()
 road_action.visible=not battle_controls.visible
 road_action.disabled=model.phase=="ended" or (model.editable() and not model.explored and (route_selected.is_empty() or not model.outing_error(route_selected).is_empty()))
 road_action.text="打开物资箱 →" if model.phase=="encounter" else "整理战利品 →" if model.explored else "出发 · "+RoadView.ROUTE_NAMES[route_selected] if not route_selected.is_empty() else "请先点击上方路牌"
 crew_button.text="成员 %d人"%model.members.size()
 board_title.text="我的车辆 · %d×%d"%[model.width,model.height]
 board_hint.text="战斗中 · 布局锁定，发光设备正在生效" if fighting else "行进中 · 布局锁定" if model.phase=="travel" else "抵达后先处理道路遭遇" if model.phase=="encounter" else "选位置放置 · R旋转 · Esc取消" if moving else "点击设施使用 · 拖动物品整理 · R旋转"
 pause_button.text="继续 Space" if paused else "暂停 Space";speed_button.text="速度 ×%d"%speed
 var night:Dictionary=model.night_plan(model.day,model.quantity("fuel"))
 night_label.text="今晚  ·  水 %d  /  粮 1  /  制冷油 %d     %s"%[night.water,night.fuel,"预计热伤 %d"%night.damage if night.damage>0 else "防护后无热伤"]
 var shortage:bool=model.quantity("water")<night.water or model.quantity("food")<1
 night_label.text+="  ·  床位 %d/%d"%[model.rest_assignments().size(),model.members.size()]
 if model.rest_recovery()==0:night_label.text+=" 无床休息"
 if shortage:night_label.text+="  ·  补给不足"
 night_label.add_theme_color_override("font_color",Color("e3ad7e") if shortage or night.damage>0 else INK)
 travel_button.disabled=not model.editable()
 travel_button.text="行进中" if model.phase=="travel" else "先处理遭遇" if model.phase=="encounter" else "战斗进行中" if fighting else "本局已结束" if model.phase=="ended" else "度过最后一晚 →" if model.day==21 else "结束第%d天 →"%model.day
 if model.phase=="ended":night_label.text=model.outcome;night_label.tooltip_text=model.outcome
 ground_box.visible=not model.ground().is_empty() and model.editable()
 if fighting and is_instance_valid(battle_summary):battle_summary.text="本场消耗弹药 %d\n防护挡下 %d · 车体损失 %d"%[model.combat.ammo,model.combat.blocked,model.combat.damage]
 if not rebuild:return
 wipe(ground_list)
 ground_heading.text="待装物资 · %d件   点击或拖入车厢"%model.ground().size()
 for item in model.ground():
  var tile=CargoCard.new();tile.model=model;tile.item_id=item.id;tile.tooltip_text=Model.CATALOG[item.kind].desc;tile.disabled=not model.editable()
  tile.pressed.connect(select_item.bind(item.id));ground_list.add_child(tile)
 render_panel()

func item_actions(item:Dictionary):
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);panel_body.add_child(row)
 row.add_child(button("放入车厢" if item.floor<0 else "移动",start_move))
 if item.floor==0 and not Model.CATALOG[item.kind].get("fixed",false):row.add_child(button("卸到地面",drop_selection))
 if moving:text_block("正在放置 · R旋转，Esc取消",GOLD)
func source_for(kind:String)->String:
 if kind in ["scrap","cloth"]:return "废车拆解线"
 if kind=="electronics":return "电站遗址线"
 return "生活补给线"
func choose_road_route(value:String):
 if not model.editable() or model.explored:return
 if not Model.ROUTES.has(value):return
 route_selected=value;open_panel("explore")
func road_interact():
 if model.phase=="encounter":collect_road_loot()
 elif model.editable():
  if model.explored:open_panel("home")
  elif not route_selected.is_empty():request_outing(route_selected)
func collect_road_loot():
 if model.collect_encounter():panel="home";toast("物资已放在车厢下方，装车后可使用。");refresh()

func render_panel():
 wipe(panel_body);panel_back.visible=panel!="home"
 if model.phase=="ended" and panel not in ["log","menu"]:
  panel_title.text="周期完成" if model.won else "生存结束"
  text_block(model.outcome,GOLD);text_block("剩余健康 %d  ·  车体 %d\n完成 %d 天日结，经历 %d 场战斗。"%[model.health,model.hull,model.day_reports.size(),model.battle_reports.size()])
  action("查看旅程记录",func():open_panel("log"));action("从第1天再试",ask_restart,true,true);return
 if model.phase=="travel" and panel not in ["log","menu"]:
  panel_title.text="正在行进";panel_back.visible=false
  text_block(Model.ROUTES[model.pending_route].name,GOLD)
  text_block("前方 · "+RoadView.ROUTE_NAMES[model.pending_route])
  text_block(Model.ROUTES[model.pending_route].hint,MUTED)
  text_block("本次外出已消耗1行动。抵达后处理遭遇，途中不会再次扣除补给。",MUTED)
  action("暂停观察" if not paused else "继续行进",toggle_pause)
  return
 if model.phase=="encounter" and panel not in ["log","menu"]:
  panel_title.text="发现物资箱";panel_back.visible=false
  text_block("周围安全 · 可以收集",GOLD)
  text_block(Model.ROUTES[model.pending_route].hint,MUTED)
  action("打开物资箱",collect_road_loot,true,true)
  text_block("本次外出已付费，开箱不额外消耗行动。物资需要放入车厢。",MUTED)
  return
 if model.phase=="combat" and panel not in ["log","menu"]:
  panel_title.text="小爱自动作战";panel_back.visible=false
  text_block("胜利后打开物资箱。\n战斗中不能更换或移动设备。",MUTED)
  battle_summary=paragraph("本场消耗弹药 %d\n防护挡下 %d · 车体损失 %d"%[model.combat.ammo,model.combat.blocked,model.combat.damage],GOLD);panel_body.add_child(battle_summary)
  for item in model.items:
   if item.floor==0 and item.kind in ["gun","cannon","armor","interceptor"]:
    text_block(Model.CATALOG[item.kind].name);text_block(Model.CATALOG[item.kind].desc,MUTED)
  action("查看战斗记录",func():open_panel("log"));return
 match panel:
  "home":
   panel_title.text="今天的安排"
   if not tracked_recipe.is_empty():
    text_block("正在准备 · "+Model.CATALOG[tracked_recipe].name,GOLD)
    var missing:PackedStringArray=[]
    if tracked_recipe not in model.learned:missing.append("前往电站遗址学习图纸")
    for kind in Model.RECIPES[tracked_recipe].cost:
     var gap:int=maxi(0,int(Model.RECIPES[tracked_recipe].cost[kind])-model.quantity(kind))
     if gap>0:missing.append("缺%d%s · %s"%[gap,Model.CATALOG[kind].name,source_for(kind)])
    text_block("\n".join(missing) if not missing.is_empty() else "材料已齐，点击车内制作台加工。",MUTED)
    action("查看追踪图纸",func():show_recipe(tracked_recipe))
   elif model.count_active("bench")==0:
    var loose_bench:int=-1
    for item in model.ground():
     if item.kind=="bench":loose_bench=item.id;break
    text_block("第一步 · 建立制作能力",GOLD)
    if loose_bench>=0:
     text_block("制作台已在下方待装区。把它放进车厢后，点击即可使用。",MUTED)
     action("安装制作台",select_item.bind(loose_bench),true,true)
    else:
     text_block("用2金属搭建制作台，占4格。装车后点击它，可制作抗灾设备和扩容。",MUTED)
     var error:String=model.recipe_error("bench")
     action("搭建制作台 · 2金属 / 1行动",func():craft("bench"),error.is_empty(),true)
     if not error.is_empty():text_block(error,GOLD)
   else:
    text_block("为三日凌空做好准备",GOLD)
    text_block("点击车内制作台，选择隔热或制冷设备。储备足够的饮水、口粮和燃油。",MUTED)
   panel_body.add_child(HSeparator.new())
   text_block("在左侧道路点选路牌，再在道路下方确认出发。",GOLD)
   text_block("今日已完成外出，可继续整理和制作。" if model.explored else "每天最多外出1次，消耗1行动。",MUTED)
   action("查看抗灾准备",func():open_panel("forecast"))
   if model.count_active("bed")==0:
    text_block("缺少睡眠空间：今晚不能通过休息恢复健康。",GOLD)
    action("制作单人床",func():show_recipe("bed"))
   if not model.last_report.is_empty():
    text_block("最近结果",MUTED);text_block(model.last_report)
  "explore":
   panel_title.text="路线情报"
   if route_selected.is_empty():
    text_block("点击左侧道路上的路牌，查看目的地情报。",GOLD)
   else:
    var entry:Dictionary=Model.ROUTES[route_selected]
    text_block(RoadView.ROUTE_NAMES[route_selected],GOLD)
    text_block(entry.name,MUTED);text_block(entry.hint)
    text_block("外出：2油 + 1水 + 1行动，暴晒健康−2" if model.day>=15 else "外出：1油 + 1行动",GOLD)
    var error:String=model.outing_error(route_selected)
    text_block(error if not error.is_empty() else "已选中。点击左侧道路下方的出发按钮。",MUTED)
  "crew":
   panel_title.text="成员 · %d人"%model.members.size()
   for member in model.members:
    text_block(member.name,GOLD)
    var seat:Dictionary=model.item_by_id(member.seat_id)
    text_block("座位："+Model.CATALOG[seat.kind].name if not seat.is_empty() and seat.floor==0 else "尚未入座")
    text_block("健康 %d / %d"%[model.health,model.max_health])
   text_block("当前1人，3个客座空置。小爱为车载自动作战系统，不占座位或床位。",MUTED)
   text_block("单人床 %d张 · 可睡 %d/%d人"%[model.count_active("bed"),model.rest_assignments().size(),model.members.size()],GOLD)
   text_block("夜间自动使用床位，日结后回到座位。不新增疲劳值；安全、补给充足且有床时恢复2健康。",MUTED)
  "item","workshop":
   var item:Dictionary=model.item_by_id(selected_id)
   if item.is_empty():panel="home";render_panel();return
   var definition:Dictionary=Model.CATALOG[item.kind]
   panel_title.text=definition.name
   text_block("%d×%d · %d格 · %s"%[model.footprint(item).x,model.footprint(item).y,model.footprint(item).x*model.footprint(item).y,"已装车" if item.floor==0 else "待装车"],MUTED)
   if item.kind=="bench" and item.floor==0:
    text_block("选择图纸，查看缺口或制作。每次制作消耗1行动。",MUTED)
    for kind in Model.RECIPES:
     if kind=="bench":continue
     var error:String=model.recipe_error(kind)
     action(Model.CATALOG[kind].name+"  ·  "+("可制作" if error.is_empty() else "未学会" if kind not in model.learned else "查看配方"),show_recipe.bind(kind))
    panel_body.add_child(HSeparator.new())
    var cost:int=6+2*model.expansion_level
    action("扩容到4×%d · %d金属"%[model.height+2,cost] if model.expansion_level<2 else "车厢已达本轮上限",func():model.upgrade();toast();refresh(),model.expansion_level<2 and model.actions>0 and model.quantity("scrap")>=cost)
    text_block("扩容消耗1行动，增加8格。",MUTED)
   else:
    text_block(definition.desc)
    if item.kind in ["driver","seat"]:
     var occupant:String=model.seat_occupant(item.id)
     text_block("当前：空座 · 0/1人" if occupant.is_empty() else "当前："+occupant+"已入座 · 1/1人",GOLD)
    if item.kind=="bed":
     var sleeper:String=model.bed_occupant(item.id) if item.floor==0 else ""
     text_block("床位：空闲 · 0/1人" if sleeper.is_empty() else "夜间："+sleeper+"使用 · 1/1人",GOLD)
    if definition.has("max"):text_block("数量 %d / %d · 拖到同类箱上可合并"%[item.amount,definition.max],MUTED)
    if item.kind=="cooler" and item.floor==0:
     action("夜间制冷："+("开启" if model.cooling_enabled else "关闭"),func():model.cooling_enabled=not model.cooling_enabled;refresh())
     text_block("准备期待机；高温夜间需车内发电机和燃油。",MUTED)
    if item.kind=="repair" and item.floor==0:action("使用修理包 · 车体+10",func():model.use_repair(selected_id);toast();refresh(),model.hull<model.max_hull,true)
   panel_body.add_child(HSeparator.new());item_actions(item)
  "recipe":
   var definition:Dictionary=Model.CATALOG[recipe_kind]
   panel_title.text=definition.name+"图纸"
   text_block("占用%d格 · 制作需1行动"%(definition.size.x*definition.size.y),GOLD);text_block(definition.desc)
   text_block("制作材料",MUTED)
   for kind in Model.RECIPES[recipe_kind].cost:
    var required:int=Model.RECIPES[recipe_kind].cost[kind]
    var have:int=model.quantity(kind)
    text_block("%s  %d / %d"%[Model.CATALOG[kind].name,have,required],INK if have>=required else GOLD)
    if have<required:text_block("来源："+source_for(kind),MUTED)
   var error:String=model.recipe_error(recipe_kind)
   action("制作 "+definition.name,func():craft(recipe_kind),error.is_empty(),true)
   if not error.is_empty():text_block(error,GOLD)
   action("取消追踪" if tracked_recipe==recipe_kind else "追踪材料缺口",func():tracked_recipe="" if tracked_recipe==recipe_kind else recipe_kind;render_panel())
   text_block("成品出现在下方待装区，装车后生效。",MUTED)
  "forecast":
   panel_title.text="抗灾准备"
   var forecast:Dictionary=model.forecast()
   text_block("第%d—21天 · 驻车预演"%forecast.from,MUTED)
   text_block("按当前配置可以撑过剩余灾难。" if forecast.projected_health>0 else "当前准备不足，预计无法撑过灾难。",INK if forecast.projected_health>0 else GOLD)
   text_block("饮水  %d / %d\n口粮  %d / %d\n制冷  可运行%d晚，预计耗%d油"%[model.quantity("water"),forecast.water,model.quantity("food"),forecast.food,forecast.cooling_nights,forecast.fuel])
   text_block("预计剩余健康 %d / %d"%[forecast.projected_health,model.max_health],GOLD)
   text_block("假设保持当前设备与库存、不外出、不生产。准备期剩余消耗另计。",MUTED)
   panel_body.add_child(HSeparator.new())
   text_block("7天热强度\n3 → 3 → 4 → 5 → 5 → 4 → 3")
   text_block("隔热层被动减热2；发电机配合制冷机耗1油/晚减热3。可以叠加，各计一套。",MUTED)
   text_block("余热每级扣4健康；需水=1+向上取整(余热÷2)。缺1水再扣6健康，缺1粮扣4；无损且有床的夜晚恢复2。",MUTED)
  "settlement":
   panel_title.text="第%d天结束"%settlement.day
   text_block("水 −%d   粮 −1   制冷油 −%d"%[settlement.plan.water,settlement.plan.fuel])
   text_block("健康 %s%d"%["+" if settlement.health_delta>=0 else "",settlement.health_delta],GOLD)
   text_block(settlement.report,MUTED)
   action("开始第%d天 →"%model.day,clear_selection,true,true)
  "log":
   panel_title.text="旅程记录"
   action("刷新记录",render_panel)
   for entry in model.logs:text_block(entry,MUTED)
  "menu":
   panel_title.text="菜单"
   text_block("点击设施查看和使用；拖动物品整理，或选中后点移动。R旋转，Esc返回。",MUTED)
   text_block("本轮目标：14天准备，挺过7天三日凌空。当前原型没有存档，退出会丢失本局。",MUTED)
   action("减少道路动态："+("开启" if reduced_motion else "关闭"),func():reduced_motion=not reduced_motion;refresh())
   action("重新开始",ask_restart)
