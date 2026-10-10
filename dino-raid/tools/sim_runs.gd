extends SceneTree

func _init() -> void:
	for sd in range(1, 81):
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		seed(sd)
		var deck: Array = []
		for id in Rules.START_DECK:
			deck.append({"id": id, "up": false})
		var s := Sim.new_battle(sd % 3, deck, rng)
		var idle := 0
		for turn in 50:
			var i := 0
			var tries := 0
			while i < s.hand.size() and tries < 20:
				tries += 1
				var where := Sim.targets(s, i)
				if where.is_empty():
					i += 1
					continue
				if not Sim.play(s, i, where[randi() % where.size()]):
					i += 1
			var ev := Sim.end_turn(s)
			var walkers := s.units.filter(func(u: Dictionary) -> bool: return u.kind == "walker")
			var shots := ev.filter(func(e: Dictionary) -> bool: return e.t == "shoot").size()
			var moves := ev.filter(func(e: Dictionary) -> bool: return e.t == "move").size()
			var robot_moves := ev.filter(func(e: Dictionary) -> bool: return e.t == "move" and s.unit(int(e.id)) != null and s.unit(int(e.id)).side == "robot").size()
			idle = idle + 1 if (shots == 0 and robot_moves == 0 and walkers.size() >= 3) else 0
			if idle >= 2 and not s.nests.is_empty():
				print("seed %d level %d turn %d: %d walkers, no shot, %d moves" % [sd, s.level, s.turn, walkers.size(), moves])
				for u in s.units:
					print("   ", u.kind, " ", u.pos, " hp ", u.hp)
				for n in s.nests:
					print("   nest ", n.pos)
				for b in s.buildings:
					print("   building ", b.kind, " ", b.pos)
				print("   rocks ", s.rocks.keys())
				quit()
				return
			if s.over:
				break
			Sim.start_turn(s, rng)
	print("no stall found")
	quit()