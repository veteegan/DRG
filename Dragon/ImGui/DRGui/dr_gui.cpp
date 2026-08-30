#include "dr_gui.h"

#include "../imgui.h"
#include "../imgui_internal.h"

#include <map>
#include <string>
#include <cmath>

using namespace ImGui;
using std::string;

static int InputTextCallback(ImGuiInputTextCallbackData* data) {
    InputTextCallback_UserData* user_data = (InputTextCallback_UserData*)data->UserData;
    if (data->EventFlag == ImGuiInputTextFlags_CallbackResize)
    {
        std::string* str = user_data->Str;
        IM_ASSERT(data->Buf == str->c_str());
        str->resize(data->BufTextLen);
        data->Buf = (char*)str->c_str();
    }
    else if (user_data->ChainCallback)
    {
        data->UserData = user_data->ChainCallbackUserData;
        return user_data->ChainCallback(data);
    }
    return 0;
}

ImVec4 DRGui::HexToColorVec4(unsigned int hex_color, float alpha)
{
    ImVec4 color;

    color.x = ((hex_color >> 16) & 0xFF) / 255.0f;
    color.y = ((hex_color >> 8) & 0xFF) / 255.0f;
    color.z = (hex_color & 0xFF) / 255.0f;
    color.w = alpha;

    return color;
}

bool DRGui::Label(const char* label, bool fade_clip, bool popup_on_clip, const ImVec2& size_arg, const ImVec2& text_align)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(size_arg, label_size.x, label_size.y);

    const ImRect bb(pos, pos + size);
    ItemSize(size);
    if (!ItemAdd(bb, id))
        return false;

    bool hovered, held;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held);

    RenderNavHighlight(bb, id);
    //RenderFrame(bb.Min, bb.Max, IM_COL32(255, 0, 0, 255), false);
    RenderTextClipped(bb.Min, bb.Max, label, NULL, &label_size, text_align, &bb);

    if (fade_clip)
    {
        window->DrawList->AddRectFilledMultiColor(pos + ImVec2(size.x - GetFontSize(), 0.0f), pos + size, GetColorU32(ImGuiCol_ChildBg, 0.0f), GetColorU32(ImGuiCol_ChildBg), GetColorU32(ImGuiCol_ChildBg), GetColorU32(ImGuiCol_ChildBg, 0.0f));
    }

    if (popup_on_clip && hovered && label_size.x >= size.x)
    {
        if (BeginTooltip())
        {
            TextDisabled(label);
            EndTooltip();
        }
    }

    return pressed;
}

void DRGui::DoubleText(ImVec4 color1, ImVec4 color2, const char* label1, const char* label2)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(std::string(label1 + std::string(label2)).c_str());
    const ImVec2 label1_size = CalcTextSize(label1, NULL, true);
    const ImVec2 label2_size = CalcTextSize(label2, NULL, true);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(ImVec2(-0.1f, g.FontSize), label1_size.x + label2_size.x, g.FontSize);

    const ImRect total_bb(pos, pos + size);
    ItemSize(total_bb);
    if (!ItemAdd(total_bb, id)) {
        return;
    }

    window->DrawList->AddText(pos, GetColorU32(color1), label1);
    window->DrawList->AddText(pos + ImVec2(size.x - ImGui::CalcTextSize(label2).x, 0), GetColorU32(color2), label2);
}

void DRGui::SeparatorText(const char* label, float thickness)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(ImVec2(-0.1f, g.FontSize), label_size.x, g.FontSize);

    const ImRect total_bb(pos, pos + size);
    ItemSize(total_bb);
    if (!ItemAdd(total_bb, id)) {
        return;
    }

    window->DrawList->AddText(pos, GetColorU32(ImGuiCol_TextDisabled), label);

    if (thickness > 0)
        window->DrawList->AddLine(pos + ImVec2(label_size.x + style.ItemInnerSpacing.x, size.y / 2), pos + ImVec2(size.x, size.y / 2), GetColorU32(ImGuiCol_Border), thickness);
}

void DRGui::VSeparator(float margin, float thickness)
{
    if (thickness <= 0)
        return;

    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(ImVec2(thickness, -0.1f), thickness, thickness);

    const ImRect bb(pos, pos + size);
    const ImRect bb_rect(pos + ImVec2(0, margin), pos + size - ImVec2(0, margin));

    ItemSize(ImVec2(thickness, 0.0f));
    if (!ItemAdd(bb, 0))
        return;

    window->DrawList->AddRectFilled(bb_rect.Min, bb_rect.Max, GetColorU32(ImGuiCol_Border));
}

