# Extra hooks sync_harness.sh puts into the generated agent_play.gd (never into the game's bot).
# DA_SIEGE_SHOT=1: a frame of a siege at 15, 30 and 45 seconds.
/^\t*print("\[siege\] %3ds %s" % \[seconds, _raid_minds(stakes)\])$/{
p
s/print(.*$/if OS.get_environment("DA_SIEGE_SHOT") != "" and seconds in [15, 30, 45]: await _shoot("siege_%ds" % seconds)/
}
