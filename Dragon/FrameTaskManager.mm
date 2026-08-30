#include "MenuLoad/Includes.h"
#include <Foundation/NSObjCRuntime.h>
#import "FrameTaskManager.h"
#include "Source/CppSDK/SDK/Engine_structs.hpp"
#include "Source/CppSDK/SDK/Engine_parameters.hpp"
#include "Source/CppSDK/SDK/Basic.hpp"
#include "Source/CppSDK/SDK/ShooterGame_parameters.hpp"
#include "Source/CppSDK/UnrealContainers.hpp"
#include "Source/CppSDK/SDK/Foliage_classes.hpp"
#include "Utilities/Format/color.h"
#include "Source/CppSDK/SDK/CoreUObject_structs.hpp"
#include "Source/CppSDK/SDK/CoreUObject_classes.hpp"
#include "Source/CppSDK/SDK/Engine_classes.hpp"
#include "Source/CppSDK/SDK/ShooterGame_structs.hpp"
#include "Source/CppSDK/SDK/ShooterGame_classes.hpp"
#include "Source/CppSDK/SDK/ExplorerChest_Base_classes.hpp"
#include "Source/CppSDK/SDK/IOSRuntimeSettings_classes.hpp"
#include "Source/CppSDK/SDK/SpawnMenu_classes.hpp"
#include <Security/Security.h>
#include <sys/_types/_uintptr_t.h>
#include <sys/qos.h>
#include <cmath>
#include <array>
#include <vector>
#include <sstream>
#include "Utilities/Variables.h"
#include "Utilities/Macros.h"
#include "Utilities/Timer.h"
#include "Utilities/LogManager.h"
#include "Source/Libraries/CGuardMemory/CGPMemory.h"

#import <objc/runtime.h>
#import <objc/message.h>


void VftSwapFunc(void* Instance, void* NewFunc, void*& OrigFunc, int32 Index)
{
    void** Vft = *reinterpret_cast<void***>(Instance);
    if (Vft[Index] != NewFunc)
    {
        OrigFunc = Vft[Index];
        Vft[Index] = NewFunc;
    }
}

std::atomic<FVector2D> GCurrentTouchLocation;
inline bool GHasActiveTouch = false;


inline float* GAverageFPS = nullptr;

TArray<AActor*> EmptyActorArray = {};

template<EActorListsBP ActorType = EActorListsBP::MAX>
FORCEINLINE const TArray<AActor*>& GetActors(ULevel* FromLevel = nullptr)
{
    if (FromLevel && FromLevel->bIsVisible)
        return FromLevel->Actors;

    UWorld* World = UWorld::GetWorld();
    if (!World)
        return EmptyActorArray;

    ULevel* PersistentLevel = World->PersistentLevel;
    if (!PersistentLevel || !PersistentLevel->bIsVisible)
        return EmptyActorArray;

    if (ActorType != EActorListsBP::MAX)
    {
        AWorldSettings* WorldSettings = PersistentLevel->WorldSettings;
        if (WorldSettings)
        {
            return WorldSettings->ActorLists[(uint8)ActorType];
        }
    }

    return PersistentLevel->Actors;
}

class FontManager
{
public:

    FontManager() = delete;
    FontManager(UFont* _Font) : Font(_Font) {}

public:
    // Sig: ? ? ? D1 ? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? 91 F5 03 00 AA ? ? ? 39 ? ? ? 71
    static inline int8 (*_GetCharKerning)(const UFont*, TCHAR, TCHAR) = nullptr;
    int8 GetCharKerning(TCHAR First, TCHAR Second) const
    {
        return _GetCharKerning(Font, First, Second);
    }

    // Sig: ? ? ? D1 ? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? 91 F3 03 03 AA F4 03 02 AA F6 03 01 AA F5 03 00 AA ? ? ? B9 ? ? ? B9 ? ? ? 39
    static inline void (*_GetCharSize)(const UFont*, TCHAR, float&, float&) = nullptr;
    void GetCharSize(TCHAR InCh, float& Width, float& Height) const
    {
        return _GetCharSize(Font, InCh, Width, Height);
    }

    static void GetDefaultCharSize( FontManager DrawFont, float& DefaultCharWidth, float& DefaultCharHeight, const TCHAR* pDefaultChar=NULL )
    {
        TCHAR DefaultChar = pDefaultChar != NULL ? *pDefaultChar : TEXT('0');
        DrawFont.GetCharSize(DefaultChar, DefaultCharWidth, DefaultCharHeight);
        if ( DefaultCharWidth == 0 )
        {
            // this font doesn't contain '0', try 'A'
            DrawFont.GetCharSize(TEXT('A'), DefaultCharWidth, DefaultCharHeight);
        }
    }

    float GetTextWidth(const FString& Text, float ScaleX, float DefaultCharWidth)
    {
        if (Text.IsEmpty())
            return 0.0f;

        float Width = 0.0f;

        const TCHAR* const BeginPos = *Text;
        const TCHAR* const EndPos = BeginPos + Text.Len();
        const TCHAR* PrevPos = nullptr;

        for (const TCHAR* CurrentPos = BeginPos; CurrentPos < EndPos && *CurrentPos; ++CurrentPos)
        {
            float CharWidth, CharHeight;

            const TCHAR Ch = *CurrentPos;
            this->GetCharSize(Ch, CharWidth, CharHeight);

            if (CharWidth == 0.0f)
                CharWidth = DefaultCharWidth;

            float CharSpacing = 0.0f;
            if (PrevPos)
            {
                CharSpacing += this->GetCharKerning(*PrevPos, Ch) * ScaleX;
            }

            CharWidth *= ScaleX;

            const TCHAR* NextPos = CurrentPos + 1;
            if (NextPos < EndPos && *NextPos && !iswspace(*NextPos))
            {
                CharWidth += CharSpacing;
            }

            Width += CharWidth;
            PrevPos = CurrentPos;
        }

        return Width;
    }

    float GetTextHeight(const FString& Text, float ScaleY, float DefaultCharHeight)
    {
        if (Text.IsEmpty())
            return 0.0f;

        float MaxHeight = 0.0f;

        const TCHAR* const BeginPos = *Text;
        const TCHAR* const EndPos = BeginPos + Text.Len();

        for (const TCHAR* CurrentPos = BeginPos; CurrentPos < EndPos && *CurrentPos; ++CurrentPos)
        {
            float CharWidth, CharHeight;
            const TCHAR Ch = *CurrentPos;
            this->GetCharSize(Ch, CharWidth, CharHeight);

            if (CharHeight == 0.0f && Ch == TEXT('\n'))
            {
                CharHeight = DefaultCharHeight;
            }

            CharHeight *= ScaleY;

            MaxHeight = FMath::Max(MaxHeight, CharHeight);
        }

        return MaxHeight;
    }

public:

    operator UFont*() const
    {
        return Font;
    }

private:

    UFont* Font;
};

FORCEINLINE FVector GetActorLocation(AActor* Actor)
{
    if (USceneComponent* RootComponent = Actor->RootComponent)
    {
        return RootComponent->ComponentToWorld.GetLocation();
    }
    return FVector::ZeroVector;
}

FORCEINLINE FVector GetActorVelocity(AActor* Actor)
{
    if (USceneComponent* RootComponent = Actor->RootComponent)
    {
        return RootComponent->ComponentVelocity;
    }
    return FVector::ZeroVector;
}

FORCEINLINE FRotator GetActorRotation(AActor* Actor)
{
    if (USceneComponent* RootComponent = Actor->RootComponent)
    {
        return RootComponent->ComponentToWorld.Rotation.Rotator();
    }
    return FRotator::ZeroRotator;
}

FORCEINLINE bool IsWild(APrimalDinoCharacter* PrimalDino)
{
    constexpr int32 WILD_TARGETIGTEAM_THRESHOLD = 49999;
    return PrimalDino->TargetingTeam <= WILD_TARGETIGTEAM_THRESHOLD;
}

FORCEINLINE bool IsUnclaimed(APrimalDinoCharacter* PrimalDino)
{
    return PrimalDino->TargetingTeam == 2000000000;
}

FORCEINLINE int32 GetLevel(UPrimalCharacterStatusComponent* StatusComp)
{
    return StatusComp->BaseCharacterLevel + StatusComp->ExtraCharacterLevel;
}

UCanvas* GetDebugCanvasObject()
{
    static UCanvas* DebugCanvasObject = nullptr;
    if (DebugCanvasObject == nullptr)
        DebugCanvasObject = UObject::FindObjectFast<UCanvas>("DebugCanvasObject");

    return DebugCanvasObject;
}

UFont* GetRenderFont()
{
    static UFont* Font = nullptr;
    if (Font == nullptr)
        Font = UObject::FindObject<UFont>("Font ArkDefaultFont.ArkDefaultFont");

    return Font;
}


FORCEINLINE const FMatrix& GetViewProjectionMatrix(UCanvas* Canvas = nullptr)
{
    UCanvas* DebugCanvasObject = Canvas ? Canvas : GetDebugCanvasObject();
    if (DebugCanvasObject)
    {
        return DebugCanvasObject->ViewProjectionMatrix;
    }
    return FMatrix::Identity;
}

constexpr int32 MaleBoneIndices[15] =
{
    static_cast<int32>(MaleBones::Cnt_Head_JNT_SKL),
    static_cast<int32>(MaleBones::Cnt_Neck_Joint000_JNT_SKL),
    static_cast<int32>(MaleBones::Lft_Arm_001Tear000_JNT_SKL),
    static_cast<int32>(MaleBones::Rht_Arm_001Tear000_JNT_SKL),
    static_cast<int32>(MaleBones::Lft_Arm_002Tear000_JNT_SKL),
    static_cast<int32>(MaleBones::Rht_Arm_002Tear000_JNT_SKL),
    static_cast<int32>(MaleBones::Lft_Arm_002Tear006_JNT_SKL),
    static_cast<int32>(MaleBones::Rht_Arm_002Tear006_JNT_SKL),
    static_cast<int32>(MaleBones::Cnt_Pelvis_000_JNT_SKL),
    static_cast<int32>(MaleBones::Lft_Leg_001Tear000_JNT_SKL),
    static_cast<int32>(MaleBones::Rht_Leg_001Tear000_JNT_SKL),
    static_cast<int32>(MaleBones::Lft_Leg_002Tear000_JNT_SKL),
    static_cast<int32>(MaleBones::Rht_Leg_002Tear000_JNT_SKL),
    static_cast<int32>(MaleBones::Lft_Leg_002_JNT_SKL),
    static_cast<int32>(MaleBones::Rht_Leg_002_JNT_SKL)
};

constexpr int32 FemaleBoneIndices[15] =
{
    static_cast<int32>(FemaleBones::Cnt_Head_JNT_SKL),
    static_cast<int32>(FemaleBones::Cnt_Neck_Joint000_JNT_SKL),
    static_cast<int32>(FemaleBones::Lft_Arm_001Tear000_JNT_SKL),
    static_cast<int32>(FemaleBones::Rht_Arm_001Tear000_JNT_SKL),
    static_cast<int32>(FemaleBones::Lft_Arm_002Tear000_JNT_SKL),
    static_cast<int32>(FemaleBones::Rht_Arm_002Tear000_JNT_SKL),
    static_cast<int32>(FemaleBones::Lft_Arm_002Tear006_JNT_SKL),
    static_cast<int32>(FemaleBones::Rht_Arm_002Tear006_JNT_SKL),
    static_cast<int32>(FemaleBones::Cnt_Pelvis_000_JNT_SKL),
    static_cast<int32>(FemaleBones::Lft_Leg_001Tear000_JNT_SKL),
    static_cast<int32>(FemaleBones::Rht_Leg_001Tear000_JNT_SKL),
    static_cast<int32>(FemaleBones::Lft_Leg_002Tear000_JNT_SKL),
    static_cast<int32>(FemaleBones::Rht_Leg_002Tear000_JNT_SKL),
    static_cast<int32>(FemaleBones::Lft_Leg_002_JNT_SKL),
    static_cast<int32>(FemaleBones::Rht_Leg_002_JNT_SKL)
};

FVector GetBoneLocation(USkeletalMeshComponent* Mesh, int32 BoneIndex, const FTransform& LocalToWorld)
{
    if (!Mesh)
        return FVector::ZeroVector;

    const TArray<FTransform>& Transforms = Mesh->ComponentSpaceTransformsArray[Mesh->CurrentReadComponentTransforms];
    if (Transforms.IsValid() && Transforms.IsValidIndex(BoneIndex))
    {
        return Transforms[BoneIndex] * LocalToWorld;
    }
    return FVector::ZeroVector;
}


template<typename T>
T* FindTransientObject()
{
    for (auto Index{0}; Index < UObject::GObjects->Num(); ++Index)
    {
        UObject* Object = UObject::GObjects->GetByIndex(Index);
        if (!Object || !Object->IsA(T::StaticClass()))
            continue;

        if (!Object->IsDefaultObject())
        {
            return Cast<T>(Object);
        }
    }
    return nullptr;
}


class UShooterLocalPlayer* GetLocalPlayer()
{
    static UShooterLocalPlayer* GLocalPlayer = nullptr;
    if (GLocalPlayer == nullptr)
        GLocalPlayer = FindTransientObject<UShooterLocalPlayer>();

    return GLocalPlayer;
}

class UShooterGameViewportClient* GetGameViewportClient()
{
    static UShooterGameViewportClient* GViewportClient = nullptr;
    if (GViewportClient == nullptr)
        GViewportClient = FindTransientObject<UShooterGameViewportClient>();

    return GViewportClient;
}

class AShooterPlayerController* GetPlayerController()
{
    UShooterLocalPlayer const* LP = GetLocalPlayer();
    if ( !LP || !LP->PlayerController)
        return nullptr;

    return UObject::Cast<AShooterPlayerController>(LP->PlayerController);
}


AShooterCharacter* GetPlayerCharacter(AShooterPlayerController* PlayerController = nullptr)
{
    AShooterPlayerController *PC = PlayerController ? PlayerController : GetPlayerController();
    if (!PC)
        return nullptr;

    ACharacter *Character = PC->Character;
    if (!Character)
        return nullptr;

    if (Character->IsA(AShooterCharacter::StaticClass()))
        return Cast<AShooterCharacter>(Character);

    TWeakObjectPtr<AShooterCharacter> Rider = static_cast<APrimalDinoCharacter*>(Character)->Rider;
    return Rider.GetSafe();
}

AActor* GetTargetedActor()
{
    AShooterPlayerController* PC = GetPlayerController();
    if (!PC || !PC->TargetingObject)
    {   return nullptr; }

    return PC->TargetingObject->AimedActorRef.Actor.GetSafe();
}

bool IsInServer()
{
    if (UWorld* World = UWorld::GetWorld())
    {
        UNetDriver* NetDriver = World->NetDriver;
        if (!NetDriver)
            return false;

        return NetDriver->ServerConnection != nullptr;
    }
    return false;
}

constexpr double TapDuration = 0.27000;

bool IsShootButtonQuickTapped(UPlayerHUDUI *_this)
{
    UWorld* World = UWorld::GetWorld();

    if (*(float*)((uint8*)_this + 0x84c) == 0.0f || !World)
        return false;

    if ((TapDuration <= *(double*)((uint8*)World + 0xb68) - (double)*(float*)((uint8*)_this + 0x84c)) ||
        (TapDuration <= *(float*)((uint8*)_this + 0x848) - *(float*)((uint8*)_this + 0x844)))
    {
        return false;
    }
    return true;
}

bool IsShootButtonHeld(UPlayerHUDUI *_this)
{
    UWorld* World = UWorld::GetWorld();
    if (!World)
        return false;

    UButton* ShootButton1 = *(UButton **)((uint8*)_this + 0x700);
    UButton* ShootButton2 = *(UButton **)((uint8*)_this + 0x708);
    UButton* ShootButton3 = *(UButton **)((uint8*)_this + 0x720);

    if ((!ShootButton1->IsPressed() && !ShootButton2->IsPressed() && !ShootButton3->IsPressed()) ||
        *(double *)((uint8*)World + 0xb68) - (double)*(float *)((uint8*)_this + 0x844) <= TapDuration)
    {
        return false;
    }
    return true;
}

bool IsShootButtonPressed(UPlayerHUDUI *_this)
{
    UButton* ShootButton1 = *(UButton **)((uint8*)_this + 0x700);
    UButton* ShootButton2 = *(UButton **)((uint8*)_this + 0x708);
    UButton* ShootButton3 = *(UButton **)((uint8*)_this + 0x720);

    if (!ShootButton1->IsPressed() && !ShootButton2->IsPressed())
    {
        return ShootButton3->IsPressed();
    }
    return true;
}

bool PerformedAnyShootAction(AShooterPlayerController* PC)
{
    AShooterHUD* HUD = PC->GetShooterHUD();
    if (!HUD)
        return false;

    UPlayerHUDUI* HUDUI = HUD->MyPlayerHUD;
    if (!HUDUI)
        return false;

    bool ButtonTapped   = IsShootButtonQuickTapped(HUDUI);
    bool ButtonPressed  = IsShootButtonPressed(HUDUI);
    bool ButtonHeld     = IsShootButtonHeld(HUDUI);

    return ButtonTapped || ButtonHeld || ButtonPressed;
}

void WorldToMapCoordinates(UWorld* World, const FVector& WorldLocation, float* Latitude, float* Longitude)
{
    if (ULevel* PersistentLevel = World->PersistentLevel)
    {
        if (APrimalWorldSettings* WorldSettings = UObject::Cast<APrimalWorldSettings>(PersistentLevel->WorldSettings))
        {
            *Latitude  = (WorldLocation.Y - WorldSettings->LatitudeOrigin)  / (WorldSettings->LatitudeScale  * 10.0f);
            *Longitude = (WorldLocation.X - WorldSettings->LongitudeOrigin) / (WorldSettings->LongitudeScale * 10.0f);
            return;
        }
    }

    *Latitude  = 0.f;
    *Longitude = 0.f;
}

class UShooterGameInstance* GetShooterGameInstance(UWorld* InWorld)
{
    UWorld* World = InWorld ? InWorld : UWorld::GetWorld();
    if ( !World )
        return nullptr;

    return UObject::Cast<UShooterGameInstance>(World->OwningGameInstance);
}


class AShooterGameState* GetShooterGameState(UWorld* InWorld)
{
    UWorld* World = InWorld ? InWorld : UWorld::GetWorld();
    if ( !World )
        return nullptr;

    return UObject::Cast<AShooterGameState>(World->GameState);
}

inline FVector2D HalfViewportSize = FVector2D::ZeroVector;

bool ProjectWorldToScreen(const FVector& WorldPosition, FVector2D& OutScreenPos, const FMatrix& VPM, bool bShouldCalcOutsideViewPosition = false)
{
    float W = VPM.M[0][3] * WorldPosition.X + VPM.M[1][3] * WorldPosition.Y + VPM.M[2][3] * WorldPosition.Z + VPM.M[3][3];

    bool bIsInsideView = W > 0.0f;
    if ( !bIsInsideView )
    {
        if ( !bShouldCalcOutsideViewPosition )
            return false;

        W = 0.01f;
    }

    float X = VPM.M[0][0] * WorldPosition.X + VPM.M[1][0] * WorldPosition.Y + VPM.M[2][0] * WorldPosition.Z + VPM.M[3][0];
    float Y = VPM.M[0][1] * WorldPosition.X + VPM.M[1][1] * WorldPosition.Y + VPM.M[2][1] * WorldPosition.Z + VPM.M[3][1];

    const float RHW = 1.0f / W;
    float PosInScreenSpaceX = X * RHW;
    float PosInScreenSpaceY = Y * RHW;

    OutScreenPos.X = HalfViewportSize.X + (HalfViewportSize.X * PosInScreenSpaceX);
    OutScreenPos.Y = HalfViewportSize.Y - (HalfViewportSize.Y * PosInScreenSpaceY);

    return bIsInsideView;
}

bool ProjectWorldToScreen(const FVector& WorldPosition, ImVec2& OutScreenPos, const FMatrix& VPM, bool bShouldCalcOutsideViewPosition = false)
{
    float W = VPM.M[0][3] * WorldPosition.X + VPM.M[1][3] * WorldPosition.Y + VPM.M[2][3] * WorldPosition.Z + VPM.M[3][3];

    bool bIsInsideView = W > 0.0f;
    if ( !bIsInsideView )
    {
        if ( !bShouldCalcOutsideViewPosition )
            return false;

        W = 0.01f;
    }

    float X = VPM.M[0][0] * WorldPosition.X + VPM.M[1][0] * WorldPosition.Y + VPM.M[2][0] * WorldPosition.Z + VPM.M[3][0];
    float Y = VPM.M[0][1] * WorldPosition.X + VPM.M[1][1] * WorldPosition.Y + VPM.M[2][1] * WorldPosition.Z + VPM.M[3][1];

    const float RHW = 1.0f / W;
    float PosInScreenSpaceX = X * RHW;
    float PosInScreenSpaceY = Y * RHW;

    OutScreenPos.x = ScreenRect.HalfWidth  + (ScreenRect.HalfWidth  * PosInScreenSpaceX);
    OutScreenPos.y = ScreenRect.HalfHeight - (ScreenRect.HalfHeight * PosInScreenSpaceY);

    return bIsInsideView;
}

void (*K2_DrawText)(UCanvas* _this, UFont* RenderFont, const FString& RenderText, FVector2D ScreenPosition, FLinearColor RenderColor, float Kerning, FLinearColor ShadowColor, FVector2D ShadowOffset, bool bCentreX, bool bCentreY, bool bOutlined, FLinearColor OutlineColor);
void (*K2_DrawTexture)(UCanvas* _this, UTexture* RenderTexture, FVector2D ScreenPosition, FVector2D ScreenSize, FVector2D CoordinatePosition, FVector2D CoordinateSize, FLinearColor RenderColor, EBlendMode BlendMode, float Rotation, FVector2D PivotPoint);
void (*K2_DrawLine)(UCanvas* _this, FVector2D ScreenPositionA, FVector2D ScreenPositionB, float Thickness, FLinearColor RenderColor);

/** An untyped array of data with compile-time alignment and size derived from another type. */
template<typename ElementType>
struct TTypeCompatibleBytes : public ContainerImpl::TAlignedBytes<sizeof(ElementType), alignof(ElementType)>
{

};