bool DRGui::RadioFrame(const char* label, int* v, int radio_id, const ImVec2& size_arg)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(size_arg, label_size.x + style.FramePadding.x * 2.0f, label_size.y + style.FramePadding.y * 2.0f);

    const ImRect total_bb(pos, pos + size);
    ItemSize(size, style.FramePadding.y);
    if (!ItemAdd(total_bb, id))
        return false;

    float half_height = ImTrunc(size.y / 2);
    float border_size = style.FrameBorderSize;

    bool hovered, held;
    bool pressed = ButtonBehavior(total_bb, id, &hovered, &held);
    bool active = (*v == radio_id);
    if (pressed) {
        *v = radio_id;
        active = true; // for this frame’s visual target
    }

    // Colors
    ImVec4 colFrame = GetStyleColorVec4(active ? ImGuiCol_SliderGrab : ImGuiCol_FrameBg);
    ImVec4 colBorderMain = GetStyleColorVec4(ImGuiCol_Border);
    ImVec4 colBorderNull = colBorderMain; colBorderNull.w = 0.0f;
    ImVec4 colBorder = (hovered && !active ? colBorderMain : colBorderNull);
    ImVec4 colLabel = GetStyleColorVec4((active || hovered) ? ImGuiCol_Text : ImGuiCol_TextDisabled);

    // Animation
    struct AnimState {
        ImVec4 Frame;
        ImVec4 Border;
        ImVec4 Label;
        float  LabelScale;
    };
    static std::map<ImGuiID, AnimState> anim;
    auto it = anim.find(id);
    if (it == anim.end()) {
        AnimState s;
        s.Frame = colFrame;
        s.Border = colBorder;
        s.Label = colLabel;
        s.LabelScale = active ? 1.10f : 1.00f; // initial scale
        it = anim.insert({ id, s }).first;
    }

    const float k = (1.0f / DRGUI_ANIMATIONS_SPEED) * g.IO.DeltaTime;
    const float target_scale = active ? 1.10f : 1.00f; // tweak to taste (e.g., 1.06–1.12 looks nice)

    it->second.Frame      = ImLerp(it->second.Frame,  colFrame,  k);
    it->second.Border     = ImLerp(it->second.Border, colBorder, k);
    it->second.Label      = ImLerp(it->second.Label,  colLabel,  k);
    it->second.LabelScale = ImLerp(it->second.LabelScale, target_scale, k);

    // Render
    ImDrawList* dl = window->DrawList;

    ImVec2 A = pos + ImVec2(half_height, 0);
    ImVec2 B = pos + ImVec2(size.x,      0);
    ImVec2 C = pos + ImVec2(size.x,      half_height);
    ImVec2 D = pos + ImVec2(size.x - half_height, size.y);
    ImVec2 E = pos + ImVec2(0,           size.y);
    ImVec2 F = pos + ImVec2(0,           half_height);

    ImVec2 poly[6] = { A, B, C, D, E, F };
    dl->AddConvexPolyFilled(poly, 6, GetColorU32(it->second.Frame));

    if (border_size == 1.0f) {
        for (int i = 0; i < 6; ++i)
            poly[i] = ImFloor(poly[i]) + ImVec2(0.5f, 0.5f);
    }
    dl->AddPolyline(poly, 6, GetColorU32(it->second.Border), ImDrawFlags_Closed, border_size);

    // Draw scaled label (no need to PushFont; pass size directly)
    ImFont* font = g.Font;
    float base_fs = g.FontSize;
    float fs = base_fs * it->second.LabelScale;

    // Keep label vertically centered as size changes
    ImVec2 text_pos = pos + ImVec2(
        half_height + style.FramePadding.x,
        style.FramePadding.y - 1.0f
    );

    dl->AddText(font, fs, text_pos, GetColorU32(it->second.Label), label, NULL);

    return pressed;
}
bool DRGui::RadioFrameIcon(ImTextureID icon_texture, const char* label, int* v, int radio_id, bool draw_label, const ImVec2& size_arg)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);
    bool has_icon = icon_texture != 0;
    bool has_border = style.FrameBorderSize > 0;

    const ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(size_arg, has_icon ? GetFrameHeight() + label_size.x + style.FramePadding.x : label_size.x + style.FramePadding.x * 2, GetFrameHeight());

    const ImRect total_bb(pos, pos + size);
    ItemSize(total_bb, style.FramePadding.y);
    if (!ItemAdd(total_bb, id))
    {
        IMGUI_TEST_ENGINE_ITEM_INFO(id, label, g.LastItemData.StatusFlags | ImGuiItemStatusFlags_Checkable | (*v ? ImGuiItemStatusFlags_Checked : 0));
        return false;
    }

    bool hovered, held;
    bool pressed = ButtonBehavior(total_bb, id, &hovered, &held);
    if (pressed)
    {
        *v = radio_id;
        MarkItemEdited(id);
    }
    bool active = *v == radio_id;

    // Colors
    ImVec4 colFrameMain = GetStyleColorVec4(ImGuiCol_Header);
    ImVec4 colFrameNull = colFrameMain; colFrameNull.w = 0.0f;
    ImVec4 colFrame = (active ? colFrameMain : colFrameNull);
    
    ImVec4 colBorderMain = GetStyleColorVec4(ImGuiCol_Border);
    ImVec4 colBorderNull = colFrameMain; colBorderNull.w = 0.0f;
    ImVec4 colBorder = (active ? colBorderMain : colBorderNull);

    ImVec4 colLabelMain = GetStyleColorVec4((active || hovered) ? ImGuiCol_Text : ImGuiCol_TextDisabled);
    ImVec4 colLabelNull = colLabelMain; colLabelNull.w = 0.0f;
    ImVec4 colLabel = (draw_label ? colLabelMain : colLabelNull);

    ImVec4 colIcon = GetStyleColorVec4((hovered && !held) || active ? ImGuiCol_Text : ImGuiCol_TextDisabled);

    // Animation
    struct stColors_State {
        ImVec4 Frame;
        ImVec4 Border;
        ImVec4 Label;
        ImVec4 Icon;
    };

    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);

    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State() });
        it_anim = anim.find(id);

        it_anim->second.Frame = colFrame;
        it_anim->second.Border = colBorder;
        it_anim->second.Label = colLabel;
        it_anim->second.Icon = colIcon;
    }

    it_anim->second.Frame = ImLerp(it_anim->second.Frame, colFrame, 1.0f / DRGUI_ANIMATIONS_SPEED * ImGui::GetIO().DeltaTime);
    if (has_border) {    // good for preformance
        it_anim->second.Border = ImLerp(it_anim->second.Border, colBorder, 1.0f / DRGUI_ANIMATIONS_SPEED * ImGui::GetIO().DeltaTime);
    }
    it_anim->second.Label = ImLerp(it_anim->second.Label, colLabel, 1.0f / DRGUI_ANIMATIONS_SPEED * ImGui::GetIO().DeltaTime);
    it_anim->second.Icon = ImLerp(it_anim->second.Icon, colIcon, 1.0f / DRGUI_ANIMATIONS_SPEED * ImGui::GetIO().DeltaTime);

    RenderNavHighlight(total_bb, id);

    window->DrawList->AddRectFilled(total_bb.Min, total_bb.Max, GetColorU32(it_anim->second.Frame), style.TabRounding);
    if (has_border) {
        window->DrawList->AddRect(total_bb.Min, total_bb.Max, GetColorU32(it_anim->second.Border), style.TabRounding, 0, style.FrameBorderSize);
    }

    if (has_icon) {
        window->DrawList->AddImage(icon_texture, pos + style.FramePadding, pos + ImVec2(size.y, size.y) - style.FramePadding, ImVec2(), ImVec2(1, 1), GetColorU32(it_anim->second.Icon));
    }

    if (label_size.x > 0.0f) {
        PushStyleColor(ImGuiCol_Text, it_anim->second.Label);
        RenderText(has_icon ? pos + ImVec2(GetFrameHeight(), style.FramePadding.y) : pos + style.FramePadding, label);
        PopStyleColor();
    }

    return pressed;
}

bool DRGui::RadioFrameText(const char* label, int* v, int radio_id, bool underline, const ImVec2& size_arg)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(size_arg, label_size.x, label_size.y);

    const ImRect bb(pos, pos + size);
    ItemSize(size);
    if (!ItemAdd(bb, id))
        return false;

    bool hovered, held, active;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held);
    active = *v == radio_id;
    if (pressed) {
        *v = radio_id;
    }

    // Colors
    ImVec4 colLabel = GetStyleColorVec4(active ? ImGuiCol_SliderGrab : (hovered && !held) ? ImGuiCol_Text : ImGuiCol_TextDisabled);

    ImVec4 colUnderlineMain = GetStyleColorVec4(ImGuiCol_SliderGrab);
    ImVec4 colUnderlineNull = colUnderlineMain; colUnderlineNull.w = 0.0f;
    ImVec4 colUnderline = (active ? colUnderlineMain : colUnderlineNull);

    // Animations
    struct stColors_State {
        ImVec4 Label;
        ImVec4 Underline;
    };

    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);

    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State() });
        it_anim = anim.find(id);

        it_anim->second.Label = colLabel;
        it_anim->second.Underline = colUnderline;
    }

    it_anim->second.Label = ImLerp(it_anim->second.Label, colLabel, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);
    it_anim->second.Underline = ImLerp(it_anim->second.Underline, colUnderline, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);

    // Render
    RenderNavHighlight(bb, id);

    window->DrawList->AddText(pos + ImVec2(size.x / 2 - label_size.x / 2, size.y / 2 - label_size.y / 2 + 1), GetColorU32(it_anim->second.Label), label);
    if (underline)
        window->DrawList->AddLine(pos + ImVec2(-1, label_size.y + style.FrameBorderSize * 2), pos + ImVec2(label_size.x, label_size.y + style.FrameBorderSize * 2), ImGui::GetColorU32(it_anim->second.Underline), style.FrameBorderSize);

    return pressed;
}

bool DRGui::LinkLabel(const char* label, bool underlined, const ImVec2& size_arg, const ImVec2& text_align, ImGuiButtonFlags button_flags)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(size_arg, label_size.x, label_size.y);

    const ImRect bb(pos, pos + size);
    ItemSize(size);
    if (!ItemAdd(bb, id))
        return false;

    bool hovered, held;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held, button_flags);
    bool has_border = style.FrameBorderSize > 0;

    // Colors
    ImVec4 colText = GetStyleColorVec4((held && hovered) ? ImGuiCol_SliderGrabActive : ImGuiCol_SliderGrab);

    // Animations
    struct stColors_State {
        ImVec4 Text;
    };

    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);

    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State() });
        it_anim = anim.find(id);

        it_anim->second.Text = colText;
    }

    it_anim->second.Text = ImLerp(it_anim->second.Text, colText, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);

    // Render
    RenderNavHighlight(bb, id);

    PushStyleColor(ImGuiCol_Text, it_anim->second.Text);
    RenderTextClipped(bb.Min, bb.Max, label, NULL, &label_size, text_align, &bb);
    PopStyleColor();

    if (underlined)
    {
        window->DrawList->AddLine(bb.Min + ImVec2(0, label_size.y - 1), bb.Min + ImVec2(bb.Max.x - bb.Min.x, label_size.y - 1), GetColorU32(it_anim->second.Text));
    }

    return pressed;
}

