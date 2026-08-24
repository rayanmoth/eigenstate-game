// ============================================================
// ASYNC - HTTP
//
// Four endpoints now (/newgame /turn /scout /resolve), so this branches on
// last_request, which post() records. The old version inferred it from
// `starting` and array_length(queued), which cannot distinguish four.
//
// The year does NOT advance here any more -- it advances in the EVENTS
// phase in Step, once the player has read the cards.
// ============================================================

if (async_load[? "id"] != request_id) exit;

awaiting = false;
var _st = async_load[? "http_status"];

// ---------------- failure ----------------
if (async_load[? "status"] != 0 || _st != 200) {
    add_log("The oracle is silent. (status "
          + string(async_load[? "status"]) + ", http " + string(_st) + ")");
    show_debug_message("raw: " + string(async_load[? "result"]));
	
	show_debug_message("status=" + string(async_load[? "status"])
                 + " http=" + string(_st)
                 + " url=" + SERVER_BASE);
	if (_st == 401) {
        link = "down";
        link_note = "This server needs a key the game does not have. "
                  + "Check SERVER_KEY in Create_0.";
    }			
					 
					 
    // never leave the player stranded mid-resolution
	if (last_request == "newgame") {
        if (!server_spawn_tried && SERVER_SPAWN_ENABLED) {
            // we can start it ourselves, so do that first
            link = "waiting";
            link_note = "Starting the quantum brain. This takes about half "
                      + "a minute the first time.";
            server_spawn();
            server_retry_timer = SERVER_RETRY_EVERY;
            server_retry_count = 0;
 
        } else if (server_retry_count <= SERVER_RETRY_MAX) {
            // A REFUSED CONNECTION HERE IS THE EXPECTED ANSWER, not a
            // failure. Either we started it and it is still importing
            // qiskit, or the launcher script did. Same situation, same
            // behaviour: keep knocking and let the Step block decide when
            // to give up.
            link = "waiting";
            link_note = SERVER_SPAWN_ENABLED
                ? "Starting the quantum brain. About half a minute the "
                + "first time."
                : "Waiting for the quantum brain. About half a minute from "
                + "a cold start.";
            server_retry_timer = SERVER_RETRY_EVERY;
 
        } else {
            link = "down";
            link_note = SERVER_SPAWN_ENABLED
                ? "Nothing answered at " + SERVER_BASE + ". Check launch.log and "
                + "server.log in the server folder, then press R."
                : "Nothing answered at " + SERVER_BASE + ". Run "
                + "run_eigenstate.command in the server folder, then press R.";
        }
        starting = true;
    }
    if (phase == "resolving") phase = "plan";
    exit;
}

var _r = json_parse(async_load[? "result"]);

// STORE THE WORLD FIRST, before any of the last_request branches below,
// because /resolve and /resolve2 both exit early and would otherwise throw
// the new world away. Every endpoint returns one.
if (variable_struct_exists(_r, "world")) world = _r.world;


// ============================================================
// /resolve -- this year's measurements
// ============================================================
// pass 1: initiative plus YOUR battles. apply_resolution runs your plan,
// lets the rivals decide, and then either asks for a second measurement
// (if any rival intends war) or finishes the year itself.
if (last_request == "resolve") {
    var _answers = _r[$ "answers"];

    // any battle where WE attacked gets a measurement beat first. The
    // outcome is already decided -- it was measured the instant /resolve
    // returned -- this just makes the collapse visible instead of
    // dumping straight to a log line.
    measuring_queue = [];
    for (var i = 0; i < array_length(_answers); i++) {
        var _a = _answers[i];
        if (_a.kind == "battle" && _a.a == ME) array_push(measuring_queue, _a);
    }
    measuring_answers = _answers;

    if (array_length(measuring_queue) > 0) {
        phase = "measuring";
        measuring_hold = 0;
        measuring_revealed = false;
    } else {
        apply_resolution(_answers);
    }
    exit;
}

