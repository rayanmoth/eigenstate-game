#region CREATE
 
randomise();
display_set_gui_size(640, 360);


scene = "splash";          // "splash" | "title" | "intro" | "play"

splash_timer    = 0;       // seconds since the splash began
SPLASH_FADE_IN  = 1.0;
SPLASH_HOLD     = 1.4;
SPLASH_FADE_OUT = 1.0;

INTRO_SPEED_BASE = 32;
 
intro_lines    = [];      // the letter, pre-wrapped
intro_total    = 0;       // total characters across all lines
intro_shown    = 0;       // characters revealed so far
intro_speed    = INTRO_SPEED_BASE;	      // characters per second.
                          // The letter is 734 characters, so this reveals
                          // it in about 8.6s -- brisk enough not to test
                          // anyone's patience, slow enough to read. At 42
                          // it took 17.5s, which is far too long for
                          // something people will see on every run.
						  
intro_lock  = 0;          // seconds of input lockout left after a reveal
INTRO_LOCK  = 0.35;       // long enough that one burst of taps cannot
                          // reveal the letter AND start the game
						  
intro_ready    = false;   // lines built yet (needs a font, so done in Draw)
intro_done     = false;   // letter fully revealed
intro_waiting  = false;   // finished, but the oracle has not answered
help_page = 0;       // 0 = how to play, 1 = the quantum

measuring_queue    = [];   // battles awaiting a "measurement" beat
measuring_answers  = [];   // full /resolve answers, applied once the queue clears
measuring_hold     = 0;
MEASURE_HOLD_REQ   = 0.6;  // quick -- a beat, not a whole minigame
measuring_revealed = false;
measuring_incoming = false;

bias_word = function(_b) {
    if (_b >  0.5)  return "the odds favour you";
    if (_b >  0.15) return "the odds lean your way";
    if (_b > -0.15) return "the odds are even";
    if (_b > -0.5)  return "the odds lean against you";
    return "the odds are against you";
}

// The intro can run with or without the connection gate installed.
// If `link` was never added, treat the world as ready.
link_ok = function() {
    if (!variable_instance_exists(id, "link")) return true;
    return link == "ok";
}
link_down = function() {
    if (!variable_instance_exists(id, "link")) return false;
    return link == "down";
}

// The handshake state the intro gate was always meant to read. Without
// these three, link_ok() returned true before the world existed and you
// could walk into a court belonging to a leader who had never been
// measured -- which crashes on _f.head.
link      = "waiting";     // "waiting" | "ok" | "down"
link_note = "";

// The host lives in exactly ONE place now. Point this at Vercel and the
// game needs no local Python at all -- no venv, no launcher, nothing to
// autostart, because there is nothing local to start.

// SERVER_BASE = "http://localhost:5055";
SERVER_BASE = "https://eigenstate-ten.vercel.app";
 
// The authoritative world state. undefined until /newgame hands one back,
// which is how the server knows to create one rather than load one.
// About 1.1 KB of JSON against a 4.5 MB request limit.
world = undefined;

retry_link = function() {
    link = "waiting";
    link_note = "";
    starting = true;
    post("/newgame", {}, "newgame");
    add_log("Reaching for the oracle again...");
}
 
LETTER_TITLE = "To the Regent of Eigenstate";
 
LETTER_BODY =
"I have a season left, maybe less. The crown is yours now, so here is "
+ "what you actually need to know.\n\n"
+ "Four kingdoms border us: Coherre, Decohra, Phasemark, Nullhold. None "
+ "are friends and none are fixed enemies. Push one too hard and it turns "
+ "on you. Tie yourself too closely to one and you lose the ability to "
+ "act against it later -- that is not advice, it is how this world "
+ "works. Every court's mood and every bond between courts can shift, "
+ "and every shift has a cost.\n\n"
+ "You have two years. Each month you choose: attack, make peace, build "
+ "up your own strength, or wait. What actually happens depends on them "
+ "as much as you.\n\n"
+ "Survive it and rule however you like. Act wisely.";

LETTER_SIGN = "-- Aurel, the (former) king of Eigenstate";

 
 
N            = 5;
ME           = 0;
MONTHS_TOTAL  = 24;
ACTIONS_MAX  = 3;
 
START_HOLDINGS       = 4;
START_ARMY           = 10;
START_TREASURY       = 120;
INCOME_PER_HOLD      = 26;
TRIBUTE_PER_VASSAL   = 12;
UPKEEP_PER_ARMY      = 2;
COST_PER_LEVY        = 14;
LEVY_BATCH           = 4;
COST_ATTACK          = 20;
COST_AID             = 15;
UNREST_MAX           = 100;
UNREST_PER_BATTLE    = 2;
UNREST_PER_LOSS      = 8;
UNREST_PER_HOLD_LOST = 14;
UNREST_PER_OCCUPIED  = 7;
UNREST_PEACE_DECAY   = 6;
UNREST_UNPAID        = 10;
CIVIL_WAR_UNREST     = 62;
// BATTLE_LUCK removed -- battles are measured, not rolled.
DEFENDER_BONUS       = 1.15;
MARCH_ATTRITION      = 0.18;
ALLY_DEF_FACTOR      = 0.60;
ARMY_PER_HOLD        = 3.0;
CONSCRIPTION_UNREST  = 1.4;
COALITION_TRIGGER    = 1.35;
INDEP_ACTION_FLOOR   = 0.50;
REBEL_UNREST         = 55;
ALLY_THRESHOLD       = 0.35;
WAR_THRESHOLD        = -0.30;


STAND_ALLY_IN  =  0.35;
STAND_ALLY_OUT =  0.22;
STAND_WAR_IN   = -0.30;
STAND_WAR_OUT  = -0.17;
 
year         = 1;
actions_left = ACTIONS_MAX;
selected     = 1;
pending_verb = "";
pending_first= -1;
game_over    = false;
restarting = false;      // set only on an F5 restart, read by Game End
tut_asked = false;
ending       = "";
queued       = [];
awaiting     = false;
starting     = true;
request_id   = -1;
 
log_lines = [];
LOG_MAX   = 8;

unrest_why = [];        // [[label, delta], ...] for the player's kingdom only



// ---------- where the brain lives ----------
//
// TWO CASES. In the IDE the server sits in your own folder; in an exported
// build it is in Included Files, which land in working_directory. Rather than
// make you remember to change it before building, look for the server file
// and use whichever place actually has it.
//

SERVER_DIR_DEV = "/Users/mothintern/Downloads/eigenstate";
SERVER_RETRY_EVERY   = 2.5;     // seconds between handshake attempts
SERVER_RETRY_MAX     = 40;      // ~100s of patience, well past a 32s boot


server_spawn_tried   = false;   // we only ever spawn once per run
server_retry_timer = SERVER_RETRY_EVERY;
server_retry_count = 0;
 
server_dir = function() {
    // exported build first: if the files shipped with the game, use those
    if (file_exists(working_directory + "eigenstate_server.py")) {
        var _d = string_replace_all(working_directory, "\\", "/");
        while (string_length(_d) > 1
        &&     string_char_at(_d, string_length(_d)) == "/")
            _d = string_copy(_d, 1, string_length(_d) - 1);
        return _d;
    }
    return SERVER_DIR_DEV;
}
 
// Can this runtime spawn a process at all? LTS2026's macOS runner cannot,
// so this is false in practice today. Probed rather than assumed.
SERVER_SPAWN_ENABLED = false;
try {
    if (os_type == os_windows) execute_shell("cmd", "/c exit");
    else                       execute_shell("/usr/bin/true", "");
    SERVER_SPAWN_ENABLED = true;
} catch (_e) {
    show_debug_message("no execute_shell on this runtime; "
                     + "the server must be started outside the game");
}

show_debug_message("SERVER_BASE = " + SERVER_BASE);

server_can_spawn   = SERVER_SPAWN_ENABLED;

 
/// @desc Start the server. Non-blocking: execute_shell returns immediately
/// and the server takes half a minute, which is exactly why the retry loop
/// below exists rather than a sleep.
server_spawn = function() {
    if (!SERVER_SPAWN_ENABLED) return false;
    if (server_spawn_tried) return false;      // never twice: an orphan on
    server_spawn_tried = true;                 // 5055 is the worst outcome
 
    var _dir = server_dir();
    add_log("Waking the oracle...");
 
    if (os_type == os_macosx || os_type == os_linux) {
        execute_shell("/bin/bash", "\"" + _dir + "/start_server.sh\" --nowait");
    } else if (os_type == os_windows) {
        // cmd needs the whole thing wrapped again when the path has spaces
        execute_shell("cmd", "/c \"\"" + _dir + "/start_server.bat\"\"");
    } else {
        add_log("Cannot start the oracle on this platform. Start it by hand.");
        return false;
    }
    return true;
}
 
/// @desc Called from Game End. Only stops a server THIS RUN started, so
/// closing the game never kills the one you have open in a terminal while
/// you are working.
server_shutdown = function() {
    if (!server_spawn_tried) return;   // only stop what we started
    var _dir = server_dir();
    if (os_type == os_macosx || os_type == os_linux)
        execute_shell("/bin/bash", "\"" + _dir + "/stop_server.sh\"");
    else if (os_type == os_windows)
        execute_shell("cmd", "/c \"\"" + _dir + "/stop_server.bat\"\"");
}

 
/// @desc Record one contribution. Called from year_economy.
/// Only tracks ME: the rivals' bookkeeping is not the player's business and
/// logging all five would drown the chronicle.
unrest_note = function(_i, _label, _delta) {
    if (_i != ME) return;
    if (abs(_delta) < 0.5) return;
    array_push(unrest_why, [_label, _delta]);
}
 
/// @desc The month's unrest movement as one sentence, or "" if nothing moved.
///
/// Sorted biggest-first so the thing to act on is the thing you read first.
/// Signs are explicit, because "+8 occupied land" and "-6 two allies" have to
/// be distinguishable at a glance in a four-line chronicle.
unrest_line = function() {
    if (array_length(unrest_why) == 0) return "";
 
    // insertion sort by absolute size; the list is never longer than 6
    for (var i = 1; i < array_length(unrest_why); i++) {
        var _v = unrest_why[i];
        var j = i - 1;
        while (j >= 0 && abs(unrest_why[j][1]) < abs(_v[1])) {
            unrest_why[j + 1] = unrest_why[j];
            j--;
        }
        unrest_why[j + 1] = _v;
    }
 
    var _s = "Unrest " + string(round(factions[ME].unrest)) + ":";
    for (var i = 0; i < array_length(unrest_why); i++) {
        var _d = unrest_why[i][1];
        _s += (i > 0 ? "," : "") + " " + (_d > 0 ? "+" : "")
            + string(round(_d)) + " " + unrest_why[i][0];
    }
    return _s;
}
 

standing = array_create(N);
for (var i = 0; i < N; i++) standing[i] = array_create(N, "-");

update_standing = function() {
    for (var i = 1; i < N; i++) {
        var _b = bonds[ME][i];
        var _s = standing[ME][i];
        if (_s == "ALLY") {
            if (_b < STAND_ALLY_OUT) _s = "-";
        } else if (_s == "WAR") {
            if (_b > STAND_WAR_OUT) _s = "-";
        } else {
            if (_b > STAND_ALLY_IN) _s = "ALLY";
            else if (_b < STAND_WAR_IN) _s = "WAR";
        }
        standing[ME][i] = _s;
        standing[i][ME] = _s;
    }
}


// ---------- settings, persisted ----------
// One ini next to the save data. GameMaker gives every game a writable
// sandbox directory, so this needs no path handling and no permissions.
SETTINGS_FILE = "eigenstate.ini";
 
opt_fullscreen = false;
opt_music      = 0.7;      // 0..1
opt_sfx        = 0.8;      // 0..1
opt_textspeed  = 1.0;      // multiplier on the intro crawl
opt_tutorial   = true;     // offer the tutorial on a fresh load
 
settings_load = function() {
    ini_open(SETTINGS_FILE);
    opt_fullscreen = bool(ini_read_real("video", "fullscreen", 0));
    opt_music      = ini_read_real("audio", "music", 0.7);
    opt_sfx        = ini_read_real("audio", "sfx",   0.8);
    opt_textspeed  = ini_read_real("text",  "speed", 1.0);
    opt_tutorial   = bool(ini_read_real("game",  "tutorial", 1));
    ini_close();
    settings_apply();
}
 
settings_save = function() {
    ini_open(SETTINGS_FILE);
    ini_write_real("video", "fullscreen", opt_fullscreen ? 1 : 0);
    ini_write_real("audio", "music", opt_music);
    ini_write_real("audio", "sfx",   opt_sfx);
    ini_write_real("text",  "speed", opt_textspeed);
    ini_write_real("game",  "tutorial", opt_tutorial ? 1 : 0);
    ini_close();
}

// Each entry is one screenful. "--- X ---" is a section heading, "" is a
// gap. Keep any page to about twelve rows and it will never overflow.
HELP_PAGES = [
    [
        ["--- YOUR MONTH ---", ""],
        ["A attack",     "march on a kingdom. costs gold, risks losses"],
        ["S aid",        "calm their unrest, soften them toward you"],
        ["B bind",       "strengthen a bond. costs you freedom to act later"],
        ["E espy",       "send agents. refreshes what you know of a court"],
        ["L levy",       "raise men. costs gold but not an action point"],
        ["", ""],
        ["--- IN THEIR COURT (V) ---", ""],
        ["ask about",    "what they know, if they like you enough to say"],
        ["make amends",  "increase bond / relations with the host kingdom"],
        ["threaten",     "decrease bond / relations with the host kingdom"],
        ["jester",       "request a jester, and 'discard' of him when done"],
    ],
    [
        ["--- OATHS ---", ""],
        ["O oath",       "swear something that resolves months later"],
        ["F lean",       "push on any open oath, including other people's"],
        ["", ""],
        ["--- WHAT THE NUMBERS MEAN ---", ""],
        ["mood",         "how warlike they are. seething means they want war"],
        ["bond",         "how entangled you are. + allied, - hostile"],
        ["sway",         "bonds run one way. who can lean on whom"],
        ["debt",         "what they owe you, and you them"],
        ["freedom",      "how much a kingdom is still its own. low = fewer acts"],
    ],
    [
        ["--- KEYS ---", ""],
        ["1-4",          "choose a kingdom"],
        ["V",            "stand in their court"],
        ["ENTER",        "end the month"],
        ["BACKSPACE",    "undo the last thing you queued"],
        ["Q",            "the Observatory -- the real quantum state"],
        ["H",            "this screen"],
        ["P",            "settings, at any time"],
        ["F5",           "start a fresh run"],
    ],
];
 
/// @desc Push the current settings at the actual engine. Called on load and
/// whenever a value changes, so there is never a "press apply" step.
settings_apply = function() {
    if (window_get_fullscreen() != opt_fullscreen)
        window_set_fullscreen(opt_fullscreen);
    intro_speed = INTRO_SPEED_BASE * opt_textspeed;
 
    if (bgm != undefined && audio_is_playing(bgm))
        audio_sound_gain(bgm, opt_music, 0);
 
    // only touch the throne theme if it is actually up, or this would
    // un-duck it while the player is stood on the map
    if (throne_bgm != undefined && audio_is_playing(throne_bgm)
     && audience_of != -1 && jbit == "")
        audio_sound_gain(throne_bgm, opt_music * 0.8, 0);
 
    if (jester_music != -1 && audio_is_playing(jester_music))
        audio_sound_gain(jester_music, opt_music * JESTER_GAIN, 0);
}