bool DRGui::Button(const char* label, const ImVec2& size_arg, ImGuiButtonFlags button_flags, ImDrawFlags draw_flags)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);

    ImVec2 pos = window->DC.CursorPos;
    if ((button_flags & ImGuiButtonFlags_AlignTextBaseLine) && style.FramePadding.y < window->DC.CurrLineTextBaseOffset) // Try to vertically align buttons that are smaller/have no padding so that text baseline matches (bit hacky, since it shouldn't be a flag)
        pos.y += window->DC.CurrLineTextBaseOffset - style.FramePadding.y;
    ImVec2 size = CalcItemSize(size_arg, label_size.x + style.FramePadding.x * 2.0f, label_size.y + style.FramePadding.y * 2.0f);

    const ImRect bb(pos, pos + size);
    ItemSize(size, style.FramePadding.y);
    if (!ItemAdd(bb, id))
        return false;

    bool hovered, held;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held, button_flags);
    bool has_border = style.FrameBorderSize > 0;

    // Colors
    ImVec4 colFrame = GetStyleColorVec4((held && hovered) ? ImGuiCol_SliderGrab : hovered ? ImGuiCol_SliderGrabActive : ImGuiCol_FrameBg);

    // Animations
    struct stColors_State {
        ImVec4 Frame;
    };

    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);

    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State() });
        it_anim = anim.find(id);

        it_anim->second.Frame = colFrame;
    }

    it_anim->second.Frame = ImLerp(it_anim->second.Frame, colFrame, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);

    // Render
    RenderNavHighlight(bb, id);

    window->DrawList->AddRectFilled(bb.Min, bb.Max, GetColorU32(it_anim->second.Frame), style.FrameRounding, draw_flags);
    if (has_border)
    {
        window->DrawList->AddRect(bb.Min, bb.Max, GetColorU32(ImGuiCol_Border), style.FrameRounding, draw_flags, style.FrameBorderSize);
    }

    RenderTextClipped(bb.Min + style.FramePadding, bb.Max - style.FramePadding, label, NULL, &label_size, style.ButtonTextAlign, &bb);

    return pressed;
}

bool DRGui::ButtonIcon(const char* str_id, ImTextureID icon_texture, const ImVec2& size_arg, ImGuiButtonFlags button_flags, ImDrawFlags draw_flags)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(str_id);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(size_arg, GetFrameHeight(), GetFrameHeight());

    const ImRect bb(pos, pos + size);
    ItemSize(size, style.FramePadding.y);
    if (!ItemAdd(bb, id))
        return false;

    bool hovered, held;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held, button_flags);
    bool has_border = style.FrameBorderSize > 0;

    // Colors
    ImVec4 colFrame = GetStyleColorVec4((held && hovered) ? ImGuiCol_ButtonActive : hovered ? ImGuiCol_ButtonHovered : ImGuiCol_Button);
    ImVec4 colIcon = GetStyleColorVec4((hovered && !held) ? ImGuiCol_Text : ImGuiCol_TextDisabled);

    // Animations
    struct stColors_State {
        ImVec4 Frame;
        ImVec4 Icon;
    };

    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);

    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State() });
        it_anim = anim.find(id);

        it_anim->second.Frame = colFrame;
        it_anim->second.Icon = colIcon;
    }

    it_anim->second.Frame = ImLerp(it_anim->second.Frame, colFrame, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);
    it_anim->second.Icon = ImLerp(it_anim->second.Icon, colIcon, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);

    // Render
    RenderNavHighlight(bb, id);

    window->DrawList->AddRectFilled(bb.Min, bb.Max, GetColorU32(it_anim->second.Frame), style.FrameRounding, draw_flags);
    if (has_border)
    {
        window->DrawList->AddRect(bb.Min, bb.Max, GetColorU32(ImGuiCol_Border), style.FrameRounding, draw_flags, style.FrameBorderSize);
    }

    window->DrawList->AddImage(icon_texture, pos + style.FramePadding, pos + size - style.FramePadding, ImVec2(0, 0), ImVec2(1, 1), GetColorU32(it_anim->second.Icon));

    return pressed;
}

bool DRGui::SelectableLabel(ImDrawList* drawlist, const char* label, bool selected, const ImVec2& size_arg)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(size_arg, label_size.x, label_size.y);

    const ImRect bb(pos, pos + size);
    ItemSize(size);
    if (!ItemAdd(bb, id))
        return false;

    bool hovered, held;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held);
    bool has_border = style.FrameBorderSize > 0;

    // Colors
    ImVec4 colText = GetStyleColorVec4(selected ? ImGuiCol_SliderGrab : (hovered && !held) ? ImGuiCol_Text : ImGuiCol_TextDisabled);

    // Animations
    struct stColors_State {
        ImVec4 Text;
    };

    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);

    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State() });
        it_anim = anim.find(id);

        it_anim->second.Text = colText;
    }

    it_anim->second.Text = ImLerp(it_anim->second.Text, colText, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);

    // Render
    RenderNavHighlight(bb, id);

    drawlist->AddText(pos, GetColorU32(it_anim->second.Text), label);

    return pressed;
}

bool DRGui::ButtonXMark(const char* str_id, const ImVec2& size_arg, ImDrawFlags draw_flags)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(str_id);

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = CalcItemSize(size_arg, GetFrameHeight(), GetFrameHeight());

    const ImRect bb(pos, pos + size);
    ItemSize(size, style.FramePadding.y);
    if (!ItemAdd(bb, id))
        return false;

    bool hovered, held;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held);

    // Colors
    ImVec4 colXMark = GetStyleColorVec4(held ? ImGuiCol_TextDisabled : ImGuiCol_Text);

    // Animation
    struct stColors_State {
        ImVec4 Frame;
        ImVec4 XMark;
    };

    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);

    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State() });
        it_anim = anim.find(id);

        it_anim->second.XMark = colXMark;
    }

    it_anim->second.XMark = ImLerp(it_anim->second.XMark, colXMark, 1.0f / DRGUI_ANIMATIONS_SPEED * ImGui::GetIO().DeltaTime);

    // Render
    RenderNavHighlight(bb, id);

    ImVec2 center = bb.GetCenter();
    float cross_extent = g.FontSize * 0.5f * 0.7071f - 1.0f;
  //  center -= ImVec2(0.5f, 0.5f);
    window->DrawList->AddLine(center + ImVec2(+cross_extent, +cross_extent), center + ImVec2(-cross_extent, -cross_extent), GetColorU32(it_anim->second.XMark), 1.0f);
    window->DrawList->AddLine(center + ImVec2(+cross_extent, -cross_extent), center + ImVec2(-cross_extent, +cross_extent), GetColorU32(it_anim->second.XMark), 1.0f);

    return pressed;
}

bool DRGui::CheckBox(const char* label, bool* v)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);

    const float square_sz = GetFontSize() + style.CellPadding.y * 2.0f;
    const ImVec2 pos = window->DC.CursorPos;
    const ImRect total_bb(pos, pos + ImVec2(square_sz + (label_size.x > 0.0f ? style.ItemInnerSpacing.x + label_size.x : 0.0f), label_size.y + style.CellPadding.y * 2.0f));
    ItemSize(total_bb, style.CellPadding.y);

    if (!ItemAdd(total_bb, id))
    {
        return false;
    }

  //  const bool is_multi_select = (g.LastItemData.InFlags & ImGuiItemFlags_IsMultiSelect) != 0;
    const bool has_border = style.FrameBorderSize > 0;

    // Range-Selection/Multi-selection support (header)
    bool checked = *v;
