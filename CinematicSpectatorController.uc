// CinematicSpectatorController - smart spectator camera
class CinematicSpectatorController extends xPlayer;

var float SwitchInterval, LastSwitchTime, ReturnToNormalTime, LingerDuration;
var float TargetRefreshInterval;
var float ScoreImportance;
var float CameraDistance;
var Controller CurrentTarget, KillerTarget;
var bool bInitialized;
var bool bAutoSwitchEnabled;
var bool bCinematicModeActive;
var float NextTargetRefreshTime;

defaultproperties
{
    SwitchInterval=3.0
    LingerDuration=5.0
    TargetRefreshInterval=0.5
    ScoreImportance=1.0
    CameraDistance=350.0
    bAutoSwitchEnabled=true
    bCinematicModeActive=false
    bBehindView=true
}

function PostBeginPlay()
{
    Super.PostBeginPlay();

    LastSwitchTime = Level.TimeSeconds;
    NextTargetRefreshTime = Level.TimeSeconds;
    ReturnToNormalTime = 0.0;
    bInitialized = false;
    bCinematicModeActive = false;

    if (PlayerReplicationInfo != None)
    {
        PlayerReplicationInfo.bOnlySpectator = true;
        PlayerReplicationInfo.bIsSpectator = true;
        PlayerReplicationInfo.bOutOfLives = true;
    }

    if (Pawn != None)
        UnPossess();

    bBehindView = true;
    CameraDist = CameraDistance;
    SetViewTarget(self);
}

event PlayerTick(float DeltaTime)
{
    Super.PlayerTick(DeltaTime);

    UpdateTargetSelection();
    UpdateViewTarget();
}

function NotifyKill(Controller Killer, Controller Killed)
{
    if (Killer == None || Killer == self || Killed == None || Killer == Killed)
        return;

    if (IsValidTarget(Killer))
    {
        KillerTarget = Killer;
        ReturnToNormalTime = Level.TimeSeconds + LingerDuration;
        CurrentTarget = KillerTarget;
        LastSwitchTime = Level.TimeSeconds;
        UpdateViewTarget();
    }
}

function UpdateTargetSelection()
{
    if (!bInitialized)
    {
        SelectCurrentTarget();
        bInitialized = true;
    }

    if (Level.TimeSeconds >= NextTargetRefreshTime)
    {
        SelectCurrentTarget();
        NextTargetRefreshTime = Level.TimeSeconds + FMax(TargetRefreshInterval, 0.1);
    }
}

function UpdateViewTarget()
{
    local Pawn TargetPawn;

    if (IsValidTarget(CurrentTarget))
        TargetPawn = CurrentTarget.Pawn;
    else
    {
        FindAnyValidTarget();
        if (IsValidTarget(CurrentTarget))
            TargetPawn = CurrentTarget.Pawn;
    }

    if (TargetPawn != None)
    {
        bCinematicModeActive = true;
        CameraDist = CameraDistance;
        if (ViewTarget != TargetPawn)
            SetViewTarget(TargetPawn);
    }
    else
    {
        bCinematicModeActive = false;
        if (ViewTarget != self)
            SetViewTarget(self);
    }
}

function FindAnyValidTarget()
{
    local Controller C;

    foreach DynamicActors(class'Controller', C)
    {
        if (IsValidTarget(C))
        {
            CurrentTarget = C;
            return;
        }
    }

    CurrentTarget = None;
}

function bool IsValidTarget(Controller C)
{
    if (C == None || C.Pawn == None)
        return false;

    if (C.Pawn.Health <= 0 || C.Pawn.bDeleteMe)
        return false;

    return (C.IsA('PlayerController') || C.IsA('Bot'));
}

function SelectCurrentTarget()
{
    local Controller C;
    local Controller BestTarget;
    local float BestScore, CandidateScore;

    if (KillerTarget != None && Level.TimeSeconds < ReturnToNormalTime && IsValidTarget(KillerTarget))
    {
        CurrentTarget = KillerTarget;
        return;
    }

    if (KillerTarget != None && (Level.TimeSeconds >= ReturnToNormalTime || !IsValidTarget(KillerTarget)))
        KillerTarget = None;

    if (bAutoSwitchEnabled && (Level.TimeSeconds - LastSwitchTime >= SwitchInterval))
    {
        BestScore = -999999.0;

        foreach DynamicActors(class'Controller', C)
        {
            if (IsValidTarget(C))
            {
                CandidateScore = GetPlayerScore(C);
                if (BestTarget == None || CandidateScore > BestScore)
                {
                    BestTarget = C;
                    BestScore = CandidateScore;
                }
            }
        }

        if (BestTarget != None)
        {
            CurrentTarget = BestTarget;
            LastSwitchTime = Level.TimeSeconds;
            return;
        }
    }

    if (!IsValidTarget(CurrentTarget))
        FindAnyValidTarget();
}

function float GetPlayerScore(Controller C)
{
    if (C == None || C.PlayerReplicationInfo == None)
        return 0.0;

    return C.PlayerReplicationInfo.Score * ScoreImportance;
}
