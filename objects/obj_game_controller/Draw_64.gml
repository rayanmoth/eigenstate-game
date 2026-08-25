// ============================================================
// DRAW GUI
//
// Rewritten so the layout is DERIVED, not hardcoded.
//
// The previous version placed panels at fixed pixel coordinates chosen
// for an assumed ~13px line height. fnt_body at size 20 actually has a
// line height of 29px, so five roster rows no longer fitted the 132px
// reserved for them, the top bar overlapped the roster rule, and the
// STANDING column ran out of the roster and into the detail panel.
//
// Now: ui_layout() measures the font and allocates the screen from that,
// and every column position comes from measuring the widest string that
// column will ever hold. Change the font size and the layout follows.
// ============================================================

// A scissor left set by any block below would clip the whole next frame to
// black. Clearing it here means the worst case is one bad frame rather than
// a dead screen.

if (overlay == "settings") {
    settings_panel_draw("UP/DOWN choose   LEFT/RIGHT change   ESC or P to close");
    exit;
}


if (overlay == "ledger") {
    draw_set_colour(make_colour_rgb(8, 10, 14));
    draw_rectangle(0, 0, 640, 360, false);
 
    var _lp  = ui_panel(12, 12, 616, 336, "THE LEDGER");
    var _llh = ui_line_h();
    ui_reserve(_lp, _llh + 6);
 
    var _view = ledger_view();
    
	// DERIVED, not guessed. 14 never fitted, so Step's clamp (which used the
    // same literal) stopped short and the oldest rows could not be reached.
    // The filter line below costs one line plus 4, so take that off first.
    var _page = max(1, floor((ui_room(_lp) - _llh - 4) / _llh));
    ledger_page_rows = _page;      // Step reads this for its scroll clamp
 
    // which slice, and what of
    ui_font("label");
    ui_text(_lp.x, _lp.cursor,
            string_upper(LEDGER_FILTERS[ledger_filter][0]),
            ui_col("quantum"), 200);
    ui_text_right(_lp.x + _lp.inner_w, _lp.cursor,
            (array_length(_view) == 0)
                ? "nothing yet"
                : string(ledger_scroll + 1) + "-"
                + string(min(array_length(_view), ledger_scroll + _page))
                + " of " + string(array_length(_view)),
            ui_col("faint"));
    _lp.cursor += _llh + 4;
    ui_font("body");
 
    if (array_length(_view) == 0) {
        ui_text(_lp.x, _lp.cursor, "Nothing under this heading yet.",
                ui_col("dim"), _lp.inner_w);
    }
 
    for (var i = ledger_scroll;
         i < min(array_length(_view), ledger_scroll + _page); i++) {
        if (ui_room(_lp) < _llh) break;
        var _e = _view[i];
 
        // COLOUR BY KIND. This is the difference between a record you can
        // scan and a wall of text: a war and a tax note should not look the
        // same weight.
        var _c = ui_col("text");
        if (_e.k == "war")   _c = ui_col("war");
        if (_e.k == "bond")  _c = ui_col("ally");
        if (_e.k == "oath")  _c = ui_col("quantum");
        if (_e.k == "gold")  _c = ui_col("faint");
        if (_e.k == "intel") _c = ui_col("dim");
 
        // the month, so it reads as a record rather than a stream
        ui_font("label");
        ui_text(_lp.x, _lp.cursor, "m" + string(_e.m), ui_col("faint"), 34);
        ui_font("body");
        ui_text(_lp.x + 38, _lp.cursor, _e.t, _c, _lp.inner_w - 38);
        _lp.cursor += _llh;
    }
 
    ui_font("label");
    ui_text(_lp.x, ui_footer_y(_lp),
            "UP/DOWN scroll    LEFT/RIGHT what to show    J or ESC close",
            ui_col("faint"), _lp.inner_w);
    ui_font("body");
    exit;
}

if (overlay == "observatory") {
    draw_set_colour(make_colour_rgb(8, 10, 14));
    draw_rectangle(0, 0, 640, 360, false);
    var _lh = ui_line_h();

    var _op = ui_panel(12, 10, 616, 20, "");
    ui_font("display");
    ui_text(_op.x, _op.cursor, "THE OBSERVATORY", ui_col("quantum"), 300);
    ui_font("body");
    ui_text_right(628, _op.cursor,
        string(N) + " qubits   depth " + string(q_depth)
        + "   " + string(q_gatecount) + " gates   "
        + string(q_shots) + " shots", ui_col("faint"));

    var _bp = ui_panel(12, 40, 300, 150, "BLOCH VECTORS");
    ui_font("label");
    ui_text(_bp.x, _bp.cursor, "KINGDOM        X      Y      Z    r", ui_col("faint"));
    ui_font("body");
    _bp.cursor += _lh;
    for (var i = 0; i < N; i++) {
        if (ui_room(_bp) < _lh) break;
        var _f = factions[i];
        var _col = (i == ME) ? ui_col("you") : ui_col("text");
        ui_text(_bp.x, _bp.cursor, _f.name, _col, string_width("Phasemark "));
        var _x0 = _bp.x + string_width("Phasemark  ");
        ui_num(_x0 + 34,  _bp.cursor, string_format(_f.bloch_x, 1, 2), ui_col("dim"));
        ui_num(_x0 + 74,  _bp.cursor, string_format(_f.bloch_y, 1, 2), ui_col("dim"));
        ui_num(_x0 + 114, _bp.cursor, string_format(_f.bloch_z, 1, 2), ui_col("text"));
        ui_num(_x0 + 150, _bp.cursor, string_format(_f.independence, 1, 2), ui_col("quantum"));
        _bp.cursor += _lh;
    }

    var _mp = ui_panel(324, 40, 304, 150, "WHAT YOU KNOW");
    for (var a = 0; a < N; a++) {
        for (var b = a + 1; b < N; b++) {
            if (ui_room(_mp) < _lh) break;
 
            // your own row is always known; for others take whichever
            // direction you have actually heard, preferring the fresher
            var _st_ab = known_state(a, b);
            var _st_ba = known_state(b, a);
            var _use   = a;
            var _st    = _st_ab;
            if (_st_ab == "unknown" && _st_ba != "unknown") { _use = b; _st = _st_ba; }
            else if (_st_ab == "stale" && _st_ba == "fresh") { _use = b; _st = _st_ba; }
            var _other = (_use == a) ? b : a;
 
            ui_text(_mp.x, _mp.cursor, string(a) + "-" + string(b),
                    ui_col("dim"), 30);
 
            if (_st == "unknown") {
                ui_text(_mp.x + 32, _mp.cursor, "--", ui_col("faint"), 46);
                ui_text(_mp.x + 84, _mp.cursor, "--", ui_col("faint"), 46);
            } else {
                var _c  = known_bonds[_use][_other];
                var _cc = ui_col("faint");
                if (_c > 0.25) _cc = ui_col("ally");
                else if (_c < -0.20) _cc = ui_col("war");
                if (_st == "stale") _cc = ui_col("dim");
 
                var _l = lev_matrix[a][b];
                ui_text(_mp.x + 32, _mp.cursor, string_format(_c, 1, 2), _cc, 46);
                ui_text(_mp.x + 84, _mp.cursor, string_format(_l, 1, 2),
                    abs(_l) > 0.25 ? ui_col("quantum") : ui_col("faint"), 46);
            }
 
            var _tag = factions[a].name + "/" + factions[b].name;
            if (_st == "stale") _tag += "  (old)";
            ui_text(_mp.x + 136, _mp.cursor, _tag, ui_col("faint"),
                    _mp.inner_w - 140);
            _mp.cursor += _lh;
        }
    }

    var _gp = ui_panel(12, 198, 616, 130, "QUANTUM OPERATIONS APPLIED LAST MONTH");
    for (var i = 0; i < array_length(q_gates); i++) {
        if (ui_room(_gp) < _lh) break;
        ui_text(_gp.x, _gp.cursor, q_gates[i], ui_col("dim"), _gp.inner_w);
        _gp.cursor += _lh;
    }
    if (array_length(q_gates) == 0)
        ui_text(_gp.x, _gp.cursor, "no operations yet", ui_col("faint"), _gp.inner_w);

    ui_font("label");
    ui_text(12, 306, "r is the Bloch vector length: how much a kingdom is "
          + "still its own", ui_col("faint"), 616);
    ui_text(12, 324, "Q or ESC to close", ui_col("faint"), 616);
    ui_font("body");
    exit;
}

