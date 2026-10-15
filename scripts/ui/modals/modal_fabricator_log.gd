extends VBoxContainer
## Master Fabricator Console: Mission logs, undiscovered blueprint hints, and discipline tree teaching.


func _ready() -> void:
	add_theme_constant_override("separation", 14)

	add_child(UIRows.heading("AI HOLOGRAM CONSOLE // SENIOR ENGINEER"))
	add_child(UIRows.row("Operational Status", "Online / Synchronized", Color("70ff8b")))

	# 1. Mission Logs & Current Directive
	add_child(UIRows.heading("MISSION LOGS // CURRENT DIRECTIVE"))
	if QuestManager.is_finished():
		add_child(UIRows.row("Directives Complete", "Citadel Colony operational", Color("70ff8b")))
	else:
		var q := QuestManager.current()
		var right := ""
		if q["type"] == "scavenge":
			right = "%d / %d" % [QuestManager.progress, int(q["target"])]
		add_child(UIRows.row("%s: %s" % [q["title"], q["task"]], right, Color("f59e0b")))
		add_child(UIRows.heading("BLUEPRINT SYNTHESIS HINT"))
		add_child(UIRows.row("Data Decryption", String(q.get("hint", "No blueprint hint available.")), Color("fff3e0")))

	# 2. Discipline Tree Teaching & Progression
	var total_lvl := GameState.get_total_level()
	add_child(UIRows.heading("DISCIPLINE TREE ADVANCEMENT (TEACHING)"))
	add_child(UIRows.row("Overall Fabricator Level", "Rank %d (Total Disciplines)" % total_lvl, Color("f59e0b")))

	for tree in GameState.skills_def.get("protag", []):
		var req: int = int(tree.get("unlock_level", 0))
		var tree_name: String = tree["name"]
		var current_pts: float = GameState.skills.get(tree["key"], 0.0)
		var current_lvl := GameState.get_level(current_pts)
		if total_lvl >= req:
			add_child(UIRows.row(tree_name, "UNLOCKED (Lv %d)" % current_lvl, Color("70ff8b")))
		else:
			add_child(UIRows.row(tree_name, "LOCKED (Requires Overall Lv %d)" % req, Color("bfb7aa")))

	# 3. Completed Mission Log History
	if QuestManager.current_index > 0:
		add_child(UIRows.heading("HISTORICAL ARCHIVE // CLEARED"))
		for i in QuestManager.current_index:
			add_child(UIRows.row(String(QuestManager.quests[i]["title"]), "VERIFIED", Color("70ff8b")))
