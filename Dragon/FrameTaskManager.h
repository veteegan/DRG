#pragma once

#include "MenuLoad/Includes.h"
#include "Source/CppSDK/SDK/Basic.hpp"
#include "Source/CppSDK/SDK/CoreUObject_classes.hpp"
#include "Source/CppSDK/SDK/CoreUObject_structs.hpp"
#include "Source/CppSDK/SDK/Engine_classes.hpp"
#include "Source/CppSDK/SDK/Engine_structs.hpp"
#include "Source/CppSDK/SDK/ShooterGame_classes.hpp"
#include "Utilities/Memory.h"
#include "Utilities/Variables.h"
#include "Source/CppSDK/UsedSDK.hpp"
#include <queue>
#include <functional>
#include <thread>
#include <chrono>
#include "DinoNames.h"
#include "Menu/Map.h"

#import <Foundation/Foundation.h>

inline std::atomic<FVector> LatLonRot;

enum class EIconType : uint8
{
    GenderMale,
    GenderFemale,
    Knocked,
    Skull
};

inline FLinearColor ConvertToFLinearColor(float rgb[3])
{
    return FLinearColor(rgb[0], rgb[1], rgb[2], 1.0f);
}

template<class T>
inline TWeakObjectPtr<T> ToWeakPtr(UObject* Object)
{
    TWeakObjectPtr<T> Ret;
    Ret.ObjectIndex = Object->Index;
    Ret.ObjectSerialNumber = UObject::GObjects->GetItemByIndex(Object->Index)->SerialNumber;
    return Ret;
};

class FFunctionQueue
{
private:
    std::queue<std::function<void()>> Functions; // queue of functions to be executed
public:

    void add(std::function<void()> function) // adding a function to the queue
    {
        Functions.push(function);
    }

    void release() // calling the functions in a row (one per tick)
    {
        while(!Functions.empty())
        {
            auto fn = Functions.front();
            fn();
            Functions.pop();
        }
    }
};

inline FFunctionQueue ExecutionQueue;

template<typename T>
class FTickQueue
{
private:
    std::queue<std::function<void(T*)>> Functions;
public:

    void Add(std::function<void(T*)> function)
    {
        Functions.push(function);
    }

    void Release(T* Obj)
    {
        while(!Functions.empty())
        {
            auto fn = Functions.front();
            fn(Obj);
            Functions.pop();
        }
    }
};

inline std::string CurrentDropItemFilterString = "";

inline FTickQueue<AShooterPlayerController> ShooterPlayerControllerQueue;
inline FTickQueue<UShooterEngine> GameEngineQueue;
inline FTickQueue<AShooterPlayerState> PlayerStateQueue;

namespace FNames
{
#define INIT_FNAME(Name) inline FName Name;

