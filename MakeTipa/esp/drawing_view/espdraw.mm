#import "esp.h"
#import "../Core/GameLogic.h"
#import "mahoa.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#include <cmath>

UIFont *VietnameseFontForLayer(CGFloat size) {
    UIFont *f = [UIFont fontWithName:NSSENCRYPT("GFF-Latin-Bold") size:size];
    if (!f) f = [UIFont systemFontOfSize:size];
    UIFontDescriptor *boldDesc = [f.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    UIFont *boldFont = [UIFont fontWithDescriptor:boldDesc size:size];
    return boldFont ?: [UIFont boldSystemFontOfSize:size];
}

static inline void ESPAddLine(CGMutablePathRef path, CGPoint p1, CGPoint p2) {
    if (!path) return;
    CGPathMoveToPoint(path, NULL, p1.x, p1.y);
    CGPathAddLineToPoint(path, NULL, p2.x, p2.y);
}

static inline void ESPAddCircle(CGMutablePathRef path, CGPoint center, CGFloat radius) {
    if (!path) return;
    CGRect rect = CGRectMake(center.x - radius, center.y - radius, radius * 2.0f, radius * 2.0f);
    CGPathAddEllipseInRect(path, NULL, rect);
}

static inline void ESPAddRoundedRect(CGMutablePathRef path, CGRect rect, CGFloat radius) {
    if (!path || radius <= 0) return;
    CGFloat r = (CGFloat)fmin((double)radius, (double)fmin(rect.size.width, rect.size.height) * 0.5);
    if (r <= 0) { CGPathAddRect(path, NULL, rect); return; }
    UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:r];
    CGPathAddPath(path, NULL, bp.CGPath);
}

static inline void ESPAddCornerBracketBox(CGMutablePathRef path, CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
    if (!path || w < 1.0f || h < 1.0f) return;
    CGFloat leg = fmaxf(5.0f, fminf(w, h) * 0.22f);
    leg = fminf(leg, w * 0.48f);
    leg = fminf(leg, h * 0.48f);

    ESPAddLine(path, CGPointMake(x, y), CGPointMake(x + leg, y));
    ESPAddLine(path, CGPointMake(x, y), CGPointMake(x, y + leg));

    ESPAddLine(path, CGPointMake(x + w, y), CGPointMake(x + w - leg, y));
    ESPAddLine(path, CGPointMake(x + w, y), CGPointMake(x + w, y + leg));

    ESPAddLine(path, CGPointMake(x, y + h), CGPointMake(x + leg, y + h));
    ESPAddLine(path, CGPointMake(x, y + h), CGPointMake(x, y + h - leg));

    ESPAddLine(path, CGPointMake(x + w, y + h), CGPointMake(x + w - leg, y + h));
    ESPAddLine(path, CGPointMake(x + w, y + h), CGPointMake(x + w, y + h - leg));
}

BOOL RenderFOVCirclePath(
    CGMutablePathRef path,
    float viewWidth,
    float viewHeight,
    BOOL aimbotEnabled,
    float fovRadius
) {
    if (!path) return NO;
    if (!aimbotEnabled || fovRadius <= 0) return NO;
    if (viewWidth < 10 || viewHeight < 10) return NO;

    float cx = viewWidth / 2.0f;
    float cy = viewHeight / 2.0f;
    float d = fovRadius * 2.0f;
    float x = cx - fovRadius;
    float y = cy - fovRadius;

    CGPathAddEllipseInRect(path, NULL, CGRectMake(x, y, d, d));
    return YES;
}

