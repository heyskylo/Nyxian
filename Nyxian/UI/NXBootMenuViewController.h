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

#ifndef NXBOOTMENUVIEWCONTROLLER_H
#define NXBOOTMENUVIEWCONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^NXBootMenuBootAction)(NSUInteger index);

/* OpenCore-style text based multiboot picker rendered with the shared
   bitmap font. Volume up/down moves the selection, holding both volume
   buttons boots the selected entry. */
@interface NXBootMenuViewController : UIViewController

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles
                        onBoot:(NXBootMenuBootAction)onBoot;

/* Arms volume button input. Called by the bootloader once the menu is
   on screen; viewDidAppear does the same as a fallback. */
- (void)activate;

@end

NS_ASSUME_NONNULL_END

#endif /* NXBOOTMENUVIEWCONTROLLER_H */
