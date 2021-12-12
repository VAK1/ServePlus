//
//  OnboardingController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 10/5/21.
//
//  Page View Controller to manage the navigation and aesthetics of the tutorial

import Foundation
import UIKit

class OnboardingController: UIPageViewController {
    
    
    // Initialize container for the tutorial's pages, or sections
    var pages = [UIViewController]()

    // External controls
    let skipButton = UIButton()
    let nextButton = UIButton()
    let pageControl = UIPageControl()
    let initialPage = 0

    // Animations
    var skipButtonTopAnchor: NSLayoutConstraint?
    var nextButtonTopAnchor: NSLayoutConstraint?
    var pageControlBottomAnchor: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup, style and layout the tutorial
        setup()
        style()
        layout()
    }
}

extension OnboardingController {
    
    func setup() {
        
        /* Initialize the pages of the overarching Onboarding Controller. Each
           page will be a subcontroller, called an OnboardingViewController. */
        
        // Set the data source and delegate
        dataSource = self
        delegate = self
        
        
        /* If the little dots at the bottom of the page view controller are tapped,
           then navigate to the relevant page */
        pageControl.addTarget(self, action: #selector(pageControlTapped(_:)), for: .valueChanged)

        
        // Initialize the necessary pages
        let page1 = OnboardingViewController(imageName: "OnboardingImage1",
                                             titleText: "ServePlus brings AI to you",
                                             subtitleText: "AI for your tennis serve. It's time to get excited!",
                                             imageSize: 0.8 ) // Welcome
        let page2 = OnboardingViewController(imageName: "OnboardingImage2",
                                             titleText: "Get your serves in",
                                             subtitleText: "Start with recording a video of your serves, or upload a previous clip.",
                                             imageSize: 1.0) // How to use
        let page3 = OnboardingViewController(imageName: "OnboardingImage3",
                                             titleText: "Improve",
                                             subtitleText: "Review feedback in real time through the \"Review\" tab.",
                                             imageSize: 1.1) // How to review
        let page4 = OnboardingViewController(imageName: "OnboardingImage4",
                                             titleText: "Track your growth",
                                             subtitleText: "Monitor progress graphs through the \"Analyze\" tab.",
                                             imageSize: 1.1) // How to grow
        
        
        // Add the pages to the reference array
        pages.append(page1)
        pages.append(page2)
        pages.append(page3)
        pages.append(page4)
        
        
        // Set the pages to be displayed in a forward scrolling fashion
        setViewControllers([pages[initialPage]], direction: .forward, animated: true, completion: nil)
    }
    
    func style() {
        
        /* Add some style to the Page Control */
        
        
        // parameter to make the contraints apply properly
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        
        
        // Set the current page dot on the page control to black
        pageControl.currentPageIndicatorTintColor = .black
        
        
        // Set all other page dots to gray
        pageControl.pageIndicatorTintColor = .systemGray2
        
        
        // Set the number of page dots to the number of pages
        pageControl.numberOfPages = pages.count
        
        
        // Set the current page dot to the first page
        pageControl.currentPage = initialPage

        
        
        
        /* Add some style to the Finish button*/
        
        // parameter to make the contraints apply properly
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        
        
        // give the Finish button a blue color
        skipButton.setTitleColor(.systemBlue, for: .normal)
        
        
        // give the Finish button a title of "Finish"
        skipButton.setTitle("Finish", for: .normal)
        
        
        // Signal that the skip button was tapped and act accordingly
        skipButton.addTarget(self, action: #selector(skipTapped(_:)), for: .primaryActionTriggered)
        
        
        
        
        /* Add some style to the Next button*/
        
        // parameter to make the contraints apply properly
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        
        
        // give the Next button a blue color
        nextButton.setTitleColor(.systemBlue, for: .normal)
        
        
        // give the Next button a title of "Next"
        nextButton.setTitle("Next", for: .normal)
        
        
        // Signal that the skip button was tapped and act accordingly
        nextButton.addTarget(self, action: #selector(nextTapped(_:)), for: .primaryActionTriggered)
    }
    
    func layout() {
        
        // Add the page control dots and navigation buttons
        view.addSubview(pageControl)
        view.addSubview(nextButton)
        view.addSubview(skipButton)
        
        
        /* Position the page control at the bottom and the control buttons
            on the top corners */
        NSLayoutConstraint.activate([
            pageControl.widthAnchor.constraint(equalTo: view.widthAnchor),
            pageControl.heightAnchor.constraint(equalToConstant: 20),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            skipButton.leadingAnchor.constraint(equalToSystemSpacingAfter: view.leadingAnchor, multiplier: 2),

            view.trailingAnchor.constraint(equalToSystemSpacingAfter: nextButton.trailingAnchor, multiplier: 2),
        ])
        
        
        /* Keep track of the button positions in case animations take
           the buttons elsewhere */
        skipButtonTopAnchor = skipButton.topAnchor.constraint(equalToSystemSpacingBelow: view.safeAreaLayoutGuide.topAnchor, multiplier: 2)
        nextButtonTopAnchor = nextButton.topAnchor.constraint(equalToSystemSpacingBelow: view.safeAreaLayoutGuide.topAnchor, multiplier: 2)
        pageControlBottomAnchor = view.bottomAnchor.constraint(equalToSystemSpacingBelow: pageControl.bottomAnchor, multiplier: 2)

        skipButtonTopAnchor?.isActive = true
        nextButtonTopAnchor?.isActive = true
        pageControlBottomAnchor?.isActive = true
    }
}

extension OnboardingController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        /* If the user swipes to the previous page, go there */

        // Check that the page exists
        guard let currentIndex = pages.firstIndex(of: viewController) else { return nil }
        
        
        // Only go left if the current page isn't the first page
        if currentIndex != 0 {
            return pages[currentIndex - 1]
        }
        return nil
    }
        
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        /* If the user swipes to the next page, go there */
        
        // Check that the page exists
        guard let currentIndex = pages.firstIndex(of: viewController) else { return nil }

        
        // Only go right if the current page isn't th elast page
        if currentIndex < pages.count - 1 {
            return pages[currentIndex + 1]
        }
        return nil
    }
}

