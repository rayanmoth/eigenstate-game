// ============================================================
// STEP  --  three-phase year
//
// PLAN      queue intentions, change your mind, nothing resolves
// RESOLVING waiting on /resolve; no input accepted
// EVENTS    read the cards one at a time, then the year advances
//
// The year counter lives HERE now (in the EVENTS phase), not in the Async
// handler. A year is not over until the player has seen what happened.
// ============================================================

// Knock until it answers or we run out of patience. Deliberately NOT
// gated on server_spawn_tried: the server being slow to boot has nothing
// to do with who started it.
if (link == "waiting") {
    server_retry_timer -= delta_time / 1000000;
    if (server_retry_timer <= 0) {
        server_retry_timer = SERVER_RETRY_EVERY;
        server_retry_count++;
        if (server_retry_count > SERVER_RETRY_MAX) {
            link = "down";
            link_note = SERVER_SPAWN_ENABLED
                ? "The quantum brain did not come up. Check launch.log and "
                + "server.log in the server folder."
                : "The quantum brain is not running. Quit, then launch with "
                + "run_eigenstate.command.";
        } else {
            retry_link();
        }
    }
}

// Nothing is playable once it is over. F5 starts a fresh run.
if (game_over) {
    if (keyboard_check_pressed(vk_f5)) {
        restarting = true;      // so Game End does not kill the server
        game_restart();
    }
    exit;
}

// DEBUG: step every court up a tier. Changes outfit, crown and hall
// together, so you see the whole look rather than a mismatched one.
// Delete before you ship.
if (keyboard_check_pressed(vk_f2)) {
    for (var i = 0; i < N; i++) {
        var _df = factions[i];
        _df.tier   = (_df.tier + 1) mod 4;
        _df.outfit = TIER_NAMES[_df.tier] + "_0";
        _df.crown  = TIER_NAMES[_df.tier] + "_" + GENDER_NAMES[_df.gender];
        _df.hall   = _df.tier;
    }
    add_log("debug: tier " + TIER_NAMES[factions[0].tier]);
}


if (scene == "splash") {
    splash_timer += delta_time / 1000000;

    var _total = SPLASH_FADE_IN + SPLASH_HOLD + SPLASH_FADE_OUT;
    if (keyboard_check_pressed(vk_anykey) || splash_timer >= _total) {
        scene = "title";
    }
    exit;
}


if (scene == "title") {
 
    // ---- settings page ----
    if (menu_page == "settings") {
        if (settings_input()) { menu_page = "root"; settings_save(); }
        exit;
    }
 
    // ---- quantum explainer ----
    if (menu_page == "quantum") {
        var _np2 = array_length(QUANTUM_PAGES);
        if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(vk_space)) {
            if (q_page < _np2 - 1) { q_page++; sfx("snd_ui_move"); }
        }
        if (keyboard_check_pressed(vk_left)) {
            if (q_page > 0) { q_page--; sfx("snd_ui_move"); }
        }
        if (keyboard_check_pressed(vk_escape)) { menu_page = "root"; q_page = 0; }
        exit;
    }
 
    // ---- root menu ----
    var _mn = array_length(MENU_ITEMS);
    if (keyboard_check_pressed(vk_down)) { menu_pick = (menu_pick + 1) mod _mn; sfx("snd_ui_move"); }
    if (keyboard_check_pressed(vk_up))   { menu_pick = (menu_pick - 1 + _mn) mod _mn; sfx("snd_ui_move"); }
 
    if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
        sfx("snd_ui_confirm");
        switch (menu_pick) {
            case 0: scene = "intro";        break;
            case 1: menu_page = "settings"; set_pick = 0; break;
            case 2: game_end();             break;
        }
    }
    exit;
}

if (scene == "intro") {
 
    // delta_time is microseconds; this keeps the hold honest at any fps
    var _dt = delta_time / 1000000;
 
    if (intro_ready && !intro_done) {
        intro_shown += intro_speed * _dt;
        if (intro_shown >= intro_total) {
            intro_shown = intro_total;
            intro_done = true;
        }
    }
 
    // --- input ---
    if (intro_lock > 0) intro_lock -= _dt;
 
    if ((keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter))
    &&  intro_lock <= 0) {
        if (!intro_done) {
            // first press: show me the rest of it
            intro_shown = intro_total;
            intro_done  = true;
            intro_lock  = INTRO_LOCK;
        } else if (link_ok()) {
            // THE GATE: the world has to exist first. Mashing cannot get
            // you into a game whose state has not arrived.
            scene = "play";
            intro_waiting = false;
        } else {
            intro_waiting = true;
        }
    }
 
    // if we were waiting on the server and it has now answered, go
    if (intro_waiting && link_ok()) {
        scene = "play";
        intro_waiting = false;
    }
 
    exit;   // nothing else in Step runs during the intro
}