if (overlay == "help") {
    draw_set_colour(make_colour_rgb(8, 10, 14));
    draw_rectangle(0, 0, 640, 360, false);

    var _hp = ui_panel(20, 16, 600, 328, "HOW TO PLAY");
    ui_font("label");
    var _lh2 = ui_line_h();
    var _lw2 = string_width("independence") + 10;
	ui_reserve(_hp, _lh2 + 10);
	
	    // help_page is now one flat index: the key pages first, then the
    // quantum pages. RIGHT always means forward.
    var _nk = array_length(HELP_PAGES);
    var _nq = array_length(QUANTUM_PAGES);
 
    // page counter, top right, so nobody has to guess how much is left
    ui_font("label");
    ui_text_right(_hp.x + _hp.inner_w, _hp.cursor,
                  string(help_page + 1) + " / " + string(_nk + _nq),
                  ui_col("faint"));
 
    if (help_page >= _nk) {
        // ---- the quantum pages ----
        var _qp2 = QUANTUM_PAGES[help_page - _nk];
 
        ui_font("display");
        ui_text(_hp.x, _hp.cursor, _qp2.title, ui_col("quantum"), _hp.inner_w);
        _hp.cursor += string_height("Ay") + 8;
        ui_font("body");
        ui_para(_hp, _qp2.body, ui_col("text"));
 
        ui_font("label");
        var _dts = "";
        for (var i = 0; i < _nk + _nq; i++)
            _dts += (i == help_page) ? "*" : ".";
        ui_text(_hp.x, ui_footer_y(_hp), _dts, ui_col("you"));
        ui_text_right(_hp.x + _hp.inner_w, ui_footer_y(_hp),
                      "LEFT/RIGHT pages   ESC close", ui_col("faint"));
        exit;
    }
 
    var _rows = HELP_PAGES[help_page];

    var _cut = false;
    for (var i = 0; i < array_length(_rows); i++) {
        if (ui_room(_hp) < _lh2) { _cut = true; break; }
        if (_rows[i][0] == "") { _hp.cursor += floor(_lh2 * 0.4); continue; }
		
 
        // a group heading spans the full width in the quantum colour, so the
        // eye can find the section it wants without reading every row
        if (string_copy(_rows[i][0], 1, 3) == "---") {
            ui_text(_hp.x, _hp.cursor,
                    string_replace_all(_rows[i][0], "-", ""),
                    ui_col("quantum"), _hp.inner_w);
            _hp.cursor += _lh2;
            continue;
        }
		
		ui_text(_hp.x, _hp.cursor, _rows[i][0], ui_col("you"), _lw2);
        ui_text(_hp.x + _lw2, _hp.cursor, _rows[i][1], ui_col("text"),
                _hp.inner_w - _lw2);
        _hp.cursor += _lh2;
    }

    ui_font("label");
    var _dts2 = "";
    for (var i = 0; i < _nk + _nq; i++)
        _dts2 += (i == help_page) ? "*" : ".";
    ui_text(_hp.x, ui_footer_y(_hp), _dts2, ui_col("you"));
    ui_text_right(_hp.x + _hp.inner_w, ui_footer_y(_hp),
                  "LEFT/RIGHT pages   ESC close", ui_col("faint"));
    exit;
}

if (scene == "splash") {
    draw_set_colour(c_black);
    draw_rectangle(0, 0, 640, 360, false);

    var _t = splash_timer;
    var _a;
    var _rise = 0;      // pixels of settle-into-place on the way in

    if (_t < SPLASH_FADE_IN) {
        var _p = _t / SPLASH_FADE_IN;
        // EASED, NOT LINEAR. A linear ramp on a bright logo against black
        // reads as fully present by about a third of the way through, which
        // is why it looked like it just appeared. Squaring it keeps the
        // early frames genuinely dark and puts the visible change late.
        _a = power(_p, 2.0);
        // and it drifts up into position as it arrives, so the fade has
        // something to accompany rather than being the only thing happening
        _rise = (1 - power(_p, 0.6)) * 7;

    } else if (_t < SPLASH_FADE_IN + SPLASH_HOLD) {
        _a = 1;

    } else {
        var _ft = _t - (SPLASH_FADE_IN + SPLASH_HOLD);
        var _q = clamp(_ft / SPLASH_FADE_OUT, 0, 1);
        _a = power(1 - _q, 2.0);
        _rise = -power(_q, 1.4) * 5;    // and drifts on out the way it came
    }
    _a = clamp(_a, 0, 1);

    // fit the logo to a fixed display height, aspect preserved, centred
    var _target_h = 200;
    var _scale = _target_h / sprite_get_height(spr_moth_logo);
    var _w = sprite_get_width(spr_moth_logo) * _scale;
    var _lx = (640 - _w) / 2;
    var _ly = (360 - _target_h) / 2;

    // one slow breath, same motif and roughly the same rate as the rulers
    // in the courts, so the whole game moves at one tempo.
    _ly += fx_bob(0.24, 2.6) + _rise;

    draw_set_alpha(_a);
    draw_sprite_ext(spr_moth_logo, 0, _lx, _ly, _scale, _scale, 0, c_white, 1);
    draw_set_alpha(1);
    exit;
}


if (scene == "title") {
    draw_set_colour(c_black);
    draw_rectangle(0, 0, 640, 360, false);
 
    // ---------- settings ----------
    if (menu_page == "settings") {
        settings_panel_draw("UP/DOWN choose   LEFT/RIGHT change   ESC back");
        exit;
    }
 
    // ---------- the quantum ----------
    if (menu_page == "quantum") {
        var _qp = ui_panel(60, 40, 520, 280, "");
        var _qlh = ui_line_h();
        ui_reserve(_qp, _qlh + 4);          // <-- THE FIX
        var _pg  = QUANTUM_PAGES[q_page];
 
        ui_font("display");
        ui_text(_qp.x, _qp.cursor, _pg.title, ui_col("quantum"), _qp.inner_w);
        _qp.cursor += string_height("Ay") + 8;
        ui_font("body");
 
        ui_para(_qp, _pg.body, ui_col("text"));
 
        var _dots = "";
        for (var i = 0; i < array_length(QUANTUM_PAGES); i++)
            _dots += (i == q_page) ? "*" : ".";
        ui_text(_qp.x, ui_footer_y(_qp), _dots, ui_col("you"));
        ui_text_right(_qp.x + _qp.inner_w, ui_footer_y(_qp),
                      (q_page < array_length(QUANTUM_PAGES) - 1)
                        ? "SPACE next   ESC back" : "ESC back",
                      ui_col("faint"));
        exit;
    }
 
    
    // ---------- root ----------
    // current_time is milliseconds since launch, so no new state to keep.
    var _tt = current_time / 1000;
 
    // drifting dust, behind everything. Positions come from a hash of the
    // index rather than random(), so they do not reshuffle every frame.
    for (var d = 0; d < 44; d++) {
        var _dx  = frac(sin(d * 12.9898) * 43758.5453) * 640;
        var _dy0 = frac(sin(d * 78.2330) * 43758.5453) * 360;
        var _dsp = 3 + frac(sin(d * 39.4210) * 1000) * 8;
        var _dyy = (_dy0 + _tt * _dsp) mod 360;
        var _dw  = (d mod 7 == 0) ? 2 : 1;
        draw_set_alpha(0.05 + 0.10 * frac(sin(d * 4.771) * 1000));
        draw_set_colour(ui_col("quantum"));
        draw_rectangle(_dx, _dyy, _dx + _dw - 1, _dyy + _dw - 1, false);
    }
    draw_set_alpha(1);
 
    // the ring behind the wordmark. Slow, wide, and dim enough that it
    // reads as an orbit you half-noticed rather than as a logo animation.
    fx_orbit(320, 92, 122, 5, ui_col("quantum"), 0.34, 0.55);
 
    // the title breathes. 3px over about four seconds -- slow enough that
    // you notice it is alive without noticing the animation.
    var _bob = sin(_tt * 1.55) * 3;
 
    ui_font("title_2");
    var _tw = string_width("EIGENSTATE");
    // a dim copy two pixels down, drifting out of phase with the title, so
    // the letters look like they are sitting slightly off their own shadow
    ui_text((640 - _tw) / 2, 72 + sin(_tt * 1.55 + 0.9) * 3,
            "EIGENSTATE", ui_col("quantum"), 640);
    ui_text((640 - _tw) / 2, 70 + _bob, "EIGENSTATE", ui_col("you"), 640);
 
    ui_font("label");
    var _sw = string_width("Demo Created by MOTH & PARLOROID");
    ui_text((640 - _sw) / 2, 132 + _bob * 0.4,
            "Demo Created by PARLOROID", ui_col("faint"), 640);
 
    ui_font("body");
    var _mlh = ui_line_h() + 6;
    var _my  = 190;
    for (var i = 0; i < array_length(MENU_ITEMS); i++) {
        var _sel = (i == menu_pick);
        var _label = MENU_ITEMS[i];
        var _w = string_width(_label);
        var _x = (640 - _w) / 2;
        if (_sel) {
            // the caret nudges toward its item, which is the only bit of
            // motion here that is telling you something rather than
            // decorating
            var _nudge = 2 + sin(_tt * 4.2) * 2;
            ui_text(_x - 20 + _nudge, _my, ">", ui_col("you"));
        }
        ui_text(_x, _my, _label, _sel ? ui_col("you") : ui_col("dim"), 640);
        _my += _mlh;
    }
 
    ui_font("label");
    var _hw = string_width("UP/DOWN choose    ENTER select");
    ui_text((640 - _hw) / 2, 330, "UP/DOWN choose    ENTER select",
            ui_col("faint"), 640);
    ui_font("body");
    exit;
}


