// On a real quit, stop the server we started. On an F5 restart, leave it
// up -- Create will post /newgame again and get an answer in a second
// instead of waiting out another 30-second boot.
if (!restarting) server_shutdown();
 
// (I am not certain GameMaker fires Game End on game_restart, and it
// differs by version. This guard makes it not matter either way, which is
// better than finding out live.)