// The offer. Raised once, when the play scene is first entered with a live
// world. `link_ok()` guard means it never appears over a game that has not
// loaded.
if (scene == "play" && opt_tutorial && !tut_asked && link_ok()) {
    tut_asked  = true;              // add `tut_asked = false;` in Create
    tut_prompt = true;
}
 
if (tut_prompt) {
    if (keyboard_check_pressed(vk_left) || keyboard_check_pressed(vk_right))
        tut_prompt_pick = 1 - tut_prompt_pick;
    if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
        if (tut_prompt_pick == 0) tut_begin();
        else { tut_prompt = false; sfx("snd_ui_confirm"); }
    }
    if (keyboard_check_pressed(vk_escape)) { tut_prompt = false; }
    exit;                            // nothing else while the question is up
}
 
if (tut_active) {
    if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)
     || keyboard_check_pressed(vk_right)) {
        if (tut_step < array_length(TUTORIAL) - 1) { tut_step++; sfx("snd_ui_move"); }
        else tut_end(false);
    }
    if (keyboard_check_pressed(vk_left) && tut_step > 0) { tut_step--; sfx("snd_ui_move"); }
    // OUT AT ANY POINT, no penalty, no confirmation dialog. A tutorial you
    // cannot leave is a cage.
    if (keyboard_check_pressed(vk_escape)) tut_end(false);
    exit;
}
 


if (keyboard_check_pressed(ord("Q"))) overlay = (overlay == "observatory") ? "" : "observatory";
if (keyboard_check_pressed(ord("H"))) {
    if (overlay == "help") overlay = "";
    else { overlay = "help"; help_page = 0; }
}
if (keyboard_check_pressed(ord("P"))) {
    if (overlay == "settings") { overlay = ""; settings_save(); }
    else { overlay = "settings"; set_pick = 0; }
}
if (overlay != "") {
	
	// settings owns the arrow keys while it is open, so it has to come
    // before the generic ESC handler below
    if (overlay == "settings") {
        if (settings_input()) { overlay = ""; settings_save(); }
        exit;
    }
	
	if (overlay == "help") {
        var _hlast = array_length(HELP_PAGES) + array_length(QUANTUM_PAGES) - 1;
        if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(vk_space))
            help_page = min(help_page + 1, _hlast);
			sfx("snd_ui_move");
        if (keyboard_check_pressed(vk_left))
            help_page = max(help_page - 1, 0);
			sfx("snd_ui_move");
    }
	
    if (keyboard_check_pressed(vk_escape)) overlay = "";
    exit;
}

