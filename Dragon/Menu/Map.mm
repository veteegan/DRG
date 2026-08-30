
#include "Map.h"

#include "MapBase64.h"

Map::Map()
    : Set(Settings::GetInstance()), dragStartPos(0, 0), windowStartPos(0, 0),
      isDragging(false), windowPos(ImVec2(SCREEN_WIDTH / 8, 30)),
      io(ImGui::GetIO())
{
    InitializeImage(TheIsland, MapTextures[MapType::Island]);
    // InitializeImage(Scorched, MapTextures[MapType::Scorched]);
    // InitializeImage(Aberration, MapTextures[MapType::Aberration]);
}

Map::~Map()
{
    for (auto &pair : MapTextures)
    {
        if (pair.second)
        {
            CFRelease((CFTypeRef)(pair.second));
            pair.second = 0;
        }
    }
    MapTextures.clear();
}

#include "Fonts.h"

void Map::RenderToggleWidget(ImVec2 mousePos)
{
    ImVec2 widgetPos = ImVec2(
        windowPos.x + Set.MapSetting.MapSize - widgetSize - widgetPadding.x,
        windowPos.y + widgetPadding.y
    );

    ImRect widgetRect(widgetPos, ImVec2(widgetPos.x + widgetSize, widgetPos.y + widgetSize));

    bool isHovered = widgetRect.Contains(mousePos);

    bool widgetClicked = false;
    if (ImGui::IsMouseReleased(ImGuiMouseButton_Left) && isHovered)
    {
        widgetClicked = true;
    }

    if (widgetClicked)
    {
        isVisible = !isVisible;
    }

    drawList->AddRectFilled(widgetRect.Min, widgetRect.Max, IM_COL32(50, 50, 50, 200), 5.0f);

    const char* widgetText = isVisible ? " " ICON_FA_EYE_SLASH : " " ICON_FA_EYE;

    ImVec2 textSize = ImGui::CalcTextSize(widgetText);

    ImVec2 textPos = ImVec2(
        widgetPos.x + (widgetSize - textSize.x) / 2.0f,
        widgetPos.y + (widgetSize - textSize.y) / 2.0f
    );

    drawList->AddText(textPos, Set.MapSetting.MapColor, widgetText);

    if (isHovered)
    {
        ImColor hoverColor = ImColor(100, 100, 100, 150);
        drawList->AddRectFilled(widgetRect.Min, widgetRect.Max, IM_COL32(100, 100, 100, 150), 5.0f);
        drawList->AddText(textPos, Set.MapSetting.MapColor, widgetText);
    }
}


void Map::InitFloatingObject(MapType _Map, float xCoord, float yCoord, float rotation)
{
    if (_Map == MapType::Maps)
        return;

    if (_Map != CurrentMap) {
        CurrentMap = _Map;
    }
    
    drawList = ImGui::GetForegroundDrawList();

    ImVec2 mousePos = io.MousePos;
    
    if (!isVisible)
    {
        RenderToggleWidget(mousePos);
        return;
    }

    bool mouseDown = ImGui::IsMouseDown(ImGuiMouseButton_Left);
    bool mouseClicked = ImGui::IsMouseClicked(ImGuiMouseButton_Left);
    bool mouseReleased = ImGui::IsMouseReleased(ImGuiMouseButton_Left);

    ImRect mapRect(windowPos, ImVec2(windowPos.x + Set.MapSetting.MapSize, windowPos.y + Set.MapSetting.MapSize));

    if (mouseClicked && mapRect.Contains(mousePos))
    {
        isDragging = true;
        dragStartPos = mousePos;
        windowStartPos = windowPos;
    }

    if (isDragging && mouseDown)
    {
        ImVec2 delta = ImVec2(mousePos.x - dragStartPos.x, mousePos.y - dragStartPos.y);
        windowPos = ImVec2(windowStartPos.x + delta.x, windowStartPos.y + delta.y);

        // bound the map, to prevent it going off screen
        windowPos.x = std::max(0.0f, std::min(windowPos.x, (float)(SCREEN_WIDTH - Set.MapSetting.MapSize)));
        windowPos.y = std::max(0.0f, std::min(windowPos.y, (float)(SCREEN_HEIGHT - Set.MapSetting.MapSize)));
    }

    if (isDragging && mouseReleased)
    {
        isDragging = false;
    }
    
    ImVec2 mapCenter = ImVec2(windowPos.x + Set.MapSetting.MapSize / 2, windowPos.y + Set.MapSetting.MapSize / 2);

    MapRender(ImVec2(windowPos.x + Set.MapSetting.MapSize, windowPos.y + Set.MapSetting.MapSize), xCoord, yCoord, rotation);
    
    drawList->AddRect(windowPos, ImVec2(windowPos.x + Set.MapSetting.MapSize, windowPos.y + Set.MapSetting.MapSize), Set.MapSetting.MapColor);

    float fontSize = 15.0f;

    drawList->AddText(ImVec2(mapCenter.x - 3, windowPos.y - fontSize - 2), Set.MapSetting.MapColor, "N");
    drawList->AddText(ImVec2(mapCenter.x - 3, windowPos.y + Set.MapSetting.MapSize + 2), Set.MapSetting.MapColor, "S");
    drawList->AddText(ImVec2(windowPos.x - fontSize - 2, mapCenter.y - 4), Set.MapSetting.MapColor, "W");
    drawList->AddText(ImVec2(windowPos.x + Set.MapSetting.MapSize + 6, mapCenter.y - 4), Set.MapSetting.MapColor, "E");
    
    RenderToggleWidget(mousePos);
}

