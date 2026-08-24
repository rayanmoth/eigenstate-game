
// per-screen strength. The plan board has to stay readable, so it gets
// the least; the letter and the ending get to be moody.
var _vig   = 0.30;
var _grain = 0.030;
var _grid  = 0.000;
 
if (scene == "splash") { _vig = 0.58; _grain = 0.050; }
if (scene == "title")  { _vig = 0.50; _grain = 0.045; }
if (scene == "intro")  { _vig = 0.62; _grain = 0.055; }
 
if (scene == "play") {
    // THE GRID ONLY EXISTS IN THE GAME PROPER. The title and the letter
    // are the fiction; the plan board is the instrument panel. Putting the
    // cold layer only here is what makes the two halves of the look read
    // as deliberate rather than as a mixed palette.
    _grid = 0.014;
 
    // an audience hall is lit by one window, so lean into the falloff
    if (audience_of != -1) _vig = 0.44;
 
    // reading an event card should feel closer in than the board does
    if (phase == "events") _vig = 0.40;
}
 
if (game_over) { _vig = 0.72; _grain = 0.060; _grid = 0.010; }
 
if (_grid > 0) fx_grid(16, ui_col("quantum"), _grid);
fx_grain(140, _grain);
fx_vignette(_vig);
 
// one line sweeping down everything, seven seconds a pass. At 0.03 you
// will not catch it looking; you will notice if it is gone.
fx_scanline(7.0, 0.030);