// ============================================================
// AUDIENCE  -- standing in someone's court
// Free to enter and free to leave; only some of the things you can DO in
// here cost an action point.
// ============================================================
if (audience_of != -1) {
	
	var _dt = delta_time / 1000000;
 
    if (jbit != "") {
        jbit_t += _dt;
 
        switch (jbit) {
 
            case "usher":
                if (jbit_t >= JBIT_USHER) {
                    // throne_bgm is already faded to 0 by jester_bit_begin.
                    // Leave the handle alive -- audience_open() assumes it
                    // persists across courts and only adjusts its gain.
                    jbit = "enter"; jbit_t = 0;
                }
            break;
			
 
            case "enter":
                // he slides in frozen on frame 0. The freeze is what makes
                // the music starting land: he is not dancing YET.
                if (jbit_t >= JBIT_ENTER) {
                    jbit = "dance"; jbit_t = 0;
                    var _js = asset_get_index("snd_jester");
                    if (_js != -1) {
                        jester_music = audio_play_sound(_js, 1, true);
                        audio_sound_gain(jester_music, opt_music * JESTER_GAIN, 0);
						audio_sound_pitch(jester_music, 1.2);
                    }
                }
            break;
 
            case "dance":
                if (keyboard_check_pressed(JBIT_STOP_KEY)) {
                    if (jester_music != -1) {
                        if (audio_is_playing(jester_music))
                            audio_stop_sound(jester_music);
                        jester_music = -1;
                    }
                    sfx("snd_boom");
                    jbit = "boom"; jbit_t = 0;
                }
                // ESC leaves the court entirely, and audience_close() cleans
                // up. Handled below by the normal ESC path.
            break;
 
            case "boom":
                if (jbit_t >= JBIT_BOOM) {
                    jbit = "return"; jbit_t = 0;
                    if (throne_bgm != undefined && audio_is_playing(throne_bgm))
                        audio_sound_gain(throne_bgm, 0.8, JBIT_RETURN * 1000);
                }
            break;
 
            case "return":
                if (jbit_t >= JBIT_RETURN) {
                    jbit = ""; jbit_t = 0;
                    audience_line = "\"...Where were we.\"";
                }
            break;
        }
 
        // ESC still works, so the player is never trapped in the bit
        if (keyboard_check_pressed(vk_escape)) audience_close();
        exit;
    }
	
    var _n = array_length(audience_opts);
    if (keyboard_check_pressed(vk_down)){
		audience_pick = (audience_pick + 1) mod _n;
		sfx("snd_ui_move");
	}
    if (keyboard_check_pressed(vk_up)){   
		audience_pick = (audience_pick - 1 + _n) mod _n;
		sfx("snd_ui_move");
	}
    if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space))
        audience_do(audience_opts[audience_pick]);
    if (keyboard_check_pressed(vk_escape)) audience_close();

	// ---- blink ----
	if (blink_hold > 0) {
    blink_hold -= _dt;
	} else {
		blink_timer -= _dt;
		if (blink_timer <= 0) {
			blink_hold  = BLINK_DURATION;
			blink_timer = random_range(2, 5);
		}
	}

	// ---- talk: a new line triggers a short mouth-flap ----
	if (audience_line != last_audience_line) {
		last_audience_line = audience_line;
		talk_timer  = TALK_DURATION;
		talk_anim_t = 0;
	}
	if (talk_timer > 0) {
		talk_timer  -= _dt;
		talk_anim_t += _dt;
	}
    exit;
}


// ============================================================
// EVENTS phase
// ============================================================
if (phase == "events") {

    if (event_current == undefined) {
        if (array_length(event_queue) == 0) {
            // the year is genuinely finished
            phase = "plan";
            year++;
			if (year == floor(MONTHS_TOTAL / 2) + 1) halfway_reckoning();
			grudge_decay();

            // entanglement costs agency
            actions_left = (factions[ME].independence >= INDEP_ACTION_FLOOR)
                         ? ACTIONS_MAX : 1;
            if (actions_left < ACTIONS_MAX)
                add_log("Your court is too entangled to act freely. One action.");

            if (year > MONTHS_TOTAL) compute_ending();
            exit;
        }
        event_current = event_queue[0];
        array_delete(event_queue, 0, 1);
        event_pick = 0;
    }

    var _nc = array_length(event_current.choices);
    if (_nc > 0) {
        if (keyboard_check_pressed(vk_down)) event_pick = (event_pick + 1) mod _nc;
        if (keyboard_check_pressed(vk_up))   event_pick = (event_pick - 1 + _nc) mod _nc;
        if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
            // Choices are DATA (an act string plus a target), resolved by
            // apply_choice. GML function literals capturing loop variables
            // are a dependable source of wrong-target bugs, so nothing here
            // captures anything.
            var _ch = event_current.choices[event_pick];
            apply_choice(_ch);
			sfx("snd_ui_confirm");
            event_current = undefined;
        }
    } else {
        if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space))
            event_current = undefined;
			sfx("snd_ui_move");
    }
    exit;
}

// ============================================================
// MEASURING phase -- a beat per battle where a qubit gets measured.
// Real odds shown from the server's bias, then hold-to-measure collapses
// it into the result that's already decided.
// ============================================================
if (phase == "measuring") {
    var _dt = delta_time / 1000000;

    if (!measuring_revealed) {
        if (keyboard_check(vk_space)) {
            measuring_hold += _dt;
            if (measuring_hold >= MEASURE_HOLD_REQ) {
                measuring_revealed = true;
                sfx("snd_boom");
        } else {
            measuring_hold = 0;
        }
    } else {
        if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
            array_delete(measuring_queue, 0, 1);
            measuring_hold = 0;
            measuring_revealed = false;
            if (array_length(measuring_queue) == 0) {
                // TWO EXITS NOW. Pass 1 (your attacks) goes on to resolve the
                // month; pass 2 (theirs) finishes the year. Getting this
                // backwards is the one way this patch can hang a month, so
                // the flag is cleared the instant it is used.
                if (measuring_incoming) {
                    measuring_incoming = false;
                    apply_rival_battles(measuring_answers);
                } else {
                    phase = "resolving";
                    apply_resolution(measuring_answers);
                }
            }
        }
    }
	exit
}


