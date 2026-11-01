extends "res://tests/layout_a_drag.gd"
var output:String=""

func capture(name_text:String):
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 if output.is_empty():return
 check(root.get_texture().get_image().save_png(output.path_join(name_text+".png"))==OK,"save screenshot "+name_text)

func run():
 output=OS.get_environment("ROADSEER_TEST_OUTPUT_DIR")
 if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
 app=load("res://scenes/storage_demo.tscn").instantiate();root.add_child(app)
 await process_frame;await process_frame;await process_frame
 app.set_process(false)
 check(app.model.items.size()==11,"demo opens with normal starter vehicle")
 await capture("storage-start")
 await click("开始行驶")
 app._process(6)
 await click("靠边停车")
 check(app.model.quantity("wood")==3,"pallet collected through live road loop")
 await click("木工与收纳合成")
 for i in range(3):await click("加工4木板")
 check(app.model.quantity("plank")==12,"crafting buttons produce real boards")
 await capture("storage-crafting")
 # Reorganize metal with viewport keyboard rotation, leaving 2x2 for workbench.
 app.clear_selection();app.refresh()
 await grid_click(1,4);await key(KEY_R);await grid_click(1,4)
 check(app.model.item_by_id(10).rotated,"metal rotation through keyboard")
 app.clear_selection();app.refresh()
 await click("木工与收纳合成")
 await click("搭建制作台")
 await grid_click(2,4)
 check(app.model.count_active("bench")==1,"crafted bench installs through viewport")
 await click("木工与收纳合成")
 await click("制作小木箱")
 var box_id:int=app.model.next_id-1
 await grid_click(2,0)
 check(app.model.cargo_on_seat(3).get("id",-1)==box_id,"crafted box loads empty seat")
 # Drag existing ammo into the visible box rather than a menu shortcut.
 var source:Vector2=app.grid.global_position+app.grid.cell_center(Vector2i(1,2))
 var target:Vector2=app.grid.global_position+app.grid.cell_center(Vector2i(2,0))
 await drag(source,target)
 check(app.model.contents(box_id).size()==1 and app.model.quantity("ammo")==30,"viewport drag deposits ammo without loss")
 await grid_click(2,0)
 await capture("storage-seat-box")
 await click("移动")
 await grid_click(1,2)
 check(app.model.reachable_ammo(app.model.item_by_id(5))==30,"moving loaded box connects machine gun")
 await capture("storage-feeding")
 await click("弹药")
 check(app.model.ground().size()==1 and app.model.contents(box_id).is_empty(),"container slot click withdraws physical cargo")
 await grid_click(3,0)
 check(app.model.cargo_on_seat(4).kind=="ammo","withdrawn ammo loads a different empty seat")
 # Put the reserve back into the box, then reach a genuine road battle.
 source=app.grid.global_position+app.grid.cell_center(Vector2i(3,0))
 target=app.grid.global_position+app.grid.cell_center(Vector2i(1,2))
 await drag(source,target)
 app.clear_selection();app.refresh()
 await click("继续行驶")
 app._process(12)
 check(app.model.phase=="landmark","next landmark reached")
 await click("停车探索")
 while app.model.phase=="combat":app._process(0.9)
 check(app.model.editable() and app.model.quantity("ammo")+int(app.model.item_by_id(5).get("loaded",0))==24,"real battle consumes six rounds with adjacent reload")
 await capture("storage-after-battle")
 app.reset_run()
 check(app.model.quantity("wood")==0 and app.model.quantity("ammo")==30 and app.model.items.size()==11,"restart preserves experiment mode without stale contents")
 print("STORAGE INPUT failures=",failures)
 quit(1 if failures else 0)
