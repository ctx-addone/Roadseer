extends SceneTree
var app
var failures:int=0
func check(ok:bool,why:String):
 if not ok:failures+=1;push_error(why)
func _initialize():call_deferred("run")
func find_button(node:Node,prefix:String):
 if node is Button and node.text.begins_with(prefix) and node.is_visible_in_tree():return node
 for child in node.get_children():
  var found=find_button(child,prefix)
  if found!=null:return found
 return null
func click_at(point:Vector2):
 var input_viewport=app.discard_dialog if app!=null and app.discard_dialog.visible else root
 var motion=InputEventMouseMotion.new();motion.position=point;input_viewport.push_input(motion,true)
 var down=InputEventMouseButton.new();down.position=point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;input_viewport.push_input(down,true)
 var up=InputEventMouseButton.new();up.position=point;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;input_viewport.push_input(up,true)
 await process_frame;await process_frame
func click(prefix:String):
 await process_frame;await process_frame
 await process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 var target=find_button(app,prefix)
 check(target!=null,"button exists: "+prefix)
 if target==null:return
 var parent=target.get_parent()
 while parent!=null:
  if parent is ScrollContainer:parent.ensure_control_visible(target)
  parent=parent.get_parent()
 await process_frame;await process_frame
 await process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 print("CLICK ",prefix," ",target.get_global_rect()," window ",root.size," final ",root.get_final_transform())
 await click_at(target.get_global_rect().get_center())
func key(code:int):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true)
 await process_frame
 event=InputEventKey.new();event.keycode=code;event.pressed=false;root.push_input(event,true)
 await process_frame
func grid_click(x:int,y:int):
 await click_at(app.grid.global_position+app.grid.cell_center(Vector2i(x,y)))
func capture(name:String):
 await process_frame;await process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("/tmp/roadseer-layout-a-"+name+".png")
func tile_for(node:Node,id:int):
 if node.get_script()==load("res://scripts/cargo_card.gd") and node.item_id==id:return node
 for child in node.get_children():
  var found=tile_for(child,id)
  if found!=null:return found
 return null
func click_tile(id:int):
 await process_frame;await process_frame;await process_frame
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 var tile=tile_for(app,id);check(tile!=null,"tile exists")
 if tile==null:return
 var parent=tile.get_parent()
 while parent!=null:
  if parent is ScrollContainer:parent.ensure_control_visible(tile)
  parent=parent.get_parent()
 await process_frame;await process_frame
 await click_at(tile.get_global_rect().get_center())