template<typename OptionalType>
struct TOptional
{
public:
    TTypeCompatibleBytes<OptionalType> Value;
    bool bIsSet;
};


/** Blend modes supported for simple element rendering */
enum ESimpleElementBlendMode
{
    SE_BLEND_Opaque = 0,
    SE_BLEND_Masked,
    SE_BLEND_Translucent,
    SE_BLEND_Additive,
    SE_BLEND_Modulate,
    SE_BLEND_MaskedDistanceField,
    SE_BLEND_MaskedDistanceFieldShadowed,
    SE_BLEND_TranslucentDistanceField,
    SE_BLEND_TranslucentDistanceFieldShadowed,
    SE_BLEND_AlphaComposite,
    // Like SE_BLEND_Translucent, but modifies destination alpha
    SE_BLEND_AlphaBlend,
    // Like SE_BLEND_Translucent, but reads from an alpha-only texture
    SE_BLEND_TranslucentAlphaOnly,

    SE_BLEND_RGBA_MASK_START,
    SE_BLEND_RGBA_MASK_END = SE_BLEND_RGBA_MASK_START + 31, //Using 5bit bit-field for red, green, blue, alpha and desaturation

    SE_BLEND_MAX
};

class FCanvasItem
{
public:
    void** VTable;
    /**
     * Basic render item.
     *
     * @param    InPosition        Draw position
     */
    FCanvasItem( const FVector2D& InPosition )
        : Position( InPosition )
        , StereoDepth( 0 )
        , BlendMode( SE_BLEND_Opaque )
        , bFreezeTime( false )
        , BatchedElementParameters( nullptr )
        , Color( FLinearColor::White )
    {
        VTable = reinterpret_cast<void**>(InSDKUtils::GetImageBase() + 0x104102FC0);
    };


    /* The position to draw the item. */
    FVector2D Position;

    /* Stereo projection depth in game units.  Default value 0 draws at canvas property StereoDepth. */
    uint32 StereoDepth;

        /* Blend mode. */
    ESimpleElementBlendMode BlendMode;

    bool bFreezeTime;

    /* Used for batch rendering. */
    struct FBatchedElementParameters* BatchedElementParameters;
public:
    /* Color of the item. */
    FLinearColor Color;
};

/* 'Tile' item can override size and UV . */
class FCanvasTileItem : public FCanvasItem
{
public:
    /**
     * Tile item which uses the default white texture using given size.
     *
     * @param    InPosition        Draw position
     * @param    InSize            The size to render
     */
    FCanvasTileItem( const FVector2D& InPosition, const FVector2D& InSize, const FLinearColor& InColor )
        : FCanvasItem( InPosition )
        , Size( InSize )
        , Z( 1.0f )
        , UV0( 0.0f, 0.0f )
        , UV1( 1.0f, 1.0f )
        , Texture( nullptr )
        , MaterialRenderProxy( nullptr )
        , Rotation()
        , PivotPoint( FVector2D::ZeroVector )
    {
        Color = InColor;
    }


    /* Size of the tile. */
    FVector2D Size;

    /* used to calculate depth. */
    float Z;

    /* UV Coordinates 0 (Left/Top). */
    FVector2D UV0;

    /* UV Coordinates 0 (Right/Bottom). */
    FVector2D UV1;

    /* Texture to render. */
    const struct FTexture* Texture;

    /* Material proxy for rendering. */
    const struct FMaterialRenderProxy* MaterialRenderProxy;

    /* Rotation. */
    FRotator Rotation;

    /* Pivot point, as percentage of tile (0-1). */
    FVector2D    PivotPoint;
};


/* Base item used for drawing text */
class FCanvasTextItemBase : public FCanvasItem
{
public:
    FCanvasTextItemBase( const FVector2D& InPosition, const FLinearColor& InColor )
        : FCanvasItem( InPosition )
        , HorizSpacingAdjust( 0.0f )
        , Depth( 1.0f )
        , ShadowColor( FLinearColor::Black )
        , ShadowOffset( FVector2D::ZeroVector )
        , DrawnSize( FVector2D::ZeroVector )
        , bCentreX( false )
        , bCentreY( false )
        , bOutlined( false )
        , OutlineColor( FLinearColor::Black )
        , bDontCorrectStereoscopic( true )
        , TileItem( InPosition, FVector2D::ZeroVector, InColor )
    {
        Color = InColor;
        Scale = FVector2D( 1.0f, 1.0f );
        BlendMode = SE_BLEND_Translucent;
    }

    /**
     * Set the shadow offset and color.
     *
     * @param    InColor            Shadow color
     * @param    InOffset        Shadow offset. Defaults to 1,1. (Passing zero vector will disable the shadow)
     */
    void EnableShadow( const FLinearColor& InColor, const FVector2D& InOffset = FVector2D( 1.0f, 1.0f ) )
    {
        ShadowOffset = InOffset;
        ShadowColor = InColor;
        FontRenderInfo.bEnableShadow = ShadowOffset.SizeSquared() != 0.0f;
    }

    /**
     * Disable the shadow
     */
    void DisableShadow()
    {
        ShadowOffset = FVector2D::ZeroVector;
        FontRenderInfo.bEnableShadow = false;
    }

    /* Horizontal spacing adjustment. */
    float HorizSpacingAdjust;

    /* Depth sort key. */
    float Depth;

    /* Custom font render information. */
    FFontRenderInfo    FontRenderInfo;

    /* The color of the shadow */
    FLinearColor ShadowColor;

    /* The offset of the shadow. */
    FVector2D ShadowOffset;

    /* The size of the drawn text after the draw call. */
    FVector2D DrawnSize;

    /* Centre the text in the viewport on horizontally. */
    bool    bCentreX;

    /* Centre the text in the viewport on vertically. */
    bool    bCentreY;

    /* Draw an outline on the text. */
    bool    bOutlined;

    /* The color of the outline. */
    FLinearColor OutlineColor;

    /* Disables correction of font render issue when using stereoscopic display. */
    bool    bDontCorrectStereoscopic;

    /* The scale of the text */
    FVector2D Scale;

public:
    /* Background tile used to fixup 3d text issues. */
    FCanvasTileItem    TileItem;
    /**
     * These are used by the DrawStringInternal function.
     */
    /* Used for batching. */
    struct FBatchedElements* BatchedElements;
};

/* Text item with misc optional items such as shadow, centering etc. */
class FCanvasTextItem : public FCanvasTextItemBase
{
public:
    /**
     * Text item
     *
     * @param    InPosition        Draw position
     * @param    InText            String to draw
     * @param    InFont            Font to draw with
     */
    FCanvasTextItem( const FVector2D& InPosition, const FText& InText, const UFont* InFont, const FLinearColor& InColor )
        : FCanvasTextItemBase( InPosition, InColor )
        , Text( InText )
        , Font( InFont )
        , SlateFontInfo()
    {
        BlendMode = SE_BLEND_Translucent;
    }

    FORCEINLINE void Draw(struct FCanvas* Canvas) const
    {
        reinterpret_cast<void(*)(const FCanvasTextItem*, struct FCanvas*)>(VTable[2])(this, Canvas);
    }

    /* The text to draw. */
    FText Text;

    /* Font to draw text with. */
    const UFont* Font;

    /** Font info to draw the text with. */
    TOptional<FSlateFontInfo> SlateFontInfo;
};



void _K2_DrawText(UCanvas* _this, UFont* RenderFont, const FString& RenderText, float TextScale, FVector2D ScreenPosition, const FLinearColor& RenderColor, float Kerning, bool bCentreX, bool bCentreY, bool bOutlined)
{
    if (!RenderText.IsEmpty() && _this->Canvas)
    {
        static FCanvasTextItem TextItem(ScreenPosition, FText::GetEmpty(), RenderFont, RenderColor);
        TextItem.Text.TextData.Object->DisplayString = RenderText;
        TextItem.Font = RenderFont;
        TextItem.Color = RenderColor;
        TextItem.Position = ScreenPosition;
        TextItem.TileItem.Position = ScreenPosition;
        TextItem.HorizSpacingAdjust = Kerning;
        TextItem.bCentreX = bCentreX;
        TextItem.bCentreY = bCentreY;
        TextItem.bOutlined = bOutlined;
        TextItem.Scale = TextScale;

        TextItem.Draw(_this->Canvas);
    }
}

FORCEINLINE void DrawLine(UCanvas* Canvas, const FVector2D& PosA, const FVector2D& PosB, float Thickness, const FLinearColor& Color)
{
    return K2_DrawLine(Canvas, PosA, PosB, Thickness, Color);
}

void DrawCircle(UCanvas* Canvas, const FVector2D& Center, float Radius, const FLinearColor& Color, int32 NumSegments, float Thickness)
{
    if (!Canvas || NumSegments < 3 || Radius <= 0.0f)
    {
        return;
    }

    const float AngleStep = 2.0f * PI / NumSegments;
    FVector2D StartPoint = Center + FVector2D(Radius, 0);

    for (int32 i = 1; i <= NumSegments; i++)
    {
        const float Angle = i * AngleStep;
        float Sin, Cos;
        FMath::SinCos(&Sin, &Cos, Angle);
        FVector2D EndPoint = Center + FVector2D(Cos * Radius, Sin * Radius);

        DrawLine(Canvas, StartPoint, EndPoint, Thickness, Color);
        StartPoint = EndPoint;
    }
}

FORCEINLINE void DrawText(UCanvas* Canvas, UFont* Font, const FString& Text, const FVector2D& ScreenPosition, const FLinearColor& Color, float Scale, bool Outline = true, bool Center = true)
{
    if ( !Font )
        return;

    _K2_DrawText(Canvas, Font, Text, Scale, ScreenPosition, Color, (float)Font->Kerning, Center ? true : false, Center ? true : false, Outline);
}

FORCEINLINE void DrawTexture(UCanvas* Canvas, UTexture2D* RenderTexture, const FVector2D& ScreenPosition, const FVector2D& SizeXY, const FLinearColor& Color, bool bCenterX = true, bool bCenterY = true)
{
    FVector2D CorrectedPositon(bCenterX ? ScreenPosition.X - (SizeXY.X * 0.5f) : ScreenPosition.X, bCenterY ? ScreenPosition.Y - SizeXY.Y : ScreenPosition.Y);
    return K2_DrawTexture(Canvas, RenderTexture, CorrectedPositon, SizeXY, FVector2D(0, 0), FVector2D(1, 1), Color, EBlendMode::BLEND_Translucent, 0.0f, FVector2D(0.5f, 0.5f));
}

FORCEINLINE void DrawRectFilled(UCanvas* Canvas, const FVector2D& ScreenPosition, const FVector2D& SizeXY, const FLinearColor& Color)
{
    return K2_DrawLine(Canvas, ScreenPosition, FVector2D(ScreenPosition.X + SizeXY.X, ScreenPosition.Y), SizeXY.Y, Color);
}

void Draw3DBox(UCanvas* Canvas, AShooterCharacter* Player, const FLinearColor& BoxColor)
{
    if (!Canvas || !Player || !Player->Mesh)
        return;

    const FBoxSphereBounds& Bounds = Player->Mesh->Bounds;

    const FVector Origin = Bounds.Origin;
    const FVector Extent = Bounds.BoxExtent;

    const FQuat& Rotation = Player->Mesh->ComponentToWorld.Rotation;

    const float YawRadians = FMath::Atan2(
            2.f * (Rotation.W * Rotation.Z + Rotation.X * Rotation.Y),
            1.f - 2.f * (FMath::Square(Rotation.Y) + FMath::Square(Rotation.Z))
    );

    float SinYaw, CosYaw;
    FMath::SinCos(&SinYaw, &CosYaw, YawRadians);

    const FVector Offsets[8] = {
            {-Extent.X, -Extent.Y, -Extent.Z},
            { Extent.X, -Extent.Y, -Extent.Z},
            { Extent.X,  Extent.Y, -Extent.Z},
            {-Extent.X,  Extent.Y, -Extent.Z},
            {-Extent.X, -Extent.Y,  Extent.Z},
            { Extent.X, -Extent.Y,  Extent.Z},
            { Extent.X,  Extent.Y,  Extent.Z},
            {-Extent.X,  Extent.Y,  Extent.Z},
    };

    FVector2D Screen[8];
    for (auto Index{0}; Index < 8; ++Index)
    {
        const FVector& Offset = Offsets[Index];

        const float DX = Offset.X;
        const float DY = Offset.Y;

        const FVector Corner = {
            Origin.X + DX * CosYaw - DY * SinYaw,
            Origin.Y + DX * SinYaw + DY * CosYaw,
            Origin.Z + Offset.Z
        };

        if (!ProjectWorldToScreen(Corner, Screen[Index], Canvas->ViewProjectionMatrix))
            return;
    }

    K2_DrawLine(Canvas, Screen[0], Screen[1], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[1], Screen[2], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[2], Screen[3], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[3], Screen[0], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[4], Screen[5], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[5], Screen[6], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[6], Screen[7], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[7], Screen[4], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[0], Screen[4], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[1], Screen[5], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[2], Screen[6], 2.f, BoxColor);
    K2_DrawLine(Canvas, Screen[3], Screen[7], 2.f, BoxColor);
}

void Draw2DBox(UCanvas* Canvas, FVector2D const& Top,  FVector2D const& Bottom, FLinearColor const& BoxColor)
{
    float Height = Bottom.Y - Top.Y;
    FVector2D Size(Height * 0.5f, Height);

    FVector2D Pos(Top.X - (Size.X / 2), Top.Y);

    float CornerLen = Size.X * 0.4f;
    if (CornerLen > Size.X / 2.0f)
        CornerLen = Size.X / 2.0f;
    if (CornerLen > Size.Y / 2.0f)
        CornerLen = Size.Y / 2.0f;

    DrawLine(Canvas, Pos, FVector2D(Pos.X + CornerLen, Pos.Y), 3.0f, BoxColor);
    DrawLine(Canvas, Pos, FVector2D(Pos.X, Pos.Y + CornerLen), 3.0f, BoxColor);

    FVector2D TopRight = FVector2D(Pos.X + Size.X, Pos.Y);
    DrawLine(Canvas, TopRight, FVector2D(TopRight.X - CornerLen, TopRight.Y), 3.0f, BoxColor);
    DrawLine(Canvas, TopRight, FVector2D(TopRight.X, TopRight.Y + CornerLen), 3.0f, BoxColor);

    FVector2D BottomLeft = FVector2D(Pos.X, Pos.Y + Size.Y);
    DrawLine(Canvas, BottomLeft, FVector2D(BottomLeft.X + CornerLen, BottomLeft.Y), 3.0f, BoxColor);
    DrawLine(Canvas, BottomLeft, FVector2D(BottomLeft.X, BottomLeft.Y - CornerLen), 3.0f, BoxColor);

    FVector2D BottomRight = FVector2D(Pos.X + Size.X, Pos.Y + Size.Y);
    DrawLine(Canvas, BottomRight, FVector2D(BottomRight.X - CornerLen, BottomRight.Y),  3.0f, BoxColor);
    DrawLine(Canvas, BottomRight, FVector2D(BottomRight.X, BottomRight.Y - CornerLen),  3.0f, BoxColor);
}

void DrawSkeleton(UCanvas* Canvas, AShooterCharacter* Player, const FLinearColor& Color)
{
    if (!Player || !Player->Mesh)
        return;

    const int32* BoneIndices = Player->bIsFemale ? FemaleBoneIndices : MaleBoneIndices;

    const FMatrix& ViewProjMatrix = Canvas->ViewProjectionMatrix;

    constexpr auto NumRelevantBones = 15;

    FVector2D BonePositions[NumRelevantBones];
    for (auto Index{0}; Index < NumRelevantBones; ++Index)
    {
        FVector WorldBonePosition = GetBoneLocation(Player->Mesh, BoneIndices[Index], Player->Mesh->ComponentToWorld);
        if (!ProjectWorldToScreen(WorldBonePosition, BonePositions[Index], ViewProjMatrix))
            return;
    }

    static constexpr int32 LinePairs[14][2] =
    {
            {0, 1}, {1, 2}, {1, 3}, {2, 4}, {3, 5},
            {4, 6}, {5, 7}, {1, 8}, {8, 9}, {8, 10},
            {9, 11}, {10, 12}, {11, 13}, {12, 14}
    };

    for (const auto& [From, To] : LinePairs)
        DrawLine(Canvas, BonePositions[From], BonePositions[To], 2.0f, Color);
}

FORCEINLINE void DrawHealthBar(UCanvas* Canvas, const FVector2D& ScreenPosition, const FVector2D& SizeXY, const FLinearColor& Color, float HealthPercentage, float Thickness)
{
    FVector2D CenteredPos(ScreenPosition.X - SizeXY.X * 0.5f, ScreenPosition.Y);

    K2_DrawLine(Canvas, CenteredPos, FVector2D(CenteredPos.X + SizeXY.X, CenteredPos.Y), SizeXY.Y + Thickness * 2, FLinearColor::Black);

    FVector2D HealthBarSize(SizeXY.X * HealthPercentage, SizeXY.Y);
    K2_DrawLine(Canvas, CenteredPos, FVector2D(CenteredPos.X + HealthBarSize.X, CenteredPos.Y), SizeXY.Y, Color);
}

const FLinearColor ItemQualityColors[] =
{
    FLinearColor(0.9, 0.9, 0.9, 1),
    FLinearColor(0.2, 1, 0.2, 1),
    FLinearColor(0.2, 0.3, 1, 1),
    FLinearColor(0.5, 0.2, 1, 1),
    FLinearColor(1, 0.95, 0.1, 1),
    FLinearColor(0, 1, 1, 1)
};

void DrawWeapon(UCanvas* Canvas, AShooterCharacter* Player, FVector2D ScreenPosition, FVector2D SizeXY)
{
    if (!Player || !Player->CurrentWeapon)
        return;

    UPrimalItem* WeaponItem = Player->CurrentWeapon->AssociatedPrimalItem;
    if (!WeaponItem)
        return;

    UTexture2D* Texture = Cast<UPrimalItem>(WeaponItem->Class->DefaultObject)->ItemIcon;
    if (!Texture)
        return;

    static UTexture2D* T_CircleGlow = nullptr;
    if (T_CircleGlow == nullptr)
        T_CircleGlow = UObject::FindObject<UTexture2D>("Texture2D T_CircleGlow.T_CircleGlow");

    FLinearColor Color = ItemQualityColors[WeaponItem->ItemQualityIndex];

    if (T_CircleGlow != nullptr)
        DrawTexture(Canvas, T_CircleGlow, ScreenPosition, SizeXY, Color);

    DrawTexture(Canvas, Texture, ScreenPosition, SizeXY, FLinearColor::White);
}

void DrawArmor(UCanvas* Canvas, AShooterCharacter* Player, const FVector2D& ScreenPosition, const FVector2D& SizeXY, bool IsSelf = false)
{
    if (!Player || !Player->MyInventoryComponent)
        return;

    TArray<UPrimalItem*> EquippedItems = Player->MyInventoryComponent->EquippedItems;
    if (!EquippedItems)
        return;

    auto GetSlotIndex = [](UPrimalItem* Item) -> int32
    {
        switch (Item->MyEquipmentType)
        {
            case EPrimalEquipmentType::Hat: return 0;
            case EPrimalEquipmentType::Shirt: return 1;
            case EPrimalEquipmentType::Gloves: return 2;
            case EPrimalEquipmentType::Pants: return 3;
            case EPrimalEquipmentType::Boots: return 4;
            default: return -1;
        }
    };

    std::array<UPrimalItem*, 6> ValidArmorItems = {nullptr, nullptr, nullptr, nullptr, nullptr};
    int NumArmorToDraw = 0;

    for (UPrimalItem* Armor : EquippedItems)
    {
        if (!Armor)
            continue;

        int32 SlotIndex = GetSlotIndex(Armor);
        if (SlotIndex >= 0 && NumArmorToDraw < ValidArmorItems.size())
            ValidArmorItems[NumArmorToDraw++] = Armor;
    }

    if (NumArmorToDraw == 0)
        return;

    std::sort(ValidArmorItems.begin(), ValidArmorItems.begin() + NumArmorToDraw, [&](UPrimalItem* A, UPrimalItem* B) {
        return GetSlotIndex(A) < GetSlotIndex(B);
    });

    const float TotalWidth = NumArmorToDraw * SizeXY.X;
    const float StartX = ScreenPosition.X - (TotalWidth * 0.5f);

    UFont* RenderFont = GetRenderFont();

    for (auto Index{0}; Index < NumArmorToDraw; ++Index)
    {
        UPrimalItem* Armor = ValidArmorItems[Index];
        if (!Armor)
            continue;

        UTexture2D* Texture = Cast<UPrimalItem>(Armor->Class->DefaultObject)->ItemIcon;
        if (!Texture)
            continue;

        FLinearColor Color = ItemQualityColors[Armor->ItemQualityIndex];
        Color.A = 0.5f;

        const FVector2D DrawPosition(
                StartX + (Index * SizeXY.X),
                ScreenPosition.Y + (SizeXY.Y * 1.75f)
        );

        DrawTexture(Canvas, nullptr, DrawPosition, SizeXY, Color, false);
        DrawTexture(Canvas, Texture, DrawPosition, SizeXY, FLinearColor::White, false);

        int32 ItemDurability = int32(Armor->ItemDurability);

        const FVector2D TextPosition(
                StartX + (Index * SizeXY.X) + (SizeXY.X * 0.5f),
                ScreenPosition.Y + SizeXY.Y * (IsSelf ? 1.f : 2.f)
        );

        DrawText(Canvas, RenderFont, fmt::format(L"{}", ItemDurability).c_str(), TextPosition, FLinearColor::White, IsSelf ? 1.1f : 0.8f);
    }
}

