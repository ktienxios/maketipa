#import "ModMenuViewController.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/ESPPrefs.h"
#import "../esp/drawing_view/menu.h"
#import "../mahoa.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ─────────────────────────────────────────────
// MARK: - LAYOUT CONSTANTS
// ─────────────────────────────────────────────
static const CGFloat kSidebarWidth    = 62.0f;
static const CGFloat kTabIconSize     = 42.0f;
static const CGFloat kTabSpacing      = 14.0f;
static const CGFloat kSeparatorPadding = 16.0f;
static const CGFloat kPanelWidth      = 390.0f;
static const CGFloat kPanelHeight     = 340.0f;
static const CGFloat kHeaderHeight    = 52.0f;
static const CGFloat kRowHeight       = 46.0f;
static const CGFloat kScrollBarWidth  = 3.0f;
static const CGFloat kTabStartY       = 22.0f;

// ─────────────────────────────────────────────
// MARK: - COLOUR PALETTE  (Clean White)
//   Background  #F4F6F9  light grey-white
//   Surface     #FFFFFF  pure white cards
//   Surface2    #EEF1F5  slightly deeper
//   SidebarBG   #F0F2F6  sidebar tint
//   Border      #00000010 soft hairline
//   Accent      #2563EB  vivid blue
//   AccentSoft  #3B82F6  lighter blue
//   Text        #0F172A  near-black
//   TextMuted   #94A3B8  slate-400
//   Danger      #EF4444  red
// ─────────────────────────────────────────────
#define kColorBG         [UIColor colorWithRed:0.957f green:0.965f blue:0.976f alpha:1.0f]
#define kColorSurface    [UIColor colorWithWhite:1.0f alpha:1.0f]
#define kColorSurface2   [UIColor colorWithRed:0.933f green:0.945f blue:0.961f alpha:1.0f]
#define kColorSidebarBG  [UIColor colorWithRed:0.941f green:0.949f blue:0.965f alpha:1.0f]
#define kColorBorder     [UIColor colorWithWhite:0.0f alpha:0.07f]
#define kColorAccent     [UIColor colorWithRed:0.145f green:0.388f blue:0.922f alpha:1.0f]
#define kColorAccentSoft [UIColor colorWithRed:0.231f green:0.510f blue:0.965f alpha:1.0f]
#define kColorAccentBg   [UIColor colorWithRed:0.145f green:0.388f blue:0.922f alpha:0.08f]
#define kColorText       [UIColor colorWithRed:0.059f green:0.090f blue:0.165f alpha:1.0f]
#define kColorMuted      [UIColor colorWithRed:0.580f green:0.639f blue:0.722f alpha:1.0f]
#define kColorDanger     [UIColor colorWithRed:0.937f green:0.267f blue:0.267f alpha:1.0f]
#define kColorDangerSurf [UIColor colorWithRed:1.0f   green:0.929f blue:0.929f alpha:1.0f]

// Legacy accent RGB — updated to blue
static const CGFloat kAccentR = 0.145f, kAccentG = 0.388f, kAccentB = 0.922f;

static const NSInteger kSegmentTrackTag = 9101;
static const NSInteger kSegmentLabelTag = 9201;

typedef NS_ENUM(NSInteger, MenuTab) {
    MenuTabESP    = 0,
    MenuTabAimbot = 1
};

// ─────────────────────────────────────────────
// MARK: - HELPERS
// ─────────────────────────────────────────────

/// Apply a consistent "card" appearance to any UIView.
static void ApplyCardStyle(UIView *v, BOOL elevated) {
    v.backgroundColor    = elevated ? kColorSurface2 : kColorSurface;
    v.layer.cornerRadius = 10.0f;
    v.layer.borderWidth  = 0.5f;
    v.layer.borderColor  = [UIColor colorWithWhite:1.0f alpha:0.07f].CGColor;
    // Subtle inner-shadow effect via shadow on the layer
    v.layer.shadowColor   = [UIColor blackColor].CGColor;
    v.layer.shadowOpacity = 0.35f;
    v.layer.shadowRadius  = 6.0f;
    v.layer.shadowOffset  = CGSizeMake(0, 2);
    v.layer.masksToBounds = NO; // allow shadow
}

/// Accent gradient layer (left→right) sized to a given rect.
static CAGradientLayer *AccentGradientLayer(CGRect rect) {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame      = rect;
    g.colors     = @[
        (id)[UIColor colorWithRed:1.0f green:0.306f blue:0.165f alpha:1.0f].CGColor,
        (id)[UIColor colorWithRed:1.0f green:0.180f blue:0.100f alpha:1.0f].CGColor
    ];
    g.startPoint = CGPointMake(0, 0.5f);
    g.endPoint   = CGPointMake(1, 0.5f);
    g.cornerRadius = rect.size.height / 2.0f;
    return g;
}


@interface ModMenuViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, assign) MenuTab currentTab;
@property (nonatomic, strong) UIView *floatingPanel;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, strong) UIButton *headerButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) NSInteger trackingPointerId;
@property (nonatomic, assign) BOOL touchOnClose;
@property (nonatomic, assign) BOOL touchOnExitHUD;
@property (nonatomic, assign) BOOL menuDragging;
@property (nonatomic, assign) CGPoint menuDragStartCenter;
@property (nonatomic, assign) CGPoint menuDragStartPoint;
@property (nonatomic, weak)   UISwitch *activeSwitch;
@property (nonatomic, strong) UIView *scrollbarTrack;
@property (nonatomic, strong) UIView *scrollbarThumb;
@property (nonatomic, assign) BOOL scrollbarDragging;
@property (nonatomic, weak)   UISlider *sliderTracking;
@property (nonatomic, weak)   UIView *segmentedRowTracking;
@property (nonatomic, assign) CGFloat scrollbarDragStartY;
@property (nonatomic, assign) CGFloat scrollbarDragStartOffsetY;
@end

@implementation ModMenuViewController