void Map::InitializeImage(NSString* MapBase64, ImTextureID& MapTexture)
{
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:MapBase64
                                                           options:NSDataBase64DecodingIgnoreUnknownCharacters];
    MapImage = [UIImage imageWithData:imageData];

    if (MapImage)
    {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
        
        NSDictionary * const textureLoaderOptions = @{
            MTKTextureLoaderOptionSRGB : @NO,
            MTKTextureLoaderOptionTextureUsage : @(MTLTextureUsageShaderRead),
            MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
        };
        
        NSError *error = nil;
        id<MTLTexture> texture = [textureLoader newTextureWithCGImage:MapImage.CGImage
                                                               options:textureLoaderOptions
                                                                 error:&error];
        if (texture && !error)
        {
            MapTexture = (ImTextureID)CFBridgingRetain(texture);
        }
    }
}

void Map::ComputeUVs(float centerX, float centerY, float zoom, ImVec2 &uvMin, ImVec2 &uvMax)
{
    float normalizedCenterX = (centerX - MIN_COORD) / (MAX_COORD - MIN_COORD);
    float normalizedCenterY = (centerY - MIN_COORD) / (MAX_COORD - MIN_COORD);
    
    float halfSize = 0.5f / zoom;
    
    float uMin = normalizedCenterX - halfSize;
    float uMax = normalizedCenterX + halfSize;
    float vMin = normalizedCenterY - halfSize;
    float vMax = normalizedCenterY + halfSize;
    
    if (uMin < 0.0f) { uMax -= (uMin); uMin = 0.0f; }
    if (uMax > 1.0f) { uMin -= (uMax - 1.0f); uMax = 1.0f; }
    if (vMin < 0.0f) { vMax -= (vMin); vMin = 0.0f; }
    if (vMax > 1.0f) { vMin -= (vMax - 1.0f); vMax = 1.0f; }
    
    uMin = std::max(uMin, 0.0f);
    uMax = std::min(uMax, 1.0f);
    vMin = std::max(vMin, 0.0f);
    vMax = std::min(vMax, 1.0f);

    uvMin = ImVec2(uMin, vMin);
    uvMax = ImVec2(uMax, vMax);
}

