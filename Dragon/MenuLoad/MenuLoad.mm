#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

#include "Includes.h"
#include "../Menu/Map.h"

@interface MenuLoad()

@property (nonatomic, strong) ImGuiDrawView* ImGuiView;
@property (nonatomic, strong) UIImage* CachedGifImage;

- (ImGuiDrawView*)GetImGuiDrawView;

@end

static MenuLoad* GExtraInfo;

@interface MenuInteraction()

@end

@implementation MenuInteraction

- (BOOL)pointInside:(CGPoint)InPoint withEvent:(UIEvent*)InEvent
{
    if (MenDeal)
    {
        ImGuiContext* Context = ImGui::GetCurrentContext();

        if (Context)
        {
            const ImVector<ImGuiWindow*>& Windows = Context->Windows;
            for (int i = 0; i < Windows.Size; ++i)
            {
                ImGuiWindow* CurrentWindow = Windows[i];
                if (!CurrentWindow)
                    continue;

                if (CurrentWindow->Active && !(CurrentWindow->Flags & ImGuiWindowFlags_NoInputs))
                {
                    CGRect TouchableArea = CGRectMake(CurrentWindow->Pos.x, CurrentWindow->Pos.y, CurrentWindow->Size.x, CurrentWindow->Size.y);
                    if (CGRectContainsPoint(TouchableArea, InPoint)) {
                        return [super pointInside:InPoint withEvent:InEvent];
                    }
                }
            }
        }
    }

    if (settings.MapEnabled)
    {
        Map& map = Map::GetInstance();

        ImVec2 widgetPos  = map.GetWidgetPosition();
        float  widgetSize = map.GetWidgetSize();
        CGRect widgetRect = CGRectMake(widgetPos.x, widgetPos.y, widgetSize, widgetSize);

        if (map.IsVisible())
        {
            ImVec2 mapPos     = map.GetMapPosition();
            float  mapSize    = settings.MapSetting.MapSize;
            CGRect mapRect    = CGRectMake(mapPos.x, mapPos.y, mapSize, mapSize);

            if (CGRectContainsPoint(widgetRect, InPoint))
            {
                return [super pointInside:InPoint withEvent:InEvent];
            }

            if (CGRectContainsPoint(mapRect, InPoint))
            {
                return [super pointInside:InPoint withEvent:InEvent];
            }
        }
        else
        {
            if (CGRectContainsPoint(widgetRect, InPoint))
            {
                return [super pointInside:InPoint withEvent:InEvent];
            }
        }
    }

    return NO;
}

- (void)touchesBegan:(NSSet<UITouch*>*)InTouches withEvent:(UIEvent*)InEvent
{
    [[GExtraInfo GetImGuiDrawView] updateIOWithTouchEvent:InEvent];
}

- (void)touchesMoved:(NSSet<UITouch*>*)InTouches withEvent:(UIEvent*)InEvent
{
    [[GExtraInfo GetImGuiDrawView] updateIOWithTouchEvent:InEvent];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)InTouches withEvent:(UIEvent*)InEvent
{
    [[GExtraInfo GetImGuiDrawView] updateIOWithTouchEvent:InEvent];
}

- (void)touchesEnded:(NSSet<UITouch*>*)InTouches withEvent:(UIEvent*)InEvent
{
    [[GExtraInfo GetImGuiDrawView] updateIOWithTouchEvent:InEvent];
}

@end

@implementation MenuLoad

bool bIsMenuOpened = false;

- (ImGuiDrawView*)GetImGuiDrawView
{
    return _ImGuiView;
}

FORCEINLINE void InitializeMenu()
{
    GExtraInfo = [MenuLoad new];
    [GExtraInfo InitializeGestureRecognizers];
}

+ (void)load
{
    [super load];

    CallAfterSeconds(3)
    {
        settings.Load();
        InitializeMenu();
    });
}

- (void)InitializeGestureRecognizers
{
    UIView* const MainApplicationView = [UIApplication sharedApplication].windows[0].rootViewController.view;
    const CGRect ScreenBounds = [[UIScreen mainScreen] bounds];

    [self SetupHiddenRecordingComponents:ScreenBounds];
    [self InitializeImGuiDrawSystem];
    [self SetupTouchInteractionLayer:MainApplicationView];
    [self LoadAnimatedMenuButton:MainApplicationView];
    [self SetupInvisibleDraggableButton:MainApplicationView];
    [self CreateSwitches:ScreenBounds];
}

