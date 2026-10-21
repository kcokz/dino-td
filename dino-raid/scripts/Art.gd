class_name Art
## The paintings (GAME-DESIGN 23, 24; tools/paint_cards.py: assets/art): each card's, each creature's and monster's,
## each star dinosaur's, each place's. Loaded in the background when the game starts
## (warm), so none is first drawn the frame it loads (a texture is not ready to show until the frames after); kept once
## loaded. A picture with no painting yet falls back on the model's portrait (Portraits).

const DIR := "res://assets/art/"

static var _tex := {}              # file name ("u_red.jpg") -> Texture2D
static var _files := {}            # file name -> true: the paintings there are


## Every painting asked for in the background, now.
static func warm() -> void:
	_list()
	for f in _files:
		ResourceLoader.load_threaded_request(DIR + f)


## The painting `key` (a file's name without its extension: "u_red", "s_hoarder"), or null when there is none.
static func of(key: String, ext := "jpg") -> Texture2D:
	var f := key + "." + ext
	if _tex.has(f):
		return _tex[f]
	_list()
	var t: Texture2D = load(DIR + f) if _files.has(f) else null
	_tex[f] = t
	return t


## The painting for a portrait's key (Portraits: "u:red", "e:grey", "a:shell", "s:hoarder", "b:nest_red:1::", "raise"),
## or null.
static func of_portrait(key: String) -> Texture2D:
	if key == "raise":
		return of("raise")
	var bits := key.split(":")
	if bits.size() < 2:
		return null
	return of(bits[0] + "_" + bits[1])


static func _list() -> void:
	if not _files.is_empty():
		return
	for f in DirAccess.get_files_at(DIR):
		# Only what has been imported (name.jpg.import): in a build that is all there is; while working, a painting
		# just made is not there to load until the editor has imported it.
		if not f.ends_with(".import"):
			continue
		var name := f.trim_suffix(".import")
		if name.ends_with(".jpg") or name.ends_with(".png"):
			_files[name] = true