void DrawBuffs(UCanvas* Canvas, APrimalCharacter* PrimalCharacter, const FVector2D& ScreenPosition, const FVector2D& SizeXY)
{
    TArray<APrimalBuff*> Buffs = PrimalCharacter->Buffs;
    if (!Buffs)
        return;

    auto Index{0};

    for (APrimalBuff* Buff : Buffs)
    {
        if (!Buff)
            continue;

        if (Buff->BuffDescription.ModifierIcon)
        {
            Index++;
        }
    }

    float TotalWidth = Index * SizeXY.X;
    float StartX = ScreenPosition.X - (TotalWidth / 2.0f);

    for (auto Index{0}; Index < Buffs.Num(); ++Index)
    {
        APrimalBuff* Buff = Buffs[Index];
        if (!Buff)
            continue;

      if (!Buff->BuffDescription.ModifierIcon)
            continue;

        const FVector2D DrawPosition(
                StartX + (Index * SizeXY.X),
                ScreenPosition.Y + (SizeXY.Y * 1.75f)
        );

        DrawTexture(Canvas, Cast<UTexture2D>(Buff->BuffDescription.ModifierIcon), DrawPosition, SizeXY, FLinearColor::White, false);
    }
}



std::map<int32, std::vector<FVector>> ResourceWorldPositions;
const std::vector<FVector>& GetFoliageLocations(UFoliageInstancedStaticMeshComponent* Resource)
{
    int32 InternalIndex = Resource->Index;
    std::vector<FVector>& Data = ResourceWorldPositions[InternalIndex];
    if (!Data.empty())
        return Data;

    if (!Resource->PerInstanceSMData)
        return Data;

    Data.reserve(Resource->PerInstanceSMData.Num() + 1);

    for (int32 i = 0; i < Resource->PerInstanceSMData.Num(); ++i)
    {
        FTransform OutTransform;
        if (Resource->GetInstanceTransform(i, &OutTransform, true))
        {
            Data.push_back(OutTransform.Translation);
        }
    }
    return Data;
}

bool IsAllied(AShooterCharacter* Character, int32 TeamID)
{
    AShooterPlayerState* PlayerState = UObject::Cast<AShooterPlayerState>(Character->PlayerState);
    if (PlayerState)
    {
        if (!PlayerState->MyTribeData.TribeAlliances)
            return false;

        for (const FTribeAlliance& Alliance : PlayerState->MyTribeData.TribeAlliances)
        {
            if (!Alliance.MembersTribeID)
                continue;

            for (int32 TribeID : Alliance.MembersTribeID)
            {
                if (TribeID == TeamID)
                    return true;
            }
        }
    }
    return false;
}

EActorSpecificType GetSpecificStructureType(APrimalStructure* Structure)
{
    if (Structure->IsA(APrimalStructureBed::StaticClass()))
    {
        return EActorSpecificType::Bed;
    }
    else if (Structure->IsA(APrimalStructureExplosive::StaticClass()))
    {
        return Structure->IsA(APrimalStructureExplosiveTransGPS::StaticClass())
               ? EActorSpecificType::None : EActorSpecificType::Explosive;
    }
    else if (Structure->IsA(APrimalStructureItemContainer::StaticClass()))
    {
        if (Structure->IsA(APrimalStructureTurret::StaticClass()))
        {
            if (Structure->IsA(APrimalStructureTurretPlant::StaticClass()))
                return EActorSpecificType::PlantX;
            else
                return EActorSpecificType::Turret;
        }
        else if (Structure->IsA(APrimalStructureItemContainer_SupplyCrate::StaticClass()))
        {
            return EActorSpecificType::SupplyCrate;
        }
        else if (Structure->Name.IsAny(FNames::DeathItemCache_C, FNames::DeathItemCache_PlayerDeath_C))
        {
            return EActorSpecificType::ItemCache;
        }
        else if (Structure->IsA(APrimalStructureElevatorTrack::StaticClass()) ||
                 Structure->IsA(APrimalStructureElevatorPlatform::StaticClass()) ||
                 Structure->IsA(APrimalStructureItemContainer_CropPlot::StaticClass()))
        {
            return EActorSpecificType::None;
        }
        else
        {
            return EActorSpecificType::Container;
        }
    }
    return EActorSpecificType::None;
}

FORCEINLINE EActorAssociation GetActorAssociation(AShooterCharacter* MySelf, AActor* Target)
{
    int32 TargetingTeam = Target->TargetingTeam;

    if (MySelf->TargetingTeam == TargetingTeam)
        return EActorAssociation::Team;
    else if (IsAllied(MySelf, TargetingTeam))
        return EActorAssociation::Ally;

    return EActorAssociation::Enemy;
}


FORCEINLINE bool ShouldStructureBeDrawn(EActorSpecificType Type)
{
    switch (Type)
    {
        case EActorSpecificType::Explosive:
            return settings.esp.Explosives;
        case EActorSpecificType::Bed:
            return settings.esp.Beds;
        case EActorSpecificType::Turret:
            return settings.esp.Turrets;
        case EActorSpecificType::PlantX:
            return settings.esp.PlantX;
        case EActorSpecificType::Container:
            return settings.esp.Containers;
        case EActorSpecificType::ItemCache:
            return settings.esp.ItemCache;
        case EActorSpecificType::SupplyCrate:
            return settings.esp.SupplyCrate;
        default:
            return false;
    }
}

FORCEINLINE bool ShouldResourceBeDrawn(EActorSpecificType Type)
{
    switch (Type)
    {
        case EActorSpecificType::Obsidian:
            return settings.esp.Obsidian;
        case EActorSpecificType::Oil:
            return settings.esp.Oil;
        case EActorSpecificType::Metal:
            return settings.esp.Metal;
        case EActorSpecificType::Crystal:
            return settings.esp.Crystal;
        case EActorSpecificType::Perl:
            return settings.esp.Perl;
        default:
            return false;
    }
}


std::unordered_map<int32, int32> FNameDinoMap(DinoClasses.size());

FORCEINLINE bool ShouldSpecificDinoBeDrawn(FName NamePrivate)
{
    int32 ComparisonIndex = NamePrivate.GetDisplayIndex();
    if (auto it = FNameDinoMap.find(ComparisonIndex); it != FNameDinoMap.end())
    {
        return settings.esp.AllDinosaurs[it->second];
    }
    return false;
}

FORCEINLINE FLinearColor GetColorByAssociationPlayer(EActorAssociation Association)
{
    if (Association == EActorAssociation::Team)
        return ConvertToFLinearColor(settings.esp.PlayerTeamColor);
    else if (Association == EActorAssociation::Ally)
        return ConvertToFLinearColor(settings.esp.PlayerAllyColor);
    else if (Association == EActorAssociation::Admin)
        return FLinearColor::Purple;

    return ConvertToFLinearColor(settings.esp.PlayerEnemyColor);
}

FORCEINLINE FLinearColor GetColorByAssociationDino(EActorAssociation Association)
{
    if (Association == EActorAssociation::Team)
        return ConvertToFLinearColor(settings.esp.DinoTeamColor);
    else if (Association == EActorAssociation::Ally)
        return ConvertToFLinearColor(settings.esp.DinoAllyColor);

    return ConvertToFLinearColor(settings.esp.DinoEnemyColor);
}

FORCEINLINE FLinearColor GetSpecificStructureColor(EActorSpecificType Type)
{
    switch (Type)
    {
        case EActorSpecificType::Explosive:
            return ConvertToFLinearColor(settings.esp.ExplosivesColor);
        case EActorSpecificType::Bed:
            return ConvertToFLinearColor(settings.esp.BedsColor);
        case EActorSpecificType::Turret:
            return ConvertToFLinearColor(settings.esp.TurretsColor);
        case EActorSpecificType::PlantX:
            return ConvertToFLinearColor(settings.esp.PlantXColor);
        case EActorSpecificType::Container:
            return ConvertToFLinearColor(settings.esp.ContainersColor);
        case EActorSpecificType::ItemCache:
            return ConvertToFLinearColor(settings.esp.ItemCacheColor);
        case EActorSpecificType::SupplyCrate:
            return ConvertToFLinearColor(settings.esp.SupplyCrateColor);
        default:
            return FLinearColor();
    }
}

FORCEINLINE FLinearColor GetColorByAssociationStructure(EActorAssociation Association, EActorSpecificType Type)
{
    if (Association == EActorAssociation::Team)
        return ConvertToFLinearColor(settings.esp.StructureTeamColor);
    else if (Association == EActorAssociation::Ally)
        return ConvertToFLinearColor(settings.esp.StructureAllyColor);

    return GetSpecificStructureColor(Type);
}

bool LocalIsPerMapExplorerNoteUnlocked(AShooterPlayerState* PlayerState, int32 ExplorerNoteIndex)
{
    const TArray<uint32>& PerMapExplorerNoteUnlocks = PlayerState->MyPlayerDataStruct.MyPersistentCharacterStats.PerMapExplorerNoteUnlocks;
    if (!PerMapExplorerNoteUnlocks)
        return false;

    int32 InArrayIndex = ((0 > ExplorerNoteIndex) ? (ExplorerNoteIndex + 31) : ExplorerNoteIndex) >> 5;
    if (ExplorerNoteIndex >= -31 && InArrayIndex && PerMapExplorerNoteUnlocks.Num() > InArrayIndex)
        return PerMapExplorerNoteUnlocks[InArrayIndex] & (1 << (ExplorerNoteIndex & 0x1F));

    return false;
}

struct
{
    std::vector<FPlayerActorData> PlayerBuffers[2];
    std::vector<FOtherActorData>  OtherBuffers[2];

    int32 FrontBufferIndex = 0;
    int32 BackBufferIndex = 1;

    std::atomic<bool> bIsNewDataReady{false};

    void Reserve(uint64 AllocForPlayers, uint64 AllocForOthers)
    {
        for (size_t i{0}; i < 2; ++i)
        {
            PlayerBuffers[i].reserve(AllocForPlayers);
            OtherBuffers[i].reserve(AllocForOthers);
        }
    }

    std::vector<FPlayerActorData>& GetFrontPlayerBuffer() { return PlayerBuffers[FrontBufferIndex]; }
    std::vector<FPlayerActorData>& GetBackPlayerBuffer()  { return PlayerBuffers[BackBufferIndex]; }

    std::vector<FOtherActorData>& GetFrontOtherBuffer() { return OtherBuffers[FrontBufferIndex]; }
    std::vector<FOtherActorData>& GetBackOtherBuffer()  { return OtherBuffers[BackBufferIndex]; }


    void WaitForRender()
    {
        bIsNewDataReady.wait(true, std::memory_order_acquire);
    }

    void Publish()
    {
        bIsNewDataReady.store(true, std::memory_order_release);
    }

    bool TrySwap()
    {
        if (!bIsNewDataReady.load(std::memory_order_acquire))
            return false;

        std::swap(FrontBufferIndex, BackBufferIndex);

        bIsNewDataReady.store(false, std::memory_order_release);
        bIsNewDataReady.notify_one();
        return true;
    }

}DrawBuffer;


void DrawDataThread()
{
    DrawBuffer.Reserve(64, 512);
    while (true)
    {
        if (!settings.esp.Enable)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            continue;
        }

        DrawBuffer.WaitForRender();

        auto& PlayerBuffer = DrawBuffer.GetBackPlayerBuffer();
        auto& OtherBuffer  = DrawBuffer.GetBackOtherBuffer();

        PlayerBuffer.clear();
        OtherBuffer.clear();

        AShooterPlayerController* PC = GetPlayerController();
        if (!PC)
            continue;

        AShooterCharacter* MySelf = GetPlayerCharacter(PC);
        if (!MySelf)
            continue;

        FVector MyLocation = GetActorLocation(MySelf);

        FMatrix const& ViewProjMatrix = GetViewProjectionMatrix();

        if (settings.esp.Players)
        {
            const TArray<AActor*>& Players = GetActors<EActorListsBP::AL_PLAYERS>();
            for (auto Index{0}; Index < Players.Num(); ++Index)
            {
                if (!MySelf || !PC)
                    break;

                AShooterCharacter* Player = Cast<AShooterCharacter>(Players[Index]);
                if (!Player)
                    continue;

                if (Player == MySelf)
                    continue;

                USkeletalMeshComponent* Mesh = Player->Mesh;
                if (!Mesh)
                    continue;

                EActorAssociation Association = GetActorAssociation(MySelf, Player);
                if (Player->bIsServerAdmin)
                    Association = EActorAssociation::Admin;

                if (!settings.esp.AllyPlayers && Association == EActorAssociation::Ally)
                    continue;

                if (!settings.esp.TeamPlayers && Association == EActorAssociation::Team)
                    continue;

                const bool IsSleeping = Player->bIsSleeping;
                const bool IsDead     = Player->bIsDead;

                if (!settings.esp.Dead && IsDead)
                    continue;

                if (!settings.esp.Sleeping && IsSleeping)
                    continue;

                FVector PlayerLocation = GetActorLocation(Player);

                int Distance = MyLocation.GetDistanceToInMeters(PlayerLocation);
                if (Distance > 2000)
                    continue;

                FVector TopLocation = PlayerLocation, BottomLocation = PlayerLocation;
                TopLocation.Z    += Mesh->Bounds.BoxExtent.Z;
                BottomLocation.Z -= Mesh->Bounds.BoxExtent.Z;

                FVector2D TopScreenLocation, BottomScreenLocation;
                if (ProjectWorldToScreen(TopLocation, TopScreenLocation, ViewProjMatrix, true) &&
                    ProjectWorldToScreen(BottomLocation, BottomScreenLocation, ViewProjMatrix, false))
                {
                    FLinearColor DrawColor = GetColorByAssociationPlayer(Association);

                    UPrimalCharacterStatusComponent* MyCharacterStatusComponent = Player->MyCharacterStatusComponent;
                    if (!MyCharacterStatusComponent)
                        continue;

                    std::wstring WStr = fmt::format(L"Lvl-{} {} [{}m]", GetLevel(MyCharacterStatusComponent), Player->PlayerName.CStr(), Distance);

                    PlayerBuffer.emplace_back(std::move(WStr), Player, TopScreenLocation, BottomScreenLocation, EActorType::Player, Association, true, DrawColor);
                }
                else
                {
                    if (IsDead || IsSleeping)
                        continue;

                    if (Association == EActorAssociation::Enemy)
                        PlayerBuffer.emplace_back(L"", Player, TopScreenLocation, BottomScreenLocation, EActorType::Player, Association, false, FLinearColor::Yellow);
                }
            }
        }

        if (settings.esp.ExplorerNotes && !settings.esp.HideResource)
        {
            const TArray<AActor*>& ExplorerNotes = GetActors<EActorListsBP::AL_PREMIUMSTRUCTURES>();
            for (auto Index{0}; Index < ExplorerNotes.Num(); ++Index)
            {
                AExplorerChest_Base_C* ExplorerNote = Cast<AExplorerChest_Base_C>(ExplorerNotes[Index]);
                if (!ExplorerNote)
                    continue;

                if (!MySelf || !PC)
                    break;

                AShooterPlayerState* PlayerState = Cast<AShooterPlayerState>(MySelf->PlayerState);
                if (!PlayerState)
                    continue;

                int32 ExplorerNoteIndex = ExplorerNote->ExplorerNoteIndex;
                if (LocalIsPerMapExplorerNoteUnlocked(PlayerState, ExplorerNoteIndex))
                    continue;

                FVector ExplorerNoteLocation = GetActorLocation(ExplorerNote);

                FVector2D ScreenLocation;
                if (!ProjectWorldToScreen(ExplorerNoteLocation, ScreenLocation, ViewProjMatrix))
                    continue;

                int32 Distance = MyLocation.GetDistanceToInMeters(ExplorerNoteLocation);

                std::wstring Name = fmt::format(L"Explorer Note [{}m]", Distance);

                OtherBuffer.emplace_back(std::move(Name), ExplorerNote, ScreenLocation, EActorType::FoliageActor, EActorSpecificType::ExplorerNote, ConvertToFLinearColor(settings.esp.ResourceColor));
            }
        }

        if (settings.esp.Dinosaurs || settings.esp.Structures || settings.esp.Eggs)
        {
            const TArray<AActor*>& Actors = GetActors();
            for (auto Index{0}; Index < Actors.Num(); ++Index)
            {
                AActor* Actor = Actors[Index];
                if (!Actor)
                    continue;

                if (!MySelf || !PC)
                    break;

                if (settings.esp.Dinosaurs && Actor->IsA(APrimalDinoCharacter::StaticClass()))
                {
                    if (settings.esp.HideDinosaur)
                        continue;

                    APrimalDinoCharacter* Dino = (APrimalDinoCharacter*)Actor;
                    if (!Dino)
                        continue;

                    USkeletalMeshComponent* Mesh = Dino->Mesh;
                    if (!Mesh)
                        continue;

                    if (settings.esp.UseDinoSearch && !ShouldSpecificDinoBeDrawn(Dino->Name))
                        continue;

                    const bool bIsWild = IsWild(Dino);

                    if (!settings.esp.WildDino && bIsWild)
                        continue;

                    EActorAssociation Association = GetActorAssociation(MySelf, Dino);

                    if (!settings.esp.AllyDino && Association == EActorAssociation::Ally)
                        continue;

                    if (!settings.esp.TeamDino && Association == EActorAssociation::Team)
                        continue;

                    UPrimalCharacterStatusComponent* MyCharacterStatusComponent = Dino->MyCharacterStatusComponent;
                    if (!MyCharacterStatusComponent)
                        continue;

                    int32 Level = GetLevel(MyCharacterStatusComponent);

                    if (bIsWild && settings.esp.MinDinoLevel > Level)
                        continue;

                    FVector Location = GetActorLocation(Dino);

                    FVector2D ScreenLocation;
                    if (!ProjectWorldToScreen(Location, ScreenLocation, ViewProjMatrix))
                        continue;

                    int Distance = MyLocation.GetDistanceToInMeters(Location);

                    FString DescriptiveName = Dino->DescriptiveName.GetDisplayString();
                    if (!DescriptiveName)
                        continue;

                    std::wstring Name = fmt::format(L"Level-{} {} [{}m]", Level, DescriptiveName.CStr(), Distance);

                    OtherBuffer.emplace_back(std::move(Name), Dino, ScreenLocation, EActorType::Dinosaur, EActorSpecificType::None, bIsWild ? ConvertToFLinearColor(settings.esp.DinoWildColor) : GetColorByAssociationDino(Association));
                }
                else
                if (settings.esp.Structures && Actor->IsA(APrimalStructure::StaticClass()))
                {
                    if (settings.esp.HideStructure)
                        continue;

                    APrimalStructure* Structure = (APrimalStructure*)Actor;
                    if (!Structure)
                        continue;

                    EActorAssociation Association = GetActorAssociation(MySelf, Actor);

                    if (!settings.esp.AllyStructures && Association == EActorAssociation::Ally)
                        continue;

                    if (!settings.esp.TeamStructures && Association == EActorAssociation::Team)
                        continue;

                    EActorSpecificType SpecType = GetSpecificStructureType(Structure);
                    if (!ShouldStructureBeDrawn(SpecType))
                        continue;

                    FVector StructureLocation = GetActorLocation(Structure);

                    int Distance = MyLocation.GetDistanceToInMeters(StructureLocation);

                    if (settings.esp.MaxDistance < Distance)
                        continue;

                    FVector2D ScreenLocation;
                    if (!ProjectWorldToScreen(StructureLocation, ScreenLocation, ViewProjMatrix))
                        continue;

                    FString DescriptiveName = Structure->DescriptiveName.GetDisplayString();
                    if (!DescriptiveName)
                        continue;

                    std::wstring Name;

                    if (SpecType == EActorSpecificType::Turret)
                    {
                        APrimalStructureTurret* Turret = (APrimalStructureTurret*)Structure;
                        const bool bIsPowered = Turret->bIsPowered;

                        int32 NumBullets = Turret->NumBullets;
                        if (NumBullets)
                            Name = fmt::format(L"{} [{}m]\n[Bullets: {}] {}", DescriptiveName.CStr(), Distance, NumBullets, bIsPowered ? L"Powered" : L"Unpowerd");
                        else
                            Name = fmt::format(L"{} [{}m]\n[Empty] {}", DescriptiveName.CStr(), Distance, bIsPowered ? L"Powered" : L"Unpowerd");
                    }
                    else
                    {
                        Name = fmt::format(L"{} [{}m]", DescriptiveName.CStr(), Distance);
                    }

                    OtherBuffer.emplace_back(std::move(Name), Structure, ScreenLocation, EActorType::Structure, SpecType, GetColorByAssociationStructure(Association, SpecType));
                }
                else if (settings.esp.Eggs && Actor->IsA(ADroppedItemEgg::StaticClass()))
                {
                    UPrimalItem* MyItem = Cast<ADroppedItemEgg>(Actor)->MyItems[0];
                    if (!MyItem)
                        continue;

                    FVector Location = GetActorLocation(Actor);

                    FVector2D ScreenLocation;
                    if (!ProjectWorldToScreen(Location, ScreenLocation, ViewProjMatrix))
                        continue;

                    int Distance = MyLocation.GetDistanceToInMeters(Location);

                    FString DescriptiveNameBase = MyItem->DescriptiveNameBase.GetDisplayString();
                    if (!DescriptiveNameBase)
                        continue;

                    FString CustomItemDescription = MyItem->CustomItemDescription;


                    std::wstring Name = fmt::format(L"{} [{}m]\n{}", *DescriptiveNameBase, Distance, !CustomItemDescription.IsEmpty() ? *CustomItemDescription : TEXT("No Parents"));


                    OtherBuffer.emplace_back(std::move(Name), Actor, ScreenLocation, EActorType::Egg, EActorSpecificType::None, FLinearColor::Gray);
                }

            }
        }

        if (settings.esp.Resources && !settings.esp.HideResource)
        {
            static std::unordered_map<int32, EActorSpecificType> ResourceTypes =
            {
                    {FName(L"MetalHarvestComponent_C").GetDisplayIndex(), EActorSpecificType::Metal},
                    {FName(L"MetalHarvestComponent_Rich_C").GetDisplayIndex(), EActorSpecificType::Metal},
                    {FName(L"MountainObsidianHarvestComponent_C").GetDisplayIndex(), EActorSpecificType::Obsidian},
                    {FName(L"SiliconHarvestComponent_C").GetDisplayIndex(), EActorSpecificType::Perl},
                    {FName(L"OilHarvestComponent_C").GetDisplayIndex(), EActorSpecificType::Oil},
                    {FName(L"OilHarvestComponentRich_C").GetDisplayIndex(), EActorSpecificType::Oil},
                    {FName(L"OilHarvestComponentUnderwater_C").GetDisplayIndex(), EActorSpecificType::Oil},
                    {FName(L"ObsidianHarvestComponent_C").GetDisplayIndex(), EActorSpecificType::Obsidian},
                    {FName(L"CrystalHarvestComponent_C").GetDisplayIndex(), EActorSpecificType::Crystal},
                    {FName(L"CrystalHarvestComponent_Summit_C").GetDisplayIndex(), EActorSpecificType::Crystal},
                    {FName(L"CrystalHarvestComponent_UnderwaterCave_C").GetDisplayIndex(), EActorSpecificType::Crystal}
            };

            if (UWorld* World = UWorld::GetWorld())
            {
                World = nullptr;
                const TArray<ULevel*>& Levels = World->Levels;
                for (int32 Idx = 1; Idx < Levels.Num(); ++Idx)
                {
                    ULevel* Level = Levels[Idx];
                    if (!Level)
                        continue;

                    const TArray<AActor*>& Actors = GetActors(Level);
                    for (auto Index{0}; Index < Actors.Num(); ++Index)
                    {
                        AActor* Actor = Actors[Index];
                        if (!Actor)
                            continue;

                        if (!MySelf || !PC)
                            break;

                        if (!Actor || !Actor->IsA(AInstancedFoliageActor::StaticClass()))
                            continue;

                        const TSet<UActorComponent*>& OwnedComponents = Actor->OwnedComponents;
                        if (!OwnedComponents.IsValid())
                            continue;

                        for (UActorComponent* Component : OwnedComponents)
                        {
                            UFoliageInstancedStaticMeshComponent* FISMComponent = UObject::Cast<UFoliageInstancedStaticMeshComponent>(Component);
                            if (!FISMComponent)
                                continue;

                            UPrimalHarvestingComponent* ReferencedAttachedComponent = UObject::Cast<UPrimalHarvestingComponent>(FISMComponent->ReferencedAttachedComponent);
                            if (!ReferencedAttachedComponent)
                                continue;

                            auto ResourceInfo = ResourceTypes.find(ReferencedAttachedComponent->Name.GetDisplayIndex());
                            if (ResourceInfo == ResourceTypes.end())
                                continue;

                            if (!ShouldResourceBeDrawn(ResourceInfo->second))
                                continue;

                            FString DescriptiveName = ReferencedAttachedComponent->DescriptiveName.GetDisplayString();
                            if (!DescriptiveName)
                                continue;

                            const std::vector<FVector>& FoliageLocations = GetFoliageLocations(FISMComponent);
                            for (int i = 0; i < FoliageLocations.size(); ++i)
                            {
                                bool IsVisible = FISMComponent->InstancesVisibility[i / 32] >> i & 1;
                                if (!IsVisible)
                                    continue;

                                const FVector& Location = FoliageLocations[i];

                                FVector2D ScreenLocation;
                                if (!ProjectWorldToScreen(Location, ScreenLocation, ViewProjMatrix))
                                    continue;

                                int Distance = int(MyLocation.GetDistanceToInMeters(Location));
                                std::wstring Name = fmt::format(L"{} [{}m]", DescriptiveName.CStr(), Distance);

                                OtherBuffer.emplace_back(std::move(Name), Actor, ScreenLocation, EActorType::FoliageActor, ResourceInfo->second, ConvertToFLinearColor(settings.esp.ResourceColor));
                            }
                        }

                    }
                }
            }
        }

        DrawBuffer.Publish();
    }
}

