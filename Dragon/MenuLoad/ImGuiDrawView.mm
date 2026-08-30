#include "Includes.h"
#include "../Resources/Fonts.h"
#include "../FrameTaskManager.h"
#include "../Menu/UserMenu.h"
#include "../Utilities/Timer.h"

#include <CoreText/CoreText.h>
#include <UIKit/UIKit.h>

@interface ImGuiDrawView () <MTKViewDelegate>

@property (nonatomic, strong) id <MTLDevice> device;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;

@end

@implementation ImGuiDrawView

- (void)UpdateSwitches
{
    if (settings.ShowAutoFireSwitch) {
        AutoFireSwitch.hidden = NO;
        settings.AutoFire = AutoFireSwitch.isOn;
    } else {
        AutoFireSwitch.hidden = YES;
    }

    if (settings.esp.HideStructureSwitch || settings.esp.HideResourceSwitch || settings.esp.HideDinosaurSwitch) {
        HideDrawSwitch.hidden = NO;
        if (settings.esp.HideStructureSwitch)
            settings.esp.HideStructure = HideDrawSwitch.isOn;
        if (settings.esp.HideDinosaurSwitch)
            settings.esp.HideDinosaur = HideDrawSwitch.isOn;
        if (settings.esp.HideResourceSwitch)
            settings.esp.HideResource = HideDrawSwitch.isOn;
    } else {
        HideDrawSwitch.hidden = YES;
    }

    if (settings.EnableAimbot && settings.AimType == 0 ) {
        AimlockSwitch.hidden = NO;
        settings.LockAim = AimlockSwitch.isOn;
    } else {
        AimlockSwitch.hidden = YES;
    }

    if (settings.ShowFreezeSwitch) {
        FreezeSwitch.hidden = NO;
        settings.Freeze = FreezeSwitch.isOn;
    } else {
        FreezeSwitch.hidden = YES;
    }
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    if (!self.device) abort();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiStyle &style = ImGui::GetStyle();
    ImGuiIO& io = ImGui::GetIO(); (void)io;

    io.Fonts->Clear();

    // / / // / / // / / / / / / / // / / / / // / / // / / // // // / / // / / /// / // / / / /

    FontRanges &ranges = FontRanges::GetInstance();

    // DEFAULT
    ImFontConfig font_config; font_config.FontDataOwnedByAtlas = false; /* font_config.PixelSnapH = true; */
    // font_config.FontBuilderFlags |= ImGuiFreeTypeBuilderFlags::ImGuiFreeTypeBuilderFlags_ForceAutoHint;
    io.Fonts->AddFontFromMemoryCompressedTTF(ARKFont_compressed_data, ARKFont_compressed_size, 14.f, &font_config, ranges.latin_ranges);

    // CHINESE
    // ImFontConfig china_config;
    // china_config.MergeMode = true; /* china_config.PixelSnapH = true; */ china_config.FontDataOwnedByAtlas = false;
    // china_config.FontBuilderFlags |= ImGuiFreeTypeBuilderFlags::ImGuiFreeTypeBuilderFlags_ForceAutoHint;
    // io.Fonts->AddFontFromMemoryCompressedTTF(DRGFont_compressed_data, DRGFont_compressed_size, 12.f, &china_config, io.Fonts->GetGlyphRangesChineseFull());

    // ICONS
    ImFontConfig fa_config; fa_config.MergeMode = true; fa_config.PixelSnapH = true; fa_config.FontDataOwnedByAtlas = false;
    // fa_config.FontBuilderFlags |= ImGuiFreeTypeBuilderFlags::ImGuiFreeTypeBuilderFlags_ForceAutoHint;
    io.Fonts->AddFontFromMemoryCompressedTTF(fa6_solid_compressed_data, fa6_solid_compressed_size, 14.f, &fa_config, ranges.icons_ranges_max);
    // io.Fonts->AddFontFromMemoryCompressedTTF(fa_brands_400_compressed_data, fa_brands_400_compressed_size, 14.f, &fa_config, ranges.icons_ranges_brands);

    // LOGOs (not used)
    // ImFontConfig icons_config; icons_config.PixelSnapH = true; icons_config.FontDataOwnedByAtlas = false;
    // icons_config.FontBuilderFlags |= ImGuiFreeTypeBuilderFlags::ImGuiFreeTypeBuilderFlags_ForceAutoHint;
    // IconFont = io.Fonts->AddFontFromMemoryCompressedTTF(fa6_solid_compressed_data, fa6_solid_compressed_size, 18.f, &icons_config, ranges.icons_ranges);
    // LogoFont = io.Fonts->AddFontFromMemoryCompressedTTF(NSMFont_compressed_data, NSMFont_compressed_size, IconFont->FontSize + style.WindowPadding.y * 2 + style.FramePadding.y * 2, /*NULL*/ &font_config, ranges.logo_ranges);

    // ESP
    // ImFontConfig esp_config; esp_config.PixelSnapH = true; esp_config.MergeMode = true; esp_config.FontDataOwnedByAtlas = false;
    // Font = io.Fonts->AddFontFromMemoryCompressedTTF(DRGFont_compressed_data, DRGFont_compressed_size, 28.f, &esp_config, ranges.esp_ranges); // 18.f
    // io.Fonts->AddFontFromMemoryCompressedTTF(fa6_solid_compressed_data, fa6_solid_compressed_size, 22.f, &esp_config, ranges.icons_ranges_esp);

    FontRanges::DestroyInstance();
    // / / // / / // / / / / / / / /// / / / / // / / // / / // / // / / // / / /// / // / / / /

    ImGui_ImplMetal_Init(_device);

    return self;
}

