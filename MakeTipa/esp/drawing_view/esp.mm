#import "esp.h"
#import "ESPPrefs.h"
#import "../drawing_view/offset.h"
#import "mahoa.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <string>
#include <vector>
#include <cmath>
#include <float.h>

uint64_t Moudule_Base = -1;

// ─── ESP Flags ────────────────────────────────
bool isBox      = YES;
bool isBone     = YES;
bool isHealth   = YES;
bool isName     = YES;
bool isDis      = YES;
bool isLine     = YES;
bool isEspBot   = NO;
bool isWeapon   = NO;

// ─── Aimbot Flags ─────────────────────────────
bool isAimbot          = NO;
bool isAimIgnoreBot    = NO;
bool isAimIgnoreKnock  = NO;
bool isAimCheckVisible = NO;
bool isAimRage         = NO;
bool isLineAim         = YES;

int   triggerMode    = 0;
int   aimPosition    = 0;
int   aimTargetMode  = 0;
float aimFov         = 150.0f;
float aimDistance    = 200.0f;
float aimSpeed       = 1.0f;

static bool gESPPrefsLoadedOnce = false;

void ESPSyncFromPrefs(void) {
    isBox    = ESPPrefsBool(NSSENCRYPT("Box"),    NO);
    isBone   = ESPPrefsBool(NSSENCRYPT("Bone"),   NO);
    isHealth = ESPPrefsBool(NSSENCRYPT("Health"), NO);
    isName   = ESPPrefsBool(NSSENCRYPT("Name"),   NO);
    isDis    = ESPPrefsBool(NSSENCRYPT("Dis"),    NO);
    isLine   = ESPPrefsBool(NSSENCRYPT("Line"),   NO);
    isEspBot = ESPPrefsBool(NSSENCRYPT("EspBot"), NO);

    isAimIgnoreBot    = ESPPrefsBool(NSSENCRYPT("AimIgnoreBot"),    NO);
    isAimIgnoreKnock  = ESPPrefsBool(NSSENCRYPT("AimIgnoreKnock"), NO);
    isAimCheckVisible = ESPPrefsBool(NSSENCRYPT("AimCheckVisible"), NO);
    isAimRage         = ESPPrefsBool(NSSENCRYPT("AimRage"),         NO);
    isLineAim         = ESPPrefsBool(NSSENCRYPT("LineAim"),         YES);
    isAimbot          = ESPPrefsBool(NSSENCRYPT("Aimbot"),          NO);

    triggerMode = (int)ESPPrefsFloat(NSSENCRYPT("TriggerMode"), 0.0f);
    if (triggerMode < 0 || triggerMode > 3) triggerMode = 0;

    aimPosition = (int)ESPPrefsFloat(NSSENCRYPT("AimPos"), 0.0f);
    if (aimPosition < 0 || aimPosition > 2) aimPosition = 0;

    aimTargetMode = (int)ESPPrefsFloat(NSSENCRYPT("AimTargetMode"), 0.0f);
    if (aimTargetMode < 0 || aimTargetMode > 2) aimTargetMode = 0;

    aimFov = ESPPrefsFloat(NSSENCRYPT("Fov"), 150.0f);
    aimFov = fmaxf(10.0f, fminf(aimFov, 500.0f));

    aimDistance = ESPPrefsFloat(NSSENCRYPT("Distance"), 200.0f);

    aimSpeed = ESPPrefsFloat(NSSENCRYPT("AimSpeed"), 100.0f) / 100.0f;
    aimSpeed = fmaxf(0.01f, fminf(aimSpeed, 1.0f));
}

// ─── Aim Lock State ───────────────────────────
static uint64_t    gAimLockTarget         = 0;
static int         gAimLockLostFrames     = 0;
static const int   kAimLockMaxLostFrames  = 10;
static const NSUInteger kMaxTextLayerPoolSize = 128;

// ─── Frame Cache ──────────────────────────────
static uint64_t cachedMatchGame  = 0;
static uint64_t cachedCamera     = 0;
static uint64_t cachedMatch      = 0;
static int      cacheRefreshTick = 0;

typedef struct {
    int  enemyCount;
    bool inMatch;
} ESPFrameStats;

// ─── Helpers ──────────────────────────────────
static inline float Clamp01f(float v) {
    return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
}