// pass 2: the rivals' wars, measured the same way yours were. This is the
// fix for rivals having settled their battles with dice.
if (last_request == "resolve2") {
    var _ans = _r[$ "answers"];
 
    // Any rival battle aimed at YOU earns the beat. rival_battles holds the
    // pairings in the same order the answers came back, which is exactly how
    // apply_rival_battles matches them up, so walking both in step here is
    // safe and needs no new bookkeeping.
    measuring_queue = [];
    var _k = 0;
    for (var i = 0; i < array_length(_ans); i++) {
        if (_ans[i].kind != "battle") continue;
        if (_k >= array_length(rival_battles)) break;
        var _rb = rival_battles[_k];
        _k++;
        if (_rb.b != ME) continue;
 
        // carry the pairing on the answer so Draw knows who is marching on
        // whom without re-deriving it
        var _a2 = _ans[i];
        _a2.a = _rb.a;
        _a2.b = _rb.b;
        _a2.incoming = true;
        array_push(measuring_queue, _a2);
    }
 
    measuring_answers = _ans;
 
    if (array_length(measuring_queue) > 0) {
        phase = "measuring";
        measuring_hold = 0;
        measuring_revealed = false;
        measuring_incoming = true;
    } else {
        apply_rival_battles(_ans);
    }
    exit;
}


// ============================================================
// /newgame, /turn and /scout all return factions + pairs
// ============================================================
var _in = _r[$ "factions"];
for (var i = 0; i < array_length(_in); i++) {
    var _s = _in[i];
    var _f = factions[_s.id];
    _f.prev_hostility    = _f.hostility;
    _f.prev_independence = _f.independence;
    _f.hostility    = _s.hostility;
    _f.independence = _s.independence;
    _f.intel_fresh  = _s.intel_fresh;
    _f.last_scouted = _s.last_scouted;
	_f.conviction = _s.conviction;
    _f.leverage   = _s.leverage_over_you;
	_f.debt   = _s.debt_over_you;
    _f.tangle = _s.tangle_with_you;
	
	    if (variable_struct_exists(_s, "bond_budget_max")) {
        _f.budget_max  = _s.bond_budget_max;
        _f.budget_used = _s.bond_budget_used;
        _f.commitments = _s.commitments;
    }
	
    if (variable_struct_exists(_s, "bloch")) {
        _f.bloch_x = _s.bloch.X;
        _f.bloch_y = _s.bloch.Y;
        _f.bloch_z = _s.bloch.Z;
    }
}

// snapshot your own bonds before the new ones land, so a single month's
// swing is measurable. Cheap: five floats.
var _was = array_create(N, 0);
for (var _wj = 0; _wj < N; _wj++) _was[_wj] = bonds[ME][_wj];

var _pairs = _r[$ "pairs"];
for (var i = 0; i < array_length(_pairs); i++) {
    var _p = _pairs[i];
    bonds[_p.a][_p.b] = _p.correlation;
    bonds[_p.b][_p.a] = _p.correlation;
	lev_matrix[_p.a][_p.b] =  _p.leverage;
    lev_matrix[_p.b][_p.a] = -_p.leverage;
}

// Only on /turn. /newgame fills these from zero for the first time and
// /scout re-reports values that have not moved, so neither is a turn.
if (last_request == "turn") {
    for (var _wj2 = 1; _wj2 < N; _wj2++) {
        var _dd = bonds[ME][_wj2] - _was[_wj2];
        if (_dd < run_worst_d) {
            run_worst_d = _dd;
            run_worst_j = _wj2;
            run_worst_m = year;
        }
    }
}

for (var a = 0; a < N; a++) {
    if (a != ME && !factions[a].intel_fresh) continue;
    for (var b = 0; b < N; b++) {
        if (a == b) continue;
        known_bonds[a][b]    = bonds[a][b];
        known_bond_age[a][b] = year;
    }
}

update_standing()

var _q = _r[$ "quantum"];
if (_q != undefined) {
	q_gates     = _q.gates;
    q_depth     = _q.circuit_depth;
    q_gatecount = _q.gate_count;
    q_shots     = _q.shots;
}

// ---- the oath board -------------------------------------------------
// Every open commitment in the world, as the server last measured it.
// p_seal is not a guess: it is the real probability that oath seals if it
// were measured right now, interference included, so it visibly moves as
// people work on it.
var _bd = _r[$ "board"];
if (_bd != undefined) board = _bd;

