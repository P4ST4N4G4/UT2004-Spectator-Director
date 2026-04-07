// CinematicGame - Deathmatch based gametype that uses our spectator controller
// and custom game rules.
class CinematicGame extends xDeathMatch;

event InitGame(string Options, out string Error)
{
    Super.InitGame(Options, Error);

    if (Error == "")
        AddCinematicGameRules();
}

event PlayerController Login(string Portal, string Options, out string Error)
{
    if (Options != "")
        Options = "SpectatorOnly=1?" $ Options;
    else
        Options = "SpectatorOnly=1";

    return Super.Login(Portal, Options, Error);
}

function AddCinematicGameRules()
{
    local GameRules NewRules;

    NewRules = Spawn(class'CinematicGameRules');
    if (NewRules != None)
        AddGameModifier(NewRules);
    else
        Log("CinematicGame failed to spawn CinematicGameRules", 'Error');
}

defaultproperties
{
    GameName="Cinematic DeathMatch"
    Description="Spectator-only DeathMatch that automatically follows active players and recent kills."
    Acronym="CDM"
    BeaconName="CDM"
    PlayerControllerClassName="Spect.CinematicSpectatorController"
}