if (scene == "intro") {
    
    // the desk the letter is lying on
    draw_set_colour(make_colour_rgb(8, 9, 13));
    draw_rectangle(0, 0, 640, 360, false);
 
    // the letter itself
    fx_paper(62, 12, 516, 336);
 
    // double ruled border. Two lines at different alphas does more for the
    // period feel than any amount of ornament, because it is what an
    // actual formal letter looks like.
    draw_set_colour(make_colour_rgb(96, 82, 62));
    draw_set_alpha(0.55);
    draw_rectangle(70, 20, 570, 340, true);
    draw_set_alpha(0.28);
    draw_rectangle(73, 23, 567, 337, true);
    draw_set_alpha(1);
 
    fx_corner( 70,  20, 14, 0, make_colour_rgb(150, 126, 84), 0.75);
    fx_corner(570,  20, 14, 1, make_colour_rgb(150, 126, 84), 0.75);
    fx_corner( 70, 340, 14, 2, make_colour_rgb(150, 126, 84), 0.75);
    fx_corner(570, 340, 14, 3, make_colour_rgb(150, 126, 84), 0.75);
 
    // THE COLD THING. Five dots in orbit at the foot of the page, as if
    // the letter had been measured as well as written. Same motif as the
    // observatory, so the player meets it here first and recognises it
    // later without being told.
    fx_orbit(508, 306, 34, 5, ui_col("quantum"), 0.28, 1.0);
 
    // one candle, and everything on the page answers to it
    var _cand = fx_flicker();
 
    // --- build the wrapped lines once, here, because wrapping needs a
    //     font to measure against and Create has none set yet ---
    if (!intro_ready) {
        ui_font("body");
        intro_lines = [];
        // honour the blank lines between paragraphs
        var _buf = "";
        var _n = string_length(LETTER_BODY);
        for (var i = 1; i <= _n + 1; i++) {
            var _ch = (i <= _n) ? string_char_at(LETTER_BODY, i) : "";
            if (_ch == "\n" || i > _n) {
                if (_buf != "") {
                    var _w = ui_wrap(_buf, 470);
                    for (var j = 0; j < array_length(_w); j++) {
                        array_push(intro_lines, _w[j]);
                    }
                    _buf = "";
                } else if (i <= _n) {
                    array_push(intro_lines, "");   // paragraph break
                }
            } else {
                _buf += _ch;
            }
        }
        intro_ready = true;
    }

    var _lh = ui_line_h();

    // --- heading, in the decorative face ---
    // the parchment runs 62..578, and the text starts at 85, so this is the
    // real room available -- not 540, which was wider than the page
    var _t_room = 578 - 85 - 8;

    ui_font("title");
    if (string_width(LETTER_TITLE) > _t_room) ui_font("display");
    if (string_width(LETTER_TITLE) > _t_room) ui_font("body");
    var _title_h = string_height("Ay");     // measured in whichever won
    ui_text(85, 26, LETTER_TITLE, fx_dim(ui_col("you"), _cand), _t_room);
    ui_font("body");

    var _y0 = 26 + _title_h + 14;

    // --- PAGINATE, once the title height is actually known ---
    // The letter is longer than one screenful now. Before this it was cut
    // off wherever y passed 268 and the rest was simply never drawn.
    // A page never STARTS with a paragraph break -- a blank first line
    // reads as a rendering fault rather than as spacing.
    if (!intro_paged) {
        var _per = max(1, floor((268 - _y0) / _lh));

        intro_pages = [];
        var _cur = [];
        for (var i = 0; i < array_length(intro_lines); i++) {
            if (array_length(_cur) == 0 && intro_lines[i] == "") continue;
            array_push(_cur, intro_lines[i]);
            if (array_length(_cur) >= _per) {
                array_push(intro_pages, _cur);
                _cur = [];
            }
        }
        if (array_length(_cur) > 0) array_push(intro_pages, _cur);
        if (array_length(intro_pages) == 0) array_push(intro_pages, [""]);

        // characters per page, so the reveal runs one page at a time
        intro_page_chars = [];
        for (var i = 0; i < array_length(intro_pages); i++) {
            var _c = 0;
            for (var j = 0; j < array_length(intro_pages[i]); j++)
                _c += string_length(intro_pages[i][j]);
            array_push(intro_page_chars, max(1, _c));
        }

        intro_page  = 0;
        intro_shown = 0;
        intro_total = intro_page_chars[0];
        intro_done  = false;
        intro_paged = true;
    }

    // --- the current page, revealed a character at a time ---
    var _pg = intro_pages[intro_page];
    var _last_page = (intro_page >= array_length(intro_pages) - 1);
    var _budget = floor(intro_shown);
    var _y = _y0;
    for (var i = 0; i < array_length(_pg); i++) {
        var _line = _pg[i];
        var _len  = string_length(_line);
        if (_budget <= 0 && _len > 0) break;
        var _cut = (_len <= _budget) ? _line : string_copy(_line, 1, _budget);
        if (_cut != "") ui_text(85, _y, _cut, fx_dim(ui_col("text"), _cand), 470);
        _budget -= _len;
        _y += _lh;
    }

    // --- signature, on the last page only, once it has finished ---
    if (intro_done && _last_page) {
        ui_font("display");
        var _sgy = min(296, _y + 8);
        ui_text(85, _sgy, LETTER_SIGN, fx_dim(ui_col("faint"), _cand), 470);
        // the seal goes to the right of the name, measured rather than
        // guessed, so it cannot land on top of a long signature
        var _sgw = string_width(LETTER_SIGN);
        ui_font("body");
        // CLAMPED. Measured in the display font, a 50-character signature
        // pushes this off the parchment and off the screen.
        fx_seal(min(85 + _sgw + 24, 552), _sgy + 10, 11);
    }

    // --- prompts. ONE block, not two: this was drawn twice before. ---
    draw_set_colour(ui_col("faint"));
    var _pgn = " (" + string(intro_page + 1) + " of "
             + string(array_length(intro_pages)) + ")";
    if (link == "down") {
        // link_note first: once we have actually given up, the player needs
        // to know that, not a reassuring message about measurement.
        ui_text(85, 316, link_note, ui_col("war"), 440);
    } else if (intro_waiting) {
        ui_text(85, 316, "The oracle has not finished measuring the world...",
                ui_col("quantum"), 440);
    } else if (!intro_done) {
        ui_text(85, 316, "SPACE to read this page at once" + _pgn,
                ui_col("faint"), 440);
    } else if (!_last_page) {
        ui_text(85, 316, (intro_page > 0 ? "SPACE forward   LEFT back"
                                         : "SPACE to turn the page") + _pgn,
                ui_col("you"), 440);
    } else {
        ui_text(85, 316, (intro_page > 0 ? "SPACE to take the throne   LEFT back"
                                         : "SPACE to take the throne") + _pgn,
                ui_col("you"), 440);
    }
 
    // --- a failed handshake is drawn OVER the letter, not instead of it,
    //     so you never lose your place ---
    if (link_down()) {
        draw_set_alpha(0.88);
        draw_set_colour(make_colour_rgb(6, 7, 10));
        draw_rectangle(60, 120, 580, 240, false);
        draw_set_alpha(1);
        draw_set_colour(ui_col("war"));
        draw_rectangle(60, 120, 580, 240, true);
        var _ep = ui_panel(72, 128, 496, 104, "");
        ui_font("display");
        ui_text(_ep.x, _ep.cursor, "The oracle does not answer", ui_col("war"), 480);
        _ep.cursor += string_height("Ay") + 4;
        ui_font("body");
        ui_para(_ep, link_note, ui_col("text"));
        _ep.cursor += 4;
        ui_text(_ep.x, _ep.cursor, "Press R to try again.", ui_col("you"), 480);
        if (keyboard_check_pressed(ord("R"))) retry_link();
    }
 
    exit;
}
 





ui_font("body");
var L  = ui_layout(N);          // N rows in the roster


var LH = L.lh;
// ============================================================
// AUDIENCE SCREEN
//
// 320x180 illustration built from stacked layers -- hall, build, outfit,
// hair, face -- with the FACE chosen by the leader's live hostility, so
// the same person visibly hardens across a run as their qubit rotates.
//
// Until sprites exist, each layer draws as a labelled box so the stack and
// its dimensions are already correct. Draw them at the full 320x180 with
// transparency and they will composite with no offset maths at all.
// ============================================================