// ─────────────────────────────────────────────
// MARK: - Lifecycle
// ─────────────────────────────────────────────

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.multipleTouchEnabled = YES;

    _trackingPointerId = -1;
    _currentTab        = MenuTabESP;
    _tabButtons        = [NSMutableArray array];

    [self setupFloatingPanel];
    [self setupSidebar];
    [self setupHeaderBar];
    [self setupContentArea];

    [self updateHeaderForTab:_currentTab];
    [self loadTabContent:_currentTab];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleOutsideTap:)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
}

- (CGPoint)loadPanelPosition {
    CGFloat x = [[NSUserDefaults standardUserDefaults] floatForKey:@"FloatingPanelX"];
    CGFloat y = [[NSUserDefaults standardUserDefaults] floatForKey:@"FloatingPanelY"];
    if (x <= 0 && y <= 0) {
        CGRect screen = [UIScreen mainScreen].bounds;
        x = screen.size.width - kPanelWidth - 24.0f;
        y = 80.0f;
    }
    return CGPointMake(x, y);
}

// ─────────────────────────────────────────────
// MARK: - Panel Shell
// ─────────────────────────────────────────────

- (void)setupFloatingPanel {
    _floatingPanel = [[UIView alloc] initWithFrame:CGRectMake(50, 50, kPanelWidth, kPanelHeight)];
    _floatingPanel.backgroundColor  = kColorBG;
    _floatingPanel.layer.cornerRadius = 16.0f;
    _floatingPanel.layer.borderWidth  = 0.5f;
    _floatingPanel.layer.borderColor  = [UIColor colorWithWhite:1.0f alpha:0.10f].CGColor;
    _floatingPanel.clipsToBounds      = YES;

    // Outer shadow (soft, natural for light UI)
    _floatingPanel.layer.shadowColor   = [UIColor colorWithWhite:0.0f alpha:0.18f].CGColor;
    _floatingPanel.layer.shadowOpacity = 1.0f;
    _floatingPanel.layer.shadowRadius  = 24.0f;
    _floatingPanel.layer.shadowOffset  = CGSizeMake(0, 8);
    _floatingPanel.layer.masksToBounds = NO;
    _floatingPanel.layer.borderColor   = [UIColor colorWithWhite:0.0f alpha:0.07f].CGColor;

    // Thin top-edge accent line (blue)
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, 2.0f)];
    CAGradientLayer *lineGrad = [CAGradientLayer layer];
    lineGrad.frame  = topLine.bounds;
    lineGrad.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor colorWithRed:0.145f green:0.388f blue:0.922f alpha:0.8f].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    lineGrad.startPoint = CGPointMake(0, 0.5f);
    lineGrad.endPoint   = CGPointMake(1, 0.5f);
    [topLine.layer addSublayer:lineGrad];
    [_floatingPanel addSubview:topLine];

    [self.view addSubview:_floatingPanel];
}

// ─────────────────────────────────────────────
// MARK: - Sidebar
// ─────────────────────────────────────────────

- (void)setupSidebar {
    UIView *sidebarContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSidebarWidth, kPanelHeight)];
    sidebarContainer.backgroundColor = kColorSidebarBG;
    sidebarContainer.clipsToBounds = YES;
    [_floatingPanel addSubview:sidebarContainer];

    NSArray *icons = @[ @"eye.fill", @"scope" ];
    CGFloat startY = kTabStartY;

    for (NSInteger i = 0; i < icons.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat btnX = (kSidebarWidth - kTabIconSize) / 2.0f;
        CGFloat btnY = startY + (i * (kTabIconSize + kTabSpacing));
        btn.frame = CGRectMake(btnX, btnY, kTabIconSize, kTabIconSize);
        btn.layer.cornerRadius = kTabIconSize / 2.0f;
        btn.tag = (NSInteger)i;

        BOOL active = (i == _currentTab);
        if (active) {
            btn.backgroundColor = kColorAccentBg;
            btn.layer.borderWidth = 1.0f;
            btn.layer.borderColor = [UIColor colorWithRed:0.145f green:0.388f blue:0.922f alpha:0.35f].CGColor;
        } else {
            btn.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.04f];
            btn.layer.borderWidth = 1.0f;
            btn.layer.borderColor = [UIColor colorWithWhite:0.0f alpha:0.07f].CGColor;
        }

        UIImage *img = [UIImage systemImageNamed:icons[i]];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:18
                                                               weight:UIImageSymbolWeightSemibold];
            img = [img imageByApplyingSymbolConfiguration:cfg];
        }
        [btn setImage:img forState:UIControlStateNormal];
        btn.tintColor = active ? kColorAccent : kColorMuted;

        [btn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [sidebarContainer addSubview:btn];
        [_tabButtons addObject:btn];
    }

    // Separator — subtle vertical line
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(kSidebarWidth - 1, kSeparatorPadding,
                                                           1, kPanelHeight - kSeparatorPadding * 2)];
    sep.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.07f];
    [_floatingPanel addSubview:sep];
}

// ─────────────────────────────────────────────
// MARK: - Header Bar
// ─────────────────────────────────────────────