    INIT_FNAME(ExplorerChest_Base_C)
    INIT_FNAME(DeathItemCache_PlayerDeath_C)
    INIT_FNAME(DeathItemCache_C)
    INIT_FNAME(MainMenu)
    INIT_FNAME(TheIsland)
    INIT_FNAME(ScorchedEarth_P)
    INIT_FNAME(Aberration_P)
    INIT_FNAME(Ragnarok)
    INIT_FNAME(Extinction)
    INIT_FNAME(Genesis)
    INIT_FNAME(Gen2)
    INIT_FNAME(theisland_ruins)
    INIT_FNAME(ExplorerNotes)
    INIT_FNAME(AB_SupplyDrops)
    INIT_FNAME(PrimalItemAmmo_AdvancedRifleBullet_C)
    INIT_FNAME(PrimalItemResource_ElementShard_C)
    INIT_FNAME(StructureTurretTek_C)
    INIT_FNAME(Buff_TekArmor_Shirt_Rework_C)
    INIT_FNAME(Buff_TekArmor_Gloves_C)
    INIT_FNAME(WeapTekSniper_C)
    INIT_FNAME(WeapMachinedShotgun_C)
    INIT_FNAME(WeapMachinedShotgun_Flashlight_C)
    INIT_FNAME(WeapMachinedShotgun_HoloScope_C)
    INIT_FNAME(WeapMachinedShotgun_Laser_C)
    INIT_FNAME(WeapMachinedShotgun_Scope_C)
    INIT_FNAME(WeapBola_C)
    INIT_FNAME(WeapFists_C)
    INIT_FNAME(WeapFists_Female_C)
    INIT_FNAME(Buff_Bola_C)
    INIT_FNAME(BearTrap_C)
    INIT_FNAME(BearTrapLarge_C)
    INIT_FNAME(WeapMachinedPistol_C)
    INIT_FNAME(WeapMachinedPistol_Flashlight_C)
    INIT_FNAME(WeapMachinedPistol_HoloScope_C)
    INIT_FNAME(WeapMachinedPistol_Laser1_C)
    INIT_FNAME(WeapMachinedPistol_Scoped_C)
    INIT_FNAME(WeapMachinedPistol_Silencer_C)
    INIT_FNAME(WeapC4_C)
    INIT_FNAME(WeapTekRifle_C)
    INIT_FNAME(PrimalItemConsumable_HealSoup_C)
    INIT_FNAME(PrimalItemConsumable_StaminaSoup_C)
    INIT_FNAME(Body)
    INIT_FNAME(Hair)
    INIT_FNAME(Buff_FlyerSlowdown_C)
    INIT_FNAME(FirstPerson)


    namespace Func
    {
        INIT_FNAME(ServerFireProjectileEx)
        INIT_FNAME(ServerNotifyShot)
        INIT_FNAME(BPFireWeapon)
        INIT_FNAME(BP_GetCustomModifier_RotationRate)
        INIT_FNAME(ClientNotifyRespawned)
        INIT_FNAME(ServerMultiUse)
        INIT_FNAME(ServerChatLogin)
        INIT_FNAME(ServerRequestPlaceStructure)
        INIT_FNAME(PlayHitEffectPoint)
        INIT_FNAME(PlayHitEffectRadial)
        INIT_FNAME(PlayHitEffectGeneric)
        INIT_FNAME(ServerSendBadPlayer)
        INIT_FNAME(ServerSendChatMessage)
    }

#undef INIT_FNAME

