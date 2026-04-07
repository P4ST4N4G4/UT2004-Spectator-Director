// CinematicSpectatorController - custom over-the-shoulder spectator camera
class CinematicSpectatorController extends xPlayer;

var float SwitchInterval, LastSwitchTime, ReturnToNormalTime, LingerDuration;
var float TargetRefreshInterval, CameraChangeCooldown, LastCameraChangeTime;
var float ScoreImportance;
var float CameraDistance, CameraHeight, CameraSideOffset;
var float LocationFollowSpeed, RotationFollowSpeed;
var float NextTargetRefreshTime, LastCameraUpdateTime;
var Controller CurrentTarget, KillerTarget;
var bool bInitialized, bAutoSwitchEnabled, bCinematicModeActive, bHasCameraState;
var vector CameraLocationState;
var rotator CameraRotationState;

defaultproperties
{
    SwitchInterval=3.0
    LingerDuration=5.0
    TargetRefreshInterval=0.5
    CameraChangeCooldown=5.0
    ScoreImportance=1.0
    CameraDistance=104.0
    CameraHeight=42.0
    CameraSideOffset=16.0
    LocationFollowSpeed=1.0
    RotationFollowSpeed=1.0
    bAutoSwitchEnabled=true
    bCinematicModeActive=false
    bBehindView=true
}

function PostBeginPlay()
{
    Super.PostBeginPlay();

    LastSwitchTime = Level.TimeSeconds;
    NextTargetRefreshTime = Level.TimeSeconds;
    LastCameraUpdateTime = Level.TimeSeconds;
    LastCameraChangeTime = Level.TimeSeconds - CameraChangeCooldown;
    ReturnToNormalTime = 0.0;
    bInitialized = false;
    bCinematicModeActive = false;
    bHasCameraState = false;

    if (PlayerReplicationInfo != None)
    {
        PlayerReplicationInfo.bOnlySpectator = true;
        PlayerReplicationInfo.bIsSpectator = true;
        PlayerReplicationInfo.bOutOfLives = true;
    }

    if (Pawn != None)
        UnPossess();

    SetViewTarget(self);
}

function NotifyKill(Controller Killer, Controller Killed)
{
    if (Killer == None || Killer == self || Killed == None || Killer == Killed)
        return;

    if (IsValidTarget(Killer))
    {
        KillerTarget = Killer;
        ReturnToNormalTime = Level.TimeSeconds + LingerDuration;
    }
}

