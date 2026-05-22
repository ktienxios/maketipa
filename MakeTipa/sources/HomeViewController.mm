#import "HomeViewController.h"
#import "HUDHelper.h"
#import "../esp/Core/pid.h"
#import "roothide/varCleanController.h"

#import <QuartzCore/QuartzCore.h>

@interface HomeViewController ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subTitleLabel;

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *glowView;

@property (nonatomic, strong) UILabel *hudLabel;
@property (nonatomic, strong) UILabel *hudStatusLabel;
@property (nonatomic, strong) UISwitch *hudSwitch;

@property (nonatomic, strong) UILabel *descLabel;

@property (nonatomic, strong) UILabel *autoCleanLabel;
@property (nonatomic, strong) UISwitch *autoCleanSwitch;

@property (nonatomic, strong) UIView *statusDot;

@property (nonatomic, strong) NSTimer *pollTimer;

@property (nonatomic, assign) BOOL lastGameRunning;
@property (nonatomic, assign) NSInteger gameMissingStreak;
@property (nonatomic, assign) CFTimeInterval pendingHUDEnableUntil;

@end

@implementation HomeViewController

#pragma mark - Gradient Helper

- (CAGradientLayer *)gradientLayerForView:(UIView *)view {
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = view.bounds;

    gradient.colors = @[
        (__bridge id)[UIColor colorWithRed:0.08 green:0.09 blue:0.16 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.17 green:0.05 blue:0.28 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.28 green:0.06 blue:0.45 alpha:1.0].CGColor
    ];

    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);

    gradient.cornerRadius = 28.0;

    return gradient;
}

