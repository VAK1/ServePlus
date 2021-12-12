//
//  OnboardingViewController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 10/5/21.
//
//  Template view controller for each page in the tutorial

import Foundation
import UIKit

class OnboardingViewController: UIViewController {
    
    // Initialize view layout for the page components
    let stackView = UIStackView()
    
    
    // Initialize container for image to be displayed on page
    let imageView = UIImageView()
    
    
    // Initialize title and subtitle for each page
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    
    
    // initialize variable for storing the size of the image
    var imageSize: Double?
    
    
    // Cutsom initialization function
    init(imageName: String, titleText: String, subtitleText: String, imageSize: Double) {
        super.init(nibName: nil, bundle: nil)
        
        // Set the imageView's image to the specified image
        imageView.image = UIImage(named: imageName)
        
        
        // Set the title and subtitle text
        titleLabel.text = titleText
        subtitleLabel.text = subtitleText

        
        // Pass along the image size
        self.imageSize = imageSize
    }
    
    
    // required function
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        
        /* Style and layout the page (setup already done) */
        
        super.viewDidLoad()
        style()
        layout()
    }
}

extension OnboardingViewController {
    
    func style() {
        
        // Make the background color responsive to light/dark mode
        view.backgroundColor = UIColor.black
        
        /* Stack View Settings */
        
        // Make the constraints apply properly
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        
        // Center the Stack View
        stackView.axis = .vertical
        stackView.alignment = .center
        
        
        // Add some breathing room
        stackView.spacing = 20
        
        
        
        /* Image View Settings */
        
        // Make the constraints apply properly
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        
        // Autoscale the image
        imageView.contentMode = .scaleAspectFit
        
        
        
        /* Title Label Settings*/
        
        // Make the constraints apply properly
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        
        // Set the default font style
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        
        
        // Make the title color responsive to light/dark mode
        titleLabel.textColor = .label

        
        
        
        /* Subtitle Label Settings */
        
        // Make the constraints apply properly
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        
        // Set the default font style
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        
        
        // Center the text inside the text container
        subtitleLabel.textAlignment = .center
        
        
        // Make the title color responsive to light/dark mode
        subtitleLabel.textColor = .label

        
        // Make sure there is no clipping of text
        subtitleLabel.numberOfLines = 0
    }
        
    func layout() {
        
        /* Put the image and labels in the right place */
        
        // Add the image and labels to the stack view
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        
        // Add the stack view to the main view
        view.addSubview(stackView)
        
        
        // Position the stack view, images and labels
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            imageView.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: CGFloat(imageSize!)),
            
            subtitleLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: view.leadingAnchor, multiplier: 2),
            view.trailingAnchor.constraint(equalToSystemSpacingAfter: subtitleLabel.trailingAnchor, multiplier: 2),
        ])
    }
}
