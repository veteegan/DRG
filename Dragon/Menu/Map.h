#ifndef MAP_H
#define MAP_H

#include "../Utilities/Singleton.h"
#include "../Utilities/Variables.h"
#include "../Utilities/Macros.h"

#include "../ImGui/imgui.h"
#include "../ImGui/imgui_internal.h"

#include <unordered_map>

enum class MapType : uint8_t
{
    Maps,
    Island,
    Scorched,
    Aberration,
    Ragnarok,
    Extinction,
    Genesis,
    Genesis2
};

class Map : public SingletonDestroyProbe<Map>
{
public:
    friend class SingletonDestroyProbe<Map>;
    
    void InitFloatingObject(MapType _Map, float xCoord, float yCoord, float rotation);

    ImVec2 GetMapPosition() const { return windowPos; }
    
    bool IsVisible() const { return isVisible; }
    
    ImVec2 GetWidgetPosition() const
    {
        return ImVec2(
            windowPos.x + Set.MapSetting.MapSize - widgetSize - widgetPadding.x,
            windowPos.y + widgetPadding.y
        );
    }
    
    float GetWidgetSize() const { return widgetSize; }

protected:
    Map();
    ~Map();

private:

    Settings& Set;

    /*----------Class Settings-----------*/
    
    ImVec2 dragStartPos;
    ImVec2 windowStartPos;
    
    bool isDragging;
    
    ImVec2 windowPos;
    
    ImGuiIO& io;
    ImDrawList* drawList;

    MapType CurrentMap = MapType::Maps;
    
    /*----------Toggle Widget-----------*/
    
    bool isVisible = true;
    const float widgetSize = 27.0f;
    const ImVec2 widgetPadding = ImVec2(-10.0f, -10.0f);
    
private:
    /*----------Textures-----------*/

    UIImage* MapImage = nil;
    std::unordered_map<MapType, ImTextureID> MapTextures;
    
    /*----------CONSTANTS-----------*/
    
    const float MIN_COORD = 7.4f;
    const float MAX_COORD = 92.8f;
    
    const float MIN_DAY_TIME = 0.0f;
    const float MID_DAY_TIME = 12.0f;
    const float MAX_DAY_TIME = 24.0f;
    
    const ImGuiWindowFlags window_flags = ImGuiWindowFlags_NoTitleBar |
                                ImGuiWindowFlags_NoResize |
                                ImGuiWindowFlags_NoMove |
                                ImGuiWindowFlags_NoScrollbar |
                                ImGuiWindowFlags_NoScrollWithMouse |
                                ImGuiWindowFlags_NoCollapse;

    
private:
    /*----------Functions-----------*/
    
    void InitializeImage(NSString* MapBase64, ImTextureID& MapTexture);
    
    ImColor DayNightMode(float DayTime);
    
    void DrawTriangle(const ImVec2 &position, float angleRadians, const ImVec4 &color);
    
    void ComputeUVs(float centerX, float centerY, float zoom, ImVec2 &uvMin, ImVec2 &uvMax);
    
    void MapRender(const ImVec2 &posEnd, float &centerX, float &centerY, float &Yaw);
    
    void RenderToggleWidget(ImVec2 mousePos);
    
    // UIImage *CropToStaticSize(UIImage *image, CGFloat centerX, CGFloat centerY, BOOL *reachedBoundaryX, BOOL *reachedBoundaryY);
    
    // void UpdateImageTexture(UIImage *image);

    // void CalculateCenterLimits(UIImage *image, CGFloat cropWidth, CGFloat cropHeight, CGFloat *minCenterX, CGFloat *maxCenterX, CGFloat *minCenterY, CGFloat *maxCenterY);
};

#endif // MAP_H