- (void)SetupHiddenRecordingComponents:(CGRect)InScreenBounds
{
    GHideRecordTextField = [[UITextField alloc] init];
    GHideRecordView = [[UIView alloc] initWithFrame:InScreenBounds];
    GHideRecordView.backgroundColor = [UIColor clearColor];
    GHideRecordView.userInteractionEnabled = YES;
    GHideRecordTextField.secureTextEntry = YES;
    [GHideRecordView addSubview:GHideRecordTextField];

    CALayer* const TextFieldLayer = GHideRecordTextField.layer;

    if ([TextFieldLayer.sublayers.firstObject.delegate isKindOfClass:[UIView class]])
    {
        GHideRecordView = (UIView*)TextFieldLayer.sublayers.firstObject.delegate;
    }
    else
    {
        GHideRecordView = nil;
    }

    if (GHideRecordView)
    {
        [[UIApplication sharedApplication].windows.firstObject addSubview:GHideRecordView];
    }
}

- (void)InitializeImGuiDrawSystem
{
    if (!_ImGuiView)
    {
        _ImGuiView = [[ImGuiDrawView alloc] init];
    }

    [ImGuiDrawView showChange:YES];
    [GHideRecordView addSubview:_ImGuiView.view];
}

- (void)SetupTouchInteractionLayer:(UIView*)InMainView
{
    GMenuTouchView = [[MenuInteraction alloc] initWithFrame:InMainView.frame];
    [InMainView addSubview:GMenuTouchView];
}

- (void)LoadAnimatedMenuButton:(UIView*)InMainView
{
    (void)InMainView;
    // TODO: Supply a local menu-button asset for your own public build.
}

- (void)SetupInvisibleDraggableButton:(UIView*)InMainView
{
    const CGFloat ButtonSize = 75.0f;
    const CGFloat HalfButtonSize = ButtonSize * 0.5f;

    GInvisibleMenuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    GInvisibleMenuButton.frame = CGRectMake(
        CGRectGetMidX(InMainView.frame) - HalfButtonSize,
        CGRectGetMidY(InMainView.frame) - HalfButtonSize,
        ButtonSize,
        ButtonSize
    );
    GInvisibleMenuButton.backgroundColor = [UIColor clearColor];

    [GInvisibleMenuButton addTarget:self
                             action:@selector(OnButtonDragged:withEvent:)
                   forControlEvents:UIControlEventTouchDragInside];

    UITapGestureRecognizer* MenuTapGesture = [[UITapGestureRecognizer alloc]
                                             initWithTarget:self
                                             action:@selector(OnMenuButtonTapped:)];
    [GInvisibleMenuButton addGestureRecognizer:MenuTapGesture];
    [InMainView addSubview:GInvisibleMenuButton];
}

- (void)CreateVisibleMenuButton:(UIImage*)InAnimatedImage InMainView:(UIView*)InMainView
{
    const CGFloat ButtonSize = 75.0f;
    const CGFloat HalfButtonSize = ButtonSize * 0.5f;
    const CGFloat CornerRadius = 25.0f;

    GVisibleMenuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    GVisibleMenuButton.frame = CGRectMake(
        CGRectGetMidX(InMainView.frame) - HalfButtonSize,
        CGRectGetMidY(InMainView.frame) - HalfButtonSize,
        ButtonSize,
        ButtonSize
    );
    GVisibleMenuButton.backgroundColor = [UIColor clearColor];
    GVisibleMenuButton.layer.cornerRadius = CornerRadius;
    GVisibleMenuButton.clipsToBounds = YES;
    [GVisibleMenuButton setImage:InAnimatedImage forState:UIControlStateNormal];
    [GHideRecordView addSubview:GVisibleMenuButton];
}


- (void)CreateSwitches:(CGRect)ScreenRect
{
    // AutoFireSwitch
    AutoFireSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    AutoFireSwitch.frame = CGRectMake(ScreenRect.size.width - 53, CGRectGetMidY(ScreenRect) - 16, 51, 31);
    AutoFireSwitch.hidden = YES;
    [[UIApplication sharedApplication].windows.firstObject addSubview:AutoFireSwitch];

    // HideDrawSwitch
    HideDrawSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    HideDrawSwitch.frame = CGRectMake(ScreenRect.size.width - 53, 35, 51, 31);
    HideDrawSwitch.hidden = YES;
    [[UIApplication sharedApplication].windows.firstObject addSubview:HideDrawSwitch];

    // AimlockSwitch
    AimlockSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    AimlockSwitch.frame = CGRectMake(ScreenRect.size.width - 53, CGRectGetMidY(ScreenRect) + 16, 51, 31);
    AimlockSwitch.hidden = YES;
    [[UIApplication sharedApplication].windows.firstObject addSubview:AimlockSwitch];

    // FreezeSwitch
    FreezeSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    FreezeSwitch.frame = CGRectMake(53, CGRectGetMidY(ScreenRect), 51, 31);
    FreezeSwitch.hidden = YES;
    [[UIApplication sharedApplication].windows.firstObject addSubview:FreezeSwitch];
}