- (void)setupHeaderBar {
    // Header background strip
    UIView *headerBG = [[UIView alloc] initWithFrame:CGRectMake(kSidebarWidth, 0,
                                                                kPanelWidth - kSidebarWidth, kHeaderHeight)];
    headerBG.backgroundColor = kColorSurface;
    [_floatingPanel addSubview:headerBG];

    // Bottom border of header
    UIView *hLine = [[UIView alloc] initWithFrame:CGRectMake(0, kHeaderHeight - 1,
                                                              kPanelWidth - kSidebarWidth, 1)];
    hLine.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.06f];
    [headerBG addSubview:hLine];

    // Draggable header button (invisible tap region + title)
    CGFloat headerButtonWidth = kPanelWidth - kSidebarWidth - 52;
    _headerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _headerButton.frame = CGRectMake(kSidebarWidth, 0, headerButtonWidth, kHeaderHeight);
    _headerButton.backgroundColor = [UIColor clearColor];
    [_floatingPanel addSubview:_headerButton];

    // Icon badge
    UIView *iconBadge = [[UIView alloc] initWithFrame:CGRectMake(14, 12, 28, 28)];
    iconBadge.backgroundColor = kColorAccentBg;
    iconBadge.layer.cornerRadius = 8.0f;
    iconBadge.layer.borderWidth  = 0.5f;
    iconBadge.layer.borderColor  = [UIColor colorWithRed:0.145f green:0.388f blue:0.922f alpha:0.3f].CGColor;

    UIImageView *headerIcon = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, 18, 18)];
    UIImage *scopeImg = [UIImage systemImageNamed:@"scope"];
    if (@available(iOS 13.0, *)) {
        scopeImg = [scopeImg imageByApplyingSymbolConfiguration:
                    [UIImageSymbolConfiguration configurationWithPointSize:14
                                                                    weight:UIImageSymbolWeightBold]];
    }
    headerIcon.image       = scopeImg;
    headerIcon.tintColor   = kColorAccent;
    headerIcon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:headerIcon];
    [_headerButton addSubview:iconBadge];

    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 0, headerButtonWidth - 58, kHeaderHeight)];
    titleLabel.tag           = 2002;
    titleLabel.font          = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    titleLabel.textColor     = kColorText;
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [_headerButton addSubview:titleLabel];

    // Sub-label "TACTICAL SUITE"
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 30, headerButtonWidth - 58, 14)];
    subLabel.font      = [UIFont systemFontOfSize:9 weight:UIFontWeightMedium];
    subLabel.textColor = kColorMuted;
    NSMutableAttributedString *subAS =
        [[NSMutableAttributedString alloc] initWithString:@"TACTICAL SUITE"];
    [subAS addAttribute:NSKernAttributeName value:@(2.0) range:NSMakeRange(0, subAS.length)];
    subLabel.attributedText = subAS;
    [_headerButton addSubview:subLabel];

    // Close button
    CGFloat btnSize = 32.0f;
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.frame           = CGRectMake(kPanelWidth - 44, (kHeaderHeight - btnSize) / 2, btnSize, btnSize);
    _closeButton.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.05f];
    _closeButton.layer.cornerRadius = btnSize / 2.0f;
    _closeButton.layer.borderWidth  = 0.5f;
    _closeButton.layer.borderColor  = [UIColor colorWithWhite:1.0f alpha:0.10f].CGColor;

    UIImage *closeImg = [UIImage systemImageNamed:@"xmark"];
    if (@available(iOS 13.0, *)) {
        closeImg = [closeImg imageByApplyingSymbolConfiguration:
                    [UIImageSymbolConfiguration configurationWithPointSize:11
                                                                    weight:UIImageSymbolWeightBold]];
    }
    [_closeButton setImage:closeImg forState:UIControlStateNormal];
    _closeButton.tintColor = kColorMuted;

    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_floatingPanel addSubview:_closeButton];
}

// ─────────────────────────────────────────────
// MARK: - Content Area
// ─────────────────────────────────────────────

- (void)setupContentArea {
    CGFloat contentWidth  = kPanelWidth - kSidebarWidth;
    CGFloat contentHeight = kPanelHeight - kHeaderHeight;
    CGFloat scrollWidth   = contentWidth - kScrollBarWidth - 4;

    UIView *contentClipView = [[UIView alloc] initWithFrame:CGRectMake(kSidebarWidth, kHeaderHeight,
                                                                        contentWidth, contentHeight)];
    contentClipView.backgroundColor = [UIColor clearColor];
    contentClipView.clipsToBounds   = YES;
    contentClipView.tag             = 4000;
    [_floatingPanel addSubview:contentClipView];

    _contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, scrollWidth, contentHeight)];
    _contentScrollView.backgroundColor           = [UIColor clearColor];
    _contentScrollView.showsVerticalScrollIndicator = NO;
    _contentScrollView.bounces                   = YES;
    [contentClipView addSubview:_contentScrollView];

    _contentContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, scrollWidth, contentHeight)];
    _contentContainer.backgroundColor = [UIColor clearColor];
    [_contentScrollView addSubview:_contentContainer];

    // Scrollbar track
    _scrollbarTrack = [[UIView alloc] initWithFrame:CGRectMake(scrollWidth + 2, 6,
                                                                kScrollBarWidth, contentHeight - 12)];
    _scrollbarTrack.backgroundColor  = [UIColor colorWithWhite:1.0f alpha:0.06f];
    _scrollbarTrack.layer.cornerRadius = kScrollBarWidth / 2.0f;
    _scrollbarTrack.tag = 5000;
    [contentClipView addSubview:_scrollbarTrack];

    // Scrollbar thumb
    _scrollbarThumb = [[UIView alloc] initWithFrame:CGRectMake(scrollWidth + 2, 6,
                                                                kScrollBarWidth, 40.0f)];
    _scrollbarThumb.backgroundColor  = kColorAccent;
    _scrollbarThumb.layer.cornerRadius = kScrollBarWidth / 2.0f;
    _scrollbarThumb.layer.shadowColor   = [UIColor colorWithRed:1.0f green:0.306f blue:0.165f alpha:0.6f].CGColor;
    _scrollbarThumb.layer.shadowOpacity = 1.0f;
    _scrollbarThumb.layer.shadowRadius  = 3.0f;
    _scrollbarThumb.layer.shadowOffset  = CGSizeMake(0, 0);
    _scrollbarThumb.tag = 5001;
    [contentClipView addSubview:_scrollbarThumb];
}

// ─────────────────────────────────────────────
// MARK: - Scrollbar Layout  (logic unchanged)
// ─────────────────────────────────────────────

- (void)updateScrollbarLayout {
    CGFloat contentH = _contentScrollView.contentSize.height;
    CGFloat viewH    = _contentScrollView.bounds.size.height;
    if (contentH <= viewH || viewH <= 0) {
        _scrollbarTrack.hidden = YES;
        _scrollbarThumb.hidden = YES;
        return;
    }
    _scrollbarTrack.hidden = NO;
    _scrollbarThumb.hidden = NO;

    CGFloat maxOffset  = contentH - viewH;
    CGFloat thumbHeight = viewH * (viewH / contentH);
    if (thumbHeight < 40.0f) thumbHeight = 40.0f;
    if (thumbHeight > viewH - 4.0f) thumbHeight = viewH - 4.0f;

    CGFloat trackH  = viewH;
    CGFloat range   = trackH - thumbHeight;
    CGFloat offsetY = _contentScrollView.contentOffset.y;
    CGFloat thumbY  = (range > 0) ? (offsetY / maxOffset) * range : 0;
    if (thumbY < 0) thumbY = 0;
    if (thumbY > range) thumbY = range;

    _scrollbarThumb.frame = CGRectMake(_scrollbarThumb.frame.origin.x,
                                        thumbY,
                                        kScrollBarWidth, thumbHeight);
}

