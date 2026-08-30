#pragma once

#include <string>
#define IMGUI_DEFINE_MATH_OPERATORS

#include "imgui.h"
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <iostream>
#include <filesystem>
#include <fstream>

enum class CrosshairType {
    FourSticks = 0,
    FourSticksRotated45,
    ThreeSticks,
    Triangle
};

struct CrosshairSettings {
    bool cross_enabled = false;

    ImColor color = ImColor(255, 255, 255, 255);
    float size = 5.0f;
    float thickness = 0.3f;
    float gap = 3.0f;

    bool outline_cross = false;
    ImColor outline_color = ImColor(50, 50, 50, 150);

    bool small_circle_enabled = false;
    float small_circle_radius = 5.0f;

    bool small_dot_enabled = false;
    float small_dot_radius = 0.7f;

    bool make_foreground = true;

    CrosshairType type = CrosshairType::FourSticks;
};

struct MiniMapSettings {
    float MapSize = 150.0f;
    int MapZoom = 1;

    bool bDayTimeMode = false;
    float fDayTime = 5.0f;

    // int MapTransparency = 255;
    ImColor MapColor = ImColor(1.0f, 1.0f, 1.0f, 1.0f);
};

class Settings
{
public:
    bool StreamerMode = false;

    // ImVec2 MenuSize;
    // ImVec2 MenuPos;

    float FOV = 1.0f;
    bool GhostMode = false;

    bool EnableTime = false;
    float DayCycleSky = 6.0f;
    float DayCycle = 60.0f;
    float DirLight = 50.0f;
    float ReflectionMult = 50.0f;
    bool NoScopeOverlay = false;
    bool NoScopeSway = false;
    bool TameShooting = false;
    bool AutoArmor = false;
    bool AutoPickupEggs = false;
    bool AutoMeds = false;
    bool AutoRemount = false;
    bool AutoSteal = false;
    bool LootPlayers = false;
    bool LootTurrets = false;
    bool LootContainers = false;
    bool LootSupplyCrates = false;
    bool ForceOptimizeGame = false;

    float DrawScale = 1.0f;

    struct ExtrasensoryPerception
    {
        bool Enable = false;
        float Scale = 1.5f;

        bool PlayerChams = false;
        bool DinoChams = false;
        bool StructureChams = false;

        bool Players = false;
        bool Dead = false;
        bool Sleeping = false;
        bool Tracers = false;
        bool HPBar = false;
        bool Armor = false;
        bool Buffs = false;
        bool Weapon = false;
        bool Box2D = false;
        bool Box3D = false;
        bool ShotTraces = false;
        bool Skeleton = false;
        bool TeamPlayers = false;
        bool AllyPlayers = false;

        bool Dinosaurs = false;
        int MinDinoLevel = 150;
        bool WildDino = false;
        bool TeamDino = false;
        bool AllyDino = false;

        bool Structures = false;
        bool TeamStructures = false;
        bool AllyStructures = false;
        bool Containers = false;
        bool Beds = false;
        bool Explosives = false;
        bool Turrets = false;
        bool SupplyCrate = false;
        bool ItemCache = false;
        bool PlantX = false;
        bool Generator = false;
        bool Teleporter = false;
        int MaxDistance = 3000;

        bool Resources = false;
        bool Metal = false;
        bool Oil = false;
        bool Obsidian = false;
        bool Perl = false;
        bool Crystal = false;
        bool ExplorerNotes = false;

        bool Eggs = false;

        bool HideStructureSwitch = false;
        bool HideResourceSwitch = false;
        bool HideDinosaurSwitch = false;

        bool HideStructure = false;
        bool HideDinosaur = false;
        bool HideResource = false;

        float PlayerAllyColor[3] = {0.0f, 1.0f, 1.0f};
        float PlayerTeamColor[3] = {0.0f, 1.0f, 0.0f};
        float PlayerEnemyColor[3] = {1.0f, 0.0f, 0.0f};

        float StructureAllyColor[3] = {0.0f, 1.0f, 1.0f};
        float StructureTeamColor[3] = {0.0f, 1.0f, 0.0f};

        float ContainersColor[3] = {1.0f, 0.0f, 0.0f};
        float BedsColor[3] = {1.0f, 0.0f, 0.0f};
        float ExplosivesColor[3] = {1.0f, 0.0f, 0.0f};
        float TurretsColor[3] = {1.0f, 0.0f, 0.0f};
        float SupplyCrateColor[3] = {1.0f, 0.0f, 0.0f};
        float PlantXColor[3] = {1.0f, 0.0f, 0.0f};
        float ItemCacheColor[3] = {1.0f, 0.0f, 0.0f};

        float DinoWildColor[3] = {1.0f, 1.0f, 0.0f};
        float DinoAllyColor[3] = {0.0f, 1.0f, 1.0f};
        float DinoTeamColor[3] = {0.0f, 1.0f, 0.0f};
        float DinoEnemyColor[3] = {1.0f, 0.0f, 0.0f};

        float ResourceColor[3] = {1.0f, 1.0f, 1.0f};