+ (void)showChange:(BOOL)open
{
    MenDeal = open;
}

+ (BOOL)isMenuShowing
{
    return MenDeal;
}

- (MTKView *)mtkView
{
    return (MTKView *)self.view;
}

- (void)loadView {
    CGRect bounds = UIScreen.mainScreen.bounds;

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    MTKView *mtkView = [[MTKView alloc] initWithFrame:bounds device:device];
    mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.view = mtkView;
}

/* - (void)loadView
{
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
} */

- (void)viewDidLoad {
    [super viewDidLoad];
    ExecutionTimer::Synchronize(207, false);

    self.mtkView.device = self.device;
    self.mtkView.delegate = self;

    self.mtkView.opaque = NO; //
    self.mtkView.layer.opaque = NO; //
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = NO; // YES;
    self.mtkView.layer.masksToBounds = NO; //
}

- (void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();
    io.MousePos = ImVec2(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches)
    {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
        {
            hasActiveTouch = YES;
            break;
        }
    }
    io.MouseDown[0] = hasActiveTouch;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)drawInMTKView:(MTKView*)view
{
    GHideRecordTextField.secureTextEntry = settings.StreamerMode;

    ImGuiIO& io = ImGui::GetIO();
    /*if (isIPad)
    {
        io.FontGlobalScale = 1.3f;
    }*/

    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.nativeScale ? : UIScreen.mainScreen.nativeScale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
    io.DeltaTime = 1 / float(view.preferredFramesPerSecond ? : 30);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

    if (MenDeal || settings.MapEnabled)
    {
        [self.view setUserInteractionEnabled:YES];
        [self.view.superview setUserInteractionEnabled:YES];
        [GMenuTouchView setUserInteractionEnabled:YES];
    }
    else
    {
        [self.view setUserInteractionEnabled:NO];
        [self.view.superview setUserInteractionEnabled:NO];
        [GMenuTouchView setUserInteractionEnabled:NO];
    }

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil)
    {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"Dear ImGui Rendering"];

        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ImGui::NewFrame();

        [self UpdateSwitches];

        if (MenDeal)
        {
            UserMenu::GetInstance().RenderMenu();
        }

        if (settings.MapEnabled)
        {
            FVector MapParams = LatLonRot.load();
            Map::GetInstance().InitFloatingObject(MapType::Island, MapParams.Y, MapParams.X, MapParams.Z);
        }

        if (settings.g_CrosshairSettings.cross_enabled ||
            settings.g_CrosshairSettings.small_circle_enabled ||
            settings.g_CrosshairSettings.small_dot_enabled)
        {
            DrawCrosshair();
        }

        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);

        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
    }

    [commandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}

/* __attribute__((visibility("hidden"))) __attribute__((constructor))
static void _init_() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        UserMenu::GetInstance().SaveOnce();
    }];


    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        UserMenu::GetInstance().SaveOnce();
    }];
} */

@end
