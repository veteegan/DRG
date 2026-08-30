#pragma once

#define IMGUI_DEFINE_MATH_OPERATORS


#include "ImGuiDrawView.h"
#include "MenuLoad.h"

#include "ImGui/imgui.h"
#include "ImGui/imgui_internal.h"
#include "ImGui/backends/metal_additive.h"

#include "../Utilities/Singleton.h"
#include "../Utilities/Variables.h"
#include "../Utilities/Memory.h"
#include "../Utilities/Macros.h"
#include "../Utilities/OSLogManager.h"

#include "../Utilities/Format/format.h"
#include "../Utilities/Format/xchar.h"

#include "Source/CppSDK/UsedSDK.hpp"

#include <stdio.h>
#include <vector>
#include <map>
#include <unistd.h>
#include <string.h>
#include <vector>
#include <functional>
#include <iostream>
#include <queue>
#include <codecvt>
#include <mutex>
#include <unordered_set>
#include <concepts>
#include <unordered_map>
#include <regex>
#include <array>
#include <fstream>
#include <filesystem>
#include <cstring>

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <os/log.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <cmath>
#import <pthread/pthread.h>


inline bool MenDeal = true;

static Settings &settings = Settings::GetInstance();

static OSLogManager Console("com.example.projdragon", "ProjDragon");

inline UIButton* GInvisibleMenuButton = nullptr;
inline UIButton* GVisibleMenuButton = nullptr;
inline MenuInteraction* GMenuTouchView = nullptr;
inline UITextField* GHideRecordTextField = nullptr;
inline UIView* GHideRecordView = nullptr;

inline ImFont* GIconFont = nullptr;
inline ImFont* Font = nullptr;

inline UISwitch* AutoFireSwitch = nullptr;
inline UISwitch* AimlockSwitch = nullptr;
inline UISwitch* HideDrawSwitch = nullptr;
inline UISwitch* FreezeSwitch = nullptr;

FORCEINLINE void CrashSafe()
{
    *(volatile int*)0 = 1;
    return;
}

template<typename To>
FORCEINLINE To* Cast(void* Src)
{
    return static_cast<To*>(Src);
}

template<typename To>
FORCEINLINE const To* Cast(const void* Src)
{
    return static_cast<const To*>(Src);
}

struct
{
    int Width;
    int Height;
    int HalfWidth;
    int HalfHeight;
    int Scale;
    
    void Init()
    {
        this->Height = SCREEN_HEIGHT;
        this->Width = SCREEN_WIDTH;
        this->HalfHeight = SCREEN_HEIGHT / 2;
        this->HalfWidth = SCREEN_WIDTH / 2;
        this->Scale = SCREEN_SCALE;
    }
    
    
}inline ScreenRect;