#pragma mark - Aimbot -

EPrimalEquipmentType GetWeakestArmor(AShooterCharacter* Target)
{
    if (!Target)
        return EPrimalEquipmentType::Hat;

    UPrimalInventoryComponent* MyInventoryComponent = Target->MyInventoryComponent;
    if (!MyInventoryComponent)
        return EPrimalEquipmentType::Hat;

    bool HasHat = false, HasShirt = false, HasPants = false, HasGloves = false;

    UPrimalItem* WeakestItem = nullptr;
    float WeakestDurability = FLT_MAX;

    for (UPrimalItem* Item : MyInventoryComponent->EquippedItems)
    {
        if (!Item)
            continue;

        EPrimalEquipmentType MyEquipmentType = Item->MyEquipmentType;
        if (static_cast<uint8>(MyEquipmentType) > 4)
            continue;

        switch (MyEquipmentType)
        {
            case EPrimalEquipmentType::Hat: HasHat = true; break;
            case EPrimalEquipmentType::Shirt: HasShirt = true; break;
            case EPrimalEquipmentType::Pants: HasPants = true; break;
            case EPrimalEquipmentType::Gloves: HasGloves = true; break;
            default: break;
        }

        float ItemDurability = Item->ItemDurability;
        if (WeakestDurability > ItemDurability && MyEquipmentType != EPrimalEquipmentType::Boots)
        {
            WeakestItem = Item;
            WeakestDurability = ItemDurability;
        }
    }

    if (!HasHat)
        return EPrimalEquipmentType::Hat;
    else if (!HasShirt)
        return EPrimalEquipmentType::Shirt;
    else if (!HasPants)
        return EPrimalEquipmentType::Pants;
    else if (!HasGloves)
        return EPrimalEquipmentType::Gloves;

    if (WeakestItem)
        return WeakestItem->MyEquipmentType;

    return EPrimalEquipmentType::Hat;
}




int32 GetBoneIdxByArmorType(EPrimalEquipmentType ArmorType, bool bFemale)
{
    if (bFemale)
    {
        switch (ArmorType)
        {
            case EPrimalEquipmentType::Hat:
                return FemaleBones::Cnt_Head_JNT_SKL;
                break;
            case EPrimalEquipmentType::Shirt:
                return FemaleBones::Cnt_Chest_000_JNT_SKL;
                break;
            case EPrimalEquipmentType::Pants:
                return FemaleBones::Rht_Leg_002Tear000_JNT_SKL;
                break;
            case EPrimalEquipmentType::Gloves:
                return FemaleBones::Lft_Arm_002Tear000_JNT_SKL;
                break;
            default:
                return FemaleBones::Cnt_Head_JNT_SKL;
                break;
        }
    }
    else
    {
        switch (ArmorType)
        {
            case EPrimalEquipmentType::Hat:
                return MaleBones::Cnt_Head_JNT_SKL;
                break;
            case EPrimalEquipmentType::Shirt:
                return MaleBones::Cnt_Chest_000_JNT_SKL;
                break;
            case EPrimalEquipmentType::Pants:
                return MaleBones::Rht_Leg_002Tear000_JNT_SKL;
                break;
            case EPrimalEquipmentType::Gloves:
                return MaleBones::Lft_Arm_002Tear000_JNT_SKL;
                break;
            default:
                return MaleBones::Cnt_Head_JNT_SKL;
                break;
        }
    }
}

constexpr std::array<int32, 4> MaleTargetBones =
{
        MaleBones::Cnt_Head_JNT_SKL,
        MaleBones::Cnt_Chest_000_JNT_SKL,
        MaleBones::Rht_Leg_002Tear000_JNT_SKL,
        MaleBones::Lft_Arm_002Tear000_JNT_SKL
};

constexpr std::array<int32, 4> FemaleTargetBones =
{
        FemaleBones::Cnt_Head_JNT_SKL,
        FemaleBones::Cnt_Chest_000_JNT_SKL,
        FemaleBones::Rht_Leg_002Tear000_JNT_SKL,
        FemaleBones::Lft_Arm_002Tear000_JNT_SKL
};

FORCEINLINE int32 GetTargetBoneName(bool bFemale)
{
    return bFemale ? FemaleTargetBones[settings.AimTargetIndex] : MaleTargetBones[settings.AimTargetIndex];
}

std::filesystem::path GetDocumentsPath()
{
    return std::string(getenv("HOME")) + std::string("/Documents");
}

void DumpToFile(const char* FolderDir, const char* FileName, const std::vector<std::string>& Data)
{
    std::filesystem::path DocumentsPath(GetDocumentsPath());

    if (!std::filesystem::exists(DocumentsPath / FolderDir))
        std::filesystem::create_directory(DocumentsPath / FolderDir);

    std::filesystem::path Path = DocumentsPath / FolderDir / FileName;

    std::ofstream File(Path);
    if (File.is_open())
    {
        for (const std::string& Line : Data)
            File << Line;

        File.close();
    }
}

void DumpToFile(const char* FolderDir, const char* FileName, const std::vector<uint8_t>& Data)
{
    std::filesystem::path DocumentsPath(GetDocumentsPath());

    if (!std::filesystem::exists(DocumentsPath / FolderDir))
        std::filesystem::create_directory(DocumentsPath / FolderDir);

    std::filesystem::path Path = DocumentsPath / FolderDir / FileName;

    std::ofstream File(Path, std::ios::binary);
    if (File.is_open())
    {
        File.write(reinterpret_cast<const char*>(Data.data()), Data.size());
        File.close();
    }
}

// This contains Reference-skeleton related info
// Bone transform is saved as FTransform array
struct FMeshBoneInfo
{
    // Bone's name.
    FName Name;

    // 0/NULL if this is the root bone.
    int32 ParentIndex;
    int32 Padding;
};

FORCEINLINE FName GetBoneName(USkeletalMeshComponent* Mesh, int32 Index)
{
    if (USkeletalMesh* SkeletalMesh = Mesh->SkeletalMesh)
    {
        TArray<FMeshBoneInfo> FinalRefBoneInfo = *(TArray<FMeshBoneInfo>*)((uint8*)SkeletalMesh + 0x168);
        return FinalRefBoneInfo[Index].Name;
    }
    return {};
}

void DumpBones()
{
    if (AShooterCharacter* Character = GetPlayerCharacter())
    {
        if (USkeletalMeshComponent* Mesh = Character->Mesh)
        {
            if (USkeletalMesh* SkeletalMesh = Mesh->SkeletalMesh)
            {
                std::vector<std::string> Data;

                TArray<FMeshBoneInfo> FinalRefBoneInfo = *(TArray<FMeshBoneInfo>*)((uint8*)SkeletalMesh + 0x168);

                for (int32 Idx = 0; Idx < FinalRefBoneInfo.Num(); ++Idx)
                {
                    FMeshBoneInfo BoneInfo = FinalRefBoneInfo[Idx];

                    Data.push_back(fmt::format("[{}] {}\n", Idx, BoneInfo.Name.ToString()));
                }

                DumpToFile("Dumpspace", "Bones.txt", Data);
            }
        }
    }
}



bool HasBuff(APrimalCharacter* PrimalChar, FName BuffName)
{
    for (APrimalBuff* Buff : PrimalChar->Buffs)
    {
        if (Buff && Buff->Name == BuffName)
            return true;
    }
    return false;
}

bool (*LineOfSightTo)(AController* _this, const AActor* Other, FVector ViewPoint, bool bAlternateChecks) = nullptr;

struct TargetInfo
{
    APrimalCharacter* Target;
    FVector WorldPosition;
    FVector2D ScreenPosition;
    FName TargetBone;
};

TargetInfo GetBestTarget()
{
    TargetInfo PlayerRet;
    TargetInfo DinoRet;

    AShooterPlayerController* PlayerController = GetPlayerController();
    if (!PlayerController)
        return PlayerRet;

    AShooterCharacter* ShooterSelf = GetPlayerCharacter(PlayerController);
    if (!ShooterSelf)
        return PlayerRet;

    FVector MyLocation = GetActorLocation(ShooterSelf);

    /*AShooterWeapon* CurrentWeapon = ShooterSelf->CurrentWeapon;
    if (!CurrentWeapon || !CurrentWeapon->IsA(AShooterWeapon_Instant::StaticClass()))
         return PlayerRet;*/

    const FMatrix& ViewProjMatrix = GetViewProjectionMatrix();

    float CurrentBestDistance  = FLT_MAX;
    float CurrentBestWorldDist = FLT_MAX;

    const TArray<AActor*>& Players = GetActors<EActorListsBP::AL_PLAYERS>();
    for (auto Index{0}; Index < Players.Num(); ++Index)
    {
        if (!ShooterSelf || !PlayerController)
            break;

        AShooterCharacter* Player = Cast<AShooterCharacter>(Players[Index]);
        if (!Player || Player == ShooterSelf)
            continue;

        USkeletalMeshComponent* Mesh = Player->Mesh;
        if (!Mesh)
            continue;

        if (Player->bIsDead || Player->bIsSleeping)
            continue;

        if (EActorAssociation::Enemy != GetActorAssociation(ShooterSelf, Player))
            continue;

        APrimalDinoCharacter* RidingDino = nullptr;
        if (settings.SlowDinosAimbot && Player->bIsRiding)
            RidingDino = Player->RidingDino.GetSafe();

        if (RidingDino && RidingDino->Mesh && RidingDino->bIsFlyerDino && RidingDino->bIsFlying && !HasBuff(RidingDino, FNames::Buff_FlyerSlowdown_C))
        {
            FVector AimLocation = GetBoneLocation(RidingDino->Mesh, 0, RidingDino->Mesh->ComponentToWorld);
            if (AimLocation.IsZero() || !LineOfSightTo(PlayerController, ShooterSelf, AimLocation, false))
                continue;

            float Distance = MyLocation.GetDistanceTo(AimLocation);
            if (Distance > CurrentBestWorldDist)
                continue;

            CurrentBestWorldDist = Distance;

            FVector2D ScreenLocation;
            ProjectWorldToScreen(AimLocation, ScreenLocation, ViewProjMatrix, true);

            DinoRet.Target          = RidingDino;
            DinoRet.WorldPosition   = AimLocation;
            DinoRet.ScreenPosition  = ScreenLocation;
            DinoRet.TargetBone      = GetBoneName(RidingDino->Mesh, 0);
        }
        else
        {
            int32 AimBoneIndex = settings.AimAtWeakestArmor ? GetBoneIdxByArmorType(GetWeakestArmor(Player), Player->bIsFemale)
                                 : GetTargetBoneName(Player->bIsFemale);

            FVector AimLocation = GetBoneLocation(Mesh, AimBoneIndex, Mesh->ComponentToWorld);
            if (AimLocation.IsZero() || !LineOfSightTo(PlayerController, ShooterSelf, AimLocation, false))
                continue;

            FVector2D ScreenLocation;
            ProjectWorldToScreen(AimLocation, ScreenLocation, ViewProjMatrix, true);

            float Distance = HalfViewportSize.GetDistanceTo(ScreenLocation);

            if (settings.UseAimFOV && Distance > settings.AimFOVRadius)
                continue;

            if (Distance > CurrentBestDistance)
                continue;

            CurrentBestDistance = Distance;

            PlayerRet.Target          = Player;
            PlayerRet.WorldPosition   = AimLocation;
            PlayerRet.ScreenPosition  = ScreenLocation;
            PlayerRet.TargetBone      = GetBoneName(Mesh, AimBoneIndex);
        }
    }

    if (DinoRet.Target)
        return DinoRet;

    return PlayerRet;
}

AShooterCharacter* GetBestTargetV2(AShooterCharacter* ShooterSelf)
{
    AShooterCharacter* Ret = nullptr;

    AShooterWeapon* CurrentWeapon = ShooterSelf->CurrentWeapon;
    if (!CurrentWeapon || !CurrentWeapon->IsA(AShooterWeapon_Instant::StaticClass()))
         return Ret;

    const FMatrix& ViewProjMatrix = GetViewProjectionMatrix();

    float CurrentBestDistance = FLT_MAX;

    const TArray<AActor*>& Players = GetActors<EActorListsBP::AL_PLAYERS>();
    for (auto Index{0}; Index < Players.Num(); ++Index)
    {
        if (!ShooterSelf || !ShooterSelf->Controller)
            break;

        AShooterCharacter* Player = Cast<AShooterCharacter>(Players[Index]);
        if (!Player || Player == ShooterSelf)
            continue;

        USkeletalMeshComponent* Mesh = Player->Mesh;
        if (!Mesh)
            continue;

        if (Player->bIsDead || Player->bIsSleeping)
            continue;

        if (EActorAssociation::Enemy != GetActorAssociation(ShooterSelf, Player))
            continue;

        int32 AimBoneIndex = settings.AimAtWeakestArmor ? GetBoneIdxByArmorType(GetWeakestArmor(Player), Player->bIsFemale)
                             : GetTargetBoneName(Player->bIsFemale);

        FVector AimLocation = GetBoneLocation(Mesh, AimBoneIndex, Mesh->ComponentToWorld);
        if (AimLocation.IsZero())
            continue;

        if (!LineOfSightTo(ShooterSelf->Controller, ShooterSelf, AimLocation, false))
            continue;

        FVector2D ScreenLocation;
        ProjectWorldToScreen(AimLocation, ScreenLocation, ViewProjMatrix, true);

        float Distance = HalfViewportSize.GetDistanceTo(ScreenLocation);
        if (Distance > CurrentBestDistance)
            continue;

        CurrentBestDistance = Distance;
        Ret = Player;
    }

    return Ret;
}

#pragma mark - Normal Functions -

