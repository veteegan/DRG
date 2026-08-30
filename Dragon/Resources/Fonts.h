#pragma once

#include "Resources/Fonts/IconsFontAwesome6.h"
// #include "Resources/Fonts/nsmfont.h"
#include "Resources/Fonts/ark_font.h"
//#include "Resources/Fonts/fira_font.h"
//#include "Resources/Fonts/anon_font.h"

#include "Utilities/Singleton.h"
#include "ImGui/imgui.h"

class FontRanges : public SingletonDestroyProbe<FontRanges> {
public:
    static constexpr ImWchar esp_ranges[] = {
        0x0020, 0x00FF, // Basic Latin + Latin Supplement
        0x0100, 0x017F, // Latin Extended-A
        0x0180, 0x024F, // Latin Extended-B
        0x1E00, 0x1EFF, // Latin Extended Additional
        0x2000, 0x206F, // General Punctuation
        0x3000, 0x30FF, // CJK Symbols and Punctuations, Hiragana, Katakana
        0x31F0, 0x31FF, // Katakana Phonetic Extensions
        0xFF00, 0xFFEF, // Half-width characters
        0xFFFD, 0xFFFD, // Invalid
        0x4e00, 0x9FAF, // CJK Ideograms
        0
    };

    static constexpr ImWchar latin_ranges[] = {
        0x0020, 0x00FF, // Basic Latin + Latin Supplement
        0x0100, 0x017F, // Latin Extended-A
        0x0180, 0x024F, // Latin Extended-B
        0x1E00, 0x1EFF, // Latin Extended Additional
        0
    };

    /* static constexpr ImWchar logo_ranges[] = {
        0x0020, 0x0021, // space ' '
        0x0041, 0x0042, // 'A' // A
        0x0061, 0x0062, // 'a'
        0x0044, 0x0045, // 'D' // D
        0x0064, 0x0065, // 'd'
        0x0047, 0x0048, // 'G' // G
        0x0067, 0x0068, // 'g'
        0x004E, 0x004F, // 'N' // N
        0x006E, 0x006F, // 'n'
        0x004F, 0x0050, // 'O' // O
        0x006F, 0x0070, // 'o'
        0x0052, 0x0053, // 'R' // R
        0x0072, 0x0073, // 'r'
        0x0058, 0x0059, // 'X' // X
        0x004D, 0x004E, // 'M' // M
        0x006D, 0x006E, // 'm'
        0x0045, 0x0046, // 'E' // E
        0x0065, 0x0066, // 'e'
        0x0043, 0x0044, // 'C' // C
        0x0063, 0x0064, // 'c'
        0x0059, 0x005A, // 'Y' // Y
        0x0079, 0x007A, // 'y'
        0
    }; */
    
    /* static constexpr ImWchar icons_ranges[] = {
        0xf54c, 0xf54d, // ICON_FA_SKULL
        0xf186, 0xf187, // ICON_FA_MOON
        0xf004, 0xf005, // ICON_FA_HEART
        0xf007, 0xf008, // ICON_FA_USER
        0xf023, 0xf024, // ICON_FA_LOCK
        0xf70c, 0xf70d, // ICON_FA_PERSON_RUNNING
        0xf05b, 0xf05c, // ICON_FA_CROSSHAIRS
        0xf06e, 0xf06f, // ICON_FA_EYE
        0xf6e3, 0xf6e4, // ICON_FA_HAMMER
        0xf502, 0xf503, // ICON_FA_USER_LOCK
        0xf013, 0xf014, // ICON_FA_GEAR
        0xE000, 0xF8FF, // ICON_FA_WAND_MAGIC_SPARKLES
        0xf0ac, 0xf0ad, // ICON_FA_GLOBE
        0
    }; */

    /* static constexpr ImWchar icons_ranges_brands[] = {
        0xf392, 0xf393, // ICON_FA_DISCORD
        0xf09a, 0xf09b, // ICON_FA_FACEBOOK
        0xf1d6, 0xf1d7, // ICON_FA_QQ
        0xf167, 0xf168, // ICON_FA_YOUTUBE
        0
    }; */

    /* static constexpr ImWchar icons_ranges_esp[] = {
        0xf54c, 0xf54d, // ICON_FA_SKULL
        0xf186, 0xf187, // ICON_FA_MOON
        0xf004, 0xf005, // ICON_FA_HEART
        0
    }; */
    
    static constexpr ImWchar icons_ranges_max[] = {ICON_MIN_FA, ICON_MAX_16_FA, 0};
    // static constexpr ImWchar icons_ranges_brands_max[] = {ICON_MIN_FAB, ICON_MAX_16_FAB, 0};

public:
    friend class SingletonDestroyProbe<FontRanges>;

protected:
    FontRanges() = default;
    ~FontRanges() = default;
};
