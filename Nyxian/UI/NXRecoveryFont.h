/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef NXRECOVERYFONT_H
#define NXRECOVERYFONT_H

#import <UIKit/UIKit.h>

/* Shared bitmap font engine (recovery_font_18x32.png) used by the
   recovery UI and the multiboot boot menu. Implementations live in
   NXRecoveryViewController.m. */

@interface NXRecoveryFontAtlas : NSObject

@property (nonatomic, readonly) NSInteger cellWidth;
@property (nonatomic, readonly) NSInteger cellHeight;

+ (nullable instancetype)sharedAtlas;
- (nullable CGImageRef)imageTintedWithColor:(UIColor *)color;

@end

@interface NXRecoveryGlyphView : UIView

@property (nonatomic, copy) NSString *text;
@property (nonatomic) BOOL bold;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) NSInteger glyphScale;
@property (nonatomic) BOOL wraps;

- (CGSize)cellSizeInPoints;

@end

#endif /* NXRECOVERYFONT_H */
