extends "res://tests/layout_a_drag.gd"
func capture(name_text:String):
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/roadseer-speed-"+name_text+".png")
func run():
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
 app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
 await process_frame;await process_frame;await process_frame
 # Controlled wall-clock steps use the real main loop; controls use viewport mouse/keyboard input.
 app.set_process(false)
 await capture("initial")
 await click("开始行驶")
 check(app.model.phase=="travel","start highway directly without destination menu")
 app._process(6)
 check(app.model.caches_today==1 and app.model.quantity("water")==8,"real loop collects first distance box")
 check(app.feedback.text.contains("饮水") and app.travel_readout.text.contains("40 km/h"),"visible pickup and actual speed")
 await capture("pickup")
 await click("暂停 Space")
 var km:float=app.model.distance_km;var time:float=app.model.minutes_left
 app._process(6)
 check(app.model.distance_km==km and app.model.minutes_left==time,"pause freezes time and distance")
 await click("继续 Space")
 await click("播放 ×1")
 check(app.speed==2 and app.model.vehicle_speed()==40,"playback never changes vehicle attribute")
 app._process(3)
 check(is_equal_approx(app.model.distance_km,40),"double playback doubles simulation time, not distance per game hour")
 await click("靠边停车")
 check(app.model.editable() and not app.paused,"stop unlocks inventory")
 await grid_click(0,1)
 check(app.panel=="item" and app.selected_id==11,"bed remains inspectable")
 await click("返回")
 await click("继续行驶")
 app._process(3)
 check(app.model.phase=="landmark" and app.model.pending_route=="salvage","actual road discovers first landmark")
 await capture("landmark")
 await click("停车探索")
 check(app.model.phase=="combat" and app.model.minutes_left==210,"UI exploration spends hour")
 await capture("combat")
 var ticks:int=0
 while app.model.phase=="combat" and ticks<60:app._process(0.5);ticks+=1
 check(app.model.editable() and app.model.ground().size()==3,"auto combat delivers physical cargo")
 await capture("loot")
 await click("继续行驶")
 check(app.discard_dialog.visible,"loose cargo confirmation shown")
 app.discard_dialog.get_cancel_button().pressed.emit();app.discard_dialog.hide()
 await process_frame
 check(app.model.editable() and app.model.ground().size()==3,"cancel keeps cargo")
 # Workshop fixture with legitimate non-overlapping grid slots.
 app.model=app.Model.new();app.model.height=10;app.model.expansion_level=2;app.road_view.pickup_flash=0
 app.model.add_item("bench",1,0,Vector2i(0,6))
 app.model.store_generated("scrap",4)
 app.grid.model=app.model;app.road_view.model=app.model;app.clear_selection();app.refresh()
 app.grid_scroll.scroll_vertical=10000
 await process_frame;await process_frame;await process_frame
 await grid_click(0,6)
 check(app.panel_title.text=="制作台","workbench opens secondary panel")
 await click("提升至60 km/h")
 check(app.model.vehicle_speed()==60 and app.model.minutes_left==300,"engine upgrade button commits real resources/time")
 await capture("engine")
 app.clear_selection();app.refresh()
 await click("开始行驶")
 app._process(6) # playback remains x2: 60 minutes at 60km/h.
 check(app.model.phase=="landmark","upgraded engine reaches site in one game hour")
 var before:float=app.model.minutes_left
 await click("略过地点")
 check(app.model.phase=="travel" and app.model.minutes_left==before,"skip via left road costs no time")
 await click("靠边停车")
 await click("结束第1天")
 check(app.model.day==2 and app.model.minutes_left==360 and app.panel=="settlement","day settlement resets time and preserves km")
 await capture("settlement")
 root.size=Vector2i(1280,820)
 await click("开始第2天")
 app.grid_scroll.scroll_vertical=0
 await capture("small")
 check(app.road_action.get_global_rect().end.y<=root.get_visible_rect().size.y and app.travel_button.get_global_rect().end.x<=root.get_visible_rect().size.x,"minimum window controls fit")
 print("INPUT VERIFICATION failures=",failures)
 quit(1 if failures else 0)
