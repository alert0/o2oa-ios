//
//  TodoTaskViewController.swift
//  O2Platform
//
//  Created by 刘振兴 on 16/8/1.
//  Copyright © 2016年 zoneland. All rights reserved.
//

import UIKit
import Alamofire
import AlamofireImage
import AlamofireObjectMapper
import SwiftyJSON
import ObjectMapper

import CocoaLumberjack


struct TaskURLGenenater {
    var url:String
    var pageModel:CommonPageModel
    
    func pagingURL() -> String {
        var tUrl = self.url
        tUrl = AppDelegate.o2Collect.setRequestParameter(tUrl, requestParameter:self.pageModel.toDictionary() as [String : AnyObject]?)!
        return tUrl.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
    }
    
//    mutating func nextPage(_ pageModel:CommonPageModel?) -> String {
//        if let pModel = pageModel {
//            self.pageModel = pModel
//        }
//        var tUrl = self.url
//        tUrl = AppDelegate.o2Collect.setRequestParameter(tUrl, requestParameter:self.pageModel.toDictionary() as [String : AnyObject]?)!
//        return tUrl.addingPercentEscapes(using: String.Encoding.utf8)!
//    }
}

class TodoTaskViewController: UITableViewController {
    
    var segmentedControl:SegmentedControl!
    
    var currentTaskURLGenenater:TaskURLGenenater!
    
    var models:[TodoCellModel<TodoTask>] = []
    
    var filterModels:[TodoCellModel<TodoTask>] = []
    
    var emptyTexts:[String] = ["没有要处理的待办","没有要处理的待阅","没有已办数据","没有已阅数据"]
    
    var urls:[Int:TaskURLGenenater] {
        let todoTaskURL = AppDelegate.o2Collect.generateURLWithAppContextKey(TaskContext.taskContextKey, query: TaskContext.todoTaskListQuery, parameter: nil,coverted: false)
        
        let todoedTaskURL = AppDelegate.o2Collect.generateURLWithAppContextKey(TaskedContext.taskedContextKey, query: TaskedContext.taskedListByPageSizeQuery, parameter: nil,coverted: false)
        
        let readTaskURL = AppDelegate.o2Collect.generateURLWithAppContextKey(ReadContext.readContextKey, query: ReadContext.readListByPageSizeQuery, parameter: nil,coverted: false)

        let readedTaskURL = AppDelegate.o2Collect.generateURLWithAppContextKey(ReadedContext.readedContextKey, query: ReadedContext.readedListByPageSizeQuery, parameter: nil,coverted: false)

        return [0: TaskURLGenenater(url: todoTaskURL!,pageModel: CommonPageModel()),2: TaskURLGenenater(url: todoedTaskURL!,pageModel: CommonPageModel()),1 : TaskURLGenenater(url: readTaskURL!,pageModel: CommonPageModel()),3: TaskURLGenenater(url: readedTaskURL!,pageModel: CommonPageModel())]
    }
    
    
    //添加搜索功能
    var fileterUrls:[Int:TaskURLGenenater] {
        let todoTaskURL = AppDelegate.o2Collect.generateURLWithAppContextKey(TaskContext.taskContextKey, query: TaskContext.todoTaskListFilterQuery, parameter: nil,coverted: false)
        
        let todoedTaskURL = AppDelegate.o2Collect.generateURLWithAppContextKey(TaskedContext.taskedContextKey, query: TaskedContext.taskedListByPageSizeFilterQuery, parameter: nil,coverted: false)
        
        let readTaskURL = AppDelegate.o2Collect.generateURLWithAppContextKey(ReadContext.readContextKey, query: ReadContext.readListByPageSizeFilterQuery, parameter: nil,coverted: false)
        
        let readedTaskURL = AppDelegate.o2Collect.generateURLWithAppContextKey(ReadedContext.readedContextKey, query: ReadedContext.readedListByPageSizeFilterQuery, parameter: nil,coverted: false)
        
        return [0: TaskURLGenenater(url: todoTaskURL!,pageModel: CommonPageModel()),2: TaskURLGenenater(url: todoedTaskURL!,pageModel: CommonPageModel()),1 : TaskURLGenenater(url: readTaskURL!,pageModel: CommonPageModel()),3: TaskURLGenenater(url: readedTaskURL!,pageModel: CommonPageModel())]
    }
    
