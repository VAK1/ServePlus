//
//  FeedbackController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 5/18/21.
//

import UIKit
import AVKit
import AVFoundation

class FeedbackController: UIViewController
{

    @IBOutlet weak var contentView: UIView!
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    var urlArray: [URL]?
    var timestamps: [[Int]]?
    var serveVectorArray: [[Double]]?
    var practice: Practice!
    var currentViewControllerIndex = 0
    var pageViewController: CustomPageViewController?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        configurePageViewController()
    }
    
    func deletePractice(_ practice: Practice) {
        self.context.delete(practice)
        do {
            try self.context.save()
        } catch {
            print("Couldn't save practices after deleting")
        }
    }
    
    func updatePractice(_ practice: Practice, _ serveURLs: [URL], _ serveVectors: [[Double]], _ timestamps: [[Int]]) {
        practice.urls = serveURLs
        practice.vectors = serveVectors
        practice.timestamps = timestamps
        do {
            try self.context.save()
        } catch {
            print("Couldn't update practices")
        }
    }
    
    func configurePageViewController() {
        
        self.urlArray = self.practice.urls
        self.timestamps = self.practice.timestamps
        self.serveVectorArray = self.practice.vectors
        pageViewController = (storyboard?.instantiateViewController(identifier: String(describing: CustomPageViewController.self)) as! CustomPageViewController)
        
        pageViewController!.delegate = self
        pageViewController!.dataSource = self
        
        addChild(pageViewController!)
        pageViewController!.didMove(toParent: self)
        
        pageViewController!.view.translatesAutoresizingMaskIntoConstraints = false
                
        contentView.addSubview(pageViewController!.view)
        
        let views: [String: Any] = ["pageView": pageViewController?.view as Any]
        
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[pageView]-0-|",
                                                                 options: NSLayoutConstraint.FormatOptions(rawValue: 0),
                                                                 metrics: nil,
                                                                 views: views))
        
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[pageView]-0-|",
                                                                 options: NSLayoutConstraint.FormatOptions(rawValue: 0),
                                                                 metrics: nil,
                                                                 views: views))

        guard let startingViewController = detailViewControllerAt(index: currentViewControllerIndex) else {
            return
        }
                
        pageViewController!.setViewControllers([startingViewController], direction: .forward, animated: true)

    }
    
    func detailViewControllerAt(index: Int) -> DataViewController? {
        
        if index >= serveVectorArray!.count || serveVectorArray!.count == 0 {
            return nil
        }
        
        if index >= urlArray!.count || urlArray!.count == 0 {
            return nil
        }
        
        guard let dataViewController = storyboard?.instantiateViewController(identifier: String(describing: DataViewController.self)) as? DataViewController else {
            return nil
        }
        
        if (dataViewController.VideoPlayer != nil) {
            dataViewController.VideoPlayer.playerLayer.player?.pause()
        }
        
        dataViewController.index = index
        dataViewController.url = urlArray![index]
        dataViewController.startEnd = timestamps![index]
        dataViewController.serveVector = self.serveVectorArray![index]
        dataViewController.thisIsTheLastPage = deletePage
        
        
        return dataViewController
    }

}

extension FeedbackController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        return currentViewControllerIndex
    }
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return urlArray!.count
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        let dataViewController = viewController as? DataViewController
        
        guard var currentIndex = dataViewController?.index else {
            return nil
        }
        
        currentViewControllerIndex = currentIndex
        
        if currentIndex == 0 {
            return nil
        }
        
        currentIndex -= 1
        
        return detailViewControllerAt(index: currentIndex)
        
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        let dataViewController = viewController as? DataViewController
        
        guard var currentIndex = dataViewController?.index else {
            return nil
        }
        
        
        if currentIndex == urlArray!.count {
            return nil
        }
        
        currentIndex += 1
        
        currentViewControllerIndex = currentIndex

        
        return detailViewControllerAt(index: currentIndex)
        
    }
    
    func deletePage(_ viewController: UIViewController) -> Bool {
        let dataViewController = viewController as? DataViewController
        
        guard let currentIndex = dataViewController?.index else {
            return false
        }
        
        if urlArray!.count <= 1 {
            urlArray!.remove(at: currentIndex)
            self.deletePractice(self.practice!)
            return true
        }
        
        
        urlArray!.remove(at: currentIndex)
        timestamps!.remove(at: currentIndex)
        serveVectorArray!.remove(at: currentIndex)
        self.updatePractice(self.practice!, self.urlArray!, self.serveVectorArray!, self.timestamps!)
        if currentIndex >= urlArray!.count {
            currentViewControllerIndex = currentIndex - 1
        }
        
        guard let startingViewController = detailViewControllerAt(index: currentViewControllerIndex) else {
            return false
        }
        
        
        pageViewController!.setViewControllers([startingViewController], direction: .forward, animated: true)
                        
        return false
    }
}