/// @desc One frame of settings input. Returns true when the player wants
///       out, and the CALLER decides what out means -- the title menu goes
///       back to root, the in-game overlay closes. Shared so the two can
///       never drift apart.
settings_input = function() {
    var _n = array_length(SETTING_ROWS);
    if (keyboard_check_pressed(vk_down)) { set_pick = (set_pick + 1) mod _n; sfx("snd_ui_move"); }
    if (keyboard_check_pressed(vk_up))   { set_pick = (set_pick - 1 + _n) mod _n; sfx("snd_ui_move"); }
 
    var _step = 0;
    if (keyboard_check_pressed(vk_right)) _step =  1;
    if (keyboard_check_pressed(vk_left))  _step = -1;
    // held arrows nudge sliders, because 0.02 at a time by tapping is a
    // bad way to spend someone's attention
    if (_step == 0) {
        if (keyboard_check(vk_right)) _step =  1;
        if (keyboard_check(vk_left))  _step = -1;
    }
 
    var _kind = SETTING_ROWS[set_pick][1];
    if (_kind == "toggle") {
        if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(vk_left)
         || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
            if (set_pick == 0) opt_fullscreen = !opt_fullscreen;
            if (set_pick == 4) opt_tutorial   = !opt_tutorial;
            settings_apply(); settings_save(); sfx("snd_ui_confirm");
        }
    } else if (_step != 0) {
        var _d = _step * 0.02;
        if (set_pick == 1) opt_music     = clamp(opt_music + _d, 0, 1);
        if (set_pick == 2) opt_sfx       = clamp(opt_sfx + _d, 0, 1);
        if (set_pick == 3) opt_textspeed = clamp(opt_textspeed + _d * 2, 0.25, 3);
        settings_apply();
        // save on release rather than every frame
        if (keyboard_check_released(vk_right) || keyboard_check_released(vk_left))
            settings_save();
        if (set_pick == 2 && keyboard_check_pressed(vk_right)) sfx("snd_ui_move");
    }
 
    return keyboard_check_pressed(vk_escape);
}
 
/// @desc The settings panel. Takes its own footer so the title screen and
///       the in-game overlay can advertise different close keys.
settings_panel_draw = function(_footer) {
    var _sp = ui_panel(140, 60, 360, 240, "SETTINGS");
    var _slh = ui_line_h();
    ui_reserve(_sp, _slh + 4);
    var _lblw = string_width("offer tutorial") + 16;
 
    for (var i = 0; i < array_length(SETTING_ROWS); i++) {
        var _sel = (i == set_pick);
        var _col = _sel ? ui_col("you") : ui_col("dim");
        ui_text(_sp.x, _sp.cursor, (_sel ? "> " : "  ") + SETTING_ROWS[i][0],
                _col, _lblw);
 
        var _vx = _sp.x + _lblw;
        if (SETTING_ROWS[i][1] == "toggle") {
            var _on = (i == 0) ? opt_fullscreen : opt_tutorial;
            ui_text(_vx, _sp.cursor, _on ? "on" : "off",
                    _on ? ui_col("ally") : ui_col("faint"));
        } else {
            var _v = opt_music;
            if (i == 2) _v = opt_sfx;
            if (i == 3) _v = opt_textspeed / 3.0;
            ui_meter(_vx, _sp.cursor + _slh * 0.4, 120, _v, ui_col("quantum"));
            var _shown = string(round(_v * 100)) + "%";
            if (i == 3) _shown = string_format(opt_textspeed, 1, 2) + "x";
            ui_text(_vx + 130, _sp.cursor, _shown, ui_col("faint"));
        }
        _sp.cursor += _slh + 4;
    }
 
    ui_text(_sp.x, ui_footer_y(_sp), _footer, ui_col("faint"), _sp.inner_w);
}
 
// ---------- audio, defensively ----------
// Looked up by NAME. If the asset does not exist yet, sfx() and music_start()
// do nothing and the game is otherwise identical. This is what lets you add
// sound later without touching code.
 
/// @desc Play a one-shot by asset name. Silent no-op if it is not in the
/// project, so every call site can be written before the sound exists.
sfx = function(_name) {
    if (opt_sfx <= 0.001) return;
    var _s = asset_get_index(_name);
    if (_s == -1) return;
    var _i = audio_play_sound(_s, 1, false);
    audio_sound_gain(_i, opt_sfx, 0);
}
 
// ---------- menu ----------
MENU_ITEMS = ["BEGIN", "SETTINGS", "QUIT"];
menu_pick  = 0;
menu_page  = "root";     // "root" | "settings" | "quantum"
 
SETTING_ROWS = [
    ["fullscreen",  "toggle"],
    ["music",       "slider"],
    ["sound",       "slider"],
    ["text speed",  "slider"],
    ["offer tutorial", "toggle"],
];
set_pick = 0;
 
// ---------- the quantum explainer ----------
// Pages, not a wall. Each page is one idea and one concrete consequence,
// because "your bond is a ZZ correlator" means nothing on its own and
// "which is why binding someone costs you the freedom to betray them" does.
QUANTUM_PAGES = [
    {
        title: "Five kingdoms, five qubits",
        body:  "Every kingdom in this game is one qubit in a real quantum "
             + "circuit. Its mood is not a number someone typed in: it is "
             + "the qubit's Z component, read by measuring the circuit.\n"
             + "\n"
             + "A kingdom leaning toward war is a qubit rotated toward one "
             + "pole. Calm it and you are rotating it back."
    },
    {
        title: "Relationships are entanglement",
        body:  "When two kingdoms are bound, their qubits are entangled. "
             + "The strength of the bond is how correlated they are, and the "
             + "sign says which way: allied means they tend to agree, at war "
             + "means they tend to disagree.\n"
             + "\n"
             + "This is why bonds are not free. A qubit can only hold so "
             + "much correlation, so binding one kingdom close genuinely "
             + "leaves less of them for anyone else, including for you."
    },
    {
        title: "Certainty costs you options",
        body:  "The more certain a kingdom's mood, the less room is left in "
             + "its state for connection. That is a real property of a "
             + "qubit, not a rule bolted on.\n"
             + "\n"
             + "It is also why FREEDOM matters. A court tangled up in "
             + "everyone else's business has less of itself left, and gets "
             + "fewer actions. Conviction and connection compete."
    },
    {
        title: "Pressure does not simply add",
        body:  "The three kinds of pressure are rotations about different "
             + "axes, and rotations about different axes do not commute.\n"
             + "\n"
             + "Two pushes the same way add exactly. Two opposite ways "
             + "cancel exactly. But force and coercion are neither: "
             + "coercion alone does almost nothing, and changes what force "
             + "is worth. That is interference, and it is the reason the "
             + "ORDER things happen in matters."
    },
    {
        title: "Outcomes are measurements",
        body:  "Nothing here rolls a die. When a battle lands or an oath "
             + "comes due, the circuit is measured and the collapse IS the "
             + "outcome. The odds you are shown beforehand are the real "
             + "probabilities of that state.\n"
             + "\n"
             + "An oath is a deferred measurement: sworn now, measured "
             + "months later, from whatever the world has done to it in "
             + "between."
    },
    {
        title: "And some of it runs on real hardware",
        body:  "The world is simulated locally so the game stays fast. But "
             + "an oath coming due can be sent to Moth Quantum's platform, "
             + "which prepares this exact five-kingdom state and measures "
             + "it, on a simulator or on an IBM quantum computer.\n"
             + "\n"
             + "When that happens the game says so, and records the job. "
             + "Press Q in play to see the machinery."
    },
];
q_page = 0;
 
// ---------- tutorial ----------
// Cards over the live game. Each card is one idea, in the order you will
// actually need it, and each says what to press. `focus` names the part of
// the screen it is about so the draw code can point at it.
TUTORIAL = [
    { focus: "top",     title: "Your court",
      body: "Top left is the month, then your army over what your land can "
          + "support, your gold, and your holdings. UNREST rises when you "
          + "overreach. FREEDOM is how much of your court is still its own.\n"
          + "Right of that: how many actions you have left this month." },
    { focus: "roster",  title: "The other kingdoms",
      body: "Four rivals. MOOD is how warlike they are, STANDING is where "
          + "they sit with you. Press 1 to 4 to select one.\n"
          + "You will see 'unknown' for courts you have no fresh word from. "
          + "That is not a bug, it is what you have not looked at." },
    { focus: "detail",  title: "What you know",
      body: "The panel under the roster is the selected kingdom in full. "
          + "bond is how entangled you are, sway is who can lean on whom, "
          + "debt is unsettled favours.\n"
          + "sway and debt run in a direction. Holding sway over someone is "
          + "worth troops when it comes to a fight." },
    { focus: "council", title: "Acting",
      body: "The verbs at the bottom are your month. Press the letter, then "
          + "a number for who.\n"
          + "attack marches. aid calms. bind ties you closer. espy sends "
          + "agents. levy buys army. poison and broker work on two OTHER "
          + "kingdoms, not on you." },
    { focus: "council", title: "Nothing happens until you say so",
      body: "Everything you pick is queued, not done. You can see the whole "
          + "month before it happens and BACKSPACE to undo.\n"
          + "ENTER ends the month and resolves all of it at once." },
    { focus: "council", title: "Actions cost, and interfere",
      body: "You get a small number of actions a month, so a month is a "
          + "choice about what NOT to do.\n"
          + "And two things aimed at the same kingdom in the same month do "
          + "not just both happen. They combine. Marching on someone you "
          + "are also trying to bind pulls one measurement two ways." },
    { focus: "oaths",   title: "Oaths",
      body: "Press O to swear something. Pick who, then what kind, what "
          + "sort of pressure it is made of, how many months it runs, and "
          + "how much of yourself is behind it.\n"
          + "It does not resolve now. It goes on the board where everyone "
          + "can see it." },
    { focus: "oaths",   title: "The board is shared",
      body: "Every open oath in the world sits there, yours in gold. The "
          + "percentage is the real chance it seals if it were measured "
          + "right now.\n"
          + "Watch it move. It moves because people are working on it." },
    { focus: "oaths",   title: "Leaning",
      body: "Press F to lean on ANY open oath, including other people's. "
          + "Feed it or wreck it, choose which side you lean on, and choose "
          + "the kind of pressure.\n"
          + "The kind matters. Force cancels force exactly. Coercion does "
          + "almost nothing alone but changes what force is worth." },
    { focus: "council", title: "Visiting",
      body: "Press V to stand in the selected court. It costs no action, so "
          + "it is worth doing every month.\n"
          + "You will see their ruler, and their face hardens over a run as "
          + "their qubit rotates. Some of what you can do in there does "
          + "cost an action." },
    { focus: "none",    title: "When it resolves",
      body: "At the end of a month the world is measured. Battles you "
          + "started get a beat where you hold SPACE and watch the state "
          + "collapse. The odds shown are real.\n"
          + "Then the month's events come as cards. Read them: that is "
          + "where you find out what everyone else did." },
    { focus: "none",    title: "That is all of it",
      body: "H opens help at any time. Q opens the Observatory, which shows "
          + "the actual quantum state and the operations run last month.\n"
          + "You have twenty-odd months. Good luck." },
];
 
tut_active = false;       // cards are showing
tut_step   = 0;
tut_prompt = false;       // the "walk me through it?" question
tut_prompt_pick = 0;
 
tut_begin = function() {
    tut_active = true;
    tut_step   = 0;
    tut_prompt = false;
    sfx("snd_ui_confirm");
}
 
tut_end = function(_silent) {
    tut_active = false;
    tut_prompt = false;
    if (!_silent) add_log("Tutorial closed. Press H for help at any time.");
}
 
// bgm / throne_bgm are declared near the top now, above settings_load(),
// because settings_apply() reads them. They are still STARTED at the
// bottom of this event. 
bgm = undefined;        // music handle, set at the very end of this event
throne_bgm = undefined; // handle for snd_throne_bgm, played while in a court

// beats, in order. "" means the bit is not running.
//   "usher"  ruler leaving      "enter"  jester arriving
//   "dance"  the main event     "boom"   he is dealt with
//   "return" ruler coming back
jbit   = "";
jbit_t = 0;
jester_music = -1;      // the looping snd_jester instance
 
// Called once, from Create, at the very bottom:
settings_load();
 
var _names   = ["Eigenstate","Coherre","Decohra","Phasemark","Nullhold"];
var _leaders = ["you","Archon Sel","Elder Mave","Warden Pell","Queen Verrin"];
 
factions = array_create(N);
for (var i = 0; i < N; i++) {
    factions[i] = {
        id: i,
        name: _names[i],
        leader: _leaders[i],
        hostility: 0,    prev_hostility: 0,
        independence: 1, prev_independence: 1,
		conviction: 0, // how SURE they are of their mood
		leverage: 0,   // >0 they have sway over you, <0 you over them
		debt: 0, tangle: 0,
		bloch_x: 0, bloch_y: 0, bloch_z: 0,
        intel_fresh: (i == ME),
        last_scouted: 0,
        army: START_ARMY,
        treasury: START_TREASURY,
        holds: START_HOLDINGS,
        unrest: 0,
        alive: true,
        vassal_of: -1,
        temper: "wary",
        title: "",  hair: 0, outfit: 0, build: 0, hall: 0, traits: "",
		budget_max: 1.25, budget_used: 0, commitments: []
    };
}
 
bonds = array_create(N);
for (var i = 0; i < N; i++) bonds[i] = array_create(N, 0);


// WHAT YOU BELIEVE, as opposed to what is true.
//
// bonds[][] is the live world, and the server sends all ten pairs every turn.
// Drawing that directly meant the player already knew how Coherre felt about
// Decohra without ever asking, which made asking pointless. So the UI reads
// this instead, and this only fills in when somebody tells you or you scout
// one of the parties.
//
// -2 is "never heard anything", chosen because it is outside the -1..1 range
// a real correlation can occupy, so no valid bond can be mistaken for it.
//
// DIRECTIONAL ON PURPOSE. bonds[a][b] == bonds[b][a] in the server, but
// KNOWLEDGE is not symmetric: Coherre telling you they are bound to Decohra
// says nothing about what Decohra would say about Coherre. Storing both
// directions is what makes walking both courts worth doing.
known_bonds = array_create(N);
for (var i = 0; i < N; i++) known_bonds[i] = array_create(N, -2);
 
known_bond_age = array_create(N);
for (var i = 0; i < N; i++) known_bond_age[i] = array_create(N, -99);
 
GOSSIP_TTL = 6;      // months before a heard bond is drawn as stale
 
/// @desc Record what a court told you. One place, so every source agrees.
gossip_learn = function(_from, _about, _value) {
    if (_from == _about) return;
    known_bonds[_from][_about]    = _value;
    known_bond_age[_from][_about] = year;
}
 
/// @desc "fresh" | "stale" | "unknown". What the UI branches on.
known_state = function(_a, _b) {
    if (_a == _b) return "fresh";
    if (known_bonds[_a][_b] == -2) return "unknown";
    if (year - known_bond_age[_a][_b] > GOSSIP_TTL) return "stale";
    return "fresh";
}

// WHO DID WHAT TO WHOM, and it does not forget quickly.
//
// grudge[victim][aggressor]. Asymmetric on purpose: you attacking someone
// does not make YOU resent THEM, and the whole failure was that the game had
// no directional memory of harm at all.
//
// Decays much slower than bonds (0.965 against 0.90) so a grievance outlives
// the correlation it created. That gap is the point: the bond fades, the
// grudge does not, and a kingdom that has been beaten twice keeps behaving
// like one long after the numbers look calm.
grudge = array_create(N);
for (var i = 0; i < N; i++) grudge[i] = array_create(N, 0);
 
GRUDGE_DECAY   = 0.965;
GRUDGE_ATTACK  = 0.55;   // one march
GRUDGE_SIEGE   = 0.40;   // a siege sworn against them, before it even lands
GRUDGE_SPY     = 0.15;   // caught in their court
GRUDGE_HARD    = 0.45;   // above this they will not bind with you
GRUDGE_MAX     = 1.60;   // room for three or four offences to still stack
 