    //搜索文本
    var searchText = ""

    //搜索控件
    var searchController:UISearchController = UISearchController(searchResultsController: nil)
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = ""
        
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
//        if self.searchController.isActive {
//            self.searchController.isActive = false
//        }
//        self.searchController.searchBar.removeFromSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initSegmentedControl()
        let taskIndex = AppConfigSettings.shared.taskIndex
        self.currentTaskURLGenenater = self.urls[taskIndex]
//        //添加搜索功能
        self.searchController.searchResultsUpdater = self
        self.searchController.delegate = self
        self.searchController.dimsBackgroundDuringPresentation = false
        self.searchController.hidesNavigationBarDuringPresentation = false
        definesPresentationContext = true
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).title = "取消"
        let attrs =  [NSAttributedString.Key.font: UIFont.init(name: "PingFangTC-Light", size: 14) ?? UIFont.systemFont(ofSize: 14),
         NSAttributedString.Key.foregroundColor: O2ThemeManager.color(for: "Base.base_color") ?? UIColor.red]
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes(attrs, for: .normal)
        self.searchController.searchBar.searchBarStyle = UISearchBar.Style.minimal
        self.searchController.searchBar.sizeToFit()
//        self.searchController.searchBar.backgroundColor = RGB(251, g: 71, b: 71)
//        self.searchController.searchBar.setImage(UIImage(named: "contact_search"), for: .search, state: .normal)
//        if let searchField = self.searchController.searchBar.value(forKey: "searchField") as? UITextField {
//            searchField.textColor = .white
//        }
        //设置搜索框是否显示
        self.setSearchBarIsShow()
        
        //分页刷新功能
        self.tableView.mj_header = MJRefreshNormalHeader(refreshingBlock: {
           self.headerLoadData()
        })
        
        self.tableView.mj_footer = MJRefreshAutoFooter(refreshingBlock: {
            self.footerLoadData()
        })
        self.headerLoadData()
    }
    
    //隐藏搜索框
    func setSearchBarIsShow(){
        let taskIndex = AppConfigSettings.shared.taskIndex
        if taskIndex ==  2 {
            self.tableView.tableHeaderView = self.searchController.searchBar
        }else{
            if self.searchController.isActive {
                self.searchController.isActive = false
            }
            self.tableView.tableHeaderView = nil
        }
    }
    
    func headerLoadData(){
        DDLogDebug("加载数据。。。。。。。。。")
        let taskIndex = AppConfigSettings.shared.taskIndex
        if !self.searchController.isActive {
            self.currentTaskURLGenenater = self.urls[taskIndex]
            self.currentTaskURLGenenater.pageModel = CommonPageModel()
            self.loadFirstDataByURL()
        }else{
            self.currentTaskURLGenenater = self.fileterUrls[taskIndex]
            self.currentTaskURLGenenater.pageModel = CommonPageModel()
            self.loadFilterFirstDataByURL()
            
        }
        //self.loadDataByURL(genernater!.nextPage(nil))
    }
    
    func footerLoadData(){
        DDLogDebug("获取更多数据。。。。。。。。。。。。。。")
        var genernater = self.currentTaskURLGenenater
        if !(genernater?.pageModel.isLast())! {
            genernater?.pageModel.nextPage()
            if !self.searchController.isActive {
                self.loadDataNextByURL()
            }else{
                self.loadFilterNexdataByURL()
            }
        }else{
            DispatchQueue.main.async {
                self.showSuccess(title: "已到最后一页，没有更多的数据了")
            }
        }

    }
    
    func loadFilterFirstDataByURL(){
        DDLogDebug("查询数据   loadFilterFirstDataByURL")
        let tv = self.tableView as! ZLBaseTableView
        tv.emptyTitle = self.emptyTexts[AppConfigSettings.shared.taskIndex]
        AF.request(self.currentTaskURLGenenater.pagingURL(), method: .post, parameters: ["key":self.searchText], encoding: JSONEncoding.default, headers: nil).responseJSON { (response) in
            switch response.result {
            case .success(let val):
                let type = JSON(val)["type"]
                if type == "success" {
                    self.filterModels.removeAll()
                    let data = JSON(val)["data"]
                    let todoTaskArray = Mapper<TodoTask>().mapArray(JSONString: data.description)
                    if let todoTasks = todoTaskArray {
                        for task in todoTasks {
                            let model = TodoCellModel<TodoTask>(title: task.title,applicationName: task.applicationName,status: task.activityName,time: task.updateTime,sourceObj: task)
                            self.filterModels.append(model)
                        }
                    }
                    //设置页码
                    let count = JSON(val)["count"]
                    //第一次设置总数
                    self.currentTaskURLGenenater.pageModel.setPageTotal(count.int!)
                    DispatchQueue.main.async {
                        if self.searchController.isActive {
                            self.tableView.reloadData()
                        }
                    }
                    
                }else{
                    DispatchQueue.main.async {
                        DDLogError(JSON(val).description)
                        self.showError(title: "查询失败！")
                    }
                }
            case .failure(let err):
               DispatchQueue.main.async {
                   DDLogError(err.localizedDescription)
                   self.showError(title: "查询失败！")
               }
            }
            if tv.mj_header.isRefreshing(){
                tv.mj_header.endRefreshing()
            }
        }

    }
    
    func loadFilterNexdataByURL(){
        DDLogDebug("下一页数据   loadFilterNexdataByURL")
        let tv = self.tableView as! ZLBaseTableView
        tv.emptyTitle = self.emptyTexts[AppConfigSettings.shared.taskIndex]
        guard let todoTask = self.filterModels.last?.sourceObj else {
            DDLogError("没有最后一条数据，无法加载更多。。。。")
            return
        }
        self.currentTaskURLGenenater.pageModel.nextPageId = todoTask.id!
        AF.request(self.currentTaskURLGenenater.pagingURL(), method: .post, parameters: ["key":self.searchText], encoding: JSONEncoding.default, headers: nil).responseJSON { (response) in
            switch response.result {
            case .success(let val):
                let type = JSON(val)["type"]
                if type == "success" {
                    let data = JSON(val)["data"]
                    let todoTaskArray = Mapper<TodoTask>().mapArray(JSONString: data.description)
                    if let todoTasks = todoTaskArray {
                        for task in todoTasks {
                            let model = TodoCellModel<TodoTask>(title: task.title,applicationName: task.applicationName,status: task.activityName,time: task.updateTime,sourceObj: task)
                            self.filterModels.append(model)
                        }
                    }
                    DispatchQueue.main.async {
                        if self.searchController.isActive {
                            self.tableView.reloadData()
                        }
                    }
                    
                }else{
                    DispatchQueue.main.async {
                        DDLogError(JSON(val).description)
                        self.showError(title: "查询失败！")
                    }
                }
            case .failure(let err):
                DispatchQueue.main.async {
                    DDLogError(err.localizedDescription)
                    self.showError(title: "查询失败！")
                }
            }
            if tv.mj_footer.isRefreshing() {
                tv.mj_footer.endRefreshing()
            }
        }

    }

    
    //加载第一页数据
    func loadFirstDataByURL(){
        DDLogDebug("加载数据   loadFirstDataByURL")
        let tv = self.tableView as! ZLBaseTableView
        tv.emptyTitle = self.emptyTexts[AppConfigSettings.shared.taskIndex]
        AF.request(self.currentTaskURLGenenater.pagingURL(), method: .get, parameters: nil, encoding: JSONEncoding.default, headers: nil).responseJSON { (response) in
            switch response.result {
            case .success(let val):
                let type = JSON(val)["type"]
                if type == "success" {
                    self.models.removeAll()
                    let data = JSON(val)["data"]
                    let todoTaskArray = Mapper<TodoTask>().mapArray(JSONString: data.description)
                    if let todoTasks = todoTaskArray {
                        for task in todoTasks {
                            let model = TodoCellModel<TodoTask>(title: task.title,applicationName: task.applicationName,status: task.activityName,time: task.updateTime,sourceObj: task)
                            self.models.append(model)
                        }
                    }
                    //设置页码
                    let count = JSON(val)["count"]
                    //第一次设置总数
                    self.currentTaskURLGenenater.pageModel.setPageTotal(count.int!)
                    DispatchQueue.main.async {
                        if !self.searchController.isActive {
                            self.tableView.reloadData()
                        }
                    }
                    
                }else{
                    DispatchQueue.main.async {
                        DDLogError(JSON(val).description)
                        self.showError(title: "查询失败！")
                    }
                }
            case .failure(let err):
                DispatchQueue.main.async {
                    DDLogError(err.localizedDescription)
                    self.showError(title: "查询失败！")
                }
            }
            if tv.mj_header.isRefreshing(){
                tv.mj_header.endRefreshing()
            }
        }
        
    }
    
    //加载下一页数据
    func loadDataNextByURL() {
        
        let tv = self.tableView as! ZLBaseTableView
        tv.emptyTitle = self.emptyTexts[AppConfigSettings.shared.taskIndex]
        let todoTask = self.models.last?.sourceObj!
        self.currentTaskURLGenenater.pageModel.nextPageId = (todoTask?.id)!
        AF.request(self.currentTaskURLGenenater.pagingURL(), method: .get, parameters: nil, encoding: JSONEncoding.default, headers: nil).responseJSON { (response) in
            switch response.result {
            case .success(let val):
                let type = JSON(val)["type"]
                if type == "success" {
                    let data = JSON(val)["data"]
                    let todoTaskArray = Mapper<TodoTask>().mapArray(JSONString: data.description)
                    if let todoTasks = todoTaskArray {
                        for task in todoTasks {
                            let model = TodoCellModel<TodoTask>(title: task.title,applicationName: task.applicationName,status: task.activityName,time: task.updateTime,sourceObj: task)
                            self.models.append(model)
                        }
                    }
                    DispatchQueue.main.async {
                        if !self.searchController.isActive {
                            self.tableView.reloadData()
                        }
                    }
                    
                }else{
                    DispatchQueue.main.async {
                        DDLogError(JSON(val).description)
                        self.showError(title: "查询失败！")
                    }
                }
            case .failure(let err):
                DispatchQueue.main.async {
                    DDLogError(err.localizedDescription)
                    self.showError(title: "查询失败！")
                }
            }
            if tv.mj_footer.isRefreshing() {
                tv.mj_footer.endRefreshing()
            }
        }

    }
    
    
    
    
    //初始化控件
    func initSegmentedControl(){
        let titleStrings = ["待办", "待阅", "已办", "已阅"]
        let titles: [NSAttributedString] = {
            let attributes = [NSAttributedString.Key.font: UIFont(name: "PingFangSC-Regular", size: 17.0)!
                , NSAttributedString.Key.foregroundColor: UIColor.white]
            var titles = [NSAttributedString]()
            for titleString in titleStrings {
                let title = NSAttributedString(string: titleString, attributes: attributes)
                titles.append(title)
            }
            return titles
        }()
        let selectedTitles: [NSAttributedString] = {
            let attributes = [NSAttributedString.Key.font: UIFont(name: "PingFangSC-Regular", size: 17.0)!, NSAttributedString.Key.foregroundColor: UIColor.darkGray]
            var selectedTitles = [NSAttributedString]()
            for titleString in titleStrings {
                let selectedTitle = NSAttributedString(string: titleString, attributes: attributes)
                selectedTitles.append(selectedTitle)
            }
            return selectedTitles
        }()
        segmentedControl = SegmentedControl.initWithTitles(titles, selectedTitles: selectedTitles)
        segmentedControl.delegate = self
        segmentedControl.backgroundColor = UIColor.clear
        segmentedControl.selectionBoxColor = UIColor.white
        segmentedControl.selectionBoxStyle = .default
        segmentedControl.selectionBoxCornerRadius = 15
        segmentedControl.frame.size = CGSize(width: 70 * titles.count, height: 30)
        segmentedControl.isLongPressEnabled = true
        segmentedControl.isUnselectedSegmentsLongPressEnabled = true
        segmentedControl.longPressMinimumPressDuration = 1
        //segmentedControl.setTitleAttachedIcons([#imageLiteral(resourceName: "taskSegmentAdditionIcon")], selectedTitleAttachedIcons: [#imageLiteral(resourceName: "taskSegmentAdditionIconSelected")])
        navigationItem.titleView = segmentedControl
        segmentedControl.setSelected(at: AppConfigSettings.shared.taskIndex, animated: true)

    }
    

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if  !self.searchController.isActive {
            return self.models.count
        }else{
            return self.filterModels.count
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TodoTaskTableViewCell", for: indexPath) as! TodoTaskTableViewCell
        if   !self.searchController.isActive {
            let model = self.models[indexPath.row]
            cell.setData(cellModel: model)
        }else{
            let model = self.filterModels[indexPath.row]
            cell.setData(cellModel: model)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        self.performSegue(withIdentifier: "toSignature", sender: nil)
        
        var todoTask:TodoTask?
        if !self.searchController.isActive {
            todoTask = self.models[indexPath.row].sourceObj
        }else{
            todoTask = self.filterModels[indexPath.row].sourceObj
        }
        
        //根据不同的类型跳转显示
        switch self.segmentedControl.selectedIndex {
        case 0:
            self.performSegue(withIdentifier: "showTodoDetailSegue", sender: todoTask)
        case 1:
            self.performSegue(withIdentifier: "showTodoDetailSegue", sender: todoTask)
        case 2:
            self.performSegue(withIdentifier: "showTodoedDetailSegue", sender: todoTask)
        case 3:
            self.performSegue(withIdentifier: "showTodoDetailSegue", sender: todoTask)
        default:
            DDLogDebug("no click")
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    //prepare
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showTodoDetailSegue" {
            let destVC = segue.destination as! TodoTaskDetailViewController
            destVC.todoTask = sender as? TodoTask
            destVC.backFlag = 2 //返回标志
        }else if segue.identifier == "showTodoedDetailSegue" {
            let destVC = segue.destination as! TodoedTaskViewController
            destVC.todoTask = sender as? TodoTask
        }else if segue.identifier == "toSignature" {
            DDLogDebug("签名去了。。。。。。。。。")
        }
    }
    
    //backWindtodoTask
    @IBAction func unWindForTodoTask(_ segue:UIStoryboardSegue){
        DDLogDebug(segue.identifier!)
        self.tableView.mj_header.beginRefreshing()
//        if segue.identifier == "backToTodoTask" {
//            self.segmentedControl.setSelected(at: 0, animated: true)
//            AppConfigSettings.shared.taskIndex = 0
//            self.tableView.mj_header.beginRefreshing()
            //self.segmentedSelected(self.taskSegmentedControl)
//        }else if segue.identifier == "backToReadTask" {
//            self.segmentedControl.setSelected(at: 1, animated: true)
//            AppConfigSettings.shared.taskIndex = 1
//            self.tableView.mj_header.beginRefreshing()
//        }
    }
    
}

