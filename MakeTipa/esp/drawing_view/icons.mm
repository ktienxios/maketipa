#import "icons.h"
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

UIImage *FloatButtonIcon(void) {
    // 1. Tăng kích thước tổng gian vẽ lên 64x64 để có không gian đổ bóng
    CGSize size = CGSizeMake(64, 64);
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef context = ctx.CGContext;
        
        // 2. Kích thước thực của nút là 50x50 (đẩy vào trong 7px mỗi góc để lấy chỗ đổ bóng)
        CGRect circleRect = CGRectMake(7, 7, 50, 50);
        UIBezierPath *circlePath = [UIBezierPath bezierPathWithOvalInRect:circleRect];
        
        // --- 3. TẠO BÓNG ĐỔ (DROP SHADOW) CHO NÚT ---
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, CGSizeMake(0, 4), 6, [[UIColor blackColor] colorWithAlphaComponent:0.4].CGColor);
        [[UIColor whiteColor] setFill]; // Đổ nền nháp để tạo bóng
        [circlePath fill];
        CGContextRestoreGState(context);
        
        // --- 4. TẠO NỀN CHUYỂN MÀU (GRADIENT) ---
        CGContextSaveGState(context);
        [circlePath addClip]; // Bo góc gradient theo hình tròn
        
        // Phối màu: Đỏ hồng tươi -> Đỏ sẫm
        NSArray *colors = @[
            (id)[UIColor colorWithRed:1.00 green:0.35 blue:0.45 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.85 green:0.05 blue:0.15 alpha:1.0].CGColor
        ];
        CGFloat locations[] = {0.0, 1.0};
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
        
        CGPoint startPoint = CGPointMake(circleRect.origin.x, circleRect.origin.y);
        CGPoint endPoint = CGPointMake(circleRect.origin.x, circleRect.origin.y + circleRect.size.height);
        CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
        
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        CGContextRestoreGState(context);
        
        // --- 5. TẠO VIỀN SÁNG MỜ (GLOSS BORDER) ---
        [circlePath setLineWidth:1.5];
        [[UIColor colorWithWhite:1.0 alpha:0.5] setStroke];
        [circlePath stroke];
        
        // --- 6. VẼ CHỮ "VN" CÓ BÓNG ---
        NSString *text = @"CC";
        
        NSShadow *textShadow = [[NSShadow alloc] init];
        textShadow.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
        textShadow.shadowOffset = CGSizeMake(0, 1.5);
        textShadow.shadowBlurRadius = 2.0;
        
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:24 weight:UIFontWeightHeavy], // Font nét siêu dày
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSShadowAttributeName: textShadow // Áp dụng bóng cho chữ
        };
        
        CGSize textSize = [text sizeWithAttributes:attributes];
        CGRect textRect = CGRectMake(circleRect.origin.x + (circleRect.size.width - textSize.width) / 2,
                                     circleRect.origin.y + (circleRect.size.height - textSize.height) / 2,
                                     textSize.width,
                                     textSize.height);
        
        [text drawInRect:textRect withAttributes:attributes];
    }];
    
    return image;
}