if (audience_of != -1) {
    var _i = audience_of;
    var _f = factions[_i];

    draw_set_colour(make_colour_rgb(9, 11, 15));
    draw_rectangle(0, 0, 640, 360, false);

    
    // ---------- illustration ----------
    var _ax = 12, _ay = 14, _aw = 320, _ah = 180;
 
    // HOW FAR THE RULER HAS LEFT. 0 = in place, 1 = fully off frame.
    // jester_ruler_out() lives in Create and owns the state names, so this
    // file never has to know what "usher" means.
    var _out = jester_ruler_out();
    var _pdx = -(_aw + 40) * _out;      // negative = slides out to the left
	
	// one slow breath, about four seconds. Applied to the ruler and the
    // crown identically so they never come apart.
    var _pdy = fx_bob(0.26, 1.6);
	
	// CLIP TO THE FRAME. Everything below is offset by _pdx/_pdy and would
    // otherwise draw over the roster and the top bar. Anything outside these
    // bounds is discarded rather than drawn, so a ruler sliding out simply
    // disappears at the edge instead of gliding across the UI.
 
    var _hall_spr = portrait_sprite("hall", _f.hall);
    var _person_layers = [ ["build",  _f.build],
                            ["head",   _f.head],
                            ["outfit", _f.outfit],
                            ["hair",   _f.hair] ];
 
    // crown: scaled down independently of everything else.
    var _crown_l = 79, _crown_t = 3, _crown_w = 34, _crown_h = 16;
    var CROWN_SCALE = 0.75;
    var _crown_spr = portrait_sprite("crown", _f.crown);
    var _crown_full_w = _crown_w * 2, _crown_full_h = _crown_h * 2;
    var _crown_cx = _ax + _crown_l * 2 + _crown_full_w / 2;
    var _crown_cy = _ay + _crown_t * 2 + _crown_full_h / 2;
    var _crown_cw = _crown_full_w * CROWN_SCALE, _crown_ch = _crown_full_h * CROWN_SCALE;
    var _crown_x  = _crown_cx - _crown_cw / 2, _crown_y = _crown_cy - _crown_ch / 2;
 
    // hall background first, so it sits under the character. NO OFFSET.
    var _any = false;
    if (_hall_spr != -1) {
        draw_sprite_stretched(_hall_spr, 0, _ax, _ay, _aw, _ah);
        _any = true;
    }
 
    // ---------- the ruler, offset by _pdx ----------
    // Skipped entirely once he is fully gone, so a stretched sprite at a
    // large negative x is never handed to the renderer.
    if (_out < 1) {
 
        for (var i = 0; i < array_length(_person_layers); i++) {
            var _lname = _person_layers[i][0];
            var _spr   = portrait_sprite(_lname, _person_layers[i][1]);
            if (_spr == -1) continue;

            // ONE OUTFIT SPRITE PER TIER, drawn to the slender build and
            // widened for the stocky one. Cloth has no landmark the eye can
            // check against the head, unlike hair, so a horizontal stretch
            // reads as a bigger body rather than as distorted art.
            // HEIGHT IS NEVER TOUCHED. The shoulders have to stay level with
            // the neck on every build or the head looks detached.
            var _sx = _ax + _pdx, _sw = _aw;
            if (_lname == "outfit" && _f.build == 1) {
                var _wide = _aw * 0.07;
                _sx -= _wide * 0.5;     // grow outward from the centre
                _sw += _wide;
            }

            draw_sprite_stretched(_spr, 0, _sx, _ay + _pdy, _sw, _ah);
            _any = true;
        }
 
        var _nose_spr  = face_nose_sprite(_i);
        var _eyes_spr  = face_eyes_spr(_i);
        var _mouth_spr = face_mouth_spr(_i);
        if (_nose_spr != -1)  { draw_sprite_stretched(_nose_spr,  0,                    _ax + _pdx, _ay + _pdy, _aw, _ah); _any = true; }
        if (_eyes_spr != -1)  { draw_sprite_stretched(_eyes_spr,  face_eyes_frame(_i),  _ax + _pdx, _ay + _pdy, _aw, _ah); _any = true; }
        if (_mouth_spr != -1) { draw_sprite_stretched(_mouth_spr, face_mouth_frame(_i), _ax + _pdx, _ay + _pdy, _aw, _ah); _any = true; }
 
        if (_crown_spr != -1) {
            draw_sprite_part_ext(_crown_spr, 0, _crown_l, _crown_t, _crown_w, _crown_h,
                                  _crown_x + _pdx, _crown_y + _pdy,
                                  _crown_cw / _crown_w, _crown_ch / _crown_h, c_white, 1);
            _any = true;
        }
    }
	
	if (jbit == "enter" || jbit == "dance") {
        var _js = asset_get_index("spr_jester");
        if (_js != -1 && sprite_exists(_js)) {
            var _jw = sprite_get_width(_js)  * JESTER_SCALE;
            var _jh = sprite_get_height(_js) * JESTER_SCALE;
 
            // slides in from the right, easing out so he decelerates into
            // place rather than stopping dead
            var _p  = (jbit == "enter") ? clamp(jbit_t / JBIT_ENTER, 0, 1) : 1;
            var _e  = 1 - power(1 - _p, 3);
            var _jx = lerp(_ax + _aw + _jw, _ax + (_aw - _jw) * 0.5, _e);
            var _jy = _ay + _ah - _jh - 10;
 
            // FROZEN on frame 0 until the music starts. This is the whole
            // gag: he arrives, waits a beat, then the music kicks in and he
            // goes. Animating during the slide throws that away.
            var _jfr = 0;
            if (jbit == "dance")
                _jfr = floor(jbit_t * JESTER_FPS) mod sprite_get_number(_js);
 
            draw_sprite_ext(_js, _jfr, _jx, _jy, JESTER_SCALE, JESTER_SCALE,
                            0, c_white, 1);
            _any = true;
        }
    }
	
	if (jbit == "boom") {
        var _bp = clamp(jbit_t / JBIT_BOOM, 0, 1);
        var _bcx = _ax + _aw * 0.5;
        var _bcy = _ay + _ah - 10 - (32 * JESTER_SCALE) * 0.5;
 
        var _bs = asset_get_index("spr_boom");
        if (_bs != -1 && sprite_exists(_bs)) {
            var _bf = floor(_bp * sprite_get_number(_bs));
            _bf = min(_bf, sprite_get_number(_bs) - 1);
            draw_sprite_ext(_bs, _bf, _bcx, _bcy, JESTER_SCALE, JESTER_SCALE,
                            0, c_white, 1);
        } else {
            // Hand-rolled puff. Chunky squares, not circles: a smooth circle
            // next to pixel art looks like a different game.
            var _px = 4;                       // "pixel" size of the effect
            var _r  = 6 + _bp * 46;
            draw_set_alpha(1 - _bp * 0.85);
 
            // two rings of blocks, offset in phase
            for (var _ring = 0; _ring < 2; _ring++) {
                var _rr = _r * (1 - _ring * 0.35);
                var _n  = 10 + _ring * 4;
                draw_set_colour(_ring == 0 ? make_colour_rgb(245, 224, 150)
                                           : make_colour_rgb(168, 74, 90));
                for (var _k = 0; _k < _n; _k++) {
                    var _a = (360 / _n) * _k + _ring * 12 + _bp * 40;
                    var _bx = _bcx + lengthdir_x(_rr, _a);
                    var _by = _bcy + lengthdir_y(_rr, _a);
                    // snap to the pixel grid so it reads as pixel art
                    _bx = floor(_bx / _px) * _px;
                    _by = floor(_by / _px) * _px;
                    draw_rectangle(_bx, _by, _bx + _px, _by + _px, false);
                }
            }
 
            // the flash, only for the first fifth, and it is what sells the
            // whole thing
            if (_bp < 0.2) {
                draw_set_alpha(1 - _bp / 0.2);
                draw_set_colour(c_white);
                draw_rectangle(_ax, _ay, _ax + _aw, _ay + _ah, false);
            }
 
            draw_set_alpha(1);
        }
        _any = true;
    }

    // ---------- who you are talking to ----------
    var _dp = ui_panel(344, 14, 284, 180, "");
    ui_font("display");
    ui_text(_dp.x, _dp.cursor, _f.leader, ui_col("text"), _dp.inner_w);
    _dp.cursor += string_height("Ay") + 2;
    ui_font("body");
    ui_text(_dp.x, _dp.cursor, "of " + _f.name, ui_col("faint"), _dp.inner_w);
    _dp.cursor += LH + 4;

    ui_row(_dp, "mood", mood_word(_f.hostility), ui_col("text"));
    ui_row(_dp, "self", self_word(_f.independence), ui_col("quantum"));
    ui_row(_dp, "bent", _f.temper, ui_col("text"));
    ui_row(_dp, "bond", string_format(bonds[ME][_i], 1, 2),
           bonds[ME][_i] < 0 ? ui_col("war") : ui_col("ally"));
    ui_row(_dp, "host", string(_f.army) + " under arms", ui_col("text"));
	
    
    // ---------- what they said, and what you can do ----------
    var _tp = ui_panel(12, 204, 616, 148, "");
	ui_reserve(_tp, LH + 4);
 
    // The ruler's answer stays on screen throughout, including while he is
    // walking out. He answers, THEN he leaves.
    ui_para(_tp, audience_line, ui_col("text"));
    _tp.cursor += 6;
 
    if (jbit != "") {
 
        // ---- the bit is running: narrate it, offer only the way out ----
        var _msg = "";
        if (jbit == "usher")  _msg = "The court makes room.";
        if (jbit == "enter")  _msg = "Something is approaching.";
        if (jbit == "dance")  _msg = "Press " + JBIT_STOP_KEY_NAME
                                   + " to make him stop.";
        if (jbit == "boom")   _msg = "";
        if (jbit == "return") _msg = "Order is restored.";
 
                if (_msg != "")
            ui_text(_tp.x, _tp.cursor, _msg,
                    (jbit == "dance") ? ui_col("you") : ui_col("faint"),
                    _tp.inner_w);

        ui_text(_tp.x, ui_footer_y(_tp), "ESC leave the hall",
                ui_col("faint"), _tp.inner_w);
 
    } else {
 
        // ---- normal court menu: your existing code, unchanged ----
        for (var i = 0; i < array_length(audience_opts); i++) {
            if (ui_room(_tp) < LH) break;
            var _o = audience_opts[i];
            var _sel = (i == audience_pick);
            var _tag = "";
            if (_o.points > 0) _tag = "  (1 action)";
            else if (_o.cost > 0) _tag = "  (" + string(_o.cost) + " gold)";
            ui_text(_tp.x, _tp.cursor, (_sel ? "> " : "  ") + _o.label + _tag,
                    _sel ? ui_col("you") : ui_col("dim"), _tp.inner_w);
            _tp.cursor += LH;
        }
 
        ui_text(_tp.x, ui_footer_y(_tp),
			"UP/DOWN choose    ENTER speak    ESC leave the hall",
                ui_col("faint"), _tp.inner_w);
    }
 
    exit;
}