static inline void ESPReleasePath(CGMutablePathRef p) { if (p) CGPathRelease(p); }

static inline ESPGeometryBuffers ESPGeometryBuffersCreate(void) {
    ESPGeometryBuffers b;
    b.boxPath          = CGPathCreateMutable();
    b.bonePath         = CGPathCreateMutable();
    b.snaplinePath     = CGPathCreateMutable();
    b.hpBackgroundPath = CGPathCreateMutable();
    b.hpFillPath       = CGPathCreateMutable();
    b.aimAssistPath    = CGPathCreateMutable();
    b.alertPath        = CGPathCreateMutable();
    b.boxDirty = b.boneDirty = b.snaplineDirty      = NO;
    b.hpBackgroundDirty = b.hpFillDirty             = NO;
    b.aimAssistDirty = b.alertDirty                 = NO;
    return b;
}

static inline void ESPGeometryBuffersRelease(ESPGeometryBuffers *b) {
    if (!b) return;
    ESPReleasePath(b->boxPath);
    ESPReleasePath(b->bonePath);
    ESPReleasePath(b->snaplinePath);
    ESPReleasePath(b->hpBackgroundPath);
    ESPReleasePath(b->hpFillPath);
    ESPReleasePath(b->aimAssistPath);
    ESPReleasePath(b->alertPath);
}

static inline void ApplyPath(CAShapeLayer *layer, CGMutablePathRef path, bool dirty) {
    if (layer) layer.path = (dirty && path) ? path : nil;
}

// ─── Box ──────────────────────────────────────
static inline void ESPAddBox(CGMutablePathRef path, CGRect rect) {
    if (path) CGPathAddRect(path, NULL, rect);
}

// ─── Snapline (Kéo từ giữa màn hình trên cùng) ──
static inline void ESPAddSnapline(CGMutablePathRef path, CGPoint start, CGPoint end) {
    if (path) {
        CGPathMoveToPoint(path, NULL, start.x, start.y);
        CGPathAddLineToPoint(path, NULL, end.x, end.y);
    }
}

// ─── Thanh máu ────────────────────────────────
static inline void ESPAddHealthBar(CGMutablePathRef bgPath, CGMutablePathRef fillPath,
                                   CGRect boxRect, float hp) {
    if (!bgPath || !fillPath) return;

    const CGFloat barW = 2.0f;
    const CGFloat gap   = 2.0f;
    const CGFloat bdr   = 0.5f;

    CGFloat x = boxRect.origin.x - gap - barW;
    CGFloat y = boxRect.origin.y;
    CGFloat h = boxRect.size.height;

    CGPathAddRect(bgPath, NULL,
        CGRectMake(x - bdr, y - bdr, barW + bdr * 2.0f, h + bdr * 2.0f));

    CGFloat fillH = h * Clamp01f(hp);
    CGFloat fillY = y + (h - fillH);
    if (fillH > 0.5f)
        CGPathAddRect(fillPath, NULL, CGRectMake(x, fillY, barW, fillH));
}

static inline BOOL RenderFOVCirclePath(CGMutablePathRef path,
                                        CGFloat vw, CGFloat vh,
                                        BOOL aiming, float fov) {
    if (!aiming || fov <= 0) return NO;
    CGPathAddArc(path, NULL, vw / 2.0f, vh / 2.0f, fov, 0, M_PI * 2, YES);
    return YES;
}

// ─────────────────────────────────────────────
// MARK: - ESP_View Interface
// ─────────────────────────────────────────────
@interface ESP_View ()
@property (nonatomic, strong) CADisplayLink          *displayLink;
@property (nonatomic, strong) CAShapeLayer           *boxLayer;
@property (nonatomic, strong) CAShapeLayer           *boneLayer;
@property (nonatomic, strong) CAShapeLayer           *snaplineLayer;
@property (nonatomic, strong) CAShapeLayer           *hpBackgroundLayer;
@property (nonatomic, strong) CAShapeLayer           *hpFillLayer;
@property (nonatomic, strong) CAShapeLayer           *aimAssistLayer;
@property (nonatomic, strong) CAShapeLayer           *alertLayer;
@property (nonatomic, strong) CAShapeLayer           *fovLayer;
@property (nonatomic, strong) NSMutableArray<CATextLayer *> *textLayerPool;
@property (nonatomic, assign) NSUInteger              activeTextLayerCount;
@property (nonatomic, strong) CATextLayer            *statusLayer;
@end