#pragma mark - LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor =
    [UIColor colorWithRed:0.03 green:0.03 blue:0.06 alpha:1.0];

    //
    // Background glow
    //

    UIView *bgGlow = [[UIView alloc] initWithFrame:self.view.bounds];
    bgGlow.autoresizingMask =
    UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleHeight;

    bgGlow.userInteractionEnabled = NO;
    bgGlow.backgroundColor =
    [[UIColor purpleColor] colorWithAlphaComponent:0.04];

    [self.view addSubview:bgGlow];

    //
    // Title
    //

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = @"HOME";
    _titleLabel.font = [UIFont systemFontOfSize:42
                                         weight:UIFontWeightBlack];

    _titleLabel.textColor = [UIColor whiteColor];

    _titleLabel.layer.shadowColor =
    [UIColor purpleColor].CGColor;

    _titleLabel.layer.shadowOpacity = 0.9;
    _titleLabel.layer.shadowRadius = 16;
    _titleLabel.layer.shadowOffset = CGSizeZero;

    [self.view addSubview:_titleLabel];

    //
    // Subtitle
    //

    _subTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];

    _subTitleLabel.text = @"FREE FIRE HUD PANEL";
    _subTitleLabel.font =
    [UIFont systemFontOfSize:13
                      weight:UIFontWeightSemibold];

    _subTitleLabel.textColor =
    [UIColor colorWithWhite:1 alpha:0.55];

    [self.view addSubview:_subTitleLabel];

    //
    // Glow behind card
    //

    _glowView = [[UIView alloc] initWithFrame:CGRectZero];
    _glowView.backgroundColor =
    [[UIColor purpleColor] colorWithAlphaComponent:0.25];

    _glowView.layer.cornerRadius = 34;
    _glowView.layer.shadowColor =
    [UIColor magentaColor].CGColor;

    _glowView.layer.shadowOpacity = 1.0;
    _glowView.layer.shadowRadius = 45;
    _glowView.layer.shadowOffset = CGSizeZero;

    [self.view addSubview:_glowView];

    //
    // Main Card
    //

    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.layer.cornerRadius = 28.0;
    _cardView.clipsToBounds = YES;
    _cardView.backgroundColor = [UIColor clearColor];

    [self.view addSubview:_cardView];

    //
    // Gradient card
    //

    CAGradientLayer *gradient =
    [self gradientLayerForView:_cardView];

    [_cardView.layer insertSublayer:gradient atIndex:0];

    //
    // Glass border
    //

    _cardView.layer.borderWidth = 1.2;
    _cardView.layer.borderColor =
    [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;

    //
    // HUD Label
    //

    _hudLabel = [[UILabel alloc] initWithFrame:CGRectZero];

    _hudLabel.text = @"HUD MENU";
    _hudLabel.font =
    [UIFont systemFontOfSize:22
                      weight:UIFontWeightBold];

    _hudLabel.textColor = [UIColor whiteColor];

    [_cardView addSubview:_hudLabel];

    //
    // HUD Status
    //

    _hudStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];

    _hudStatusLabel.font =
    [UIFont systemFontOfSize:12
                      weight:UIFontWeightBold];

    _hudStatusLabel.textColor =
    [UIColor colorWithRed:0.4 green:1 blue:0.7 alpha:1];

    _hudStatusLabel.text = @"ONLINE";

    [_cardView addSubview:_hudStatusLabel];

    //
    // Status Dot
    //

    _statusDot = [[UIView alloc] initWithFrame:CGRectZero];
    _statusDot.backgroundColor =
    [UIColor colorWithRed:0.4 green:1 blue:0.7 alpha:1];

    _statusDot.layer.cornerRadius = 5;

    _statusDot.layer.shadowColor =
    [UIColor greenColor].CGColor;

    _statusDot.layer.shadowOpacity = 1;
    _statusDot.layer.shadowRadius = 10;
    _statusDot.layer.shadowOffset = CGSizeZero;

    [_cardView addSubview:_statusDot];

    //
    // Switch
    //

    _hudSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];

    _hudSwitch.onTintColor =
    [UIColor colorWithRed:0.8 green:0.2 blue:1 alpha:1];

    _hudSwitch.thumbTintColor = [UIColor whiteColor];

    _hudSwitch.layer.shadowColor =
    [UIColor magentaColor].CGColor;

    _hudSwitch.layer.shadowOpacity = 0.8;
    _hudSwitch.layer.shadowRadius = 15;
    _hudSwitch.layer.shadowOffset = CGSizeZero;

    [_hudSwitch addTarget:self
                   action:@selector(hudSwitchChanged:)
         forControlEvents:UIControlEventValueChanged];

    [_cardView addSubview:_hudSwitch];

    //
    // Description
    //

    _descLabel = [[UILabel alloc] initWithFrame:CGRectZero];

    _descLabel.numberOfLines = 0;

    _descLabel.text =
    @"Enable floating in-game HUD overlay system with advanced rendering and real-time touch support.";

    _descLabel.textColor =
    [UIColor colorWithWhite:1 alpha:0.72];

    _descLabel.font =
    [UIFont systemFontOfSize:14
                      weight:UIFontWeightMedium];

    [_cardView addSubview:_descLabel];

    //
    // Divider
    //

    UIView *line = [[UIView alloc] initWithFrame:CGRectZero];

    line.backgroundColor =
    [[UIColor whiteColor] colorWithAlphaComponent:0.08];

    line.tag = 999;

    [_cardView addSubview:line];

    //
    // Auto clean
    //

    _autoCleanLabel = [[UILabel alloc] initWithFrame:CGRectZero];

    _autoCleanLabel.text = @"AUTO VAR CLEAN";
    _autoCleanLabel.font =
    [UIFont systemFontOfSize:15
                      weight:UIFontWeightBold];

    _autoCleanLabel.textColor =
    [UIColor colorWithWhite:1 alpha:0.92];

    [_cardView addSubview:_autoCleanLabel];

    //
    // Auto switch
    //

    _autoCleanSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];

    _autoCleanSwitch.onTintColor =
    [UIColor colorWithRed:0.2 green:0.85 blue:1 alpha:1];

    _autoCleanSwitch.thumbTintColor = [UIColor whiteColor];

    _autoCleanSwitch.on =
    [[NSUserDefaults standardUserDefaults]
     boolForKey:@"AutoVarCleanBeforeHUD"];

    [_autoCleanSwitch addTarget:self
                         action:@selector(autoCleanSwitchChanged:)
               forControlEvents:UIControlEventValueChanged];

    [_cardView addSubview:_autoCleanSwitch];

    //
    // Pulse animation
    //

    CABasicAnimation *pulse =
    [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];

    pulse.fromValue = @(0.25);
    pulse.toValue = @(1.0);

    pulse.duration = 1.2;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;

    [_glowView.layer addAnimation:pulse
                           forKey:@"pulseGlow"];

    //
    // Notifications
    //

    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(appBecameActive)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];

    _lastGameRunning = [self isGameRunning];
    _gameMissingStreak = 0;
    _pendingHUDEnableUntil = 0;

    [self refreshHUDState];
    [self startPollingGameState];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UIEdgeInsets insets = self.view.safeAreaInsets;

    CGFloat w = self.view.bounds.size.width;

    _titleLabel.frame =
    CGRectMake(24,
               insets.top + 18,
               w - 48,
               48);

    _subTitleLabel.frame =
    CGRectMake(26,
               CGRectGetMaxY(_titleLabel.frame) + 2,
               250,
               18);

    CGFloat cardX = 18;
    CGFloat cardW = w - 36;

    CGFloat cardY =
    CGRectGetMaxY(_subTitleLabel.frame) + 20;

    CGFloat cardH = 240;

    _glowView.frame =
    CGRectMake(cardX + 8,
               cardY + 10,
               cardW - 16,
               cardH - 16);

    _cardView.frame =
    CGRectMake(cardX,
               cardY,
               cardW,
               cardH);

    //
    // Update gradient size
    //

    for (CALayer *layer in _cardView.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            layer.frame = _cardView.bounds;
        }
    }

    //
    // HUD title
    //

    _hudLabel.frame =
    CGRectMake(20, 20, 180, 28);

    _statusDot.frame =
    CGRectMake(22, 58, 10, 10);

    _hudStatusLabel.frame =
    CGRectMake(40, 53, 120, 18);

    //
    // Switch
    //

    CGSize swSize = _hudSwitch.intrinsicContentSize;

    _hudSwitch.frame =
    CGRectMake(cardW - swSize.width - 22,
               24,
               swSize.width,
               swSize.height);

    //
    // Desc
    //

    _descLabel.frame =
    CGRectMake(20,
               88,
               cardW - 40,
               48);

    //
    // Divider
    //

    UIView *line = [_cardView viewWithTag:999];

    line.frame =
    CGRectMake(20,
               152,
               cardW - 40,
               1);

    //
    // Auto clean
    //

    _autoCleanLabel.frame =
    CGRectMake(20,
               174,
               200,
               24);

    CGSize cs =
    _autoCleanSwitch.intrinsicContentSize;

    _autoCleanSwitch.frame =
    CGRectMake(cardW - cs.width - 22,
               170,
               cs.width,
               cs.height);
}

