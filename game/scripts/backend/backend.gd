extends Node
## Talks to Supabase with plain HTTPRequest calls (no plugins). Loaded once for
## the whole game as the "Backend" autoload. URL and key: backend_config.gd.
##
## SESSION
## Every player is signed in as an anonymous Supabase user the first time an
## online feature is used (POST /auth/v1/signup with an empty body). The tokens
## are kept in user://session.cfg and refreshed before they expire, so the
## player keeps the same leaderboard entry between launches. Clearing the
## game's data (or a refresh token that the server no longer accepts) starts a
## new anonymous player.
##
## USING IT
## Call the methods without await, and listen to the signals for the answer:
##   submit_score(score, duration_ms, drops) -> score_submitted(result)
##   fetch_top(limit)                        -> leaderboard_loaded(entries, ok)
##   set_display_name(name)                  -> name_changed(result)
##   fetch_me()                              -> me_loaded(result)
## Signals (rather than awaiting) keep things safe when the scene reloads
## while a request is still on its way: freed listeners are just disconnected.
##
## OFFLINE
## Nothing here ever blocks the game. If a score can't be sent, the best
## unsent run is saved and sent again on the next launch.

## result: the POST /api/scores reply ({display_name, best_score, is_new_best,
## rank, total_players}); {"error": message} if the server rejected the run;
## {} if the server could not be reached.
signal score_submitted(result: Dictionary)
## entries: [{player_id, display_name, best_score}, ...] best first.
## ok is false if the leaderboard could not be loaded.
signal leaderboard_loaded(entries: Array, ok: bool)
## result: {"display_name": name} on success, {"error": message} if the name
## was rejected, {} if the server could not be reached.
signal name_changed(result: Dictionary)
## result: {display_name, best_score, rank, total_players} for this player
## (a new player gets a random name), or {} if the server could not be reached.
signal me_loaded(result: Dictionary)

signal _session_done(ok: bool)

const SESSION_PATH := "user://session.cfg"
const REQUEST_TIMEOUT := 10.0
## Refresh the access token this many seconds before it runs out.
const REFRESH_MARGIN := 60

## The signed-in player's id, "" until the first sign-in.
var player_id := ""
## The player's leaderboard name, "" until their first score or name change.
var display_name := ""
## From the last successful score submit (0 = unknown / no score yet).
var my_best := 0
var my_rank := 0
var total_players := 0

var _access_token := ""
var _refresh_token := ""
var _expires_at := 0
var _session_busy := false
## Best run that has not reached the server yet ({} = none).
var _pending := {}


func _ready() -> void:
	# Keep requests running while the game is paused (e.g. leaderboard open).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_session()
	if is_configured() and not _pending.is_empty():
		_send_pending.call_deferred()


func is_configured() -> bool:
	return BackendConfig.SUPABASE_URL != "" and BackendConfig.PUBLISHABLE_KEY != ""


# --- Public API -------------------------------------------------------------

## Sends a finished run. Answers with score_submitted.
func submit_score(score: int, duration_ms: int, drops: int) -> void:
	var run := {"score": score, "duration_ms": duration_ms, "drops": drops}
	# Save it first, so it is not lost if the game closes mid-request.
	_remember_pending(run)
	var result := await _post_run(run)
	score_submitted.emit(result)


## Loads the top players. Answers with leaderboard_loaded.
func fetch_top(limit := 100) -> void:
	if not is_configured():
		leaderboard_loaded.emit([], false)
		return
	var path := "/rest/v1/leaderboard_entries?select=player_id,display_name,best_score" \
			+ "&best_score=gt.0&order=best_score.desc,achieved_at.asc&limit=%d" % limit
	# Public data: the publishable key alone is enough, no sign-in needed.
	var response := await _request(HTTPClient.METHOD_GET, path, null, false)
	if response["ok"] and response["data"] is Array:
		leaderboard_loaded.emit(response["data"], true)
	else:
		leaderboard_loaded.emit([], false)