/// @desc Record harm. Call it wherever harm happens, not just in battle.
grudge_add = function(_victim, _aggressor, _amount) {
    if (_victim == _aggressor) return;
    grudge[_victim][_aggressor] = min(GRUDGE_MAX,
                                      grudge[_victim][_aggressor] + _amount);
}
 
/// @desc 0..1-ish, for use as a score multiplier.
grudge_of = function(_victim, _aggressor) {
    return grudge[_victim][_aggressor];
}
 
/// @desc Called once a month. Put this next to wherever you already age
/// things per month -- the top of the EVENTS phase's "year is finished"
/// block in Step_0 is the natural home, beside `year++`.
grudge_decay = function() {
    for (var i = 0; i < N; i++)
        for (var j = 0; j < N; j++) {
            if (i == j) continue;
            grudge[i][j] *= GRUDGE_DECAY;
            if (grudge[i][j] < 0.04) grudge[i][j] = 0;
        }
}
 

overlay = "";       // "" | "observatory" | "help"
q_gates     = [];       // the actual quantum operations from last turn
q_depth     = 0;
q_gatecount = 0;
q_shots     = 0;
lev_matrix  = array_create(N);
for (var i = 0; i < N; i++) lev_matrix[i] = array_create(N, 0);
 
// ---------- helpers ----------

conviction_word = function(_c) {
    if (_c > 0.80) return "unshakeable";
    if (_c > 0.55) return "settled";
    if (_c > 0.30) return "wavering";
    return "in the balance";
}
 
leverage_word = function(_l) {
    if (_l >  0.45) return "they hold you";
    if (_l >  0.15) return "they have the ear";
    if (_l < -0.45) return "you hold them";
    if (_l < -0.15) return "you have the ear";
    return "even footing";
}

add_log = function(_t) {
    array_push(log_lines, _t);
    while (array_length(log_lines) > LOG_MAX) array_delete(log_lines, 0, 1);
}
 
mood_word = function(_h) {
    if (_h >  0.55) return "seething";
    if (_h >  0.20) return "hostile";
    if (_h > -0.20) return "wary";
    if (_h > -0.55) return "amiable";
    return "content";
}
 
self_word = function(_r) {
    if (_r > 0.85) return "its own master";
    if (_r > 0.60) return "entwined";
    if (_r > 0.35) return "dissolving";
    return "barely itself";
}

/// @desc How much sway a rival holds over you, in words.
sway_word = function(_v) {
    var _a = abs(_v);
    if (_a < 0.10) return "none";
    if (_a < 0.25) return (_v > 0) ? "slight hold" : "slight hold on them";
    if (_a < 0.50) return (_v > 0) ? "has your ear" : "you have theirs";
    return (_v > 0) ? "holds you" : "you hold them";
}
 
/// @desc Unsettled favours. Positive means you owe.
debt_word = function(_v) {
    var _a = abs(_v);
    if (_a < 0.10) return "clear";
    if (_a < 0.30) return (_v > 0) ? "you owe a little" : "owed a little";
    if (_a < 0.55) return (_v > 0) ? "in their debt" : "they owe you";
    return (_v > 0) ? "deep in their debt" : "deep in your debt";
}
 
/// @desc Bond as a word, so the roster and the detail panel agree. The
/// thresholds are the same ALLY_THRESHOLD / WAR_THRESHOLD the colours use,
/// so a kingdom drawn in war red never reads as "wary" in text.
bond_word = function(_v) {
    if (_v <= -0.55) return "at war";
    if (_v < WAR_THRESHOLD) return "hostile";
    if (_v < -0.08) return "wary";
    if (_v <= 0.08) return "indifferent";
    if (_v < ALLY_THRESHOLD) return "warming";
    if (_v < 0.55) return "friendly";
    return "bound close";
}

room_word = function(_left, _max) {
    var _f = (_max > 0) ? (_left / _max) : 0;
    if (_f <= 0.02) return "nothing left to give";
    if (_f < 0.20)  return "almost nothing left";
    if (_f < 0.50)  return "little left";
    if (_f < 0.80)  return "room for more";
    return "unattached";
}

grudge_word = function(_v) {
    if (_v < 0.20) return "";
    if (_v < 0.50) return "they have not forgotten";
    if (_v < 1.00) return "they want blood";
    return "they will not stop";
}
 
// a faction that is free to act (not a vassal, not dead)
is_active = function(_i) {
    return factions[_i].alive && factions[_i].vassal_of == -1;
}
 
power_of = function(_i) {
    return factions[_i].army + factions[_i].holds * 3;
}
 
rel_word = function(_i) {
    if (_i == ME) return "(you)";
    if (factions[_i].vassal_of == ME) return "VASSAL";
    if (factions[_i].vassal_of != -1)  return "held";
    return standing[ME][_i];   // already "ALLY", "WAR" or "-"
}
 
defensive_strength = function(_i) {
    var _s = factions[_i].army * DEFENDER_BONUS;
    for (var j = 0; j < N; j++) {
        if (j == _i) continue;
        if (factions[j].alive && factions[j].vassal_of == _i) {
            _s += factions[j].army * 0.75;   // your vassals march with you
            continue;
        }
        if (!is_active(j)) continue;
        if (bonds[_i][j] > ALLY_THRESHOLD)
            _s += factions[j].army * bonds[_i][j] * ALLY_DEF_FACTOR;
    }
    return _s;
}
 
sustainable_army = function(_i) {
    return factions[_i].holds * ARMY_PER_HOLD;
}
 
queue = function(_type, _f, _other) {
    var _e = { type: _type, faction: _f };
    if (_other != undefined) _e.other_faction = _other;
    array_push(queued, _e);
}
 
// generic quantum nudges (server v4)
queue_bond = function(_a, _b, _delta) {
    array_push(queued, { type: "nudge_bond", faction: _a,
                         other_faction: _b, delta: _delta });
    // mirror locally so this year's logic sees it immediately
    bonds[_a][_b] = clamp(bonds[_a][_b] + _delta, -1, 1);
    bonds[_b][_a] = bonds[_a][_b];
}
queue_mood = function(_a, _delta) {
    array_push(queued, { type: "nudge_mood", faction: _a, delta: _delta });
}
 
/// @desc POST to an endpoint, with the world attached.
///
/// _ep is a PATH now ("/turn"), not a full URL, so the host is configured
/// in one place. _body is a STRUCT, not a pre-stringified string, because
/// the world has to be attached to every single request and doing that by
/// string surgery would be miserable.
post = function(_ep, _body, _which) {
    if (!is_struct(_body)) _body = {};
 
    // THE WHOLE POINT. The server holds nothing between requests, so if we
    // do not send this, it does not know what game we are playing.
    if (world != undefined) _body.world = world;
 
    var _h = ds_map_create();
    ds_map_add(_h, "Content-Type", "application/json");
    request_id = http_request(SERVER_BASE + _ep, "POST", _h,
                              json_stringify(_body));
    ds_map_destroy(_h);
    awaiting = true;
    last_request = (_which == undefined) ? "turn" : _which;
}
 
// (4) vassalage rather than deletion
make_vassal = function(_i, _lord) {
    factions[_i].vassal_of = _lord;
    factions[_i].holds  = max(1, factions[_i].holds);          // they hold it for you
    factions[_i].army   = max(3, floor(factions[_i].army * 0.35));
    factions[_i].unrest = 40;

    // A sworn kingdom is CORRELATED with its lord, not merely labelled one.
    // This is the line that makes vassalage cost something: see below.
    queue_bond(_i, _lord, +0.85);
    add_log(factions[_i].name + " bends the knee to " + factions[_lord].name + ".");
    if (_lord == ME) {
        push_event("collapse", factions[_i].name + " bends the knee",
            factions[_i].leader + " kneels in your hall. Their land is yours to hold "
          + "and their people are yours to answer for.");
    } else if (_i != ME) {
        push_event("collapse", factions[_i].name + " has fallen",
            factions[_i].name + " is sworn to " + factions[_lord].name
          + " now. There is one less free power in the world, and one more "
          + "reason to count your friends.");
    }
    if (_i == ME) {
        game_over = true;
        ending = "DEPOSED. Eigenstate answers to " + factions[_lord].name
               + " now. Month " + string(year) + ".";
    }
}
 
// resolve_battle() removed: it was the classical dice version and is
// fully replaced by apply_battle(), which takes an outcome measured
// from the two kingdoms' joint quantum state.
 
// (1) the world closes ranks against whoever is winning
coalition_step = function() {
    var _act = [];
    for (var i = 0; i < N; i++) if (is_active(i)) array_push(_act, i);
    if (array_length(_act) < 3) return;
 
    var _sum = 0;
    for (var i = 0; i < array_length(_act); i++) _sum += power_of(_act[i]);
    var _avg = _sum / array_length(_act);
 
    var _lead = _act[0];
    for (var i = 1; i < array_length(_act); i++)
        if (power_of(_act[i]) > power_of(_lead)) _lead = _act[i];
 
    if (power_of(_lead) < _avg * COALITION_TRIGGER) return;
 
    var _others = [];
    for (var i = 0; i < array_length(_act); i++)
        if (_act[i] != _lead) array_push(_others, _act[i]);
 
    for (var i = 0; i < array_length(_others); i++) {
        queue_bond(_others[i], _lead, -0.18);
        queue_mood(_others[i], 0.10);
    }
    for (var i = 0; i < array_length(_others); i++)
        for (var j = i + 1; j < array_length(_others); j++)
            queue_bond(_others[i], _others[j], 0.14);
 
    if (_lead == ME) add_log("The others are speaking of you behind closed doors.");
    else add_log("A coalition forms against " + factions[_lead].name + ".");
}


// Rivals aid allies who are in trouble, which is how alliances come to
// feel like relationships rather than defence bonuses.
rival_aid = function(_i, _t) {
    factions[_i].treasury -= COST_AID;
    factions[_t].unrest = max(0, factions[_t].unrest - 8);
    queue("aided", _i, _t);
    add_log(factions[_i].name + " sends grain to " + factions[_t].name + ".");
}
 
rival_bind = function(_i, _t) {
    queue("bound", _i, _t);
    add_log(factions[_i].name + " and " + factions[_t].name + " swear a pact.");
}
 
rival_poison = function(_i, _a, _b) {
    queue_bond(_a, _b, -0.40);
    queue_mood(_a, 0.20);
    queue_mood(_b, 0.20);
    add_log(factions[_i].name + " sets " + factions[_a].name
          + " against " + factions[_b].name + ".");
}
 
// Does faction _i share an enemy with faction _t? Shared enemies are the
// single most reliable reason two powers find each other agreeable.
shares_enemy = function(_i, _t) {
    for (var j = 0; j < N; j++) {
        if (j == _i || j == _t || !is_active(j)) continue;
        if (bonds[_i][j] < WAR_THRESHOLD && bonds[_t][j] < WAR_THRESHOLD) return true;
    }
    return false;
}
 
