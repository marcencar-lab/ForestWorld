class_name Session
extends RefCounted

## How this run was started, chosen on the menu and read by the world.
## Static so it survives the scene change from the menu into the game.

const DEFAULT_PORT := 24517
const MAX_PLAYERS := 8
const SETTINGS_PATH := "user://settings.cfg"

static var mode := "single"        # "single", "host" or "client"
static var address := "127.0.0.1"
static var port := DEFAULT_PORT
static var player_name := "Survivor"
static var menu_message := ""       # shown on the menu, e.g. after a disconnect
static var use_upnp := true         # ask the router to open the port when hosting


static func online() -> bool:
	return mode != "single"


## True where the world is simulated: single player, or the host.
static func authority() -> bool:
	return mode != "client"


static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		player_name = str(cf.get_value("net", "name", player_name))
		address = str(cf.get_value("net", "address", address))
		port = int(cf.get_value("net", "port", port))


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("net", "name", player_name)
	cf.set_value("net", "address", address)
	cf.set_value("net", "port", port)
	cf.save(SETTINGS_PATH)