//    if (is_multi_select)
//        MultiSelectItemHeader(id, &checked, NULL);

    bool hovered, held;
    bool pressed = ButtonBehavior(total_bb, id, &hovered, &held);

    if (pressed) {
        checked = !checked;
    }

    if (*v != checked)
    {
        *v = checked;
        pressed = true; // return value
        MarkItemEdited(id);
    }

    const ImRect check_bb(pos, pos + ImVec2(square_sz, square_sz));

    // Colors
    ImVec4 colBorder = GetStyleColorVec4(hovered && !checked ? ImGuiCol_SliderGrab : ImGuiCol_SliderGrabActive);

    ImVec4 colFrameMain = GetStyleColorVec4(ImGuiCol_FrameBg);
    ImVec4 colFrameNull = colFrameMain; colFrameNull.w = 0.0f;
    ImVec4 colFrame = (hovered && !checked ? colFrameMain : colFrameNull);

    ImVec4 colCheckMarkMain = GetStyleColorVec4(ImGuiCol_SliderGrab);
    ImVec4 colCheckMarkNull = colCheckMarkMain; colCheckMarkNull.w = 0.0f;
    ImVec4 colCheckMark = (checked ? colCheckMarkMain : colCheckMarkNull);

    // Animations
    struct stColors_State {
        ImVec4 Frame;
        ImVec4 Border;
        ImVec4 CheckMark;
    };

    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);

    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State() });
        it_anim = anim.find(id);

        it_anim->second.Frame = colFrame;
        it_anim->second.Border = colBorder;
        it_anim->second.CheckMark = colCheckMark;
    }

    it_anim->second.Frame = ImLerp(it_anim->second.Frame, colFrame, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);
    it_anim->second.Border = ImLerp(it_anim->second.Border, colBorder, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);
    it_anim->second.CheckMark = ImLerp(it_anim->second.CheckMark, colCheckMark, 1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);

    RenderNavHighlight(total_bb, id);

    window->DrawList->AddRectFilled(check_bb.Min, check_bb.Max, GetColorU32(it_anim->second.Frame), style.FrameRounding);
    if (has_border)
    {
        window->DrawList->AddRect(check_bb.Min, check_bb.Max, GetColorU32(it_anim->second.Border), style.FrameRounding, 0, style.FrameBorderSize);
    }

    window->DrawList->AddRectFilled(check_bb.Min + ImVec2(style.FrameBorderSize + 1, style.FrameBorderSize + 1), check_bb.Max - ImVec2(style.FrameBorderSize + 1, style.FrameBorderSize + 1), GetColorU32(it_anim->second.CheckMark), style.FrameRounding);

    const ImVec2 label_pos = ImVec2(check_bb.Max.x + style.ItemInnerSpacing.x, check_bb.Min.y + style.CellPadding.y);
    if (label_size.x > 0.0f) {
        RenderText(label_pos, label);
    }

    return pressed;
}

bool DRGui::SliderScalar(const char* label, ImGuiDataType data_type, void* p_data, const void* p_min, const void* p_max, const char* format, ImGuiSliderFlags flags)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const float width = CalcItemWidth();
    const ImVec2 pos = window->DC.CursorPos;

    const ImVec2 label_size = CalcTextSize(label, NULL, true);
    const bool has_label = label_size.x > 0;
    const float label_height = has_label ? g.FontSize + style.ItemInnerSpacing.y : 0.0f;

    const ImRect frame_bb(pos + ImVec2(0, label_height), pos + ImVec2(width, label_height + g.FontSize));
    const ImRect total_bb(pos, pos + ImVec2(width, label_height + g.FontSize));

    ItemSize(total_bb);
    if (!ItemAdd(total_bb, id, &frame_bb, 0))
        return false;

    if (format == NULL)
        format = DataTypeGetInfo(data_type)->PrintFmt;

    // Hover/activation
    const bool hovered = ItemHoverable(frame_bb, id, GImGui->CurrentItemFlags);
    const bool clicked = hovered && IsMouseClicked(0, ImGuiInputFlags_None, id);
    const bool held    = (g.ActiveId == id);
    const bool make_active = (clicked || g.NavActivateId == id);
    if (make_active)
    {
        SetActiveID(id, window);
        SetFocusID(id, window);
        FocusWindow(window);
        g.ActiveIdUsingNavDirMask |= (1 << ImGuiDir_Left) | (1 << ImGuiDir_Right);
    }

    ImVec4 colFrame = GetStyleColorVec4(held ? ImGuiCol_FrameBgActive : hovered ? ImGuiCol_FrameBgHovered : ImGuiCol_FrameBg);
    ImVec4 colFill  = GetStyleColorVec4(held ? ImGuiCol_SliderGrabActive : ImGuiCol_SliderGrab);

    struct stColors_State { ImVec4 Frame, Fill; };
    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);
    if (it_anim == anim.end())
    {
        anim.insert({ id, stColors_State{ colFrame, colFill } });
        it_anim = anim.find(id);
    }
    const float k = (1.0f / DRGUI_ANIMATIONS_SPEED) * GetIO().DeltaTime;
    it_anim->second.Frame = ImLerp(it_anim->second.Frame, colFrame, k);
    it_anim->second.Fill  = ImLerp(it_anim->second.Fill,  colFill,  k);

    ImRect grab_bb;
    const bool value_changed = SliderBehavior(frame_bb, id, data_type, p_data, p_min, p_max, format, flags, &grab_bb);
    if (value_changed)
        MarkItemEdited(id);

    // Geometry
    const float x0 = frame_bb.Min.x;
    const float x1 = frame_bb.Max.x;
    const float cy = (frame_bb.Min.y + frame_bb.Max.y) * 0.5f;

    const float h_unfilled = IM_FLOOR(g.FontSize * 0.30f);
    const float h_filled   = h_unfilled + IM_FLOOR(ImMax(2.0f, g.FontSize * 0.08f));
    const float r          = style.FrameRounding;

    // Grab center and size
    const float grab_center = ImClamp((grab_bb.Min.x + grab_bb.Max.x) * 0.5f, x0, x1);
    const float base_grab_w = ImMax(style.GrabMinSize, h_filled * 1.15f);
    const float grab_w      = base_grab_w * 1.10f;
    const float grab_h      = (h_filled * 0.5f) + IM_FLOOR(g.FontSize * 0.10f);
    const float skew        = ImClamp(grab_w * 0.35f, 6.0f, 18.0f);

    // Draw
    RenderNavHighlight(frame_bb, id);

    // Unfilled (right) thin track
    {
        const ImVec2 a(ImMax(grab_center, x0), cy - h_unfilled * 0.5f);
        const ImVec2 b(x1,                      cy + h_unfilled * 0.5f);
        window->DrawList->AddRectFilled(a, b, GetColorU32(it_anim->second.Frame), r, ImDrawFlags_RoundCornersRight);
    }

    // Filled (left) thicker track
    {
        const ImVec2 a(x0,             cy - h_filled * 0.5f);
        const ImVec2 b(ImMax(grab_center, x0), cy + h_filled * 0.5f);
        window->DrawList->AddRectFilled(a, b, GetColorU32(it_anim->second.Fill), r, ImDrawFlags_RoundCornersLeft);
    }

    // Parallelogram grab — swapped edges, no outline, color = previous square (ImGuiCol_Text)
    if (x1 > x0)
    {
        const float gx0 = ImClamp(grab_center - grab_w * 0.5f, x0, x1);
        const float gx1 = ImClamp(grab_center + grab_w * 0.5f, x0, x1);
        const float top = cy - grab_h;
        const float bot = cy + grab_h;

        ImVec2 pts[4];
        // Swapped orientation: shift TOP to the RIGHT (opposite of before)
        //   (gx0 + skew, top) —— (gx1 + skew, top)
        //        |                    |
        //       (gx0, bot) ————  (gx1, bot)
        pts[0] = ImVec2(gx0,         bot);
        pts[1] = ImVec2(gx1,         bot);
        pts[2] = ImVec2(ImMin(gx1 + skew, x1 + skew), top);
        pts[3] = ImVec2(ImMin(gx0 + skew, x1 + skew), top);

        const ImU32 col_grab = GetColorU32(ImGuiCol_Text); // same color as the old square grab
        window->DrawList->AddConvexPolyFilled(pts, 4, col_grab);
        // No outline (removed)
    }

    // Value text + label
    char value_buf[64];
    const char* value_buf_end = value_buf + DataTypeFormatString(value_buf, IM_ARRAYSIZE(value_buf), data_type, p_data, format);

    if (has_label)
    {
        window->DrawList->AddText(total_bb.Min, GetColorU32(ImGuiCol_Text), label);
        const float val_w = CalcTextSize(value_buf, value_buf_end).x;
        window->DrawList->AddText(total_bb.Min + ImVec2(width - val_w, 0), GetColorU32(ImGuiCol_TextDisabled), value_buf);
    }

    return value_changed;
}