// ============================================================

// ============================================================
// PLAN phase
//
// This used to be: press a letter, press a number, press ENTER. Two verbs
// deep at most, and nothing you chose interacted with anything else.
//
// It is now three layers. The flat verbs are still there and still one
// keypress. On top of them:
//
//   O  swear an OATH -- pick who, then build it: what kind, what sort of
//      pressure it is made of, how many months the world gets to work on
//      it, and how much of yourself you put behind it. It does not resolve
//      this month. It goes on the board where everyone can see it and
//      everyone can push on it.
//
//   F  lean on any open oath on the board, including other people's. Feed
//      it or break it, choose which of the two parties you lean on, and
//      choose the KIND of pressure -- which matters, because the three
//      kinds are rotations about different axes and they do not simply add
//      up. Force cancels force exactly. Coercion does almost nothing by
//      itself and changes what force is worth.
// ============================================================
if (phase != "plan") exit;

// ---------------- oath builder ----------------

if (oath_mode) {
    var _fields = 3;        // kind, span, strength
 
    if (keyboard_check_pressed(vk_down)) oath_field = (oath_field + 1) mod _fields;
    if (keyboard_check_pressed(vk_up))   oath_field = (oath_field - 1 + _fields) mod _fields;
 
    var _step = 0;
    if (keyboard_check_pressed(vk_right)) _step =  1;
    if (keyboard_check_pressed(vk_left))  _step = -1;
 
    if (_step != 0) {
        if (oath_field == 0) {
            var _n = array_length(OATH_KINDS);
            oath_kind = (oath_kind + _step + _n) mod _n;
            // a kind carries its own natural span AND its own axis now
            oath_span = OATH_KINDS[oath_kind].span;
        } else if (oath_field == 1) {
            oath_span = clamp(oath_span + _step, 1, 8);
        } else {
            oath_str = clamp(oath_str + _step, 0, array_length(OATH_STRENGTHS) - 1);
        }
    }
 
    if (keyboard_check_pressed(vk_enter)) {
        if (plan_add_oath(oath_target)) {
            oath_mode = false;
            pending_verb = "";
            pending_first = -1;
        }
    }
    if (keyboard_check_pressed(vk_escape)) {
        oath_mode = false;
        pending_verb = "";
        pending_first = -1;
    }
    exit;
}

// ---------------- leaning on an open oath ----------------
if (lean_mode) {
    var _bn = array_length(board);
    if (_bn == 0) { lean_mode = false; exit; }

    lean_pick = clamp(lean_pick, 0, _bn - 1);

    var _fields = 4;
    if (keyboard_check_pressed(vk_down)) oath_field = (oath_field + 1) mod _fields;
    if (keyboard_check_pressed(vk_up))   oath_field = (oath_field - 1 + _fields) mod _fields;

    var _step = 0;
    if (keyboard_check_pressed(vk_right)) _step =  1;
    if (keyboard_check_pressed(vk_left))  _step = -1;

    if (_step != 0) {
        if (oath_field == 0) {
            lean_pick = (lean_pick + _step + _bn) mod _bn;
        } else if (oath_field == 1) {
            lean_dir = -lean_dir;
        } else if (oath_field == 2) {
            var _n = array_length(OATH_AXES);
            lean_axis = (lean_axis + _step + _n) mod _n;
        } else {
            lean_side = 1 - lean_side;
        }
    }

    if (keyboard_check_pressed(vk_enter)) {
        if (plan_add_lean(board[lean_pick], lean_dir,
                          OATH_AXES[lean_axis].key, lean_side)) {
            lean_mode = false;
        }
    }
    if (keyboard_check_pressed(vk_escape)) lean_mode = false;
    exit;
}