// ─────────────────────────────────────────────
// MARK: - Header / Sidebar Updates  (logic unchanged)
// ─────────────────────────────────────────────

- (void)updateHeaderForTab:(MenuTab)tab {
    UILabel *titleLabel = [_headerButton viewWithTag:2002];
    NSMutableAttributedString *as =
        [[NSMutableAttributedString alloc] initWithString:@"MinhiOS VN NEW_Version 1.123.1 TiPA"];
    [as addAttribute:NSKernAttributeName value:@(1.5) range:NSMakeRange(0, as.length)];
    titleLabel.attributedText = as;
}

- (void)updateSidebarForTab:(MenuTab)tab {
    for (NSInteger i = 0; i < (NSInteger)_tabButtons.count; i++) {
        UIButton *btn    = _tabButtons[i];
        BOOL     active  = (i == tab);
        btn.tintColor    = active ? kColorAccent : kColorMuted;
        btn.backgroundColor = active
            ? [UIColor colorWithRed:1.0f green:0.306f blue:0.165f alpha:0.18f]
            : [UIColor colorWithWhite:1.0f alpha:0.04f];
        btn.layer.borderColor = active
            ? [UIColor colorWithRed:1.0f green:0.306f blue:0.165f alpha:0.45f].CGColor
            : [UIColor colorWithWhite:1.0f alpha:0.06f].CGColor;
    }
}

// ─────────────────────────────────────────────
// MARK: - Tab Content  (logic unchanged, styling updated)
// ─────────────────────────────────────────────