bool DRGui::SliderFloat(const char* label, float* v, float v_min, float v_max, const char* format, ImGuiSliderFlags flags)
{
    return SliderScalar(label, ImGuiDataType_Float, v, &v_min, &v_max, format, flags);
}

bool DRGui::SliderAngle(const char* label, float* v_rad, float v_degrees_min, float v_degrees_max, const char* format, ImGuiSliderFlags flags)
{
    if (format == NULL)
        format = "%.0f deg";
    float v_deg = (*v_rad) * 360.0f / (2 * IM_PI);
    bool value_changed = SliderFloat(label, &v_deg, v_degrees_min, v_degrees_max, format, flags);
    *v_rad = v_deg * (2 * IM_PI) / 360.0f;
    return value_changed;
}

bool DRGui::SliderInt(const char* label, int* v, int v_min, int v_max, const char* format, ImGuiSliderFlags flags)
{
    return SliderScalar(label, ImGuiDataType_S32, v, &v_min, &v_max, format, flags);
}

void DRGui::BeginChild(const char* str_id, const ImVec2& size)
{
    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;

    PushStyleVar(ImGuiStyleVar_WindowPadding, style.FramePadding);
    ImGui::BeginChild(str_id, size, style.WindowBorderSize > 0 ? ImGuiChildFlags_Borders : ImGuiChildFlags_AlwaysUseWindowPadding);
    PushStyleVar(ImGuiStyleVar_ItemSpacing, style.ItemInnerSpacing);
}

void DRGui::EndChild()
{
    PopStyleVar();
    ImGui::EndChild();
    PopStyleVar();
}

bool DRGui::InputTextIcon(ImTextureID icon_texture, const char* label, char* buf, size_t buf_size, ImGuiInputTextFlags flags)
{
    IM_ASSERT(!(flags & ImGuiInputTextFlags_Multiline)); // call InputTextMultiline()

    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;

    ImVec2 pos = GetCursorScreenPos();
    bool has_icon = icon_texture != 0;

    ImGui::BeginChild(label, ImVec2(CalcItemWidth(), GetFrameHeight()), ImGuiChildFlags_None, ImGuiWindowFlags_NoBackground);

    window->DrawList->AddRectFilled(pos, pos + GetWindowSize(), GetColorU32(ImGuiCol_FrameBg), style.FrameRounding);
    if (has_icon) {
        window->DrawList->AddImage(icon_texture, pos + style.FramePadding, pos + ImVec2(GetWindowHeight(), GetWindowHeight()) - style.FramePadding);
    }

    PushStyleColor(ImGuiCol_FrameBg, ImVec4(0, 0, 0, 0));
    PushStyleVar(ImGuiStyleVar_FrameBorderSize, 0);
    PushItemWidth(has_icon ? (GetWindowWidth() - GetFontSize() - style.FramePadding.x) : GetWindowWidth());
    if (has_icon) {
        SetCursorScreenPos(pos + ImVec2(GetFontSize() + style.FramePadding.x, 0));
    }
    bool input = InputTextEx(string("##" + string(label)).c_str(), NULL, buf, (int)buf_size, ImVec2(0, 0), flags);
    PopItemWidth();
    PopStyleVar();
    PopStyleColor();

    if (has_icon) {
        GetForegroundDrawList()->AddRectFilledMultiColor(pos + ImVec2(GetFontSize() + style.FramePadding.x, 0), pos + ImVec2(GetWindowHeight(), GetWindowHeight()), GetColorU32(ImGuiCol_FrameBg), GetColorU32(ImGuiCol_FrameBg, 0.0f), GetColorU32(ImGuiCol_FrameBg, 0.0f), GetColorU32(ImGuiCol_FrameBg));
    }

    if (!IsItemActive() && strlen(buf) == 0) {
        window->DrawList->AddText(pos + ImVec2(has_icon ? GetWindowHeight() : style.FramePadding.x, style.FramePadding.y), GetColorU32(ImGuiCol_TextDisabled), label);
    }

    ImGui::EndChild();

    return input;
}

bool DRGui::InputText(const char* label, const char* text, char* buf, size_t buf_size, float width, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void* user_data)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = CalcTextSize(label, NULL, true);
    const ImVec2 text_size = CalcTextSize(text, NULL, true);

    IM_ASSERT(!(flags & ImGuiInputTextFlags_Multiline)); // call InputTextMultiline()

    bool result = false;
    bool has_label = label_size.x > 0;

    const float w = CalcItemSize(ImVec2(width, 0), CalcItemWidth(), 0).x;

    BeginGroup();
    {
        if (has_label) {
            PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(style.ItemSpacing.x, style.ItemInnerSpacing.y));
            ImGui::Text("%s", label);
        }
        {
            ImVec2 pos = GetCursorScreenPos();
            PushItemWidth(w);
            {
                result |= InputTextEx(std::string("##" + std::string(label)).c_str(), NULL, buf, (int)buf_size, ImVec2(0, 0), flags, callback, user_data);
            }
            PopItemWidth();

            if (text_size.x > 0)
            {
                if (!ImGui::IsItemActive() && !strlen(buf)) {
                    ImGui::SetCursorScreenPos(pos + style.FramePadding);
                    ImGui::TextDisabled("%s", text);
                }
            }
        }
        if (has_label) {
            PopStyleVar();
        }
    }
    EndGroup();

    return result;
}

bool DRGui::InputTextStr(const char* label, const char* text, std::string* str, float width, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void* user_data)
{
    IM_ASSERT((flags & ImGuiInputTextFlags_CallbackResize) == 0);
    flags |= ImGuiInputTextFlags_CallbackResize;

    InputTextCallback_UserData cb_user_data;
    cb_user_data.Str = str;
    cb_user_data.ChainCallback = callback;
    cb_user_data.ChainCallbackUserData = user_data;
    return DRGui::InputText(label, text, (char*)str->c_str(), str->capacity() + 1, width, flags, InputTextCallback, &cb_user_data);
}

const char* GetStringByIndex(const char* multiString, size_t index) 
{
    if (!multiString) return nullptr;

    size_t currentIndex = 0;
    const char* ptr = multiString;

    while (*ptr) {
        if (currentIndex == index)
            return ptr;

        // Move to the next string
        ptr += std::strlen(ptr) + 1;
        currentIndex++;
    }

    // Index not found
    return nullptr;
}

size_t GetMultiStringItemCount(const char* multiString) 
{
    const char* ptr = multiString;
    size_t count = 0;

    while (*ptr) {
        ++count;
        ptr += std::strlen(ptr) + 1;
    }

    return count;
}