// ─────────────────────────────────────────────
// MARK: - ESP_View Implementation
// ─────────────────────────────────────────────
@implementation ESP_View

- (void)showMenu              { }
- (void)hideMenu              { }
- (void)centerMenu            { }
- (void)handlePan:(UIPanGestureRecognizer *)g { }

static void ESPTextCallback(void *ctx, NSString *str, CGRect frame,
                                UIColor *color, CGFloat fontSize, BOOL leftAligned) {
    if (!ctx || !str) return;
    ESP_View *view = (__bridge ESP_View *)ctx;
    CGRect f = CGRectMake(frame.origin.x - 4.0f,
                          frame.origin.y - 10.0f,
                          frame.size.width + 8.0f, 10.0f);
    [view addText:str frame:f
            color:[UIColor colorWithWhite:1.0f alpha:0.92f]
         fontSize:7.0f leftAligned:NO];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.userInteractionEnabled = NO;
    self.backgroundColor        = UIColor.clearColor;
    self.textLayerPool          = [NSMutableArray array];

    [self configureRenderingLayers];
    [self setupModuleBase];

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    if (@available(iOS 15.0, *))
        self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30.0, 60.0, 60.0);
    else if (@available(iOS 10.0, *))
        self.displayLink.preferredFramesPerSecond = 60;
    [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) self.frame = self.superview.bounds;
}

- (void)setupModuleBase {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Moudule_Base = (uint64_t)GetGameModule_Base((char *)"FreeFire");
    });
}

// ─── Layer Factory ────────────────────────────
- (CAShapeLayer *)makeShapeLayer:(UIColor *)stroke fill:(UIColor *)fill
                        lineWidth:(CGFloat)lw zPos:(CGFloat)z {
    CAShapeLayer *l   = [CAShapeLayer layer];
    l.strokeColor     = stroke ? stroke.CGColor : nil;
    l.fillColor       = fill   ? fill.CGColor   : UIColor.clearColor.CGColor;
    l.lineWidth       = lw;
    l.lineJoin        = kCALineJoinMiter;
    l.lineCap         = kCALineCapSquare;
    l.contentsScale   = UIScreen.mainScreen.scale;
    l.zPosition       = z;
    l.allowsEdgeAntialiasing = NO;
    l.actions = @{ @"path": NSNull.null };
    return l;
}

- (void)configureRenderingLayers {
    UIColor *white    = UIColor.whiteColor;
    UIColor *black    = UIColor.blackColor;
    UIColor *green    = UIColor.greenColor; // Đổi Box thành Xanh lá
    UIColor *red      = UIColor.redColor;   // Text màu đỏ
    UIColor *neonDim  = [UIColor colorWithRed:0.00f green:1.00f blue:0.55f alpha:0.60f];
    UIColor *fovTint  = [UIColor colorWithWhite:1.0f alpha:0.18f];
    UIColor *magenta  = [UIColor colorWithRed:1.0f green:0.2f blue:0.6f alpha:0.9f];

    self.fovLayer          = [self makeShapeLayer:fovTint  fill:nil  lineWidth:0.5f zPos:0];
    
    // Line màu trắng giống hệt trong ảnh
    self.snaplineLayer     = [self makeShapeLayer:white    fill:nil  lineWidth:0.8f zPos:1]; 
    self.boneLayer         = [self makeShapeLayer:neonDim  fill:nil  lineWidth:0.5f zPos:2];
    
    // Box màu xanh lá
    self.boxLayer          = [self makeShapeLayer:green    fill:nil  lineWidth:1.0f zPos:3]; 
    self.hpBackgroundLayer = [self makeShapeLayer:nil      fill:black lineWidth:0   zPos:4];
    self.hpFillLayer       = [self makeShapeLayer:nil      fill:green lineWidth:0   zPos:5];
    self.aimAssistLayer    = [self makeShapeLayer:magenta  fill:nil  lineWidth:0.5f zPos:6];
    self.alertLayer        = [self makeShapeLayer:red      fill:nil  lineWidth:0.5f zPos:7];

    for (CAShapeLayer *l in @[self.fovLayer, self.snaplineLayer, self.boneLayer, self.boxLayer,
                               self.hpBackgroundLayer, self.hpFillLayer,
                               self.aimAssistLayer, self.alertLayer])
        [self.layer addSublayer:l];

    // Chữ đếm Enemy màu đỏ trên cùng
    self.statusLayer = [CATextLayer layer];
    self.statusLayer.foregroundColor = red.CGColor;
    self.statusLayer.alignmentMode   = kCAAlignmentCenter;
    self.statusLayer.fontSize        = 16.0f; // Chữ to rõ hơn
    self.statusLayer.font = (__bridge CFTypeRef)[UIFont systemFontOfSize:16.0f weight:UIFontWeightBold];
    self.statusLayer.shadowColor     = black.CGColor;
    self.statusLayer.shadowOffset    = CGSizeMake(1.0f, 1.0f);
    self.statusLayer.shadowOpacity   = 1.0f;
    self.statusLayer.shadowRadius    = 0.5f;
    self.statusLayer.contentsScale   = UIScreen.mainScreen.scale;
    self.statusLayer.zPosition       = 8;
    self.statusLayer.actions = @{ @"string":NSNull.null, @"frame":NSNull.null, @"hidden":NSNull.null };
    [self.layer addSublayer:self.statusLayer];
}