- (void)loadTabContent:(MenuTab)tab {
    for (UIView *v in _contentContainer.subviews) { [v removeFromSuperview]; }

    NSArray *rows = nil;
    if (tab == MenuTabESP) {
        rows = @[
            @[ @"Box",      @"Box"   ],
            @[ @"Bone",     @"Bone"  ],
            @[ @"Health",   @"Health"],
            @[ @"Name",     @"Name"  ],
            @[ @"Distance", @"Dis"   ],
            @[ @"Line",     @"Line"  ],
            @[ @"ESP Bot",  (NSString *)NSSENCRYPT("EspBot") ],
            @[ @"Exit HUD", @"__exit_hud__" ],
        ];
    } else {
        rows = @[
            @[ @"Aimbot",             @"Aimbot"            ],
            @[ @"Ignore Bot",         @"AimIgnoreBot"      ],
            @[ @"Ignore Knock",       @"AimIgnoreKnock"    ],
            @[ @"Check Visible",      @"AimCheckVisible"   ],
            @[ @"Rage Mode",          @"AimRage"           ],
            @[ @"Line Aim",           @"LineAim"           ],
            @[ @"Float AIM Button",   (NSString *)NSSENCRYPT("FloatAimBtn")    ],
            @[ @"Float Mode Button",  (NSString *)NSSENCRYPT("FloatModeBtn")   ],
            @[ @"Float Target Button",(NSString *)NSSENCRYPT("FloatTargetBtn") ],
        ];
    }

    CGFloat y            = 10.0f;
    CGFloat contentWidth = _contentContainer.bounds.size.width;

    for (NSArray *row in rows) {
        NSString *title = row[0];
        NSString *key   = row[1];

        // ── Exit HUD row ──────────────────────────
        if ([key isEqualToString:@"__exit_hud__"]) {
            UIView *rowView = [[UIView alloc] initWithFrame:CGRectMake(8, y,
                                                                        contentWidth - 16, kRowHeight)];
            rowView.backgroundColor  = kColorDangerSurf;
            rowView.layer.cornerRadius = 10.0f;
            rowView.layer.borderWidth  = 0.5f;
            rowView.layer.borderColor  = [UIColor colorWithRed:0.780f green:0.090f blue:0.090f alpha:0.5f].CGColor;
            objc_setAssociatedObject(rowView, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, contentWidth - 24, kRowHeight)];
            lbl.text      = title;
            lbl.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
            lbl.textColor = kColorAccent;

            NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:title];
            [as addAttribute:NSKernAttributeName value:@(0.5) range:NSMakeRange(0, as.length)];
            lbl.attributedText = as;
            [rowView addSubview:lbl];
            [_contentContainer addSubview:rowView];
            y += kRowHeight + 5.0f;
            continue;
        }

        // ── Normal toggle row ──────────────────────
        UIView *rowView = [[UIView alloc] initWithFrame:CGRectMake(8, y,
                                                                    contentWidth - 16, kRowHeight)];
        rowView.backgroundColor  = kColorSurface;
        rowView.layer.cornerRadius = 10.0f;
        rowView.layer.borderWidth  = 0.5f;
        rowView.layer.borderColor  = [UIColor colorWithWhite:1.0f alpha:0.06f].CGColor;
        objc_setAssociatedObject(rowView, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, contentWidth - 90, kRowHeight)];
        lbl.text      = title;
        lbl.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        lbl.textColor = kColorText;
        [rowView addSubview:lbl];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(contentWidth - 16 - 51,
                                                                   (kRowHeight - 31) / 2, 51, 31)];
        sw.onTintColor = kColorAccent;
        sw.transform   = CGAffineTransformMakeScale(0.85f, 0.85f);

        BOOL on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
        if ([[NSUserDefaults standardUserDefaults] objectForKey:key] == nil) {
            on = ([key isEqualToString:(NSString *)NSSENCRYPT("FloatAimBtn")] ||
                  [key isEqualToString:(NSString *)NSSENCRYPT("FloatModeBtn")] ||
                  [key isEqualToString:(NSString *)NSSENCRYPT("FloatTargetBtn")]);
        }
        sw.on = on;

        // Highlight active rows
        if (on) {
            rowView.backgroundColor = [UIColor colorWithRed:1.0f green:0.306f blue:0.165f alpha:0.07f];
            rowView.layer.borderColor = [UIColor colorWithRed:1.0f green:0.306f blue:0.165f alpha:0.20f].CGColor;
        }

        objc_setAssociatedObject(sw, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        [rowView addSubview:sw];
        [_contentContainer addSubview:rowView];
        y += kRowHeight + 5.0f;
    }

    // ── Aimbot extras ──────────────────────────────
    if (tab == MenuTabAimbot) {
        CGFloat rowW = contentWidth - 16;

        // Section divider
        y += 4;
        UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(8, y, rowW, 1)];
        divider.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.06f];
        [_contentContainer addSubview:divider];
        UILabel *sectionLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, y + 8, rowW, 16)];
        NSMutableAttributedString *secAS = [[NSMutableAttributedString alloc] initWithString:@"CONFIGURATION"];
        [secAS addAttribute:NSKernAttributeName value:@(2.0) range:NSMakeRange(0, secAS.length)];
        sectionLbl.attributedText = secAS;
        sectionLbl.font      = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
        sectionLbl.textColor = kColorMuted;
        [_contentContainer addSubview:sectionLbl];
        y += 30;

        y = [self addSegmentedComboRowWithTitle:@"Trigger Mode" key:@"TriggerMode" y:y width:rowW];
        y = [self addSegmentedComboRowWithTitle:@"Aim Position" key:@"AimPos"       y:y width:rowW];
        y = [self addSegmentedComboRowWithTitle:@"Target Mode"  key:@"AimTargetMode" y:y width:rowW];
        y += 6;

        // Section divider
        UIView *div2 = [[UIView alloc] initWithFrame:CGRectMake(8, y, rowW, 1)];
        div2.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.06f];
        [_contentContainer addSubview:div2];
        UILabel *sec2Lbl = [[UILabel alloc] initWithFrame:CGRectMake(8, y + 8, rowW, 16)];
        NSMutableAttributedString *sec2AS = [[NSMutableAttributedString alloc] initWithString:@"PARAMETERS"];
        [sec2AS addAttribute:NSKernAttributeName value:@(2.0) range:NSMakeRange(0, sec2AS.length)];
        sec2Lbl.attributedText = sec2AS;
        sec2Lbl.font      = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
        sec2Lbl.textColor = kColorMuted;
        [_contentContainer addSubview:sec2Lbl];
        y += 30;

        // FOV slider
        CGFloat fov = ESPPrefsFloat(@"Fov", 150.0f);
        if (fov < 10.0f || fov > 500.0f) fov = 150.0f;
        UILabel *fovLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, y, rowW, 20)];
        fovLbl.text      = [NSString stringWithFormat:@"Aim FOV  —  %.0f px", fov];
        fovLbl.font      = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        fovLbl.textColor = kColorText;
        fovLbl.tag       = 6001;
        [_contentContainer addSubview:fovLbl];
        y += 22;
        UISlider *fovSlider = [[UISlider alloc] initWithFrame:CGRectMake(8, y, rowW, 28)];
        fovSlider.minimumValue        = 10.0f;
        fovSlider.maximumValue        = 500.0f;
        fovSlider.value               = fov;
        fovSlider.minimumTrackTintColor = kColorAccent;
        fovSlider.maximumTrackTintColor = [UIColor colorWithWhite:1.0f alpha:0.08f];
        fovSlider.tag                 = 6002;
        objc_setAssociatedObject(fovSlider, "key",   @"Fov",  OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(fovSlider, "label", fovLbl,  OBJC_ASSOCIATION_ASSIGN);
        [fovSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_contentContainer addSubview:fovSlider];
        y += 36;

        // Distance slider
        CGFloat aimDist = ESPPrefsFloat(@"Distance", 200.0f);
        if (aimDist < 1.0f || aimDist > 400.0f) aimDist = 200.0f;
        UILabel *distLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, y, rowW, 20)];
        distLbl.text      = [NSString stringWithFormat:@"Aim Distance  —  %.0f m", aimDist];
        distLbl.font      = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        distLbl.textColor = kColorText;
        distLbl.tag       = 6003;
        [_contentContainer addSubview:distLbl];
        y += 22;
        UISlider *distSlider = [[UISlider alloc] initWithFrame:CGRectMake(8, y, rowW, 28)];
        distSlider.minimumValue        = 1.0f;
        distSlider.maximumValue        = 400.0f;
        distSlider.value               = aimDist;
        distSlider.minimumTrackTintColor = kColorAccent;
        distSlider.maximumTrackTintColor = [UIColor colorWithWhite:1.0f alpha:0.08f];
        distSlider.tag                 = 6004;
        objc_setAssociatedObject(distSlider, "key",   @"Distance", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(distSlider, "label", distLbl,     OBJC_ASSOCIATION_ASSIGN);
        [distSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_contentContainer addSubview:distSlider];
        y += 36;

        // Speed slider
        CGFloat speedPct = ESPPrefsFloat(@"AimSpeed", 100.0f);
        if (speedPct < 1.0f || speedPct > 100.0f) speedPct = 100.0f;
        UILabel *spdLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, y, rowW, 20)];
        spdLbl.text      = [NSString stringWithFormat:@"Aim Speed  —  %.0f%%", speedPct];
        spdLbl.font      = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        spdLbl.textColor = kColorText;
        spdLbl.tag       = 6005;
        [_contentContainer addSubview:spdLbl];
        y += 22;
        UISlider *spdSlider = [[UISlider alloc] initWithFrame:CGRectMake(8, y, rowW, 28)];
        spdSlider.minimumValue        = 1.0f;
        spdSlider.maximumValue        = 100.0f;
        spdSlider.value               = speedPct;
        spdSlider.minimumTrackTintColor = kColorAccent;
        spdSlider.maximumTrackTintColor = [UIColor colorWithWhite:1.0f alpha:0.08f];
        spdSlider.tag                 = 6006;
        objc_setAssociatedObject(spdSlider, "key",   @"AimSpeed", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(spdSlider, "label", spdLbl,      OBJC_ASSOCIATION_ASSIGN);
        [spdSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [_contentContainer addSubview:spdSlider];
        y += 36;
    }

    _contentContainer.frame      = CGRectMake(0, 0, contentWidth - kScrollBarWidth - 4, y + 14);
    _contentScrollView.contentSize = CGSizeMake(contentWidth - kScrollBarWidth - 4, y + 14);
    [self updateScrollbarLayout];
}