var _me = factions[ME];

// ---------------- game over ----------------

// ---------------- game over ----------------
// Two years is short enough that the player can hold the whole run in
// their head, so this is not here to inform them. It is here to tell them
// which of their choices the world actually remembered, and the answer is
// different every time, which is the reason to run it again.
if (game_over) {
    var _gp = ui_panel(40, 30, 560, 302);
	
	// dust barely moving, and the ring still turning. The world does not
    // stop because your run did.
    fx_dust(30, ui_col("faint"), 0.11, 2.5);
    fx_orbit(320, 96, 150, 5, ui_col("quantum"), 0.20, 0.35);
	
    var _lh = ui_line_h();
    ui_reserve(_gp, _lh + 6);
 
    ui_font("title");
    ui_para(_gp, ending, ui_col("you"));
    ui_font("body");
    _gp.cursor += 4;
 
    var _orow = function(_p, _lab, _val, _vcol, _lh) {
        if (ui_room(_p) < _lh) return;
        ui_text(_p.x, _p.cursor, _lab, ui_col("faint"), 150);
        ui_text(_p.x + 156, _p.cursor, _val, _vcol, _p.inner_w - 156);
        _p.cursor += _lh;
    }
 
    // ---- who you ended up entangled with ----
    var _hi = -1, _hv = -2, _lo = -1, _lv = 2;
    for (var j = 1; j < N; j++) {
        if (!factions[j].alive) continue;
        if (bonds[ME][j] > _hv) { _hv = bonds[ME][j]; _hi = j; }
        if (bonds[ME][j] < _lv) { _lv = bonds[ME][j]; _lo = j; }
    }
 
    if (_hi != -1 && _hv > 0.10)
        _orow(_gp, "Closest to you", factions[_hi].name + "   "
                 + string_format(_hv, 1, 2), ui_col("ally"), _lh);
    else
        _orow(_gp, "Closest to you", "no one, in the end",
              ui_col("dim"), _lh);
 
    if (_lo != -1 && _lv < -0.10)
        _orow(_gp, "Set against you", factions[_lo].name + "   "
                 + string_format(_lv, 1, 2), ui_col("war"), _lh);
 
    // ---- what you swore ----
    if (run_sworn > 0) {
        var _os = string(run_sworn) + " sworn, " + string(run_held) + " held";
        if (run_turned > 0) _os += ", " + string(run_turned) + " turned";
        if (run_broken > 0) _os += ", " + string(run_broken) + " broken";
        _orow(_gp, "Oaths", _os, ui_col("text"), _lh);
    } else {
        _orow(_gp, "Oaths", "you never swore one", ui_col("dim"), _lh);
    }
 
    // ---- the month it went wrong ----
    if (run_worst_j != -1 && run_worst_d < -0.15)
        _orow(_gp, "Sharpest turn", factions[run_worst_j].name + ", month "
                 + string(run_worst_m) + "   " + string_format(run_worst_d, 1, 2),
              ui_col("war"), _lh);
 
    // ---- the bit that is actually quantum, said plainly ----
    if (run_hw > 0)
        _orow(_gp, "Measured for real", string(run_hw)
                 + ((run_hw == 1) ? " oath" : " oaths")
                 + " on Moth hardware", ui_col("quantum"), _lh);
    else
        _orow(_gp, "Measured for real", "emulated, every one",
              ui_col("dim"), _lh);
 
    // ---- the collection ----
 
    ui_text(_gp.x, ui_footer_y(_gp), "F5 to run again.",
            ui_col("faint"), _gp.inner_w);
    exit;
}


// ---------------- top bar ----------------
// Laid out by walking a cursor and advancing by MEASURED width, so no
// two items can ever collide however long the numbers get.
var _t = L.top;
var _tx = _t.x;
var _ty = _t.y + 2;

var stat = function(_x, _y, _label, _value, _vcol) {
    ui_font("label");
    ui_text(_x, _y + 2, _label, ui_col("faint"));
    var _lw = string_width(_label) + 3;
    ui_font("body");
    ui_text(_x + _lw, _y, _value, _vcol);
    return _x + _lw + string_width(_value) + 12;
};

ui_text(_tx, _ty, "MONTH " + string(year) + "/" + string(MONTHS_TOTAL), ui_col("you"));
_tx += string_width("MONTH 88/88") + 16;

_tx = stat(_tx, _ty, "ARM",
      string(_me.army) + "/" + string(sustainable_army(ME)),
      _me.army > sustainable_army(ME) ? ui_col("war") : ui_col("text"));
_tx = stat(_tx, _ty, "GLD", string(_me.treasury), ui_col("text"));
_tx = stat(_tx, _ty, "LND", string(_me.holds),
      _me.holds > START_HOLDINGS ? ui_col("war") : ui_col("text"));

// meters: you need "creeping up" and "nearly gone", not 41 vs 43
ui_font("label");
ui_text(_tx, _ty + 2, "UNREST", ui_col("faint"));
_tx += string_width("UNREST") + 4;
ui_meter(_tx, _ty + LH * 0.5, 40, _me.unrest / UNREST_MAX,
         _me.unrest > 60 ? ui_col("war") : ui_col("dim"));
_tx += 48;

ui_text(_tx, _ty + 2, "FREEDOM", ui_col("faint"));
_tx += string_width("FREEDOM") + 4;
ui_meter(_tx, _ty + LH * 0.5, 36, _me.independence,
         _me.independence < INDEP_ACTION_FLOOR ? ui_col("war")
                                               : ui_col("quantum"));
_tx += 44;
ui_font("body");

// actions, right-aligned, now labelled and colour-coded
var _dots = "";
for (var i = 0; i < ACTIONS_MAX; i++) _dots += (i < actions_left) ? "*" : "-";
var _adots = "ACTS " + _dots;
ui_num(_t.x + _t.w, _ty, _adots, actions_left > 0 ? ui_col("you")
                                                  : ui_col("war"));											  
												
// If entanglement has cost you actions, say so where it happened rather
// than only in a log line that scrolls away.
if (_me.independence < INDEP_ACTION_FLOOR) {
    ui_font("label");
    ui_text_right(_t.x + _t.w, _ty + LH, "too entangled to act freely",
                  ui_col("war"));
    ui_font("body");
}



// ---------------- roster ----------------
// Columns measured from the widest content each will hold, then laid out
// left to right. If the panel is too narrow for all of them, columns are
// DROPPED rather than allowed to overlap -- ROOM first, then SELF, because
// losing ROOM costs less than losing SELF.
var _rp = ui_panel_r(L.roster);
 
var _w_name = string_width("Eigenstate");
for (var i = 0; i < N; i++) _w_name = max(_w_name, string_width(factions[i].name));
var _w_mood = string_width("seething");
var _w_self = 34;
var _w_room = 40;
var _w_arm  = string_width("888");
var _w_rel  = string_width("neutral");
var _gap    = 10;
 
var _need_all = _w_name + _w_mood + _w_self + _w_room + _w_arm + _w_rel + _gap * 5;
var _show_room = (_need_all <= _rp.inner_w);
if (!_show_room) _w_room = 0;
 
var _need = _w_name + _w_mood + _w_self + _w_room + _w_arm + _w_rel
          + _gap * (_show_room ? 5 : 4);
var _show_self = (_need <= _rp.inner_w);
if (!_show_self) _w_self = 0;
 
var _cn  = _rp.x;
var _cm  = _cn + _w_name + _gap;
var _cs  = _cm + _w_mood + _gap;
var _cro = _cs + _w_self + (_show_self ? _gap : 0);
var _ca  = _cro + _w_room + (_show_room ? _gap : 0);
var _cr  = _ca + _w_arm + _gap;
 
ui_font("label");
ui_text(_cn, _rp.cursor, "KINGDOM", ui_col("faint"), _w_name);
ui_text(_cm, _rp.cursor, "MOOD",    ui_col("faint"), _w_mood);
if (_show_self) ui_text(_cs,  _rp.cursor, "SELF", ui_col("faint"), _w_self);
if (_show_room) ui_text(_cro, _rp.cursor, "ROOM", ui_col("faint"), _w_room);
ui_num(_ca + _w_arm, _rp.cursor, "ARM", ui_col("faint"));
ui_text(_cr, _rp.cursor, "STANDING", ui_col("faint"), _rp.inner_w - (_cr - _rp.x));
ui_font("body");
_rp.cursor += LH;
 
