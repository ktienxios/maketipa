
#import "InfoViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface InfoRowView : UIView
@property (nonatomic, strong) UILabel *leftLabel;
@property (nonatomic, strong) UILabel *rightLabel;
@end

@implementation InfoRowView

- (instancetype)initWithLeft:(NSString *)left right:(NSString *)right {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];

    // Nhãn bên trái: Chữ màu trắng, tăng độ dày một chút để dễ đọc
    _leftLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _leftLabel.text = left ?: @"";
    _leftLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _leftLabel.textColor = [UIColor whiteColor];
    [self addSubview:_leftLabel];

    // Nhãn bên phải: Chữ màu hồng nhạt, mang hơi hướng công nghệ
    _rightLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _rightLabel.text = right ?: @"—";
    _rightLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _rightLabel.textColor = [UIColor colorWithRed:1.00 green:0.75 blue:0.85 alpha:0.9];
    _rightLabel.textAlignment = NSTextAlignmentRight;
    // Tự động thu nhỏ font nếu text quá dài (như Bundle Identifier) để không bị cắt chữ
    _rightLabel.adjustsFontSizeToFitWidth = YES;
    _rightLabel.minimumScaleFactor = 0.75;
    [self addSubview:_rightLabel];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    
    // Chia tỷ lệ 40% - 60% giúp hiển thị các chuỗi dài bên phải tốt hơn
    _leftLabel.frame = CGRectMake(18, 0, w * 0.40f - 18, h);
    _rightLabel.frame = CGRectMake(w * 0.40f, 0, w * 0.60f - 18, h);
}
@end


@interface InfoViewController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subTitleLabel;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) CAGradientLayer *cardGradient;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) NSArray<InfoRowView *> *rows;
@end

@implementation InfoViewController

#pragma mark - Theme Đồng Bộ (Cyber Sakura)

- (UIColor *)accent { return [UIColor colorWithRed:1.00 green:0.41 blue:0.71 alpha:1]; } // Hồng anh đào rực