bool DRGui::Combo(const char* str_id, int* current_item, const char* items_separated_by_zeros)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems) return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(str_id);

    const float width  = CalcItemWidth();
    const float height = g.FontSize + style.CellPadding.y * 2;
    const ImVec2 pos   = window->DC.CursorPos;
    const ImVec2 size  = ImVec2(width, height);

    const ImRect bb(pos, pos + size);
    ItemSize(size, style.CellPadding.y);
    if (!ItemAdd(bb, id)) return false;

    // --- Clamp index to valid range ---
    const int items_count = (int)GetMultiStringItemCount(items_separated_by_zeros);
    if (*current_item < 0 || *current_item >= items_count)
        *current_item = 0;

    bool hovered, held;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held);
    const bool has_border = style.FrameBorderSize > 0;

    // Colors + anim (unchanged)
    ImVec4 colFrame = GetStyleColorVec4((held && hovered) ? ImGuiCol_FrameBgActive
                                : hovered ? ImGuiCol_FrameBgHovered : ImGuiCol_FrameBg);
    struct stColors_State { ImVec4 Frame; };
    static std::map<ImGuiID, stColors_State> anim;
    auto it_anim = anim.find(id);
    if (it_anim == anim.end()) it_anim = anim.emplace(id, stColors_State{colFrame}).first;
    it_anim->second.Frame = ImLerp(it_anim->second.Frame, colFrame,
                                   1.0f / DRGUI_ANIMATIONS_SPEED * GetIO().DeltaTime);

    RenderNavHighlight(bb, id);
    window->DrawList->AddRectFilled(bb.Min, bb.Max, GetColorU32(it_anim->second.Frame), style.FrameRounding);
    if (has_border)
        window->DrawList->AddRect(bb.Min, bb.Max, GetColorU32(ImGuiCol_Border), style.FrameRounding, 0, style.FrameBorderSize);

    // --- Safe preview fetch (no std::string from nullptr) ---
    const char* preview_cstr = GetStringByIndex(items_separated_by_zeros, (size_t)*current_item);
    if (!preview_cstr) preview_cstr = "*error item*";
    window->DrawList->AddText(pos + style.CellPadding, GetColorU32(ImGuiCol_TextDisabled), preview_cstr);

    if (pressed)
        OpenPopup(str_id);

    PushStyleVar(ImGuiStyleVar_WindowPadding, style.CellPadding);
    PushStyleVar(ImGuiStyleVar_ItemSpacing  , style.CellPadding);
    PushStyleVar(ImGuiStyleVar_FramePadding , style.CellPadding);
    PushStyleVar(ImGuiStyleVar_PopupRounding, style.FrameRounding);
    PushStyleVar(ImGuiStyleVar_PopupBorderSize, style.FrameBorderSize);
    if (BeginPopup(str_id, ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoBackground))
    {
        ImDrawList* pDrawList = GetForegroundDrawList();
        pDrawList->AddRectFilled(pos, pos + GetWindowSize(), GetColorU32(ImGuiCol_PopupBg), style.PopupRounding);

        SetWindowPos(pos, ImGuiCond_Always);

        for (int i = 0; i < items_count; ++i)
        {
            const char* item_cstr = GetStringByIndex(items_separated_by_zeros, (size_t)i);
            if (!item_cstr) item_cstr = "*error*";

            const bool is_selected = (i == *current_item);
            if (SelectableLabel(pDrawList, item_cstr, is_selected,
                                ImVec2(width - style.WindowPadding.x * 2, 0)))
            {
                *current_item = i;
                CloseCurrentPopup();
            }

            // --- This mirrors ImGui::Selectable behavior in combos ---
            if (is_selected)
                SetItemDefaultFocus();
        }

        EndPopup();
    }
    PopStyleVar(5);

    return pressed;
}


bool DRGui::Combo(const char* str_id, int* current_item, const char* items_separated_by_zeros, float width)
{
    PushItemWidth(width <= 0 ? CalcItemWidth() : width);
    bool result = Combo(str_id, current_item, items_separated_by_zeros);
    PopItemWidth();
    return result;
}

bool DRGui::MultiCombo(const char* str_id, std::vector<int>* selected, std::vector<const char*> items)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(str_id);

    const float width = CalcItemWidth();
    const float height = g.FontSize + style.CellPadding.y * 2;

    ImVec2 pos = window->DC.CursorPos;
    ImVec2 size = ImVec2(width, height);

    const ImRect bb(pos, pos + size);
    ItemSize(size);
    if (!ItemAdd(bb, id))
        return false;

    bool hovered, held, popup_open = false;
    bool pressed = ButtonBehavior(bb, id, &hovered, &held);
    if (pressed) popup_open = !popup_open;

    std::string preview = "";

    int stop_at = -1;
    for (int i = 0; i < items.size(); i++)
    {
        if ((*selected)[i] == 1)
        {
            stop_at = i;
        }
    }

    for (int i = 0; i < items.size(); i++)
    {
        if ((*selected)[i] == 1)
        {
            preview += items[i] + std::string(i == stop_at ? "" : ", ");
        }
    }

    // Colors
    ImU32 bg_col = GetColorU32(hovered ? ImGuiCol_FrameBgHovered : ImGuiCol_FrameBg);
    // ImU32 text_col = GetColorU32((popup_open || hovered) ? ImGuiCol_Text : ImGuiCol_TextDisabled);

    // Render
    RenderNavHighlight(bb, id);

    window->DrawList->AddRectFilled(bb.Min, bb.Max, bg_col, style.FrameRounding);

    window->DrawList->PushClipRect(pos, pos + ImVec2(size.x - size.y + style.CellPadding.x, size.y), true);
    window->DrawList->AddText(pos + style.CellPadding, GetColorU32(ImGuiCol_TextDisabled), preview.length() == 0 ? "none" : preview.c_str());
    window->DrawList->PopClipRect();

    window->DrawList->AddRectFilledMultiColor(pos + ImVec2(size.x - size.y - g.FontSize, 0), pos + ImVec2(size.x - size.y + style.CellPadding.x, size.y), GetColorU32(bg_col, 0.0f), bg_col, bg_col, GetColorU32(bg_col, 0.0f));

    if (style.FrameBorderSize > 0)
    {
        window->DrawList->AddRect(bb.Min, bb.Max, GetColorU32(ImGuiCol_SeparatorActive), style.FrameRounding, 0, style.FrameBorderSize);
    }

    if (popup_open)
    {
        OpenPopup(std::string("MultiCombo_" + std::string(str_id)).c_str());
    }

    PushStyleVar(ImGuiStyleVar_WindowPadding, style.CellPadding);
    PushStyleVar(ImGuiStyleVar_ItemSpacing, style.CellPadding);
    PushStyleVar(ImGuiStyleVar_FramePadding, style.CellPadding);
    PushStyleVar(ImGuiStyleVar_PopupRounding, style.FrameRounding);
    PushStyleVar(ImGuiStyleVar_PopupBorderSize, style.FrameBorderSize);
    if (BeginPopup(std::string("MultiCombo_" + std::string(str_id)).c_str(), ImGuiWindowFlags_NoMove | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoBackground))
    {
        SetWindowPos(pos);
        SetWindowSize(ImVec2(size.x, 0));

        ImDrawList* pDrawList = GetForegroundDrawList();
        pDrawList->AddRectFilled(pos, pos + GetWindowSize(), GetColorU32(ImGuiCol_PopupBg), style.PopupRounding);

        for (int i = 0; i < items.size(); i++)
        {
            if (DRGui::SelectableLabel(pDrawList, items[i], (*selected)[i] == 1, ImVec2(size.x - style.WindowPadding.x * 2, 0)))
            {
                (*selected)[i] = (*selected)[i] == 1 ? 0 : 1;
            }
        }

        ImGui::EndPopup();
    }
    PopStyleVar(5);

    return pressed;
}

