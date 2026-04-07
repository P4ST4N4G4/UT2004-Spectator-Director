// CinematicGameRules - Listens for frags and notifies the spectator controller
class CinematicGameRules extends GameRules;

function ScoreKill(Controller Killer, Controller Killed)
{
    local CinematicSpectatorController Spec;

    if (Killer != None && Killed != None && Killer != Killed)
    {
        foreach DynamicActors(class'CinematicSpectatorController', Spec)
        {
            Spec.NotifyKill(Killer, Killed);
        }
    }

    // Always propagate to next GameRules in chain.
    if (NextGameRules != None)
        NextGameRules.ScoreKill(Killer, Killed);
}

defaultproperties
{
}
