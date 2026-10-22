extends Control
const Model=preload("res://scripts/vehicle_state.gd")
const Grid=preload("res://scripts/vehicle_grid.gd")
const BattleView=preload("res://scripts/battle_view.gd")
var model=Model.new()
var grid
var battle_view
var stats:Label
var progress_label:Label
var description_label:Label
var details:Label
var journal:Label
var ground_list:VBoxContainer
var decisions:VBoxContainer
var report:Label
var travel_button:Button
var pause_button:Button
var speed_button:Button
var drop_button:Button
var use_button:Button
var rotate_button:Button
var ground_heading:Label
var feedback:Label
var selected_id:int=-1
var selected_rotation:bool=false
var paused:bool=false
var speed:int=1
var clock_accum:float=0.0
var discard_dialog:ConfirmationDialog
var restart_dialog:ConfirmationDialog
var next_variant:int=0
var restart_was_paused:bool=false

func _ready():
 get_tree().root.gui_embed_subwindows=true
 get_window().min_size=Vector2i(1280,820)
 var t=Theme.new()
 var f=SystemFont.new();f.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC"])
 t.default_font=f;t.default_font_size=16
 for state in ["normal","hover","pressed","disabled","focus"]:
  var style=StyleBoxFlat.new()
  style.bg_color={"normal":Color("2d4653"),"hover":Color("3c606e"),"pressed":Color("426e77"),"disabled":Color("23313b"),"focus":Color(0,0,0,0)}[state]
  style.set_corner_radius_all(6)
  style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=9;style.content_margin_bottom=9
  if state=="focus":style.set_border_width_all(2);style.border_color=Color("c7b582")
  t.set_stylebox(state,"Button",style)
 t.set_color("font_disabled_color","Button",Color("778d9b"))
 theme=t
 var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
 add_child(margin)
 var root=VBoxContainer.new();root.add_theme_constant_override("separation",10);margin.add_child(root)
 var header=HBoxContainer.new();root.add_child(header)
 var title=label("ROADSEER   /   干旱公路",26);title.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(title)
 header.add_child(label("片段一 · 单局构筑 · 自动战斗",15))
 header.add_child(button("重新开始",func():ask_restart(model.variant)))
 stats=label("",18);root.add_child(stats)
 progress_label=label("",14);root.add_child(progress_label)
 var columns=HBoxContainer.new();columns.size_flags_vertical=SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",18);root.add_child(columns)
 var left=VBoxContainer.new();left.custom_minimum_size.x=324;left.size_flags_horizontal=SIZE_EXPAND_FILL;left.size_flags_stretch_ratio=0.9;columns.add_child(left)
 left.add_child(label("01  车辆背包",21))
 left.add_child(label("点选物品 → 点击空位放置；同类箱可合并",13))
 grid=Grid.new();grid.model=model;grid.size_flags_vertical=SIZE_EXPAND_FILL;left.add_child(grid)
 grid.item_selected.connect(select_item)
 grid.placement_requested.connect(place_item)
 grid.canceled.connect(clear_selection)
 var actions=HBoxContainer.new();left.add_child(actions)
 rotate_button=button("旋转 R",rotate_selection);actions.add_child(rotate_button)
 drop_button=button("放到地面",drop_selection);actions.add_child(drop_button)
 actions.add_child(button("取消 Esc",clear_selection))
 use_button=button("使用选中的修理包",func():model.use_repair(selected_id);refresh());left.add_child(use_button)
 details=paragraph("",310);details.custom_minimum_size.y=95;left.add_child(details)
 var center=VBoxContainer.new();center.custom_minimum_size.x=440;center.size_flags_horizontal=SIZE_EXPAND_FILL;center.size_flags_stretch_ratio=1.3;columns.add_child(center)
 center.add_child(label("02  公路与遭遇",21))
 battle_view=BattleView.new();battle_view.model=model;center.add_child(battle_view)
 var transport=HBoxContainer.new();center.add_child(transport)
 pause_button=button("暂停战斗",toggle_pause);transport.add_child(pause_button)
 speed_button=button("播放 ×1",func():speed=2 if speed==1 else 1;refresh(false));transport.add_child(speed_button)
 transport.add_child(label("整理时不耗时",13))
 description_label=paragraph("",420);description_label.custom_minimum_size.y=94;center.add_child(description_label)
 var decision_scroll=ScrollContainer.new();decision_scroll.size_flags_vertical=SIZE_EXPAND_FILL;decision_scroll.custom_minimum_size.y=115;center.add_child(decision_scroll)
 decisions=VBoxContainer.new();decisions.size_flags_horizontal=SIZE_EXPAND_FILL;decisions.add_theme_constant_override("separation",8);decision_scroll.add_child(decisions)
 report=paragraph("",420);report.custom_minimum_size.y=43;report.add_theme_color_override("font_color",Color("d9bf8b"));center.add_child(report)
 travel_button=button("",request_departure);travel_button.custom_minimum_size.y=48;center.add_child(travel_button)
 var right=VBoxContainer.new();right.custom_minimum_size.x=280;right.size_flags_horizontal=SIZE_EXPAND_FILL;right.size_flags_stretch_ratio=0.7;columns.add_child(right)
 ground_heading=label("03  停靠点地面",20);right.add_child(ground_heading)
 right.add_child(label("这里不是仓库：出发会丢弃未装车物品",13))
 var ground_scroll=ScrollContainer.new();ground_scroll.custom_minimum_size.y=220;right.add_child(ground_scroll)
 ground_list=VBoxContainer.new();ground_list.size_flags_horizontal=SIZE_EXPAND_FILL;ground_scroll.add_child(ground_list)
 feedback=paragraph("",270);feedback.custom_minimum_size.y=52;feedback.add_theme_color_override("font_color",Color("e6c583"));right.add_child(feedback)
 right.add_child(label("行动与战斗记录 · 最新在上",17))
 var log_scroll=ScrollContainer.new();log_scroll.size_flags_vertical=SIZE_EXPAND_FILL;log_scroll.custom_minimum_size.y=160;right.add_child(log_scroll)
 journal=paragraph("",270);journal.add_theme_font_size_override("font_size",14);log_scroll.add_child(journal)
 discard_dialog=ConfirmationDialog.new();discard_dialog.title="地面物资尚未装车";discard_dialog.ok_button_text="放弃地面物资并出发";discard_dialog.cancel_button_text="继续整理";discard_dialog.dialog_autowrap=true;add_child(discard_dialog)
 discard_dialog.confirmed.connect(func():perform_departure(true))
 restart_dialog=ConfirmationDialog.new();restart_dialog.title="重新开始这趟旅程";restart_dialog.dialog_text="当前车辆与物资将清空。没有局外成长，退出游戏也不会保留本局。";restart_dialog.ok_button_text="开始新一局";restart_dialog.cancel_button_text="继续本局";add_child(restart_dialog)
 restart_dialog.confirmed.connect(func():reset_run(next_variant))
 restart_dialog.canceled.connect(func():paused=restart_was_paused;refresh(false))
 refresh()
 print("ROADSEER_SLICE_ONE_READY: 8 nodes, physical cargo, automatic combat")