- (UIImage* _Nullable)ProcessAnimatedImageData:(NSData* _Nonnull)InImageData
{
    if (!InImageData)
    {
        return nil;
    }

    CGImageSourceRef ImageSource = CGImageSourceCreateWithData((__bridge CFDataRef)InImageData, NULL);
    if (!ImageSource)
    {
        return nil;
    }

    const size_t FrameCount = CGImageSourceGetCount(ImageSource);
    NSMutableArray<UIImage*>* FrameImages = [NSMutableArray arrayWithCapacity:FrameCount];
    NSTimeInterval TotalAnimationDuration = 0.0f;

    for (size_t FrameIndex = 0; FrameIndex < FrameCount; FrameIndex++)
    {
        @autoreleasepool
        {
            const CGImageRef _Nullable CurrentFrameRef = CGImageSourceCreateImageAtIndex(ImageSource, FrameIndex, NULL);
            if (!CurrentFrameRef)
            {
                continue;
            }

            NSDictionary* FrameProperties = (__bridge_transfer NSDictionary*)CGImageSourceCopyPropertiesAtIndex(ImageSource, FrameIndex, NULL);
            NSDictionary* GifFrameProperties = FrameProperties[(NSString* _Nonnull)kCGImagePropertyGIFDictionary];

            NSNumber* FrameDelayTime = GifFrameProperties[(NSString* _Nonnull)kCGImagePropertyGIFUnclampedDelayTime];
            if (!FrameDelayTime)
            {
                FrameDelayTime = GifFrameProperties[(NSString* _Nonnull)kCGImagePropertyGIFDelayTime];
            }

            const float MinFrameDuration = 0.011f;
            const float DefaultFrameDuration = 0.100f;
            if (FrameDelayTime.floatValue < MinFrameDuration)
            {
                FrameDelayTime = @(DefaultFrameDuration);
            }

            TotalAnimationDuration += FrameDelayTime.floatValue;

            UIImage* ProcessedFrameImage = [UIImage imageWithCGImage:CurrentFrameRef
                                                               scale:[UIScreen mainScreen].scale
                                                         orientation:UIImageOrientationUp];
            [FrameImages addObject:ProcessedFrameImage];

            CGImageRelease(CurrentFrameRef);
        }
    }

    CFRelease(ImageSource);

    if (TotalAnimationDuration == 0.0f)
    {
        constexpr float DefaultFPS = 10.0f;
        TotalAnimationDuration = (1.0f / DefaultFPS) * FrameCount;
    }

    return [UIImage animatedImageWithImages:FrameImages duration:TotalAnimationDuration];
}

- (void)OnMenuButtonTapped:(UITapGestureRecognizer*)InTapGesture
{
    if (InTapGesture.state == UIGestureRecognizerStateEnded)
    {
        const BOOL bCurrentMenuVisibility = [ImGuiDrawView isMenuShowing];

        if (bCurrentMenuVisibility)
        {
            settings.Save();
        }

        [ImGuiDrawView showChange:!bCurrentMenuVisibility];
    }
}

- (void)OnButtonDragged:(UIButton*)InDraggedButton withEvent:(UIEvent*)InDragEvent
{
    UITouch* DragTouch = [[InDragEvent touchesForView:InDraggedButton] anyObject];

    const CGPoint PreviousTouchLocation = [DragTouch previousLocationInView:InDraggedButton];
    const CGPoint CurrentTouchLocation = [DragTouch locationInView:InDraggedButton];
    const CGFloat HorizontalDelta = CurrentTouchLocation.x - PreviousTouchLocation.x;
    const CGFloat VerticalDelta = CurrentTouchLocation.y - PreviousTouchLocation.y;

    InDraggedButton.center = CGPointMake(
        InDraggedButton.center.x + HorizontalDelta,
        InDraggedButton.center.y + VerticalDelta
    );

    const CGRect ScreenBounds = [UIApplication sharedApplication].windows[0].rootViewController.view.bounds;
    [self ClampButtonToScreenBounds:InDraggedButton WithScreenBounds:ScreenBounds];

    GVisibleMenuButton.center = InDraggedButton.center;
    GVisibleMenuButton.frame = InDraggedButton.frame;
}

- (void)ClampButtonToScreenBounds:(UIButton*)InButton WithScreenBounds:(CGRect)InScreenBounds
{
    CGPoint ClampedCenter = InButton.center;

    if (ClampedCenter.x < 0)
    {
        ClampedCenter.x = 0;
    }
    else if (ClampedCenter.x > InScreenBounds.size.width)
    {
        ClampedCenter.x = InScreenBounds.size.width;
    }

    if (ClampedCenter.y < 0)
    {
        ClampedCenter.y = 0;
    }
    else if (ClampedCenter.y > InScreenBounds.size.height)
    {
        ClampedCenter.y = InScreenBounds.size.height;
    }

    InButton.center = ClampedCenter;
}

@end
