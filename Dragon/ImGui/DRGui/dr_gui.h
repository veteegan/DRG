#pragma once

#define IMGUI_DEFINE_MATH_OPERATORS


#include "../imgui.h"
#include "../imgui_internal.h"

#include <vector>

#define DRGUI_ANIMATIONS_SPEED 0.1f // Second

struct InputTextCallback_UserData
{
    std::string*            Str;
    ImGuiInputTextCallback  ChainCallback;
    void*                   ChainCallbackUserData;
};

static int InputTextCallback(ImGuiInputTextCallbackData* data);

namespace DRGui
{
    // Helpers
    ImVec4  HexToColorVec4(unsigned int hex_color, float alpha);

    // Text
	bool    Label(const char* label, bool fade_clip = false, bool popup_on_clip = true, const ImVec2& size = ImVec2(0, 0), const ImVec2& text_align = ImVec2(0.0f, 0.0f));
    void    DoubleText(ImVec4 color1, ImVec4 color2, const char* label1, const char* label2);

    // Separator
	void    SeparatorText(const char* label, float thickness = 1.0f);
	void    VSeparator(float margin = 0.0f, float thickness = 1.0f);

    // Navigation
	bool    RadioFrame(const char* label, int* v, int radio_id, const ImVec2& size_arg = ImVec2(0, 0));
	bool    RadioFrameIcon(ImTextureID icon_texture, const char* label, int* v, int radio_id, bool draw_label = true, const ImVec2& size = ImVec2(0, 0));
    bool    RadioFrameText(const char* label, int* v, int radio_id, bool underline = true, const ImVec2& size_arg = ImVec2(0, 0));

    // Button
    bool    LinkLabel(const char* label, bool underlined = true, const ImVec2& size_arg = ImVec2(0, 0), const ImVec2& text_align = ImVec2(0, 0), ImGuiButtonFlags button_flags = 0);
    bool    Button(const char* label, const ImVec2& size_arg = ImVec2(0, 0), ImGuiButtonFlags button_flags = 0, ImDrawFlags draw_flags = 0);
    bool    ButtonIcon(const char* str_id, ImTextureID icon_texture, const ImVec2& size_arg = ImVec2(0, 0), ImGuiButtonFlags button_flags = 0, ImDrawFlags draw_flags = 0);
    bool    SelectableLabel(ImDrawList* drawlist, const char* label, bool selected = false, const ImVec2& size_arg = ImVec2(0, 0));
	bool    ButtonXMark(const char* str_id, const ImVec2& size_arg = ImVec2(0, 0), ImDrawFlags draw_flags = 0);

    // Toggle
    bool    CheckBox(const char* label, bool* v);

    // Slider
    bool    SliderScalar(const char* label, ImGuiDataType data_type, void* p_data, const void* p_min, const void* p_max, const char* format = NULL, ImGuiSliderFlags flags = 0); 
    bool    SliderFloat(const char* label, float* v, float v_min, float v_max, const char* format = "%.1f", ImGuiSliderFlags flags = 0); 
    bool    SliderAngle(const char* label, float* v_rad, float v_degrees_min = -360.0f, float v_degrees_max = +360.0f, const char* format = "%.0f deg", ImGuiSliderFlags flags = 0);
    bool    SliderInt(const char* label, int* v, int v_min, int v_max, const char* format = "%d", ImGuiSliderFlags flags = 0);

    // Custom Child
    void    BeginChild(const char* str_id, const ImVec2& size = ImVec2(0, 0));
    void    EndChild();

    // Inputs
	bool    InputTextIcon(ImTextureID icon_texture, const char* label, char* buf, size_t buf_size, ImGuiInputTextFlags flags = 0);
    bool    InputText(const char* label, const char* text, char* buf, size_t buf_size, float width = 0.0, ImGuiInputTextFlags flags = 0, ImGuiInputTextCallback callback = NULL, void* user_data = NULL);
    bool    InputTextStr(const char* label, const char* text, std::string* str, float width, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback = NULL, void* user_data = NULL);

    // Combo
    bool    Combo(const char* str_id, int* current_item, const char* items_separated_by_zeros);
    bool    Combo(const char* str_id, int* current_item, const char* items_separated_by_zeros, float width);
    bool    MultiCombo(const char* str_id, std::vector<int>* selected, std::vector<const char*> items);
    bool    MultiCombo(const char* str_id, std::vector<int>* selected, std::vector<const char*> items, float width);
    bool   ArrowSelector(const char* str_id, int* current_item, const char* items_separated_by_zeros, const ImVec2& size_arg = ImVec2(0, 0), bool boxed = true);
    // ColorPicker
    bool    ColorEdit4(const char* str_id, float col[4]);
    bool    ColorEdit3(const char* str_id, float col[3]);

    // Keybind
    bool	KeyBind(const char* str_id, int* k);

	// Helpers
	float	GetCheckBoxSize();
}
