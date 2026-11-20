#import "STCompatibility.h"

typedef enum {
    STThemeStyleIOS6 = 0,
    STThemeStyleIOS7 = 1,
    STThemeStyleDark = 2
} STThemeStyle;

BOOL STStationIconsEnabled(void);
void STSetStationIconsEnabled(BOOL enabled);
NSInteger STStationSpacingMeters(void);
void STSetStationSpacingMeters(NSInteger meters);

STThemeStyle STCurrentThemeStyle(void);
void STSetThemeStyle(STThemeStyle style);
BOOL STIOS7ThemeEnabled(void);
BOOL STDarkThemeEnabled(void);

UIImage *STSolidColorImage(UIColor *color);
void STApplyNavigationTheme(UINavigationController *navigationController);
void STApplyTableTheme(UITableView *tableView);
void STApplySearchBarTheme(UISearchBar *searchBar);
void STApplyCellTheme(UITableViewCell *cell);
