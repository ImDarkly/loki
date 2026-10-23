extends GutTest

# Repo-wide mechanical checks for architecture flaws that have actually
# shipped in this codebase before. See AGENTS.md's "Architecture Guardrails"
# section for the policy each of these enforces.

const SKIP_DIRS: Array[String] = ["addons", ".godot", "tests", ".git"]
const ROOT := "res://"
const EXTERNAL_EXPORT_READERS := {
	"res://systems/fishing/fishing_mechanic.gd:fighting_pull_strength": ["res://entities/player/player.gd", "fishing_mechanic.fighting_pull_strength"],
	"res://systems/interaction/interactable_component.gd:prompt_text": ["res://entities/player/player.gd", "interactable.prompt_text"],
	"res://systems/interaction/interactable_component.gd:prompt_color": ["res://entities/player/player.gd", "interactable.prompt_color"],
	"res://systems/interaction/interactable_component.gd:is_enabled": ["res://entities/player/player.gd", "interactable.is_enabled"],
	"res://systems/interaction/interactable_component.gd:show_prompt_without_carrying": ["res://entities/player/player.gd", "interactable.show_prompt_without_carrying"],
	"res://systems/quota/shop_item_data.gd:item_name": ["res://ui/shop_ui.gd", "item.item_name"],
	"res://systems/quota/shop_item_data.gd:cost": ["res://ui/shop_ui.gd", "item.cost"],
	"res://systems/quota/shop_item_data.gd:description": ["res://ui/shop_ui.gd", "item.description"],
	"res://systems/quota/shop_item_data.gd:owned_flag_property": ["res://ui/shop_ui.gd", "item.owned_flag_property"],
}


func _collect_gd_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(entry):
				_collect_gd_files(full_path, out)
		elif entry.ends_with(".gd"):
			out.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func test_no_bare_get_node_on_root_paths() -> void:
	var files: Array[String] = []
	_collect_gd_files(ROOT, files)

	var offenders: Array[String] = []
	for path in files:
		var text := _read_file(path)
		for line in text.split("\n"):
			var stripped := line.strip_edges()
			# Flag get_node("/root -- but not get_node_or_null("/root
			if stripped.contains("get_node(\"/root") and not stripped.contains("get_node_or_null(\"/root"):
				offenders.append("%s: %s" % [path, stripped])

	assert_eq(offenders, [], "Cross-scene lookups must use get_node_or_null, not bare get_node (throws and halts the scene if the path is missing). Offenders:\n" + "\n".join(offenders))


func test_no_unread_export_vars_in_systems() -> void:
	var files: Array[String] = []
	_collect_gd_files("res://systems", files)

	var offenders: Array[String] = []
	var declared_exports: Dictionary = {}
	var export_regex := RegEx.new()
	export_regex.compile("@export(?:_\\w+\\([^)]*\\))?\\s+var\\s+(\\w+)")

	for path in files:
		var text := _read_file(path)
		var results := export_regex.search_all(text)
		for result in results:
			var var_name: String = result.get_string(1)
			var export_key := "%s:%s" % [path, var_name]
			declared_exports[export_key] = true
			if EXTERNAL_EXPORT_READERS.has(export_key):
				continue
			# Count occurrences of the identifier as a whole word.
			var word_regex := RegEx.new()
			word_regex.compile("\\b" + var_name + "\\b")
			var occurrences := word_regex.search_all(text)
			if occurrences.size() <= 1:
				offenders.append("%s: @export var %s is declared but never read" % [path, var_name])

	for export_key in EXTERNAL_EXPORT_READERS:
		if not declared_exports.has(export_key):
			offenders.append("%s: external-reader exception has no export declaration" % export_key)
		var reader: Array = EXTERNAL_EXPORT_READERS[export_key]
		var access_regex := RegEx.new()
		access_regex.compile("\\b" + String(reader[1]).replace(".", "\\.") + "\\b")
		var has_reader := false
		for line in _read_file(reader[0]).split("\n"):
			if access_regex.search(line.get_slice("#", 0)) != null:
				has_reader = true
				break
		if not has_reader:
			offenders.append("%s: expected external read %s in %s is missing" % [export_key, reader[1], reader[0]])

	assert_eq(offenders, [], "Every @export var must be read in its declaring file or have an explicit, verified external reader. Offenders:\n" + "\n".join(offenders))