bool DRGui::MultiCombo(const char* str_id, std::vector<int>* selected, std::vector<const char*> items, float width)
{
    PushItemWidth(width <= 0 ? CalcItemWidth() : width);
    bool result = MultiCombo(str_id, selected, items);
    PopItemWidth();
    return result;
}

#include "Fonts.h"

bool DRGui::ArrowSelector(const char* str_id, int* current_item, const char* items_separated_by_zeros, const ImVec2& size_arg, bool boxed)
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems)
        return false;

    IM_ASSERT(current_item != nullptr);
    IM_ASSERT(items_separated_by_zeros != nullptr);

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(str_id);

    const float height = ImMax(g.FontSize + style.FramePadding.y * 2.0f, 1.0f);
    const float width  = (size_arg.x > 0.0f) ? size_arg.x : CalcItemWidth();
    const ImVec2 pos   = window->DC.CursorPos;
    const ImVec2 size  = ImVec2(width, height);

    const ImRect bb(pos, pos + size);
    ItemSize(size, style.FramePadding.y);
    if (!ItemAdd(bb, id))
        return false;

    const bool hovered = IsMouseHoveringRect(bb.Min, bb.Max);

    const ImU32 col_bg     = GetColorU32(hovered ? ImGuiCol_FrameBgHovered : ImGuiCol_FrameBg);
    const ImU32 col_bd     = GetColorU32(ImGuiCol_Border);
    const ImU32 col_tx     = GetColorU32(ImGuiCol_Text);
    const ImU32 col_tx_dis = GetColorU32(ImGuiCol_TextDisabled);

    if (boxed)
    {
        window->DrawList->AddRectFilled(bb.Min, bb.Max, col_bg, style.FrameRounding);
        if (style.FrameBorderSize > 0.0f)
            window->DrawList->AddRect(bb.Min, bb.Max, col_bd, style.FrameRounding, 0, style.FrameBorderSize);
    }
    RenderNavHighlight(bb, id);

    const float arrow_w  = height;
    const float inner_pad = style.ItemInnerSpacing.x;

    const ImRect left_bb (bb.Min,                         ImVec2(bb.Min.x + arrow_w, bb.Max.y));
    const ImRect right_bb(ImVec2(bb.Max.x - arrow_w, bb.Min.y), bb.Max);
    const ImRect text_bb (ImVec2(left_bb.Max.x + inner_pad, bb.Min.y),
                          ImVec2(right_bb.Min.x - inner_pad, bb.Max.y));

    ImRect left_hit  = left_bb;  left_hit.Expand(style.TouchExtraPadding);
    ImRect right_hit = right_bb; right_hit.Expand(style.TouchExtraPadding);

    const int items_count = GetMultiStringItemCount(items_separated_by_zeros);
    if (*current_item < 0) *current_item = 0;
    if (items_count > 0 && *current_item >= items_count) *current_item = items_count - 1;

    const std::string current_label = (items_count > 0)
        ? GetStringByIndex(items_separated_by_zeros, *current_item)
        : std::string();

    const ImGuiID id_left  = window->GetID((std::string(str_id) + "##left").c_str());
    const ImGuiID id_right = window->GetID((std::string(str_id) + "##right").c_str());

    ImGuiButtonFlags bflags = ImGuiButtonFlags_MouseButtonLeft;

    bool l_hovered=false, l_held=false;
    bool r_hovered=false, r_held=false;

    bool l_pressed = ButtonBehavior(left_hit,  id_left,  &l_hovered, &l_held, bflags);
    bool r_pressed = ButtonBehavior(right_hit, id_right, &r_hovered, &r_held, bflags);

    if (!l_pressed && items_count > 0 && IsMouseReleased(ImGuiMouseButton_Left) && left_hit.Contains(g.IO.MousePos))
        l_pressed = true;
    if (!r_pressed && items_count > 0 && IsMouseReleased(ImGuiMouseButton_Left) && right_hit.Contains(g.IO.MousePos))
        r_pressed = true;

    bool changed = false;
    if (items_count > 0)
    {
        int idx = *current_item;
        if (l_pressed) { idx = (idx - 1 + items_count) % items_count; changed = true; }
        if (r_pressed) { idx = (idx + 1) % items_count;               changed = true; }

        if (hovered && g.IO.MouseWheel != 0.0f)
        {
            idx = (g.IO.MouseWheel > 0.0f)
                ? (idx - 1 + items_count) % items_count
                : (idx + 1) % items_count;
            changed = true;
        }

        if (changed)
        {
            *current_item = idx;
            MarkItemEdited(id);
        }
    }

#ifdef ICON_FA_ANGLE_LEFT
    const char* left_txt  = ICON_FA_ANGLE_LEFT;
    const char* right_txt = ICON_FA_ANGLE_RIGHT;
#else
    const char* left_txt  = "<";
    const char* right_txt = ">";
#endif

    auto DrawCenteredText = [&](const ImRect& r, const char* txt, ImU32 col)
    {
        const ImVec2 ts = CalcTextSize(txt, nullptr, true);
        const ImVec2 cp = ImVec2(r.Min.x + (r.GetWidth()  - ts.x) * 0.5f,
                                 r.Min.y + (r.GetHeight() - ts.y) * 0.5f);
        window->DrawList->AddText(cp, col, txt);
    };

    const ImU32 col_arrow_l = GetColorU32(l_hovered ? ImGuiCol_Text : ImGuiCol_TextDisabled);
    const ImU32 col_arrow_r = GetColorU32(r_hovered ? ImGuiCol_Text : ImGuiCol_TextDisabled);

    DrawCenteredText(left_bb,  left_txt,  items_count > 0 ? col_arrow_l : col_tx_dis);
    DrawCenteredText(right_bb, right_txt, items_count > 0 ? col_arrow_r : col_tx_dis);

    if (!current_label.empty())
    {
        const ImVec2 ts = CalcTextSize(current_label.c_str(), nullptr, true);
        ImVec2 tp = ImVec2(text_bb.Min.x + (text_bb.GetWidth() - ts.x) * 0.5f,
                           text_bb.Min.y + (text_bb.GetHeight() - ts.y) * 0.5f);
        window->DrawList->PushClipRect(text_bb.Min, text_bb.Max, true);
        window->DrawList->AddText(tp, col_tx, current_label.c_str());
        window->DrawList->PopClipRect();
    }
    else
    {
        DrawCenteredText(text_bb, "*no items*", col_tx_dis);
    }

    if (items_count > 0 && hovered && !g.IO.WantTextInput)
    {
        if (IsKeyPressed(ImGuiKey_LeftArrow, false))
        {
            *current_item = (*current_item - 1 + items_count) % items_count;
            changed = true; MarkItemEdited(id);
        }
        if (IsKeyPressed(ImGuiKey_RightArrow, false))
        {
            *current_item = (*current_item + 1) % items_count;
            changed = true; MarkItemEdited(id);
        }
    }

    return changed;
}


static inline void DrawHexagonByHeight(ImDrawList* dl, const ImRect& r,
                                       float target_h, ImU32 fill_col,
                                       float outline_thickness, ImU32 outline_col,
                                       float inset = 0.0f)
{
    if (target_h <= 0.f) return;
    const ImVec2 c = ImVec2((r.Min.x + r.Max.x) * 0.5f, (r.Min.y + r.Max.y) * 0.5f);

    // Pointy-top: vertex at top. For pointy-top, height = 2*R  =>  R = target_h/2.
    float R = target_h * 0.65f - inset; // 0.5f
    if (R <= 0.f) return;

    ImVec2 pts[6];
    // const float a0 = IM_PI * 0.5f;
    const float step = IM_PI / 3.0f;
    for (int i = 0; i < 6; ++i)
    {
        const float ang = step * i; // + a0
        pts[i] = ImVec2(c.x + R * cosf(ang), c.y + R * sinf(ang));
    }

    dl->AddConvexPolyFilled(pts, 6, fill_col);
   // if (outline_thickness > 0.0f)
   //     dl->AddPolyline(pts, 6, outline_col, true, outline_thickness);
}

