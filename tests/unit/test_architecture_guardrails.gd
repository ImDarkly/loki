extends GutTest

# Repo-wide mechanical checks for architecture flaws that have actually
# shipped in this codebase before. See AGENTS.md's "Architecture Guardrails"
# section for the policy each of these enforces.

const SKIP_DIRS: Array[String] = ["addons", ".godot", "tests", ".git"]
const ROOT := "res://"


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
	var export_regex := RegEx.new()
	export_regex.compile("@export(?:_\\w+\\([^)]*\\))?\\s+var\\s+(\\w+)")

	for path in files:
		var text := _read_file(path)
		var results := export_regex.search_all(text)
		for result in results:
			var var_name: String = result.get_string(1)
			# Count occurrences of the identifier as a whole word.
			var word_regex := RegEx.new()
			word_regex.compile("\\b" + var_name + "\\b")
			var occurrences := word_regex.search_all(text)
			if occurrences.size() <= 1:
				offenders.append("%s: @export var %s is declared but never read" % [path, var_name])

	assert_eq(offenders, [], "Every @export var must be read somewhere in the same file, in the same commit -- a declared-but-unread export silently does nothing. Offenders:\n" + "\n".join(offenders))