- (void)viewDidLoad {
    [super viewDidLoad];

    // 1. Nền tối Gradient Midnight Purple sâu thẳm giống Home Panel
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.frame = self.view.bounds;
    bg.colors = @[
        (__bridge id)[UIColor colorWithRed:0.04 green:0.03 blue:0.09 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:0.12 green:0.06 blue:0.22 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:0.20 green:0.07 blue:0.30 alpha:1].CGColor
    ];
    bg.locations = @[@0.0, @0.5, @1.0];
    [self.view.layer insertSublayer:bg atIndex:0];

    // 2. Tiêu đề chính phát sáng Neon cực chất
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = @"BUILD INFO";
    _titleLabel.font = [UIFont systemFontOfSize:38 weight:UIFontWeightBlack];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.layer.shadowColor = [self accent].CGColor;
    _titleLabel.layer.shadowRadius = 15;
    _titleLabel.layer.shadowOpacity = 0.75;
    _titleLabel.layer.shadowOffset = CGSizeZero;
    [self.view addSubview:_titleLabel];

    // Phụ đề nhỏ phía dưới tiêu đề
    _subTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subTitleLabel.text = @"APPLICATION METADATA & SPECS";
    _subTitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    _subTitleLabel.textColor = [self accent];
    _subTitleLabel.alpha = 0.85;
    [self.view addSubview:_subTitleLabel];

    // 3. Khung Card chứa thông tin kiểu Kính Mờ (Glassmorphism)
    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.layer.cornerRadius = 24;
    _cardView.clipsToBounds = YES;
    
    // Viền hồng Neon mỏng tinh tế
    _cardView.layer.borderWidth = 0.8;
    _cardView.layer.borderColor = [[self accent] colorWithAlphaComponent:0.25].CGColor;
    
    // Đổ bóng lan tỏa nhẹ sau lưng Card
    _cardView.layer.shadowColor = [self accent].CGColor;
    _cardView.layer.shadowOpacity = 0.20;
    _cardView.layer.shadowRadius = 20;
    _cardView.layer.shadowOffset = CGSizeZero;
    [self.view addSubview:_cardView];

    // Lớp phủ Gradient mờ mịn phía trong Card
    _cardGradient = [CAGradientLayer layer];
    _cardGradient.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.07].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.02].CGColor,
        (__bridge id)[UIColor colorWithRed:1.00 green:0.41 blue:0.71 alpha:0.03].CGColor
    ];
    [_cardView.layer insertSublayer:_cardGradient atIndex:0];

    // Hiệu ứng Blur nền hệ thống (Material Dark)
    _blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    _blurView.alpha = 0.98;
    [_cardView addSubview:_blurView];

    // 4. Đọc dữ liệu từ Info.plist
    NSDictionary *info = [NSBundle mainBundle].infoDictionary ?: @{};
    NSString *bundleName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"—";
    NSString *bundleID = info[@"CFBundleIdentifier"] ?: @"—";
    NSString *shortVer = info[@"CFBundleShortVersionString"] ?: @"—";
    NSString *buildVer = info[@"CFBundleVersion"] ?: @"—";

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm";
    NSString *created = [df stringFromDate:[NSDate date]];

    // Khởi tạo các hàng thông tin
    InfoRowView *r1 = [[InfoRowView alloc] initWithLeft:@"Build Name" right:bundleName];
    InfoRowView *r2 = [[InfoRowView alloc] initWithLeft:@"Build Number" right:buildVer];
    InfoRowView *r3 = [[InfoRowView alloc] initWithLeft:@"Product ID" right:bundleID];
    InfoRowView *r4 = [[InfoRowView alloc] initWithLeft:@"Version" right:shortVer];
    InfoRowView *r5 = [[InfoRowView alloc] initWithLeft:@"Compiled At" right:created];
    _rows = @[ r1, r2, r3, r4, r5 ];

    // Add các hàng và thanh chia (Separator) vào Card
    for (NSUInteger i = 0; i < _rows.count; i++) {
        [_cardView addSubview:_rows[i]];
        if (i != _rows.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectZero];
            // Thanh chia mỏng màu hồng neon cực nhạt, trong suốt cao
            sep.backgroundColor = [[self accent] colorWithAlphaComponent:0.12];
            sep.tag = 9000 + (int)i;
            [_cardView addSubview:sep];
        }
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets insets = self.view.safeAreaInsets;
    CGFloat w = self.view.bounds.size.width;

    // Định vị Tiêu đề giống hệt bên HomeViewController
    _titleLabel.frame = CGRectMake(24, insets.top + 24, w - 48, 44);
    _subTitleLabel.frame = CGRectMake(26, CGRectGetMaxY(_titleLabel.frame) + 2, w - 52, 18);

    // Định vị Card thông tin
    CGFloat cardX = 16;
    CGFloat cardW = w - 32;
    CGFloat cardY = CGRectGetMaxY(_subTitleLabel.frame) + 24;
    CGFloat rowH = 52; // Tăng chiều cao mỗi hàng lên 52 để nhìn thoáng và sang trọng hơn
    CGFloat cardH = rowH * _rows.count;
    _cardView.frame = CGRectMake(cardX, cardY, cardW, cardH);

    // Cập nhật lại khung sublayer cho đúng kích thước Card
    _blurView.frame = _cardView.bounds;
    _cardGradient.frame = _cardView.bounds;

    // Cấu hình vị trí từng hàng và thanh phân cách
    for (NSUInteger i = 0; i < _rows.count; i++) {
        InfoRowView *rv = _rows[i];
        rv.frame = CGRectMake(0, (CGFloat)i * rowH, cardW, rowH);
        
        UIView *sep = [_cardView viewWithTag:9000 + (int)i];
        if (sep) {
            // Thanh chia nằm ở sát mép dưới hàng, thụt lề 16px hai bên
            sep.frame = CGRectMake(16, CGRectGetMaxY(rv.frame) - 0.5f, cardW - 32, 0.5f);
        }
    }
}

@end