func _process(delta:float):
 if model.phase!="combat" or paused:return
 clock_accum+=delta*speed
 if clock_accum>=0.85:
  clock_accum-=0.85
  model.combat_step();battle_view.pulse()
  grid.highlighted=[]
  for effect in model.effects:
   if effect.has("id"):grid.highlighted.append(effect.id)
  refresh(model.phase!="combat")

func label(text:String,font_size:int=16)->Label:
 var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",font_size);return l

func paragraph(text:String,min_width:float)->Label:
 var l=label(text);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x=min_width;l.size_flags_horizontal=SIZE_EXPAND_FILL;return l

func button(text:String,action:Callable)->Button:
 var b=Button.new();b.text=text;b.pressed.connect(action);b.mouse_default_cursor_shape=CURSOR_POINTING_HAND;return b

func wipe(container:Node):
 for child in container.get_children():container.remove_child(child);child.queue_free()

func select_item(id:int):
 if not model.editable():return
 var item=model.item_by_id(id)
 if item.is_empty():return
 selected_id=id;selected_rotation=item.rotated;refresh(false)

func place_item(id:int,f:int,p:Vector2i,r:bool):
 if model.merge_at(id,p):
  if model.item_by_id(id).is_empty():selected_id=-1
 elif model.place(id,f,p,r):selected_id=-1
 refresh()