namespace Automatics
{
    void ArmorEquipment(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void MedConsumption(AShooterCharacter* MySelf, AShooterPlayerController* PC); // to fix
    void StamConsumption(AShooterCharacter* MySelf, AShooterPlayerController* PC); // to implement
    void RemountingDino(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void FoodConsumption(AShooterCharacter* MySelf, AShooterPlayerController* PC); // to implement

    void DinosaurHealing(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void Looting(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void UnlockNearbyNotes(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void TurretSettings(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void PickupEggs(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void RemountDinosaur(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void FireProjectile(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void FireWeapon(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void FireBallistaProjectile(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void Explosions(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void AutoGrabPlayer(AShooterCharacter* MySelf, AShooterPlayerController* PC); // to implement
    void AutoDestroyStructure(AShooterCharacter* MySelf, AShooterPlayerController* PC);
    void AutoDropItems(AShooterCharacter* MySelf, AShooterPlayerController* PC);
}

void Automatics::AutoDropItems(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    std::wstring CurrentNameFilter(CurrentDropItemFilterString.begin(), CurrentDropItemFilterString.end());

    FInventoryFilter Filter = {};
    Filter.FilterString = CurrentNameFilter.c_str();
    Filter.ItemTypeFilter = (EPrimalItemType)settings.ItemTypeFilter;
    Filter.EquipmentTypeFilter = (EPrimalEquipmentType)settings.EquipmentTypeFilter;
    Filter.ConsumableTypeFilter = (EPrimalConsumableType)settings.ConsumableTypeFilter;

    PC->ServerRequestDropAllItems(TEXT(""), CurrentNameFilter.c_str(), Filter);
}

void Automatics::AutoGrabPlayer(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    if (!MySelf->bIsRiding)
        return;

    APrimalDinoCharacter* Dino = Cast<APrimalDinoCharacter>(PC->Character);
    if (!Dino || !Dino->bIsFlyerDino || !Dino->bIsFlying || Dino->CarriedCharacter.IsValid())
        return;

    FVector RidingDinoLocation = GetActorLocation(Dino);

    const TArray<AActor*>& Players = GetActors<EActorListsBP::AL_PLAYERS>();
    for (auto Index{0}; Index < Players.Num(); ++Index)
    {
        AShooterCharacter* Player = Cast<AShooterCharacter>(Players[Index]);
        if (!Player || Player == MySelf || Player->bIsSleeping || Player->bIsDead)
            continue;

        if (EActorAssociation::Enemy != GetActorAssociation(MySelf, Player))
            continue;

        if (RidingDinoLocation.GetDistanceTo(GetActorLocation(Player)) > 1500)
            continue;

        return Dino->ServerRequestAttack(1);
    }
}

void Automatics::AutoDestroyStructure(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    if (!PC->TargetingObject)
        return;

    APlayerCameraManager* PCM = PC->PlayerCameraManager;
    if (!PCM)
        return;

    FVector Start = PCM->CameraCache.POV.Location;
    FVector Dir   = PCM->CameraCache.POV.Rotation.Vector().GetSafeNormal();
    FVector End   = Start + Dir * 10000.0f;

    TAllocatedArray<AActor*> ActorsToIgnore(1);
    ActorsToIgnore.Add(MySelf);

    FHitResult OutResult;
    if (!UKismetSystemLibrary::LineTraceSingle(UWorld::GetWorld(), Start, End, ECollisionChannel::ECC_Visibility, false, ActorsToIgnore, EDrawDebugTrace::None, &OutResult, true, FLinearColor::Transparent, FLinearColor::Transparent, 0.f))
        return;

    AActor* Target = OutResult.Actor.GetSafe();
    if (!Target || !Target->IsA(APrimalStructure::StaticClass()))
        return;

    if (Target->TargetingTeam != MySelf->TargetingTeam)
        return;

    PC->ServerMultiUse(Target, 201, 0, true, false);
}

bool CanEatItem(APrimalDinoCharacter* Dino, TSubclassOf<UPrimalItem> ItemClass)
{
    if (UPrimalDinoSettings* MyDinoSettings = Dino->MyDinoSettingsCDO)
    {
        for (int32 i = 0; i < MyDinoSettings->FoodEffectivenessMultipliers.Num(); ++i)
        {
            const auto& Multiplier = MyDinoSettings->FoodEffectivenessMultipliers[i];

            UClass* FoodItemParent = UKismetSystemLibrary::Conv_SoftClassReferenceToClass(Multiplier.FoodItemParent);
            if (FoodItemParent && ItemClass->IsChildOf(FoodItemParent))
            {
                return Multiplier.AffinityEffectivenessMultiplier > 0.f;
            }
        }
    }
    return false;
}


void Automatics::DinosaurHealing(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    if (!MySelf->bIsRiding)
        return;

    APrimalDinoCharacter* Dino = UObject::Cast<APrimalDinoCharacter>(PC->Character);
    if (!Dino)
        return;

    if (!Dino->bIsCarnivore && !Dino->bIsFlyerDino)
        return;

    UPrimalInventoryComponent* InventoryComponent = Dino->MyInventoryComponent;
    if (!InventoryComponent)
        return;

    UPrimalCharacterStatusComponent* StatusComponent = Dino->MyCharacterStatusComponent;
    if (!StatusComponent)
        return;

    if (StatusComponent->CurrentStatusValues[0] == StatusComponent->MaxStatusValues[0])
        return;

    for (UPrimalItem* Item : InventoryComponent->InventoryItems)
    {
        if (!Item || Item->MyItemType != EPrimalItemType::MiscConsumable || !Dino->CanEatItem(Item->Class))
            continue;

        PC->ServerRequestInventoryUseItem(InventoryComponent, Item->ItemID);
        return;
    }
}

void Automatics::Explosions(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    if (!PC->PlayerCameraManager)
        return;

    if (!MySelf->CurrentDungeon)
        return;

    PC->ServerRequestPlaceStructure(
        36,
        GetActorLocation(MySelf),
        GetActorRotation(MySelf),
        PC->PlayerCameraManager->CameraCache.POV.Rotation,
        nullptr,
        nullptr,
        FName(),
        FItemNetID(),
        FPreferredSnapData(),
        false,
        false,
        false,
        0,
        true
    );
}

enum class ERangeSettings : uint8
{
    Low = 0,
    Medium = 1,
    High = 2
};

enum class EAISettings : uint8
{
    AllTargets = 0,
    OnlySurvivorOrTamedCreatures = 1,
    OnlySurvivors = 2,
    OnlyWildCreatures = 3
};

void Automatics::TurretSettings(AShooterCharacter *MySelf, AShooterPlayerController *PC)
{
    UPrimalInventoryComponent* InventoryComponent = MySelf->MyInventoryComponent;
    if (!InventoryComponent)
        return;

    const TArray<AActor*>& Actors = GetActors();
    for (auto Index{0}; Index < Actors.Num(); ++Index)
    {
        APrimalStructureTurret* Turret = UObject::Cast<APrimalStructureTurret>(Actors[Index]);
        if (!Turret)
            continue;

        if (Turret == PC->StructurePlacer->CurrentPlacingStructure)
            continue;

        if (MySelf->TargetingTeam == Turret->TargetingTeam)
        {
            if (GetActorLocation(MySelf).GetDistanceTo(GetActorLocation(Turret)) > 800)
                continue;

            if (settings.AutoActivateTurrets && Turret->bIsPowered && !Turret->bContainerActivated)
                PC->ServerMultiUse(Turret, 600, 0, true, true);

            if (settings.AutoRangeSettings)
            {
                if (settings.CurrentRangeSetting != Turret->RangeSetting)
                {
                    Turret->RangeSetting = settings.CurrentRangeSetting;
                }
            }

            if (settings.AutoTargetSettings)
            {
                if (settings.CurrentTargetSetting != Turret->AISetting)
                {
                    Turret->AISetting = settings.CurrentTargetSetting;
                }
            }

            if (settings.AutoNameTurrets && (Turret->BoxName.Num() < 3 || UTF32Utils::Strnicmp(*Turret->BoxName, L"Lat", 3) != 0))
            {
                float Lat, Lon;
                WorldToMapCoordinates(UWorld::GetWorld(), GetActorLocation(Turret), &Lat, &Lon);

                std::wstring LocationName = fmt::format(L"Lat: {:.1f} Lon: {:.1f}", Lat, Lon);
                PC->ServerNotifyEditText(LocationName.c_str(), false, Turret->Class, 0, 0, Turret);
            }

            if (settings.AutoFillTurrets)
            {
                UPrimalInventoryComponent* TurretInventoryComponent = Turret->MyInventoryComponent;
                if (!TurretInventoryComponent)
                    continue;

                int32 NumBullets = Turret->NumBullets;
                if (NumBullets >= settings.MaxBulletsPerTurret)
                    continue;


                int32 NeededAmmo = settings.MaxBulletsPerTurret - NumBullets;

                for (UPrimalItem* Item : InventoryComponent->InventoryItems)
                {
                    if (!Item || !PC || !Item->IsA(Turret->AmmoItemTemplate))
                        continue;

                    PC->ServerTransferToRemoteInventory(TurretInventoryComponent, Item->ItemID, false, NeededAmmo, false, true, false);

                    break;
                }
            }

        }
    }
}


void Automatics::FireBallistaProjectile(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    if (MySelf->bIsControllingBallista)
    {
        APrimalStructureTurretBallista* Ballista = Cast<APrimalStructureTurretBallista>(MySelf->SeatingStructure.GetSafe());
        if (Ballista && Ballista->MySkeletalMeshComp && PerformedAnyShootAction(PC))
        {
            FVector Origin   = Ballista->MySkeletalMeshComp->GetSocketLocation(Ballista->TurretTipBone);
            FVector ShootDir = PC->ControlRotation.Vector();

            MySelf->ServerFireBallistaProjectile(Origin, ShootDir);
        }
    }
}

void Automatics::FireProjectile(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    if (AShooterWeapon_Projectile* Weapon = UObject::Cast<AShooterWeapon_Projectile>(MySelf->CurrentWeapon))
    {
        if (Weapon->Name == FNames::WeapBola_C) // ignore bolas
            return;

        if (PerformedAnyShootAction(PC))
        {
            Weapon->ServerFireProjectileEx(Weapon->GetMuzzleLocation(), PC->ControlRotation.Vector(), 99999, 0);
        }
    }
}


void Automatics::ArmorEquipment(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    UPrimalInventoryComponent* MyInventoryComponent = MySelf->MyInventoryComponent;
    if (!MyInventoryComponent)
        return;

    UPrimalItem* NullEquip[5] = {};
    UPrimalItem* QueueEquip[5] = {};

    for (auto Index{0}; Index < MyInventoryComponent->EquippedItems.Num(); ++Index)
    {
        UPrimalItem* EquippedItem = MyInventoryComponent->EquippedItems[Index];
        if (!EquippedItem)
            continue;

        NullEquip[(uint8)EquippedItem->MyEquipmentType] = EquippedItem;
    }

    for (auto Index{0}; Index < MyInventoryComponent->InventoryItems.Num(); ++Index)
    {
        UPrimalItem* InventoryItem = MyInventoryComponent->InventoryItems[Index];
        if (!InventoryItem)
            continue;

        EPrimalItemType ItemType = InventoryItem->MyItemType;
        if (ItemType != EPrimalItemType::Equipment)
            continue;

        float ItemDurability = InventoryItem->ItemDurability;
        if (ItemDurability == 0.0f)
            continue;

        uint8 ItemIndex = (uint8)InventoryItem->MyEquipmentType;

        if (ItemIndex > 4 || InventoryItem->bIsBlueprint || !InventoryItem->bAllowEquppingItem || InventoryItem->bIsEngram)
            continue;

        if (!NullEquip[ItemIndex] || NullEquip[ItemIndex]->ItemDurability < ItemDurability)
        {
            QueueEquip[ItemIndex] = InventoryItem;
        }
    }

    for (auto Index{0}; Index < 5; ++Index)
    {
        if (QueueEquip[Index])
        {
            PC->ServerEquipPawnItem(QueueEquip[Index]->ItemID);
        }
    }
}

void Automatics::MedConsumption(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    static constexpr float HealRate       = 8.0f;
    static constexpr float BrewDuration   = 5.0f;
    static constexpr float BrewHealAmount = HealRate * BrewDuration;
    static constexpr double DrinkCooldown = 4.5;

    static double NextAllowedDrinkTime = 0.0;
    static float LastHpMissing         = 0.0f;

    UCharacterMovementComponent* CharacterMovement = MySelf->CharacterMovement;
    if (!CharacterMovement)
        return;

    if (CharacterMovement->MovementMode == EMovementMode::MOVE_Swimming)
        return;

    UPrimalInventoryComponent* Inventory = MySelf->MyInventoryComponent;
    if (!Inventory || !Inventory->InventoryItems)
        return;

    UPrimalCharacterStatusComponent* Status = MySelf->MyCharacterStatusComponent;
    if (!Status)
        return;

    float CurrentHealth = Status->CurrentStatusValues[(int)EPrimalCharacterStatusValue::Health];
    float MaxHealth     = Status->MaxStatusValues[(int)EPrimalCharacterStatusValue::Health];
    double Now          = CFAbsoluteTimeGetCurrent();

    float HpMissing = MaxHealth - CurrentHealth;
    if (HpMissing <= 10.f || CurrentHealth >= MaxHealth)
        return;

    if (Now < NextAllowedDrinkTime)
    {
        if (HpMissing > LastHpMissing + 50.f)
        {
            NextAllowedDrinkTime = 0.0;
        }
        else
        {
            return;
        }
    }

    LastHpMissing = HpMissing;

    int32 BrewsToDrink = static_cast<int32>(std::ceil(HpMissing / BrewHealAmount));
    int32 BrewsDrank   = 0;
    const int32 BrewsNeeded = BrewsToDrink;

    auto DrinkNeededBrews = [&](TArray<UPrimalItem*>& Items)
    {
        for (UPrimalItem* Item : Items)
        {
            if (!Item || Item->Name != FNames::PrimalItemConsumable_HealSoup_C)
                continue;

            int32 Count = (Item->ItemQuantity >= BrewsToDrink) ? BrewsToDrink : Item->ItemQuantity;
            for (auto Index{0}; Index < Count; ++Index)
            {
                PC->ServerRequestInventoryUseItem(Inventory, Item->ItemID);
                BrewsDrank++;
                BrewsToDrink--;
            }

            if (BrewsToDrink <= 0)
                return true;
        }
        return false;
    };

    if (!DrinkNeededBrews(Inventory->ItemSlots))
        DrinkNeededBrews(Inventory->InventoryItems);

    if (BrewsDrank == BrewsNeeded)
    {
        NextAllowedDrinkTime = Now + ((HpMissing / BrewHealAmount) * DrinkCooldown);
    }
    else if (BrewsDrank > 0)
    {
        NextAllowedDrinkTime = Now + (BrewsDrank * DrinkCooldown);
    }
}




void Automatics::StamConsumption(AShooterCharacter* MySelf, AShooterPlayerController* PC)
{
    static constexpr float BrewStaminaAmount = 40.0f;
    static constexpr double DrinkCooldown    = 4.5;
    static double NextAllowedDrinkTime = 0.0;

    UPrimalInventoryComponent* Inventory = MySelf->MyInventoryComponent;
    if (!Inventory || !Inventory->InventoryItems)
        return;

    UPrimalCharacterStatusComponent* Status = MySelf->MyCharacterStatusComponent;
    if (!Status)
        return;

    float CurrentStamina = Status->CurrentStatusValues[(int)EPrimalCharacterStatusValue::Stamina];
    float MaxStamina     = Status->MaxStatusValues[(int)EPrimalCharacterStatusValue::Stamina];
    double Now           = CFAbsoluteTimeGetCurrent();

    if (CurrentStamina >= MaxStamina)
        return;

    if (Now < NextAllowedDrinkTime || (MaxStamina - CurrentStamina) < 40.f)
        return;

    float TimeToDrinkBrews = (MaxStamina - CurrentStamina) / BrewStaminaAmount;
    int32 BrewsToDrink = static_cast<int32>(std::ceil((MaxStamina - CurrentStamina) / BrewStaminaAmount));
    int32 BrewsDrank   = 0;
    const int32 BrewsNeeded = BrewsToDrink;

    auto DrinkNeededBrews = [&](TArray<UPrimalItem*>& Items)
    {
        for (UPrimalItem* Item : Items)
        {
            if (!Item || Item->Name != FNames::PrimalItemConsumable_StaminaSoup_C)
                continue;

            int32 Count = (Item->ItemQuantity >= BrewsToDrink) ? BrewsToDrink : Item->ItemQuantity;
            while (Count-- > 0)
            {
                PC->ServerRequestInventoryUseItem(Inventory, Item->ItemID);
                BrewsDrank++;
                BrewsToDrink--;
            }

            if (BrewsToDrink == 0)
                return true;
        }
        return false;
    };

    if (!DrinkNeededBrews(Inventory->ItemSlots))
        DrinkNeededBrews(Inventory->InventoryItems);

    if (BrewsDrank == BrewsNeeded)
    {
        NextAllowedDrinkTime = Now + (TimeToDrinkBrews * DrinkCooldown);
    }
    else if (BrewsDrank > 0)
    {
        NextAllowedDrinkTime = Now + (BrewsDrank * DrinkCooldown);
    }
}


void Automatics::Looting(AShooterCharacter *MySelf, AShooterPlayerController *PC)
{
    FVector MyLocation = GetActorLocation(MySelf);
    int32 MyTargetingTeam = MySelf->TargetingTeam;

    if (settings.LootPlayers)
    {
        const TArray<AActor*>& Players = GetActors<EActorListsBP::AL_PLAYERS>();
        for (auto Index{0}; Index < Players.Num(); ++Index)
        {
            AShooterCharacter* Player = Cast<AShooterCharacter>(Players[Index]);
            if (!Player || Player == MySelf)
                continue;

            if (!MySelf || !PC)
                break;

            if (!Player->bIsSleeping && !Player->bIsDead)
                continue;

            int32 TargetingTeam = Player->TargetingTeam;
            if (MyTargetingTeam == TargetingTeam || IsAllied(MySelf, TargetingTeam))
                continue;

            FVector Location = GetActorLocation(Player);
            if (Location.GetDistanceTo(MyLocation) > 900.0f)
                continue;

            UPrimalInventoryComponent* MyInventoryComponent = Player->MyInventoryComponent;
            if (MyInventoryComponent)
            {
                PC->ServerTransferAllFromRemoteInventory(MyInventoryComponent, TEXT(""), TEXT(""), FInventoryFilter());
            }
        }
    }

    if (settings.LootContainers || settings.LootTurrets || settings.LootSupplyCrates)
    {
        const TArray<AActor*>& Actors = GetActors();
        for (auto Index{0}; Index < Actors.Num(); ++Index)
        {
            AActor* Actor = Actors[Index];
            if (!Actor || !Actor->IsA(APrimalStructureItemContainer::StaticClass()))
                continue;

            if (!MySelf || !PC)
                continue;

            APrimalStructureItemContainer* Container = Cast<APrimalStructureItemContainer>(Actor);

            const bool IsTurret = Container->IsA(APrimalStructureTurret::StaticClass());
            if (!settings.LootTurrets && IsTurret)
                continue;

            const bool IsSupplyCrate = Container->IsA(APrimalStructureItemContainer_SupplyCrate::StaticClass());
            if (IsSupplyCrate && !settings.LootSupplyCrates)
                continue;

            if (!IsTurret && !IsSupplyCrate && !settings.LootContainers)
                continue;

            int32 TargetingTeam = Container->TargetingTeam;
            if (MyTargetingTeam == TargetingTeam || IsAllied(MySelf, TargetingTeam))
                continue;

            FVector Location = GetActorLocation(Container);
            if (Location.GetDistanceTo(MyLocation) > 900.0f)
                continue;

            UPrimalInventoryComponent* MyInventoryComponent = Container->MyInventoryComponent;
            if (MyInventoryComponent)
            {
                if ( IsSupplyCrate )
                {
                    PC->ServerRequestActorItems(MyInventoryComponent, true, false);
                    PC->ServerTransferAllFromRemoteInventory(MyInventoryComponent, TEXT(""), TEXT(""), FInventoryFilter());
                    continue;
                }

                PC->ServerTransferAllFromRemoteInventory(MyInventoryComponent, TEXT(""), TEXT(""), FInventoryFilter());
            }
        }
    }

}


FVector (*GetShootingCameraLocation)(AShooterWeapon* _this) = nullptr;

void Automatics::FireWeapon(AShooterCharacter *MySelf, AShooterPlayerController *PC)
{
    if (0 >= MySelf->CurrentWeapon->CurrentAmmoInClip && PC->Player)
        return;

    AShooterWeapon_Instant* CurrentWeapon = Cast<AShooterWeapon_Instant>(MySelf->CurrentWeapon);

    auto [Target, WorldPosition, ScreenPosition, BoneName] = GetBestTarget();
    if (!Target || !Target->Mesh || WorldPosition.IsZero())
        return;

    FVector CameraLocation = GetShootingCameraLocation(CurrentWeapon);
    FVector ShootDirection = (WorldPosition - CameraLocation).GetSafeNormal();

    FHitResult OutHitResult;
    OutHitResult.bBlockingHit   = true;
    OutHitResult.TraceStart     = CameraLocation;
    OutHitResult.TraceEnd       = WorldPosition;
    OutHitResult.Normal         = ShootDirection;
    OutHitResult.ImpactNormal   = ShootDirection;
    OutHitResult.ImpactPoint    = WorldPosition;
    OutHitResult.Location       = WorldPosition;
    OutHitResult.BoneName       = BoneName;
    OutHitResult.Actor          = Target;
    OutHitResult.Component      = settings.CrashPlayersAim ? reinterpret_cast<UPrimitiveComponent*>(Target) : Target->Mesh;

    TAllocatedArray<FVector> ShootDirs(1);
    ShootDirs.Add(settings.ShieldBypass ? FVector::UpVector : ShootDirection);

    TAllocatedArray<FHitResult> Impacts(1);
    Impacts.Add(OutHitResult);

    TAllocatedArray<float> ModelHeightChecks(1);
    ModelHeightChecks.Add(3.0f);

    CurrentWeapon->ServerNotifyShot(Impacts, ShootDirs, ModelHeightChecks);
    CurrentWeapon->CurrentAmmoInClip -= 1;

    static bool IsReloading = false;
    if (5 >= CurrentWeapon->CurrentAmmoInClip && !IsReloading)
    {
        CurrentWeapon->ServerStartReload();
        IsReloading = true;
    } else {
        IsReloading = false;
    }
}



template<typename T>
std::vector<std::string> ExtractPaths(const TArray<TSoftClassPtr<T>>& Array)
{
    std::vector<std::string> Out;
    Out.reserve(Array.Num());

    for (int i = 0; i < Array.Num(); i++)
    {
        const TSoftClassPtr<T>& SoftClass = Array[i];
        if (!SoftClass.ObjectID.AssetLongPathname.IsEmpty())
        {
            Out.push_back(SoftClass.ObjectID.AssetLongPathname.ToString() + "\n");
        }
    }
    return Out;
}

id<MTLTexture> GetMTLTexture(UTexture2D* Texture2D)
{
    if (!Texture2D)
        return nil;

    //class FTextureResource*    UTexture::Resource; (actually FTexture2DResource)
    // Right after ETextureGroup UTexture::LODGroup;
    uint8* Resource = *(uint8**)((uint8*)Texture2D + 0x68);
    if (!Resource)
        return nil;

    // RenderResource.h
    // FTextureRHIRef FTexture::TextureRHI;
    uint8* TextureRHI = *(uint8**)(Resource + 0x30);
    if (!TextureRHI)
        return nil;

    // "metalstencilsample"
    return (__bridge id<MTLTexture>)*(void**)(TextureRHI + 0x70);
}

UClass* (*StaticLoadClass)( UClass* BaseClass, UObject* InOuter, const TCHAR* InName, const TCHAR* Filename, uint32 LoadFlags, UObject* Sandbox ) = nullptr;

void DumpSpawnMenuArrays(USpawnMenu_C* SpawnMenu)
{
    std::map<std::string, std::string> DumpedData;

    auto ProcessArray = [&](const TArray<TSoftClassPtr<UClass>>& Array)
    {
        for (const TSoftClassPtr<UClass>& SoftClass : Array)
        {
            if (!SoftClass.ObjectID.AssetLongPathname.IsValid())
                continue;

            std::string AssetPath = SoftClass.ObjectID.AssetLongPathname.ToString();

            UClass* LoadedClass = StaticLoadClass(UClass::StaticClass(), nullptr, *SoftClass.ObjectID.AssetLongPathname, nullptr, 0, nullptr);
            if (!LoadedClass)
                continue;


            FString DescName;

            if (LoadedClass->IsChildOf(UPrimalItem::StaticClass()))
            {
                UPrimalItem* DefaultObj = Cast<UPrimalItem>(LoadedClass->GetDefaultObject());
                if (DefaultObj)
                    DescName = DefaultObj->DescriptiveNameBase.GetDisplayString();
            }
            else if (LoadedClass->IsChildOf(APrimalCharacter::StaticClass()))
            {
                APrimalCharacter* DefaultObj = Cast<APrimalCharacter>(LoadedClass->GetDefaultObject());
                if (DefaultObj)
                    DescName = DefaultObj->DescriptiveName.GetDisplayString();
            }
            else if (LoadedClass->IsChildOf(APrimalTargetableActor::StaticClass()))
            {
                APrimalTargetableActor* DefaultObj = Cast<APrimalTargetableActor>(LoadedClass->GetDefaultObject());
                if (DefaultObj)
                    DescName = DefaultObj->DescriptiveName.GetDisplayString();
            }

            if (DescName.IsValid() && !DescName.IsEmpty())
            {
                DumpedData[AssetPath] = DescName.ToString();
            }
        }
    };

    ProcessArray(SpawnMenu->DinoBlueprintIDs);
    ProcessArray(SpawnMenu->SaddleBlueprintIDs);
    ProcessArray(SpawnMenu->SaddleBlueprintIDs2);
    ProcessArray(SpawnMenu->ResourceBlueprintIDs);
    ProcessArray(SpawnMenu->FoodBlueprintIDs);
    ProcessArray(SpawnMenu->SeedBlueprintIDs);
    ProcessArray(SpawnMenu->ClothingBlueprintIDs);
    ProcessArray(SpawnMenu->WeaponBlueprintIDs);
    ProcessArray(SpawnMenu->ToolBlueprintIDs);
    ProcessArray(SpawnMenu->AmmoBlueprintIDs);
    ProcessArray(SpawnMenu->ThatchStructureBlueprintIDs);
    ProcessArray(SpawnMenu->WoodStructureBlueprintIDs);
    ProcessArray(SpawnMenu->StoneStructureBlueprintIDs);
    ProcessArray(SpawnMenu->MetalStructureBlueprintIDs);
    ProcessArray(SpawnMenu->ElectricStructureBlueprintIDs);
    ProcessArray(SpawnMenu->MiscStructureBlueprintIDs);
    ProcessArray(SpawnMenu->FurnatureStructureBlueprintIDs);
    ProcessArray(SpawnMenu->DinoEggBlueprintIDs);
    ProcessArray(SpawnMenu->DinoFertEggBlueprintIDs);
    ProcessArray(SpawnMenu->KibbleBlueprintIDs);
    ProcessArray(SpawnMenu->PremiumBlueprintIDs);
    ProcessArray(SpawnMenu->DyeBlueprintIDs);
    ProcessArray(SpawnMenu->ArtifactBlueprintIDs);
    ProcessArray(SpawnMenu->SkinBlueprintIDs);
    ProcessArray(SpawnMenu->DinoItemBlueprintIDs);
    ProcessArray(SpawnMenu->PremiumFurnishingsBlueprintIDs);
    ProcessArray(SpawnMenu->PremiumGardenBlueprintIDs);
    ProcessArray(SpawnMenu->ImplantGraftBlueprintIDs);
    ProcessArray(SpawnMenu->TekBlueprintIDs);

    // Convert map to vector for writing
    std::vector<std::string> Lines;
    for (const auto& [Path, Desc] : DumpedData)
    {
        Lines.push_back(Path + " = " + Desc + "\n");
    }

    DumpToFile("SpawnMenuDumps", "Blueprints.txt", Lines);
}


void DumpAllBlueprintIDs()
{
    AShooterPlayerController* PC = GetPlayerController();
    if (!PC)
        return;

    AShooterHUD* MyHUD = Cast<AShooterHUD>(PC->MyHUD);
    if (!MyHUD)
        return;

    UPlayerHUDUI* MyPlayerHUD = MyHUD->MyPlayerHUD;
    if (!MyPlayerHUD)
        return;

    MyPlayerHUD->EnableMenu(EPrimalSubmenuType::SpawnMenu, true, nullptr, false);

    USpawnMenu_C* SpawnMenu = Cast<USpawnMenu_C>(MyPlayerHUD->Submenus[(uint8)EPrimalSubmenuType::SpawnMenu]);
    if (!SpawnMenu)
        return;

    DumpSpawnMenuArrays(SpawnMenu);
}



void DevMenuDumpYee()
{
    AActor* Target = GetTargetedActor();
    if (!Target)
        return;

    std::string OutStr;
    for (UStruct* Class = Target->Class; Class; Class = Class->Super)
    {
        OutStr += Class->GetName() + ".";
    }

    NSLog(@"%s", OutStr.c_str());
}

void ChatSpamLogin(AShooterPlayerController* PC)
{
    PC->ServerChatLogin();
}

void DungeonMenu(AShooterPlayerController* PC)
{
    PC->ServerRequestDungeonAccess();
}

void UnlockNotes(AShooterPlayerController* PC)
{
    for (auto Index{0}; Index < 200; ++Index)
		PC->ServerUnlockPerMapExplorerNote(Index);
}

void UnlockAdmin(AShooterPlayerController* PC)
{
	PC->ClientNotifyAdmin(true, true);
}

void EnterDungeon(AShooterPlayerController* PC)
{
	PC->ServerDownloadDungeon(L"Sep22_Hootenanny");
}

void SpawnMaterials(AShooterPlayerController* PC)
{
    for (auto Index{0}; Index < settings.MaterialAmount; ++Index)
    {
        PC->ServerGodConsoleCommandThree((EGiveItem)settings.MaterialIndex, true);
    }
}

void Suicide(AShooterPlayerController* PC)
{
	PC->ServerSuicide();
}

void SetLightType(int LightType)
{
    ShooterPlayerControllerQueue.Add([LightType](AShooterPlayerController* PC)
    {
        if (AShooterCharacter* Character = GetPlayerCharacter(PC))
        {
            Character->ClientSetDungeonLighting(LightType);
        }
    });;
}

void Relog(AShooterPlayerController* PC)
{
    UWorld* World = UWorld::GetWorld();
    if (!World)
        return;

    UShooterGameInstance* GameInstance = GetShooterGameInstance(World);
    if (GameInstance && UEngine::GetEngine())
    {
        SetClientTravel_Internal(UEngine::GetEngine(), World, GameInstance->LastSuccessfulURL.CStr(), ETravelType::TRAVEL_Absolute);
    }
}

void QuitToMenu(AShooterPlayerController* PC)
{
    UWorld* World = UWorld::GetWorld();
    if (!World)
        return;

    if (UEngine* Engine = UEngine::GetEngine())
    {
        SetClientTravel_Internal(Engine, World, TEXT("MainMenu"), ETravelType::TRAVEL_Absolute);
    }
}

void Rollback(AShooterPlayerController* PC)
{
    if (!PC->PlayerCameraManager)
        return;

    AShooterCharacter* Character = GetPlayerCharacter(PC);
    if (!Character)
        return;

	PC->ServerRequestPlaceStructure(
        290,
        GetActorLocation(Character),
        GetActorRotation(Character),
        PC->PlayerCameraManager->CameraCache.POV.Rotation,
        nullptr,
        nullptr,
        FName(),
        FItemNetID(),
        FPreferredSnapData(),
        false,
        false,
        false,
        0,
        true
    );
}

void ResurrectDino(AShooterPlayerController* PC)
{
    AShooterCharacter* Character = GetPlayerCharacter(PC);
    if (!Character)
        return;

    UPrimalItem_Implant* Implant = UObject::Cast<UPrimalItem_Implant>(PC->GetInventoryUISelectedItemRemote());
    if (Implant && !Implant->IsExpired)
    {
        Character->ServerResurrectDino(Implant->MyDinoID1);
    }
}

void RandomTeleport(AShooterPlayerController* PC)
{
    PC->ServerRequestRespawnAtPoint(int(std::rand() % 50), 0, true);
}

void RemoveDungeonLoadingScreen(AShooterPlayerController* PC)
{
    PC->ClientRemoveDungeonLoadingScreen();
}

void SendMessage(const std::wstring& Message, int Index)
{
    ShooterPlayerControllerQueue.Add([Message, Index](AShooterPlayerController* PC)
    {
        if ( !PC || Message.empty())
            return;

        EChatMessageType MessageType;
        switch (Index)
        {
            case 0: MessageType = EChatMessageType::Text; break;
            case 1: MessageType = EChatMessageType::Announcement; break;
            case 2: MessageType = EChatMessageType::Notification; break;
            case 3: MessageType = EChatMessageType::LogIn; break;
            case 4: MessageType = EChatMessageType::Emote; break;
            default: return;
        }

        static FText EmptyText = UKismetTextLibrary::GetEmptyText();

        FServerText ServerText;
        ServerText.MainText = EmptyText;

        PC->ServerSendChatMessage(EChatChannel::Global, MessageType, Message.c_str(), ServerText);
    });
}

template<typename T>
T* GetAimedActor(AShooterPlayerController* PC)
{
    if (UTargetingObject* TargetObj = PC->TargetingObject)
    {
        return UObject::Cast<T>(TargetObj->AimedActorRef.Actor.GetSafe());
    }
    return nullptr;
}

void AutoPlaceCurrentStructure()
{
	AShooterPlayerController* PC = GetPlayerController();
    if (!PC || !PC->PlayerCameraManager)
       return;

    APrimalStructurePlacer* StructurePlacer = PC->StructurePlacer;
    if (!StructurePlacer || !StructurePlacer->CurrentPlacingStructure)
       return;

    PC->ServerRequestPlaceStructure(
        StructurePlacer->CurrentPlacingStructureIndex,
        StructurePlacer->CurrentPlacingStructure->RootComponent->ComponentToWorld.GetLocation(),
        StructurePlacer->CurrentPlacingStructure->RootComponent->ComponentToWorld.Rotation.Rotator(),
        PC->PlayerCameraManager->CameraCache.POV.Rotation,
        nullptr,
        nullptr,
        FName(),
        FItemNetID(),
        FPreferredSnapData(),
        false,
        false,
        false,
        0,
        true
    );
}

void TransferFromContainer(AShooterPlayerController* PC)
{
    APrimalStructureItemContainer* Container = GetAimedActor<APrimalStructureItemContainer>(PC);
	if (Container)
	{
		PC->ServerTransferAllFromRemoteInventory(
            Container->MyInventoryComponent,
            TEXT(""),
            TEXT(""),
            FInventoryFilter()
        );
	}
}

FVector AdjustForGravity(FVector const& VelocityAdjustedPosition, FVector const& InitialPosition, float ProjectileSpeed, FVector const& Gravity)
{
    FVector HorizontalDirectionVector = (VelocityAdjustedPosition - InitialPosition);
    HorizontalDirectionVector.Z = 0.0f;

    const float Distance           = VelocityAdjustedPosition.GetDistanceTo(InitialPosition);
    const float TimeOfFlight       = Distance / ProjectileSpeed;
    FVector GravityDisplacement    = Gravity * 0.5f * (TimeOfFlight * TimeOfFlight);
    return VelocityAdjustedPosition + GravityDisplacement;
}

FVector ProjectilePrediction(APrimalCharacter* Target, FVector const& TargetLocation, FVector const& ProjLocation, float ProjectileSpeed)
{
    AShooterPlayerController* PlayerController = GetPlayerController();
    if (!PlayerController)
        return TargetLocation;

    AShooterCharacter* MySelf = GetPlayerCharacter(PlayerController);
    if (!MySelf || !MySelf->CurrentWeapon || (!MySelf->CurrentWeapon->IsA(APrimalWeaponBow::StaticClass()) && MySelf->CurrentWeapon->Name != FNames::WeapBola_C))
        return TargetLocation;

    FVector Velocity = Target->GetVelocity(false);

    FVector VelocityAdjusted = UVictoryCore::LeadTargetPosition(ProjLocation, ProjectileSpeed, TargetLocation, Velocity);
    return AdjustForGravity(VelocityAdjusted, ProjLocation, ProjectileSpeed, FVector(0,0,300));
}


void DumpAllSpawnUIPtrs()
{
}

/*
void AutoPopcornTurrets()
{
    if (!settings.AutoPopcornTurrets)
    {   return; }

    AShooterPlayerController* PC = GetPlayerController();
    if (!PC)
    {   return; }

    AShooterCharacter* Character = GetShooterCharacter();
    if (!Character)
    {   return; }

    TFreedArray<class AActor*> Turrets;
    UGameplayStatics::GetAllActorsOfClass(
        UWorld::GetWorld(),
        APrimalStructureTurret::StaticClass(),
        &Turrets
    );



    for (int i = 0; i < Turrets.Num(); ++i)
    {
        APrimalStructureTurret* Turret = static_cast<APrimalStructureTurret*>(Turrets[i]);
        if (!IsValidObj(Turret) || (0 >= Turret->NumBullets))
            continue;

        if (!Turret->MyInventoryComponent)
            continue;

        if (ToMeters(Character->GetDistanceTo(Turret)) > 10)
            continue;

        PC->ServerRequestActorItems(Turret->MyInventoryComponent, true, false);

        for (UPrimalItem* Item : Turret->MyInventoryComponent->InventoryItems)
        {
            if (!Item)
                continue;

            PC->ServerDropFromRemoteInventory(Turret->MyInventoryComponent, Item->ItemID);
        }
    }
}
*/


void TransferToContainer(AShooterPlayerController* PC)
{
    APrimalStructureItemContainer* Container = GetAimedActor<APrimalStructureItemContainer>(PC);
	if (Container)
	{
        FString None(TEXT(""));
        FInventoryFilter InventoryFilter;
        InventoryFilter.FilterString = None;
        InventoryFilter.ItemTypeFilter = EPrimalItemType::MAX;
        InventoryFilter.EquipmentTypeFilter = EPrimalEquipmentType::MAX;
        InventoryFilter.ConsumableTypeFilter = EPrimalConsumableType::MAX;

		PC->ServerTransferAllToRemoteInventory(
            Container->MyInventoryComponent,
            None,
            None,
            InventoryFilter
        );
	}
}

void ClaimTargetedDino(AShooterPlayerController* PC)
{
    AShooterCharacter* Character = GetPlayerCharacter(PC);
    if (!Character)
        return;

    APrimalDinoCharacter* Dino = UObject::Cast<APrimalDinoCharacter>(GetTargetedActor());
    if (!Dino || IsWild(Dino))
        return;

    if (GetActorAssociation(Character, Dino) == EActorAssociation::Enemy)
    {
        PC->ServerMultiUse(Dino, 122, 0, true, true);
    }
}

void ClaimAllDinos(AShooterPlayerController* PC)
{
    AShooterCharacter* Character = GetPlayerCharacter(PC);
    if (!Character)
        return;

    const TArray<AActor*>& Dinos = GetActors();
    if (!Dinos)
        return;

    for (int i = 0; i < Dinos.Num(); ++i)
    {
        APrimalDinoCharacter* Dino = UObject::Cast<APrimalDinoCharacter>(Dinos[i]);
        if (!Dino || IsWild(Dino))
            continue;

        if (GetActorAssociation(Character, Dino) == EActorAssociation::Enemy)
        {
            PC->ServerMultiUse(Dino, 122, 0, true, true);
        }
    }
}


void PickupTargetedStructure(AShooterPlayerController* PC)
{
    if (!PC->TargetingObject)
        return;

    AShooterCharacter* Character = GetPlayerCharacter(PC);
    if (!Character)
        return;

    APrimalStructure* Structure = Cast<APrimalStructure>(GetTargetedActor());
    if (!Structure || !Structure->IsA(APrimalStructure::StaticClass()))
        return;

	EActorAssociation Assoc = GetActorAssociation(Character, Structure);
    if (Assoc == EActorAssociation::Enemy)
    {
        PC->ServerMultiUse(Structure, 204, 0, true, true);
    }
}

void PickupAllStructures(AShooterPlayerController* PC)
{
    AShooterCharacter* Character = GetPlayerCharacter(PC);
    if (!Character)
        return;

    const TArray<AActor*>& Structures = GetActors();
    if (!Structures)
        return;

    for (auto Index{0}; Index < Structures.Num(); ++Index)
    {
        APrimalStructure* Structure = Cast<APrimalStructure>(Structures[Index]);
        if (!Structure || !Structure->IsA(APrimalStructure::StaticClass()))
            continue;

        EActorAssociation Assoc = GetActorAssociation(Character, Structure);
        if (Assoc == EActorAssociation::Enemy)
        {
            PC->ServerMultiUse(Structure, 204, 0, true, true);
        }
    }
}

APrimalStructureBed* GetLookAtBed()
{
    APrimalStructureBed* BestBed = nullptr;
    float CurrentDistance = FLT_MAX;

    const FMatrix& ViewProjMatrix = GetViewProjectionMatrix();

    const TArray<AActor*>& Beds = GetActors();
    for (auto Index{0}; Index < Beds.Num(); ++Index)
    {
        APrimalStructureBed* Bed = UObject::Cast<APrimalStructureBed>(Beds[Index]);
        if (!Bed)
            continue;

        FVector Location = GetActorLocation(Bed);

        FVector2D ScreenLocation;
        if (!ProjectWorldToScreen(Location, ScreenLocation, ViewProjMatrix))
            continue;

        float Distance = HalfViewportSize.GetDistanceTo(ScreenLocation);
        if (CurrentDistance > Distance)
        {
            CurrentDistance = Distance;
            BestBed = Bed;
        }
    }
    return BestBed;
}

void BedTeleport(AShooterPlayerController* PC)
{
    if (APrimalStructureBed* Bed = GetLookAtBed())
    {
        return PC->ServerRequestRespawnAtPoint(Bed->BedID, 0, true);
    }
}

UTexture2D* GetIcon(EIconType IconType)
{
    static UTexture2D* Knocked_Icon = nullptr;
    static UTexture2D* Skull_Icon = nullptr;

    switch (IconType)
    {
        case EIconType::Knocked:
        {
            if (Knocked_Icon == nullptr)
                Knocked_Icon = UObject::FindObject<UTexture2D>("Texture2D Sleep_Icon.Sleep_Icon");

            return Knocked_Icon;
        }
        case EIconType::Skull:
        {
            if (Skull_Icon == nullptr)
                Skull_Icon = UObject::FindObject<UTexture2D>("Texture2D SkullIcon.SkullIcon");

            return Skull_Icon;
        }
        default:
            return nullptr;
    }
}



void DrawInViewport(UCanvas* Canvas)
{
    if (!settings.esp.Enable)
        return;

    AShooterPlayerController* PC = GetPlayerController();
    if (!PC)
        return;

    AShooterCharacter* MySelf = GetPlayerCharacter(PC);
    if (!MySelf)
        return;

    UFont* RenderFont = GetRenderFont();
    if (!RenderFont)
        return;

    FontManager ArkFont(RenderFont);

    float DefaultCharHeight, DefaultCharWidth;
    FontManager::GetDefaultCharSize(ArkFont, DefaultCharWidth, DefaultCharHeight);

    float TextHeight = ArkFont.GetTextHeight(TEXT("Hg"), settings.esp.Scale, DefaultCharHeight);

    DrawBuffer.TrySwap();

    for (const FOtherActorData& Data : DrawBuffer.GetFrontOtherBuffer())
    {
        if (!Data.TheActor || Data.Location.IsZero())
            continue;

        const float Scale = settings.esp.Scale;

        if (Data.SpecType == EActorSpecificType::Bed && settings.TapToBedTeleport)
        {
            APrimalStructureBed* Bed = Cast<APrimalStructureBed>(Data.TheActor);

            FVector2D RenderLocation(Data.Location.X, Data.Location.Y - (TextHeight * 0.5f));

            FVector2D TouchLocation = GCurrentTouchLocation.load(std::memory_order_acquire);

            FVector2D MinBed = RenderLocation - 40.f;
            FVector2D MaxBed = RenderLocation + 40.f;
            if (FMath::IsWithinInclusive(TouchLocation.X, MinBed.X, MaxBed.X) &&
                FMath::IsWithinInclusive(TouchLocation.Y, MinBed.Y, MaxBed.Y))
            {
                int32 BedID = Bed->BedID;
                ShooterPlayerControllerQueue.Add([BedID](AShooterPlayerController* PC)
                {
                    PC->ServerRequestRespawnAtPoint(BedID, 0, true);
                });
            }

            DrawTexture(Canvas, Cast<UPrimalItem>(Bed->ConsumesPrimalItem->DefaultObject)->ItemIcon,
                        RenderLocation,
                        FVector2D(80.0f, 80.0f),
                        FLinearColor::White);
        }
        else if (Data.Type == EActorType::Dinosaur && settings.esp.ShowDinoInfo)
        {
            APrimalDinoCharacter* Dino = Cast<APrimalDinoCharacter>(Data.TheActor);

            float ReplicatedCurrentHealth = Dino->ReplicatedCurrentHealth;
            float ReplicatedMaxHealth     = Dino->ReplicatedMaxHealth;
            DrawHealthBar(Canvas, FVector2D(Data.Location.X, Data.Location.Y + (TextHeight * 0.5f) + 5), FVector2D(80, 10), FLinearColor::Red, ReplicatedCurrentHealth / ReplicatedMaxHealth, 1.5f);

            if (Dino->ReplicatedCurrentTorpor > 0.f)
            {
                float ReplicatedCurrentTorpor = Dino->ReplicatedCurrentTorpor;
                float ReplicatedMaxTorpor     = Dino->ReplicatedMaxTorpor;
                DrawHealthBar(Canvas, FVector2D(Data.Location.X, Data.Location.Y + (TextHeight * 0.5f) + 17), FVector2D(80, 10), FLinearColor::Purple, ReplicatedCurrentTorpor / ReplicatedMaxTorpor, 1.5f);
            }
        }

        DrawText(Canvas, ArkFont, Data.Name.c_str(), Data.Location, Data.DrawColor, Scale);
    }

    if (settings.TapToBedTeleport)
    {
        GCurrentTouchLocation.store(FVector2D::ZeroVector, std::memory_order_release);
    }


    int NumPlayersDrawn = 0;

    for (const FPlayerActorData& Data : DrawBuffer.GetFrontPlayerBuffer())
    {
        if (!Data.ThePlayer || Data.TopLocation.IsZero())
            continue;

        if (!Data.IsVisible)
        {
            if (settings.esp.Tracers)
                DrawLine(Canvas, {Canvas->SizeX * 0.5f, 50.0f}, Data.TopLocation, 3.0f, Data.DrawColor);

            NumPlayersDrawn++;
            continue;
        }

        const float Scale = settings.esp.Scale;

        float TextWidth = ArkFont.GetTextWidth(Data.Name.c_str(), Scale, DefaultCharWidth);

        const bool IsSleeping = Data.ThePlayer->bIsSleeping;
        const bool IsDead     = Data.ThePlayer->bIsDead;

        if (IsSleeping || IsDead)
        {
            UTexture2D* Texture = GetIcon(IsDead ? EIconType::Skull : EIconType::Knocked);

            FVector2D IconLocation = Data.TopLocation;
            IconLocation.X -= (TextWidth * 0.5f) + 20.0f;
            IconLocation.Y += 20.0f;

            DrawTexture(Canvas, Texture, IconLocation, FVector2D(40.0f, 40.0f), FLinearColor::White);
            DrawText(Canvas, ArkFont, Data.Name.c_str(), Data.TopLocation, Data.DrawColor, Scale);
            continue;
        }

        if (!IsDead && !IsSleeping && Data.Association == EActorAssociation::Enemy)
        {
            NumPlayersDrawn++;

            const float HalfTextSize = TextHeight * 0.5f;

            const float HpBarHeight   = 10.0f;
            const float HpBarOffset   = HalfTextSize + 5.0f;
            const float HpBarLowestY  = Data.TopLocation.Y + HpBarOffset + HpBarHeight;

            const float VerticalShift = HpBarLowestY > Data.TopLocation.Y
                ? (HpBarLowestY - Data.TopLocation.Y)
                : 0.0f;

            FVector2D TopPos    = { Data.TopLocation.X, Data.TopLocation.Y - VerticalShift };
            FVector2D BottomPos = { Data.BottomLocation.X, Data.BottomLocation.Y - VerticalShift};

            if (settings.esp.Box3D)
                Draw3DBox(Canvas, Data.ThePlayer, Data.DrawColor);

            if (settings.esp.Box2D)
                Draw2DBox(Canvas, Data.TopLocation, Data.BottomLocation, Data.DrawColor);

            if (settings.esp.Skeleton)
                DrawSkeleton(Canvas, Data.ThePlayer, Data.DrawColor);

            if (settings.esp.Tracers)
                DrawLine(Canvas, { TopPos.X, TopPos.Y - HalfTextSize }, FVector2D(Canvas->SizeX * 0.5f, 50), 3.0f, Data.DrawColor);

            if (settings.esp.Weapon)
                DrawWeapon(Canvas, Data.ThePlayer, FVector2D(TopPos.X, TopPos.Y - (HalfTextSize * 1.25f)), FVector2D(75.0f, 75.0f));

            DrawText(Canvas, ArkFont, Data.Name.c_str(), TopPos, Data.DrawColor, Scale);

            if (settings.esp.HPBar)
            {
                float ReplicatedCurrentHealth = Data.ThePlayer->ReplicatedCurrentHealth;
                float ReplicatedMaxHealth     = Data.ThePlayer->ReplicatedMaxHealth;
                DrawHealthBar(Canvas, FVector2D(TopPos.X, TopPos.Y + HpBarOffset), FVector2D(80, HpBarHeight), FLinearColor::Red, ReplicatedCurrentHealth / ReplicatedMaxHealth, 1.5f);
            }

            if (settings.esp.Armor)
                DrawArmor(Canvas, Data.ThePlayer, BottomPos, FVector2D(50.0f, 50.0f));
        }

        else
        {
            DrawText(Canvas, ArkFont, Data.Name.c_str(), Data.TopLocation, Data.DrawColor, Scale);
        }
    }

    DrawText(Canvas, ArkFont, fmt::format(L"{}", NumPlayersDrawn).c_str(), FVector2D(Canvas->SizeX * 0.5f, 90), FLinearColor::Red, 3.0);

    if (UWorld* World = UWorld::GetWorld())
    {
        if (AShooterGameState* GameState = UObject::Cast<AShooterGameState>(World->GameState))
        {
            FVector MapPosition = GetActorLocation(MySelf);

            float Latitude, Longitude;
            WorldToMapCoordinates(World, MapPosition, &Latitude, &Longitude);

            LatLonRot.store(FVector(Latitude, Longitude, FMath::DegreesToRadians(PC->ControlRotation.Yaw) + HALF_PI));

            int32 Hours   = (int32)GameState->DayTime / 3600;
            int32 Minutes = ((int32)GameState->DayTime % 3600) / 60;

            if (settings.MapSetting.bDayTimeMode)
                settings.MapSetting.fDayTime = Hours;

            float Ping = 0.0f;
            if (APlayerState* PlayerState = MySelf->PlayerState)
            {
                Ping = (*(float*)((uint8*)PlayerState + 0x610) * 0.25f) * 0.5f;
            }

            std::wstring CommonInfo = fmt::format(L"FPS: {}\nPing: {}ms\nLatitude: {:.2f}\nLongitude: {:.2f}\nPlayers Online: {}\nTime: {:02d}:{:02d}",
                                                    int(*GAverageFPS),
                                                    (int)Ping,
                                                    Latitude,
                                                    Longitude,
                                                    GameState->NumPlayerConnected,
                                                    Hours,
                                                    Minutes
            );

            DrawText(Canvas, ArkFont, CommonInfo.c_str(), FVector2D(170, Canvas->SizeY * 0.25), FLinearColor::White, 1.5f);
        }
    }

    if (settings.EnableAimbot)
    {
        AShooterWeapon* CurrentWeapon = MySelf->CurrentWeapon;
        if (CurrentWeapon)
        {
            if ((settings.BowAimbot && CurrentWeapon->IsA(APrimalWeaponBow::StaticClass())) ||
                CurrentWeapon->IsA(AShooterWeapon_Instant::StaticClass()) ||
                CurrentWeapon->Name == FNames::WeapBola_C)
            {
                auto [Target, WorldPosition, ScreenPosition, BoneName] = GetBestTarget();
                if (Target && !ScreenPosition.IsZero())
                {
                    FVector2D MuzzleLocation;
                    if (ProjectWorldToScreen(CurrentWeapon->GetMuzzleLocation(), MuzzleLocation, Canvas->ViewProjectionMatrix))
                        DrawLine(Canvas, MuzzleLocation, ScreenPosition, 3.f, FLinearColor::Green);
                }
            }
        }
    }

    if (settings.SelfArmorESP)
        DrawArmor(Canvas, MySelf, FVector2D(Canvas->SizeX * 0.5f, Canvas->SizeY * 0.72f), FVector2D(80, 80), true);

    if (APlayerCameraManager* PlayerCameraManager = PC->PlayerCameraManager)
    {
        if (PlayerCameraManager->CameraStyle != FNames::FirstPerson)
        {
            if (settings.SelfBoneESP)
                DrawSkeleton(Canvas, MySelf, FLinearColor::White);

            if (settings.Self3DBoxESP)
                Draw3DBox(Canvas, MySelf, FLinearColor::White);
        }
    }


    if (settings.UseAimFOV)
    {
        DrawCircle(Canvas, FVector2D(Canvas->SizeX * 0.5f, Canvas->SizeY * 0.5f), settings.AimFOVRadius, FLinearColor::Purple, 64, 3.0f);
    }
}

bool GotScreenSize = false;

struct FBulletLine
{
    FVector From;
    FVector To;
};

std::queue<FBulletLine> ShotTraces;

void (*orig_AShooterWeapon$ProcessEvent)(AShooterWeapon_Instant* _this, UFunction* Function, void* Params);
void new_AShooterWeapon$ProcessEvent(AShooterWeapon_Instant* _this, UFunction* Function, void* Params)
{
    if (settings.NoTekRifleOverheat && Function->Name == FNames::Func::BPFireWeapon && _this->Name == FNames::WeapTekRifle_C)
    {
        return;
    }
    else if (Function->Name == FNames::Func::ServerNotifyShot)
    {
        auto Parms = (Params::ShooterWeapon_Instant_ServerNotifyShot*)Params;

        if (settings.EnableAimbot && settings.AimType == 1)
        {
            auto [Target, WorldLocation, ScreenPosition, BoneName] = GetBestTarget();
            if (Target && Target->Mesh && !WorldLocation.IsZero() && GetLocalPlayer())
            {
                FVector CameraLocation = Parms->Impacts[0].TraceStart;
                FVector ShootDirection = (WorldLocation - CameraLocation).GetSafeNormal();


                for (FVector& ShootDir : Parms->ShootDirs)
                    ShootDir = settings.ShieldBypass ? FVector::UpVector : ShootDirection;

                for (FHitResult& Impact : Parms->Impacts)
                {
                    Impact.bBlockingHit  = true;
                    Impact.TraceStart    = CameraLocation;
                    Impact.TraceEnd      = WorldLocation;
                    Impact.Normal        = ShootDirection;
                    Impact.ImpactNormal  = ShootDirection;
                    Impact.ImpactPoint   = WorldLocation;
                    Impact.Location      = WorldLocation;
                    Impact.BoneName      = BoneName;
                    Impact.Actor         = Target;
                    Impact.Component     = settings.CrashPlayersAim ? reinterpret_cast<UPrimitiveComponent*>(Target) : Target->Mesh;
                }
            }
        }

        /*FVector MuzzleLocation = _this->GetMuzzleLocation();
        for (const FHitResult& Impact : Parms->Impacts)
        {
            ShotTraces.push(FBulletLine(MuzzleLocation, Impact.TraceEnd));
        }*/

    }
    else if (settings.BowAimbot && Function->Name == FNames::Func::ServerFireProjectileEx)
    {
        auto Parms = (Params::ShooterWeapon_Projectile_ServerFireProjectileEx*)Params;

        auto [Target, WorldLocation, ScreenPosition, BoneName] = GetBestTarget();
        if (Target && Target->CharacterMovement)
        {
            Parms->ShootDir = (ProjectilePrediction(Target, WorldLocation, Parms->Origin, Parms->Speed) - Parms->Origin).GetSafeNormal();
        }
    }



    return orig_AShooterWeapon$ProcessEvent(_this, Function, Params);
}



void (*orig_ULineBatchComponent$TickComponent)(ULineBatchComponent* _this, float DeltaTime, int32 TickType, void* ThisTickFunction);
void new_ULineBatchComponent$TickComponent(ULineBatchComponent* _this, float DeltaTime, int32 TickType, void* ThisTickFunction)
{
    auto DrawLine = (void(*)(ULineBatchComponent* _this, const FVector& Start, const FVector& End, const FLinearColor& Color, uint8 DepthPriority, float Thickness, float LifeTime))(_this->VTable[284]);

    while (!ShotTraces.empty())
    {
        FBulletLine BulletLine = ShotTraces.front();
        DrawLine(_this, BulletLine.From, BulletLine.To, FLinearColor::White, 1, 10.0f, 3.f);
        ShotTraces.pop();
    }

    return orig_ULineBatchComponent$TickComponent(_this, DeltaTime, TickType, ThisTickFunction);
}

FVector GetPredictedLocation(AShooterPlayerController* Controller, AShooterCharacter* Target, const FVector& TheirLocation)
{
    UCharacterMovementComponent* MovementComp = Target->CharacterMovement;

    FVector Velocity = Target->GetVelocity(false);

    if (APrimalDinoCharacter* RidingDino = Target->RidingDino.GetSafe())
    {
        Velocity = RidingDino->GetVelocity(false);
        MovementComp = RidingDino->CharacterMovement;
    }

    if (FMath::Abs(Velocity.X) < 25) Velocity.X = 0.0f;
    if (FMath::Abs(Velocity.Y) < 25) Velocity.Y = 0.0f;
    if (FMath::Abs(Velocity.Z) < 25) Velocity.Z = 0.0f;

    if (APlayerState* PlayerState = Controller->PlayerState)
    {
        float ExactPing = *reinterpret_cast<float*>((uint8*)PlayerState + 0x610);
        const float OneWayLatency = (ExactPing / 4000.0f) * 0.25f;

        return TheirLocation + Velocity * OneWayLatency + 0.5f*MovementComp->Acceleration * FMath::Square(OneWayLatency);
    }

    return FVector::ZeroVector;
}


void (*orig_APrimalDinoCharacter$ProcessEvent)(APrimalDinoCharacter* _this, UFunction* Function, void* Params);
void new_APrimalDinoCharacter$ProcessEvent(APrimalDinoCharacter* _this, UFunction* Function, void* Params)
{
    if (settings.QuickTurn && Function->Name == FNames::Func::BP_GetCustomModifier_RotationRate)
    {
        *(float*)Params = 9999999.0f;
        return;
    }

    return orig_APrimalDinoCharacter$ProcessEvent(_this, Function, Params);
}

void (*orig_AShooterPlayerController$ProcessEvent)(AShooterPlayerController* _this, UFunction* Function, void* Params);
void new_AShooterPlayerController$ProcessEvent(AShooterPlayerController* _this, UFunction* Function, void* Params)
{
    if (settings.NoSpawnAnim && Function->Name == FNames::Func::ClientNotifyRespawned)
    {
        return _this->CheckForPlayerInventory();
    }
    else if (settings.TameShooting && Function->Name == FNames::Func::ServerMultiUse)
    {
        auto Parms = (Params::ShooterPlayerController_ServerMultiUse*)Params;

        if (Parms->UseIndex == 100 && !Parms->bAllowSpam)
        {
            AShooterCharacter* MySelf = GetPlayerCharacter(_this);
            if (MySelf && MySelf->CurrentWeapon)
            {
                if (!MySelf->CurrentWeapon->Name.IsAny(FNames::WeapFists_C, FNames::WeapFists_Female_C))
                {
                    FItemNetID CurrentWeaponID = MySelf->CurrentWeapon->AssociatedPrimalItem->ItemID;
                    MySelf->ServerGiveFists();
                    MySelf->ServerRestorePrevWeapon(CurrentWeaponID);
                }
            }
        }
    }
    else if (settings.HideLogin && !settings.ChatSpam && Function->Name == FNames::Func::ServerChatLogin)
    {
        return;
    }
    else if (Function->Name == FNames::Func::ServerRequestPlaceStructure)
    {
        auto Parms = (Params::ShooterPlayerController_ServerRequestPlaceStructure*)Params;

        if (settings.FloatingStructures && Parms->StructureIndex != 290 && Parms->StructureIndex != 36 && Parms->StructureIndex != 161)
        {
            Params::ShooterPlayerController_ServerRequestPlaceStructure NewParams{};

            NewParams.bSnapped              = false;
            NewParams.AttachToPawn          = nullptr;
            NewParams.PlayerViewRotation    = _this->ControlRotation;
            NewParams.BuildLocation         = _this->StructurePlacer->CurrentPlacingStructure->RootComponent->ComponentToWorld.GetLocation();
            NewParams.BuildRotation         = _this->StructurePlacer->CurrentPlacingStructure->RootComponent->ComponentToWorld.Rotation.Rotator();
            NewParams.IsWeaponPlacement     = true;
            NewParams.StructureIndex        = _this->StructurePlacer->CurrentPlacingStructureIndex;

            return orig_AShooterPlayerController$ProcessEvent(_this, Function, &NewParams);
        }

    }
    else if (Function->Name == FNames::Func::ServerSendBadPlayer)
    {
        return;
    }



    return orig_AShooterPlayerController$ProcessEvent(_this, Function, Params);
}


void (*orig_AShooterCharacter$ProcessEvent)(AShooterCharacter* _this, UFunction* Function, void* Params);
void new_AShooterCharacter$ProcessEvent(AShooterCharacter* _this, UFunction* Function, void* Params)
{
    if (_this->Controller) // my player
    {
        if (Function->Name == FNames::Func::PlayHitEffectPoint)
            return;

        return orig_AShooterCharacter$ProcessEvent(_this, Function, Params);
    }

    if (Function->Name.IsAny(FNames::Func::PlayHitEffectPoint, FNames::Func::PlayHitEffectRadial, FNames::Func::PlayHitEffectGeneric))
    {
        orig_AShooterCharacter$ProcessEvent(_this, Function, Params);
        UPrimalInventoryComponent* MyInventoryComponent = Cast<AShooterCharacter>(_this)->MyInventoryComponent;
        if (MyInventoryComponent)
        {
            GetPlayerController()->ServerRequestActorItems(MyInventoryComponent, false, false);
        }
        return;
    }


    return orig_AShooterCharacter$ProcessEvent(_this, Function, Params);
}

void (*orig_GetPlayerViewPoint)(AShooterPlayerController *_this, FVector* OutLocation, FRotator* OutRotation, bool ForAiming);
void new_GetPlayerViewPoint(AShooterPlayerController *_this, FVector* OutLocation, FRotator* OutRotation, bool ForAiming)
{
    orig_GetPlayerViewPoint(_this, OutLocation, OutRotation, ForAiming);

    if (settings.EnableAimbot)
    {
        if (settings.LockAim && settings.AimType == 0)
        {
            auto [Target, WorldLocation, ScreenLocation, BoneName] = GetBestTarget();
            if (Target && Target->Mesh && !WorldLocation.IsZero())
            {
                FRotator ShootRot = (/*GetPredictedLocation(_this, Target,*/ WorldLocation/*)*/ - *OutLocation).GetSafeNormal().Rotation();

                *OutRotation = ShootRot;
                _this->ControlRotation = ShootRot;
            }
        }
    }
}

void (*orig_UShooterEngine$Tick)(UShooterEngine* _this, float DeltaSeconds, bool bIdleMode );
void new_UShooterEngine$Tick(UShooterEngine* _this, float DeltaSeconds, bool bIdleMode )
{
    GameEngineQueue.Release(_this);
    return orig_UShooterEngine$Tick(_this, DeltaSeconds, bIdleMode);
}

// remove aim assist bs safely
FVector (*orig_GetAdjustedAim)(AShooterWeapon_Instant* _this) = nullptr;
FVector new_GetAdjustedAim(AShooterWeapon_Instant* _this)
{
    AShooterPlayerController* const PlayerController = _this->Instigator ? Cast<AShooterPlayerController>(_this->Instigator->Controller) : NULL;
    FVector FinalAim = FVector::ZeroVector;
    // If we have a player controller use it for the aim
    if (PlayerController)
    {
        FVector CamLoc;
        FRotator CamRot;
        //PlayerController->GetPlayerViewPoint(CamLoc, CamRot);
        // calling the function above cuz ark does that
        auto GetPlayerViewPoint = (void(*)(AShooterPlayerController*, FVector&, FRotator&, bool))(PlayerController->VTable[839]);
        GetPlayerViewPoint(PlayerController, CamLoc, CamRot, true);
        FinalAim = CamRot.Vector();
    }

    return FinalAim;
}

// explicitly used for no shotgun reload
void (*orig_FireWeapon)(AShooterWeapon_Instant* _this);
void new_FireWeapon(AShooterWeapon_Instant* _this)
{
    orig_FireWeapon(_this);

    if (settings.NoReloadShotgun && _this->CurrentAmmo > 0)
        _this->ServerStartReload();
}

void (*orig_ReplicateMoveToServer)(UCharacterMovementComponent* _this, float DeltaTime, const FVector& NewAcceleration);
void new_ReplicateMoveToServer(UCharacterMovementComponent* _this, float DeltaTime, const FVector& NewAcceleration)
{
    if (_this->CharacterOwner && _this->CharacterOwner->IsA(AShooterCharacter::StaticClass()))
        DeltaTime *= settings.Freeze ? 0 : settings.PlayerSpeed;
    else
        DeltaTime *= settings.DinoSpeed;


    return orig_ReplicateMoveToServer(_this, DeltaTime, NewAcceleration);
}

inline bool IsMachinedPistol(AShooterWeapon* Weapon)
{
    return Weapon->Name.IsAny(FNames::WeapMachinedPistol_C,
                              FNames::WeapMachinedPistol_Laser1_C,
                              FNames::WeapMachinedPistol_Scoped_C,
                              FNames::WeapMachinedPistol_Silencer_C,
                              FNames::WeapMachinedPistol_Flashlight_C,
                              FNames::WeapMachinedPistol_HoloScope_C);
}

inline bool IsMachinedShotgun(AShooterWeapon* Weapon)
{
    return Weapon->Name.IsAny(FNames::WeapMachinedShotgun_C,
                              FNames::WeapMachinedShotgun_Laser_C,
                              FNames::WeapMachinedShotgun_Scope_C,
                              FNames::WeapMachinedShotgun_Flashlight_C,
                              FNames::WeapMachinedShotgun_HoloScope_C);
}

void (*K2_SetRelativeRotation_Internal)(USceneComponent* _this, FRotator NewRotation, bool bSweep, FHitResult* SweepHitResult, bool bTeleport);

void OnPlayerControllerTick(AShooterPlayerController* PlayerController, AShooterCharacter* ShooterSelf)
{
    UEngine* GEngine = UEngine::GetEngine();
    if ( !GEngine )
         return;

    if (settings.NoKnockoutBlur)
    {
        UPrimalGlobals* Singleton = Cast<UPrimalGlobals>(GEngine->GameSingleton);
        if (Singleton)
        {
            UPrimalGameData* GameData = Singleton->PrimalGameData;
            if (GameData == nullptr)
                GameData = Singleton->PrimalGameDataOverride;

            GameData->PostProcess_KnockoutBlur = nullptr;
        }
    }

    GEngine->SmoothedFrameRateRange.UpperBound.Value = settings.FPS;

    UShooterGameUserSettings* UserSettings = UObject::Cast<UShooterGameUserSettings>(GEngine->GameUserSettings);
    if (UserSettings)
    {
        UserSettings->FOVMultiplier = settings.FOV;

        if (settings.JoinNotifications)
            UserSettings->bJoinNotifications = true;
        else
            UserSettings->bJoinNotifications = false;
    }

    ShooterSelf->TPVCameraOffset.X = settings.TPVCameraOffsetX;
    ShooterSelf->TPVCameraOffset.Y = settings.TPVCameraOffsetY;

    if (settings.UseDynamicColors && ShooterSelf->Mesh)
    {
        FLinearColor NewBodyColor = ConvertToFLinearColor(settings.DynamicBodyColor);
        FLinearColor NewHairColor = ConvertToFLinearColor(settings.DynamicHairColor);

        FLinearColor& BodyColor = ShooterSelf->BodyColors[0];
        FLinearColor& HairColor = ShooterSelf->BodyColors[1];

        if (NewBodyColor != BodyColor || NewHairColor != HairColor)
        {
            BodyColor = NewBodyColor;
            HairColor = NewHairColor;
            ShooterSelf->ApplyBodyColors();
        }
    }

    if (APlayerCameraManager* PCM = PlayerController->PlayerCameraManager)
    {
        PCM->FreeCamDistance = settings.FreeCamDistance * 256;
    }

    if (settings.Ragebot)
    {
        if (USkeletalMeshComponent* Mesh = ShooterSelf->Mesh)
        {
            FRotator NewRotation = Mesh->RelativeRotation;
            NewRotation.Yaw += 20.f;

            K2_SetRelativeRotation_Internal(Mesh, NewRotation, false, nullptr, true);
        }
    }

    if (APrimalStructurePlacer* StructurePlacer = PlayerController->StructurePlacer)
    {
        if (settings.CustomPlacement && settings.PlacingStructureIndex > 0)
            StructurePlacer->CurrentPlacingStructureIndex = settings.PlacingStructureIndex;

        if (settings.PlacementDupe)
            *(int32*)((uint8*)StructurePlacer + 0x660) = 5;

        if (settings.StructureFlip)
        {
            APrimalStructure* CurrentPlacingStructure = StructurePlacer->CurrentPlacingStructure;
            if (CurrentPlacingStructure)
            {
                USceneComponent* RootComponent = CurrentPlacingStructure->RootComponent;
                if (RootComponent)
                {
                    RootComponent->ComponentToWorld.Rotation = FRotator(settings.FlipPitch, settings.FlipYaw, settings.FlipRoll).ToQuaterion();
                }
            }
        }
    }

    if (PlayerController->Character && PlayerController->Character->CharacterMovement)
    {
        VftSwapFunc(PlayerController->Character->CharacterMovement, (void*)new_ReplicateMoveToServer, (void*&)orig_ReplicateMoveToServer, 338);
    }

    if (APrimalDinoCharacter* Dino = UObject::Cast<APrimalDinoCharacter>(PlayerController->Character))
    {
        if (settings.InstantTurn)
        {
            Dino->bUseControllerRotationPitch = true;
            Dino->bUseControllerRotationYaw = true;
            Dino->bUseControllerRotationRoll = true;
        }
        else
        {
            Dino->bUseControllerRotationPitch = false;
            Dino->bUseControllerRotationYaw = false;
            Dino->bUseControllerRotationRoll = false;
        }

        if (settings.QuickTurn)
        {
            VftSwapFunc(Dino, (void*)new_APrimalDinoCharacter$ProcessEvent, (void*&)orig_APrimalDinoCharacter$ProcessEvent, Offsets::ProcessEventIdx);
            Dino->bUseBP_CustomModifier_RotationRate = true;
        }
        else
        {
            Dino->bUseBP_CustomModifier_RotationRate = Cast<APrimalDinoCharacter>(Dino->Class->DefaultObject)->bUseBP_CustomModifier_RotationRate;
        }

        if (settings.Strafing)
        {
            Dino->bFlyerDinoAllowBackwardsFlight = true;
            Dino->bFlyerDinoAllowStrafing = true;
        }


    }

    static bool WasFreecam = false;
    if (settings.GhostMode && !WasFreecam)
    {
        WasFreecam = true;
        ShooterSelf->ClientCheatGhost();
        ShooterSelf->SetReplicateMovement(false);
    }
    else if (WasFreecam && !settings.GhostMode)
    {
        WasFreecam = false;
        ShooterSelf->ClientCheatWalk();
        ShooterSelf->SetReplicateMovement(true);
    }

    AShooterWeapon* CurrentWeapon = ShooterSelf->CurrentWeapon;
    if (CurrentWeapon && !CurrentWeapon->IsA(AShooterWeapon_Melee::StaticClass()))
    {
        VftSwapFunc(CurrentWeapon, (void*)new_AShooterWeapon$ProcessEvent, (void*&)orig_AShooterWeapon$ProcessEvent, Offsets::ProcessEventIdx);

        if (settings.NoScopeSway)
        {
            CurrentWeapon->AimDriftYawAngle = 0.0f;
            CurrentWeapon->AimDriftPitchAngle = 0.0f;
        }

        if (CurrentWeapon->IsA(AShooterWeapon_Instant::StaticClass()))
        {
            AShooterWeapon_Instant* InstantWeapon = Cast<AShooterWeapon_Instant>(CurrentWeapon);
            if (settings.AutoFire)
            {
                InstantWeapon->bAllowRunning = true;
                InstantWeapon->bAllowRunningWhileFiring = true;
                InstantWeapon->bAllowRunningWhileReloading = true;
                InstantWeapon->bAllowTargetingWhileReloading = true;
            }

            if (settings.SubmergedFiring)
            {
                InstantWeapon->bAllowSubmergedFiring = true;
                InstantWeapon->bCanAltFire = true;
            }

            if (settings.NoSpread)
            {
                InstantWeapon->InstantConfig.WeaponSpread = 0.0001f;
            }

            if (settings.InfFabiPistolAmmo)
            {
                if (InstantWeapon->CurrentAmmoInClip > 0 && IsMachinedPistol(InstantWeapon))
                {
                    InstantWeapon->Role = ENetRole::ROLE_Authority;
                    InstantWeapon->CurrentAmmoInClip = 99999;
                }
            }

            if (settings.BulletBurst)
            {
                InstantWeapon->WeaponConfig.TimeBetweenShots = 0.001f;
            }

            if (settings.NoScopeOverlay)
            {
                InstantWeapon->bUseScopeOverlay = false;
            }

            if (settings.BigGun && InstantWeapon->Mesh3P)
            {
                InstantWeapon->Mesh3P->RelativeScale3D = 3.f;
            }

            if (settings.NoReloadShotgun && IsMachinedShotgun(InstantWeapon))
            {
                VftSwapFunc(InstantWeapon, (void*)new_FireWeapon, (void*&)orig_FireWeapon, 326);
            }


        }
        else if (settings.ProjectileSpam && CurrentWeapon->IsA(AShooterWeapon_Projectile::StaticClass()) && !CurrentWeapon->Name.IsAny(FNames::WeapTekRifle_C, FNames::WeapBola_C))
        {
            AShooterWeapon_Projectile* ProjectileWeapon = Cast<AShooterWeapon_Projectile>(CurrentWeapon);

            ProjectileWeapon->bCanAltFire = false;
            ProjectileWeapon->bCanFire = false;
        }
        else if (settings.InfiniteC4 && CurrentWeapon->Name == FNames::WeapC4_C)
        {
            AShooterWeapon_Placer* C4 = Cast<AShooterWeapon_Placer>(CurrentWeapon);

            C4->bHiddenExplosive = false;
            C4->WaitingForPlacementTimer = 0.f;
            C4->bHideLeftArmFPVWhenNoAmmo = false;
            C4->CurrentAmmoInClip = 1;
        }

    }
}


float (*orig_APrimalDinoCharacter$PlayHitEffect)(APrimalDinoCharacter *_this, float DamageTaken, void *DamageEvent, APawn *PawnInstigator, AActor *DamageCauser, bool bIsLocalPath);
float new_APrimalDinoCharacter$PlayHitEffect(APrimalDinoCharacter *_this, float DamageTaken, void *DamageEvent, APawn *PawnInstigator, AActor *DamageCauser, bool bIsLocalPath)
{
    if (_this->bIsDead || _this->ReplicatedCurrentHealth <= 0.0f)
        return orig_APrimalDinoCharacter$PlayHitEffect(_this, DamageTaken, DamageEvent, PawnInstigator, DamageCauser, bIsLocalPath);

    if (IsWild(_this) && DamageCauser && DamageCauser->IsA(APrimalDinoCharacter::StaticClass()) && IsWild(Cast<APrimalDinoCharacter>(DamageCauser)))
        return orig_APrimalDinoCharacter$PlayHitEffect(_this, DamageTaken, DamageEvent, PawnInstigator, DamageCauser, bIsLocalPath);

    if (settings.ShowFloatingDamage && DamageCauser && _this != DamageCauser)
    {
        AShooterPlayerController* PlayerController = GetPlayerController();
        PlayerController->ClientAddFloatingDamageText(GetActorLocation(_this), (int)DamageTaken, DamageCauser->TargetingTeam, true);
    }

    return orig_APrimalDinoCharacter$PlayHitEffect(_this, DamageTaken, DamageEvent, PawnInstigator, DamageCauser, bIsLocalPath);
}

void (*orig_UpdateRotation)(AShooterPlayerController* _this, float a2);
void new_UpdateRotation(AShooterPlayerController* _this, float a2)
{
    if (settings.UnlockRotation)
    {
        return decltype(orig_UpdateRotation)(APlayerController::GetDefaultObj()->VTable[429])(_this, a2);
    }
    return orig_UpdateRotation(_this, a2);
}

void (*orig_TickActor)(AShooterPlayerController* _this, float DeltaTime, int32 TickType, void* ThisTickFunction) = nullptr;
void new_TickActor(AShooterPlayerController* _this, float DeltaTime, int32 TickType, void* ThisTickFunction)
{
    VftSwapFunc(_this, (void*)new_GetPlayerViewPoint, (void*&)orig_GetPlayerViewPoint, 839);
    VftSwapFunc(_this, (void*)new_AShooterPlayerController$ProcessEvent, (void*&)orig_AShooterPlayerController$ProcessEvent, Offsets::ProcessEventIdx);

    if (!_this->bPlayerHasPrimalPass && settings.FakePrimal)
    {
        _this->bPlayerHasPrimalPass = true;
    }

    if (AShooterCharacter* ShooterSelf = GetPlayerCharacter(_this))
    {
        VftSwapFunc(ShooterSelf, (void*)new_AShooterCharacter$ProcessEvent, (void*&)orig_AShooterCharacter$ProcessEvent, Offsets::ProcessEventIdx);

        OnPlayerControllerTick(_this, ShooterSelf);

        if (settings.AutoArmor)
            Automatics::ArmorEquipment(ShooterSelf, _this);

        if (settings.AutoMeds)
            Automatics::MedConsumption(ShooterSelf, _this);

        if (settings.AutoStamina)
            Automatics::StamConsumption(ShooterSelf, _this);

        if (settings.AutoGrabPlayers)
            Automatics::AutoGrabPlayer(ShooterSelf, _this);

        if (settings.AutoDestroyBot)
        {
            //AutoPlaceCurrentStructure();
            Automatics::AutoDestroyStructure(ShooterSelf, _this);
        }

        if (settings.ChatSpam)
        {
            ChatSpamLogin(_this);
        }


        if (settings.AutoSteal)
        {
            static iOSExecutionTimer AutoLoot_Timer;
            AutoLoot_Timer.UpdateWithInterval(0.2f, Automatics::Looting, ShooterSelf, _this);
        }

        if (settings.AutoDropItems)
        {
            static iOSExecutionTimer AutoDropItems_Timer;
            AutoDropItems_Timer.UpdateWithInterval(0.2f, Automatics::AutoDropItems, ShooterSelf, _this);
        }

        if (settings.AutoFire)
        {
            if (AShooterWeapon_Instant* Weapon = UObject::Cast<AShooterWeapon_Instant>(ShooterSelf->CurrentWeapon))
            {
                static iOSExecutionTimer AutoFire_Timer;
                AutoFire_Timer.UpdateWithInterval(Weapon->WeaponConfig.TimeBetweenShots * 1.5f, Automatics::FireWeapon, ShooterSelf, _this);
            }
        }

        if (settings.EnableTurretSettings)
        {
            static iOSExecutionTimer TurretSettings_Timer;
            TurretSettings_Timer.UpdateWithInterval(1.0f / 5.0f, Automatics::TurretSettings, ShooterSelf, _this);
        }

        if (settings.ProjectileSpam)
        {
            static iOSExecutionTimer FireProjectile_Timer;
            FireProjectile_Timer.UpdateWithInterval(1.0f / 10.0f, Automatics::FireProjectile, ShooterSelf, _this);
        }

        if (settings.BallistaSpam)
        {
            static iOSExecutionTimer FireBallistaProjectile_Timer;
            FireBallistaProjectile_Timer.UpdateWithInterval(1.0f / 10.0f, Automatics::FireBallistaProjectile, ShooterSelf, _this);
        }

        if (settings.HealDinosaur)
        {
            static iOSExecutionTimer HealDinosaur_Timer;
            HealDinosaur_Timer.UpdateWithInterval(1.0f / 10.0f, Automatics::DinosaurHealing, ShooterSelf, _this);
        }

        if (settings.AutoExplosions)
        {
            static iOSExecutionTimer AutoExplosions_Timer;
            AutoExplosions_Timer.UpdateWithInterval(1.0f / 5.0f, Automatics::Explosions, ShooterSelf, _this);
        }


    }
    else if (settings.UsePermenantColors)
    {
        if (UWorld* GWorld = UWorld::GetWorld(); GWorld && GWorld->Name != FNames::MainMenu)
        {
            if (UEngine* GEngine = UEngine::GetEngine())
            {
                GEngine = nullptr;
                UPrimalGlobals* Singleton = (UPrimalGlobals*)GEngine->GameSingleton;
                if (Singleton)
                {
                    UPrimalGameData* GameData = Singleton->PrimalGameData;
                    if (GameData == nullptr)
                        GameData = Singleton->PrimalGameDataOverride;

                    for (auto Index{0}; Index < 2; ++Index)
                    {
                        for (FLinearColor& BodyColor : GameData->PlayerCharacterGenderDefinitions[Index].ColorSetBody)
                            BodyColor = ConvertToFLinearColor(settings.PermBodyColor);

                        for (FLinearColor& HairColor : GameData->PlayerCharacterGenderDefinitions[Index].ColorSetHair)
                            HairColor = ConvertToFLinearColor(settings.PermHairColor);
                    }

                }
            }
        }
    }

    ShooterPlayerControllerQueue.Release(_this);

    return orig_TickActor(_this, DeltaTime, TickType, ThisTickFunction);
}

void (*orig_PostRender)(UGameViewportClient* _this, UCanvas* Canvas) = nullptr;
void new_PostRender(UGameViewportClient* _this, UCanvas* Canvas)
{
    if (Canvas)
    {
        if (!GotScreenSize)
        {
            HalfViewportSize = FVector2D(Canvas->SizeX * 0.5f, Canvas->SizeY * 0.5f);
            GotScreenSize = true;
        }

        DrawInViewport(Canvas);


    }
    return orig_PostRender(_this, Canvas);
}


void (*orig_UpdateGroup)(UInterpGroup* _this, float NewPosition, UInterpGroupInst* GrInst, bool bPreview, bool bJump) = nullptr;
void new_UpdateGroup(UInterpGroup* _this, float NewPosition, UInterpGroupInst* GrInst, bool bPreview, bool bJump)
{
    static const FName NAME_DayCycle = FName(TEXT("DayCycle"));
    static const FName NAME_DirLight = FName(TEXT("DirLight"));
    static const FName NAME_ReflectionMult = FName(TEXT("ReflectionMult"));
    static const FName NAME_DayInterpolationContainer = FName(TEXT("DayInterpolationContainer"));

    if (settings.EnableTime)
    {
        const FName Input = _this->GroupName;

        if (Input == NAME_DayCycle)
            NewPosition = NewPosition > 20.f ? settings.DayCycle : settings.DayCycleSky;
        else if (Input == NAME_DirLight)
            NewPosition = settings.DirLight;
        else if (Input == NAME_ReflectionMult)
            NewPosition = settings.ReflectionMult;
        else if (Input == NAME_DayInterpolationContainer)
            NewPosition = 1.8f;
    }

    return orig_UpdateGroup(_this, NewPosition, GrInst, bPreview, bJump);
}

void SwizzleObjCMethod(Class _class, SEL sel, IMP imp, IMP *result)
{
    Method original = class_getInstanceMethod(_class, sel);
    const char *typeEncoding = method_getTypeEncoding(original);
    if(!class_addMethod(_class, sel, imp, typeEncoding))
    {
        // Replace implementation and return old implementation
        if(result)
            *result = method_getImplementation(original);
        method_setImplementation(original, imp);
    }
    else
    {
        // Add implementation and return super implementation
        Class superClass = class_getSuperclass(_class);
        original = class_getInstanceMethod(superClass, sel);
        if(result)
            *result = method_getImplementation(original);
    }
}

#define HookInstanceMessage(_class, _sel, _imp, _result) \
     SwizzleObjCMethod(                                       \
        objc_getClass((_class)),                                \
        sel_registerName((_sel)),                               \
        (IMP)(_imp),                                            \
        (IMP*)(&_result)                                        \
    )

#define HookClassMessage(_class, _sel, _imp, _result)    \
    SwizzleObjCMethod(                                       \
        objc_getMetaClass((_class)),                            \
        sel_registerName((_sel)),                               \
        (IMP)(_imp),                                            \
        (IMP*)(&_result)                                        \
    )

void (*orig_sendEvent)(id, SEL, UIEvent *);
static void new_sendEvent(id self, SEL _cmd, UIEvent *event)
{
    if (settings.TapToBedTeleport && event.type == UIEventTypeTouches)
    {
        UITouch* Touch = event.allTouches.anyObject;
        if (Touch.phase == UITouchPhaseBegan)
        {
            CGPoint Point = [Touch locationInView:Touch.view];
            GCurrentTouchLocation.store(FVector2D(Point.x * SCREEN_SCALE, Point.y * SCREEN_SCALE), std::memory_order_release);
        }
    }
    return orig_sendEvent(self, _cmd, event);
}

FORCEINLINE void CheckRestrictedLoadCommands()
{
    struct mach_header_64 *mh = (struct mach_header_64 *)_dyld_get_image_header(0);
    if (!mh)
        CrashSafe();

    const struct load_command* lc = (const struct load_command*)((uintptr_t)mh + sizeof(struct mach_header_64));
    for (uint32_t i = 0; i < mh->ncmds; i++)
    {
        if (lc->cmd == LC_LOAD_DYLIB || lc->cmd == LC_LOAD_WEAK_DYLIB)
        {
            struct dylib_command* dylib_cmd = (struct dylib_command*)lc;
            char* dylib_name = (char*)dylib_cmd + dylib_cmd->dylib.name.offset;
            if (!dylib_name)
                continue;

            if (UTF8Utils::Strstr(dylib_name, "/System/Library/") || UTF8Utils::Strstr(dylib_name, "/usr/lib/"))
                continue;

            if (UTF8Utils::Strstr(dylib_name, "Sishen.dylib"))
                continue;

            CrashSafe();
        }
        lc = (const struct load_command*)((uintptr_t)lc + lc->cmdsize);
    }
}

namespace fs = std::filesystem;

void UpdateEngineIni()
{
    fs::path Directory = GetDocumentsPath() / "ShooterGame/Saved/Config/IOS";
    fs::path EngineIni = Directory / "Engine.ini";

    if (!fs::exists(Directory))
        fs::create_directories(Directory);

    std::ifstream InFile(EngineIni);
    std::stringstream Buffer;
    Buffer << InFile.rdbuf();
    std::string EngineContent = Buffer.str();
    InFile.close();

    if (EngineContent.empty())
        EngineContent = "";

    if (EngineContent.find("[/Script/IOSRuntimeSettings.IOSRuntimeSettings]") == std::string::npos)
        EngineContent += "\n[/Script/IOSRuntimeSettings.IOSRuntimeSettings]\n";

    const std::string NewFrameRateLock = "FrameRateLock=PUFRL_None";
    std::regex Pattern(R"(FrameRateLock=.*)");

    if (std::regex_search(EngineContent, Pattern))
        EngineContent = std::regex_replace(EngineContent, Pattern, NewFrameRateLock);
    else
        EngineContent += "\n" + NewFrameRateLock;

    std::ofstream OutFile(EngineIni, std::ios::trunc);
    OutFile << EngineContent;
    OutFile.close();
}


ENTRY_POINT void __Entry(void)
{
    CheckRestrictedLoadCommands();

    SwizzleObjCMethod(objc_getClass("UIWindow"), @selector(sendEvent:), (IMP)(new_sendEvent), (IMP*)(&orig_sendEvent));

    CallAfterSeconds(2)
    {
        CheckRestrictedLoadCommands();

        ScreenRect.Init();

        FName::GNames = *reinterpret_cast<TNameEntryArray**>(SDK::InSDKUtils::GetImageBase() + Offsets::GNames);

        CGPMemoryScanner Scanner("ShooterGame");

#define InitFunc(Func, Address) Func = decltype(Func)(Address)
#define InitFuncWithOffset(Func, Offset) Func = decltype(Func)(SDK::InSDKUtils::GetImageBase() + Offset)
        // static void* Realloc(void* Original, SIZE_T Count, uint32 Alignment = DEFAULT_ALIGNMENT);
        void* FMemory_Realloc_Address   = (void*)Scanner.FindDirectSig("? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? 91 F3 03 02 AA F4 03 01 AA F5 03 00 AA ? ? ? ? ? ? ? 91 ? ? ? F9");
        void* SetClientTravel_Address   = (void*)Scanner.FindDirectSig("? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? 91 F3 03 03 AA F4 03 02 AA ? ? ? B9 ? ? ? 34");
        void* FName_Constructor_Address = (void*)(SDK::InSDKUtils::GetImageBase() + 0x1014010EC);
        void* UFont_GetCharSize_Address = (void*)Scanner.FindDirectSig("? ? ? D1 ? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? 91 F3 03 03 AA F4 03 02 AA F6 03 01 AA F5 03 00 AA ? ? ? B9 ? ? ? B9 ? ? ? 39");
        void* UFont_GetCharKerning_Address = (void*)Scanner.FindDirectSig("? ? ? D1 ? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? 91 F5 03 00 AA ? ? ? 39 ? ? ? 71");
        void* FText_Constructor_Address = (void*)Scanner.FindDirectSig("? ? ? D1 ? ? ? 6D ? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? A9 ? ? ? 91 F5 03 01 AA F3 03 00 AA ? ? ? 52");

        InitFunc(FName::Constructor, FName_Constructor_Address);
        InitFunc(FText::Constructor, FText_Constructor_Address);
        InitFunc(FMemory::EngineRealloc, FMemory_Realloc_Address);
        InitFunc(SetClientTravel_Internal, SetClientTravel_Address);
        InitFunc(FontManager::_GetCharSize, UFont_GetCharSize_Address);
        InitFunc(FontManager::_GetCharKerning, UFont_GetCharKerning_Address);

        InitFuncWithOffset(K2_DrawLine, 0x102BBBE0C);
        InitFuncWithOffset(K2_DrawText, 0x102BC0138);
        InitFuncWithOffset(K2_DrawTexture, 0x102BBFE90);
        InitFuncWithOffset(K2_SetRelativeRotation_Internal, 0x102659ACC);
        InitFuncWithOffset(LineOfSightTo, 0x1026E3338);
        InitFuncWithOffset(GetShootingCameraLocation, 0x100BDB550);

        InitFuncWithOffset(StaticLoadClass, 0x101560AF0);

#undef InitFunc

        FNames::FindAll();

        for (auto Index{0}; Index < DinoClasses.size(); ++Index)
        {
            int32 CompIndex = *FName(DinoClasses[Index].c_str());
            FNameDinoMap.emplace(CompIndex, Index);
        }

        GAverageFPS = (float*)(InSDKUtils::GetImageBase() + 0x104468130);

        std::thread(DrawDataThread).detach();

        VftSwapFunc(UShooterGameViewportClient::GetDefaultObj(), (void*)new_PostRender, (void*&)orig_PostRender, 128);
        VftSwapFunc(AShooterPlayerController::GetDefaultObj(), (void*)new_TickActor, (void*&)orig_TickActor, 155);
        VftSwapFunc(UInterpGroup::GetDefaultObj(), (void*)new_UpdateGroup, (void*&)orig_UpdateGroup, 77);
        VftSwapFunc(AShooterPlayerController::GetDefaultObj(), (void*)new_UpdateRotation, (void*&)orig_UpdateRotation, 429);
        VftSwapFunc(AShooterCharacter::GetDefaultObj(), (void*)new_AShooterCharacter$ProcessEvent, (void*&)orig_AShooterCharacter$ProcessEvent, Offsets::ProcessEventIdx);
        VftSwapFunc(APrimalDinoCharacter::GetDefaultObj(), (void*)new_APrimalDinoCharacter$PlayHitEffect, (void*&)orig_APrimalDinoCharacter$PlayHitEffect, 496);
        VftSwapFunc(AShooterWeapon_Instant::GetDefaultObj(), (void*)new_GetAdjustedAim, (void*&)orig_GetAdjustedAim, 334);
        VftSwapFunc(UShooterEngine::GetDefaultObj(), (void*)new_UShooterEngine$Tick, (void*&)orig_UShooterEngine$Tick, 94);

        UpdateEngineIni();

    });
}