    FORCEINLINE void FindAll()
    {
#define SET_FNAME(Name) Name = FName(L## #Name);

        SET_FNAME(ExplorerChest_Base_C)
        SET_FNAME(DeathItemCache_PlayerDeath_C)
        SET_FNAME(DeathItemCache_C)
        SET_FNAME(MainMenu)
        SET_FNAME(TheIsland)
        SET_FNAME(ScorchedEarth_P)
        SET_FNAME(Aberration_P)
        SET_FNAME(Ragnarok)
        SET_FNAME(Extinction)
        SET_FNAME(Genesis)
        SET_FNAME(Gen2)
        SET_FNAME(theisland_ruins)
        SET_FNAME(ExplorerNotes)
        SET_FNAME(AB_SupplyDrops)
        SET_FNAME(PrimalItemAmmo_AdvancedRifleBullet_C)
        SET_FNAME(PrimalItemResource_ElementShard_C)
        SET_FNAME(StructureTurretTek_C)
        SET_FNAME(Buff_TekArmor_Shirt_Rework_C)
        SET_FNAME(Buff_TekArmor_Gloves_C)
        SET_FNAME(WeapTekSniper_C)
        SET_FNAME(WeapMachinedShotgun_C)
        SET_FNAME(WeapMachinedShotgun_Flashlight_C)
        SET_FNAME(WeapMachinedShotgun_HoloScope_C)
        SET_FNAME(WeapMachinedShotgun_Laser_C)
        SET_FNAME(WeapMachinedShotgun_Scope_C)
        SET_FNAME(WeapBola_C)
        SET_FNAME(WeapFists_C)
        SET_FNAME(WeapFists_Female_C)
        SET_FNAME(Buff_Bola_C)
        SET_FNAME(BearTrap_C)
        SET_FNAME(BearTrapLarge_C)
        SET_FNAME(WeapMachinedPistol_C)
        SET_FNAME(WeapMachinedPistol_Flashlight_C)
        SET_FNAME(WeapMachinedPistol_HoloScope_C)
        SET_FNAME(WeapMachinedPistol_Laser1_C)
        SET_FNAME(WeapMachinedPistol_Scoped_C)
        SET_FNAME(WeapMachinedPistol_Silencer_C)
        SET_FNAME(WeapC4_C)
        SET_FNAME(WeapTekRifle_C)
        SET_FNAME(PrimalItemConsumable_HealSoup_C)
        SET_FNAME(PrimalItemConsumable_StaminaSoup_C)
        SET_FNAME(Body)
        SET_FNAME(Hair)
        SET_FNAME(Buff_FlyerSlowdown_C)
        SET_FNAME(FirstPerson)

        Func::SET_FNAME(ServerNotifyShot)
        Func::SET_FNAME(BPFireWeapon)
        Func::SET_FNAME(BP_GetCustomModifier_RotationRate)
        Func::SET_FNAME(ClientNotifyRespawned)
        Func::SET_FNAME(ServerMultiUse)
        Func::SET_FNAME(ServerChatLogin)
        Func::SET_FNAME(ServerRequestPlaceStructure)
        Func::SET_FNAME(PlayHitEffectPoint)
        Func::SET_FNAME(PlayHitEffectRadial)
        Func::SET_FNAME(PlayHitEffectGeneric)
        Func::SET_FNAME(ServerSendBadPlayer)
        Func::SET_FNAME(ServerFireProjectileEx)
        Func::SET_FNAME(ServerSendChatMessage)
#undef SET_FNAME
    }
}





enum class EActorAssociation : uint8
{
    Enemy,
    Wild,
    Team,
    Ally,
    Admin
};

enum class EActorType : uint8
{
    Player,
    Dinosaur,
    Structure,
    FoliageActor,
    Foliage,
    Egg,
    None,
    Unknown
};

enum class EActorSpecificType : uint8
{
    Bed,
    Turret,
    Container,
    SupplyCrate,
    ItemCache,
    PlantX,
    Explosive,
    Metal,
    Oil,
    Perl,
    Crystal,
    Obsidian,
    BlackPerl,
    ExplorerNote,
    Generator,
    None
};


struct FActorInfo
{
    std::wstring Name;
    EActorType Type;
    EActorSpecificType SpecificType;

    FActorInfo() : Name(L""), Type(EActorType::Unknown), SpecificType(EActorSpecificType::None) {}
    FActorInfo(std::wstring&& _Name, EActorType _Type, EActorSpecificType _SpecificType = EActorSpecificType::None) : Name(std::move(_Name)), Type(_Type), SpecificType(_SpecificType) {}

    static const FActorInfo& None()
    {
        static FActorInfo s_None(L"None", EActorType::None);
        return s_None;
    }
};

struct FPlayerActorData
{
    std::wstring Name;
    AShooterCharacter* ThePlayer;
    FVector2D TopLocation;
    FVector2D BottomLocation;
    EActorType Type;
    EActorAssociation Association;
    FLinearColor DrawColor;
    bool IsVisible;


    FPlayerActorData()
            : Name(L""), ThePlayer(nullptr), TopLocation(FVector2D(0.0f, 0.0f)), Type(EActorType::None), Association(EActorAssociation::Enemy), IsVisible(false), DrawColor(FLinearColor()) {}