for (var i = 0; i < N; i++) {
    if (ui_room(_rp) < LH) break;
    var _f = factions[i];
 
    var _col = ui_col("text");
    if (i == ME) _col = ui_col("you");
    else if (!is_active(i)) _col = ui_col("faint");
    else if (bonds[ME][i] < WAR_THRESHOLD) _col = ui_col("war");
    else if (bonds[ME][i] > ALLY_THRESHOLD) _col = ui_col("ally");
 
    if (i == selected) ui_text(_rp.x - 9, _rp.cursor, ">", ui_col("you"));
    ui_text(_cn, _rp.cursor, _f.name, _col, _w_name);
 
    if (!_f.alive) {
        ui_text(_cm, _rp.cursor, "gone", ui_col("faint"), _w_mood);
    } else if (_f.vassal_of != -1) {
        ui_text(_cm, _rp.cursor, "sworn", ui_col("faint"), _w_mood);
    } else if (_f.intel_fresh) {
        ui_text(_cm, _rp.cursor, mood_word(_f.hostility), _col, _w_mood);
 
        if (_show_self)
            ui_meter(_cs, _rp.cursor + LH * 0.45, _w_self - 4,
                     _f.independence, ui_col("quantum"));
 
        // ROOM: how much of them is already committed. NOTE THE INVERTED
        // SENSE against SELF next to it -- this bar FILLING UP is bad news,
        // the same way UNREST is, because a full kingdom has nothing left to
        // give you. It turns red when there is almost no room left.
        if (_show_room) {
            var _rm = max(0.001, _f.budget_max);
            var _rl = max(0, _rm - _f.budget_used);
            ui_meter(_cro, _rp.cursor + LH * 0.45, _w_room - 4,
                     _f.budget_used / _rm,
                     (_rl / _rm < 0.20) ? ui_col("war") : ui_col("dim"));
        }
 
        ui_num(_ca + _w_arm, _rp.cursor, _f.army, _col);
    } else {
        ui_text(_cm, _rp.cursor, "unknown", ui_col("quantum"), _w_mood);
        ui_num(_ca + _w_arm, _rp.cursor, "?", ui_col("quantum"));
    }
 
    ui_text(_cr, _rp.cursor, rel_word(i), _col, _rp.inner_w - (_cr - _rp.x));
    _rp.cursor += LH;
}

// ---------------- detail ----------------
var _dp = ui_panel_r(L.detail);
var _s = factions[selected];

ui_font("display");
ui_text(_dp.x, _dp.cursor, _s.name,
        bonds[ME][selected] < WAR_THRESHOLD ? ui_col("war") : ui_col("text"),
        _dp.inner_w);
_dp.cursor += string_height("Ay") + 1;
ui_font("body");
ui_text(_dp.x, _dp.cursor, _s.leader, ui_col("faint"), _dp.inner_w);
_dp.cursor += LH + 2;

if (_s.vassal_of != -1) {
    ui_para(_dp, "Sworn to " + factions[_s.vassal_of].name + ".", ui_col("faint"));
} else if (!_s.alive) {
    ui_para(_dp, "Gone from the world.", ui_col("faint"));
} else if (_s.intel_fresh) {
    ui_row(_dp, "mood", mood_word(_s.hostility), ui_col("text"));
    ui_row(_dp, "self", self_word(_s.independence), ui_col("quantum"));
 
    // army and land on one line: two small numbers do not each deserve a row
    ui_row(_dp, "force", string(_s.army) + " troops, " + string(_s.holds)
                       + " lands", ui_col("text"));
 
    var _bv = bonds[ME][selected];
    ui_row(_dp, "bond", bond_word(_bv) + "  (" + string_format(_bv, 1, 2) + ")",
           _bv < 0 ? ui_col("war") : ui_col("ally"));
 
    // the two directional channels, sharing a row. Only drawn when either is
    // worth mentioning, so a clean relationship does not spend a line saying
    // "none, clear".
    // sway only. Drawn when there is something to say, so a clean
    // relationship does not spend a line saying "none".
    var _swy = sway_word(_s.leverage);
    if (_swy != "none")
        ui_row(_dp, "sway", _swy, ui_col("quantum"));
		
		
    // ---- the bond budget ----
    // GUARDED, unlike the first version. Needs a row plus the bar plus a
    // little breathing space, and if the panel cannot spare that it draws
    // nothing rather than spilling into the panel below.
    var _bmax  = max(0.001, _s.budget_max);
    var _bleft = max(0, _bmax - _s.budget_used);
    var _need  = LH + 10;
 
    if (ui_room(_dp) >= _need) {
        ui_row(_dp, "room", room_word(_bleft, _bmax),
               (_bleft / _bmax < 0.20) ? ui_col("war") : ui_col("quantum"));
 
        var _barw = _dp.inner_w;
        var _barh = 5;
        var _bary = _dp.cursor;
 
        draw_set_colour(make_colour_rgb(28, 33, 43));
        draw_rectangle(_dp.x, _bary, _dp.x + _barw, _bary + _barh, false);
 
        // one segment per relationship, biggest first, gold allied red hostile
        var _cx = _dp.x;
        for (var ci = 0; ci < array_length(_s.commitments); ci++) {
            var _cm = _s.commitments[ci];
            var _cw = (_cm.amount / _bmax) * _barw;
            if (_cw < 1) continue;
            draw_set_colour((_cm.sign > 0) ? ui_col("ally") : ui_col("war"));
            draw_rectangle(_cx, _bary, min(_dp.x + _barw, _cx + _cw - 1),
                           _bary + _barh, false);
            _cx += _cw;
        }
        _dp.cursor += _barh + 4;
    }
} else {
    ui_para(_dp, "No fresh word from this court. [E] to send agents.",
            ui_col("quantum"));
}


// ---------------- chronicle ----------------
var _cp = ui_panel_r(L.chron, "CHRONICLE");
ui_log(_cp, log_lines);

// ---------------- oaths ----------------
// The shared board. Everything anyone has sworn and not yet had tested,
// yours in gold. The percentage is the REAL probability that oath seals if
// it were measured right now -- the server computes it from shots on the
// same prepared circuit the deciding measurement will come from. Watch it
// move as people work on each other's plans.
var _op = ui_panel_r(L.oaths, "OATHS SWORN");

if (array_length(board) == 0) {
    ui_text(_op.x, _op.cursor, "Nothing is being sworn.", ui_col("faint"), _op.inner_w);
    _op.cursor += LH;
    ui_text(_op.x, _op.cursor, "[O] swear one.", ui_col("faint"), _op.inner_w);
} else {
    for (var i = 0; i < array_length(board); i++) {
        if (ui_room(_op) < LH * 2) break;
        var _o = board[i];

        var _ocol = ui_col("dim");
        if (oath_involves_me(_o)) {
            if (oath_is_friendly(_o)) _ocol = ui_col("ally");
            else _ocol = ui_col("war");
        }
        if (_o.owner == ME) _ocol = ui_col("you");

        if (lean_mode && i == lean_pick)
            ui_text(_op.x - 9, _op.cursor, ">", ui_col("you"));

        var _mo = string(_o.months_left) + "mo";
        ui_text(_op.x, _op.cursor, oath_line(_o), _ocol,
                _op.inner_w - string_width("88mo") - 6);
        ui_text_right(_op.x + _op.inner_w, _op.cursor, _mo, ui_col("faint"));
        _op.cursor += LH;

        // what it is made of, and how likely it is to hold
        ui_font("label");
        var _axw = string_width("persuasion") + 4;
        ui_text(_op.x, _op.cursor, oath_axis_of(_o.axis).label, ui_col("faint"), _axw);
        ui_font("body");

        var _pc = string(round(_o.p_seal * 100)) + "%";
        var _pcw = string_width("100%") + 4;
        var _mw  = _op.inner_w - _axw - _pcw - 4;
        if (_mw > 12)
            ui_meter(_op.x + _axw, _op.cursor + LH * 0.4, _mw, _o.p_seal,
                     ui_col("quantum"));
        ui_text_right(_op.x + _op.inner_w, _op.cursor, _pc, ui_col("quantum"));
        _op.cursor += LH + 3;
    }
}



// ---------------- council ----------------
var _np = ui_panel_r(L.council);

// BUG FIX: this panel used to be drawn here AND again by the plan block
// appended at the end of the event, so during the plan phase the verbs and
// the queued-plan list were painted on top of each other in the same rect.
// One panel, three states.