// ─── Text Layer Pool ──────────────────────────
- (void)resetTextLayers {
    for (CATextLayer *l in self.textLayerPool) l.hidden = YES;
    self.activeTextLayerCount = 0;
}

- (CATextLayer *)dequeueTextLayer {
    CATextLayer *layer;
    if (self.activeTextLayerCount < self.textLayerPool.count) {
        layer = self.textLayerPool[self.activeTextLayerCount];
    } else if (self.textLayerPool.count < kMaxTextLayerPoolSize) {
        layer = [CATextLayer layer];
        layer.contentsScale = UIScreen.mainScreen.scale;
        layer.alignmentMode = kCAAlignmentCenter;
        layer.shadowColor   = UIColor.blackColor.CGColor;
        layer.shadowOffset  = CGSizeMake(0.5f, 0.5f);
        layer.shadowOpacity = 1.0f;
        layer.shadowRadius  = 0.0f;
        layer.actions = @{ @"position":NSNull.null, @"bounds":NSNull.null,
                           @"string":NSNull.null,   @"hidden":NSNull.null };
        [self.textLayerPool addObject:layer];
        [self.layer addSublayer:layer];
    } else {
        layer = self.textLayerPool.lastObject;
    }
    layer.hidden = NO;
    self.activeTextLayerCount++;
    return layer;
}

- (void)addText:(NSString *)text frame:(CGRect)frame color:(UIColor *)color
       fontSize:(CGFloat)fontSize leftAligned:(BOOL)leftAligned {
    if (!text.length) return;
    CGFloat fs        = (fontSize > 0) ? fontSize : 7.0f;
    CATextLayer *l    = [self dequeueTextLayer];
    l.string          = text;
    l.frame           = frame;
    l.foregroundColor = (color ?: UIColor.whiteColor).CGColor;
    l.fontSize        = fs;
    l.font = (__bridge CFTypeRef)[UIFont monospacedSystemFontOfSize:fs weight:UIFontWeightRegular];
    l.alignmentMode   = leftAligned ? kCAAlignmentLeft : kCAAlignmentCenter;
    l.shadowColor     = UIColor.blackColor.CGColor;
    l.shadowOffset    = CGSizeMake(0.5f, 0.5f);
    l.shadowOpacity   = 1.0f;
    l.shadowRadius    = 0.0f;
}