// ─────────────────────────────────────────────
// MARK: - Switch / Slider handlers  (logic unchanged)
// ─────────────────────────────────────────────

- (void)switchChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    if (!key) return;

    BOOL value = sender.isOn;
    ESPPrefsSetBool(key, value);
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    ESPPrefsSync();

    // Update row highlight to match new state
    UIView *rowView = sender.superview;
    if (rowView) {
        rowView.backgroundColor = value
            ? [UIColor colorWithRed:1.0f green:0.306f blue:0.165f alpha:0.07f]
            : kColorSurface;
        rowView.layer.borderColor = value
            ? [UIColor colorWithRed:1.0f green:0.306f blue:0.165f alpha:0.20f].CGColor
            : [UIColor colorWithWhite:1.0f alpha:0.06f].CGColor;
    }

    for (UIView *v = self.view.superview; v; v = v.superview) {
        if ([v isKindOfClass:[MenuView class]]) {
            [(MenuView *)v reloadFloatingAuxButtonsFromPrefs];
            break;
        }
    }
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    if (!key) return;

    float value = sender.value;
    ESPPrefsSetFloat(key, value);
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    ESPPrefsSync();

    UILabel *lbl = objc_getAssociatedObject(sender, "label");
    if (lbl && [key isEqualToString:@"Fov"])
        lbl.text = [NSString stringWithFormat:@"Aim FOV  —  %.0f px", value];
    else if (lbl && [key isEqualToString:@"Distance"])
        lbl.text = [NSString stringWithFormat:@"Aim Distance  —  %.0f m", value];
    else if (lbl && [key isEqualToString:@"AimSpeed"])
        lbl.text = [NSString stringWithFormat:@"Aim Speed  —  %.0f%%", value];
}

// ─────────────────────────────────────────────
// MARK: - Segmented Combo  (logic unchanged, styling updated)
// ─────────────────────────────────────────────

- (NSArray<NSString *> *)comboOptionsForKey:(NSString *)key {
    if ([key isEqualToString:@"TriggerMode"])   return @[ @"Auto", @"Fire", @"Scope", @"Fire/Scope" ];
    if ([key isEqualToString:@"AimPos"])         return @[ @"Head", @"Neck", @"Chest" ];
    if ([key isEqualToString:@"AimTargetMode"]) return @[ @"Gần tâm", @"HP thấp", @"Gần nhất" ];
    return @[];
}

- (void)updateSegmentedRowVisual:(UIView *)row selectedIndex:(int)sel {
    NSArray<UIView *> *cells = objc_getAssociatedObject(row, "segCells");
    if (!cells || cells.count == 0) return;

    for (NSInteger i = 0; i < (NSInteger)cells.count; i++) {
        UIView  *cell = cells[i];
        UILabel *lab  = [cell viewWithTag:kSegmentLabelTag];
        if (i == sel) {
            cell.backgroundColor = kColorAccent;
            cell.layer.cornerRadius = 8.0f;
            if (lab) {
                lab.textColor = [UIColor whiteColor];
                lab.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
            }
        } else {
            cell.backgroundColor = [UIColor clearColor];
            if (lab) {
                lab.textColor = kColorMuted;
                lab.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
            }
        }
    }
}

- (CGFloat)addSegmentedComboRowWithTitle:(NSString *)title key:(NSString *)key
                                       y:(CGFloat)y width:(CGFloat)rowW {
    NSArray<NSString *> *opts = [self comboOptionsForKey:key];
    if (opts.count == 0) return y;

    const CGFloat titleH    = 18.0f;
    const CGFloat pillH     = 32.0f;
    const CGFloat vGap      = 6.0f;
    const CGFloat bottomPad = 6.0f;
    CGFloat rowH = titleH + vGap + pillH + bottomPad;

    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(8, y, rowW, rowH)];
    row.backgroundColor = [UIColor clearColor];
    objc_setAssociatedObject(row, "segComboPrefsKey", key, OBJC_ASSOCIATION_COPY_NONATOMIC);

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(2, 0, rowW - 4, titleH)];
    titleLbl.text      = title;
    titleLbl.font      = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    titleLbl.textColor = kColorMuted;
    [row addSubview:titleLbl];

    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(0, titleH + vGap, rowW, pillH)];
    track.tag                = kSegmentTrackTag;
    track.backgroundColor    = kColorSurface;
    track.layer.cornerRadius = 10.0f;
    track.layer.borderWidth  = 0.5f;
    track.layer.borderColor  = [UIColor colorWithWhite:1.0f alpha:0.07f].CGColor;
    track.clipsToBounds      = YES;
    [row addSubview:track];

    int sel = (int)ESPPrefsFloat(key, 0.0f);
    if (sel < 0 || sel >= (int)opts.count) sel = 0;

    CGFloat segW = rowW / (CGFloat)opts.count;
    NSMutableArray<UIView *> *cells = [NSMutableArray arrayWithCapacity:opts.count];
    for (NSInteger i = 0; i < (NSInteger)opts.count; i++) {
        UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(segW * (CGFloat)i + 2, 2,
                                                                 segW - 4, pillH - 4)];
        cell.layer.cornerRadius = 8.0f;
        cell.userInteractionEnabled = NO;

        UILabel *lab = [[UILabel alloc] initWithFrame:cell.bounds];
        lab.tag             = kSegmentLabelTag;
        lab.text            = opts[i];
        lab.font            = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        lab.textAlignment   = NSTextAlignmentCenter;
        lab.textColor       = kColorMuted;
        lab.adjustsFontSizeToFitWidth = YES;
        lab.minimumScaleFactor = 0.65f;
        lab.numberOfLines   = 1;
        [cell addSubview:lab];
        [track addSubview:cell];
        [cells addObject:cell];
    }
    objc_setAssociatedObject(row, "segCells", cells, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self updateSegmentedRowVisual:row selectedIndex:sel];

    [_contentContainer addSubview:row];
    return y + rowH + 6.0f;
}