if (phase == "resolving") {
    ui_text(_np.x, _np.cursor, "The month turns...", ui_col("quantum"), _np.inner_w);
    ui_text(_np.x, _np.bottom - LH, "the oracle is being consulted",
            ui_col("faint"), _np.inner_w);


} else if (phase == "measuring" && array_length(measuring_queue) > 0) {
    var _b = measuring_queue[0];
    var _inc = variable_struct_exists(_b, "incoming") && _b.incoming;
 
    ui_font("display");
    if (_inc)
        ui_text(_np.x, _np.cursor, factions[_b.a].name + " marches on you",
                ui_col("war"), _np.inner_w);
    else
        ui_text(_np.x, _np.cursor, factions[ME].name + " vs " + factions[_b.b].name,
                ui_col("you"), _np.inner_w);
    ui_font("body");
    _np.cursor += LH;
 
    if (!measuring_revealed) {
        ui_text(_np.x, _np.cursor, bias_word(_b.bias), ui_col("quantum"), _np.inner_w);
        _np.cursor += LH;
 
        // colour by who BENEFITS, not by sign
        var _good = _inc ? (_b.bias < 0) : (_b.bias >= 0);
        ui_meter(_np.x, _np.cursor + 4, 200, clamp(0.5 + _b.bias * 0.4, 0, 1),
                 _good ? ui_col("ally") : ui_col("war"));
 
        ui_text(_np.x, _np.bottom - LH, "hold SPACE to measure",
                ui_col("faint"), _np.inner_w);
    } else {
        var _label = "Stalemate.";
        if (_inc) {
            if (_b.outcome == "decisive")      _label = "They have broken through.";
            else if (_b.outcome == "costly")   _label = "They took it, and bled for it.";
            else if (_b.outcome == "repelled") _label = "Held. They are thrown back.";
        } else {
            if (_b.outcome == "decisive")      _label = "Decisive victory.";
            else if (_b.outcome == "costly")   _label = "A costly victory.";
            else if (_b.outcome == "repelled") _label = "Repelled.";
        }
 
        var _lcol = ui_col("you");
        if (_inc) _lcol = (_b.outcome == "repelled") ? ui_col("ally") : ui_col("war");
        else      _lcol = (_b.outcome == "repelled") ? ui_col("war")  : ui_col("you");
 
        ui_text(_np.x, _np.cursor, _label, _lcol, _np.inner_w);
        ui_text(_np.x, _np.bottom - LH, "ENTER to continue",
                ui_col("faint"), _np.inner_w);
    }

} else if (oath_mode) {

    // The preparation phase's real decision. Four dials, and the axis one
    // is not cosmetic: it picks which rotation this oath is made of, and
    // therefore how other people's interference will combine with it.
    var _title = "OATH WITH " + factions[oath_target].name;
    ui_text(_np.x, _np.cursor, _title, ui_col("you"));
    var _ox = _np.x + string_width(_title) + 14;

    var _chips = [
        OATH_KINDS[oath_kind].label,
        string(oath_span) + "mo",
        string(round(OATH_STRENGTHS[oath_str] * 100)) + "%"
    ];
    for (var i = 0; i < 3; i++) {
        var _ccol = ui_col("dim");
        if (i == oath_field) _ccol = ui_col("text");
        if (i == oath_field) ui_text(_ox - 6, _np.cursor, "[", ui_col("you"));
        ui_text(_ox, _np.cursor, _chips[i], _ccol);
        var _cwid = string_width(_chips[i]);
        if (i == oath_field) ui_text(_ox + _cwid, _np.cursor, "]", ui_col("you"));
        _ox += _cwid + 18;
    }
 
    // the axis, shown but not chosen
    ui_font("label");
    ui_text(_ox, _np.cursor + 2,
            "made of " + oath_axis_of(OATH_KINDS[oath_kind].axis).label,
            ui_col("faint"));
    ui_font("body");
 
    var _hint = OATH_KINDS[oath_kind].hint;
    if (oath_field == 1) _hint = "longer means stronger, and more months for "
                               + "others to work on it";
    if (oath_field == 2) _hint = "how much of yourself you put behind it";
	
	ui_text(_np.x, _np.bottom - LH, _hint, ui_col("quantum"),
            _np.inner_w - string_width("ENTER swear   ESC cancel") - 20);
    ui_text_right(_np.x + _np.inner_w, _np.bottom - LH,
                  "ENTER swear   ESC cancel", ui_col("faint"));

} else if (lean_mode) {

    var _lo = board[clamp(lean_pick, 0, array_length(board) - 1)];
    var _dirw = "break";
    if (lean_dir > 0) _dirw = "back";
    var _sidename = factions[_lo.b].name;
    if (lean_side == 0) _sidename = factions[_lo.a].name;

    var _lt = "LEAN ON";
    ui_text(_np.x, _np.cursor, _lt, ui_col("you"));
    var _lx = _np.x + string_width(_lt) + 14;

    var _lchips = [ oath_line(_lo), _dirw, OATH_AXES[lean_axis].label, _sidename ];
    for (var i = 0; i < 4; i++) {
        var _ccol = ui_col("dim");
        if (i == oath_field) _ccol = ui_col("text");
        if (i == oath_field) ui_text(_lx - 6, _np.cursor, "[", ui_col("you"));
        ui_text(_lx, _np.cursor, _lchips[i], _ccol);
        var _cwid = string_width(_lchips[i]);
        if (i == oath_field) ui_text(_lx + _cwid, _np.cursor, "]", ui_col("you"));
        _lx += _cwid + 18;
    }

    var _lhint = "choose an oath -- anyone's";
    if (oath_field == 1) _lhint = "feed it or wreck it";
    if (oath_field == 2) _lhint = OATH_AXES[lean_axis].hint;
    if (oath_field == 3) _lhint = "which of the two you lean on";

    ui_text(_np.x, _np.bottom - LH, _lhint, ui_col("quantum"),
            _np.inner_w - string_width("ENTER commit   ESC cancel") - 20);
    ui_text_right(_np.x + _np.inner_w, _np.bottom - LH,
                  "ENTER commit   ESC cancel", ui_col("faint"));
				  

} else if (pending_verb != "") {
    ui_text(_np.x, _np.cursor + fx_bob(0.9, 1.0),
                string_upper(pending_verb), ui_col("you"))
    var _pw = string_width(string_upper(pending_verb)) + 8;
    ui_text(_np.x + _pw, _np.cursor,
        (pending_first == -1) ? "choose a kingdom (1-4)"
                             : "and now the second (1-4)",
        ui_col("text"), _np.inner_w - _pw);
    ui_text(_np.x, _np.bottom - LH, "ESC to think again",
            ui_col("faint"), _np.inner_w);

} else if (array_length(plan) > 0) {
 
    for (var i = 0; i < array_length(plan); i++) {
        if (ui_room(_np) < LH) break;
        var _p = plan[i];
 
        var _lbl = plan_label(_p);
        ui_text(_np.x, _np.cursor, _lbl, ui_col("you"));
 
        // the effect, right-aligned in the label colour's quieter cousin so
        // the eye reads the ACTION first and the consequence second
        ui_font("label");
        ui_text_right(_np.x + _np.inner_w, _np.cursor + 2,
                      plan_effect(_p), ui_col("faint"));
        ui_font("body");
 
        _np.cursor += LH;
    }

    // THE VERBS STAY VISIBLE. Queueing one action replaced the entire verb
    // list with the queue, so for the rest of the month the player had no
    // list of what else they could do. This belongs INSIDE this branch and
    // nowhere else -- outside it, it draws on top of the full verb list.
    if (plan_room() > 0 && ui_room(_np) >= LH) {
        ui_font("label");
        var _short = [["A","atk"],["S","aid"],["B","bind"],["O","oath"],
                      ["F","lean"],["E","espy"],["L","levy"],
                      ["X","pois"],["K","brok"]];
        var _rx = _np.x, _ry = _np.cursor - 4, _rhid = 0;
        for (var i = 0; i < array_length(_short); i++) {
            var _rc = _short[i][0] + " " + _short[i][1];
            var _rw = string_width(_rc) + 10;
            if (_rx + _rw > _np.x + _np.inner_w) {
                _rhid = array_length(_short) - i;
                break;
            }
            ui_text(_rx, _ry, _short[i][0], ui_col("you"));
            ui_text(_rx + string_width(_short[i][0] + " "), _ry,
                    _short[i][1], ui_col("dim"));
            _rx += _rw;
        }
        if (_rhid > 0)
            ui_text_right(_np.x + _np.inner_w, _ry,
                          "+" + string(_rhid) + " (H)", ui_col("quantum"));
        ui_font("body");
        _np.cursor += LH;
    }
 
    ui_text(_np.x, _np.bottom - LH,
        "ENTER commit the month    BACKSPACE undo    " + string(plan_room())
        + " left", ui_col("faint"), _np.inner_w);

} else {
	var _verbs = [["A","attack"],["S","aid"],["B","bind"],["O","oath"],
                  ["F","lean"],["E","espy"],["L","levy"],
                  ["X","poison"],["K","broker"]];
 
    // Two rows, filled greedily. The footer needs the last line, so the
    // verbs get everything above it.
    var _vx = _np.x;
    var _vy = _np.cursor;
    var _rows_used = 1;
    var _hidden = 0;
 
    for (var i = 0; i < array_length(_verbs); i++) {
        var _chunk = _verbs[i][0] + " " + _verbs[i][1];
        var _cw = string_width(_chunk) + 12;
 
        if (_vx + _cw > _np.x + _np.inner_w) {
            // wrap, but only once: a third row would collide with the footer
            if (_rows_used >= 2) { _hidden = array_length(_verbs) - i; break; }
            _rows_used++;
            _vx = _np.x;
            _vy += LH;
        }
 
        ui_text(_vx, _vy, _verbs[i][0], ui_col("you"));
        ui_text(_vx + string_width(_verbs[i][0] + " "), _vy,
                _verbs[i][1], ui_col("text"));
        _vx += _cw;
    }
 
    // Never fail silently. If the panel genuinely cannot hold them, the
    // player is told a key exists rather than left to guess.
    if (_hidden > 0)
        ui_text_right(_np.x + _np.inner_w, _vy, "+" + string(_hidden)
                      + " more (H)", ui_col("quantum"));
					  		 
 
    // FOOTER. H and Q were nowhere on screen, which made the only two
    // explanatory screens in the game undiscoverable.
    ui_text(_np.x, _np.bottom - LH,
        "1-4 choose   V court   ENTER end month   H help   Q observatory   J ledger   P settings",
        ui_col("faint"), _np.inner_w);
}