void Map::MapRender(const ImVec2 &posEnd, float &centerX, float &centerY, float &Yaw)
{
    ImTextureID ActiveTexture = MapTextures[CurrentMap];
    if (!ActiveTexture) return;
 
    centerX = fmaxf(MIN_COORD, fminf(MAX_COORD, centerX));
    centerY = fmaxf(MIN_COORD, fminf(MAX_COORD, centerY));
    
    ImColor finalColor = (Set.MapSetting.bDayTimeMode)
        ? DayNightMode(Set.MapSetting.fDayTime)
    :  ImColor(1.0f, 1.0f, 1.0f, Set.MapSetting.MapColor.Value.w);

    ImVec2 uvMin, uvMax;
    ComputeUVs(centerX, centerY, (float)Set.MapSetting.MapZoom, uvMin, uvMax);
    
    drawList->AddImage(
        ActiveTexture,
        windowPos,
        posEnd,
        uvMin,
        uvMax,
        finalColor
    );
    
    float normalizedCenterX = (centerX - MIN_COORD) / (MAX_COORD - MIN_COORD);
    float normalizedCenterY = (centerY - MIN_COORD) / (MAX_COORD - MIN_COORD);

    float fracX = (normalizedCenterX - uvMin.x) / (uvMax.x - uvMin.x);
    float fracY = (normalizedCenterY - uvMin.y) / (uvMax.y - uvMin.y);

    float mapWidth  = posEnd.x - windowPos.x;
    float mapHeight = posEnd.y - windowPos.y;
    float pointerX = windowPos.x + fracX * mapWidth;
    float pointerY = windowPos.y + fracY * mapHeight;
    
    DrawTriangle(ImVec2(pointerX, pointerY), Yaw, ImVec4(1.0f, 0.0f, 0.0f, Set.MapSetting.MapColor.Value.w));
    
    /*
     
    centerX = fmaxf(MIN_COORD, fminf(MAX_COORD, centerX));
    centerY = fmaxf(MIN_COORD, fminf(MAX_COORD, centerY));
     
    CGFloat cropWidth = MapImage.size.width;
    CGFloat cropHeight = MapImage.size.height;
    
    if (MapZoom > 1) {
        cropWidth /= MapZoom;
        cropHeight /= MapZoom;
    }
    
    CGFloat minCenterX, maxCenterX, minCenterY, maxCenterY;
    CalculateCenterLimits(MapImage, cropWidth, cropHeight, &minCenterX, &maxCenterX, &minCenterY, &maxCenterY);
    
    float scaledX;
    float scaledY;
    
    if (centerX < minCenterX) {
        CGFloat proportion = (centerX - MIN_COORD) / (minCenterX - MIN_COORD);
        proportion = fmaxf(0.0f, fminf(1.0f, proportion));
        scaledX = pos.x + (proportion * (MapSize / 2.0f));
    } else if (centerX > maxCenterX) {
        CGFloat proportion = (MAX_COORD - centerX) / (MAX_COORD - maxCenterX);
        proportion = fmaxf(0.0f, fminf(1.0f, proportion));
        scaledX = pos.x + MapSize - (proportion * (MapSize / 2.0f));
    } else {
        scaledX = pos.x + MapSize / 2.0f;
    }
    
    if (centerY < minCenterY) {
        CGFloat proportion = (centerY - MIN_COORD) / (minCenterY - MIN_COORD);
        proportion = fmaxf(0.0f, fminf(1.0f, proportion));
        scaledY = pos.y + (proportion * (MapSize / 2.0f));
    } else if (centerY > maxCenterY) {
        CGFloat proportion = (MAX_COORD - centerY) / (MAX_COORD - maxCenterY);
        proportion = fmaxf(0.0f, fminf(1.0f, proportion));
        scaledY = pos.y + MapSize - (proportion * (MapSize / 2.0f));
    } else {
        scaledY = pos.y + MapSize / 2.0f;
    }
    
    DrawTriangle(ImVec2(scaledX, scaledY), Yaw, ImVec4(1.0f, 0.0f, 0.0f, 1.0f));
    
    */
}

ImColor Map::DayNightMode(float DayTime)
{
    float normalized;
    if (DayTime <= MID_DAY_TIME) {
        normalized = (DayTime - MIN_DAY_TIME) / (MID_DAY_TIME - MIN_DAY_TIME);
    } else {
        normalized = (MAX_DAY_TIME - DayTime) / (MAX_DAY_TIME - MID_DAY_TIME);
    }

    normalized = std::max(0.0f, std::min(1.0f, normalized));

    ImVec4 nightColor = ImVec4(0.4f, 0.4f, 0.4f, 1.0f);
    ImVec4 dayColor = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);

    ImVec4 currentColor;
    currentColor.x = nightColor.x + (dayColor.x - nightColor.x) * normalized;
    currentColor.y = nightColor.y + (dayColor.y - nightColor.y) * normalized;
    currentColor.z = nightColor.z + (dayColor.z - nightColor.z) * normalized;
    currentColor.w = nightColor.w + (dayColor.w - nightColor.w) * normalized;

    return currentColor;
}

