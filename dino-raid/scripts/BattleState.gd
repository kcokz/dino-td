class_name BattleState
extends RefCounted
## Everything a battle is at one moment, as plain data (Sim works on it). clone() makes a copy that can be
## played forward without touching this one -- how the coming turn is shown before it happens.
##
## A unit:     {id, side "dino"|"robot", kind, pos, hp, max, bodies, pack, body_hp, frenzy, angry_at, lead}
## A nest:     {id, pos, hp, species, pack, eggs, hatch, needs, progress, card}
## A building: {id, pos, kind, up, hp}

var level := 0
var turn := 1
var energy := 0
var units: Array = []
var nests: Array = []
var buildings: Array = []
var rocks := {}                   # Vector2i -> true
var scents: Array = []            # {pos, turns}
var ashes: Array = []             # {pos, turns}: the middle of 3x3
var noises: Array = []            # {pos, reach}: this turn only
var calls: Array = []             # {pos, reach}: this turn only
var draw: Array = []              # card instances {id, up}; the top is the end
var hand: Array = []
var discard: Array = []
var next_id := 1
var over := false
var won := false
var waves := true                 # the time machine sends its waves (a test board may not want them)


func clone() -> BattleState:
	var c := BattleState.new()
	c.level = level
	c.turn = turn
	c.energy = energy
	c.units = units.duplicate(true)
	c.nests = nests.duplicate(true)
	c.buildings = buildings.duplicate(true)
	c.rocks = rocks.duplicate()
	c.scents = scents.duplicate(true)
	c.ashes = ashes.duplicate(true)
	c.noises = noises.duplicate(true)
	c.calls = calls.duplicate(true)
	c.draw = draw.duplicate(true)
	c.hand = hand.duplicate(true)
	c.discard = discard.duplicate(true)
	c.next_id = next_id
	c.over = over
	c.won = won
	c.waves = waves
	return c


func unit(id: int) -> Variant:
	for u in units:
		if u.id == id:
			return u
	return null


func nest(id: int) -> Variant:
	for n in nests:
		if n.id == id:
			return n
	return null
