// ============================================================
// ASYNC - DIALOG
//
// The only dialog in the game is the Moth API key prompt.
// ============================================================
if (key_request != -1 && async_load[? "id"] == key_request) {
    key_request = -1;

    // A CANCEL MUST NOT WIPE A KEY THE PLAYER ALREADY HAD. Cancelling gives
    // back something that is not a string, and only a real string -- including
    // a deliberately empty one, which is how you clear it -- gets saved.
    if (ds_map_exists(async_load, "result")) {
        var _v = async_load[? "result"];
        if (is_string(_v)) {
            moth_key = string_trim(_v);
            settings_save();
            add_log((moth_key == "")
                ? "Key cleared. The world runs on the local simulation."
                : "Key accepted. Your kingdoms are measured on Moth's engine.",
                "ui");
        }
    }
}