// ---- what matured ---------------------------------------------------
// Oaths whose span ran out this month. Their outcomes were measured on the
// server from the state the whole world had left them in.
var _md = _r[$ "matured"];
if (_md != undefined) matured = _md;

// which pairs got crowded out of a kingdom's bond budget this month
var _dil = _r[$ "diluted"];

// ---------------- /newgame ----------------
if (last_request == "newgame") {
    starting = false;

    // temperament from the real measurement taken to build the world.
    // Only one bit per kingdom is available from it, so the warlike/not
    // split is genuinely quantum and the schemer/diplomat split falls
    // back to ordinary randomness. Worth knowing rather than overclaiming.
    var _bits = _r[$ "measured_bits"];
    for (var j = 1; j < N; j++) {
        if (string_char_at(_bits, j + 1) == "1") {
            factions[j].temper = "warlike";
        } else {
            factions[j].temper = (random(1) < 0.5) ? "schemer" : "diplomat";
        }
    }

    // 16 uniform quantum bits per kingdom become its title, name and
    // portrait layers. Every playthrough gets different rulers, and they
    // come from a measurement rather than a stored seed.
    var _traits = _r[$ "traits"];
    if (_traits != undefined) {
        for (var j = 0; j < array_length(_traits); j++) make_leader(j, _traits[j]);
        factions[ME].leader = "you";
        add_log("You take the throne of Eigenstate. Your neighbours have names now.");
    }
	
	// THE WORLD IS VISIBLE FROM THE START. Gossip and espy still refresh
    // this, and known_bond_age still ages, so a relationship you have not
    // checked in a while still reads as old news. Nothing is unknown, some
    // things are just stale.
    for (var a = 0; a < N; a++)
        for (var b = 0; b < N; b++) {
            if (a == b) continue;
            known_bonds[a][b]    = bonds[a][b];
            known_bond_age[a][b] = year;
        }
	
	link = "ok";
	

    add_log("Four rivals measured into being. Month 1 begins.");
    phase = "plan";
    exit;
}


// ---------------- /scout ----------------
if (last_request == "scout") {
    if (array_length(pending_scouts) > 0) {
        var _next = pending_scouts[0];
        array_delete(pending_scouts, 0, 1);
        post("/scout", { target: _next, year: year }, "scout");
        exit;
    }
    phase = "events";
    exit;
}



// ---------------- /turn ----------------
if (last_request == "turn") {
    queued = [];

    // an oath coming due is the most consequential thing that can happen in
    // a month, so it gets a card rather than a log line
    push_matured_cards();
	
	if (_dil != undefined) {
        for (var i = 0; i < array_length(_dil); i++) {
            var _d = _dil[i];
            var _over = _d.over;
            var _oth  = (_d.a == _over) ? _d.b : _d.a;
 
            // only report it if the player can plausibly know: their own
            // relationships, or a court they have fresh word from. Otherwise
            // it is information they have not earned.
            if (_over != ME && _oth != ME && !factions[_over].intel_fresh)
                continue;
 
            if (_over == ME) {
                add_log("You have no more of yourself to give. Your bond with "
                      + factions[_oth].name + " thins.");
            } else if (_oth == ME) {
                add_log(factions[_over].name + " has spent itself elsewhere. "
                      + "Its bond with you thins.");
            } else {
                add_log(factions[_over].name + " has no room left. Its bond "
                      + "with " + factions[_oth].name + " thins.");
            }
        }
    }

    // fire any scouts the player queued, one at a time
    if (array_length(pending_scouts) > 0) {
        var _next = pending_scouts[0];
        array_delete(pending_scouts, 0, 1);
        post("/scout", { target: _next, year: year }, "scout");
        exit;
    }

    phase = "events";

    // if nothing noteworthy happened, say so rather than showing no card
    if (array_length(event_queue) == 0)
        push_event("quiet", "A quiet month",
                   "No host marched and no oath came due. The chronicle "
                 + "records only weather and taxes.");
    exit;
}