bool DRGui::ColorEdit4(const char* str_id, float col[4])
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems) return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;

    // Visible label (strip "##...")
    std::string label_full = str_id;
    size_t hashpos = label_full.find("##");
    std::string label_draw = (hashpos != std::string::npos) ? label_full.substr(0, hashpos) : label_full;

    ImGui::PushID(str_id);
    const ImGuiID id = window->GetID("##hex_color4");
    const ImVec2 label_size = ImGui::CalcTextSize(label_draw.c_str(), nullptr, true);

    // === Geometry matching CheckBox ===
    const float square_sz = ImGui::GetFontSize() + style.CellPadding.y * 2.0f; // row height & icon height
    const ImVec2 pos = window->DC.CursorPos;
    const ImRect total_bb(
        pos,
        pos + ImVec2(
            square_sz + (label_size.x > 0.0f ? style.ItemInnerSpacing.x + label_size.x : 0.0f),
            label_size.y + style.CellPadding.y * 2.0f
        )
    );
    ImGui::ItemSize(total_bb, style.CellPadding.y);
    if (!ImGui::ItemAdd(total_bb, id)) { ImGui::PopID(); return false; }

    const ImRect hex_bb(pos, pos + ImVec2(square_sz, square_sz)); // layout rect (no box drawn)
    const ImVec2 label_pos = ImVec2(hex_bb.Max.x + style.ItemInnerSpacing.x,
                                    hex_bb.Min.y + style.CellPadding.y);

    // Interaction: whole row clickable (like CheckBox)
    bool hovered = false, held = false;
    bool pressed = ImGui::ButtonBehavior(total_bb, id, &hovered, &held);

    // Optional nav highlight (keeps keyboard/focus behavior)
    ImGui::RenderNavHighlight(total_bb, id);

    // Hex preview (fills the role of the old box); height == square_sz
    const ImVec4 col_v4(col[0], col[1], col[2], col[3]);
    const ImU32 fill_u32 = ImGui::ColorConvertFloat4ToU32(col_v4);
    const ImU32 border_u32 = ImGui::GetColorU32(ImGuiCol_Border);
    const float outline_thickness = style.FrameBorderSize;
    const float inset = outline_thickness + 1.0f; // avoid edge clipping
    DrawHexagonByHeight(window->DrawList, hex_bb, square_sz, fill_u32, outline_thickness, border_u32, inset);

    // Label (aligned exactly like CheckBox)
    if (!label_draw.empty())
        ImGui::RenderText(label_pos, label_draw.c_str());

    // Popup
    if (pressed)
        ImGui::OpenPopup("##picker4");

    // Make popup compact (only on appear so user can resize later)
    ImGui::SetNextWindowSize(ImVec2(g.FontSize * 16.0f, 0.0f), ImGuiCond_Appearing);

    bool changed = false;
    if (ImGui::BeginPopup("##picker4"))
    {
        // Smaller padding helps too
        ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(style.FramePadding.x, style.FramePadding.y));

        ImGuiColorEditFlags flags =
              ImGuiColorEditFlags_PickerHueBar      // compact vs wheel
            | ImGuiColorEditFlags_NoSidePreview     // remove big preview pane
            | ImGuiColorEditFlags_NoSmallPreview
            | ImGuiColorEditFlags_AlphaBar
            | ImGuiColorEditFlags_AlphaPreview
            | ImGuiColorEditFlags_NoInputs
            | ImGuiColorEditFlags_NoTooltip
            | ImGuiColorEditFlags_NoOptions
            | ImGuiColorEditFlags_NoLabel;

        // Let the picker handle MarkItemEdited internally.
        changed |= ImGui::ColorPicker4("##picker", col, flags);

        ImGui::PopStyleVar();
        ImGui::EndPopup();
    }

    // NO: ImGui::MarkItemEdited(id);  // ← remove this line
    ImGui::PopID();
    return pressed || changed;
}

bool DRGui::ColorEdit3(const char* str_id, float col[3])
{
    ImGuiWindow* window = GetCurrentWindow();
    window = nullptr;
    
    if (window->SkipItems) return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;

    // Visible label (strip "##...")
    std::string label_full = str_id;
    size_t hashpos = label_full.find("##");
    std::string label_draw = (hashpos != std::string::npos) ? label_full.substr(0, hashpos) : label_full;

    ImGui::PushID(str_id);
    const ImGuiID id = window->GetID("##hex_color3");
    const ImVec2 label_size = ImGui::CalcTextSize(label_draw.c_str(), nullptr, true);

    // === Geometry matching CheckBox ===
    const float square_sz = ImGui::GetFontSize() + style.CellPadding.y * 2.0f;
    const ImVec2 pos = window->DC.CursorPos;
    const ImRect total_bb(
        pos,
        pos + ImVec2(
            square_sz + (label_size.x > 0.0f ? style.ItemInnerSpacing.x + label_size.x : 0.0f),
            label_size.y + style.CellPadding.y * 2.0f
        )
    );
    ImGui::ItemSize(total_bb, style.CellPadding.y);
    if (!ImGui::ItemAdd(total_bb, id)) { ImGui::PopID(); return false; }

    const ImRect hex_bb(pos, pos + ImVec2(square_sz, square_sz));
    const ImVec2 label_pos = ImVec2(hex_bb.Max.x + style.ItemInnerSpacing.x,
                                    hex_bb.Min.y + style.CellPadding.y);

    // Interaction
    bool hovered = false, held = false;
    bool pressed = ImGui::ButtonBehavior(total_bb, id, &hovered, &held);
    ImGui::RenderNavHighlight(total_bb, id);

    // Hex preview (height == square_sz)
    const ImVec4 col_v4(col[0], col[1], col[2], 1.0f);
    const ImU32 fill_u32 = ImGui::ColorConvertFloat4ToU32(col_v4);
    const ImU32 border_u32 = ImGui::GetColorU32(ImGuiCol_Border);
    const float outline_thickness = style.FrameBorderSize;
    const float inset = outline_thickness + 1.0f;
    DrawHexagonByHeight(window->DrawList, hex_bb, square_sz, fill_u32, outline_thickness, border_u32, inset);

    // Label
    if (!label_draw.empty())
        ImGui::RenderText(label_pos, label_draw.c_str());

    // Popup
    if (pressed)
        ImGui::OpenPopup("##picker3");

    ImGui::SetNextWindowSize(ImVec2(g.FontSize * 16.0f, 0.0f), ImGuiCond_Appearing);

    bool changed = false;
    if (ImGui::BeginPopup("##picker3"))
    {
        ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(style.FramePadding.x, style.FramePadding.y));

        ImGuiColorEditFlags flags =
              ImGuiColorEditFlags_PickerHueBar
            | ImGuiColorEditFlags_NoSidePreview
            | ImGuiColorEditFlags_NoSmallPreview
            | ImGuiColorEditFlags_NoInputs
            | ImGuiColorEditFlags_NoTooltip
            | ImGuiColorEditFlags_NoOptions
            | ImGuiColorEditFlags_NoLabel;

        changed |= ImGui::ColorPicker3("##picker", col, flags);

        ImGui::PopStyleVar();
        ImGui::EndPopup();
    }

    // NO: ImGui::MarkItemEdited(id);
    ImGui::PopID();
    return pressed || changed;
}

float DRGui::GetCheckBoxSize()
{
    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;

    return g.FontSize + style.CellPadding.y * 2.0f;
}