        bool UseDinoSearch = false;
        bool AllDinosaurs[123] = {false};

        bool ShowDinoGender = false;
        bool ShowDinoHealth = false;
        bool ShowDinoInfo = false;
    };

    ExtrasensoryPerception esp;


    bool UsePlayerSpeed = false;

    float PlayerSpeed = 1.0f;

    bool Freeze = false;

    bool EnableAimbot = false;
    int AimType = 0;

    bool StartCracking = false;

    bool InfiniteWeight = false;

    bool ShowFloatingDamage = false;

    bool AimAtWeakestArmor = false;
    int AimTargetIndex = 0;

    bool NoRecoil = false;

    bool UnlockRotation = false;

    bool NoTekRifleOverheat = false;
    bool UnlockEngrams = false;
    bool RemoveBolaOrTrap = false;

    bool SelfC4 = false;
    bool FloatingStructures = false;

    bool StructureFlip = false;
    float FlipPitch = 180.0f;
    float FlipYaw = 180.0f;
    float FlipRoll = 180.0f;


    bool ShieldBypass = false;
    bool NoSpawnAnim = false;
    float PingScale = 1.0f;

    bool InfFabiPistolAmmo = false;

    bool JoinNotifications = false;

    bool PlacementDupe = false;
    bool CustomPlacement = false;
    int PlacingStructureIndex = 0;

    bool InstantTurn = false;
    bool Strafing = false;

    bool SubmergedFiring = false;
    bool AutoFire = false;
    bool NoSpread = false;
    bool BulletBurst = false;
    bool ProjectileSpam = false;
    bool TapToBedTeleport = false;

    bool ShowAutoFireSwitch = false;
    bool ShowFreezeSwitch = false;
    bool LockAim = false;
    bool QuickTurn = false;

    int MaterialIndex = 0;
    int MaterialAmount = 2000;

    bool CrashPlayersAim = false;
    bool BallistaSpam = false;
    bool AutoExplosions = false;
    bool HealDinosaur = false;
    bool HideLogin = false;
    float FreeCamDistance = 1.0f;
    float TPVCameraOffsetX = 40.0f;
    float TPVCameraOffsetY = 60.0f;
    float FPS = 60.0f;
    bool Ragebot = false;

    float PermBodyColor[3] = {1.0f, 0.0f, 0.0f};
    float PermHairColor[3] = {1.0f, 0.0f, 0.0f};

    float BodyColorValue = 0.0f;
    float EyeColorValue = 0.0f;
    float HairColorValue = 0.0f;

    bool UsePermenantColors = false;
    bool UseDynamicColors = false;

    float DynamicBodyColor[3] = {1.0f, 0.0f, 0.0f};
    float DynamicHairColor[3] = {1.0f, 0.0f, 0.0f};

    bool BigGun = false;
    float DinoSpeed = 1.0f;

    bool SlowMountedDino = false;
    bool InfiniteC4 = false;
    bool NoKnockoutBlur = false;

    bool AutoPincodeTurrets = false;
    int CurrentPinCode = 0;
    bool AutoFillTurrets = false;
    int MaxBulletsPerTurret = 150;
    bool AutoActivateTurrets = false;
    bool AutoRangeSettings = false;
    int CurrentRangeSetting = 3;
    bool AutoTargetSettings = false;
    int CurrentTargetSetting = 2;
    bool EnableTurretSettings = false;
    bool AutoStamina = false;
    bool AutoDestroyBot = false;
    bool NoReloadShotgun = false;
    bool FakePrimal = false;

    bool SlowDinosAimbot = false;
    bool AutoGrabPlayers = false;

    bool AutoDropItems = false;
    int ItemTypeFilter = 9;
    int EquipmentTypeFilter = 10;
    int ConsumableTypeFilter = 4;

    bool SelfArmorESP = false;
    bool SelfBoneESP = false;
    bool Self3DBoxESP = false;

    bool ChatSpam = false;

    bool AutoNameTurrets = false;

    bool UseAimFOV = false;
    int AimFOVRadius = 100;

    CrosshairSettings g_CrosshairSettings;

    bool MapEnabled = false;
    MiniMapSettings MapSetting;

    bool AllowWindowMove = false;

    bool BowAimbot = false;

public:

    static Settings& GetInstance()
    {
        static Settings Instance{};
        return Instance;
    }

    static inline std::filesystem::path FilePath = std::filesystem::path(std::string(getenv("HOME")) + "/Documents/Settings.txt");

    void Save()
    {
        std::ofstream OutFile(FilePath, std::ios::binary | std::ios::trunc);
        OutFile.write(reinterpret_cast<const char*>(this), sizeof(Settings));
        OutFile.close();
    }

    void Load()
    {
        if (std::filesystem::exists(FilePath))
        {
            std::ifstream InFile(FilePath, std::ios::binary);
            InFile.read(reinterpret_cast<char*>(this), sizeof(Settings));
            InFile.close();
        }
    }

    void Reset()
    {
        *this = Settings{};
        return Save();
    }

private:

    Settings() { };
    ~Settings() { };
};