// ---- selection and targeting ----
for (var k = 1; k < N; k++) {
    if (!keyboard_check_pressed(ord(string(k)))) continue;

    if (pending_verb == "") { selected = k; sfx("snd_ui_move"); break; }

    if (!is_active(k) && pending_verb != "espy") {
        add_log(factions[k].name + " is in no position to answer.");
        pending_verb = ""; pending_first = -1;
        break;
    }

    // an oath opens the builder instead of resolving straight away
    if (pending_verb == "oath") {
        if (oath_exists(ME, k)) {
            add_log("There is already an oath open with " + factions[k].name + ".");
            pending_verb = "";
            break;
        }
        oath_target = k;
        oath_mode   = true;
        oath_field  = 0;
        oath_span   = OATH_KINDS[oath_kind].span;
        selected    = k;
        break;
    }

    // two-target verbs wait for a second pick
    if (pending_verb == "poison" || pending_verb == "broker") {
        if (pending_first == -1) {
            pending_first = k;
            add_log(pending_verb == "poison"
                ? "Poison: set " + factions[k].name + " against...?"
                : "Broker: " + factions[k].name + " and...?");
            break;
        }
        if (pending_first == k) break;
        plan_add(pending_verb, pending_first, k);
        pending_first = -1;
        pending_verb = "";
        selected = k;
        break;
    }

    plan_add(pending_verb, k, -1);
    pending_verb = "";
    selected = k;
    break;
}

// ---- verbs ----
if (plan_room() > 0) {
    var _vk = "";
    if (keyboard_check_pressed(ord("A"))) _vk = "attack";
    if (keyboard_check_pressed(ord("S"))) _vk = "aid";
    if (keyboard_check_pressed(ord("B"))) _vk = "bind";
    if (keyboard_check_pressed(ord("E"))) _vk = "espy";
    if (keyboard_check_pressed(ord("O"))) _vk = "oath";
    if (_vk != "") {
        pending_verb = _vk;
        pending_first = -1;
        sfx("snd_ui_move");
    }
 
    if (keyboard_check_pressed(ord("F"))) {
        if (array_length(board) == 0) {
            add_log("Nothing is being sworn anywhere. There is nothing to lean on.");
            sfx("snd_ui_move");
        } else {
            lean_mode  = true;
            lean_pick  = 0;
            oath_field = 0;
            pending_verb = ""; pending_first = -1;
            sfx("snd_ui_confirm");
        }
    }
}

if (keyboard_check_pressed(ord("L"))) {
    if (factions[ME].treasury < COST_PER_LEVY)
        add_log("There is no gold to raise more men.");
    else
        plan_add("levy", ME, -1, 1);      // costs gold, not resolve
    pending_verb = ""; pending_first = -1;
}

// V visits the selected court. Free -- it costs no action point, which is
// what makes it worth doing every year.
if (keyboard_check_pressed(ord("V")) && selected != ME) audience_open(selected);

if (keyboard_check_pressed(vk_escape)) {
    if (pending_verb != "") { pending_verb = ""; pending_first = -1; }
    else plan_undo();
}
if (keyboard_check_pressed(vk_backspace)) plan_undo();


// ---- commit the year ----
if (keyboard_check_pressed(vk_enter)) {
    pending_verb = ""; pending_first = -1;
    phase = "resolving";
	sfx("snd_ui_confirm");

    // Ask the quantum state for this year's outcomes BEFORE any classical
    // bookkeeping: who moves, and how each battle lands.
    var _qs = [ { kind: "initiative" } ];

    for (var i = 0; i < array_length(plan); i++) {
        if (plan[i].verb != "attack") continue;
        var _t = plan[i].a;

        // v8 INTERFERENCE. Anything else you queued this month that lands on
        // the same kingdom arrives at the same qubit, and the server composes
        // them into one prepared state before the single deciding shot. Two
        // pushes the same way add exactly; opposite ways cancel exactly;
        // different KINDS of pressure do neither, because they are rotations
        // about axes that do not commute.
        //
        // So marching on someone you are also trying to bind is not two
        // separate events any more. It is one measurement you have pulled in
        // two directions.
        var _rots = [];
        for (var j = 0; j < array_length(plan); j++) {
            if (j == i) continue;
            var _p2 = plan[j];
            if (_p2.verb == "bind" && _p2.a == _t)
                array_push(_rots, { q: _t, axis: "X", angle: -0.5 });
            if (_p2.verb == "aid" && _p2.a == _t)
                array_push(_rots, { q: _t, axis: "X", angle: -0.35 });
            if (_p2.verb == "poison" && (_p2.a == _t || _p2.b == _t))
                array_push(_rots, { q: _t, axis: "Z", angle: 0.9 });
            if (_p2.verb == "oath" && _p2.a == _t)
                array_push(_rots, { q: _t, axis: _p2.axis, angle: -0.45 });
        }

        array_push(_qs, {
            kind: "battle",
            a: ME,
            b: _t,
            attacker_strength: factions[ME].army,
            defender_strength: defensive_strength(_t),
            rotations: _rots
        });
    }

    post("/resolve", { year: year, questions: _qs }, "resolve");
}