// One rival, one action. Scores every option it could take and picks the
// best, with noise so it is never perfectly predictable. Targets are
// drawn from EVERYONE, which is why most of this lands between rivals.
//
// v8 adds two options, and they are the ones that make the world feel
// inhabited rather than reactive: a rival can commit to something that
// will not resolve for months, and a rival can interfere in a commitment
// it is not party to.
rival_act = function(_i) {
    var _f = factions[_i];
    if (!is_active(_i)) return false;

    var _best_score = 0.48;      // do-nothing threshold: quiet years exist
    var _best = undefined;

    var _hos = clamp((_f.hostility + 1) * 0.5, 0, 1);   // 0..1
    var _warlike  = (_f.temper == "warlike")  ? 1.45 : 1.0;
    var _scheming = (_f.temper == "schemer")  ? 1.55 : 1.0;
    var _kind     = (_f.temper == "diplomat") ? 1.55 : 1.0;

    for (var t = 0; t < N; t++) {
        if (t == _i || !is_active(t)) continue;

        // ---- ATTACK ----
        // A SOFTER THRESHOLD IS NOT ENOUGH, and I checked before shipping
        // this: a defender's army collapses faster than any relaxed gate
        // opens. Beaten to 49 troops against a need of 53, then 23 against
        // 36. They can never qualify, at any sane factor.
        //
        // So a deep grudge does not lower the bar, it IGNORES it. A kingdom
        // that has been marched on three times comes anyway, at odds it
        // knows are bad, because that is what "they will not stop" means.
		
        var _gr = grudge_of(_i, t);
        var _need = defensive_strength(t) * 0.9;
        var _desperate = (_gr >= 1.00);
        if (_f.treasury >= COST_ATTACK && (_f.army > _need || _desperate)) {
            var _s = _hos * _warlike * 1.30;
 
            // BOND IS NOW CONTINUOUS. Warm relations should make you safe
            // because the appetite is low, not because a hard veto catches
            // it at the last moment. At +0.35 this is 0.09 and they simply
            // never come; at +0.20 it is 0.48 and they occasionally do; at
            // 0.00 it is unchanged; at -0.30 it is 1.78 and they are eager.
            // This also replaces the old flat 1.5x below WAR_THRESHOLD --
            // the ramp already covers a feud, and doing both double-counted.
            _s *= clamp(1.0 - bonds[_i][t] * 2.6, 0.02, 1.8);
 
            if (factions[t].unrest > 55) _s *= 1.35;   // kick them while down
            _s *= (1.0 + _gr * 1.30);                  // and remember
 
            // A GRUDGE STILL PUNCHES THROUGH. At _gr = 1.0 that is 2.3x,
            // which beats the bond damping at any moderate bond -- so if
            // you keep invading someone you are on paper friendly with,
            // they still come for you. That was the whole point of grudges
            // and the ramp above must not quietly undo it.
            if (bonds[_i][t] > ALLY_THRESHOLD && _gr < GRUDGE_HARD) _s = 0;
 
            // ONE HOST ON YOU PER MONTH. Two rivals independently picking
            // you in the same month is not a story, it is a coin flip that
            // ends the run, and neither of them knew about the other. The
            // second one waits until next month, by which point it can see
            // what the first one's war did to your army.
            if (t == ME) {
                for (var w = 0; w < array_length(rival_battles); w++)
                    if (rival_battles[w].b == ME) _s = 0;
            }
 
            // TWO MONTHS OF GRACE. Long enough to read the tutorial and
            // make one plan before anyone tests you. Rivals still fight
            // each other in months 1 and 2, so the world is not asleep.
            if (t == ME && year <= 2) _s = 0;
 
            _s *= (0.7 + random(0.6));
            if (_s > _best_score) { _best_score = _s; _best = ["attack", t, -1]; }
        }
		
		// NOTE the changed ally check: a strong enough grudge now overrides the
		// "not your ally" veto. Being attacked by an ally SHOULD be able to turn
		// into a war, and previously a positive bond made you permanently safe from
		// someone you were actively invading.

        // ---- BIND ----
        if (bonds[_i][t] > WAR_THRESHOLD && bonds[_i][t] < 0.10
            && grudge_of(_i, t) < GRUDGE_HARD) {
            var _s = (1.25 - _hos * 0.7) * _kind * 0.92;
            if (shares_enemy(_i, t)) _s *= 2.1;                // the classic reason
            // shelter under the strong -- but not under the fist that is
            // hitting you. Attacking someone makes you stronger, so without
            // this check violence reads as protection.
            if (power_of(t) > power_of(_i) * 1.2 && grudge_of(_i, t) < 0.20)
                _s *= 1.5;
            for (var g = 0; g < N; g++) {
                if (g == _i || g == t || !is_active(g)) continue;
                if (power_of(g) > power_of(_i) * 1.5) { _s *= 1.5; break; }
            }
            _s *= (0.7 + random(0.6));
            if (_s > _best_score) { _best_score = _s; _best = ["bind", t, -1]; }
        }
		// NOTE the loop also now skips `t` itself. Previously a strong t triggered
		// the "someone out there is dangerous" multiplier for binding with t, which
		// double-counted the same kingdom as both threat and shelter.

        // ---- AID a friend in trouble ----
        if (bonds[_i][t] > 0.15 && _f.treasury >= COST_AID
            && factions[t].unrest > 25) {
            var _s = (0.5 + factions[t].unrest / 80) * _kind * 1.3 * (0.7 + random(0.6));
            if (_s > _best_score) { _best_score = _s; _best = ["aid", t, -1]; }
        }

        // ---- SWEAR AN OATH: something that will not resolve for months --
        // A bind is instant and cheap. An oath is slower, stronger and
        // PUBLIC, which means the whole board gets months to work on it.
        // A rival taking that risk is a rival with a plan.
        if (!oath_exists(_i, t)) {
            var _grt = grudge_of(_i, t);
 
            // a pact, for the same reasons they would bind, but committed
            if (bonds[_i][t] > -0.45 && _grt < GRUDGE_HARD) {
                var _s = (1.05 - _hos * 0.55) * _kind * 0.98;
                if (shares_enemy(_i, t)) _s *= 2.0;
                if (power_of(t) > power_of(_i) * 1.2 && _grt < 0.20) _s *= 1.45;
                _s *= (0.7 + random(0.6));
                if (_s > _best_score) { _best_score = _s; _best = ["oath_pact", t, -1]; }
            }
 
            // a siege: war declared in advance, and the RIGHT move for a
            // kingdom too weak to march. A siege is a vow, not an army, so
            // once the grudge is real the strength test does not apply at
            // all. It also goes on the shared board, which means a doomed
            // siege sworn by a beaten neighbour is visible to everyone and
            // can be leaned on. That is better drama than silence.
            var _sneed = defensive_strength(t) * 0.75;
            if (_f.treasury >= COST_ATTACK && bonds[_i][t] < 0.05
                && (_f.army > _sneed || _grt >= GRUDGE_HARD)) {
                var _s = _hos * _warlike * 1.18;
                if (bonds[_i][t] < WAR_THRESHOLD) _s *= 1.4;
                if (factions[t].unrest > 50) _s *= 1.3;
                _s *= (1.0 + _grt * 1.10);
                _s *= (0.7 + random(0.6));
                if (_s > _best_score) { _best_score = _s; _best = ["oath_siege", t, -1]; }
            }
        }

    // ---- POISON two others (never involving itself) ----
    for (var a = 0; a < N; a++) {
        if (a == _i || !is_active(a)) continue;
        for (var b = a + 1; b < N; b++) {
            if (b == _i || !is_active(b)) continue;
            if (bonds[a][b] < WAR_THRESHOLD) continue;         // already enemies
            var _s = _scheming * 0.62;
            if (power_of(a) > power_of(_i) && power_of(b) > power_of(_i)) _s *= 1.8;
            if (bonds[a][b] > ALLY_THRESHOLD) _s *= 1.4;       // break up a pact
 
            // THE RETALIATION. If either party wronged them, isolating that
            // party is the move. Weighted by the grudge, so it is a response
            // and not a habit.
            var _ga = grudge_of(_i, a);
            var _gb = grudge_of(_i, b);
            var _gm = max(_ga, _gb);
            if (_gm > 0.20) _s *= (1.0 + _gm * 1.60);
 
            _s *= (0.7 + random(0.6));
            if (_s > _best_score) { _best_score = _s; _best = ["poison", a, b]; }
        }
    }

    // ---- LEAN ON SOMEBODY ELSE'S OATH ----
    // The branch that makes rival-vs-rival consequences weigh as much as
    // yours: they are not only acting on kingdoms now, they are acting on
    // each other's unresolved plans, and on yours.
    for (var c = 0; c < array_length(board); c++) {
        var _o = board[c];
        if (_o.a == _i || _o.b == _i) continue;
        var _s = _scheming * 0.68;
        if (oath_threatens(_i, _o)) _s *= 1.95;
        if (_o.months_left <= 1)    _s *= 1.35;   // last chance to spoil it
        if (_o.p_seal > 0.60)       _s *= 1.25;   // worth spoiling
        if (_o.p_seal < 0.25)       _s *= 0.55;   // already dying, save the effort
        _s *= (0.7 + random(0.6));
        if (_s > _best_score) { _best_score = _s; _best = ["lean", c, -1]; }
    }

    // ---- LEVY ----
    if (_f.treasury >= COST_PER_LEVY * 3 && _f.army < sustainable_army(_i)) {
        var _s = (0.5 + _hos) * _warlike * 0.9 * (0.7 + random(0.6));
        if (_s > _best_score) { _best_score = _s; _best = ["levy", -1, -1]; }
    }

    if (_best == undefined) return false;

    switch (_best[0]) {
        case "attack":
            _f.treasury -= COST_ATTACK;
            array_push(rival_battles, { a: _i, b: _best[1] });
        break;
        case "bind":   rival_bind(_i, _best[1]); break;
        case "aid":    rival_aid(_i, _best[1]);  break;
        case "poison": rival_poison(_i, _best[1], _best[2]); break;

        case "oath_pact":
            var _ax = "X";
            if (_f.temper == "warlike") _ax = "Y";
            rival_oath(_i, _best[1], "pact", _ax, 0.55 + random(0.3), 3);
        break;

        case "oath_siege":
            _f.treasury -= COST_ATTACK;
            rival_oath(_i, _best[1], "siege", "Y", 0.6 + random(0.35), 2);
        break;

        case "lean":
            rival_lean(_i, board[_best[1]]);
        break;

        case "levy":
            var _n = min(4, floor(_f.treasury / COST_PER_LEVY));
            _f.army += _n;
            _f.treasury -= _n * COST_PER_LEVY;
        break;
    }
    return true;
	}
}

 
#endregion

// ============================================================
// year_economy -- extracted from the old Step event.
//
// This used to live inline in Step. apply_resolution() needs to call it,
// so it has to be a function. (I referenced year_economy() in the phases
// file without ever writing it -- this is that missing piece.)
// ============================================================
year_economy = function() {
for (var i = 0; i < N; i++) {
            var _f = factions[i];
            if (!_f.alive) continue;
 
            // vassals pay tribute and seethe
            if (_f.vassal_of != -1) {
                var _lord = factions[_f.vassal_of];
                if (_lord.alive) {
                    _lord.treasury += TRIBUTE_PER_VASSAL + _f.holds * INCOME_PER_HOLD * 0.5;
                    _lord.unrest += 3;
                    if (_lord.unrest > REBEL_UNREST && random(1) < 0.25) {
                        _f.vassal_of = -1;
                        _f.holds = 1;
                        _f.army = 4;
                        _lord.holds = max(1, _lord.holds - 1);
                        queue_mood(i, 0.5);
                        queue_bond(i, _lord.id, -0.5);
                        add_log(_f.name + " throws off " + _lord.name + "'s yoke!");
                        if (_lord.id == ME) {
                            push_event("rebellion", _f.name + " rises",
                                "Your unrest has been read as weakness. " + _f.leader
                              + " has thrown off the yoke and taken a holding back.",
                                [ { label: "Crush it (costs 4 levies)", act: "crush",  target: i, cost: 0 },
                                  { label: "Let them go",              act: "let_go", target: i, cost: 0 } ]);
                        }
                    }
                } else {
                    _f.vassal_of = -1; _f.holds = 1; _f.army = 4;
                    add_log(_f.name + " is masterless once more.");
                }
                continue;
            }
 
             _f.treasury += _f.holds * INCOME_PER_HOLD;
            var _up = _f.army * UPKEEP_PER_ARMY;
            if (_f.treasury >= _up) _f.treasury -= _up;
            else {
                _f.treasury = 0;
                _f.unrest += UNREST_UNPAID;
                unrest_note(i, "unpaid levies", UNREST_UNPAID);
                _f.army = floor(_f.army * 0.85);
                if (i == ME) add_log("You cannot pay the levies. Some desert.");
            }
 
            // (2) occupied land never settles
            var _occ = max(0, _f.holds - START_HOLDINGS);
            if (_occ > 0) {
                _f.unrest += _occ * UNREST_PER_OCCUPIED;
                unrest_note(i, "occupied land", _occ * UNREST_PER_OCCUPIED);
            }
 
            // (6) conscription: an army your land cannot support breeds resentment
            var _over = _f.army - sustainable_army(i);
            if (_over > 0) {
                _f.unrest += _over * CONSCRIPTION_UNREST;
                unrest_note(i, "conscription", _over * CONSCRIPTION_UNREST);
            }
 
            var _at_war = false;
            for (var j = 0; j < N; j++)
                if (j != i && is_active(j) && bonds[i][j] < WAR_THRESHOLD) _at_war = true;
 
            if (_at_war) queue_mood(i, 0.12);
            else {
                _f.unrest -= UNREST_PEACE_DECAY;
                unrest_note(i, "a quiet month", -UNREST_PEACE_DECAY);
                queue("peace_year", i);
            }
 
            var _allies = 0;
            for (var j = 0; j < N; j++)
                if (j != i && is_active(j) && bonds[i][j] > ALLY_THRESHOLD) _allies++;
            if (_allies > 0) {
                _f.unrest -= _allies * 3;
                unrest_note(i, (_allies == 1) ? "an ally" : string(_allies) + " allies",
                            -_allies * 3);
            }
            _f.unrest = max(0, _f.unrest);
 
			// ...and at the very TOP of year_economy, before the `for` loop:
			//
			unrest_why = [];
			//
			// Fresh every month, or the line grows forever.
 
            // (4) civil war, not deletion
            if (_f.unrest >= UNREST_MAX) {
                _f.army = floor(_f.army * 0.5);
                _f.unrest = CIVIL_WAR_UNREST;
                _f.holds--;
                add_log(_f.name + " tears itself apart in civil war.");
                if (i == ME) {
                    push_event("collapse", "Eigenstate turns on itself",
                        "The cost of your reign has come due. A holding is lost to "
                      + "disorder and half the host has gone home.");
                } else {
                    push_event("collapse", _f.name + " tears itself apart",
                        _f.name + " is consumed by civil war. Whatever it wanted, "
                      + "it wants nothing now.");
                }
                if (_f.holds <= 0) {
                    var _best = -1;
                    for (var j = 0; j < N; j++) {
                        if (j == i || !is_active(j)) continue;
                        if (_best == -1 || power_of(j) > power_of(_best)) _best = j;
                    }
                    if (_best != -1) make_vassal(i, _best);
                    else {
                        _f.alive = false;
                        if (i == ME) {
                            game_over = true;
                            ending = "EIGENSTATE IS NO MORE. Month " + string(year) + ".";
                        }
                    }
                }
            }
        }
}


// ============================================================
// PHASES, PLAN QUEUE AND EVENTS  (appended -- must come AFTER the
// original setup above, because these reference factions and add_log)
// ============================================================

// "plan" | "resolving" | "events"
phase = "plan";

plan = [];              // intentions queued this year, not yet executed
event_queue = [];       // cards awaiting the player
event_current = undefined;
event_pick = 0;

last_request = "";      // which endpoint the pending reply belongs to
pending_scouts = [];    // scouts queued from this year's plan
rival_battles  = [];    // attacks rivals INTEND; settled by measurement
audience_of    = -1;    // which court you are standing in, -1 = none
audience_page = "root";     // "root" | "ask"
audience_pick  = 0;
audience_opts  = [];
audience_line  = "";    // what they just said to you

plan_cost = function() {
    var _c = 0;
    for (var i = 0; i < array_length(plan); i++) _c += plan[i].cost;
    return _c;
}

plan_room = function() {
    return actions_left - plan_cost();
}

plan_add = function(_verb, _a, _b, _cost = 1) {
    if (_cost > 0 && plan_room() < _cost) {
        add_log("No more resolve this month.");
        return false;
    }
    array_push(plan, { verb: _verb, a: _a, b: _b, cost: _cost });
    return true;
}

plan_undo = function() {
    if (array_length(plan) == 0) return;
    var _p = plan[array_length(plan) - 1];
    array_pop(plan);
    add_log("You reconsider: " + _p.verb + " withdrawn.");
}

plan_label = function(_p) {
    if (_p.verb == "oath") {
        return "Oath: " + oath_kind_of(_p.kind).label + " w/ " + factions[_p.a].name
             + " (" + string(_p.span) + "mo, " + oath_axis_of(_p.axis).label + ")";
    }
    if (_p.verb == "lean") {
        var _w = "break";
        if (_p.amount > 0) _w = "back";
        return string_upper(string_copy(_w, 1, 1)) + string_copy(_w, 2, 99)
             + " the " + _p.shown;
    }
    var _t = string_upper(string_copy(_p.verb, 1, 1)) + string_copy(_p.verb, 2, 99);
    if (_p.b != -1 && _p.b != undefined)
        return _t + " " + factions[_p.a].name + " / " + factions[_p.b].name;
    return _t + " " + factions[_p.a].name;
}

/// @desc What this queued action costs and what it does, in words.
plan_effect = function(_p) {
    switch (_p.verb) {
        case "attack":
            return string(COST_ATTACK) + "g, 1 act.  they harden, the bond turns";
        case "aid":
            return string(COST_AID) + "g, 1 act.  they soften, and owe you";
        case "bind":
            return "1 act.  closer to you, and less room for anyone else";
        case "espy":
            return "1 act.  fresh word from their court";
        case "levy":
            return string(COST_PER_LEVY) + "g, free.  more men";
        case "poison":
            return "1 act.  sets " + factions[_p.a].name + " against "
                 + factions[_p.b].name;
        case "broker":
            return "1 act.  patches " + factions[_p.a].name + " and "
                 + factions[_p.b].name;
        case "oath":
            return "1 act.  resolves in " + string(_p.span)
                 + "mo, and everyone can push on it";
        case "lean":
            return "1 act.  moves the odds now, and they will notice";
    }
    return "1 act.";
}


push_event = function(_kind, _title, _body, _choices) {
    array_push(event_queue, {
        kind: _kind, title: _title, body: _body,
        choices: (_choices == undefined) ? [] : _choices
    });
}

// One illustration per event TYPE. Uncomment each case as you draw it;
// until then the card draws a labelled placeholder at the right size.
event_art = function(_kind) {
    // uncomment each line as you draw that vignette
    if (_kind == "battle")    return spr_vig_battle;
    if (_kind == "binding")   return spr_vig_binding;
    if (_kind == "collapse")  return spr_vig_collapse;
    if (_kind == "rebellion") return spr_vig_rebellion;
    if (_kind == "coalition") return spr_vig_coalition;
    if (_kind == "quiet")     return spr_vig_quiet;
    return -1;   // -1 means "draw the placeholder frame"
}

// ============================================================
// LEADERS: generated from real quantum bits
//
// /newgame returns 16 uniform bits per kingdom, measured from a plain
// H-register. Deliberately uniform rather than read off the world state,
// because appearance should not correlate with mood -- otherwise every
// hostile kingdom ends up wearing the same hat.
//
// Bit budget per kingdom:
//   0-2  title      3-5  name stem     6-8  name ending
//   9-10 hair      11-12 outfit       13   build      14-15 hall
// ============================================================

// read _n bits starting at _from as an integer
bits_val = function(_s, _from, _n) {
    var _v = 0;
    for (var i = 0; i < _n; i++) {
        _v = _v << 1;
        if (string_char_at(_s, _from + i + 1) == "1") _v += 1;
    }
    return _v;
}

TITLES  = ["Queen","King","Archon","Warden","Elder","Margrave","Doge","Hierarch"];
STEMS   = ["Ver","Sel","Mav","Pel","Cor","Tha","Ryn","Ost"];
ENDINGS = ["rin","dan","esh","ick","oth","ael","ur","is"];

