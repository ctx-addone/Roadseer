extends RefCounted
## Shared, in-memory prototype model. Footprints and economy are test values.
const CATALOG = {
 "driver": {"name":"驾驶位", "size":Vector2i(1,2), "cost":0, "zone":"inside", "color":"6386a0", "desc":"行驶必需。不可拆卸；可在车内一层搬移。"},
 "seat": {"name":"客座", "size":Vector2i(1,2), "cost":0, "zone":"inside", "color":"465b70", "desc":"占位样本；暂定1×2，可拆到待装区。尚无乘员模拟。"},
 "collector": {"name":"集水器", "size":Vector2i(2,2), "cost":4, "zone":"inside", "color":"3a9ca8", "desc":"每回合产水3。基础需求每回合耗水2。"},
 "kitchen": {"name":"厨房", "size":Vector2i(2,2), "cost":5, "zone":"inside", "color":"c28b50", "desc":"每回合把1原料加工为3食物。"},
 "culture": {"name":"培养皿", "size":Vector2i(2,3), "cost":6, "zone":"inside", "color":"71985e", "desc":"每回合消耗1水和1电，产2原料。"},
 "room": {"name":"房间", "size":Vector2i(2,3), "cost":4, "zone":"inside", "color":"9b799d", "desc":"休整额外修复2耐久。暂未模拟睡眠和乘员。"},
 "bathroom": {"name":"卫生间", "size":Vector2i(1,2), "cost":4, "zone":"inside", "color":"71aaa4", "desc":"回收系统：每回合耗水降低1。原型最低需求为1。"},
 "storage": {"name":"存储室", "size":Vector2i(2,2), "cost":4, "zone":"inside", "color":"a18c65", "desc":"一般资源容量+15；基础每种资源容量30。"},
 "command": {"name":"指挥室", "size":Vector2i(2,2), "cost":6, "zone":"inside", "color":"9a6570", "desc":"遭遇战损降低3，最低战损1。"},
 "solar": {"name":"太阳能板", "size":Vector2i(2,2), "cost":5, "zone":"roof", "color":"527fc0", "desc":"仅车顶；每回合发电3。"},
 "arm": {"name":"机械臂", "size":Vector2i(1,3), "cost":6, "zone":"roof", "color":"c4924c", "desc":"仅车顶；每次探索额外获得2材料。"},
 "drone": {"name":"无人机平台", "size":Vector2i(2,2), "cost":6, "zone":"roof", "color":"8b7fbd", "desc":"仅车顶；揭示下一次遭遇并降低2战损。"},
 "statue": {"name":"幸运树桩", "size":Vector2i(1,1), "cost":3, "zone":"inside", "color":"7f9c64", "desc":"每回合产1原料。游戏化测试效果。"}
}
var width:int=4
var height:int=6
var level:int=1
var floor_index:int=0
var branch:String="未选择"
var turn:int=1
var progress:int=0
var resources={"材料":14,"水":14,"食物":14,"燃油":14,"原料":3,"电力":0,"耐久":30}
var items:Array=[]
var next_id:int=1
var logs:Array[String]=[]
var outcome:String=""

func _init():
 add_item("driver",0,Vector2i(0,0))
 for x in range(1,4): add_item("seat",0,Vector2i(x,0))
 add_item("collector",-1,Vector2i.ZERO)
 logs.append("P0 共用底座：搭建生产链，探索扩容，解锁二层与车顶。")

func add_item(kind:String, floor_id:int=-1, pos:Vector2i=Vector2i.ZERO)->int:
 var id:int=next_id
 next_id+=1
 items.append({"id":id,"kind":kind,"floor":floor_id,"pos":pos,"rotated":false})
 return id

func item_by_id(id:int)->Dictionary:
 for item in items:
  if item.id==id:return item
 return {}

func footprint(item:Dictionary)->Vector2i:
 var s:Vector2i=CATALOG[item.kind].size
 return Vector2i(s.y,s.x) if item.rotated else s

func floor_unlocked(f:int)->bool:
 return f==0 or (f==1 and level>=3) or (f==2 and level>=4)

func placement_error(item:Dictionary,f:int,p:Vector2i)->String:
 if not floor_unlocked(f):return "该楼层尚未解锁"
 if CATALOG[item.kind].zone=="roof" and f!=2:return "该设备只能安装在车顶"
 if CATALOG[item.kind].zone=="inside" and f==2:return "该设施只能安装在车内"
 if item.kind=="driver" and f!=0:return "驾驶位必须留在车内一层"
 var s:Vector2i=footprint(item)
 if p.x<0 or p.y<0 or p.x+s.x>width or p.y+s.y>height:return "超出车辆边界"
 var rect=Rect2i(p,s)
 for other in items:
  if other.id!=item.id and other.floor==f and rect.intersects(Rect2i(other.pos,footprint(other))):return "与现有设施重叠"
 return ""

