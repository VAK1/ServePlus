//
//  FeedbackController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 5/18/21.
//
//  View Controller to manage the feedback UI. Users will be able
//  to scroll through their individual serves and get feedback on
//  each serve. Users will be able to get more detailed feedback
//  on each feedback category as well. Users can delete individual
//  serves and the entire serve practice.

import UIKit
import AVKit
import AVFoundation

class FeedbackController: UIViewController
{

    // Reference to the container view
    @IBOutlet weak var contentView: UIView!
    
    
    /* context helps this controller link to the app's data model to retrieve
       and update the user's practices. */
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    
    // Reference to the URL array (an array with the same repeated input URL)
    var urlArray: [URL]?
    
    
    /* Reference to the timestamps (starting and ending frames of each
       individual serve */
    var timestamps: [[Int]]?
    
    
    // Reference to the scores of each individual serve
    var serveVectorArray: [[Double]]?
    
    
    /* Reference to the practice that this feedback controller will be
       displaying */
    var practice: Practice!
    
    
    // Reference to the current serve the view controller will display
    var currentViewControllerIndex = 0
    
    
    // Reference to the feedback page view controller
    var pageViewController: CustomPageViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the custom page view controller
        configurePageViewController()
    }
    
    func deletePractice(_ practice: Practice) {
        
        /* Delete a practice from the database and save the database */
        
        self.context.delete(practice)
        do {
            try self.context.save()
        } catch {
            print("Couldn't save practices after deleting")
        }
    }
    
    func updatePractice(_ practice: Practice, _ serveURLs: [URL], _ serveVectors: [[Double]], _ timestamps: [[Int]]) {
        
        /* Update a practice from the database and save the database */
        
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
        
        /* Give the page view controller the starting feedback controller
           and establish the delegate and data source*/
            
        
        // Get the input video URL
        self.urlArray = self.practice.urls
        
        
        // Get the starting and ending frames for each serve
        self.timestamps = self.practice.timestamps
        
        
        // Get the scores for each serve
        self.serveVectorArray = self.practice.vectors
        
        
        // Instantiate a custom page view controller
        pageViewController = (storyboard?.instantiateViewController(identifier: String(describing: CustomPageViewController.self)) as! CustomPageViewController)
        
        
        // Set the delegate and data source of the page view controller
        pageViewController!.delegate = self
        pageViewController!.dataSource = self
        
        
        // Add the page view controller as a child to this view controller
        addChild(pageViewController!)
        
        
        // Tell the page view controller it has a new dad
        pageViewController!.didMove(toParent: self)
        
        
        // Apply constraints properly
        pageViewController!.view.translatesAutoresizingMaskIntoConstraints = false
                
        
        // Add the PVC's view as a subview to the container view
        contentView.addSubview(pageViewController!.view)
        
        
        // Add the PVC into an array of views
        let views: [String: Any] = ["pageView": pageViewController?.view as Any]
        
        
        // Horizontally and vertically center the container view
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[pageView]-0-|",
                                                                 options: NSLayoutConstraint.FormatOptions(rawValue: 0),
                                                                 metrics: nil,
                                                                 views: views))
        
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[pageView]-0-|",
                                                                 options: NSLayoutConstraint.FormatOptions(rawValue: 0),
                                                                 metrics: nil,
                                                                 views: views))

        
        // Set the current page as the starting view controller
        guard let startingViewController = detailViewControllerAt(index: currentViewControllerIndex) else {
            return
        }
        
        
        // Give the PVC the current page to start
        pageViewController!.setViewControllers([startingViewController], direction: .forward, animated: true)

    }
    
    func detailViewControllerAt(index: Int) -> DataViewController? {
        
        /* Return the view controller for a specific page index */
        
        // Check that the specified index exists
        if index >= serveVectorArray!.count || serveVectorArray!.count == 0 {
            return nil
        }

        // Instantiate a page
        guard let dataViewController = storyboard?.instantiateViewController(identifier: String(describing: DataViewController.self)) as? DataViewController else {
            return nil
        }
        
        
        // Pause the individual serve video on that page
        if (dataViewController.VideoPlayer != nil) {
            dataViewController.VideoPlayer.playerLayer.player?.pause()
        }
        
        
        // Assign the page its index
        dataViewController.index = index
        
        
        // Pass the input video and necessary starting and ending frames
        dataViewController.url = urlArray![index]
        dataViewController.startEnd = timestamps![index]
        
        
        // Pass the necessary scores
        dataViewController.serveVector = self.serveVectorArray![index]
        
        
        /* If this is the only serve left in the practice, then the
           page will delete the entire practice from the database if the
           user deletes this serve */
        dataViewController.thisIsTheLastPage = deletePage
        
        
        return dataViewController
    }

}