TIER_NAMES   = ["common", "martial", "courtly", "regal"];
GENDER_NAMES = ["king", "queen"];
BUILD_NAMES  = ["slender", "stocky"];
SKIN_NAMES   = ["fair", "tan", "brown", "deep"];

make_leader = function(_i, _bits) {
    var _f = factions[_i];
    var _gender = bits_val(_bits, 15, 1);   // 0 = king-presenting, 1 = queen-presenting

    _f.gender  = _gender;
    _f.title   = TITLES[bits_val(_bits, 0, 3)];
    _f.leader  = _f.title + " " + STEMS[bits_val(_bits, 3, 3)]
                                + ENDINGS[bits_val(_bits, 6, 3)];

    // tier drives hall + outfit so they can never mismatch; hair and build
    // stay independent for cross-cutting variance
    _f.tier      = bits_val(_bits, 9, 2);
    _f.outfit_v  = 0
    _f.hair      = bits_val(_bits, 12, 2);
    _f.build     = bits_val(_bits, 14, 1);
    _f.hall      = _f.tier;

    // skin has no bit left to measure from -- plain random, same fallback
    // pattern as temper's schemer/diplomat split
    _f.skin      = irandom(3);
	_f.face_type = irandom(2);
	
    _f.head      = GENDER_NAMES[_gender] + "_" + BUILD_NAMES[_f.build]
                                          + "_" + SKIN_NAMES[_f.skin];
    _f.outfit    = TIER_NAMES[_f.tier] + "_" + string(_f.outfit_v);
    _f.traits    = _bits;
	
	_f.crown = TIER_NAMES[_f.tier] + "_" + GENDER_NAMES[_gender];

}

blink_timer = random_range(2, 5);
blink_hold  = 0;
BLINK_DURATION = 0.12;

talk_timer  = 0;
talk_anim_t = 0;
TALK_DURATION = 0.8;
TALK_FPS = 8;
last_audience_line = "";

face_eyes_spr = function(_i) {
    var _f = factions[_i];
    return asset_get_index("spr_eyes_" + GENDER_NAMES[_f.gender] + "_" + string(_f.face_type));
}

face_mouth_spr = function(_i) {
    var _f = factions[_i];
    return asset_get_index("spr_mouth_" + GENDER_NAMES[_f.gender] + "_" + string(_f.face_type));
}

face_eyes_frame = function(_i) {
    if (blink_hold > 0) return 4;           // blink is now frame 4, not 5
    return min(expression_of(_i), 3);        // hostile (3) and seething (4) now the same, frame 3
}

face_mouth_frame = function(_i) {
    var _e = min(expression_of(_i), 3);   // hostile (3) and seething (4) share
    if (talk_timer > 0) {
        var _cycle = floor(talk_anim_t * TALK_FPS) mod 3;
        if (_e >= 3) return 7 + _cycle;   // angry talk
        return 4 + _cycle;                 // calm talk
    }
    return _e;
}

face_nose_sprite = function(_i) {
    return asset_get_index("spr_nose_" + SKIN_NAMES[factions[_i].skin]);
}

// Expression is NOT generated -- it is read from the live qubit every
// frame, so a leader visibly hardens across a run as their state rotates.
// This is the cheapest way to make an invisible number land emotionally.
expression_of = function(_i) {
    var _h = factions[_i].hostility;
    if (_h >  0.55) return 4;   // seething
    if (_h >  0.20) return 3;   // hostile
    if (_h > -0.20) return 2;   // guarded
    if (_h > -0.55) return 1;   // civil
    return 0;                   // warm
}

// Portrait sprites, assigned as you draw them. Until then the audience
// screen draws the layer stack as labelled placeholder boxes so the
// composition is already correct.
HALL_NAMES = ["common", "martial", "courtly", "regal"];

portrait_sprite = function(_layer, _index) {
    if (_layer == "hall") return asset_get_index("spr_hall_" + HALL_NAMES[_index]);
    if (_layer == "head") return asset_get_index("spr_" + string(_index));
	if (_layer == "crown") return asset_get_index("spr_crown_" + string(_index));
    // if (_layer == "build")  return asset_get_index("spr_build_" + string(_index));
    if (_layer == "outfit") return asset_get_index("spr_outfit_" + string(_index));
    // if (_layer == "hair")   return asset_get_index("spr_hair_" + string(_index));
    // if (_layer == "face")   return asset_get_index("spr_face_" + string(_index));
    return -1;
}


// ============================================================
// WHAT THEY SAY TO YOU
//
// Chosen from the live quantum state: their hostility band, how much of
// themselves is left (independence), and the measured correlation between
// their qubit and yours. Same leader, different year, different greeting.
// ============================================================

audience_greeting = function(_i) {
    var _f = factions[_i];
    var _b = bonds[ME][_i];
    var _h = _f.hostility;

    // a kingdom that has dissolved into its bonds talks like it
    if (_f.independence < 0.40) {
        if (_b > ALLY_THRESHOLD)
            return "\"We hardly know where you end and we begin. Ask, and it is "
                 + "already given.\"";
        return "\"We are pulled in so many directions that we scarcely have a "
             + "position of our own. Say what you want.\"";
    }

    if (_b < WAR_THRESHOLD) {
        if (_h > 0.55) return "\"You have ash on your boots and the gall to stand "
                            + "in my hall. Speak, and be brief.\"";
        return "\"There is nothing between us that words will fix. But speak.\"";
    }

    if (_b > ALLY_THRESHOLD) {
        if (_h > 0.20) return "\"Friend. I am in no mood, but for you I will sit.\"";
        return "\"Eigenstate is welcome here, and known here. Sit.\"";
    }

    // neutral
    if (_h > 0.55) return "\"I am told you came to talk. I am told a great many "
                        + "things.\"";
    if (_h > 0.20) return "\"Make it worth the walk.\"";
    if (_h < -0.55) return "\"A quiet month and a visitor. Sit, then.\"";
    return "\"We have no quarrel and no bond. Which did you come to change?\"";
}

/// @desc The open oath between two courts, or undefined. The board holds
/// every unresolved commitment in the world, so this is how a host knows
/// they have something pending with someone.
gossip_oath_between = function(_a, _b) {
    for (var i = 0; i < array_length(board); i++) {
        var _o = board[i];
        if ((_o.a == _a && _o.b == _b) || (_o.a == _b && _o.b == _a))
            return _o;
    }
    return undefined;
}


/// @desc Which fact this host would reach for about this target.
///
/// ORDER IS THE DESIGN. Specific beats general, and the top of the list is
/// the thing that would actually be on their mind. A ruler with an open siege
/// against someone does not lead with "they keep to themselves".
gossip_kind = function(_i, _t) {
    if (factions[_t].vassal_of == _i)              return "mine";
    if (factions[_t].vassal_of == ME)              return "yours";
    if (gossip_oath_between(_i, _t) != undefined)  return "oath";
    if (standing[_i][_t] == "WAR")                 return "war";
 
    var _b = bonds[_i][_t];
    if (_b > ALLY_THRESHOLD)                       return "allied";
    if (_b < WAR_THRESHOLD)                        return "hostile";
 
    var _l = lev_matrix[_i][_t];
    if (_l >  0.35)                                return "sway_over";
    if (_l < -0.35)                                return "sway_under";
 
    if (factions[_t].hostility > 0.4)              return "arming";
    return "indifferent";
}
 
/// @desc The frank clause, in the host's voice. No framing, no quote marks:
/// the frames add those, so a clause can be hedged or stated plainly without
/// being written twice.
gossip_clause = function(_i, _t) {
    var _n = factions[_t].name;
    var _k = gossip_kind(_i, _t);
 
    switch (_k) {
        case "mine":
            return _n + " answers to me now. What of it";
        case "yours":
            return _n + " wears your collar, and you know it better than I do";
        case "oath":
            var _o = gossip_oath_between(_i, _t);
            return "there is a thing sworn between us and " + _n
                 + ", and " + string(_o.months_left)
                 + " months left for the world to spoil it";
        case "war":
            return _n + " and I are past talking. It is soldiers now";
        case "allied":
            return "we are bound to " + _n + ". Do not ask me to choose";
        case "hostile":
            return _n + " is a wound that has not closed";
        case "sway_over":
            return _n + " does as I suggest. They have not noticed yet";
        case "sway_under":
            return _n + " has more of my court than I would like";
        case "arming":
            return _n + " is arming. Everyone can see it but them";
        default:
            return _n + " keeps to themselves. For now";
    }
}
 
/// @desc SWORN framing gets intent: a vassal tells you what they will do,
/// which is information you cannot get any other way.
gossip_intent = function(_i, _t) {
    var _k = gossip_kind(_i, _t);
    if (_k == "war" || _k == "hostile")
        return " We will march on them the month you say so.";
    if (_k == "allied" || _k == "mine")
        return " I will hold them steady while you look elsewhere.";
    if (_k == "sway_under")
        return " Say the word and I will cut them out of my council.";
    return " We watch them. That is all, unless you want more.";
}
 
/// @desc WARM framing gets a second real fact. Their mood is the one thing a
/// friendly court can hand you that you might not have scouted.
gossip_trend = function(_i, _t) {
    var _h = factions[_t].hostility;
    if (_h > 0.55) return " And they are past reasoning with. Watch your border.";
    if (_h > 0.20) return " Their court has hardened this season.";
    if (_h < -0.35) return " Softer than they were, whatever they say in public.";
    return " Nothing has changed there in a while.";
}
 
/// @desc CIVIL framing. Hedges the clause into something true but useless,
/// keyed on the kind so it is not the same shrug every time.
gossip_hedge = function(_i, _t) {
    var _n = factions[_t].name;
    switch (gossip_kind(_i, _t)) {
        case "mine":
        case "yours":
            return "\"" + _n + "'s loyalties are a matter of record. Look it up.\"";
        case "oath":
            return "\"We have business with " + _n + ". It is not concluded, "
                 + "and it is not yours.\"";
        case "war":
        case "hostile":
            return "\"There is history between us and " + _n + ". I will not "
                 + "rehearse it for a guest.\"";
        case "allied":
            return "\"We speak with " + _n + ". Everyone speaks with someone.\"";
        case "sway_over":
        case "sway_under":
            return "\"" + _n + " and I understand each other well enough.\"";
        case "arming":
            return "\"" + _n + " is doing what any sensible court would do.\"";
        default:
            return "\"" + _n + "? I have no view worth your time.\"";
    }
}
 
/// @desc COLD framing. Names the target so it does not read as a bug, and
/// tells you nothing. Temper picks the flavour of the refusal, which is what
/// makes the four rivals feel like different people for one `if`.
gossip_deflect = function(_i, _t) {
    var _n = factions[_t].name;
    switch (factions[_i].temper) {
        case "warlike":
            return "\"You come into my hall and ask about " + _n + ".\" "
                 + "A short laugh. \"Ask them about me.\"";
        case "schemer":
            return "\"" + _n + ".\" A pause just long enough to be an answer. "
                 + "\"What a curious thing to want to know.\"";
        default:
            return "\"" + _n + " is well, I believe. You would have to ask "
                 + "someone who tells you things.\"";
    }
}

audience_gossip = function(_i, _t) {
    var _cand = gossip_candour(_i);
 
    if (_cand == "cold" || _cand == "refuse")
        return gossip_deflect(_i, _t);
 
    if (_cand == "civil")
        return gossip_hedge(_i, _t);
 
    // sworn and warm both state the fact plainly, then differ in what they
    // add: intent from someone who serves you, a second fact from a friend
    var _line = "\"" + gossip_clause(_i, _t) + ".\"";
    if (_cand == "sworn") return _line + gossip_intent(_i, _t);
    return _line + gossip_trend(_i, _t);
}


/// @desc How honest is this court with YOU? Drives both the wording and
/// whether the answer gets written into known_bonds.
///
/// The WAR case never fires in practice because audience_open refuses to let
/// you in during a war, but it is here so the function is total and so a
/// future "parley under flag of truce" has somewhere to land.
gossip_candour = function(_i) {
    if (factions[_i].vassal_of == ME)        return "sworn";
    if (standing[ME][_i] == "WAR")           return "refuse";
    var _b = bonds[ME][_i];
    if (_b > ALLY_THRESHOLD)                 return "warm";
    if (_b < WAR_THRESHOLD)                  return "cold";
    return "civil";
}
 
/// @desc What they say when asked about you. PLACEHOLDER -- step 3 makes the
/// cold branch flatter you while the bond you can see says otherwise, which
/// is the moment the whole system teaches itself.
audience_gossip_self = function(_i, _cand) {
    var _b = bonds[ME][_i];
 
    switch (_cand) {
        case "sworn":
            return "\"I serve. You did not leave me much choice, and I have "
                 + "stopped minding.\"";
 
        case "warm":
            if (_b > 0.55)
                return "\"There is no one I would rather have at my back. "
                     + "Say what you need.\"";
            return "\"We have done well by each other. Long may it hold.\"";
 
        case "civil":
            // true and unhelpful, which is what neutrality sounds like
            if (factions[_i].temper == "schemer")
                return "\"You are useful to me. I assume the reverse is also "
                     + "true.\"";
            return "\"We have no quarrel. In this world that is not nothing.\"";
 
        default:
            // COLD. Deliberately warmer than the number the player can see.
            switch (factions[_i].temper) {
                case "warlike":
                    return "\"You?\" They hold your eye a moment too long. "
                         + "\"We have no quarrel worth naming.\"";
                case "schemer":
                    return "\"I think of you often, and always kindly.\" "
                         + "The smile arrives a beat late.";
                default:
                    return "\"You are welcome here whenever you come.\" "
                         + "Nobody in the hall moves.";
            }
    }
}
 


// ============================================================
// THE AUDIENCE
//
// What you can DO here depends on the relationship, which is the whole
// point: the same visit offers different levers depending on the measured
// correlation between your qubit and theirs, and on who is stronger.
// ============================================================

audience_open = function(_i) {
    if (_i == ME) return;
	if (!variable_struct_exists(factions[_i], "head")) {
		add_log("That court has not been measured into being yet.");
		return;
	}
    if (!factions[_i].alive) { add_log("There is no court left to visit."); return; }
    if (factions[_i].vassal_of == ME) {
        // your own vassal cannot refuse you
    } else if (standing[ME][_i] == "WAR") {
        add_log(factions[_i].name + " will not receive you. There is a war on.");
        return;
    }
    audience_of = _i;
    audience_page = "root";        // <-- ADD, before audience_build
    audience_pick = 0;
    audience_line = audience_greeting(_i);
    audience_opts = audience_build(_i);

    // duck the kingdom theme and cross into the throne room theme, rather
    // than hard-cutting one track for the other
    if (bgm != undefined && audio_is_playing(bgm)) audio_sound_gain(bgm, 0, 600);
	if (throne_bgm == undefined || !audio_is_playing(throne_bgm)) {
		throne_bgm = audio_play_sound(snd_throne_bgm, 1, true);
		audio_sound_gain(throne_bgm, 0, 0);
	}
	audio_sound_gain(throne_bgm, 0.8, 600);
}

/// The single exit path out of an audience -- so the music always comes
/// back up, however the audience ends (ESC, or the "aud_leave" option).
audience_close = function() {
	if (jbit != "") jester_bit_abort();
    audience_of = -1;
    if (throne_bgm != undefined && audio_is_playing(throne_bgm))
        audio_sound_gain(throne_bgm, 0, 600);
    if (bgm != undefined && audio_is_playing(bgm)) audio_sound_gain(bgm, 0.8, 600);
}


