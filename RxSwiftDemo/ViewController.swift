import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController, UITableViewDelegate {

    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    static let startLoadingOffset: CGFloat = 20.0
    static func isNearTheBottomEdge(contentOffset: CGPoint, _ tableView: UITableView) -> Bool {
        return contentOffset.y + tableView.frame.size.height + startLoadingOffset > tableView.contentSize.height
    }
    
    let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, Repository>>()
    var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "RxSwift Demo"
        
        let tableView = self.tableView
        let searchField = self.searchField
        
        dataSource.cellFactory = { (tv, ip, repository: Repository) in
            let cell = tv.dequeueReusableCellWithIdentifier("Cell")!
            cell.textLabel?.text = repository.name
            cell.detailTextLabel?.text = repository.url
            return cell
        }
        
        dataSource.titleForHeaderInSection = { [unowned dataSource] sectionIndex in
            let section = dataSource.sectionAtIndex(sectionIndex)
            return section.items.count > 0 ? "Repositories (\(section.items.count))" : "No repositories found"
        }
        
        
        let loadNextPageTrigger = tableView.rx_contentOffset
            .flatMap { offset in
                ViewController.isNearTheBottomEdge(offset, tableView)
                    ? Observable.just()
                    : Observable.empty()
        }
        
        let searchResult = searchField.rx_text.asDriver()
            .throttle(0.3)
            .distinctUntilChanged()
            .flatMapLatest { query -> Driver<RepositoriesState> in
                if query.isEmpty {
                    return Driver.just(RepositoriesState.empty)
                } else {
                    return GitHubSearchRepositoriesAPI.sharedAPI.search(query, loadNextPageTrigger: loadNextPageTrigger)
                        .asDriver(onErrorJustReturn: RepositoriesState.empty)
                }
        }
        
        searchResult
            .map { $0.serviceState }
            .drive(navigationController!.rx_serviceState)
            .addDisposableTo(disposeBag)
        
        searchResult
            .map { [SectionModel(model: "Repositories", items: $0.repositories)] }
            .drive(tableView.rx_itemsWithDataSource(dataSource))
            .addDisposableTo(disposeBag)
        
        searchResult
            .filter { $0.limitExceeded }
            .driveNext { n in
                showAlert("Exceeded limit of 10 non authenticated requests per minute for GitHub API. Please wait a minute. :(\nhttps://developer.github.com/v3/#rate-limiting")
            }
            .addDisposableTo(disposeBag)
        
        // dismiss keyboard on scroll
        tableView.rx_contentOffset
            .subscribe { _ in
                if searchField.isFirstResponder() {
                    _ = searchField.resignFirstResponder()
                }
            }
            .addDisposableTo(disposeBag)
        
        // so normal delegate customization can also be used
        tableView.rx_setDelegate(self)
            .addDisposableTo(disposeBag)
        
        // activity indicator in status bar
        GitHubSearchRepositoriesAPI.sharedAPI.activityIndicator
            .drive(UIApplication.sharedApplication().rx_networkActivityIndicatorVisible)
            .addDisposableTo(disposeBag)
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

}

