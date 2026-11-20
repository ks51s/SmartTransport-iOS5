#import "STCityViewController.h"
#import "STStore.h"
#import "STTheme.h"

@interface STCityViewController ()
@property(nonatomic, retain) NSArray *items;
@property(nonatomic, retain) UISearchBar *searchBar;
@end

@implementation STCityViewController

@synthesize items = _items;
@synthesize searchBar = _searchBar;

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) self.title = @"Город";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.searchBar = [[[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)] autorelease];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Название города";
    STApplySearchBarTheme(self.searchBar);
    self.tableView.tableHeaderView = self.searchBar;
    STApplyTableTheme(self.tableView);
    [self filter:@""];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    STApplySearchBarTheme(self.searchBar);
}

- (void)filter:(NSString *)query {
    NSArray *cities = [[STStore sharedStore].cities sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
        return [STString([first objectForKey:@"name"]) localizedCaseInsensitiveCompare:STString([second objectForKey:@"name"])];
    }];
    if (query.length) {
        cities = [cities filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id city, NSDictionary *bindings) {
            return [STString([city objectForKey:@"name"]) rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }]];
    }
    self.items = cities;
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { [self filter:searchText]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"CityCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    NSDictionary *city = [self.items objectAtIndex:indexPath.row];
    cell.textLabel.text = STString([city objectForKey:@"name"]);
    cell.detailTextLabel.text = STString([city objectForKey:@"title"]);
    cell.accessoryType = [STString([city objectForKey:@"code"]) isEqualToString:[STStore sharedStore].cityCode]
        ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *city = [self.items objectAtIndex:indexPath.row];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Загрузка…" style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
    [[STStore sharedStore] selectCityCode:STString([city objectForKey:@"code"]) completion:^(NSError *error) {
        self.navigationItem.rightBarButtonItem = nil;
        if (error && [STStore sharedStore].stations.count == 0) STShowError(self, [error localizedDescription]);
        else [self.navigationController popToRootViewControllerAnimated:YES];
    }];
}

- (void)dealloc {
    [_items release];
    [_searchBar release];
    [super dealloc];
}

@end