func clear_selection():selected_id=-1;refresh(false)
func rotate_selection():
 if selected_id>=0 and model.editable():selected_rotation=not selected_rotation;refresh(false)
func drop_selection():
 if model.drop(selected_id):selected_id=-1
 refresh()

func toggle_pause():
 if model.phase=="combat":paused=not paused;refresh(false)

func request_departure():
 if not model.departure_error().is_empty():model.note(model.departure_error());refresh(false);return
 if not model.ground().is_empty():
  var names:PackedStringArray=[]
  for item in model.ground():names.append("%s ×%d"%[Model.CATALOG[item.kind].name,item.amount])
  discard_dialog.dialog_text="以下物品还在地面：\n"+"、".join(names)+"\n\n出发后无法返回取回。"
  discard_dialog.popup_centered(Vector2i(580,230))
 else:perform_departure(false)

func perform_departure(discard:bool):
 if model.depart(discard):selected_id=-1;paused=false;clock_accum=0;grid.highlighted=[]
 refresh()

func ask_restart(run_variant:int):
 next_variant=run_variant
 restart_was_paused=paused;paused=true;refresh(false)
 restart_dialog.popup_centered(Vector2i(530,160))

func reset_run(run_variant:int):
 model=Model.new(run_variant);grid.model=model;battle_view.model=model
 selected_id=-1;paused=false;clock_accum=0;grid.highlighted=[];refresh()

func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_R:rotate_selection()
  if event.keycode==KEY_ESCAPE:clear_selection()
  if event.keycode==KEY_SPACE:toggle_pause()