extension FeedbackController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        
        /* Determine which page dot to bold in the page indicator */
        
        return currentViewControllerIndex
    }
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        
        /* Determine how many page dots to display */
        
        return urlArray!.count
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        /* Returns the previous page */
        
        // Get the current view controller's index
        let dataViewController = viewController as? DataViewController
        guard var currentIndex = dataViewController?.index else {
            return nil
        }
        
        // Check that this is not the first page
        if currentIndex == 0 {
            return nil
        }
        
        // Decrement the current index
        currentIndex -= 1
        
        
        // Set the new index
        currentViewControllerIndex = currentIndex

        
        // Return the page at the new index
        return detailViewControllerAt(index: currentIndex)
        
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        /* Returns the next page */
        
        // Get the current view controller's index
        let dataViewController = viewController as? DataViewController
        guard var currentIndex = dataViewController?.index else {
            return nil
        }
        
        // Check that this is not the first page
        if currentIndex == urlArray!.count {
            return nil
        }
        
        // Increment the current index
        currentIndex += 1
        
        
        // Set the new index
        currentViewControllerIndex = currentIndex

        
        // Return the page at the new index
        return detailViewControllerAt(index: currentIndex)
        
    }
    
    func deletePage(_ viewController: UIViewController) -> Bool {
        let dataViewController = viewController as? DataViewController
        
        /* If a user deletes a serve, delete the respective page */
        
        // Get the current page's index
        guard let currentIndex = dataViewController?.index else {
            /* Tell the page it doesn't have to dismiss the feedback
               controller and return to the home screen */
            return false
        }
        
        /* If this was the last serve, delete this page and delete
           the entire practice */
        if urlArray!.count <= 1 {
            urlArray!.remove(at: currentIndex)
            self.deletePractice(self.practice!)
            
            /* Tell the page to dismiss the feedback controller and return
               to the home screen */
            return true
        }
        
        /* At this point, this page must not have been the last one left
           in the practice */
        
        // Remove the related url from the data source of urls
        urlArray!.remove(at: currentIndex)
        
        
        // Remove the related timestamp from the data source of timestamps
        timestamps!.remove(at: currentIndex)
        
        
        // Remove the related scores from the data source of scores
        serveVectorArray!.remove(at: currentIndex)
        
        
        // Update the related practice with the new data
        self.updatePractice(self.practice!, self.urlArray!, self.serveVectorArray!, self.timestamps!)
        
        
        /* If this is the final page of the practice, set the current page
           index to the previous page */
        if currentIndex >= urlArray!.count {
            currentViewControllerIndex = currentIndex - 1
        }
        
        /* Get a reference to the new view controller now that the current
           one has been deleted */
        guard let startingViewController = detailViewControllerAt(index: currentViewControllerIndex) else {
            
            /* Tell the page it doesn't have to dismiss the feedback
               controller and return to the home screen */
            return false
        }
        
        
        // Pass the new view controller to the page view controller
        pageViewController!.setViewControllers([startingViewController], direction: .forward, animated: true)
                   
        
        /* Tell the page it doesn't have to dismiss the feedback
           controller and return to the home screen */
        return false
    }
}