extension OnboardingController: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        
        /* Sync the page control dots with the actual pages being displayed*/
        
        
        // Fetch the pages
        guard let viewControllers = pageViewController.viewControllers else { return }
        
        
        // Get the index of the current page
        guard let currentIndex = pages.firstIndex(of: viewControllers[0]) else { return }
        
        
        // Let the page control know what the current page is
        pageControl.currentPage = currentIndex
        
        
        // Animate the changes if necessary
        animateControlsIfNeeded()
    }
    
    private func animateControlsIfNeeded() {
        
        /* If the tutorial is on the last page, hide the controls. Otherwise,
           put the controls back where they belong. */
        
        // Boolean that knows whether the current page is the last one.
        let lastPage = pageControl.currentPage == pages.count - 1
        
        
        // Hide the "next" button if this is the last page
        if lastPage {
            hideControls()
        }
        
        // show the "next" button if this is not the last page
        else {
            showControls()
        }

        
        /* This PropertyAnimator will ensure that whenever controls are hidden
           or unhidden, they will glide seamlessly back onto display */
        UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0.5, delay: 0, options: [.curveEaseOut], animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    private func hideControls() {
        
        // Take the next button off-screen
        nextButtonTopAnchor?.constant = -80
    }

    private func showControls() {
        
        // Put the controls back onto the screen
        pageControlBottomAnchor?.constant = 16
        skipButtonTopAnchor?.constant = 16
        nextButtonTopAnchor?.constant = 16
    }
}

extension OnboardingController {

    @objc func pageControlTapped(_ sender: UIPageControl) {
        
        /* If one of the page control dots are tapped, go to the respective
           page */
        
        // Set the current page to the respective page tapped.
        setViewControllers([pages[sender.currentPage]], direction: .forward, animated: true, completion: nil)
        
        
        // If necessary, animate the controls
        animateControlsIfNeeded()
    }

    @objc func skipTapped(_ sender: UIButton) {
        
        /* If the user presses the "finish" button, dismiss the tutorial */
        dismiss(animated: true, completion: nil)

    }
    
    @objc func nextTapped(_ sender: UIButton) {
        
        /* If the user presses the "next" button, go to the next page*/
        pageControl.currentPage += 1
        goToNextPage()
        animateControlsIfNeeded()
    }
}

extension UIPageViewController {

    func goToNextPage(animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        
        /* Set the next page as the view controller, if applicable*/
        
        // Fetch the current page
        guard let currentPage = viewControllers?[0] else { return }
        
        
        /* Get the next page given the current page, and return nothing if
           there is no proper next page */
        guard let nextPage = dataSource?.pageViewController(self, viewControllerAfter: currentPage) else { return }
        
        
        // Set the next page as the current page
        setViewControllers([nextPage], direction: .forward, animated: animated, completion: completion)
    }
    
    func goToPreviousPage(animated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        
        /* Set the previous page as the view controller, if applicable*/
        
        // Fetch the current page
        guard let currentPage = viewControllers?[0] else { return }
        
        
        /* Get the last page given the current page, and return nothing if
           there is no proper last page */
        guard let prevPage = dataSource?.pageViewController(self, viewControllerBefore: currentPage) else { return }
        
        
        // Set the last page as the current page
        setViewControllers([prevPage], direction: .forward, animated: animated, completion: completion)
    }
}