// ─── Main Update Loop ─────────────────────────
- (void)updateFrame {
    if (!self.window) return;
    @autoreleasepool {
#ifdef NOTIFY_DESTROY_HUD
        if (GetGameProcesspid((char *)"FreeFire") == -1) {
            notify_post(NOTIFY_DESTROY_HUD);
            exit(0);
        }
#endif
        if (Moudule_Base == (uint64_t)-1)
            Moudule_Base = (uint64_t)GetGameModule_Base((char *)"FreeFire");

        if (!gESPPrefsLoadedOnce) {
            ESPSyncFromPrefs();
            gESPPrefsLoadedOnce = true;
        }

        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self resetTextLayers];

        CGFloat vw    = self.bounds.size.width;
        CGFloat vh    = self.bounds.size.height;
        CGFloat scale = self.contentScaleFactor > 0.01f ? self.contentScaleFactor : 1.0f;
        CGFloat vpW   = vw * scale;
        CGFloat vpH   = vh * scale;

        ESPGeometryBuffers buffers = ESPGeometryBuffersCreate();
        ESPFrameStats stats = [self renderESPWithBuffers:&buffers
                                               viewWidth:vw viewHeight:vh
                                           matrixVpWidth:vpW matrixVpHeight:vpH];

        ApplyPath(self.boxLayer,          buffers.boxPath,          buffers.boxDirty);
        ApplyPath(self.boneLayer,         buffers.bonePath,         buffers.boneDirty);
        ApplyPath(self.snaplineLayer,     buffers.snaplinePath,     buffers.snaplineDirty);
        ApplyPath(self.hpBackgroundLayer, buffers.hpBackgroundPath, buffers.hpBackgroundDirty);
        ApplyPath(self.hpFillLayer,       buffers.hpFillPath,       buffers.hpFillDirty);
        ApplyPath(self.aimAssistLayer,    buffers.aimAssistPath,    buffers.aimAssistDirty);
        ApplyPath(self.alertLayer,        buffers.alertPath,        buffers.alertDirty);
        ESPGeometryBuffersRelease(&buffers);

        if (stats.inMatch) {
            CGMutablePathRef fovPath = CGPathCreateMutable();
            BOOL hasFov = RenderFOVCirclePath(fovPath, vw, vh, isAimbot, aimFov);
            self.fovLayer.path = hasFov ? fovPath : nil;
            CGPathRelease(fovPath);

            // Đưa chữ Enemies ra chính giữa phía trên
            self.statusLayer.string = [NSString stringWithFormat:@"Enemies: %d", stats.enemyCount];
            self.statusLayer.frame  = CGRectMake(vw / 2.0f - 100.0f, 40.0f, 200.0f, 20.0f);
            self.statusLayer.hidden = NO;
        } else {
            [self clearAllContent];
        }

        [CATransaction commit];
    }
}

- (void)clearAllContent {
    self.boxLayer.path = self.boneLayer.path = self.snaplineLayer.path  = nil;
    self.hpBackgroundLayer.path = self.hpFillLayer.path                 = nil;
    self.aimAssistLayer.path = self.alertLayer.path = self.fovLayer.path = nil;
    self.statusLayer.hidden = YES;
    [self resetTextLayers];
}

- (void)dealloc {
    [_displayLink invalidate];
    _displayLink = nil;
}

// ─── C++ Helpers ──────────────────────────────
Quaternion GetRotationToLocation(Vector3 target, float yBias, Vector3 myLoc) {
    return Quaternion::LookRotation((target + Vector3(0, yBias, 0)) - myLoc, Vector3(0, 1, 0));
}

static inline bool IsZeroVec(const Vector3 &v) {
    return v.x == 0.0f && v.y == 0.0f && v.z == 0.0f;
}

Vector3 GetAimTargetPos(Vector3 head, Vector3 hip, int setting) {
    if (IsZeroVec(head) || IsZeroVec(hip)) return head;
    if (setting == 0) return head;
    if (setting == 1) {
        Vector3 neck(head.x * 0.85f + hip.x * 0.15f,
                     head.y * 0.85f + hip.y * 0.15f,
                     head.z * 0.85f + hip.z * 0.15f);
        neck.y -= 0.1f;
        return neck;
    }
    return Vector3(head.x * 0.4f + hip.x * 0.6f,
                   head.y * 0.4f + hip.y * 0.6f,
                   head.z * 0.4f + hip.z * 0.6f);
}

bool get_IsBot(uint64_t player) {
    if (!isVaildPtr(player)) return false;
    return ReadAddr<uint8_t>(player + (uint64_t)kIsClientBot) != 0;
}

bool get_IsKnockedDown(uint64_t player) {
    if (!isVaildPtr(player)) return false;
    if (get_CurHP(player) <= 0) return false;
    uint64_t phx = ReadAddr<uint64_t>(player + kMyPhysXData);
    if (isVaildPtr(phx)) {
        uint64_t ghg = ReadAddr<uint64_t>(phx + (uint64_t)kPhxNpeononogeo);
        if (isVaildPtr(ghg) && ReadAddr<uint32_t>(ghg + (uint64_t)kGhgState) == 8)
            return true;
    }
    return ReadAddr<uint8_t>(player + kKnocked) != 0;
}

