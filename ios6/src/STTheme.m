#import "STTheme.h"

static NSString *const STStationIconsKey = @"STShowStationIcons";
static NSString *const STThemeStyleKey = @"STThemeStyle";

BOOL STStationIconsEnabled(void) {
    id saved = [[NSUserDefaults standardUserDefaults] objectForKey:STStationIconsKey];
    // Hundreds of annotations are expensive on an iPhone 3GS/4, so a fresh
    // iOS 6 installation starts with stop icons hidden.
    return saved ? [saved boolValue] : NO;
}

void STSetStationIconsEnabled(BOOL enabled) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:STStationIconsKey];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:STStationVisibilityDidChangeNotification object:nil];
}

STThemeStyle STCurrentThemeStyle(void) {
    id saved = [[NSUserDefaults standardUserDefaults] objectForKey:STThemeStyleKey];
    // The requested flat theme is the default; the classic iOS 6 appearance
    // remains selectable in Settings.
    NSInteger value = saved ? [saved integerValue] : STThemeStyleIOS7;
    if (value < STThemeStyleIOS6 || value > STThemeStyleDark) value = STThemeStyleIOS7;
    return (STThemeStyle)value;
}

void STSetThemeStyle(STThemeStyle style) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:style forKey:STThemeStyleKey];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:STThemeDidChangeNotification object:nil];
}

BOOL STIOS7ThemeEnabled(void) {
    return STCurrentThemeStyle() == STThemeStyleIOS7;
}

BOOL STDarkThemeEnabled(void) {
    return STCurrentThemeStyle() == STThemeStyleDark;
}

UIImage *STSolidColorImage(UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(2.0, 2.0), NO, 0.0);
    [color setFill];
    UIRectFill(CGRectMake(0, 0, 2.0, 2.0));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image stretchableImageWithLeftCapWidth:1 topCapHeight:1];
}

void STApplyNavigationTheme(UINavigationController *navigationController) {
    if (!navigationController) return;
    UINavigationBar *bar = navigationController.navigationBar;
    if (STDarkThemeEnabled()) {
        bar.barStyle = UIBarStyleBlack;
        bar.translucent = NO;
        UIColor *dark = [UIColor colorWithRed:0.09 green:0.10 blue:0.12 alpha:0.98];
        [bar setBackgroundImage:STSolidColorImage(dark) forBarMetrics:UIBarMetricsDefault];
        if ([bar respondsToSelector:@selector(setShadowImage:)]) {
            bar.shadowImage = STSolidColorImage([UIColor colorWithWhite:0.25 alpha:1.0]);
        }
        bar.tintColor = [UIColor colorWithRed:0.18 green:0.55 blue:0.94 alpha:1.0];
        bar.titleTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [UIColor whiteColor], UITextAttributeTextColor,
                                   [NSValue valueWithUIOffset:UIOffsetZero], UITextAttributeTextShadowOffset, nil];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
    } else if (STIOS7ThemeEnabled()) {
        bar.barStyle = UIBarStyleDefault;
        bar.translucent = NO;
        UIColor *white = [UIColor colorWithRed:0.985 green:0.985 blue:0.99 alpha:0.98];
        [bar setBackgroundImage:STSolidColorImage(white) forBarMetrics:UIBarMetricsDefault];
        if ([bar respondsToSelector:@selector(setShadowImage:)]) {
            bar.shadowImage = STSolidColorImage([UIColor colorWithWhite:0.75 alpha:1.0]);
        }
        bar.tintColor = STTintColor();
        bar.titleTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [UIColor colorWithWhite:0.12 alpha:1.0], UITextAttributeTextColor,
                                   [NSValue valueWithUIOffset:UIOffsetZero], UITextAttributeTextShadowOffset, nil];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    } else {
        bar.barStyle = UIBarStyleDefault;
        bar.translucent = NO;
        [bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        if ([bar respondsToSelector:@selector(setShadowImage:)]) bar.shadowImage = nil;
        bar.tintColor = STTintColor();
        bar.titleTextAttributes = nil;
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
    }
}

void STApplyTableTheme(UITableView *tableView) {
    if (!tableView) return;
    if (STDarkThemeEnabled()) {
        UIView *background = [[[UIView alloc] initWithFrame:tableView.bounds] autorelease];
        background.backgroundColor = [UIColor colorWithRed:0.055 green:0.06 blue:0.075 alpha:1.0];
        tableView.backgroundView = background;
        tableView.backgroundColor = background.backgroundColor;
        tableView.separatorColor = [UIColor colorWithWhite:0.23 alpha:1.0];
    } else if (STIOS7ThemeEnabled()) {
        UIView *background = [[[UIView alloc] initWithFrame:tableView.bounds] autorelease];
        background.backgroundColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];
        tableView.backgroundView = background;
        tableView.backgroundColor = background.backgroundColor;
        tableView.separatorColor = [UIColor colorWithWhite:0.79 alpha:1.0];
    } else {
        // groupTableViewBackgroundColor is the dark linen texture on iOS 6.
        // Keep the classic glossy controls, but use the original light blue-
        // gray table canvas so text and grouped cells remain readable.
        UIView *background = [[[UIView alloc] initWithFrame:tableView.bounds] autorelease];
        background.backgroundColor = tableView.style == UITableViewStyleGrouped
            ? [UIColor colorWithRed:0.87 green:0.89 blue:0.92 alpha:1.0]
            : [UIColor whiteColor];
        tableView.backgroundView = background;
        tableView.backgroundColor = background.backgroundColor;
        tableView.separatorColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    }
}

void STApplySearchBarTheme(UISearchBar *searchBar) {
    if (!searchBar) return;
    if (STDarkThemeEnabled()) {
        UIColor *background = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];
        searchBar.backgroundImage = STSolidColorImage(background);
        searchBar.tintColor = background;
    } else if (STIOS7ThemeEnabled()) {
        UIColor *background = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];
        searchBar.backgroundImage = STSolidColorImage(background);
        searchBar.tintColor = background;
    } else {
        searchBar.backgroundImage = nil;
        searchBar.tintColor = STTintColor();
    }
    NSMutableArray *pending = [NSMutableArray arrayWithObject:searchBar];
    while (pending.count) {
        UIView *view = [[[pending lastObject] retain] autorelease];
        [pending removeLastObject];
        if ([view isKindOfClass:[UITextField class]]) {
            UITextField *field = (UITextField *)view;
            field.backgroundColor = STDarkThemeEnabled() ? [UIColor colorWithWhite:0.16 alpha:1.0] : [UIColor whiteColor];
            field.textColor = STDarkThemeEnabled() ? [UIColor whiteColor] : [UIColor blackColor];
            field.keyboardAppearance = STDarkThemeEnabled() ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
        }
        [pending addObjectsFromArray:view.subviews];
    }
}

void STApplyCellTheme(UITableViewCell *cell) {
    if (!cell) return;
    if (STDarkThemeEnabled()) {
        cell.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.14 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.68 alpha:1.0];
        UIView *selected = [[[UIView alloc] initWithFrame:cell.bounds] autorelease];
        selected.backgroundColor = [UIColor colorWithRed:0.16 green:0.24 blue:0.33 alpha:1.0];
        cell.selectedBackgroundView = selected;
    } else {
        cell.backgroundColor = [UIColor whiteColor];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
        cell.selectedBackgroundView = nil;
    }
}