audience_build = function(_i) {
    if (audience_page == "ask") return audience_build_ask(_i);
 
    var _o = [];
    var _b = bonds[ME][_i];
    var _stronger = power_of(ME) > power_of(_i) * 1.25;
    var _vassal = (factions[_i].vassal_of == ME);
 
    // Asking around is always available and always free. Information is the
    // reason to come here even when you want nothing.
    array_push(_o, { label: "Ask about...", act: "aud_ask_open",
                     target: -1, cost: 0, points: 0 });
 
    if (_b > 0.10 || _vassal)
        array_push(_o, { label: "Propose a pact", act: "aud_pact",
                         target: _i, cost: 0, points: 1 });
 
    if (_stronger)
        array_push(_o, { label: "Demand tribute", act: "aud_tribute",
                         target: _i, cost: 0, points: 1 });
 
    if (_b < 0.10)
        array_push(_o, { label: "Make amends", act: "aud_amends",
                         target: _i, cost: 40, points: 0 });
 
    array_push(_o, { label: "Threaten them", act: "aud_threaten",
                     target: _i, cost: 0, points: 0 });
 
    array_push(_o, { label: "Ask about their jester", act: "aud_jester",
                     target: _i, cost: 0, points: 0 });
 
    array_push(_o, { label: "Take your leave", act: "aud_leave",
                     target: _i, cost: 0, points: 0 });
    return _o;
}


/// @desc The ask page. Everyone but the host, plus yourself.
///
/// YOURSELF IS THE POINT. "What do you think of me" is the only question in
/// the game whose answer you can check -- you can see bonds[ME][_i] on your
/// own screen -- so it is the one place the game can be unreliable and have
/// the player notice. Step 3 leans on that.
///
/// The labels carry the state, so the player can see at a glance which pairs
/// they have nothing on. That turns the fog into a to-do list rather than a
/// confusion, which is the whole risk with step 1.
audience_build_ask = function(_i) {
    var _o = [];

    for (var t = 0; t < N; t++) {
        if (t == _i) continue;
        if (t != ME && !factions[t].alive) continue;

        var _lbl = (t == ME) ? "...me" : "..." + factions[t].name;
        if (t != ME && known_state(_i, t) == "stale") _lbl += "   (old news)";

        array_push(_o, { label: _lbl, act: "gossip", target: t,
                         cost: 0, points: 0 });
    }

    array_push(_o, { label: "Never mind", act: "aud_ask_close",
                     target: -1, cost: 0, points: 0 });
    return _o;
}
 
// Durations, seconds. Tuned so the whole thing is about four seconds before
// the player has to do anything, which is long enough to register as
// deliberate and short enough not to be annoying on a second viewing.
JBIT_USHER  = 0.85;
JBIT_ENTER  = 1.10;
JBIT_BOOM   = 0.60;
JBIT_RETURN = 0.90;
JESTER_GAIN = 1.8;      // snd_jester is mastered quiet, so lift it
 
JESTER_SCALE = 2;       // 32x32 art at 2x inside the 320x180 illustration
JESTER_FPS   = 4;
JBIT_STOP_KEY = vk_space;
JBIT_STOP_KEY_NAME = "SPACE";
 

 
/// @desc Start the bit. Fades the music rather than cutting it, because a
/// hard cut on the same frame as the option being chosen reads as a glitch.
jester_bit_begin = function() {
    jbit   = "usher";
    jbit_t = 0;
    // fade rather than cut: a hard stop on the same frame as the menu
    // selection reads as a glitch. 0.8 is the level audience_open() sets.
    if (throne_bgm != undefined && audio_is_playing(throne_bgm))
        audio_sound_gain(throne_bgm, 0, JBIT_USHER * 1000);
}

/// @desc Kill everything the bit owns and put the audio back. Safe to call
/// at any time, including when the bit is not running.
jester_bit_abort = function() {
    jbit   = "";
    jbit_t = 0;
    if (jester_music != -1) {
        if (audio_is_playing(jester_music)) audio_stop_sound(jester_music);
        jester_music = -1;
    }
    // audience_close() fades throne_bgm out straight after this, so all we
    // owe it is a handle in a sane state. If the player is staying in the
    // court, FIX 4's "return" case is what brings it back up.
    if (throne_bgm != undefined && audio_is_playing(throne_bgm))
        audio_sound_gain(throne_bgm, 0.8, 300);
}
 
/// @desc How far the ruler is pushed off frame, 0 = in place, 1 = fully out.
/// One function so Draw never has to know the state names.
jester_ruler_out = function() {
    switch (jbit) {
        case "usher":  return clamp(jbit_t / JBIT_USHER, 0, 1);
        case "enter":  return 1;
        case "dance":  return 1;
        case "boom":   return 1;
        case "return": return 1 - clamp(jbit_t / JBIT_RETURN, 0, 1);
    }
    return 0;
}
 

// Outcomes differ by relationship and by who is stronger. Nothing here is
// a flat success roll.
audience_do = function(_ch) {
    var _i = audience_of;
    var _f = factions[_i];
    var _me = factions[ME];
    var _b = bonds[ME][_i];
	

    // an action that costs a point must be affordable
    if (_ch.points > 0 && plan_room() < _ch.points) {
        audience_line = "\"You have nothing left to spend this month, ane both "
                      + "know it.\"";
        return;
    }
    if (_ch.cost > 0 && _me.treasury < _ch.cost) {
        audience_line = "\"You came empty-handed. That is its own kind of answer.\"";
        return;
    }

    switch (_ch.act) {
        case "aud_ask_open":
            audience_page = "ask";
            audience_pick = 0;
            audience_opts = audience_build(_i);
            audience_line = "\"Ask, then.\"";
        break;
 
        case "aud_ask_close":
            audience_page = "root";
            audience_pick = 0;
            audience_opts = audience_build(_i);
        break;
 
        case "gossip":
            var _t = _ch.target;
            var _cand = gossip_candour(_i);
 
            if (_t == ME) {
                // their opinion of YOU. Own bucket in step 3; for now say
                // the true thing, because you can already see it anyway.
                audience_line = "\"You?\" " + audience_gossip_self(_i, _cand);
            } else {
                audience_line = audience_gossip(_i, _t);
            }
 
            if (_cand == "sworn" || _cand == "warm") {
                if (_t != ME) {
                    gossip_learn(_i, _t, bonds[_i][_t]);
                    add_log(_f.leader + " on " + factions[_t].name + ": "
                          + bond_word(bonds[_i][_t]));
                }
            } else if (_cand == "civil") {
                add_log(_f.leader + " was polite and told you nothing firm.");
            } else {
                add_log(_f.leader + " told you nothing you can use.");
            }
 
            // stay on the page: work the whole court in one visit
            audience_opts = audience_build(_i);
        break;

        case "aud_pact":
            // a pact offered from strength is cheap; from weakness, costly
            plan_add("bind", _i, -1);
            if (_b > ALLY_THRESHOLD)
                audience_line = "\"Then it is already done. We will send the words "
                              + "after you.\"";
            else
                audience_line = "\"We will consider it. Loudly, and where others "
                              + "can hear.\"";
        break;

        case "aud_tribute":
            if (_f.hostility > 0.40) {
                // a furious kingdom refuses and hardens
                queue_mood(_i, 0.25);
                queue_bond(ME, _i, -0.30);
                audience_line = "\"Tribute. From us. Get out of my hall.\"";
                add_log(_f.name + " refuses tribute, and remembers being asked.");
            } else {
                _me.treasury += 45;
                _f.treasury = max(0, _f.treasury - 45);
                queue_bond(ME, _i, -0.20);
                queue_mood(_i, 0.15);
                // BUG: I first wrote this as plan_add() followed by
                // array_pop(), which consumes nothing at all -- plan_cost()
                // just goes back to what it was. Spend the point directly.
                actions_left -= _ch.points;
                audience_line = "\"Take it. Take it and go.\"";
                add_log("You extract 45 gold from " + _f.name + ".");
            }
        break;

        case "aud_amends":
            _me.treasury -= _ch.cost;
            queue_bond(ME, _i, +0.30);
            queue_mood(_i, -0.20);
            audience_line = (_b < WAR_THRESHOLD)
                ? "\"This does not undo it. But it is not nothing.\""
                : "\"Then let it be forgotten. Mostly.\"";
        break;

        case "aud_threaten":
            queue_mood(_i, 0.30);
            queue_bond(ME, _i, -0.25);
            if (power_of(ME) > power_of(_i) * 1.4) {
                _f.unrest += 8;
                audience_line = "\"...I hear you.\"";
                add_log(_f.name + " is cowed, and resentful.");
            } else {
                queue_mood(_i, 0.20);
                audience_line = "\"You are not strong enough to say that here.\"";
                add_log(_f.name + " is not impressed. It will cost you.");
            }
        break;
		
		case "aud_poison":
            if (plan_add("poison", _i, _ch.target)) {
                audience_line = "\"" + factions[_ch.target].name
                              + ".\" A long pause. \"Say more.\"";
                audience_opts = audience_build(_i);
            }
        break;
		
		case "aud_broker":
            if (plan_add("broker", _i, _ch.target)) {
                audience_line = "\"You would have us shake hands with "
                              + factions[_ch.target].name + ".\" "
                              + "They do not say no.";
                audience_opts = audience_build(_i);
            }
        break;
		
		case "aud_jester":
            audience_line = jester_reply(_i, _b);
            jester_bit_begin();
        break;

        case "aud_leave":
            audience_close();
            return;
    }

    // the room reacts, so the options change as the conversation goes
    audience_opts = audience_build(_i);
    audience_pick = min(audience_pick, array_length(audience_opts) - 1);
}


apply_choice = function(_ch) {
    var _me = factions[ME];
    switch (_ch.act) {
        case "vengeance":
            queue_bond(ME, _ch.target, -0.30);
            queue_mood(ME, 0.25);
            _me.unrest = max(0, _me.unrest - 6);   // the court likes resolve
            add_log("You swear it before the court. " + factions[_ch.target].name
                  + " will answer for this.");
        break;

        case "pay_off":
            if (_me.treasury >= _ch.cost) {
                _me.treasury -= _ch.cost;
                queue_bond(ME, _ch.target, +0.35);
                queue_mood(_ch.target, -0.30);
                add_log("Gold changes hands. " + factions[_ch.target].name
                      + " withdraws, for now.");
            } else {
                _me.unrest += 8;
                add_log("You promise gold you do not have. Word gets out.");
            }
        break;

        case "nothing":
            _me.unrest += 6;
            add_log("You say nothing. The silence is noted, and not kindly.");
        break;

        case "stand_firm":
            queue_mood(ME, 0.20);
            _me.unrest = max(0, _me.unrest - 8);
            add_log("You refuse to be spoken about. The court stiffens.");
        break;

        case "appease":
            if (_me.treasury >= _ch.cost) {
                _me.treasury -= _ch.cost;
                for (var j = 1; j < N; j++)
                    if (is_active(j)) queue_bond(ME, j, +0.18);
                add_log("You buy goodwill by the cartload. It works, and it costs you.");
            } else {
                add_log("There is not enough in the treasury to buy silence.");
            }
        break;

        case "crush":
            _me.army = max(0, _me.army - 4);
            factions[_ch.target].unrest += 20;
            add_log("You put the rising down. It is remembered.");
        break;

        case "let_go":
            factions[_ch.target].vassal_of = -1;
            factions[_ch.target].holds = 1;
            factions[_ch.target].army = 3;
            _me.unrest = max(0, _me.unrest - 10);
            add_log(factions[_ch.target].name + " goes free. Your court exhales.");
        break;
    }
}

jester_reply = function(_i, _b) {
    var _f = factions[_i];
    if (_f.vassal_of == ME)
        return "\"He is yours now too, I suppose. He was the only thing I did "
             + "not mind losing.\"";
    if (_b < WAR_THRESHOLD)
        return "\"You march on my borders and you ask after my FOOL?\" A "
             + "pause. \"...He does an impression of you. Shall I send for "
             + "him?\"";
    if (_b < -0.08)
        return "\"He is the only one at this table who says what he means. "
             + "Take from that what you like.\"";
    if (_b > 0.45)
        return "\"Ah! Sit, sit. He has a new one about the tax collectors.\" "
             + "The bells start before you can decline.";
    if (_f.temper == "warlike")
        return "\"I had him whipped for a joke about the cavalry. He made the "
             + "same joke the next day.\" Almost fondly.";
    if (_f.temper == "schemer")
        return "\"My jester?\" A very long look. \"Which of my enemies sent "
             + "you to ask about my jester?\"";
    return "\"He is the only advisor I trust, on the grounds that he is the "
         + "only one who has nothing to gain.\"";
}


compute_ending = function() {
    game_over = true;
    // fade the music on the ending. Use the HANDLE returned by
    // audio_play_sound, not the asset -- the asset form applies to every
    // instance of that sound and will bite you the moment you add a second.
    if (bgm != undefined && audio_is_playing(bgm)) audio_sound_gain(bgm, 0, 2500);

    var _free = 0; var _vassals = 0; var _allies = 0;
    for (var j = 1; j < N; j++) {
        if (!factions[j].alive) continue;
        if (factions[j].vassal_of == ME) _vassals++;
        else if (factions[j].vassal_of == -1) {
            _free++;
            if (bonds[ME][j] > ALLY_THRESHOLD) _allies++;
        }
    }

    var _ind = factions[ME].independence;

    // entanglement magnitude ignores sign: love and hatred consume you
    // equally. Which one did it decides which ending you earned.
    var _pos = 0; var _neg = 0;
    for (var j = 1; j < N; j++) {
        if (bonds[ME][j] > 0) _pos += bonds[ME][j];
        else _neg -= bonds[ME][j];
    }

    if (_free == 0) {
        ending_key = "HEGEMON";
        ending = "HEGEMON. No free power remains but Eigenstate.";
    } else if (_ind < 0.45) {
        if (_pos >= _neg) {
            ending_key = "DISSOLVED";
            ending = "DISSOLVED. You survived, but you are barely yourself.";
        } else {
            ending_key = "CONSUMED";
            ending = "CONSUMED. Your hatreds outlived your kingdom's soul.";
        }
    } else if (_vassals >= 1) {
        ending_key = "EMPIRE";
        ending = "EMPIRE. Eigenstate rules, and is resented for it.";
    } else if (_allies >= 2) {
        ending_key = "CONCERT";
        ending = "CONCERT OF POWERS. Bound on every side, and standing.";
    } else if (_allies == 0) {
        ending_key = "QUIET";
        ending = "THE QUIET KING. Two years alone, and still your own.";
    } else {
        ending_key = "ENDURED";
        ending = "ENDURED. Eigenstate saw two years.";
    }
 
    // The collection lives in the settings ini, so it survives a quit and
    // is the one thing in the game that carries between runs. Seven
    // endings is small enough that "3 of 7" reads as a gap to close
    // rather than a grind.
    ini_open(SETTINGS_FILE);
    ini_write_real("endings", ending_key, 1);
    endings_seen = [];
    for (var e = 0; e < array_length(ENDING_KEYS); e++)
        if (ini_read_real("endings", ENDING_KEYS[e], 0) > 0)
            array_push(endings_seen, ENDING_KEYS[e]);
    ini_close();
}