    FPlayerActorData(std::wstring&& _Name, AShooterCharacter* _ThePlayer, FVector2D _TopLocation, FVector2D _BottomLocation, EActorType _Type, EActorAssociation _Association, bool _IsVisible, FLinearColor _DrawColor) noexcept
            : Name(std::move(_Name)), ThePlayer(_ThePlayer), TopLocation(_TopLocation), BottomLocation(_BottomLocation), Type(_Type), Association(_Association), IsVisible(_IsVisible), DrawColor(_DrawColor) {}

};

struct FOtherActorData
{
    std::wstring Name;
    AActor* TheActor;
    FVector2D Location;
    FLinearColor DrawColor;
    EActorType Type;
    EActorSpecificType SpecType;


    FOtherActorData()
            : Name(L""), TheActor(nullptr), Location(FVector2D(0.0f, 0.0f)), Type(EActorType::None), SpecType(EActorSpecificType::None), DrawColor(FLinearColor()) {}

    FOtherActorData(std::wstring&& _Name, AActor* _TheActor, FVector2D _Location, EActorType _Type, EActorSpecificType _SpecType, FLinearColor _DrawColor) noexcept
            : Name(std::move(_Name)), TheActor(_TheActor), Location(_Location), Type(_Type), SpecType(_SpecType), DrawColor(_DrawColor) {}

};