// ============================================================
// PLAN QUEUE  -- drawn over the council panel during the plan phase
// Queued intentions are visible and reversible; that is the whole point
// of having a plan phase at all.
// ============================================================
// EVENT CARD
// ============================================================

if (phase == "events" && event_current != undefined) {
    var _e = event_current;

    draw_set_alpha(0.80);
    draw_set_colour(make_colour_rgb(5, 7, 10));
    draw_rectangle(0, 0, 640, 360, false);
    draw_set_alpha(1);

    var CX = 128, CWD = 384;

    // MEASURE FIRST, then size the card. It was a fixed 280 tall with a
    // fixed 150 of that spent on the picture, which left about one line for
    // the body -- and then the choice loop's ui_room guard broke before
    // drawing anything, so a card with options showed none of them while
    // Step still cycled and applied them. The player chose blind.
    ui_font("display");
    var _tith = string_height("Ay") + 3;
    ui_font("body");

    var _bl = 0;
    var _bp = string_split(_e.body, "\n");
    for (var _bi = 0; _bi < array_length(_bp); _bi++)
        _bl += (_bp[_bi] == "") ? 1 : array_length(ui_wrap(_bp[_bi], CWD - 20));

    var _nch = array_length(_e.choices);

    // everything the card needs except the picture
    var _need = 8 + _tith + _bl * LH + 4 + _nch * LH + LH + 12;

    // THE PICTURE GETS WHAT IS LEFT, and is dropped rather than squashed
    // when the text needs the room. Text wins: an unreadable card is worse
    // than a card with no art.
    var CHT = min(336, _need + 158);
    var _ah = CHT - _need - 8;
    if (_ah < 76) { _ah = 0; CHT = min(336, _need); }
    var CY = max(12, floor((360 - CHT) / 2));

    draw_set_colour(make_colour_rgb(13, 15, 20));
    draw_rectangle(CX, CY, CX + CWD, CY + CHT, false);
    draw_set_colour(ui_col("you"));
    draw_rectangle(CX, CY, CX + CWD, CY + CHT, true);

    // ---- illustration, authored 368x150, aspect kept ----
    var _cur = CY + 8;
    if (_ah > 0) {
        var _aw = min(368, _ah * (368 / 150));
        var _ax = CX + floor((CWD - _aw) / 2);
        var _ay = CY + 8;
        var _spr = event_art(_e.kind);
        if (_spr != -1) {
            draw_sprite_stretched(_spr, 0, _ax, _ay, _aw, _ah);
        } else {
            draw_set_colour(make_colour_rgb(28, 33, 43));
            draw_rectangle(_ax, _ay, _ax + _aw, _ay + _ah, false);
            draw_set_colour(ui_col("faint"));
            draw_rectangle(_ax, _ay, _ax + _aw, _ay + _ah, true);
        }
        _cur = _ay + _ah + 8;
    }

    // a hand-rolled panel struct, since the card is not part of ui_layout
    var _tp = {
        x: CX + 10, y: CY, w: CWD - 20,
        inner_w: CWD - 20,
        cursor: _cur,
        bottom: CY + CHT - LH - 8
    };

    ui_font("display");
    ui_text(_tp.x, _tp.cursor, _e.title, ui_col("you"), _tp.inner_w);
    _tp.cursor += _tith;
    ui_font("body");

    ui_para(_tp, _e.body, ui_col("text"));
    _tp.cursor += 4;

    // NO ui_room GUARD ON THE CHOICES. The card is now sized to hold them,
    // and a choice the player cannot see is not a choice.
    if (_nch > 0) {
        for (var i = 0; i < _nch; i++) {
            var _sel = (i == event_pick);
            ui_text(_tp.x, _tp.cursor,
                    (_sel ? "> " : "  ") + _e.choices[i].label,
                    _sel ? ui_col("you") : ui_col("dim"), _tp.inner_w);
            _tp.cursor += LH;
        }
        ui_text(_tp.x, CY + CHT - LH - 4, "UP/DOWN choose    ENTER accept",
                ui_col("faint"), _tp.inner_w);
    } else {
        ui_text(_tp.x, CY + CHT - LH - 4, "ENTER to continue",
                ui_col("faint"), _tp.inner_w);
    }
}



// ---- the offer ----
if (tut_prompt) {
    draw_set_alpha(0.86);
    draw_set_colour(make_colour_rgb(5, 7, 10));
    draw_rectangle(0, 0, 640, 360, false);
    draw_set_alpha(1);
 
    var _pp = ui_panel(150, 120, 340, 130, "");
	ui_reserve(_pp, ui_line_h() + 4);
    ui_font("display");
    ui_text(_pp.x, _pp.cursor, "First time here?", ui_col("you"), _pp.inner_w);
    _pp.cursor += string_height("Ay") + 6;
    ui_font("body");
    ui_para(_pp, "I can walk you through the whole game. You can leave it "
                 + "at any point with ESC.", ui_col("text"));
    _pp.cursor += 6;
 
    var _opts = ["Walk me through it", "Just let me play"];
    for (var i = 0; i < 2; i++) {
        var _sel = (i == tut_prompt_pick);
        ui_text(_pp.x, _pp.cursor, (_sel ? "> " : "  ") + _opts[i],
                _sel ? ui_col("you") : ui_col("dim"), _pp.inner_w);
        _pp.cursor += ui_line_h();
    }
    ui_text(_pp.x, ui_footer_y(_pp), "UP/DOWN choose   ENTER",
		ui_col("faint"), _pp.inner_w);
    exit;
}
 
// ---- the cards ----
// Deliberately NOT a full-screen dim: the card sits at the bottom and the
// game stays visible above it, because every card is about something you
// are looking at. A tutorial that hides the thing it describes is a manual.
if (tut_active) {
    var _c = TUTORIAL[tut_step];
    var _lh3 = ui_line_h();
 
    // Point at what this card is about, by outlining that panel.
    var _box = -1;
    switch (_c.focus) {
        case "top":     _box = L.top;     break;
        case "roster":  _box = L.roster;  break;
        case "detail":  _box = L.detail;  break;
        case "council": _box = L.council; break;
        case "oaths":   _box = L.oaths;   break;
    }
    // L is `var L = ui_layout(N)` in this same event, declared above the
    // early exits, so it exists by the time we get here. If you ever move
    // this block above that line it will be undefined.
    if (is_struct(_box)) {
        draw_set_colour(ui_col("you"));
        draw_rectangle(_box.x - 2, _box.y - 2,
                       _box.x + _box.w + 2, _box.y + _box.h + 2, true);
    }

    // MEASURE THE CARD BEFORE DRAWING IT. The height was a fixed 116, which
    // only worked as long as no body wrapped past it. Fonts have to be set
    // before measuring, since every width and height here is font-relative.
    ui_font("display");
    var _tith = string_height("Ay") + 2;
    ui_font("body");

    var _blines = 0;
    var _bparas = string_split(_c.body, "\n");
    for (var _bi = 0; _bi < array_length(_bparas); _bi++)
        _blines += (_bparas[_bi] == "")
                 ? 1 : array_length(ui_wrap(_bparas[_bi], 588));

    // the card itself, bottom of the screen, over the council area
    var CH = clamp(8 + _tith + _blines * _lh3 + 4 + _lh3 + 8, 116, 240);
    
	// PUT THE CARD OPPOSITE WHAT IT IS POINTING AT. It lived at the bottom
    // permanently, and the cards about acting point at the council panel,
    // which is also at the bottom -- so the explanation sat on top of the
    // thing being explained. Driven off the panel's own rect rather than a
    // list of focus names, so a new card lands correctly for free.
    var CY = 360 - CH - 6;
    if (is_struct(_box) && (_box.y + _box.h * 0.5) > 180) CY = 6;
	
    draw_set_alpha(0.94);
    draw_set_colour(make_colour_rgb(10, 12, 17));
    draw_rectangle(14, CY, 626, CY + CH, false);
    draw_set_alpha(1);
    draw_set_colour(ui_col("you"));
    draw_rectangle(14, CY, 626, CY + CH, true);
 
    var _tp2 = {
        x: 26, y: CY, w: 588, inner_w: 588,
        cursor: CY + 8,
        bottom: CY + CH
    };
    ui_reserve(_tp2, _lh3 + 4);      // the footer's space, taken up front
 
    ui_font("display");
    ui_text(_tp2.x, _tp2.cursor, _c.title, ui_col("you"), _tp2.inner_w);
    _tp2.cursor += string_height("Ay") + 2;
    ui_font("body");
    ui_para(_tp2, _c.body, ui_col("text"));
 
    ui_font("label");
    ui_text(26, ui_footer_y(_tp2), string(tut_step + 1) + " of "
            + string(array_length(TUTORIAL)), ui_col("faint"));
    ui_text_right(614, ui_footer_y(_tp2),
                  "ENTER next    LEFT back    ESC skip the tutorial",
                  ui_col("faint"));
    ui_font("body");
    exit;
}