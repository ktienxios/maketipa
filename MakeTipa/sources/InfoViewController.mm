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

    // Nhãn bên trái: Chữ màu trắng nguyên bản
    _leftLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _leftLabel.text = left ?: @"";
    _leftLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _leftLabel.textColor = [UIColor whiteColor];
    [self addSubview:_leftLabel];

    // SỬA: Thay thế màu hồng nhạt cũ thành màu trắng mờ (Xám nhạt) tinh tế
    _rightLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _rightLabel.text = right ?: @"—";
    _rightLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    _rightLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    _rightLabel.textAlignment = NSTextAlignmentRight;
    _rightLabel.adjustsFontSizeToFitWidth = YES;
    _rightLabel.minimumScaleFactor = 0.75;
    [self addSubview:_rightLabel];
    return self;
}

- (void)layoutSubviews {
    [super copy]; // Đảm bảo cấu trúc hiển thị
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    
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

#pragma mark - Theme Đồng Bộ (Monochrome)

// SỬA: Đổi màu Accent chủ đạo từ Hồng sang Trắng hoàn toàn để đồng bộ Home Panel
- (UIColor *)accent { return [UIColor whiteColor]; }

- (void)viewDidLoad {
    [super viewDidLoad];

    // 1. SỬA: Đổi nền Gradient Midnight Purple thành màu đen thuần giống hệt HomeViewController
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.frame = self.view.bounds;
    bg.colors = @[
        (__bridge id)[UIColor blackColor].CGColor,
        (__bridge id)[UIColor blackColor].CGColor
    ];
    [self.view.layer insertSublayer:bg atIndex:0];

    // 2. Tiêu đề chính phát sáng tinh tế
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = @"BUILD INFO";
    _titleLabel.font = [UIFont systemFontOfSize:38 weight:UIFontWeightBlack];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.layer.shadowColor = [UIColor whiteColor].CGColor;
    _titleLabel.layer.shadowRadius = 16;
    _titleLabel.layer.shadowOpacity = 0.15; // Hạ shadow mờ ảo dịu mắt giống Home Panel
    _titleLabel.layer.shadowOffset = CGSizeZero;
    [self.view addSubview:_titleLabel];

    // Phụ đề nhỏ phía dưới tiêu đề
    _subTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _subTitleLabel.text = @"APPLICATION METADATA & SPECS";
    _subTitleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    _subTitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.55]; // Thay thế màu hồng bằng màu xám mờ
    [self.view addSubview:_subTitleLabel];

    // 3. Khung Card chứa thông tin kiểu Kính Mờ (Glassmorphism) tối giản
    _cardView = [[UIView alloc] initWithFrame:CGRectZero];
    _cardView.layer.cornerRadius = 24;
    _cardView.clipsToBounds = YES;
    
    // SỬA: Viền kính trắng mờ mỏng tinh tế thay cho viền hồng cũ
    _cardView.layer.borderWidth = 1.2;
    _cardView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08].CGColor;
    
    // SỬA: Đổ bóng xám nhẹ nhàng sau lưng Card
    _cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    _cardView.layer.shadowOpacity = 0.3;
    _cardView.layer.shadowRadius = 20;
    _cardView.layer.shadowOffset = CGSizeZero;
    [self.view addSubview:_cardView];

    // SỬA: Lớp phủ Gradient xám/đen mờ mịn phía trong Card đồng bộ với Card bên Home Panel
    _cardGradient = [CAGradientLayer layer];
    _cardGradient.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.12 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.10 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.08 alpha:1.0].CGColor
    ];
    _cardGradient.startPoint = CGPointMake(0, 0);
    _cardGradient.endPoint = CGPointMake(1, 1);
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
            // SỬA: Thanh chia mỏng màu xám mờ đồng bộ (tag=999 giống bên Home)
            sep.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
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
    _titleLabel.frame = CGRectMake(24, insets.top + 18, w - 48, 48);
    _subTitleLabel.frame = CGRectMake(26, CGRectGetMaxY(_titleLabel.frame) + 2, w - 52, 18);

    // Định vị Card thông tin
    CGFloat cardX = 18;
    CGFloat cardW = w - 36;
    CGFloat cardY = CGRectGetMaxY(_subTitleLabel.frame) + 20;
    CGFloat rowH = 52; 
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
            sep.frame = CGRectMake(20, CGRectGetMaxY(rv.frame) - 0.5f, cardW - 40, 0.5f);
        }
    }
}

@end