void Map::DrawTriangle(const ImVec2 &position, float angleRadians, const ImVec4 &color)
{

    float triangleHeight = 6.0f;
    float triangleBase = 3.0f;
    
    ImVec2 topPoint = ImVec2(position.x, position.y - triangleHeight / 2.0f);
    ImVec2 leftPoint = ImVec2(position.x - triangleBase / 2.0f, position.y + triangleHeight / 2.0f);
    ImVec2 rightPoint = ImVec2(position.x + triangleBase / 2.0f, position.y + triangleHeight / 2.0f);

    auto RotatePoint = [](const ImVec2 &point, float angle, const ImVec2 &center) -> ImVec2 {
        float s = sin(angle);
        float c = cos(angle);

        return ImVec2(
            c * (point.x - center.x) - s * (point.y - center.y) + center.x,
            s * (point.x - center.x) + c * (point.y - center.y) + center.y
        );
    };

    topPoint = RotatePoint(topPoint, angleRadians, position);
    leftPoint = RotatePoint(leftPoint, angleRadians, position);
    rightPoint = RotatePoint(rightPoint, angleRadians, position);

    drawList->AddTriangleFilled(topPoint, leftPoint, rightPoint, ImColor(color));
}

/* void Map::CalculateCenterLimits(UIImage *image, CGFloat cropWidth, CGFloat cropHeight, CGFloat *minCenterX, CGFloat *maxCenterX, CGFloat *minCenterY, CGFloat *maxCenterY)
{
    *minCenterX = MIN_COORD + (cropWidth / image.size.width) * (MAX_COORD - MIN_COORD) / 2.0f;
    *maxCenterX = MAX_COORD - (cropWidth / image.size.width) * (MAX_COORD - MIN_COORD) / 2.0f;
    
    *minCenterY = MIN_COORD + (cropHeight / image.size.height) * (MAX_COORD - MIN_COORD) / 2.0f;
    *maxCenterY = MAX_COORD - (cropHeight / image.size.height) * (MAX_COORD - MIN_COORD) / 2.0f;
} */

/* UIImage* Map::CropToStaticSize(UIImage *image, CGFloat centerX, CGFloat centerY, BOOL *reachedBoundaryX, BOOL *reachedBoundaryY) {
    
    CGFloat actualCenterX = (centerX - MIN_COORD) * image.size.width / (MAX_COORD - MIN_COORD);
    CGFloat actualCenterY = (centerY - MIN_COORD) * image.size.height / (MAX_COORD - MIN_COORD);

    CGFloat cropWidth = image.size.width;
    CGFloat cropHeight = image.size.height;
    
    if (MapZoom > 1) {
        cropWidth /= MapZoom;
        cropHeight /= MapZoom;
    }
    
    CGFloat cropX = MAX(actualCenterX - cropWidth / 2.0f, 0);
    CGFloat cropY = MAX(actualCenterY - cropHeight / 2.0f, 0);
    cropX = MIN(cropX, image.size.width - cropWidth);
    cropY = MIN(cropY, image.size.height - cropHeight);
    
    *reachedBoundaryX = (cropX <= 0.0f || (cropX + cropWidth) >= image.size.width);
    *reachedBoundaryY = (cropY <= 0.0f || (cropY + cropHeight) >= image.size.height);
    
    CGRect cropRect = CGRectMake(cropX, cropY, cropWidth, cropHeight);
    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(imageRef);
    
    return croppedImage;
} */

/* void Map::UpdateImageTexture(UIImage *image) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:device];
    
    NSDictionary * const textureLoaderOptions = @{
        MTKTextureLoaderOptionSRGB : @NO,
        MTKTextureLoaderOptionTextureUsage : @(MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget),
        MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
    };
    
    NSError *error = nil;
    id<MTLTexture> texture = [textureLoader newTextureWithCGImage:image.CGImage options:textureLoaderOptions error:&error];
    
    if (texture && !error) {
        if (MapTexture)
            CFBridgingRelease(MapTexture);

        MapTexture = (ImTextureID)CFBridgingRetain(texture);
    }
} */