void set_aim(uint64_t player, Quaternion rotation, float targetDist) {
    if (!isVaildPtr(player)) return;
    Quaternion q       = Quaternion::Normalized(rotation);
    Quaternion current = ReadAddr<Quaternion>(player + kAimRotation);
    float angle        = Quaternion::Angle(current, q);
    if (angle < 0.0005f) return;

    float t;
    if (isAimRage || aimSpeed >= 0.99f) {
        t = 1.0f;
    } else {
        t = 0.75f + 0.25f * Clamp01f(aimSpeed);
        float dn = Clamp01f(targetDist / fmaxf(aimDistance, 1.0f));
        if      (dn    < 0.15f) t += 0.20f;
        else if (dn    < 0.30f) t += 0.12f;
        if      (angle > 10.0f) t += 0.15f;
        else if (angle >  5.0f) t += 0.08f;
        t = fminf(t, 0.995f);
    }

    Quaternion out = Quaternion::Normalized(Quaternion::Slerp(current, q, t));
    WriteAddr<Quaternion>(player + kAimRotation,    out);
    WriteAddr<Quaternion>(player + kAimRotationAux, out);
}

static inline uint32_t get_VisibleFlags(uint64_t player) {
    uint64_t arr = ReadAddr<uint64_t>(player + kVisibleObj);
    return isVaildPtr(arr) ? ReadAddr<uint32_t>(arr + kVisibleObjFlags) : 0;
}
bool get_IsVisible(uint64_t p)                      { return isVaildPtr(p) && (get_VisibleFlags(p) & kISVisibleDynamicPVS) != 0; }
bool get_IsVisibleByFlag(uint64_t p, uint32_t flag) { return isVaildPtr(p) && (get_VisibleFlags(p) & flag) != 0; }
bool get_IsFPPVisible(uint64_t p)                   { return isVaildPtr(p) && (get_VisibleFlags(p) & kISVisibleFPPMask) == kISVisibleFPPMask; }
bool get_IsFiring(uint64_t p)   { return isVaildPtr(p) && GetDataUInt16(p, 21) == 2; }
bool get_IsScoping(uint64_t p)  { return isVaildPtr(p) && GetDataUInt16(p, 12) != 0; }