/// @desc One card at the midpoint. No new state: this reads the world and
/// says what it sees, which is exactly what the player has been unable to do
/// for themselves until this patch.
halfway_reckoning = function() {
    var _strong = -1, _hater = -1, _best = -1, _worst = 1;
    for (var j = 1; j < N; j++) {
        if (!is_active(j)) continue;
        if (_strong == -1 || power_of(j) > power_of(_strong)) _strong = j;
        if (bonds[ME][j] < _worst) { _worst = bonds[ME][j]; _hater = j; }
        if (bonds[ME][j] > _best)  { _best = bonds[ME][j]; }
    }
 
    var _b = "Twelve months gone, twelve to come.\n\n";
 
    if (_strong != -1 && _strong != ME)
        _b += factions[_strong].name + " is the strongest power that is not you. ";
    if (_hater != -1 && _worst < WAR_THRESHOLD)
        _b += factions[_hater].name + " will not forgive you. ";
    else if (_hater != -1)
        _b += "Nobody hates you yet. ";
 
    var _open = array_length(board);
    if (_open > 0)
        _b += string(_open) + (_open == 1 ? " oath stands unresolved."
                                          : " oaths stand unresolved.");
    else
        _b += "Nothing is sworn anywhere, which is its own kind of answer.";
 
    _b += "\n\nUnrest " + string(round(factions[ME].unrest))
        + ", " + string(factions[ME].holds) + " holdings, "
        + string(factions[ME].army) + " under arms.";
 
    push_event("reckoning", "The reckoning at midwinter", _b);
}


// ---- battle resolution, now driven by the joint measurement ----------
// Four outcomes instead of win/lose. Which ones are even reachable is
// shaped by the bond between the two kingdoms: at a strongly positive
// bond "decisive" is essentially impossible, because correlated qubits
// collapse together so both sides commit and both bleed.
apply_battle = function(_a, _d, _outcome) {
    var _vs_player = (_d == ME);
    var _by_player = (_a == ME);
    var _att = factions[_a];
    var _def = factions[_d];
    _att.unrest += UNREST_PER_BATTLE;
    _def.unrest += UNREST_PER_BATTLE;
    queue("attacked", _a, _d);
    grudge_add(_d, _a, GRUDGE_ATTACK);
    grudge_add(_a, _d, GRUDGE_ATTACK * 0.25);

    var _dval = defensive_strength(_d);
    _att.army -= max(1, floor(_att.army * MARCH_ATTRITION + _dval * 0.12));

    switch (_outcome) {
        case "decisive":
            _def.army -= max(1, floor(_def.army * 0.45));
            _def.unrest += UNREST_PER_LOSS + UNREST_PER_HOLD_LOST;
            if (_def.holds > 0) { _def.holds--; _att.holds++; }
            if (_vs_player) {
                push_event("battle", factions[_a].leader + " is in your fields",
                    _att.name + " broke your line and took a holding. Your captains "
                  + "are waiting in the hall for an answer.",
                    [ { label: "Swear vengeance",             act: "vengeance", target: _a, cost: 0 },
                      { label: "Buy peace (60 gold)",         act: "pay_off",   target: _a, cost: 60 },
                      { label: "Say nothing. Let them wonder", act: "nothing",  target: _a, cost: 0 } ]);
            } else {
                push_event("battle", _att.name + " breaks " + _def.name,
                    _def.name + " gives ground and a holding changes hands. Their line simply folded.");
            }
            if (_def.holds <= 0 && _def.vassal_of == -1) make_vassal(_d, _a);
        break;

        case "costly":
            _def.army -= max(1, floor(_def.army * 0.40));
            _att.army -= max(1, floor(_att.army * 0.30));
            _att.unrest += UNREST_PER_LOSS;
            _def.unrest += UNREST_PER_LOSS;
            if (_def.holds > 0) { _def.holds--; _att.holds++; }
            if (_vs_player) {
                push_event("battle", "A field of ruin",
                    _att.name + " took ground from you and paid for every yard of it. "
                  + "Both hosts are wrecked. Neither court is celebrating.",
                    [ { label: "Swear vengeance",     act: "vengeance", target: _a, cost: 0 },
                      { label: "Sue for terms (40 gold)", act: "pay_off", target: _a, cost: 40 } ]);
            } else if (_by_player) {
                push_event("battle", "A field of ruin",
                    "You took ground from " + _def.name + " and paid for every yard of it. "
                  + (bonds[ME][_d] > 0
                     ? "You were bound to them, and a bond does not break cleanly."
                     : "Both hosts are wrecked."));
            } else {
                push_event("battle", "A field of ruin",
                    _att.name + " takes ground from " + _def.name + ", and pays for every yard of it.");
            }
            if (_def.holds <= 0 && _def.vassal_of == -1) make_vassal(_d, _a);
        break;

        case "repelled":
            _att.army -= max(1, floor(_att.army * 0.25));
            _att.unrest += UNREST_PER_LOSS;
            if (_vs_player)
                push_event("battle", "Your border holds",
                    _att.name + " came and was thrown back with nothing. For now.");
            else
                push_event("battle", _def.name + " holds",
                    _att.name + " is thrown back from the border with nothing to show for it.");
        break;

        default: // stalemate
            _att.unrest += 4;
            _def.unrest += 4;
            push_event("battle", "Nothing was decided",
                "The hosts faced each other across bad ground and neither committed. Both armies go home hungry.");
        break;
    }
    _att.army = max(0, _att.army);
    _def.army = max(0, _def.army);
}



// ---- pass 1: your actions, then rivals decide what they intend -------
apply_resolution = function(_answers) {
    // initiative decides who moves at all this year
    var _acts = [];
    for (var i = 0; i < array_length(_answers); i++)
        if (_answers[i].kind == "initiative") _acts = _answers[i].acts;

    // --- your queued intentions ---
    var _battle_i = 0;
    for (var i = 0; i < array_length(plan); i++) {
        var _p = plan[i];
        switch (_p.verb) {
            case "attack":
                var _found = undefined;
                var _seen = 0;
                for (var j = 0; j < array_length(_answers); j++) {
                    if (_answers[j].kind != "battle") continue;
                    if (_seen == _battle_i) { _found = _answers[j]; break; }
                    _seen++;
                }
                _battle_i++;
                if (factions[ME].treasury >= COST_ATTACK && _found != undefined) {
                    factions[ME].treasury -= COST_ATTACK;
                    apply_battle(ME, _p.a, _found.outcome);
                } else add_log("The march could not be paid for.");
            break;
            case "aid":
                if (factions[ME].treasury >= COST_AID) {
                    factions[ME].treasury -= COST_AID;
                    queue("aided", ME, _p.a);
                    factions[_p.a].unrest = max(0, factions[_p.a].unrest - 8);
                    add_log("You send aid to " + factions[_p.a].name + ".");
                }
            break;
            case "bind":
                queue("bound", ME, _p.a);
                add_log("You bind Eigenstate to " + factions[_p.a].name + ".");
            break;

            // ---- v8: an oath is NOT resolved here. It is opened, and the
            //      server will measure it when its span runs out. ----
            case "oath":
                run_sworn++;
                array_push(new_commitments, {
                    kind: _p.kind, a: ME, b: _p.a, axis: _p.axis,
                    strength: _p.strength, span: _p.span, owner: ME
                });
                add_log("You swear a " + oath_kind_of(_p.kind).label + " with "
                      + factions[_p.a].name + ". It will be tested in "
                      + string(_p.span) + " months.");
            break;

            case "lean":
                array_push(new_pressures, {
                    uid: _p.uid, by: ME, axis: _p.axis,
                    amount: _p.amount, on: _p.on
                });
                if (_p.amount < 0) add_log("You set to work undoing the " + _p.shown + ".");
                else               add_log("You put your weight behind the " + _p.shown + ".");
            break;

            case "poison":
                queue_bond(_p.a, _p.b, -0.45);
                queue_mood(_p.a, 0.25); queue_mood(_p.b, 0.25);
                add_log("You whisper, and " + factions[_p.a].name
                      + " begins to look sideways at " + factions[_p.b].name + ".");
            break;
            case "broker":
                queue("brokered", _p.a, _p.b);
                add_log("You broker peace between " + factions[_p.a].name
                      + " and " + factions[_p.b].name + ".");
            break;
            case "espy":
                array_push(pending_scouts, _p.a);
            break;
            case "levy":
                var _c = COST_PER_LEVY * LEVY_BATCH;
                if (factions[ME].treasury >= _c) {
                    factions[ME].treasury -= _c;
                    factions[ME].army += LEVY_BATCH;
                    add_log("You raise " + string(LEVY_BATCH) + " levies.");
                }
            break;
        }
        if (game_over) break;
    }
    plan = [];

    // --- rivals act. Only those the measurement said would move; those
    //     bits are correlated, so allies tend to stir in the same year.
    //     Their ATTACKS are only queued here, never resolved. ---
    rival_battles = [];
    if (!game_over) {
        for (var i = 1; i < N; i++) {
            if (!is_active(i)) continue;
            if (i < array_length(_acts) && !_acts[i]) continue;
            var _n = (factions[i].independence >= INDEP_ACTION_FLOOR) ? 2 : 1;
            while (_n > 0) {
                if (!rival_act(i)) break;
                _n--;
                if (game_over) break;
            }
            if (game_over) break;
        }
    }

    // --- if any rival intends war, go and MEASURE those outcomes too ---
    if (!game_over && array_length(rival_battles) > 0) {
        var _qs = [];
        for (var i = 0; i < array_length(rival_battles); i++) {
            var _rb = rival_battles[i];
            array_push(_qs, {
                kind: "battle",
                a: _rb.a,
                b: _rb.b,
                attacker_strength: factions[_rb.a].army,
                defender_strength: defensive_strength(_rb.b)
            });
        }
        post("http://localhost:5055/resolve",
             json_stringify({ year: year, questions: _qs }), "resolve2");
        return;
    }

    finish_year();
}



// ---- pass 2: the rivals' wars, decided the same way yours were -------
apply_rival_battles = function(_answers) {
    var _k = 0;
    for (var i = 0; i < array_length(_answers); i++) {
        if (_answers[i].kind != "battle") continue;
        if (_k >= array_length(rival_battles)) break;
        var _rb = rival_battles[_k];
        _k++;
        if (!factions[_rb.a].alive || !factions[_rb.b].alive) continue;
        apply_battle(_rb.a, _rb.b, _answers[i].outcome);
        if (game_over) break;
    }
    rival_battles = [];
    finish_year();
}


// ---- the classical tail of the year ----------------------------------
finish_year = function() {
    if (game_over) return;

    year_economy();
 
    var _ul = unrest_line();
    if (_ul != "") add_log(_ul);
 
    if (game_over) return;

    // note whether a coalition formed, so it can be surfaced as a card
    var _was_targeted = false;
    var _before = 0;
    for (var j = 1; j < N; j++) if (is_active(j)) _before += bonds[ME][j];

    coalition_step();

    var _after = 0;
    for (var j = 1; j < N; j++) if (is_active(j)) _after += bonds[ME][j];
    if (_after < _before - 0.25) _was_targeted = true;

    if (_was_targeted) {
        push_event("coalition", "They are talking without you",
            "Word reaches you that the other courts have been corresponding. "
          + "Not one letter was addressed to Eigenstate.",
            [ { label: "Buy one of them off (70 gold)", act: "appease",    target: -1, cost: 70 },
              { label: "Let them talk",                 act: "stand_firm", target: -1, cost: 0 } ]);
    }

    // v8: oaths sworn and pressure applied this month travel with the turn.
    // The server opens the new ones, ages the old ones, and measures any
    // that have run out of span.
    post("/turn", { year: year, events: queued,
                          commitments: new_commitments,
                          pressures: new_pressures }, "turn");
    new_commitments = [];
    new_pressures   = [];
}


// The board as the server last reported it. Every open commitment in the
// world, whoever swore it. This is the shared object all three of the new
// systems hang off: you can read it, rivals can read it, and both of you
// can push on the same entries.
board   = [];

// ---- run summary -----------------------------------------------------
// Counted as the run happens, not reconstructed at the end, because half
// of it is not recoverable from the final state. A bond that dropped 0.9
// in one month and crept back up leaves no trace in the closing numbers,
// and that month is usually the story of the run.
ENDING_KEYS = ["HEGEMON", "EMPIRE", "CONCERT", "ENDURED",
               "QUIET", "DISSOLVED", "CONSUMED"];
ending_key   = "";
endings_seen = [];
 
run_sworn   = 0;      // oaths you put your name to
run_held    = 0;      // ...that sealed
run_turned  = 0;      // ...that half-kept, or that the other side captured
run_broken  = 0;      // ...that came apart
run_hw      = 0;      // measurements that actually went to Moth hardware
run_worst_j = -1;     // who turned on you hardest
run_worst_d = 0;      // by how much, in a single month
run_worst_m = 0;      // and when


matured = [];          // what resolved last month, for the event cards

// Sworn / leaned this month, posted with /turn and then cleared.
new_commitments = [];
new_pressures   = [];

// An oath is a KIND (what it is trying to become), an AXIS (what kind of
// pressure it is made of) and a SPAN (how long the world gets to interfere
// with it before it is measured).
//
// The axes are not flavour. Each one is a rotation about a different axis
// of the qubit, and rotations about different axes do not commute, so:
//   force       swings the odds hardest, and cancels other force exactly
//   persuasion  does almost nothing to a kingdom that is undecided, and a
//               great deal to one that has already made up its mind
//   coercion    is weak alone and changes what force is worth
// Those three sentences are measured facts about the circuit, not balance
// numbers I picked. See the server's COMMITMENTS comment block.
OATH_KINDS = [
    { key: "pact",      label: "pact",      span: 3, axis: "X",
      hint: "bind them to you" },
    { key: "betrothal", label: "betrothal", span: 6, axis: "X",
      hint: "a long, deep tie" },
    { key: "siege",     label: "siege",     span: 2, axis: "Y",
      hint: "a war announced in advance" },
    { key: "embargo",   label: "embargo",   span: 4, axis: "Z",
      hint: "starve them slowly" }
];

OATH_AXES = [
    { key: "Y", label: "force",      hint: "swings the odds hardest, both ways" },
    { key: "X", label: "persuasion", hint: "works on the decided, not the undecided" },
    { key: "Z", label: "coercion",   hint: "weak alone; changes what force is worth" }
];

OATH_STRENGTHS = [0.3, 0.5, 0.75, 1.0];

// ---- oath builder sub-state (plan phase) ----
oath_mode   = false;
oath_target = -1;
oath_kind   = 0;
oath_axis   = 0;
oath_span   = 3;
oath_str    = 1;       // index into OATH_STRENGTHS
oath_field  = 0;       // 0 kind, 1 axis, 2 span, 3 weight

// ---- lean sub-state (plan phase) ----
lean_mode = false;
lean_pick = 0;
lean_dir  = 1;         // +1 feed it, -1 break it
lean_axis = 0;
lean_side = 1;         // 0 = lean on the party who swore it, 1 = the other

oath_kind_of = function(_key) {
    for (var i = 0; i < array_length(OATH_KINDS); i++)
        if (OATH_KINDS[i].key == _key) return OATH_KINDS[i];
    return OATH_KINDS[0];
}

oath_axis_of = function(_key) {
    for (var i = 0; i < array_length(OATH_AXES); i++)
        if (OATH_AXES[i].key == _key) return OATH_AXES[i];
    return OATH_AXES[0];
}

// Is there already an open oath between these two? One per pair, so the
// board stays legible and nobody can stack five pacts on one neighbour.
oath_exists = function(_a, _b) {
    for (var i = 0; i < array_length(board); i++) {
        var _o = board[i];
        if ((_o.a == _a && _o.b == _b) || (_o.a == _b && _o.b == _a)) return true;
    }
    for (var i = 0; i < array_length(new_commitments); i++) {
        var _c = new_commitments[i];
        if ((_c.a == _a && _c.b == _b) || (_c.a == _b && _c.b == _a)) return true;
    }
    return false;
}

oath_is_friendly = function(_o) {
    return (_o.kind == "pact" || _o.kind == "betrothal");
}

// Short board row: "pact  Coherre-Decohra  2mo"
oath_line = function(_o) {
    return oath_kind_of(_o.kind).label + " " + factions[_o.a].name
         + "-" + factions[_o.b].name;
}

oath_involves_me = function(_o) {
    return (_o.a == ME || _o.b == ME);
}