void RenderESPForPawn(
    ESPGeometryBuffers *buffers,
    ESPAddTextCallback textCallback,
    void *callbackContext,
    uint64_t PawnObject,
    int CurHP,
    float dis,
    float *matrix,
    float layerWidth,
    float layerHeight,
    float matrixVpWidth,
    float matrixVpHeight
) {

    if (dis > 400.0f || !buffers || !matrix) return;
    if (!PawnObject || !isVaildPtr(PawnObject)) return;

    Vector3 HeadPos      = getPositionExt(getHead(PawnObject));
    Vector3 RightToePos  = getPositionExt(getRightToeNode(PawnObject));

    Vector3 LeftToePos   = getPositionExt(getLeftAnkle(PawnObject));
    Vector3 HipPos       = getPositionExt(getHip(PawnObject));
    Vector3 L_Ankle      = getPositionExt(getLeftAnkle(PawnObject));
    Vector3 R_Ankle      = getPositionExt(getRightAnkle(PawnObject));
    Vector3 L_ForeArm    = getPositionExt(getLeftElbow(PawnObject));
    Vector3 R_ForeArm    = getPositionExt(getRightElbow(PawnObject));
    Vector3 L_Hand       = getPositionExt(getLeftHand(PawnObject));
    Vector3 R_Hand       = getPositionExt(getRightHand(PawnObject));

    Vector3 HeadTop = HeadPos; HeadTop.y += 0.2f;
    Vector3 w2sHead = WorldToScreenLayer(HeadTop, matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
    Vector3 w2sToe  = WorldToScreenLayer(RightToePos, matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);

    if (w2sHead.z < 0.001f || w2sToe.z < 0.001f) return;
    const float margin = layerWidth * 0.6f;
    if (w2sHead.x < -margin || w2sHead.x > layerWidth + margin ||
        w2sHead.y < -margin || w2sHead.y > layerHeight + margin) return;

    Vector3 wHead   = WorldToScreenLayer(HeadPos,   matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
    Vector3 wHip    = WorldToScreenLayer(HipPos,    matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);

    float screenHeight = fabsf(w2sHead.y - w2sToe.y);

    if (isBone) {

        Vector3 wLE = WorldToScreenLayer(L_ForeArm,  matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
        Vector3 wRE = WorldToScreenLayer(R_ForeArm,  matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
        Vector3 wLH = WorldToScreenLayer(L_Hand,      matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
        Vector3 wRH = WorldToScreenLayer(R_Hand,      matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
        Vector3 wLA = WorldToScreenLayer(L_Ankle,     matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
        Vector3 wRA = WorldToScreenLayer(R_Ankle,     matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
        Vector3 wLT = WorldToScreenLayer(LeftToePos,  matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
        Vector3 wRT = WorldToScreenLayer(RightToePos, matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);

        CGPoint pHead = CGPointMake(wHead.x, wHead.y);
        CGPoint pHip  = CGPointMake(wHip.x,  wHip.y);

        CGPoint pNeck = CGPointMake(
            pHead.x + (pHip.x - pHead.x) * 0.15f,
            pHead.y + (pHip.y - pHead.y) * 0.15f
        );

        CGPoint pLE = CGPointMake(wLE.x, wLE.y);
        CGPoint pRE = CGPointMake(wRE.x, wRE.y);

        CGPoint pLS = CGPointMake(
            pNeck.x + (pLE.x - pNeck.x) * 0.3f,
            pNeck.y + (pLE.y - pNeck.y) * 0.3f
        );
        CGPoint pRS = CGPointMake(
            pNeck.x + (pRE.x - pNeck.x) * 0.3f,
            pNeck.y + (pRE.y - pNeck.y) * 0.3f
        );

        CGPoint pLH = CGPointMake(wLH.x, wLH.y);
        CGPoint pRH = CGPointMake(wRH.x, wRH.y);

        CGPoint pLK = CGPointMake(
            pHip.x + (wLA.x - pHip.x) * 0.45f,
            pHip.y + (wLA.y - pHip.y) * 0.45f
        );
        CGPoint pRK = CGPointMake(
            pHip.x + (wRA.x - pHip.x) * 0.45f,
            pHip.y + (wRA.y - pHip.y) * 0.45f
        );

        CGPoint pLA = CGPointMake(wLA.x, wLA.y);
        CGPoint pRA = CGPointMake(wRA.x, wRA.y);
        CGPoint pLT = CGPointMake(wLT.x, wLT.y);
        CGPoint pRT = CGPointMake(wRT.x, wRT.y);

        CGFloat headToHip = fabs(pHead.y - pHip.y);
        CGFloat headRadius = fmaxf(headToHip / 4.5f, 1.0f);
        CGPoint circleCenter = CGPointMake(pHead.x, pHead.y - headRadius * 0.5f);
        ESPAddCircle(buffers->bonePath, circleCenter, headRadius);

        ESPAddLine(buffers->bonePath, pNeck, pHip);

        ESPAddLine(buffers->bonePath, pNeck, pLS);
        ESPAddLine(buffers->bonePath, pLS,   pLE);
        ESPAddLine(buffers->bonePath, pLE,   pLH);

        ESPAddLine(buffers->bonePath, pNeck, pRS);
        ESPAddLine(buffers->bonePath, pRS,   pRE);
        ESPAddLine(buffers->bonePath, pRE,   pRH);

        ESPAddLine(buffers->bonePath, pHip, pLK);
        ESPAddLine(buffers->bonePath, pLK,  pLA);
        ESPAddLine(buffers->bonePath, pLA,  pLT);

        ESPAddLine(buffers->bonePath, pHip, pRK);
        ESPAddLine(buffers->bonePath, pRK,  pRA);
        ESPAddLine(buffers->bonePath, pRA,  pRT);

        buffers->boneDirty = true;
    }

    float boxHeight = fabsf(w2sHead.y - w2sToe.y);
    float boxWidth  = boxHeight * 0.5f;
    float x = w2sHead.x - boxWidth * 0.5f;
    float y = w2sHead.y;

    if (isLine) {

        const CGFloat kSnaplineStartY = 22.0f + 26.0f;
        CGPoint lineStart = CGPointMake(layerWidth / 2.0f, (CGFloat)kSnaplineStartY);
        CGPoint enemyHead = CGPointMake((CGFloat)w2sHead.x, (CGFloat)w2sHead.y);
        ESPAddLine(buffers->snaplinePath, lineStart, enemyHead);
        buffers->snaplineDirty = true;
    }

    if (isBox) {
        ESPAddCornerBracketBox(buffers->boxPath, x, y, boxWidth, boxHeight);
        buffers->boxDirty = true;
    }

    const CGFloat kNameLineH = 14.0f;
    const CGFloat kBelowBoxGap = 2.0f;
    const CGFloat boxBottom = y + boxHeight;
    const CGFloat kNameY = boxBottom + kBelowBoxGap;
    CGFloat kDistY = boxBottom + kBelowBoxGap;
    if (isName)
        kDistY = kNameY + kNameLineH + kBelowBoxGap;

    UIFont *nameFont = VietnameseFontForLayer(9.0f);
    CGFloat namePartWidth = 0.0f;
    CGFloat hpPartWidth = 0.0f;
    NSString *displayName = nil;
    UIColor *hpColor = [UIColor greenColor];
    if (CurHP > 150)
        hpColor = [UIColor colorWithRed:0.2f green:0.85f blue:0.3f alpha:1.0f];
    else if (CurHP > 75)
        hpColor = [UIColor yellowColor];
    else
        hpColor = [UIColor redColor];
    NSString *hpPrefix = [NSString stringWithFormat:@"%d ", CurHP];
    if (isName || isHealth)
        hpPartWidth = (CGFloat)floor([hpPrefix sizeWithAttributes:@{NSFontAttributeName: nameFont}].width);

    if (isName || isHealth) {
        NSString *Name = (isEspBot && get_IsBot(PawnObject)) ? NSSENCRYPT("BOT") : GetNickName(PawnObject);
        if (Name.length > 0) {
            const CGFloat maxNameW = 200.0f;
            namePartWidth = (CGFloat)[Name sizeWithAttributes:@{NSFontAttributeName: nameFont}].width;
            displayName = Name;
            if (namePartWidth > maxNameW) {
                NSMutableString *trunc = [NSMutableString stringWithString:Name];
                while (trunc.length > 0 && (CGFloat)[trunc sizeWithAttributes:@{NSFontAttributeName: nameFont}].width > maxNameW - 12.0f)
                    [trunc deleteCharactersInRange:NSMakeRange(trunc.length - 1, 1)];
                [trunc appendString:@"…"];
                displayName = trunc;
                namePartWidth = (CGFloat)floor([displayName sizeWithAttributes:@{NSFontAttributeName: nameFont}].width);
            } else {
                namePartWidth = (CGFloat)floor(namePartWidth);
            }
        }
    }

    CGFloat totalTextWidth = hpPartWidth + namePartWidth;
    CGFloat nameX = (CGFloat)w2sHead.x - totalTextWidth * 0.5f;

    bool isKnocked = get_IsKnockedDown(PawnObject);
    if (isKnocked && textCallback) {
        UIFont *tagFont = VietnameseFontForLayer(8.0f);
        CGFloat tagY = kNameY - kNameLineH - 1.0f;
        NSString *knockTag = NSSENCRYPT("[KNOCKED]");
        UIColor *knockColor = [UIColor colorWithRed:1.0f green:0.4f blue:0.1f alpha:1.0f];
        CGFloat tagW = (CGFloat)floor([knockTag sizeWithAttributes:@{NSFontAttributeName: tagFont}].width);
        textCallback(callbackContext, knockTag, CGRectMake((CGFloat)w2sHead.x - tagW * 0.5f, tagY, tagW, kNameLineH), knockColor, 8.0f, YES);
    }

    if (isName && textCallback) {
        BOOL isBot = (isEspBot && get_IsBot(PawnObject));
        UIColor *textColor = isBot ? [UIColor redColor] : [UIColor yellowColor];
        textCallback(callbackContext, hpPrefix, CGRectMake(nameX, kNameY, hpPartWidth, kNameLineH), hpColor, 9.0f, YES);
        if (displayName.length > 0)
            textCallback(callbackContext, displayName, CGRectMake(nameX + hpPartWidth, kNameY, namePartWidth, kNameLineH), textColor, 9.0f, YES);
    }

    if (isHealth) {
        int MaxHP = get_MaxHP(PawnObject);
        if (MaxHP > 0) {
            float currentHealth = (float)CurHP;
            float maxHealth = (float)MaxHP;
            if (maxHealth < 1.0f) maxHealth = 1.0f;
            float healthRatio = currentHealth / maxHealth;
            if (healthRatio < 0.0f) healthRatio = 0.0f;
            if (healthRatio > 1.0f) healthRatio = 1.0f;

            const CGFloat barWidth = 6.0f;
            const CGFloat barGap = 1.5f;
            CGFloat barX = x - barGap;
            CGFloat barTop = y;
            CGFloat barBottom = y + boxHeight;
            CGFloat barHeight = barBottom - barTop;
            CGFloat filledTop = barBottom - barHeight * (CGFloat)healthRatio;

            CGRect bgRect = CGRectMake(barX - barWidth, barTop, barWidth, barHeight);
            CGPathAddRect(buffers->hpBackgroundPath, NULL, bgRect);
            buffers->hpBackgroundDirty = true;

            CGRect fillRect = CGRectMake(barX - barWidth, filledTop, barWidth, barBottom - filledTop);
            CGPathAddRect(buffers->hpFillPath, NULL, fillRect);
            buffers->hpFillDirty = true;
        }
    }

    if (isDis && textCallback) {
        NSString *distString = [NSString stringWithFormat:NSSENCRYPT("%.0fm"), dis];
        CGRect frame = CGRectMake(x - 10, kDistY, boxWidth + 20, 14);
        textCallback(callbackContext, distString, frame, [UIColor whiteColor], 9.0f, NO);
    }
}
