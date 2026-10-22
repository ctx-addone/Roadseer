extends Control
const Model=preload("res://scripts/vehicle_state.gd")
const Grid=preload("res://scripts/vehicle_grid.gd")
var model=Model.new()
var grid
var stats:Label
var objective:Label
var details:Label
var journal:Label
var inventory:VBoxContainer
var catalog:VBoxContainer
var level_label:Label
var route:OptionButton
var selected_id:int=-1
var selected_rotation:bool=false
var upgrade_button:Button

func _ready():
 var theme_new=Theme.new()
 var system_font=SystemFont.new();system_font.font_names=PackedStringArray(["PingFang SC","Noto Sans CJK SC"])
 theme_new.default_font=system_font;theme_new.default_font_size=16
 var style=StyleBoxFlat.new();style.bg_color=Color("253b49");style.set_corner_radius_all(6)
 style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=9;style.content_margin_bottom=9
 theme_new.set_stylebox("normal","Button",style)
 var over=style.duplicate();over.bg_color=Color("3b5a68");theme_new.set_stylebox("hover","Button",over)
 self.theme=theme_new
 var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
 add_child(margin)
 var root=VBoxContainer.new();root.add_theme_constant_override("separation",12);margin.add_child(root)
 var header=HBoxContainer.new();root.add_child(header)
 var heading=label("ROADSEER  /  公路先知",26);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(heading)
 header.add_child(label("P0 · PC 车辆背包共用底座",16))
 stats=label("",19);root.add_child(stats)
 objective=label("",16);root.add_child(objective)
 var columns=HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",22);root.add_child(columns)
 var left=VBoxContainer.new();left.custom_minimum_size.x=245;columns.add_child(left)
 left.add_child(label("制造设备",21))
 var cat_scroll=ScrollContainer.new();cat_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;cat_scroll.custom_minimum_size=Vector2(245,250);left.add_child(cat_scroll)
 catalog=VBoxContainer.new();catalog.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cat_scroll.add_child(catalog)
 for kind in Model.CATALOG:
  if kind in ["driver","seat"]:continue
  var def=Model.CATALOG[kind]
  var s:Vector2i=def.size
  var b=button("%s  %d×%d · %d材料"%[def.name,s.x,s.y,def.cost],func():model.build(kind);refresh())
  b.tooltip_text=def.desc;catalog.add_child(b)
 left.add_child(label("待装区 / 点击后放入网格",16))
 var inv_scroll=ScrollContainer.new();inv_scroll.custom_minimum_size=Vector2(245,160);left.add_child(inv_scroll)
 inventory=VBoxContainer.new();inventory.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inv_scroll.add_child(inventory)
 var center=VBoxContainer.new();center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(center)
 var floors=HBoxContainer.new();center.add_child(floors)
 for i in range(3):
  floors.add_child(button(["一层","二层 · Lv3","车顶 · Lv4"][i],func():model.floor_index=i;refresh()))
 grid=Grid.new();grid.model=model;grid.size_flags_vertical=Control.SIZE_EXPAND_FILL;center.add_child(grid)
 grid.item_selected.connect(select_item)
 grid.placement_requested.connect(func(id,f,p,r):
  if model.place(id,f,p,r):selected_id=-1
  refresh())
 grid.canceled.connect(clear_selection)
 center.add_child(label("点选搬移 / R 旋转 / 点击放置 / 右键或 Esc 取消",15))
 var actions=HBoxContainer.new();center.add_child(actions)
 actions.add_child(button("旋转 R",rotate_selection));actions.add_child(button("拆到待装区",func():model.remove(selected_id);clear_selection()))
 actions.add_child(button("取消选择",clear_selection))
 details=label("",16);details.custom_minimum_size.y=65;details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;center.add_child(details)
 var right=VBoxContainer.new();right.custom_minimum_size.x=310;columns.add_child(right)
 right.add_child(label("公路与建设",21))
 level_label=label("",17);right.add_child(level_label)
 route=OptionButton.new();route.add_item("探索型 · 行驶耗油降低");route.add_item("家园型 · 集水额外+1");right.add_child(route)
 upgrade_button=button("",func():model.upgrade("探索型" if route.selected==0 else "家园型");refresh());right.add_child(upgrade_button)
 right.add_child(button("探索公路  /  获得材料",func():model.advance("探索");refresh()))
 right.add_child(button("停车休整  /  运行生产",func():model.advance("休整");refresh()))
 right.add_child(button("应急补给  /  2材料",func():model.resupply();refresh()))
 right.add_child(button("挑战终点  /  灾难检查",func():model.finish();refresh()))
 right.add_child(label("行动记录",20))
 var log_scroll=ScrollContainer.new();log_scroll.custom_minimum_size.y=160;log_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(log_scroll)
 journal=label("",15);journal.custom_minimum_size.x=290;journal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;journal.size_flags_horizontal=Control.SIZE_EXPAND_FILL;log_scroll.add_child(journal)
 right.add_child(button("重新开始 P0",func():model=Model.new();grid.model=model;selected_id=-1;refresh()))
 refresh()

func label(text:String,font_size:int)->Label:
 var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",font_size);return l

func button(text:String,action:Callable)->Button:
 var b=Button.new();b.text=text;b.pressed.connect(action);b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;return b

func select_item(id:int):
 selected_id=id;selected_rotation=model.item_by_id(id).rotated;refresh()

func clear_selection():selected_id=-1;refresh()

func rotate_selection():
 if selected_id>=0:selected_rotation=not selected_rotation;refresh()

func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_R:rotate_selection()
  if event.keycode==KEY_ESCAPE:clear_selection()

func refresh():
 if grid==null:return
 var parts:PackedStringArray=[]
 for key in model.resources:parts.append("%s %d"%[key,model.resources[key]])
 stats.text="   |   ".join(parts)
 objective.text=model.outcome if not model.outcome.is_empty() else "目标：探索6次 + 3级车 + 已装厨房 + 水/食物各4 → 挑战终点（压缩验证流程）"
 level_label.text="回合 %d · 探索 %d/6\nLv%d · %s · %d×%d"%[model.turn,model.progress,model.level,model.branch,model.width,model.height]
 upgrade_button.text="升级车辆 · %d材料"%model.upgrade_cost() if model.level<4 else "已达P0等级上限"
 upgrade_button.disabled=model.level>=4 or not model.outcome.is_empty()
 for child in inventory.get_children():inventory.remove_child(child);child.queue_free()
 for item in model.items:
  if item.floor==-1:inventory.add_child(button(Model.CATALOG[item.kind].name,select_item.bind(item.id)))
 grid.selected_id=selected_id;grid.rotated=selected_rotation;grid.queue_redraw()
 if selected_id>=0:
  var item=model.item_by_id(selected_id)
  details.text=Model.CATALOG[item.kind].name+"："+Model.CATALOG[item.kind].desc
 else:details.text="先把待装区的集水器放进车内。设施只有安装后才生效。\n布局验证暂不模拟通道、乘员寻路和楼层连接。"
 journal.text="\n\n".join(model.logs)