board_find_uid = function(_uid) {
    for (var i = 0; i < array_length(board); i++)
        if (board[i].uid == _uid) return board[i];
    return undefined;
}

// Would this oath, if it sealed, leave _i worse off? The rival AI's whole
// reason to interfere in something that is none of its business.
oath_threatens = function(_i, _o) {
    if (_o.a == _i || _o.b == _i) return false;
    if (oath_is_friendly(_o)) {
        // two others closing ranks. Worse the stronger they are together.
        var _them = power_of(_o.a) + power_of(_o.b);
        if (_them > power_of(_i) * 1.25) return true;
        if (oath_involves_me(_o)) return true;   // nobody likes the player
                                                  // making friends
        return false;
    }
    // a siege on somebody _i is bound to is _i's problem too
    if (bonds[_i][_o.b] > ALLY_THRESHOLD) return true;
    return false;
}

// ---- the player's two new plan verbs ----

plan_add_oath = function(_t) {
    if (plan_room() < 1) { add_log("No more resolve this month."); return false; }
    if (oath_exists(ME, _t)) {
        add_log("There is already an oath open with " + factions[_t].name + ".");
        return false;
    }
    array_push(plan, {
        verb: "oath", a: _t, b: -1, cost: 1,
        kind:     OATH_KINDS[oath_kind].key,
        axis:     OATH_AXES[oath_axis].key,
        span:     oath_span,
        strength: OATH_STRENGTHS[oath_str],
		axis:     OATH_KINDS[oath_kind].axis
	
    });
    return true;
}

plan_add_lean = function(_o, _dir, _axis_key, _side) {
    if (plan_room() < 1) { add_log("No more resolve this month."); return false; }
    var _on = _o.b;
    if (_side == 0) _on = _o.a;
    array_push(plan, {
        verb: "lean", a: -1, b: -1, cost: 1,
        uid: _o.uid, on: _on, axis: _axis_key,
        amount: _dir * 0.85,
        shown: oath_line(_o)
    });
    return true;
}

// ---- rivals swear and interfere too ----

rival_oath = function(_i, _t, _kind, _axis, _strength, _span) {
    array_push(new_commitments, {
        kind: _kind, a: _i, b: _t, axis: _axis,
        strength: _strength, span: _span, owner: _i
    });
    if (_kind == "siege") {
        add_log(factions[_i].name + " begins a siege of " + factions[_t].name
              + ". It will be decided in " + string(_span) + " months.");
    } else if (_kind == "embargo") {
        add_log(factions[_i].name + " closes its roads to " + factions[_t].name + ".");
    } else {
        add_log(factions[_i].name + " opens talks with " + factions[_t].name
              + ". Something is being drafted.");
    }
}

rival_lean = function(_i, _o) {
    // feed it if it suits them, break it if it does not
    var _dir = -1;
    if (!oath_threatens(_i, _o) && oath_is_friendly(_o) == false) _dir = 1;
    if (bonds[_i][_o.a] > ALLY_THRESHOLD && oath_is_friendly(_o)) _dir = 1;

    // schemers work by coercion, which is the axis that does nothing on its
    // own and changes what everything else is worth. Warlike powers just
    // shove.
    var _axis = "Y";
    if (factions[_i].temper == "schemer")  _axis = "Z";
    if (factions[_i].temper == "diplomat") _axis = "X";

    var _on = _o.b;
    if (random(1) < 0.4) _on = _o.a;

    array_push(new_pressures, {
        uid: _o.uid, by: _i, axis: _axis,
        amount: _dir * (0.55 + random(0.45)), on: _on
    });

    if (_dir < 0) {
        add_log(factions[_i].name + " works against the "
              + oath_kind_of(_o.kind).label + " between "
              + factions[_o.a].name + " and " + factions[_o.b].name + ".");
    } else {
        add_log(factions[_i].name + " quietly backs the "
              + oath_kind_of(_o.kind).label + " between "
              + factions[_o.a].name + " and " + factions[_o.b].name + ".");
    }
	
	if (oath_involves_me(_o)) {
        push_event("lean",
            factions[_i].name + " moves on your oath",
            factions[_i].leader + " has put weight behind an effort to "
          + ((_dir < 0) ? "break" : "shore up") + " the " + oath_line(_o)
          + ", leaning on " + factions[_on].name + " to do it.\n\n"
          + "Watch the odds on the board. They have already moved.");
    }
}

// ---- cards for what matured ----
// A commitment resolving is the most consequential thing that can happen in
// a month, so it gets a card rather than a log line.
push_matured_cards = function() {
    for (var i = 0; i < array_length(matured); i++) {
        var _m = matured[i];
		
		// run summary bookkeeping
        if (_m.a == ME || _m.b == ME) {
            if      (_m.outcome == "sealed") run_held++;
            else if (_m.outcome == "broken") run_broken++;
            else                             run_turned++;
        }
        if (variable_struct_exists(_m, "measured_on")
        &&  string_pos("moth", _m.measured_on) > 0) run_hw++;
		
        var _k = oath_kind_of(_m.kind).label;
        var _an = factions[_m.a].name;
        var _bn = factions[_m.b].name;
        var _mine = (_m.a == ME || _m.b == ME);

        if (_m.outcome == "sealed") {
            if (_mine) {
                push_event("binding", "The " + _k + " holds",
                    "What was sworn " + string(_m.matures - _m.sworn)
                  + " months ago has been tested and it held. " + _an + " and "
                  + _bn + " are bound by it now, whatever either of them has "
                  + "since come to feel.");
            } else {
                push_event("binding", _an + " and " + _bn + " are bound",
                    "Their " + _k + " held. Whatever they agreed months ago, "
                  + "they are agreed on it still, and you were not consulted.");
            }
        } else if (_m.outcome == "broken") {
            push_event("binding", "The " + _k + " collapses",
                "Too many hands were on it. The " + _k + " between " + _an
              + " and " + _bn + " has come apart, and both courts blame the "
              + "other for the waste.");
        } else if (_m.outcome == "hollow") {
            push_event("binding", "A one-sided " + _k,
                _an + " kept faith and " + _bn + " did not quite. The words "
              + "stand and mean less than they cost, and " + _bn + " knows it.");
        } else {
            push_event("binding", "The " + _k + " turns",
                _bn + " came out of it holding the better end. " + _an
              + " swore in good faith and paid for the privilege.");
        }
    }
    matured = [];
}


/// @desc Deterministic 0..1 from an integer. The sin-hash trick. Every
///       effect below uses it so nothing reshuffles between frames -- the
///       thing that makes cheap effects look cheap is when the "random"
///       parts crawl, and this is why they will not.
fx_hash = function(_n) {
    return frac(sin(_n * 12.9898 + 78.233) * 43758.5453);
}
 
/// @desc Slow sine offset in pixels. Use on any y coordinate that should
///       breathe. _hz is cycles per second, so 0.25 is one slow swell
///       every four seconds.
fx_bob = function(_hz, _amp, _phase = 0) {
    return sin(current_time / 1000 * _hz * 6.2831 + _phase) * _amp;
}
 
/// @desc Dim a colour toward black. Pair with fx_flicker() so a whole
///       screen breathes as one object rather than one element flickering
///       against a static background, which is what reads as cheap.
fx_dim = function(_col, _f) {
    return merge_colour(c_black, _col, clamp(_f, 0, 1));
}
 
/// @desc Candlelight as a 0..1 multiplier. Two sines at unrelated rates
///       so the eye cannot find the loop, plus an occasional guttering
///       dip, which is the part that actually sells it.
fx_flicker = function() {
    var _t = current_time / 1000;
    var _v = 0.90 + 0.055 * sin(_t * 7.3) + 0.035 * sin(_t * 17.1 + 1.7);
    if (fx_hash(floor(_t * 6)) > 0.955) _v -= 0.10;
    return clamp(_v, 0, 1);
}


// ---------------------------------------------------------------------
// FULL-SCREEN ATMOSPHERE
// ---------------------------------------------------------------------
 
/// @desc Drifting motes rising up the frame. n rectangles, no state.
fx_dust = function(_n, _col, _alpha, _speed) {
    var _t = current_time / 1000;
    draw_set_colour(_col);
    for (var d = 0; d < _n; d++) {
        var _x = fx_hash(d) * 640;
        var _y = (fx_hash(d + 91) * 360 + _t * _speed * (0.4 + fx_hash(d + 7))) mod 360;
        var _s = (fx_hash(d + 33) > 0.86) ? 2 : 1;
        draw_set_alpha(_alpha * (0.35 + fx_hash(d + 55) * 0.65));
        draw_rectangle(_x, _y, _x + _s - 1, _y + _s - 1, false);
    }
    draw_set_alpha(1);
}
 
/// @desc One pale line sweeping down the screen. _period is seconds per
///       pass. Keep the alpha under 0.04 or it stops being subliminal and
///       starts being a bug report.
fx_scanline = function(_period, _alpha) {
    var _y = (((current_time / 1000) / _period) mod 1) * 420 - 30;
    if (_y < -2 || _y > 360) return;
    draw_set_colour(c_white);
    draw_set_alpha(_alpha);
    draw_rectangle(0, _y, 640, _y + 1, false);
    draw_set_alpha(1);
}
 
/// @desc Vignette as 26 nested one-pixel frames, squared falloff. This is
///       what a vignette shader would buy you at 640x360, for 26 draw
///       calls and no GPU-specific failure mode.
fx_vignette = function(_str) {
    draw_set_colour(c_black);
    for (var v = 0; v < 26; v++) {
        var _f = 1 - v / 26;
        draw_set_alpha(_str * _f * _f);
        draw_rectangle(v, v, 639 - v, 359 - v, true);
    }
    draw_set_alpha(1);
}
 
/// @desc Film grain. The time bucket is the whole trick: it resamples
///       eight times a second instead of every frame, so it reads as film
///       rather than as television static.
fx_grain = function(_n, _alpha) {
    var _b = floor(current_time / 125) * 3.7;
    draw_set_colour(c_white);
    draw_set_alpha(_alpha);
    for (var g = 0; g < _n; g++) {
        var _x = floor(fx_hash(g + _b) * 640);
        var _y = floor(fx_hash(g + _b + 404) * 360);
        draw_rectangle(_x, _y, _x, _y, false);
    }
    draw_set_alpha(1);
}
 
/// @desc The cold half. A faint ruled grid over everything. At alpha 0.012
///       you cannot see it if you look for it, and the screen looks
///       measured if you do not.
fx_grid = function(_step, _col, _alpha) {
    draw_set_colour(_col);
    draw_set_alpha(_alpha);
    for (var gx = 0; gx < 640; gx += _step) draw_rectangle(gx, 0, gx, 359, false);
    for (var gy = 0; gy < 360; gy += _step) draw_rectangle(0, gy, 639, gy, false);
    draw_set_alpha(1);
}
 
/// @desc Five dots in a squashed orbit. The quantum motif, and the only
///       decoration in the game that means something. Squashed vertically
///       so it reads as a tilted ring rather than a circle, and dimmer on
///       the far side so it reads as depth.
fx_orbit = function(_cx, _cy, _r, _n, _col, _alpha, _speed) {
    var _t = current_time / 1000 * _speed;
    draw_set_colour(_col);
    for (var o = 0; o < _n; o++) {
        var _a = _t * 40 + o * (360 / _n);
        var _px = _cx + lengthdir_x(_r, _a);
        var _py = _cy + lengthdir_y(_r * 0.34, _a);
        draw_set_alpha(_alpha * (0.5 + 0.5 * dcos(_a)));
        draw_rectangle(_px - 1, _py - 1, _px + 1, _py + 1, false);
    }
    draw_set_alpha(1);
}
 
 
// ---------------------------------------------------------------------
// THE MEDIEVAL HALF
// ---------------------------------------------------------------------
 
/// @desc Parchment. A warm base, horizontal fibres, and age blotches, all
///       from fx_hash so the page does not crawl under the text.
fx_paper = function(_x, _y, _w, _h) {
    draw_set_alpha(1);
    draw_set_colour(make_colour_rgb(38, 33, 27));
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
 
    draw_set_colour(make_colour_rgb(58, 50, 40));
    for (var f = 0; f < 90; f++) {
        var _fy = _y + fx_hash(f + 11) * _h;
        var _fx = _x + fx_hash(f + 202) * _w * 0.7;
        var _fw = 12 + fx_hash(f + 303) * 70;
        draw_set_alpha(0.05 + fx_hash(f + 404) * 0.06);
        draw_rectangle(_fx, _fy, min(_x + _w, _fx + _fw), _fy, false);
    }
 
    draw_set_colour(make_colour_rgb(22, 18, 14));
    for (var b = 0; b < 22; b++) {
        var _bx = _x + fx_hash(b + 71) * _w;
        var _by = _y + fx_hash(b + 137) * _h;
        draw_set_alpha(0.04 + fx_hash(b + 313) * 0.05);
        draw_circle(_bx, _by, 5 + fx_hash(b + 251) * 16, false);
    }
    draw_set_alpha(1);
}
 
/// @desc A ruled divider with a diamond at the centre.
fx_rule = function(_x, _y, _w, _col) {
    draw_set_colour(_col);
    draw_set_alpha(0.50);
    draw_rectangle(_x, _y, _x + _w, _y, false);
    draw_set_alpha(1);
    var _mx = _x + _w / 2;
    draw_primitive_begin(pr_trianglelist);
    draw_vertex(_mx, _y - 4); draw_vertex(_mx + 4, _y); draw_vertex(_mx, _y + 4);
    draw_vertex(_mx, _y - 4); draw_vertex(_mx - 4, _y); draw_vertex(_mx, _y + 4);
    draw_primitive_end();
}
 
/// @desc Illuminated-manuscript corner bracket. _dir: 0 TL, 1 TR, 2 BL,
///       3 BR. The inner tick is what makes it read as decoration rather
///       than as a badly drawn border.
fx_corner = function(_x, _y, _len, _dir, _col, _alpha) {
    var _sx = (_dir == 1 || _dir == 3) ? -1 : 1;
    var _sy = (_dir == 2 || _dir == 3) ? -1 : 1;
    draw_set_colour(_col);
    draw_set_alpha(_alpha);
    draw_rectangle(_x, _y, _x + _len * _sx, _y, false);
    draw_rectangle(_x, _y, _x, _y + _len * _sy, false);
    draw_rectangle(_x + 4 * _sx, _y + 4 * _sy, _x + 9 * _sx, _y + 4 * _sy, false);
    draw_set_alpha(1);
}
 
/// @desc A wax seal. Three overlapping blobs so the edge is irregular,
///       then a stamp on top.
fx_seal = function(_x, _y, _r) {
    draw_set_colour(make_colour_rgb(122, 32, 38));
    draw_circle(_x, _y, _r, false);
    draw_set_alpha(0.85);
    draw_circle(_x - _r * 0.35, _y + _r * 0.30, _r * 0.72, false);
    draw_circle(_x + _r * 0.40, _y - _r * 0.18, _r * 0.62, false);
    draw_set_alpha(1);
    draw_set_colour(make_colour_rgb(168, 62, 66));
    draw_circle(_x, _y, _r * 0.62, true);
    draw_set_colour(make_colour_rgb(196, 96, 96));
    draw_rectangle(_x - 1, _y - 4, _x + 1, _y + 4, false);
    draw_rectangle(_x - 4, _y - 1, _x + 4, _y + 1, false);
}

// ---- kick off: rivals generated by a real quantum measurement ----
// Last, so every variable and function above already exists when the
// reply lands.
post("/newgame", {}, "newgame");
add_log("Measuring the world into being...");

bgm = audio_play_sound(snd_bgm, 1, true);   // 1 = priority, true = loop
audio_sound_gain(bgm, 0.8, 0);              // half volume; music sits under UI

settings_apply();
