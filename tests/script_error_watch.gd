# res://tests/script_error_watch.gd
# Every SCRIPT ERROR the engine reports while the tests run, caught as it happens.
#
# A GDScript runtime error does not throw. The function it happens in stops, the error
# is printed, and everything else carries on -- which in the game is a crash: the
# player placed one wooden stake and got "Trying to assign an array of type "Array" to
# a variable of type "Array[Vector2i]"", on every single-stake placement. In this runner
# it was a line in the log and, whenever the test's assertions happened to hold anyway, a
# green [PASS] right under it. Reading the log for "SCRIPT ERROR" after each run was the
# only guard, and a guard that depends on someone remembering to look is not one.
#
# So the runner registers this with the engine's own logger hook (OS.add_logger) and
# fails whichever test was running when an error came through. Only script errors: the
# engine's own ERROR lines include things this game already handles on purpose, such as
# navigation queries made before the map's first sync.
extends Logger

var _mutex := Mutex.new()
var _errors: PackedStringArray = []

## Called by the engine, possibly from another thread -- hence the mutex.
func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	var what: String = rationale if not rationale.is_empty() else code
	_mutex.lock()
	_errors.append("%s  (%s:%d, in %s)" % [what, file, line, function])
	_mutex.unlock()

func _log_message(_message: String, _error: bool) -> void:
	pass

## How many script errors have been reported so far.
func count() -> int:
	_mutex.lock()
	var n: int = _errors.size()
	_mutex.unlock()
	return n

## The script errors reported since there were `start` of them.
func since(start: int) -> PackedStringArray:
	_mutex.lock()
	var out: PackedStringArray = _errors.slice(start)
	_mutex.unlock()
	return out
