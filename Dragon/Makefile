
#  Makefile
#  Sishen
#
#  Maintained by Project Contributors 2024 (c)
#
# 	Under Support of MHGA
#
# 	 We have only God
#  	 We have only one
#	@@@@@@@@@@@@@@@@@@@
#  		We pray, we hope
# 		We love, we faith
#	   @@@@@@@@@@@@@@@@@@@
#  			Our God - Hikari
#  			The World is art
#
#  LLVM16 Hikari Obfuscator
#  arm64e is supported
#

ARCHS = arm64 # arm64e
TARGET = iphone:clang:16.5:15

export TARGET_CC=/Library/Developer/Toolchains/Hikari_LLVM16.0.0.xctoolchain/usr/bin/clang
export TARGET_CXX=/Library/Developer/Toolchains/Hikari_LLVM16.0.0.xctoolchain/usr/bin/clang++

DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

include $(THEOS)/makefiles/common.mk
# thats why
TWEAK_NAME = Sishen

$(TWEAK_NAME)_USE_MODULES = 0
$(TWEAK_NAME)_FRAMEWORKS = UIKit Metal MetalKit Foundation CFNetwork CoreFoundation Security QuartzCore CoreGraphics CoreText AVFoundation Accelerate GLKit SystemConfiguration GameController ImageIO

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function -I./Utilities -I./ImGui -I./ImGui/backends -I./Resources -Wno-reorder -Wno-array-bounds -Wno-misleading-indentation -Wno-format-security

$(TWEAK_NAME)_CCFLAGS = -std=c++20 -fno-rtti -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function -Wno-writable-strings -Wno-unused-private-field -Wno-class-conversion -I./Utilities -I./ImGui -I./Resources  -I./ImGui/backends -Wno-reorder -Wno-array-bounds -Wno-misleading-indentation -Wno-format-security

$(TWEAK_NAME)_LDFLAGS += -L./ -lfmt 

$(TWEAK_NAME)_CFLAGS += -I$(THEOS_PROJECT_DIR)/vendor/include
$(TWEAK_NAME)_LDFLAGS += -L$(THEOS_PROJECT_DIR)/vendor/lib
$(TWEAK_NAME)_LIBRARIES += curl z ssl crypto 

# $(TWEAK_NAME)_CFLAGS += -DTHREAD -I$(THEOS_PROJECT_DIR)/vendor/include/MariaDB/include

IMGUI_SRC = \
 $(wildcard ImGui/*.mm) \
 ImGui/backends/metal_additive.mm \
  $(wildcard ImGui/*.cpp) \
   ImGui/DRGui/dr_gui.cpp 
   
LOADERS_SRC = \
  MenuLoad/MenuLoad.mm \
  MenuLoad/ProcessFront.mm \
  MenuLoad/ImGuiDrawView.mm

UTILITIES = \
  Source/Libraries/UrlOpener/UrlOpener.mm \
   Source/Libraries/CGuardMemory/CGPMemory.cpp \
    Source/Libraries/CGuardMemory/fishhook.cpp \
     Utilities/iOSAlerts.mm 

SOURCE_BASE = \
 Source/CppSDK/SDK/Basic.cpp \
  Source/CppSDK/SDK/CoreUObject_functions.cpp \
   Source/CppSDK/SDK/Engine_functions.cpp \
    Source/CppSDK/SDK/ShooterGame_functions.cpp \
     Source/CppSDK/SDK/UMG_functions.cpp \
	  Source/CppSDK/Math.mm
      
MENU_SRC = \
 Menu/UserMenu.mm \
  Menu/EnumPage.cpp \
   FrameTaskManager.mm

UDID_SRC = \
 Source/Libraries/GetUDID/UDID.m \
  $(wildcard Source/Libraries/GetUDID/SFWebServer/*.m) 

FONTS_SRC = \
  Resources/Fonts/ark_font.cpp \
   Resources/Fonts/IconsFontAwesome6_Bytes.cpp


##### NONE OBFUSCATED FILES #####

NON_OBFUSCATED_FILES = DinoNames.cpp Menu/AdminMaps.cpp Menu/Map.mm $(wildcard Source/Libraries/GetUDID/CocoaAsyncSocket/*.m) $(FONTS_SRC)

##### FILES TO OBFUSCATE #####

OBFUSCATED_FILES = $(IMGUI_SRC) $(LOADERS_SRC) $(UTILITIES) $(SOURCE_BASE) $(MENU_SRC) $(UDID_SRC)

##### OBFUSCATE #####
OBFUSCATED_CFLAGS = -mllvm -enable-bcfobf -mllvm -bcf_prob=100 -mllvm -enable-cffobf -mllvm -enable-strcry -mllvm -enable-subobf -mllvm -enable-fco -mllvm -enable-indibran -mllvm -enable-antihook -mllvm -ah_inline -mllvm -ah_objcruntime -mllvm -ah_antirebind -mllvm -enable-adb -mllvm -adb_prob=40 -mllvm -enable-constenc -mllvm -constenc_times=1 -mllvm -constenc_togv=1 -mllvm -constenc_togv_prob=50 -mllvm -constenc_subxor=1 -mllvm -constenc_subxor_prob=40 -mllvm -indibran-use-stack -mllvm -indibran-enc-jump-target
OBFUSCATED_CCFLAGS = $(OBFUSCATED_CFLAGS)

##### STRIP UNUSED CODE #####
CFLAGS  +=  -fvisibility=hidden -fvisibility-inlines-hidden 
CCFLAGS +=  -fvisibility=hidden -fvisibility-inlines-hidden

define OBFUSCATE_FILE
 $(1)_CFLAGS += $(OBFUSCATED_CFLAGS)
 $(1)_CCFLAGS += $(OBFUSCATED_CCFLAGS)
endef

$(foreach file,$(OBFUSCATED_FILES),$(eval $(call OBFUSCATE_FILE,$(file))))

##### BUILD #####
	
$(TWEAK_NAME)_FILES = $(NON_OBFUSCATED_FILES) $(OBFUSCATED_FILES)

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS)/makefiles/aggregate.mk