func place(id:int,f:int,p:Vector2i,rotated:bool)->bool:
 if not outcome.is_empty():return false
 var item=item_by_id(id)
 if item.is_empty():return false
 var candidate=item.duplicate()
 candidate.rotated=rotated
 var error=placement_error(candidate,f,p)
 if not error.is_empty():note(error);return false
 item.floor=f;item.pos=p;item.rotated=rotated
 note("已放置 %s"%CATALOG[item.kind].name)
 return true

func remove(id:int):
 if not outcome.is_empty():return
 var item=item_by_id(id)
 if item.is_empty():return
 if item.kind=="driver":note("驾驶位不能拆卸");return
 item.floor=-1
 note("已移至待装区；原有设备保留")

func build(kind:String):
 if not outcome.is_empty():return
 if resources["材料"]<CATALOG[kind].cost:note("材料不足");return
 resources["材料"]-=CATALOG[kind].cost
 add_item(kind)
 note("制造 %s；从待装区选择后放入车辆"%CATALOG[kind].name)

func count_active(kind:String)->int:
 var n:int=0
 for item in items:
  if item.kind==kind and item.floor>=0 and floor_unlocked(item.floor):n+=1
 return n

func upgrade_cost()->int:return [8,12,16][mini(level-1,2)]

func upgrade(route:String):
 if not outcome.is_empty():return
 if level>=4:note("P0 车辆等级上限为4；不是完整十级路线");return
 if resources["材料"]<upgrade_cost():note("扩容材料不足");return
 if level==2 and route not in ["探索型","家园型"]:note("选择一个分支后再升级");return
 resources["材料"]-=upgrade_cost();level+=1
 if level==2:height=8
 if level==3:width=6;branch=route
 note(["","","升至2级：4×8格","升至3级：6×8格，解锁车内二层","升至4级：解锁车顶"][level])

func advance(action:String):
 if not outcome.is_empty():return
 if action=="探索":
  var fuel_cost:int=1 if branch=="探索型" else 2
  if resources["燃油"]<fuel_cost:note("燃油不足，可用应急补给换油");return
  resources["燃油"]-=fuel_cost
  progress+=1
  resources["材料"]+=5+2*count_active("arm")
  resources["原料"]+=2
  if progress%3==0:
   var damage:int=maxi(1,6-3*count_active("command")-2*count_active("drone"))
   resources["耐久"]-=damage;note("遭遇拦路者：损失%d耐久，获得6材料"%damage);resources["材料"]+=6
  else:note("探索：获得材料和原料")
 else:
  resources["耐久"]=mini(30,resources["耐久"]+2+2*count_active("room"))
  note("停车休整，生产仍消耗一回合")
 settle()

func settle():
 var before=resources.duplicate()
 var water_gain:int=count_active("collector")*3
 if branch=="家园型" and water_gain>0:water_gain+=1
 resources["水"]+=water_gain
 resources["电力"]+=count_active("solar")*3
 resources["原料"]+=count_active("statue")
 for i in range(count_active("culture")):
  if resources["水"]>=1 and resources["电力"]>=1:
   resources["水"]-=1;resources["电力"]-=1;resources["原料"]+=2
 for i in range(count_active("kitchen")):
  if resources["原料"]>=1:resources["原料"]-=1;resources["食物"]+=3
 resources["水"]-=maxi(1,2-count_active("bathroom"))
 resources["食物"]-=2
 for key in ["水","食物"]:
  if resources[key]<0:resources["耐久"]+=resources[key]*3;resources[key]=0
 var capacity:int=30+15*count_active("storage")
 for key in resources:
  if key!="耐久":resources[key]=mini(resources[key],capacity)
 turn+=1
 note("结算：水 %+d / 食物 %+d / 原料 %+d / 电力 %+d"%[resources["水"]-before["水"],resources["食物"]-before["食物"],resources["原料"]-before["原料"],resources["电力"]-before["电力"]])
 if resources["耐久"]<=0:outcome="本次测试失败：耐久耗尽。可重新开始调整构筑。"

func resupply():
 if not outcome.is_empty():return
 if resources["材料"]<2:note("应急补给需要2材料");return
 resources["材料"]-=2
 for key in ["水","食物","燃油"]:resources[key]=mini(30+15*count_active("storage"),resources[key]+5)
 note("消耗2材料，补充水、食物、燃油各5；测试用交易")

func finish():
 if not outcome.is_empty():return
 if progress<6 or level<3 or count_active("kitchen")==0 or resources["水"]<4 or resources["食物"]<4:
  note("终点要求：探索6次、3级车、已装厨房、水和食物各4");return
 resources["水"]-=4;resources["食物"]-=4
 outcome="P0 验证通关：通过灾难检查，抵达下一世界。完整模式尚未实现。"
 note(outcome)

func note(message:String):
 logs.push_front(message)
 if logs.size()>8:logs.resize(8)