// ─── Main ESP Render ──────────────────────────
- (ESPFrameStats)renderESPWithBuffers:(ESPGeometryBuffers *)buffers
                            viewWidth:(CGFloat)vw viewHeight:(CGFloat)vh
                        matrixVpWidth:(CGFloat)vpW matrixVpHeight:(CGFloat)vpH {

    ESPFrameStats stats = {0, false};
    if (!buffers || Moudule_Base == -1 || IsAtLobby(Moudule_Base)) return stats;

    cacheRefreshTick++;
    if (cacheRefreshTick > 30 ||
        !isVaildPtr(cachedMatchGame) || !isVaildPtr(cachedMatch) || !isVaildPtr(cachedCamera)) {
        cachedMatchGame = getMatchGame(Moudule_Base);
        if (!isVaildPtr(cachedMatchGame)) return stats;
        cachedCamera     = CameraMain(cachedMatchGame);
        cachedMatch      = getMatch(cachedMatchGame);
        cacheRefreshTick = 0;
    }
    if (!isVaildPtr(cachedCamera) || !isVaildPtr(cachedMatch)) return stats;

    uint64_t myPawn = getLocalPlayer(cachedMatch);
    if (!isVaildPtr(myPawn) || get_CurHP(myPawn) <= 0) return stats;

    stats.inMatch = true;

    uint64_t camTransform = ReadAddr<uint64_t>(myPawn + kMainCameraTransform);
    if (!isVaildPtr(camTransform)) return stats;
    Vector3 myLoc = getPositionExt(camTransform);

    uint64_t playerDict = ReadAddr<uint64_t>(cachedMatch + kMatchPlayerDict);
    if (!isVaildPtr(playerDict)) return stats;

    int      dictCount  = ReadAddr<int>(playerDict + kDictCount);
    uint64_t entriesArr = ReadAddr<uint64_t>(playerDict + kDictEntries);
    if (!isVaildPtr(entriesArr)) return stats;

    int slotCap = ReadAddr<int>(entriesArr + kIl2CppArrayMaxLength);
    if (slotCap <= 0 || slotCap > 256 || dictCount <= 0) return stats;

    float *matrix = GetViewMatrix(cachedCamera);
    if (!matrix) return stats;

    CGFloat screenVpW = vpW > 1.0 ? vpW : vw;
    CGFloat screenVpH = vpH > 1.0 ? vpH : vh;
    CGPoint center    = CGPointMake(vw / 2.0f, vh / 2.0f);
    
    // Tọa độ bắt đầu của Line (Giữa đỉnh màn hình)
    CGPoint topCenter = CGPointMake(vw / 2.0f, 0.0f);

    uint64_t bestTarget   = 0;
    Vector3  bestHeadPos;
    float    bestScore    = FLT_MAX;
    float    bestDistance = FLT_MAX;
    bool     bestVisible  = false;

    const float aimFovSq  = isAimbot ? aimFov * aimFov : 0.0f;
    const float safeDist  = fmaxf(aimDistance, 1.0f);
    const float safeFovSq = fmaxf(aimFovSq, 1.0f);
    const uint64_t base   = entriesArr + kIl2CppArrayItems;

    for (int i = 0; i < slotCap; i++) {
        uint64_t ent = base + (uint64_t)kDictEntryStrideBytePlayer * (uint64_t)i;
        if (ReadAddr<int>(ent) == 0) continue;

        uint64_t pawn = ReadAddr<uint64_t>(ent + (uint64_t)kDictEntryValueOffByte);
        if (!isVaildPtr(pawn) || isLocalTeamMate(myPawn, pawn)) continue;

        int hp = get_CurHP(pawn);
        if (hp <= 0) continue;

        Vector3 footPos = getPositionExt(getHip(pawn));
        if (IsZeroVec(footPos)) continue;

        float dis = Vector3::Distance(myLoc, footPos);
        if (dis > 400.0f) continue;

        Vector3 headPos  = getPositionExt(getHead(pawn));
        Vector3 aimPos   = GetAimTargetPos(headPos, footPos, aimPosition);
        bool    isBot    = get_IsBot(pawn);
        bool    isKnocked = get_IsKnockedDown(pawn);
        bool    visFPP   = get_IsFPPVisible(pawn);
        bool    visCam   = get_IsVisibleByFlag(pawn, kISVisibleCamera);
        bool    aimVis   = visFPP && (!isAimCheckVisible || visCam);
        bool    espVis   = visFPP || isKnocked;

        // ── AIMBOT ──
        if (isAimbot && dis <= aimDistance) {
            BOOL valid = YES;
            if (isAimIgnoreBot    && isBot)      valid = NO;
            if (isAimIgnoreKnock  && isKnocked)  valid = NO;
            if (isAimCheckVisible && !aimVis)    valid = NO;

            if (valid) {
                Vector3 w2s = WorldToScreenLayer(aimPos, matrix,
                                                 (float)screenVpW, (float)screenVpH,
                                                 (float)vw, (float)vh);
                if (w2s.z > 0.001f) {
                    float dx = w2s.x - center.x;
                    float dy = w2s.y - center.y;
                    float dSq = dx * dx + dy * dy;

                    if (dSq <= aimFovSq) {
                        float cn = dSq / safeFovSq;
                        float dn = dis  / safeDist;
                        float score;

                        if (aimTargetMode == 0)
                            score = cn * 0.85f + dn * 0.15f;
                        else if (aimTargetMode == 1)
                            score = fminf((float)hp / 200.0f, 1.5f) * 0.65f
                                    + cn * 0.25f + dn * 0.10f;
                        else
                            score = dn * 0.75f + cn * 0.25f;

                        if (pawn == gAimLockTarget) score *= 0.80f;

                        if (score < bestScore) {
                            bestScore    = score;
                            bestDistance = dis;
                            bestVisible  = aimVis;
                            bestTarget   = pawn;
                            bestHeadPos  = aimPos;
                        }
                    }
                }
            }
        }

        // ── ESP ──
        if (espVis) {
            stats.enemyCount++;

            Vector3 sHead = WorldToScreenLayer(headPos, matrix,
                                               (float)screenVpW, (float)screenVpH,
                                               (float)vw, (float)vh);
            Vector3 sFoot = WorldToScreenLayer(footPos, matrix,
                                               (float)screenVpW, (float)screenVpH,
                                               (float)vw, (float)vh);

            if (sHead.z > 0.001f && sFoot.z > 0.001f) {
                CGFloat bodyH = fabs(sHead.y - sFoot.y);

                if (bodyH < 12.0f) {
                    bodyH = 12.0f;
                }

                CGFloat headSize = bodyH * 0.18f;
                CGFloat hH = bodyH + headSize;
                CGFloat hW = bodyH * 0.50f;

                CGRect rect = CGRectMake(
                    sHead.x - hW / 2.0f,
                    sHead.y - headSize * 0.5f,
                    hW, hH
                );

                // ── Box ──
                if (isBox) {
                    ESPAddBox(buffers->boxPath, rect);
                    buffers->boxDirty = YES;
                }
                
                // ── Line (Kéo từ giữa trên cùng xuống đầu địch) ──
                if (isLine) {
                    CGPoint targetPoint = CGPointMake(sHead.x, rect.origin.y);
                    ESPAddSnapline(buffers->snaplinePath, topCenter, targetPoint);
                    buffers->snaplineDirty = YES;
                }

                // ── Thanh máu ──
                if (isHealth) {
                    ESPAddHealthBar(buffers->hpBackgroundPath, buffers->hpFillPath,
                                    rect, (float)hp / 200.0f);
                    buffers->hpBackgroundDirty = YES;
                    buffers->hpFillDirty       = YES;
                }

                // ── Khoảng cách ──
                if (isDis) {
                    CGRect disFrame = CGRectMake(
                        rect.origin.x,
                        CGRectGetMaxY(rect) + 1.0f,
                        rect.size.width, 9.0f
                    );
                    [self addText:[NSString stringWithFormat:@"%dm", (int)dis]
                            frame:disFrame
                            color:[UIColor colorWithWhite:1.0f alpha:0.70f]
                         fontSize:7.0f leftAligned:NO];
                }
            }

            // Tạm thời tắt line ở hàm C++ để tránh vẽ đè line cũ
            bool sv_box = isBox, sv_hp = isHealth, sv_name = isName, sv_dis = isDis, sv_line = isLine;
            isBox = isHealth = isName = isDis = isLine = NO;

            RenderESPForPawn(buffers,
                             ESPTextCallback,
                             (__bridge void *)self,
                             pawn, hp, dis, matrix,
                             (float)vw, (float)vh,
                             (float)screenVpW, (float)screenVpH);

            isBox = sv_box; isHealth = sv_hp; isName = sv_name; isDis = sv_dis; isLine = sv_line;
        }
    }

    // ── Aim Lock Tracking ──
    if (!isAimbot) {
        gAimLockTarget = gAimLockLostFrames = 0;
    } else if (bestTarget) {
        gAimLockTarget     = bestTarget;
        gAimLockLostFrames = 0;
    } else if (gAimLockTarget) {
        if (++gAimLockLostFrames > kAimLockMaxLostFrames)
            gAimLockTarget = gAimLockLostFrames = 0;
    }

    // ── Aimbot Apply ──
    if (isAimbot && bestTarget && (!isAimCheckVisible || bestVisible)) {
        bool fire  = get_IsFiring(myPawn);
        bool scope = get_IsScoping(myPawn);
        bool go    = true;

        switch (triggerMode) {
            case 1: go = fire;         break;
            case 2: go = scope;        break;
            case 3: go = fire || scope; break;
            default: break;
        }

        if (go && bestDistance >= 0.2f) {
            float yBias = (aimPosition == 0) ? 0.1f : (aimPosition == 1 ? 0.05f : 0.0f);
            set_aim(myPawn, GetRotationToLocation(bestHeadPos, yBias, myLoc), bestDistance);
            if (triggerMode == 1 || (triggerMode == 3 && fire))
                SetDataUInt16(myPawn, 21, 2);
        }
    }

    return stats;
}

@end

// ─────────────────────────────────────────────
// MARK: - ESPOverlayView
// ─────────────────────────────────────────────
@implementation ESPOverlayView {
    ESP_View *_espView;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    for (UIView *v in self.subviews) [v removeFromSuperview];
    self.backgroundColor        = UIColor.clearColor;
    self.userInteractionEnabled = NO;

    _espView = [[ESP_View alloc] initWithFrame:self.bounds];
    _espView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_espView];
    return self;
}

@end