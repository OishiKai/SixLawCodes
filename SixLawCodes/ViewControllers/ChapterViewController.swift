//
//  ArticreViewController.swift
//  SixLawCodes
//
//  Created by kai on 2021/02/01.
//

import UIKit
import SwiftyXMLParser
import Reachability
import SVProgressHUD

class ChapterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
    @IBOutlet weak var tableView: UITableView!
    
    var chapterNum: Int = 0;
    var setLawNumber = ""
    var titles: [String] = []
    var chapterTitles: [String] = []
    var partTitleFlag = false
    var partTitles: [String] = []
    
    private var ExceptionStatus = true
    private var part = 0
    private var fixIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: ChapterListTableViewCell.cellIdentifier, bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: ChapterListTableViewCell.cellIdentifier)

        if self.setLawNumber == "昭和二十三年法律第百三十一号" && self.chapterTitles.count == 7 {
            self.ExceptionStatus = true
        }else{
            self.ExceptionStatus = false
        }
        print(ExceptionStatus)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chapterNum
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChapterListTableViewCell.cellIdentifier, for: indexPath) as! ChapterListTableViewCell
        cell.chapterTitle.text = chapterTitles[indexPath.row]
        if self.partTitleFlag == true{
            cell.partTitle.text = partTitles[indexPath.row]
        }
        tableView.tableFooterView = UIView()
        
        if self.setLawNumber == "昭和二十一年憲法" {
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let reachability = try! Reachability()
        if reachability.connection == .unavailable {
            let alert = ErrorAlert.internetError()
            present(alert, animated: true, completion: nil)
            return
        }
        SVProgressHUD.show()
        
        ArticleRepository.fetchArticle(row: indexPath.row, setLawNumber: self.setLawNumber) { (data: Data?, response: URLResponse?, error: Error?) in
            let xml = XML.parse(data!)
            
            if xml.error != nil {
                DispatchQueue.main.async { // メインスレッドで行うブロック
                    SVProgressHUD.dismiss()
                    let alert = ErrorAlert.parseError()
                    self.present(alert, animated: true, completion: nil)
                }
                return
            }
            
            if self.setLawNumber == "昭和二十三年法律第百三十一号" && self.ExceptionStatus == true && (indexPath.row == 0 || indexPath.row == 1 || indexPath.row == 2) {
                let chapterNum = self.ExCountChapter(data: data, row: indexPath.row)
                let title = self.ExGetChapterTitle(data: data, row: indexPath.row)
                
                DispatchQueue.main.async { // メインスレッドで行うブロック
                    SVProgressHUD.dismiss()
                    let storyboard = UIStoryboard(name: "Chapter", bundle: nil)
                    let nextVC = storyboard.instantiateViewController(identifier: "chapter")as! ChapterViewController
                    self.navigationController?.pushViewController(nextVC, animated: true)
                    nextVC.chapterNum = chapterNum
                    nextVC.chapterTitles = title
                    nextVC.setLawNumber = self.setLawNumber
                    nextVC.partTitleFlag = self.partTitleFlag
                    nextVC.partTitles = self.partTitles
                    nextVC.title = self.chapterTitles[indexPath.row]
                    nextVC.part = indexPath.row
                }
            }else{
                let articleNum = self.countArticle(data: data, row: indexPath.row)
                let chapterTitle = self.getChapterTitle(data: data, row: indexPath.row)
                
                self.titles = []
                self.titles = self.getTitleSeq(data: data, articleNum: articleNum, row: indexPath.row)
                DispatchQueue.main.async { // メインスレッドで行うブロック
                    SVProgressHUD.dismiss()
                    let storyboard = UIStoryboard(name: "Article", bundle: nil)
                    let nextVC = storyboard.instantiateViewController(identifier: "article")as! ArticleViewController
                    self.navigationController?.pushViewController(nextVC, animated: true)
                    nextVC.title = chapterTitle
                    nextVC.articleNum = articleNum
                    nextVC.setLawNumber = self.setLawNumber
                    nextVC.chapterNum = indexPath.row - self.fixIndex
                    nextVC.articleCount = self.titles
                    nextVC.part = self.part
                }
            }
        }
    }

    
    func countArticle (data: Data?, row : Int) -> Int {
        let xml = XML.parse(data!)
        if self.setLawNumber == "昭和二十一年憲法" {
            let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Chapter", row, "Article"]
            let articleNum = text.all?.count ?? 0
            return articleNum
        }else if self.setLawNumber == "明治四十年法律第四十五号" {
            if row <= 12{
                let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", 0, "Chapter", row, "Article"]
                let articleNum = text1.all?.count ?? 0
                self.part = 0
                return articleNum
            }else{
                let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", 1, "Chapter", row - 13, "Article"]
                let articleNum = text1.all?.count ?? 0
                self.part = 1
                self.fixIndex = 13
                return articleNum
            }
        }else if self.setLawNumber == "明治二十九年法律第八十九号" {
            self.part = 0
            self.fixIndex = 0
            switch row {
            case (0...6):
                self.part = 0
            case (7...16):
                self.part = 1
                self.fixIndex = 7
                print("")
            case (17...21):
                self.part = 2
                self.fixIndex = 17
            case (22...28):
                self.part = 3
                self.fixIndex = 22
            case (29...100):
                self.part = 4
                self.fixIndex = 29
            default:
                self.fixIndex = 0
            }
            let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Article"]
            if text.all?.count == nil {
                let textEX = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section"]
                let sectionNum = textEX.all?.count ?? 0
                var articleNum = 0
                for i in 0...(sectionNum - 1) {
                    let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Article"]
                    let a = text1.all?.count ?? 0
                    articleNum += a
                }
                return articleNum
            }
            let articleNum = text.all?.count ?? 0
            return articleNum
        }else if self.setLawNumber == "明治三十二年法律第四十八号" {
            self.part = 0
            self.fixIndex = 0
            switch row {
            case (0...6):
                self.part = 0
            case (7...15):
                self.part = 1
                self.fixIndex = 7
                print("")
            case (16...100):
                self.part = 2
                self.fixIndex = 16
            default:
                self.fixIndex = 0
            }
            let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Article"]
            if text.all?.count == nil {
                let section = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section"]
                let sectionCnt = section.all?.count ?? 0
                var artCnt = 0
                for i in 0...(sectionCnt - 1) {
                    let consSub = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Article"]
                    let articleCnt = consSub.all?.count ?? 0
                    if articleCnt == 0 {
                        let sub = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Subsection"]
                        let subCnt = sub.all?.count ?? 0
                        for j in 0...(subCnt - 1) {
                            let art = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Subsection", j, "Article"]
                            let artNum = art.all?.count ?? 0
                            artCnt += artNum
                        }
                    }else{
                        artCnt += articleCnt
                    }
                }
                return artCnt
            }
            let articleNum = text.all?.count ?? 0
            return articleNum
        }else if self.setLawNumber == "昭和二十三年法律第百三十一号" {
            if ExceptionStatus == true {
                let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", row, "Article"]
                let artNum = text.all?.count ?? 0
                return artNum
            }else {
                let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", row, "Article"]
                let artNum = text.all?.count ?? 0
                return artNum
            }
        }
        return 0
    }
    
    func getTitleSeq(data:Data?, articleNum: Int, row : Int) -> [String] {
        let xml = XML.parse(data!)
        var Seq :[String] = []
        if self.setLawNumber == "昭和二十一年憲法" {
            for i in 0...(articleNum - 1){
                let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Chapter", row,"Article" ,i, "ArticleTitle"]
                Seq.append(text1.element?.text ?? "")
            }
            return Seq
        }else if self.setLawNumber == "明治四十年法律第四十五号" {
            if row <= 12{
                for i in 0...(articleNum - 1){
                    let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", 0, "Chapter", row,"Article" ,i, "ArticleTitle"]
                    Seq.append(text1.element?.text ?? "")
                }
            }else{
                let truePath = row - 13
                for i in 0...(articleNum - 1){
                    let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", 1, "Chapter", truePath,"Article" ,i, "ArticleTitle"]
                    Seq.append(text1.element?.text ?? "")
                }
            }
        }else if self.setLawNumber == "明治二十九年法律第八十九号" {
            let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Article"]
            if text.all?.count == nil{
                let textEX = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section"]
                let sectionNum = textEX.all?.count ?? 0
                for i in 0...(sectionNum - 1) {
                    let a = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Article"]
                    let num = a.all?.count ?? 0
                    
                    if num == 0{
                        let c = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Subsection"]
                        let subsectionCount = c.all?.count ?? 0
                        for n in 0...(subsectionCount - 1) {
                            let d = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Subsection", n, "Article"]
                            let articleCnt = d.all?.count ?? 0
                            for m in 0...(articleCnt - 1){
                                let e = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Subsection", n, "Article", m, "ArticleTitle"]
                                Seq.append(e.element?.text ?? "")
                            }
                        }
                        
                    }else{
                        for j in 0...(num - 1) {
                            let b = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Article", j, "ArticleTitle"]
                            Seq.append(b.element?.text ?? "")
                        }
                    }
                }
            }else {
                for i in 0...(articleNum - 1) {
                    let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Article",i, "ArticleTitle"]
                    Seq.append(text.element?.text ?? "")
                }
            }
        }else if self.setLawNumber == "明治三十二年法律第四十八号" {
            let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Article"]
            if text.all?.count == nil{
                let textEX = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section"]
                let sectionNum = textEX.all?.count ?? 0
                for i in 0...(sectionNum - 1) {
                    let a = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Article"]
                    let num = a.all?.count ?? 0
                    
                    if num == 0{
                        let c = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Subsection"]
                        let subsectionCount = c.all?.count ?? 0
                        for n in 0...(subsectionCount - 1) {
                            let d = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Subsection", n, "Article"]
                            let articleCnt = d.all?.count ?? 0
                            for m in 0...(articleCnt - 1){
                                let e = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Subsection", n, "Article", m, "ArticleTitle"]
                                Seq.append(e.element?.text ?? "")
                            }
                        }
                        
                    }else{
                        for j in 0...(num - 1) {
                            let b = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Section", i, "Article", j, "ArticleTitle"]
                            Seq.append(b.element?.text ?? "")
                        }
                    }
                }
            }else {
                for i in 0...(articleNum - 1) {
                    let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "Article",i, "ArticleTitle"]
                    Seq.append(text.element?.text ?? "")
                }
            }
        }else if self.setLawNumber == "昭和二十三年法律第百三十一号" {
            if ExceptionStatus == true {
                let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", row, "Article"]
                let artNum = text.all?.count ?? 0
                for i in 0...(artNum - 1) {
                    let artTitle = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", row, "Article", i, "ArticleTitle"]
                    let title = artTitle.element?.text ?? ""
                    Seq.append(title)
                }
            }else {
                let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", row, "Article"]
                let artNum = text.all?.count ?? 0
                for i in 0...(artNum - 1) {
                    let artTitle = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", row, "Article", i, "ArticleTitle"]
                    let title = artTitle.element?.text ?? ""
                    Seq.append(title)
                }
            }
        }
        return Seq
    }
    
    func getChapterTitle (data: Data?, row : Int) -> String?{
        let xml = XML.parse(data!)
        if self.setLawNumber == "昭和二十一年憲法" {
            let titleA = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Chapter", row, "ChapterTitle"]
            let chapterTitle = titleA.element?.text
            return chapterTitle
        }else if self.setLawNumber == "明治四十年法律第四十五号"{
            if row <= 12{
                let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", 0, "Chapter" ,row, "ChapterTitle"]
                let chapterTitle = text1.element?.text
                return chapterTitle
            }else {
                let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", 1, "Chapter" ,row - 13, "ChapterTitle"]
                let chapterTitle = text1.element?.text
                return chapterTitle
            }
        }else if self.setLawNumber == "明治二十九年法律第八十九号" {
            let text1 = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter" , (row - self.fixIndex), "ChapterTitle"]
            let chapterTitle = text1.element?.text
            return chapterTitle
        }else if self.setLawNumber == "明治三十二年法律第四十八号" {
            let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", self.part, "Chapter", (row - self.fixIndex), "ChapterTitle"]
            let chapterTitle = text.element?.text
            return chapterTitle
        }else if self.setLawNumber == "昭和二十三年法律第百三十一号" {
            return chapterTitles[row]
        }
        return nil
    }
    
    func ExCountChapter(data: Data?, row: Int) -> Int {
        let xml = XML.parse(data!)
        let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", row, "Chapter"]
        let count = text.all?.count ?? 0
        return count
    }
    
    func ExGetChapterTitle(data: Data?, row: Int) -> [String] {
        var titles: [String] = []
        let xml = XML.parse(data!)
        let text = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", row, "Chapter"]
        let count = text.all?.count ?? 0
        for i in 0...(count - 1) {
            let parseTitle = xml["DataRoot", "ApplData", "LawFullText", "Law", "LawBody", "MainProvision", "Part", row, "Chapter", i, "ChapterTitle"]
            let title = parseTitle.element?.text ?? ""
            titles.append(title)
        }
        return titles
    }

}
