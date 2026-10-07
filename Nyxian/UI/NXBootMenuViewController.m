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

#import <UI/NXBootMenuViewController.h>
#import <UI/NXRecoveryFont.h>
#import <UI/NXRecoveryViewController.h>
#import <UI/NXVolumeButtonMonitor.h>

static const NSInteger NXBootMenuGlyphScale = 1;
static const CGFloat NXBootMenuFooterGap = 8.0;

static UIColor *NXBootMenuColor(CGFloat r, CGFloat g, CGFloat b)
{
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

@interface NXBootMenuRow : NSObject

@property (nonatomic, strong) UIView *bar;
@property (nonatomic, strong) NXRecoveryGlyphView *glyph;

@end

@implementation NXBootMenuRow
@end

@interface NXBootMenuViewController ()

@property (nonatomic, copy) NSArray<NSString *> *titles;
@property (nonatomic, copy) NXBootMenuBootAction onBoot;

@property (nonatomic, strong) NXRecoveryGlyphView *titleView;
@property (nonatomic, strong) UIStackView *menuStack;
@property (nonatomic, strong) NXRecoveryGlyphView *footerView;

@property (nonatomic, strong) NSMutableArray<NXBootMenuRow *> *rows;

@property (nonatomic) NSInteger selectedIndex;
@property (nonatomic) NSInteger menuOffset;
@property (nonatomic) NSInteger visibleWindow;

@end

@implementation NXBootMenuViewController

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles
                        onBoot:(NXBootMenuBootAction)onBoot
{
    self = [super initWithNibName:nil bundle:nil];
    if(self)
    {
        _titles = [(titles ?: @[]) copy];
        _onBoot = [onBoot copy];
        _rows = [NSMutableArray array];
        _selectedIndex = 0;
        _menuOffset = 0;
        _visibleWindow = 0;
    }
    return self;
}

- (NXRecoveryGlyphView *)makeGlyphWrapping:(BOOL)wraps
                                     color:(UIColor *)color
                                      bold:(BOOL)bold
{
    NXRecoveryGlyphView *v = [NXRecoveryGlyphView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.glyphScale = NXBootMenuGlyphScale;
    v.wraps = wraps;
    v.color = color;
    v.bold = bold;
    return v;
}

- (UIView *)makeRuleWithColor:(UIColor *)color
{
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = color;
    [v.heightAnchor constraintEqualToConstant:[self px:2.0]].active = YES;
    return v;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = NXBootMenuColor(0.0, 0.0, 0.0);

    UIColor *titleColor = NXBootMenuColor(1.0, 1.0, 1.0);
    UIColor *entryColor = NXBootMenuColor(196/255.0, 196/255.0, 196/255.0);
    UIColor *ruleColor = NXBootMenuColor(1.0, 1.0, 1.0);

    NXRecoveryGlyphView *title = [self makeGlyphWrapping:NO color:titleColor bold:YES];
    title.text = @"NYXIAN BOOT MENU";
    [self.view addSubview:title];
    self.titleView = title;

    UIView *topRule = [self makeRuleWithColor:ruleColor];
    [self.view addSubview:topRule];

    UIStackView *stack = [UIStackView new];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 0;
    [self.view addSubview:stack];
    self.menuStack = stack;

    UIView *bottomRule = [self makeRuleWithColor:ruleColor];
    [self.view addSubview:bottomRule];

    NXRecoveryGlyphView *footer = [self makeGlyphWrapping:YES color:entryColor bold:NO];
    footer.text = @"Volume up/down to move, hold both to boot";
    [self.view addSubview:footer];
    self.footerView = footer;

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:guide.topAnchor constant:12],
        [title.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],
        [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:guide.leadingAnchor constant:8],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:guide.trailingAnchor constant:-8],

        [topRule.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [topRule.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [topRule.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],

        [stack.topAnchor constraintEqualToAnchor:topRule.bottomAnchor constant:6],
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],

        [bottomRule.topAnchor constraintEqualToAnchor:stack.bottomAnchor constant:6],
        [bottomRule.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [bottomRule.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],

        [footer.topAnchor constraintGreaterThanOrEqualToAnchor:bottomRule.bottomAnchor constant:NXBootMenuFooterGap],
        [footer.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-12],
        [footer.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
    ]];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if(self.titles.count == 0)
    {
        return;
    }
    if([self effectiveMenuWindow] != self.visibleWindow)
    {
        [self rebuildRows];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self activate];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self deactivate];
}

- (void)activate
{
    [self armVolumeInput];
}

- (void)deactivate
{
    [self disarmVolumeInput];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)armVolumeInput
{
    __weak typeof(self) weakSelf = self;
    [NXVolumeButtonMonitor armWithHandler:^(NSInteger button, NSString *kind) {
        [weakSelf handleButton:button kind:kind];
    }];
}

- (void)disarmVolumeInput
{
    [NXVolumeButtonMonitor disarm];
}