//searcher update
extension TodoTaskViewController:UISearchResultsUpdating,UISearchControllerDelegate{
    func willPresentSearchController(_ searchController: UISearchController) {
        DDLogDebug("willPresentSearchController 1, searchController.isActive = \(searchController.isActive)")
        self.models.removeAll()
        self.tableView.reloadData()
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {
        DDLogDebug(" didPresentSearchController 2, searchController.isActive = \(searchController.isActive)")
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
         DDLogDebug(" didPresentSearchController 3, searchController.isActive = \(searchController.isActive)")
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
         DDLogDebug(" didDismissSearchController 4, searchController.isActive = \(searchController.isActive)")
        //self.tableView.mj_header.beginRefreshing()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        DDLogDebug("updateSearchResults........")
        if let sText = searchController.searchBar.text {
            self.searchText = sText
            self.headerLoadData()
        }else {
            DDLogDebug("search text is nil ..................")
        }
        
    }
}

extension TodoTaskViewController:SegmentedControlDelegate{
    func segmentedControl(_ segmentedControl: SegmentedControl, didSelectIndex selectedIndex: Int) {
        DDLogDebug("click \(selectedIndex)")
        AppConfigSettings.shared.taskIndex = selectedIndex
        self.setSearchBarIsShow()
        self.headerLoadData()
        //self.tableView.mj_header.beginRefreshing()
    }
    
    func segmentedControl(_ segmentedControl: SegmentedControl, didLongPressIndex longPressIndex: Int) {
        
    }
}