namespace FemaleBones
{
    enum Type
    {
        ROOT_JNT_SKL = 0,
        Cnt_Pelvis_000_JNT_SKL = 1,
        Cnt_Spine_001_JNT_SKL = 2,
        Cnt_Spine_002_JNT_SKL = 3,
        Cnt_Spine_003_JNT_SKL = 4,
        Cnt_Chest_000_JNT_SKL = 5,
        Cnt_Neck_Joint000_JNT_SKL = 6,
        Cnt_Neck_Joint001_JNT_SKL = 7,
        Cnt_Head_JNT_SKL = 8,
        Cnt_Jaw000_JNT_SKL = 9,
        d_L_lowerLip_jnt = 10,
        d_C_lowerLip_jnt = 11,
        d_R_lowerLip_jnt1 = 12,
        d_C_upperLip_jnt = 13,
        d_L_upperLip_jnt = 14,
        d_L_mouthCorner_jnt = 15,
        d_L_cheekBone_jnt = 16,
        d_L_browStart_jnt = 17,
        d_L_browEnd_jnt = 18,
        Lft_EyeBall_JNT_SKL = 19,
        Lft_EyeBottomLid_JNT_SKL = 20,
        Lft_EyeTopLid_JNT_SKL = 21,
        d_R_browStart_jnt = 22,
        d_R_browEnd_jnt = 23,
        d_R_cheekBone_jnt1 = 24,
        d_R_upperLip_jnt1 = 25,
        d_R_mouthCorner_jnt1 = 26,
        Rht_EyeBall_JNT_SKL = 27,
        Rht_EyeBottomLid_JNT_SKL = 28,
        Rht_EyeTopLid_JNT_SKL = 29,
        d_R_browMid_jnt = 30,
        d_L_browMid_jnt = 31,
        Lft_Arm_Clav000_JNT_SKL = 32,
        Lft_Arm_001Tear000_JNT_SKL = 33,
        Lft_Arm_001Tear003_JNT_SKL = 34,
        Lft_shoulder_helper_JNT_SKL = 35,
        Lft_Arm_002Tear000_JNT_SKL = 36,
        Lft_Arm_002Tear003_JNT_SKL = 37,
        Lft_Arm_002Tear006_JNT_SKL = 38,
        Lft_Thumb_000_JNT_SKL = 39,
        Lft_Thumb_001_JNT_SKL = 40,
        Lft_Thumb_002_JNT_SKL = 41,
        Lft_IndexFinger_000_JNT_SKL = 42,
        Lft_IndexFinger_001_JNT_SKL = 43,
        Lft_IndexFinger_002_JNT_SKL = 44,
        Lft_MiddleFinger_000_JNT_SKL = 45,
        Lft_MiddleFinger_001_JNT_SKL = 46,
        Lft_MiddleFinger_002_JNT_SKL = 47,
        Lft_RingFinger_000_JNT_SKL = 48,
        Lft_RingFinger_001_JNT_SKL = 49,
        Lft_RingFinger_002_JNT_SKL = 50,
        Lft_LittleFinger_000_JNT_SKL = 51,
        Lft_LittleFinger_001_JNT_SKL = 52,
        Lft_LittleFinger_002_JNT_SKL = 53,
        c_L_weapon_jnt = 54,
        c_L_attatch_jnt = 55,
        Lft_Breast_JNT_SKL = 56,
        Rht_Breast_JNT_SKL = 57,
        Rht_Arm_Clav000_JNT_SKL = 58,
        Rht_Arm_001Tear000_JNT_SKL = 59,
        Rht_Arm_001Tear003_JNT_SKL = 60,
        Rht_shoulder_helper_JNT_SKL = 61,
        Rht_Arm_002Tear000_JNT_SKL = 62,
        Rht_Arm_002Tear003_JNT_SKL = 63,
        Rht_Arm_002Tear006_JNT_SKL = 64,
        Rht_LittleFinger_000_JNT_SKL = 65,
        Rht_LittleFinger_001_JNT_SKL = 66,
        Rht_LittleFinger_002_JNT_SKL = 67,
        Rht_RingFinger_000_JNT_SKL = 68,
        Rht_RingFinger_001_JNT_SKL = 69,
        Rht_RingFinger_002_JNT_SKL = 70,
        Rht_MiddleFinger_000_JNT_SKL = 71,
        Rht_MiddleFinger_001_JNT_SKL = 72,
        Rht_MiddleFinger_002_JNT_SKL = 73,
        Rht_IndexFinger_000_JNT_SKL = 74,
        Rht_IndexFinger_001_JNT_SKL = 75,
        Rht_IndexFinger_002_JNT_SKL = 76,
        c_R_weapon_jnt = 77,
        Rht_Thumb_000_JNT_SKL = 78,
        Rht_Thumb_001_JNT_SKL = 79,
        Rht_Thumb_002_JNT_SKL = 80,
        c_R_attatch_jnt = 81,
        Lft_Leg_001Tear000_JNT_SKL = 82,
        Lft_Leg_001Tear003_JNT_SKL = 83,
        Lft_Leg_002Tear000_JNT_SKL = 84,
        Lft_Leg_002Tear003_JNT_SKL = 85,
        Lft_Leg_002_JNT_SKL = 86,
        Lft_Leg_003_JNT_SKL = 87,
        Rht_Leg_001Tear000_JNT_SKL = 88,
        Rht_Leg_001Tear003_JNT_SKL = 89,
        Rht_Leg_002Tear000_JNT_SKL = 90,
        Rht_Leg_002Tear003_JNT_SKL = 91,
        Rht_Leg_002_JNT_SKL = 92,
        Rht_Leg_003_JNT_SKL = 93
    };
}