#pragma mark - Dealloc

- (void)dealloc {

    [[NSNotificationCenter defaultCenter]
     removeObserver:self];

    [_pollTimer invalidate];
    _pollTimer = nil;
}

#pragma mark - Game State

- (BOOL)isGameRunning {
    return GetGameProcesspid((char *)"FreeFire") != -1;
}

- (void)startPollingGameState {

    __weak __typeof(self) wself = self;

    _pollTimer =
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                    repeats:YES
                                      block:^(NSTimer * _Nonnull timer) {

        __strong __typeof(wself) sself = wself;

        if (!sself) return;

        [sself refreshHUDState];
    }];
}

- (void)appBecameActive {
    [self refreshHUDState];
}

#pragma mark - Actions

- (void)autoCleanSwitchChanged:(UISwitch *)sw {

    [[NSUserDefaults standardUserDefaults]
     setBool:sw.on
     forKey:@"AutoVarCleanBeforeHUD"];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)hudSwitchChanged:(UISwitch *)sw {

    BOOL canEnable = [self isGameRunning];

    if (sw.on && !canEnable) {

        sw.on = NO;
        return;
    }

    BOOL autoClean =
    [[NSUserDefaults standardUserDefaults]
     boolForKey:@"AutoVarCleanBeforeHUD"];

    if (sw.on)
        _pendingHUDEnableUntil =
        CACurrentMediaTime() + 2.5;
    else
        _pendingHUDEnableUntil = 0;

    //
    // Fancy switch animation
    //

    [UIView animateWithDuration:0.18 animations:^{
        sw.transform = CGAffineTransformMakeScale(1.15, 1.15);
    } completion:^(BOOL finished) {

        [UIView animateWithDuration:0.18 animations:^{
            sw.transform = CGAffineTransformIdentity;
        }];
    }];

    if (sw.on && autoClean) {

        sw.enabled = NO;

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{

            [[varCleanController sharedInstance] runVarCleanNow];

            dispatch_async(dispatch_get_main_queue(), ^{

                SetHUDEnabled(YES);

                sw.enabled = YES;

                [self refreshHUDState];
            });
        });

        return;
    }

    SetHUDEnabled(sw.on);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        [self refreshHUDState];
    });
}

#pragma mark - Refresh

- (void)refreshHUDState {

    BOOL gameNow = [self isGameRunning];
    BOOL hud = IsHUDEnabled();

    if (!gameNow)
        _gameMissingStreak++;
    else
        _gameMissingStreak = 0;

    BOOL game =
    gameNow || (_gameMissingStreak < 3);

    if (!game) {

        if (hud) {
            SetHUDEnabled(NO);
            hud = NO;
        }

        _hudSwitch.enabled = NO;

        if (_hudSwitch.on)
            [_hudSwitch setOn:NO animated:YES];

        _descLabel.alpha = 0.45;

        _hudStatusLabel.text = @"OFFLINE";
        _hudStatusLabel.textColor =
        [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1];

        _statusDot.backgroundColor =
        [UIColor redColor];

        _pendingHUDEnableUntil = 0;

        return;
    }

    _hudSwitch.enabled = YES;
    _descLabel.alpha = 1.0;

    _hudStatusLabel.text = @"ONLINE";
    _hudStatusLabel.textColor =
    [UIColor colorWithRed:0.4 green:1 blue:0.7 alpha:1];

    _statusDot.backgroundColor =
    [UIColor colorWithRed:0.4 green:1 blue:0.7 alpha:1];

    CFTimeInterval now =
    CACurrentMediaTime();

    BOOL inGrace =
    (_pendingHUDEnableUntil > 0 &&
     now < _pendingHUDEnableUntil);

    if (!hud && inGrace) {

        if (!_hudSwitch.on)
            [_hudSwitch setOn:YES animated:NO];

        return;
    }

    if (_hudSwitch.on != hud)
        [_hudSwitch setOn:hud animated:YES];

    if (hud)
        _pendingHUDEnableUntil = 0;
}

@end