## Loads this player's own name, best score and rank from the server (the
## server is the source of truth; the copy in session.cfg is only a cache).
## A new player gets a random name here. Answers with me_loaded.
func fetch_me() -> void:
	var response := await _call_api(HTTPClient.METHOD_GET, "/me", null)
	var data: Variant = response["data"]
	if response["ok"] and data is Dictionary and data.has("display_name"):
		display_name = str(data["display_name"])
		my_best = int(data.get("best_score", 0))
		my_rank = int(data["rank"]) if data.get("rank") != null else 0
		total_players = int(data.get("total_players", 0))
		_save_session()
		me_loaded.emit(data)
	else:
		me_loaded.emit({})


## Changes the player's leaderboard name. Answers with name_changed.
func set_display_name(new_name: String) -> void:
	var response := await _call_api(HTTPClient.METHOD_PUT, "/me/name", {"name": new_name})
	var data: Variant = response["data"]
	if response["ok"] and data is Dictionary and data.has("display_name"):
		display_name = data["display_name"]
		_save_session()
		name_changed.emit({"display_name": display_name})
	elif response["code"] == 400 and data is Dictionary and data.has("error"):
		name_changed.emit({"error": str(data["error"])})
	else:
		name_changed.emit({})


# --- Scores -----------------------------------------------------------------

## Sends one run and updates my_best / my_rank. Returns the result dictionary
## described at score_submitted.
func _post_run(run: Dictionary) -> Dictionary:
	var response := await _call_api(HTTPClient.METHOD_POST, "/scores", run)
	var data: Variant = response["data"]
	if response["ok"] and data is Dictionary:
		_clear_pending_up_to(int(run["score"]))
		display_name = str(data.get("display_name", display_name))
		my_best = int(data.get("best_score", my_best))
		my_rank = int(data["rank"]) if data.get("rank") != null else 0
		total_players = int(data.get("total_players", total_players))
		_save_session()
		return data
	if response["code"] == 400:
		# The server will never accept this run, so don't keep retrying it.
		_clear_pending_up_to(int(run["score"]))
		_save_session()
		return {"error": str(data.get("error", "Score not accepted")) if data is Dictionary else "Score not accepted"}
	return {}


## Retries the saved unsent run from an earlier session (no signal).
func _send_pending() -> void:
	if not _pending.is_empty():
		await _post_run(_pending.duplicate())


## Only the best unsent run matters for an all-time board.
func _remember_pending(run: Dictionary) -> void:
	if _pending.is_empty() or int(run["score"]) > int(_pending["score"]):
		_pending = run.duplicate()
		_save_session()


func _clear_pending_up_to(score: int) -> void:
	if not _pending.is_empty() and int(_pending["score"]) <= score:
		_pending = {}


# --- Session ----------------------------------------------------------------