namespace MaleBones
{
    enum Type
    {
        ROOT_JNT_SKL = 0,
        Cnt_Pelvis_000_JNT_SKL = 1,
        Cnt_Spine_001_JNT_SKL = 2,
        Cnt_Spine_002_JNT_SKL = 3,
        Cnt_Spine_003_JNT_SKL = 4,
        Cnt_Chest_000_JNT_SKL = 5,
        Cnt_Neck_Joint000_JNT_SKL = 6,
        Cnt_Neck_Joint001_JNT_SKL = 7,
        Cnt_Head_JNT_SKL = 8,
        Lft_EyeBall_JNT_SKL = 9,
        Lft_EyeBottomLid_JNT_SKL = 10,
        Lft_EyeTopLid_JNT_SKL = 11,
        Rht_EyeBall_JNT_SKL = 12,
        Rht_EyeBottomLid_JNT_SKL = 13,
        Rht_EyeTopLid_JNT_SKL = 14,
        d_C_upperLip_jnt = 15,
        d_L_upperLip_jnt = 16,
        d_R_upperLip_jnt = 17,
        d_L_cheekBone_jnt = 18,
        d_R_cheekBone_jnt = 19,
        d_R_browStart_jnt = 20,
        d_R_browMid_jnt = 21,
        d_R_browEnd_jnt = 22,
        d_L_browEnd_jnt = 23,
        d_L_browMid_jnt = 24,
        d_L_browStart_jnt = 25,
        d_L_mouthCorner_jnt = 26,
        Cnt_Jaw000_JNT_SKL = 27,
        d_C_lowerLip_jnt = 28,
        d_L_lowerLip_jnt = 29,
        d_R_lowerLip_jnt = 30,
        d_R_mouthCorner_jnt = 31,
        Lft_Arm_Clav000_JNT_SKL = 32,
        Lft_Arm_001Tear000_JNT_SKL = 33,
        Lft_Arm_001Tear003_JNT_SKL = 34,
        Lft_shoulder_helper_JNT_SKL = 35,
        Lft_Arm_002Tear000_JNT_SKL = 36,
        Lft_Arm_002Tear003_JNT_SKL = 37,
        Lft_Arm_002Tear006_JNT_SKL = 38,
        Lft_Thumb_000_JNT_SKL = 39,
        Lft_Thumb_001_JNT_SKL = 40,
        Lft_Thumb_002_JNT_SKL = 41,
        Lft_IndexFinger_000_JNT_SKL = 42,
        Lft_IndexFinger_001_JNT_SKL = 43,
        Lft_IndexFinger_002_JNT_SKL = 44,
        Lft_MiddleFinger_000_JNT_SKL = 45,
        Lft_MiddleFinger_001_JNT_SKL = 46,
        Lft_MiddleFinger_002_JNT_SKL = 47,
        Lft_RingFinger_000_JNT_SKL = 48,
        Lft_RingFinger_001_JNT_SKL = 49,
        Lft_RingFinger_002_JNT_SKL = 50,
        Lft_LittleFinger_000_JNT_SKL = 51,
        Lft_LittleFinger_001_JNT_SKL = 52,
        Lft_LittleFinger_002_JNT_SKL = 53,
        c_L_weapon_jnt = 54,
        c_L_attatch_jnt = 55,
        Rht_Arm_Clav000_JNT_SKL = 56,
        Rht_Arm_001Tear000_JNT_SKL = 57,
        Rht_Arm_001Tear003_JNT_SKL = 58,
        Rht_shoulder_helper_JNT_SKL = 59,
        Rht_Arm_002Tear000_JNT_SKL = 60,
        Rht_Arm_002Tear003_JNT_SKL = 61,
        Rht_Arm_002Tear006_JNT_SKL = 62,
        Rht_Thumb_000_JNT_SKL = 63,
        Rht_Thumb_001_JNT_SKL = 64,
        Rht_Thumb_002_JNT_SKL = 65,
        Rht_IndexFinger_000_JNT_SKL = 66,
        Rht_IndexFinger_001_JNT_SKL = 67,
        Rht_IndexFinger_002_JNT_SKL = 68,
        Rht_MiddleFinger_000_JNT_SKL = 69,
        Rht_MiddleFinger_001_JNT_SKL = 70,
        Rht_MiddleFinger_002_JNT_SKL = 71,
        Rht_RingFinger_000_JNT_SKL = 72,
        Rht_RingFinger_001_JNT_SKL = 73,
        Rht_RingFinger_002_JNT_SKL = 74,
        Rht_LittleFinger_000_JNT_SKL = 75,
        Rht_LittleFinger_001_JNT_SKL = 76,
        Rht_LittleFinger_002_JNT_SKL = 77,
        c_R_weapon_jnt = 78,
        c_R_attatch_jnt = 79,
        Lft_Leg_001Tear000_JNT_SKL = 80,
        Lft_Leg_001Tear003_JNT_SKL = 81,
        Lft_Leg_002Tear000_JNT_SKL = 82,
        Lft_Leg_002Tear003_JNT_SKL = 83,
        Lft_Leg_002_JNT_SKL = 84,
        Lft_Leg_003_JNT_SKL = 85,
        Rht_Leg_001Tear000_JNT_SKL = 86,
        Rht_Leg_001Tear003_JNT_SKL = 87,
        Rht_Leg_002Tear000_JNT_SKL = 88,
        Rht_Leg_002Tear003_JNT_SKL = 89,
        Rht_Leg_002_JNT_SKL = 90,
        Rht_Leg_003_JNT_SKL = 91
    };

}