func run():
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 await process_frame;await process_frame
 await capture("initial")
 check(app.model.members.size()==1 and app.model.seat_occupant(1)=="主角","one protagonist occupies driver seat")
 check(app.model.footprint(app.model.item_by_id(1))==Vector2i.ONE,"driver uses one cell")
 check(app.model.count_active("bed")==1 and app.model.rest_assignments().size()==1,"starter single bed supports protagonist")
 for sign in app.road_view.route_buttons.values():
  check(app.road_view.get_global_rect().encloses(sign.get_global_rect()),"route sign inside road")
 await grid_click(0,0)
 check(app.selected_id==1 and app.panel=="item","click occupied seat shows details")
 await grid_click(1,0)
 check(app.selected_id==2 and app.model.seat_occupant(2).is_empty(),"guest seat explicitly empty")
 await grid_click(0,1)
 check(app.model.item_by_id(app.selected_id).kind=="bed","bed accessible in cabin")
 await capture("bed")
 await click("成员")
 check(app.panel=="crew","HUD opens single-member details")
 await capture("crew")
 await click("返回")
 check(app.road_view.visible and app.grid.visible and not app.ground_box.visible,"road and cabin persistent; empty loot hidden")
 await grid_click(0,2)
 check(app.panel=="item" and not app.moving,"equipment click inspects without moving")
 await grid_click(2,2)
 check(app.model.item_by_id(5).pos==Vector2i(0,2) and app.selected_id==7,"second inspection does not move weapon")
 await click("返回")
 await click("搭建制作台")
 var bench_id:int=app.selected_id
 check(app.model.actions==1 and app.model.ground().size()==1 and app.moving,"bootstrap creates physical workbench")
 await grid_click(0,0)
 check(app.model.item_by_id(bench_id).floor==-1,"invalid placement retains bench")
 await key(KEY_ESCAPE)
 await grid_click(1,4)
 await key(KEY_R)
 await grid_click(1,4)
 check(app.model.item_by_id(10).rotated,"rotation and upright placement")
 await click_tile(bench_id)
 await grid_click(2,4)
 check(app.model.count_active("bench")==1 and app.panel=="workshop" and not app.moving,"installed workbench opens workshop")
 await capture("workshop")
 await click("隔热层")
 check(app.panel=="recipe" and app.recipe_kind=="shade","workshop recipe detail")
 await click("追踪材料缺口")
 check(app.tracked_recipe=="shade","track blueprint")
 await click("返回")
 check(app.panel=="home","return to home")
 await capture("goal")
 await grid_click(2,4)
 check(app.panel=="workshop" and not app.moving,"click workshop opens secondary UI")
 await click("移动")
 await grid_click(0,0)
 check(app.model.item_by_id(bench_id).pos==Vector2i(2,4) and app.moving,"invalid move retains position")
 await key(KEY_ESCAPE)
 await click("破损车辆")
 check(app.model.phase=="stop" and app.model.actions==1,"selecting route does not depart")
 check(app.panel=="explore" and app.panel_title.text=="路线情报","right pane contains chosen route detail")
 check(find_button(app.panel_body,"破损车辆")==null and find_button(app.panel_body,"出发")==null,"right pane has no duplicate route selection or departure")
 check(app.road_action.get_global_rect().end.x<app.grid_scroll.get_global_rect().position.x,"departure remains below road")
 await capture("routes")
 await click("出发 ·")
 check(app.model.phase=="travel" and app.road_view.visible and app.grid.visible,"journey retains road and cabin")
 check(not app.model.editable() and app.travel_button.disabled,"journey locks inventory and end day")
 var fuel:int=app.model.quantity("fuel")
 app.request_outing("supply")
 check(app.model.quantity("fuel")==fuel,"double departure rejected")
 await click("暂停 Space")
 var progress:float=app.road_view.progress
 await create_timer(0.15).timeout
 check(app.road_view.progress==progress,"pause freezes journey")
 await capture("travel")
 await click("继续 Space")
 await create_timer(3.1).timeout
 check(app.model.phase=="combat" and app.road_view.visible and app.grid.visible,"combat happens alongside inventory")
 if app.model.phase!="combat":quit(1);return
 await click("暂停 Space")
 var tick:int=app.model.combat.tick
 await create_timer(1.0).timeout
 check(tick==app.model.combat.tick,"pause freezes battle")
 await click("继续 Space")
 await create_timer(1.0).timeout
 await click("暂停 Space")
 await capture("battle")
 while app.model.phase=="combat":app.model.combat_step()
 app.panel="home";app.refresh()
 check(app.ground_box.visible and app.grid.visible and app.road_view.visible,"loot returns to inventory layout")
 await capture("loot")
 # Check translated stack placement with actual clicks.
 var metal_id:int=-1
 for item in app.model.ground():
  if item.kind=="scrap":metal_id=item.id
 await click_tile(metal_id)
 await grid_click(1,4)
 check(app.model.quantity("scrap")==6,"merge physical material in upright grid")
 await click("结束第1天")
 check(app.discard_dialog.visible,"day end confirms remaining ground")
 app.discard_dialog.get_cancel_button().pressed.emit()
 await process_frame;await process_frame
 check(not app.discard_dialog.visible and app.model.day==1,"cancel preserves day")
 await click("结束第1天")
 app.discard_dialog.get_ok_button().pressed.emit()
 await process_frame;await process_frame
 check(app.model.day==2 and app.panel=="settlement","day summary shown")
 await capture("settlement")
 await click("开始第2天")
 await grid_click(2,4)
 await click("扩容到4×8")
 check(app.model.height==8 and app.model.actions==1,"expansion through installed workbench")
 await click("抗灾预报")
 check(app.panel=="forecast","forecast entry")
 await capture("forecast")
 root.size=Vector2i(1280,820);root.content_scale_size=Vector2i(1280,820)
 await process_frame;await process_frame;await capture("small")
 check(app.travel_button.get_global_rect().end.y<=820,"primary action visible at compact size")
 # Exercise safe encounter and prevent duplicate rewards.
 app.reset_run();await process_frame
 app.request_outing("supply")
 await create_timer(3.1).timeout
 check(app.model.phase=="encounter" and app.model.ground().is_empty(),"safe arrival waits for crate interaction")
 check(app.grid.visible and not app.model.editable(),"encounter keeps cabin visible and locked")
 var cost_fuel:int=app.model.quantity("fuel")
 await capture("crate")
 await click_at(app.road_view.global_position+app.road_view.encounter_rect.get_center())
 check(app.model.phase=="stop" and app.model.ground().size()==3,"road crate click grants loot")
 app.collect_road_loot()
 check(app.model.ground().size()==3 and app.model.quantity("fuel")==cost_fuel,"crate cannot duplicate loot or charge twice")
 # Expansion must scroll, rather than shrinking the inventory below usable cell size.
 app.model.height=10;app.model.expansion_level=2;app.refresh()
 await process_frame;await process_frame
 check(app.grid.cell>=47.5,"expanded grid keeps readable cells")
 check(app.grid_scroll.get_v_scroll_bar().max_value>app.grid_scroll.size.y,"long cabin scrolls")
 app.grid_scroll.scroll_vertical=10000
 await process_frame;await process_frame
 check(app.grid_scroll.get_global_rect().has_point(app.grid.global_position+app.grid.cell_center(Vector2i(3,9))),"rear cells reachable by scrolling")
 await capture("expanded-loot-small")
 app.reset_run();app.model.day=15;app.refresh();app.request_outing("arms")
 await create_timer(3.1).timeout
 app.paused=true;app.refresh()
 check(app.model.phase=="combat" and app.model.health==58,"heat outing and armored road encounter")
 await capture("heat-combat-small")
 print("LAYOUT A INPUT failures=",failures)
 quit(1 if failures else 0)