## Makes sure there is a valid access token: signs in anonymously the first
## time, refreshes it when it is about to run out. Returns false if offline.
func _ensure_session() -> bool:
	if not is_configured():
		return false
	if _access_token != "" and Time.get_unix_time_from_system() < _expires_at - REFRESH_MARGIN:
		return true
	if _session_busy:
		return await _session_done
	_session_busy = true

	var ok := false
	if _refresh_token != "":
		var refreshed := await _request(HTTPClient.METHOD_POST,
				"/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh_token}, false)
		if refreshed["ok"]:
			ok = _store_session(refreshed["data"])
		elif refreshed["code"] >= 400 and refreshed["code"] < 500:
			# The server no longer accepts this session: start a new player.
			# (Network errors keep the old one so it can be retried later.)
			push_warning("Backend: session expired, signing in as a new player.")
			_refresh_token = ""
			player_id = ""
			display_name = ""
			my_best = 0
			my_rank = 0
	if not ok and _refresh_token == "":
		var signed_up := await _request(HTTPClient.METHOD_POST, "/auth/v1/signup", {}, false)
		if signed_up["ok"]:
			ok = _store_session(signed_up["data"])
		else:
			push_warning("Backend: anonymous sign-in failed (HTTP %d)." % signed_up["code"])

	_session_busy = false
	_session_done.emit(ok)
	return ok


func _store_session(data: Variant) -> bool:
	if not (data is Dictionary) or not data.has("access_token"):
		return false
	var now := int(Time.get_unix_time_from_system())
	_access_token = data["access_token"]
	_refresh_token = data.get("refresh_token", _refresh_token)
	_expires_at = int(data.get("expires_at", now + int(data.get("expires_in", 3600))))
	var user: Variant = data.get("user")
	if user is Dictionary and user.has("id"):
		player_id = user["id"]
	_save_session()
	return true


func _load_session() -> void:
	var config := ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return
	_access_token = config.get_value("session", "access_token", "")
	_refresh_token = config.get_value("session", "refresh_token", "")
	_expires_at = config.get_value("session", "expires_at", 0)
	player_id = config.get_value("session", "player_id", "")
	display_name = config.get_value("player", "display_name", "")
	my_best = config.get_value("player", "best", 0)
	my_rank = config.get_value("player", "rank", 0)
	total_players = config.get_value("player", "total_players", 0)
	_pending = config.get_value("pending", "run", {})


func _save_session() -> void:
	var config := ConfigFile.new()
	config.set_value("session", "access_token", _access_token)
	config.set_value("session", "refresh_token", _refresh_token)
	config.set_value("session", "expires_at", _expires_at)
	config.set_value("session", "player_id", player_id)
	config.set_value("player", "display_name", display_name)
	config.set_value("player", "best", my_best)
	config.set_value("player", "rank", my_rank)
	config.set_value("player", "total_players", total_players)
	config.set_value("pending", "run", _pending)
	config.save(SESSION_PATH)


# --- HTTP -------------------------------------------------------------------

## Calls the game API (BackendConfig.API_URL + path, routes in
## supabase/functions/api/app.ts) as the signed-in player. If the token is
## rejected (401), it signs in again once and retries. body is null for GET
## (browsers refuse a GET with a body).
func _call_api(method: HTTPClient.Method, path: String, body: Variant) -> Dictionary:
	if not await _ensure_session():
		return {"ok": false, "code": 0, "data": null}
	var url := BackendConfig.API_URL.trim_suffix("/") + path
	var response := await _request_url(method, url, body, true)
	if response["code"] == 401:
		_access_token = ""
		if await _ensure_session():
			response = await _request_url(method, url, body, true)
	return response


## A request to Supabase itself (auth and Data API), path relative to SUPABASE_URL.
func _request(method: HTTPClient.Method, path: String, body: Variant, with_token: bool) -> Dictionary:
	return await _request_url(method, BackendConfig.SUPABASE_URL.trim_suffix("/") + path, body, with_token)


## One HTTPS request. Returns {"ok": bool, "code": int, "data": parsed JSON or null}.
## code is 0 when the server could not be reached at all.
func _request_url(method: HTTPClient.Method, url: String, body: Variant, with_token: bool) -> Dictionary:
	var headers := PackedStringArray([
		"apikey: " + BackendConfig.PUBLISHABLE_KEY,
		"Content-Type: application/json",
	])
	if with_token and _access_token != "":
		headers.append("Authorization: Bearer " + _access_token)

	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	# Web build: the browser already unzips gzip responses, but Supabase's REST
	# API still exposes "Content-Encoding: gzip" to the page, so Godot would try
	# to unzip the plain body again and fail (the leaderboard showed "Can't
	# reach"). With accept_gzip off, Godot never decompresses; native builds
	# keep it on so their responses stay compressed.
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	var payload := JSON.stringify(body) if body != null else ""
	if http.request(url, headers, method, payload) != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": null}

	var reply: Array = await http.request_completed
	http.queue_free()
	var result: int = reply[0]
	var code: int = reply[1]
	var text := (reply[3] as PackedByteArray).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "data": null}
	var data: Variant = JSON.parse_string(text) if text != "" else null
	return {"ok": code >= 200 and code < 300, "code": code, "data": data}