#define CreateNewMaterial(x) UKismetMaterialLibrary::CreateDynamicMaterialInstance(UWorld::GetWorld(), x)


class SDK::UShooterLocalPlayer* GetLocalPlayer();
class SDK::AShooterPlayerController* GetPlayerController();
class SDK::AShooterCharacter* GetShooterCharacter();

bool IsServerLoaded();
bool AreTribesAllied(int32 TeamID);

class UShooterGameInstance* GetShooterGameInstance(UWorld* InWorld = nullptr);
class AShooterGameState* GetShooterGameState(UWorld* InWorld = nullptr);

class AActor* GetTargetedActor();

void UnlockNotes(AShooterPlayerController* PC);
void UnlockAdmin(AShooterPlayerController* PC);
void EnterDungeon(AShooterPlayerController* PC);
void Suicide(AShooterPlayerController* PC);
void Rollback(AShooterPlayerController* PC);
void ResurrectDino(AShooterPlayerController* PC);
void TransferFromContainer(AShooterPlayerController* PC);
void TransferToContainer(AShooterPlayerController* PC);
void ClaimTargetedDino(AShooterPlayerController* PC);
void ClaimAllDinos(AShooterPlayerController* PC);
void PickupTargetedStructure(AShooterPlayerController* PC);
void PickupAllStructures(AShooterPlayerController* PC);
void RandomTeleport(AShooterPlayerController* PC);
void RemoveDungeonLoadingScreen(AShooterPlayerController* PC);
void BedTeleport(AShooterPlayerController* PC);
void Relog(AShooterPlayerController* PC);
void QuitToMenu(AShooterPlayerController* PC);
void PickupAllStructures(AShooterPlayerController* PC);
void ClaimAllDinos(AShooterPlayerController* PC);
void DungeonMenu(AShooterPlayerController* PC);
void SetLightType(int LightType);
void PlaceStructureWithIndex(uint16_t Index);
void SendMessage(const std::wstring& Message, int Index);
void SpawnMaterials(AShooterPlayerController* PC);
void DumpAllSpawnUIPtrs();
void DumpAllBlueprintIDs();
void DumpBones();
void DevMenuDumpYee();
// void InitializeMiniMap();

constexpr uintptr_t MARK_DIRTY_ADDRESS = 0x10262671C;
constexpr uintptr_t CLIENT_TRAVEL_ADDRESS = 0x002b9dc88;
constexpr uintptr_t QUIT_TO_MENU_ADDRESS = 0x000b97d84;
constexpr uintptr_t WEAPON_TRACE = 0x00BDB748;
// constexpr uintptr_t SET_PASSWORD_ADDRESS = 0x000b1efe8;

inline void (*SetClientTravel_Internal)(UEngine* _this, UWorld* InWorld, const wchar_t* NextURL, ETravelType InTravelType);

//using MarkRenderStateDirty = void(UActorComponent*);
using SetClientTravel = void(UEngine*, UWorld*, const wchar_t*, ETravelType);
using QuitToMainMenuFromInGame = void(AShooterPlayerController*);
using WeaponTrace = FHitResult(AShooterWeapon*, const FVector&, const FVector&);

//static USoundCue* CustomSounds = nullptr;
//static AShooterCharacter* Target = nullptr;