- (void)applySegmentedSelectionForRow:(UIView *)row touchInContent:(CGPoint)inContent {
    NSString *key         = objc_getAssociatedObject(row, "segComboPrefsKey");
    NSArray<UIView *> *cells = objc_getAssociatedObject(row, "segCells");
    UIView *track         = [row viewWithTag:kSegmentTrackTag];
    if (!key || !track || cells.count == 0) return;

    CGPoint inRow = CGPointMake(inContent.x - row.frame.origin.x,
                                inContent.y - row.frame.origin.y);
    if (!CGRectContainsPoint(track.frame, inRow)) return;

    CGFloat relX = inRow.x - track.frame.origin.x;
    CGFloat w    = track.bounds.size.width;
    NSInteger n  = (NSInteger)cells.count;
    if (w <= 0 || n <= 0) return;
    NSInteger idx = (NSInteger)(relX / (w / (CGFloat)n));
    if (idx < 0) idx = 0;
    if (idx >= n) idx = n - 1;

    ESPPrefsSetFloat(key, (float)idx);
    ESPPrefsSync();
    ESPSyncFromPrefs();
    [self updateSegmentedRowVisual:row selectedIndex:(int)idx];

    for (UIView *v = self.view.superview; v; v = v.superview) {
        if ([v isKindOfClass:[MenuView class]]) {
            [(MenuView *)v reloadFloatingAuxButtonsFromPrefs];
            break;
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Actions / Touch  (100% logic unchanged)
// ─────────────────────────────────────────────

- (void)tabButtonTapped:(UIButton *)sender {
    MenuTab tab = (MenuTab)sender.tag;
    if (tab == _currentTab) return;
    _currentTab = tab;
    [self updateSidebarForTab:tab];
    [self updateHeaderForTab:tab];
    [self loadTabContent:tab];
}

- (void)closeTapped {
    [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.x forKey:@"FloatingPanelX"];
    [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.y forKey:@"FloatingPanelY"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (self.onCloseBlock) self.onCloseBlock();
}

- (void)handlePanelDrag:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.view];
    if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint center = _floatingPanel.center;
        center.x += translation.x;
        center.y += translation.y;
        _floatingPanel.center = center;
        [pan setTranslation:CGPointZero inView:self.view];
    }
    if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled) {
        [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.x forKey:@"FloatingPanelX"];
        [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.y forKey:@"FloatingPanelY"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)handleOutsideTap:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:self.view];
    if (!CGRectContainsPoint(_floatingPanel.frame, p)) {
        [self closeTapped];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    CGPoint p = [touch locationInView:self.view];
    if (CGRectContainsPoint(_floatingPanel.frame, p)) return NO;
    return YES;
}

- (BOOL)handleTouchAtViewPoint:(CGPoint)point phase:(NSInteger)phase pointerId:(NSInteger)pointerId {
    BOOL insidePanel = CGRectContainsPoint(_floatingPanel.frame, point);
    UITouchPhase ph  = (UITouchPhase)phase;

    if (ph == UITouchPhaseBegan) {
        if (!insidePanel) return NO;
        _trackingPointerId    = pointerId;
        _touchOnClose         = NO;
        _touchOnExitHUD       = NO;
        _menuDragging         = NO;
        _activeSwitch         = nil;
        _segmentedRowTracking = nil;
        CGPoint inPanel = CGPointMake(point.x - _floatingPanel.frame.origin.x,
                                      point.y - _floatingPanel.frame.origin.y);

        if (inPanel.x < kSidebarWidth) {
            CGFloat tabX = (kSidebarWidth - kTabIconSize) / 2.0f;
            for (NSInteger i = 0; i < (NSInteger)_tabButtons.count; i++) {
                CGFloat ty = kTabStartY + ((CGFloat)i * (kTabIconSize + kTabSpacing));
                CGRect tabRect = CGRectMake(tabX, ty, kTabIconSize, kTabIconSize);
                if (CGRectContainsPoint(tabRect, inPanel)) {
                    if (i != (NSInteger)_currentTab)
                        [self tabButtonTapped:_tabButtons[i]];
                    return YES;
                }
            }
            return YES;
        }
        if (inPanel.y < kHeaderHeight) {
            CGRect closeRect = CGRectMake(kPanelWidth - 44, (kHeaderHeight - 32) / 2, 32, 32);
            if (CGRectContainsPoint(CGRectInset(closeRect, -8, -8), inPanel)) {
                _touchOnClose = YES;
            } else {
                _menuDragging         = YES;
                _menuDragStartCenter  = _floatingPanel.center;
                _menuDragStartPoint   = point;
            }
        } else {
            CGFloat contentLeft = kSidebarWidth;
            if (inPanel.x >= (kPanelWidth - kScrollBarWidth - 4)) {
                CGFloat trackY   = inPanel.y - kHeaderHeight;
                CGFloat trackH   = _contentScrollView.bounds.size.height;
                CGFloat contentH = _contentScrollView.contentSize.height;
                CGFloat viewH    = _contentScrollView.bounds.size.height;
                CGFloat maxOffset = contentH - viewH;
                if (maxOffset > 0 && trackH > 0) {
                    CGFloat thumbY = _scrollbarThumb.frame.origin.y;
                    CGFloat thumbH = _scrollbarThumb.frame.size.height;
                    if (trackY >= thumbY && trackY <= thumbY + thumbH) {
                        _scrollbarDragging         = YES;
                        _scrollbarDragStartY        = point.y;
                        _scrollbarDragStartOffsetY  = _contentScrollView.contentOffset.y;
                    } else {
                        CGFloat range = trackH - thumbH;
                        if (range > 0) {
                            CGFloat newOffset = (trackY / trackH) * maxOffset;
                            if (newOffset < 0) newOffset = 0;
                            if (newOffset > maxOffset) newOffset = maxOffset;
                            _contentScrollView.contentOffset = CGPointMake(0, newOffset);
                            [self updateScrollbarLayout];
                        }
                    }
                }
            } else {
                CGPoint inContent = CGPointMake(inPanel.x - contentLeft - 8,
                                                inPanel.y - kHeaderHeight + _contentScrollView.contentOffset.y);
                for (UIView *rowView in _contentContainer.subviews) {
                    if ([rowView isKindOfClass:[UISlider class]] || [rowView isKindOfClass:[UILabel class]]) continue;
                    if (!CGRectContainsPoint(rowView.frame, inContent)) continue;

                    NSString *segKey = objc_getAssociatedObject(rowView, "segComboPrefsKey");
                    if (segKey) {
                        UIView  *track  = [rowView viewWithTag:kSegmentTrackTag];
                        CGPoint inRow   = CGPointMake(inContent.x - rowView.frame.origin.x,
                                                      inContent.y - rowView.frame.origin.y);
                        if (track && CGRectContainsPoint(track.frame, inRow))
                            _segmentedRowTracking = rowView;
                        break;
                    }

                    NSString *rk = objc_getAssociatedObject(rowView, "key");
                    if ([rk isEqualToString:@"__exit_hud__"]) {
                        _touchOnExitHUD = YES;
                    } else {
                        for (UIView *sub in rowView.subviews) {
                            if ([sub isKindOfClass:[UISwitch class]]) {
                                _activeSwitch = (UISwitch *)sub;
                                break;
                            }
                        }
                    }
                    break;
                }
                if (!_activeSwitch && !_touchOnExitHUD) {
                    for (UIView *v in _contentContainer.subviews) {
                        if ([v isKindOfClass:[UISlider class]] && CGRectContainsPoint(v.frame, inContent)) {
                            _sliderTracking = (UISlider *)v;
                            break;
                        }
                    }
                }
            }
        }
        return YES;
    }

    if (ph == UITouchPhaseMoved && pointerId == _trackingPointerId && _sliderTracking) {
        CGPoint inPanel   = CGPointMake(point.x - _floatingPanel.frame.origin.x,
                                        point.y - _floatingPanel.frame.origin.y);
        CGFloat contentLeft = kSidebarWidth;
        CGPoint inContent   = CGPointMake(inPanel.x - contentLeft - 8,
                                          inPanel.y - kHeaderHeight + _contentScrollView.contentOffset.y);
        UISlider *sl = _sliderTracking;
        CGFloat ratio = (inContent.x - sl.frame.origin.x) / sl.frame.size.width;
        if (ratio < 0) ratio = 0;
        if (ratio > 1) ratio = 1;
        sl.value = sl.minimumValue + (float)ratio * (sl.maximumValue - sl.minimumValue);
        [self sliderChanged:sl];
        return YES;
    }

    if (ph == UITouchPhaseMoved && pointerId == _trackingPointerId && _scrollbarDragging) {
        CGFloat contentH  = _contentScrollView.contentSize.height;
        CGFloat viewH     = _contentScrollView.bounds.size.height;
        CGFloat maxOffset = contentH - viewH;
        if (maxOffset <= 0) { _scrollbarDragging = NO; return YES; }
        CGFloat dy        = point.y - _scrollbarDragStartY;
        CGFloat newOffset = _scrollbarDragStartOffsetY + dy;
        if (newOffset < 0) newOffset = 0;
        if (newOffset > maxOffset) newOffset = maxOffset;
        _contentScrollView.contentOffset = CGPointMake(0, newOffset);
        [self updateScrollbarLayout];
        return YES;
    }

    if (ph == UITouchPhaseMoved && pointerId == _trackingPointerId && _menuDragging) {
        CGFloat dx = point.x - _menuDragStartPoint.x;
        CGFloat dy = point.y - _menuDragStartPoint.y;
        _floatingPanel.center = CGPointMake(_menuDragStartCenter.x + dx,
                                            _menuDragStartCenter.y + dy);
        _menuDragStartCenter = _floatingPanel.center;
        _menuDragStartPoint  = point;
        return YES;
    }

    if ((ph == UITouchPhaseEnded || ph == UITouchPhaseCancelled) &&
        pointerId == _trackingPointerId) {

        if (_touchOnClose) {
            [self closeTapped];

        } else if (_touchOnExitHUD && self.onExitHUDRequested) {
            self.onExitHUDRequested();

        } else if (_activeSwitch) {
            BOOL newValue = !_activeSwitch.isOn;
            [_activeSwitch setOn:newValue animated:YES];
            [self switchChanged:_activeSwitch];

        } else if (_segmentedRowTracking) {
            CGPoint inPanel   = CGPointMake(point.x - _floatingPanel.frame.origin.x,
                                            point.y - _floatingPanel.frame.origin.y);
            CGFloat contentLeft = kSidebarWidth;
            CGPoint inContent   = CGPointMake(inPanel.x - contentLeft - 8,
                                              inPanel.y - kHeaderHeight + _contentScrollView.contentOffset.y);
            [self applySegmentedSelectionForRow:_segmentedRowTracking touchInContent:inContent];

        } else if (_menuDragging) {
            [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.x forKey:@"FloatingPanelX"];
            [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.y forKey:@"FloatingPanelY"];
            [[NSUserDefaults standardUserDefaults] synchronize];

        } else if (_scrollbarDragging) {
            [self updateScrollbarLayout];
        }

        _trackingPointerId    = -1;
        _touchOnClose         = NO;
        _touchOnExitHUD       = NO;
        _menuDragging         = NO;
        _activeSwitch         = nil;
        _segmentedRowTracking = nil;
        _scrollbarDragging    = NO;
        _sliderTracking       = nil;
        return YES;
    }

    if (insidePanel && pointerId == _trackingPointerId) return YES;
    if (_scrollbarDragging) return YES;
    return NO;
}

@end