func refresh(rebuild:bool=true):
 if grid==null:return
 if model.item_by_id(selected_id).is_empty():selected_id=-1
 stats.text="耐久 %d/%d    水 %d    口粮 %d    油 %d    弹药 %d    材料 %d    |    样本%s · %d/%d格"%[model.hull,model.max_hull,model.quantity("water"),model.quantity("food"),model.quantity("fuel"),model.quantity("ammo"),model.quantity("scrap"),["A","B"][model.variant],model.used_cells(),model.width*model.height]
 var nodes:PackedStringArray=[]
 for i in range(Model.NODE_NAMES.size()):nodes.append(("● " if i==model.node else "✓ " if i<model.node else "○ ")+Model.NODE_NAMES[i])
 progress_label.text="   →   ".join(nodes)
 description_label.text=model.description()
 grid.selected_id=selected_id;grid.rotated=selected_rotation;grid.queue_redraw();battle_view.queue_redraw()
 pause_button.disabled=model.phase!="combat";pause_button.text="继续战斗 Space" if paused else "暂停战斗 Space"
 speed_button.text="播放 ×%d"%speed;speed_button.disabled=model.phase!="combat"
 rotate_button.disabled=selected_id<0 or not model.editable()
 drop_button.disabled=selected_id<0 or not model.editable()
 use_button.disabled=true
 var item=model.item_by_id(selected_id)
 if not item.is_empty():
  var d:Dictionary=Model.CATALOG[item.kind]
  details.text="%s · %d×%d%s\n%s"%[d.name,model.footprint(item).x,model.footprint(item).y," · %d/%d"%[item.amount,d.max] if d.has("max") else "",d.desc]
  drop_button.disabled=not model.editable() or item.floor<0 or d.get("fixed",false)
  use_button.disabled=not model.editable() or item.kind!="repair" or item.floor<0 or model.hull>=model.max_hull
 else:details.text="绿色预览可放置，红色表示冲突。R旋转，右键/Esc取消。\n物资堆叠有上限；消耗完会腾出格子。座位在本片段保留。"
 feedback.text=model.logs[0] if not model.logs.is_empty() else ""
 journal.text="\n\n".join(model.logs)
 report.text=model.last_report
 travel_button.disabled=not model.departure_error().is_empty()
 if model.phase=="combat":travel_button.text="自动战斗中 · 可暂停观察"
 elif model.phase=="ended":travel_button.text="本局结束 · 在上方选择再来一局"
 else:
  var cost:Dictionary=model.travel_cost()
  travel_button.text="出发 → %s  |  %d油 / %d水 / 1口粮"%[Model.NODE_NAMES[mini(model.node+1,7)],cost.fuel,cost.water]
 if not rebuild:return
 wipe(ground_list)
 ground_heading.text="03  地面物品 · %d件"%model.ground().size()
 if model.ground().is_empty():ground_list.add_child(paragraph("暂无待装物品。\n获得奖励后会放在这里。",265))
 for ground_item in model.ground():
  var d:Dictionary=Model.CATALOG[ground_item.kind]
  var s:Vector2i=d.size
  var b=button("%s%s  ·  %d×%d"%[d.name," ×%d"%ground_item.amount if d.has("max") else "",s.x,s.y],select_item.bind(ground_item.id))
  b.tooltip_text=d.desc;b.disabled=not model.editable();ground_list.add_child(b)
 wipe(decisions)
 if model.phase=="ended":
  decisions.add_child(label("旅程完成" if model.won else "下一局可以改变准备",23))
  decisions.add_child(paragraph("本局射击%d次，耗弹%d，减伤%d。\n你最想保留哪件设备？下次会腾出哪些格子？"%[model.metrics.shots,model.metrics.ammo,model.metrics.blocked],420))
  decisions.add_child(button("用相同样本再试",func():ask_restart(model.variant)))
  decisions.add_child(button("换一组奖励 / 敌人数值再试",func():ask_restart(1-model.variant)))
  for battle_report in model.battle_reports:decisions.add_child(paragraph(battle_report,420))
  return
 if model.phase=="combat":
  decisions.add_child(paragraph("小爱正在自动控制武器。\n金色弹道：己方开火；红色弹道：敌方攻击；蓝色弧线：防护生效。\n暂停可阅读右侧日志；战斗期间不能搬移或换装。",420));return
 if model.node==3:
  decisions.add_child(label("先选路线，再选一组奖励",17))
  decisions.add_child(button(("✓ " if model.route=="short" else "")+"干河床 · 1油/2水 · 装甲车 · 营地4水",func():model.choose_route("short");refresh()))
  decisions.add_child(button(("✓ " if model.route=="water" else "")+"旧水站 · 2油/1水 · 兽群 · 营地6水",func():model.choose_route("water");refresh()))
 var offers:Array=model.offers()
 if not offers.is_empty():decisions.add_child(label("奖励三选一 · 向下滚动查看全部",14))
 for i in range(offers.size()):
  var offer:Dictionary=offers[i]
  decisions.add_child(button(offer.title,func():model.choose_reward(i);refresh()))
  var hint=paragraph(offer.hint,420);hint.add_theme_font_size_override("font_size",13);decisions.add_child(hint)
 if model.node==4:
  var expansion=button("扩容到4×8 · 消耗6材料" if not model.expanded else "已扩容 · 增加8格",func():model.upgrade();refresh())
  expansion.disabled=model.expanded;decisions.add_child(expansion)
  var repair=button("维修车体 +6 · 消耗2材料",func():model.workshop_repair();refresh());repair.disabled=model.hull>=model.max_hull;decisions.add_child(repair)
 if offers.is_empty() and model.node!=4 and model.node!=3:
  decisions.add_child(paragraph("整理完成后点击下方出发。\n选中车内设备后可放到地面腾位置；本节点离开前可以装回。",420))
