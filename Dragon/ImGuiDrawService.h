//
//  ImGuiDrawService.hpp
//  Sishen
//
//  Created by Project Contributors on 18.07.25.
//
#define IMGUI_DEFINE_MATH_OPERATORS


#include "imgui.h"
#include "imgui_internal.h"

namespace ImGui
{
    namespace Color
    {
        inline const ImColor Red        = ImColor(255, 0, 0);         // Pure Red
        inline const ImColor Blue       = ImColor(0, 0, 255);        // Pure Blue
        inline const ImColor Green      = ImColor(0, 255, 0);       // Pure Green
        inline const ImColor Cyan       = ImColor(0, 255, 255);      // Pure Cyan
        inline const ImColor Yellow     = ImColor(255, 255, 0);    // Pure Yellow
        inline const ImColor Magenta    = ImColor(255, 0, 255);   // Pure Magenta
        inline const ImColor White      = ImColor(255, 255, 255);   // Pure White
        inline const ImColor Black      = ImColor(0, 0, 0);         // Pure Black
        inline const ImColor Orange     = ImColor(255, 165, 0);    // Orange
        inline const ImColor Purple     = ImColor(128, 0, 128);    // Purple
        inline const ImColor Gray       = ImColor(128, 128, 128);    // Gray
    }
}


class IImGuiDrawService
{
public:
    
    IImGuiDrawService() : DrawList(nullptr) {}
    IImGuiDrawService(ImDrawList* _DrawList) : DrawList(_DrawList) {}
    
    static IImGuiDrawService* Get(ImDrawList* InDrawList)
    {
        static IImGuiDrawService s_DrawService;
        s_DrawService.SetDrawList(InDrawList);
        return &s_DrawService;
    }
    
public:
    
    void SetDrawList(ImDrawList* InDrawList)
    {
        DrawList = InDrawList;
    }
    
public:
    void DrawLine(ImVec2 PositionA, ImVec2 PositionB, float Thickness, const ImColor& Color)
    {
        DrawList->AddLine(PositionA, PositionB, Color, Thickness);
    }

    void DrawCircle(ImVec2 Center, float Radius, int Segments, const ImColor& Color)
    {
        DrawList->AddCircle(Center, Radius, Color, Segments, 1.0f);
    }

    void DrawCircleFilled(ImVec2 Center, float Radius, int Segments, const ImColor& Color)
    {
        DrawList->AddCircleFilled(Center, Radius, Color, Segments);
    }

    void DrawText(const std::string& TheText, ImVec2 Position, const ImColor& Color, float Size, bool Center = true, bool Outline = true)
    {
        const char* TextBegin = TheText.data();
        const char* TextEnd   = TextBegin + TheText.size();

        if ( Center )
            Position.x -= Font->CalcTextSizeA(Size, FLT_MAX, 0.0f, TextBegin, TextEnd).x * 0.5f;

        constexpr float OutlineSize = 1.0f;
        if ( Outline )
        {
            const ImColor& OutlineColor = ImGui::Color::Black;

            DrawList->AddText(Font, Size, ImVec2(Position.x + OutlineSize, Position.y + OutlineSize), OutlineColor, TextBegin, TextEnd);
            DrawList->AddText(Font, Size, ImVec2(Position.x - OutlineSize, Position.y - OutlineSize), OutlineColor, TextBegin, TextEnd);
            DrawList->AddText(Font, Size, ImVec2(Position.x + OutlineSize, Position.y - OutlineSize), OutlineColor, TextBegin, TextEnd);
            DrawList->AddText(Font, Size, ImVec2(Position.x - OutlineSize, Position.y + OutlineSize), OutlineColor, TextBegin, TextEnd);
        }

        DrawList->AddText(Font, Size, Position, Color, TextBegin, TextEnd);
    }

    void DrawRect(ImVec2 Position, ImVec2 Size, const ImColor& Color)
    {
        DrawList->AddRect(Position, ImVec2(Position.x + Size.x, Position.y + Size.y), Color, 0, 0, 1.0f);
    }

    void DrawRectFilled(ImVec2 Position, ImVec2 Size, const ImColor& Color)
    {
        DrawList->AddRectFilled(Position, ImVec2(Position.x + Size.x, Position.y + Size.y), Color, 0, 0);
    }

    void DrawImage(ImTextureID Texture, ImVec2 Pos, ImVec2 Size, bool Center = true)
    {
        if (Center)
        {
            Pos.x -= Size.x * 0.5f;
            Pos.y -= Size.y * 0.5f;
        }
        DrawList->AddImage(Texture, Pos, ImVec2(Pos.x + Size.x, Pos.y + Size.y), ImVec2(0.0f, 0.0f), ImVec2(1.0f, 1.0f));
    }
    
    void DrawHorizontalBar(const ImVec2& ScreenPosition, const ImVec2& SizeXY, const ImColor& Color, float HealthPercentage)
    {
        ImVec2 CenteredPos(ScreenPosition.x - SizeXY.x * 0.5f, ScreenPosition.y );

        DrawRectFilled(CenteredPos, SizeXY, ImGui::Color::Black);

        ImVec2 HealthBarSize(SizeXY.x * HealthPercentage, SizeXY.y);
        DrawRectFilled(CenteredPos, HealthBarSize, Color);
    }

    
private:
    ImDrawList* DrawList;
};