- (void)handleButton:(NSInteger)button kind:(NSString *)kind
{
    if(self.titles.count == 0)
    {
        return;
    }

    if([kind isEqualToString:@"select"])
    {
        [self disarmVolumeInput];
        if(self.onBoot != nil)
        {
            self.onBoot((NSUInteger)self.selectedIndex);
        }
        return;
    }

    NSInteger delta = (button == NXRecoveryButtonVolumeUp) ? -1 : 1;
    NSInteger count = (NSInteger)self.titles.count;
    self.selectedIndex = (((self.selectedIndex + delta) % count) + count) % count;
    [self applyRows];
}

- (CGFloat)px:(CGFloat)pixels
{
    CGFloat scale = self.traitCollection.displayScale;
    if(scale <= 0.0)
    {
        scale = UIScreen.mainScreen.scale;
    }
    return (scale > 0.0) ? (pixels / scale) : pixels;
}

- (CGFloat)menuCellHeight
{
    NXRecoveryGlyphView *probe = [self makeGlyphWrapping:NO color:NXBootMenuColor(1.0, 1.0, 1.0) bold:NO];
    return [probe cellSizeInPoints].height;
}

- (CGFloat)menuRowHeight
{
    return [self menuCellHeight] + 2.0 * [self px:2.0];
}

- (NSInteger)autoMenuWindow
{
    CGFloat rowHeight = [self menuRowHeight];
    if(rowHeight <= 0.0)
    {
        return 1;
    }

    CGFloat top = CGRectGetMinY(self.menuStack.frame);
    CGFloat bottom = CGRectGetMinY(self.footerView.frame);

    if(bottom <= top)
    {
        top = 0.0;
        bottom = CGRectGetHeight(self.view.bounds);
        if(bottom <= top)
        {
            return 1;
        }
    }

    /* stack.bottom + 6 + rule + footer gap must still fit above the footer */
    CGFloat chrome = 6.0 + [self px:2.0] + NXBootMenuFooterGap;
    CGFloat available = (bottom - top) - chrome;
    if(available < rowHeight)
    {
        return 1;
    }
    return MAX(1, (NSInteger)floor(available / rowHeight));
}

- (NSInteger)effectiveMenuWindow
{
    NSInteger count = (NSInteger)self.titles.count;
    if(count == 0)
    {
        return 0;
    }
    NSInteger window = [self autoMenuWindow];
    return MIN(MAX(window, 1), count);
}

- (void)clampMenuOffset
{
    NSInteger count = (NSInteger)self.titles.count;
    NSInteger window = self.visibleWindow;
    if(count == 0 || window <= 0 || window >= count)
    {
        self.menuOffset = 0;
        return;
    }

    NSInteger offset = self.menuOffset;
    if(self.selectedIndex < offset)
    {
        offset = self.selectedIndex;
    }
    else if(self.selectedIndex >= offset + window)
    {
        offset = self.selectedIndex - window + 1;
    }

    self.menuOffset = MIN(MAX(offset, 0), count - window);
}

- (void)rebuildRows
{
    for(NXBootMenuRow *row in self.rows)
    {
        [row.bar removeFromSuperview];
    }
    [self.rows removeAllObjects];

    NSInteger window = [self effectiveMenuWindow];
    self.visibleWindow = window;
    if(window == 0)
    {
        return;
    }

    CGFloat rowHeight = [self menuRowHeight];
    CGFloat cellHeight = [self menuCellHeight];

    for(NSInteger slot = 0; slot < window; slot++)
    {
        UIView *bar = [UIView new];
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        bar.backgroundColor = [UIColor clearColor];

        NXRecoveryGlyphView *glyph = [self makeGlyphWrapping:NO color:NXBootMenuColor(196/255.0, 196/255.0, 196/255.0) bold:NO];
        [bar addSubview:glyph];
        [NSLayoutConstraint activateConstraints:@[
            [bar.heightAnchor constraintEqualToConstant:rowHeight],
            [glyph.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
            [glyph.heightAnchor constraintEqualToConstant:cellHeight],
            [glyph.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:[self px:8.0]],
            [glyph.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        ]];

        [self.menuStack addArrangedSubview:bar];

        NXBootMenuRow *row = [NXBootMenuRow new];
        row.bar = bar;
        row.glyph = glyph;
        [self.rows addObject:row];
    }

    [self applyRows];
}

- (void)applyRows
{
    [self clampMenuOffset];

    NSInteger count = (NSInteger)self.titles.count;
    for(NSInteger slot = 0; slot < (NSInteger)self.rows.count; slot++)
    {
        NSInteger index = self.menuOffset + slot;
        NXBootMenuRow *row = self.rows[slot];

        if(index < 0 || index >= count)
        {
            row.glyph.text = @"";
            row.glyph.color = NXBootMenuColor(196/255.0, 196/255.0, 196/255.0);
            row.glyph.bold = NO;
            continue;
        }

        BOOL selected = (index == self.selectedIndex);
        NSString *prefix = selected ? @"> " : @"  ";
        row.glyph.text = [prefix stringByAppendingString:self.titles[index]];
        row.glyph.color = selected ? NXBootMenuColor(1.0, 1.0, 1.0)
                                   : NXBootMenuColor(196/255.0, 196/255.0, 196/255.0);
        row.glyph.bold = selected;
    }
}

@end