event PlayerCalcView(out actor ViewActor, out vector CameraLocation, out rotator CameraRotation)
{
    local Pawn TargetPawn;
    local vector DesiredLocation;
    local rotator DesiredViewRotation;
    local float DeltaTime;

    UpdateTargetSelection();
    TargetPawn = GetObservedPawn();

    if (TargetPawn == None)
    {
        bCinematicModeActive = false;
        ViewActor = self;
        if (bHasCameraState)
        {
            CameraLocation = CameraLocationState;
            CameraRotation = CameraRotationState;
        }
        else
        {
            CameraLocation = Location;
            CameraRotation = Rotation;
        }
        return;
    }

    DesiredViewRotation = GetDesiredCameraRotation(TargetPawn);
    DesiredLocation = GetDesiredCameraLocation(TargetPawn, DesiredViewRotation);

    DeltaTime = Level.TimeSeconds - LastCameraUpdateTime;
    if (DeltaTime < 0.0)
        DeltaTime = 0.0;
    LastCameraUpdateTime = Level.TimeSeconds;

    if (!bHasCameraState || DeltaTime <= 0.0)
    {
        CameraLocationState = DesiredLocation;
        CameraRotationState = DesiredViewRotation;
        bHasCameraState = true;
    }
    else
    {
        CameraLocationState = SmoothVector(CameraLocationState, DesiredLocation, DeltaTime, LocationFollowSpeed);
        CameraRotationState = SmoothRotation(CameraRotationState, DesiredViewRotation, DeltaTime, RotationFollowSpeed);
    }

    bCinematicModeActive = true;
    ViewActor = self;
    CameraLocation = CameraLocationState;
    CameraRotation = CameraRotationState;
    SetRotation(CameraRotationState);
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

function Pawn GetObservedPawn()
{
    if (CurrentTarget != None && CurrentTarget.Pawn != None && !CurrentTarget.Pawn.bDeleteMe)
        return CurrentTarget.Pawn;

    if (Level.TimeSeconds - LastCameraChangeTime < CameraChangeCooldown)
        return None;

    if (SetObservedTarget(GetAnyValidTarget()))
    {
        return CurrentTarget.Pawn;
    }

    return None;
}

function rotator GetDesiredCameraRotation(Pawn TargetPawn)
{
    local rotator TargetRotation;

    if (TargetPawn == None)
        return Rotation;

    if (TargetPawn.Controller != None)
        TargetRotation = TargetPawn.GetViewRotation();
    else
        TargetRotation = TargetPawn.Rotation;

    TargetRotation.Roll = 0;
    return TargetRotation;
}

function vector GetDesiredCameraLocation(Pawn TargetPawn, rotator DesiredRotation)
{
    local rotator OffsetRotation;
    local vector FocusLocation, BackVector, RightVector, DesiredLocation;

    FocusLocation = TargetPawn.Location;
    FocusLocation.Z += CameraHeight;

    OffsetRotation = DesiredRotation;
    OffsetRotation.Pitch = 0;

    BackVector = vector(OffsetRotation);
    OffsetRotation.Yaw += 16384;
    RightVector = vector(OffsetRotation);

    DesiredLocation = FocusLocation;
    DesiredLocation -= BackVector * CameraDistance;
    DesiredLocation += RightVector * CameraSideOffset;

    return ClampCamera(TargetPawn, FocusLocation, DesiredLocation);
}

function vector ClampCamera(Pawn TargetPawn, vector FocusLocation, vector DesiredLocation)
{
    local vector HitLocation, HitNormal;

    if (Trace(HitLocation, HitNormal, DesiredLocation, FocusLocation, false, vect(8,8,8)) != None)
        return HitLocation + HitNormal * 8.0;

    return DesiredLocation;
}

function vector SmoothVector(vector CurrentValue, vector DesiredValue, float DeltaTime, float FollowSpeed)
{
    local float Alpha;

    Alpha = FClamp(DeltaTime * FollowSpeed, 0.0, 1.0);
    return CurrentValue + (DesiredValue - CurrentValue) * Alpha;
}

function rotator SmoothRotation(rotator CurrentValue, rotator DesiredValue, float DeltaTime, float FollowSpeed)
{
    local rotator Result;
    local float Alpha;

    if (FollowSpeed <= 0.0)
        return DesiredValue;

    Alpha = FClamp(DeltaTime * FollowSpeed, 0.0, 1.0);

    Result.Pitch = CurrentValue.Pitch + int(float(NormalizeAxis(DesiredValue.Pitch - CurrentValue.Pitch)) * Alpha);
    Result.Yaw = CurrentValue.Yaw + int(float(NormalizeAxis(DesiredValue.Yaw - CurrentValue.Yaw)) * Alpha);
    Result.Roll = 0;

    return Result;
}

function int NormalizeAxis(int Axis)
{
    while (Axis > 32767)
        Axis -= 65536;

    while (Axis < -32768)
        Axis += 65536;

    return Axis;
}

function Controller GetAnyValidTarget()
{
    local Controller C;

    foreach DynamicActors(class'Controller', C)
    {
        if (IsValidTarget(C))
            return C;
    }

    return None;
}

function bool CanChangeCamera(Controller NewTarget)
{
    if (NewTarget == None)
        return false;

    if (CurrentTarget == NewTarget)
        return true;

    if (CurrentTarget == None)
        return true;

    return (Level.TimeSeconds - LastCameraChangeTime >= CameraChangeCooldown);
}

function bool SetObservedTarget(Controller NewTarget)
{
    if (!IsValidTarget(NewTarget))
        return false;

    if (CurrentTarget == NewTarget)
        return true;

    if (!CanChangeCamera(NewTarget))
        return false;

    CurrentTarget = NewTarget;
    LastCameraChangeTime = Level.TimeSeconds;
    return true;
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
        SetObservedTarget(KillerTarget);
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
            if (SetObservedTarget(BestTarget))
            {
                LastSwitchTime = Level.TimeSeconds;
                return;
            }
        }
    }

    if (!IsValidTarget(CurrentTarget))
        SetObservedTarget(GetAnyValidTarget());
}

function float GetPlayerScore(Controller C)
{
    if (C == None || C.PlayerReplicationInfo == None)
        return 0.0;

    return C.PlayerReplicationInfo.Score * ScoreImportance;
}
