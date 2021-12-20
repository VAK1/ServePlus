//
//  PracticeViewController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/4/21.
//
//  View controller class for displaying all of the practice sessions
//  the user has built up over time. This view controller helps the user
//  review metadata about their practice sessions (e.g. date, practice
//  length, number of serves), and also allows them to review scores
//  for their individual serves by segueing to the Feedback Controller.


import UIKit
import AVFoundation
import Foundation
import CoreGraphics

class PracticeViewController: UIViewController {
    
    
    /* context helps this controller link to the app's data model to retrieve
       and update the user's practices. */
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    /* boolean indicating whether or not this is the final build. If false, the
       tutorial will launch on every run. */
    let productionMode = false

    /* defaults are used to store whether or not the user is launching the app
       for the first time. */
    let defaults = UserDefaults.standard

    
    var practices:[Practice]?       // Array to store the user's practices.
    var dateLabels:[String]?        // Array to store the dates of all practices.
    var serveLabels:[String]?       // Array to store labels that indicate the number
                                    // of serves in a practice.
    var durationLabels:[String]?    // Array to store labels that indicate the
                                    // duration of a practice.

    var thumbnails:[UIImage]?       // Array to store the thumbnails of every
                                    // practice.
     
    @IBOutlet weak var tableView: UITableView!       /* Connection to the table view
                                                        that displays the practices */
    @IBOutlet weak var emptyTableMessage: UILabel!   /* Text that displays if the
                                                        user hasn't uploaded any
                                                        practices */
    @IBOutlet weak var emptyTableView: UIView!       /* View that will contain the
                                                        empty table message */
    @IBOutlet weak var emptyTableImage: UIImageView! /* Faux background that will
                                                        be displayed behind the
                                                        empty table message */
    
    var practiceToSegue: Practice?  /* When a practice is selected for review by
                                       the user, this variable will contain that
                                       practice object */
 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Review"  /* Sets the title of this view controller in the Tab
                             Bar controller that displays on the bottom of the
                             app */
        
        // Give user update alert if a new version of my app has been released
        let bundleId = "VikramKhandelwal.ServePlus"
        let appUpdater = AppUpdateManager()
        let updateStatus = appUpdater.updateStatus(for: bundleId)

        if let alertController = UIAlertController(for: updateStatus) {
            self.present(alertController, animated: true)
        }
        
        
        // Determine whether or not to conduct the onboarding tutorial
        if self.productionMode == false {
            defaults.set(false, forKey: "First Launch")
        }
        if !defaults.bool(forKey: "First Launch") == true {
            self.conductTutorial()
            defaults.set(true, forKey: "First Launch")
        }
        
        
        // Settings for the empty table view
        let bgImage = UIImage(named: "DefaultBackground")
        let imgWidth = bgImage!.size.width
        let imgHeight = bgImage!.size.height
        
    
        // Calculate the responsive (real) height of my background image
        let ratio = imgWidth/emptyTableImage.frame.width
        let realHeight = imgHeight/ratio
        
        
        // Apply the background image
        emptyTableImage.frame.size = CGSize(width: emptyTableImage.frame.width, height: CGFloat(realHeight))
        emptyTableImage.image = bgImage
        emptyTableImage.blurImage()
        
        
        /* Register two table cell types: one for practices that were recorded
           with a landscape camera, and another for practices that were taken
           with a portrait camera */
        let nib1 = UINib(nibName: "WideVideoCell", bundle: nil)
        tableView.register(nib1, forCellReuseIdentifier: "WideVideoCell")
        let nib2 = UINib(nibName: "TallVideoCell", bundle: nil)
        tableView.register(nib2, forCellReuseIdentifier: "TallVideoCell")
        
        
        // Set the table view delegate and data source
        tableView.delegate = self
        tableView.dataSource = self
        
        
        // Fetch all of the practices and reload the table view
        fetchPractices()
        tableView.refreshControl = UIRefreshControl()
        
        
        // If the user swipes down on the table view, it will reload
        tableView.refreshControl?.addTarget(self,
                                            action: #selector(pullRefresh),
                                            for: .valueChanged)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {

        /* Ensures that all the practices from the database will be represented
           in the table view. */

        super.viewWillAppear(animated)
        
        
        // Get the current number of practices available to the table view
        let currentCount = self.practices!.count
        
        DispatchQueue.main.async {
            
            // Fetch all the practices from the database
            self.fetchPractices()
            
            
            /* Check for any discrepancies between the percieved practices
               and the true number of practices */
            if self.practices!.count != currentCount {
                
                
                // Reload the table view if there is a difference
                self.tableView.reloadData()
            }
        }



    }
    
    func conductTutorial() {
        
        // Segue to the onboarding controller for the tutorial
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
            self.performSegue(withIdentifier:"OnboardingSegue", sender: self)
        }
    }
    
    @objc private func pullRefresh() {
        
        // Refresh the table view controller
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
            self.fetchPractices()
            self.tableView.reloadData()
            self.tableView.refreshControl?.endRefreshing()

        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // Segue to the feedback controller
        if segue.identifier == "buttonSegueFeedback" {
            if let destinationVC = segue.destination as? FeedbackController {
                
                /* give the feedback controller the practice selected by the
                   user */
                destinationVC.practice = self.practiceToSegue
            }
        }
        
        // Segue to the onboarding controller
        if segue.identifier == "OnboardingSegue" {
        }
    }
    
    func doSegue(_ practiceIndex: Int) {
        
        /* Given a practiceIndex, fetch the respective practice and segue
           to the feedback controller */
        self.practiceToSegue = self.practices![practiceIndex]
        self.performSegue(withIdentifier: "buttonSegueFeedback", sender: self)
    }
    
    func getThumbnailImage(url: URL) -> UIImage? {
        
        /* Generate a thumbnail image given a video URL*/
        
        // Create Image Generator from URL
        let asset = AVAsset(url: url)
        let avAssetImageGenerator = AVAssetImageGenerator(asset: asset)
        avAssetImageGenerator.appliesPreferredTrackTransform = true
        
        
        // Set thumbnail to the second frame of the video
        let thumbnailTime = CMTimeMake(value: 2, timescale: 1)
        do {
            let cgThumbImage = try avAssetImageGenerator.copyCGImage(at: thumbnailTime, actualTime: nil)
            let thumbNailImage = UIImage(cgImage: cgThumbImage).withRoundedCorners(radius: 30.0)
            return thumbNailImage
        } catch {
            
            // Print the error
            print(error.localizedDescription)
            return nil
        }

    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        /* This function needs to be present in all table view controllers */
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        /* Returns the height of a given table view cell depending on the
           cell's video dimensions */
        
        
        let ratio = thumbnails![indexPath.row].size.width / thumbnails![indexPath.row].size.height
        
        
        // Quick math to determine responsive height of a cell
        if ratio > 1 {
            return (tableView.frame.width-40) / ratio + 120
        }
        else {
            return ((tableView.frame.width-40) * 0.6) / ratio + 30
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        
        
        // If the user swipes on a table view cell, that row will be deleted.
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        
        /* If a user deletes a cell from the table view, then that cell's
           practice should be deleted form the database. */
        
        if editingStyle == .delete {
            
            // Declare that we will update the table view.
            tableView.beginUpdates()
            
            
            // Remove the thumbnail from the table view's reference array
            self.thumbnails!.remove(at:indexPath.row)
            
            
            // Remove the labels from the table view's reference arrays
            self.serveLabels!.remove(at:indexPath.row)
            self.dateLabels!.remove(at:indexPath.row)
            self.durationLabels!.remove(at:indexPath.row)
            
            
            // Delete the practice from the database
            self.deletePractice(self.practices![indexPath.row])
            
            
            // Remove the practice from the table view's reference array
            self.practices!.remove(at: indexPath.row)

            
            // Remove the cell form the table
            tableView.deleteRows(at: [indexPath], with: .fade)
        
            
            // Declare that the table view's updates are finished
            tableView.endUpdates()
        }
    }
    
    func fetchPractices() {
        
        /* Fetches all of the practices, preprocesses the results and stores
           them in arrays the table view can reference and present nicely. */
        
        do {
            
            // Fetch the practices
            self.practices = try self.context.fetch(Practice.fetchRequest())
            
            
            // Order them in reverse chronological order for display
            self.practices = self.practices!.reversed()
            
            
            /* Initialize arrays for labels that will be displayed on every
               table view cell */
            var dateLabels:[String] = []
            var serveLabels:[String] = []
            var durationLabels:[String] = []
            
            
            /* Initialize array for thumbnail images */
            var imgs:[UIImage] = []
            
            
            // Loop through all of the retrieved practices
            for practice in self.practices! {
                
                
                // Generate and store a thumbnail image from the practice's video
                if let img = self.getThumbnailImage(url: practice.urls![0]) {
                    imgs.append(img)
                }
                
                
                // Generate and store a date label to be displayed on the cell
                let date = practice.date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, y | hh:mm"
                dateLabels.append(dateFormatter.string(from: date!))
                
                
                // Generate and store a serve count label to be displayed on the cell
                if (practice.vectors!.count) == 1 {
                    serveLabels.append("1 serve")
                }
                else {
                    serveLabels.append(String(practice.vectors!.count) + " serves")
                }
                
                
                // Generate and store a duration label to be displayed on the cell
                let durationTime = Float64(CMTimeGetSeconds(AVAsset(url: practice.urls![0]).duration))

                if durationTime < 60.0 {
                    if Int(ceil(durationTime)) % 60 == 1 {
                        durationLabels.append("1 second")
                    }
                    else {
                        durationLabels.append(String(Int(ceil(durationTime)) % 60) + " seconds")
                    }
                }
                else if durationTime > 120.0 {
                    if (Int(durationTime) % 60) > 0 {
                        if Int(durationTime) % 60 == 1 {
                            durationLabels.append(String(Int(floor(durationTime / 60))) + " minutes and 1 second")
                        }
                        else {
                            durationLabels.append(String(Int(floor(durationTime / 60))) + " minutes and " + String(Int(durationTime) % 60) + " seconds")
                        }
                    }
                    else {
                        durationLabels.append(String(Int(floor(durationTime / 60))) + " minutes")
                    }
                }
                else {
                    if (Int(durationTime) % 60) > 0 {
                        if Int(durationTime) % 60 == 1 {
                            durationLabels.append(String(Int(floor(durationTime / 60))) + " minute and 1 second")
                        }
                        else {
                            durationLabels.append(String(Int(floor(durationTime / 60))) + " minute and " + String(Int(durationTime) % 60) + " seconds")
                        }
                    }
                    else {
                        durationLabels.append(String(Int(floor(durationTime / 60))) + " minute")
                    }
                }
            }
            
            
            // Store the results in variables accessible by the table view
            self.dateLabels = dateLabels
            self.serveLabels = serveLabels
            self.durationLabels = durationLabels
            self.thumbnails = imgs
            
        } catch {
            
            print("Couldn't properly fetch practices.")
        }
    }
    
    
    
    func deletePractice(_ practice: Practice) {
        
        /* Given a practice object, delete it from the database */
        
        
        // Delete the practice
        self.context.delete(practice)
        
        do {
            //Save the database
            try self.context.save()
            
        } catch {
            
            print("Couldn't save practices after deleting")
        }
    }

}
extension PracticeViewController: UITableViewDataSource{
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        // Only one section (no table divisions)
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // If there aren't any practices, display the empty table view
        if self.practices!.count == 0 {
             self.tableView.setEmptyMessage(self.emptyTableView, label: self.emptyTableMessage)
        } else {
            self.tableView.restore(self.emptyTableView)
        }
        
        // Return the number of cells
        return self.practices!.count
    }
    
}
extension PracticeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        /* Required function for all UITableViewDelegates */
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        /* Return a table cell for every practice in the database */
        
        
        // Fetch the practice thumbnail
        let img = self.thumbnails![indexPath.row]
        
        
        /* Calculate image size to determine whether to dequeue a landscape
           video cell or a portrait video cell */
        let size = img.size
        let width = abs(Int(size.width))
        let height = abs(Int(size.height))
 
        
        // Dequeue the landscape practice cell
        if (width > height) {
            
            // Get reference to landscape practice cell object
            let cell = tableView.dequeueReusableCell(withIdentifier: "WideVideoCell", for: indexPath)  as! WideVideoCell
            
            
            // Give the cell the ability to segue to the feedback controller
            cell.pSegue = self.doSegue
            
            
            // Give the cell an identity based on its position in the table view
            cell.index = indexPath.row
            
            
            // Set the cell's thumbnail
            cell.VideoPlayer?.image = self.thumbnails![indexPath.row]
            
            
            //Set the cell's labels
            cell.serveCountLabel?.text = self.serveLabels![indexPath.row]
            cell.vidDurationLabel?.text = self.dateLabels![indexPath.row]
            cell.timeLabel?.text = self.durationLabels![indexPath.row]


            return cell
        }
        
        
        // Dequeue the portrait video cell
        else {
            
            
            // Get reference to portrait practice cell object
            let cell = tableView.dequeueReusableCell(withIdentifier: "TallVideoCell", for: indexPath) as! TallVideoCell
            
            
            // Give the cell the ability to segue to the feedback controller
            cell.pSegue = self.doSegue

            
            // Give the cell an identity based on its position in the table view
            cell.index = indexPath.row
            
            
            // Set the cell's thumbnail
            cell.VideoPlayer?.image = self.thumbnails![indexPath.row]


            // Se the cell's labels
            cell.serveCountLabel?.text = self.serveLabels![indexPath.row]
            cell.vidDurationLabel?.text = self.dateLabels![indexPath.row]
            cell.timeLabel?.text = self.durationLabels![indexPath.row]


            return cell
        }
        
    }
    
   
    


}
extension UIImage {
    
        public func withRoundedCorners(radius: CGFloat? = nil) -> UIImage? {
            
            /* Return a thumbnail with rounded corners */

            /* Determine the maximum possible radius (before the image
               turns into a circle */
            let maxRadius = min(size.width, size.height) / 2
            
            
            // Initialize placeholder variable for the final corner radius
            let cornerRadius: CGFloat
            
            
            // Check if the radius is less than the maximum radius
            if let radius = radius, radius > 0 && radius <= maxRadius {
                cornerRadius = radius
            } else {
                cornerRadius = maxRadius
            }
            
            
            // Create a bitmap-based graphics context that matches the image
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            
            
            // Create a rounded rectangle mask and apply it to the image
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
            draw(in: rect)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            
            
            // Terminate the context
            UIGraphicsEndImageContext()
            
            
            return image
        }
    }
extension UITableView {
    

    func setEmptyMessage(_ emptyMessageView: UIView, label: UILabel) {
        
        /* If there aren't any practices in the database, set the empty
           table message */

        /* Set the background color to blue, in case the default background
           doesn't display properly */
        emptyMessageView.backgroundColor = UIColor.systemBlue
        
        // Set the message
        label.text = "Welcome to ServePlus!\n\nStart improving your serve immediately by heading over to the 'Record and Upload' tab on the left.\n\nAfter recording a serve, you can come back here to review areas of improvement."
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20)
        label.sizeToFit()
        
        
        // Hide the actual table view and show the empty message view
        emptyMessageView.isHidden = false
        self.isHidden = true
    }

    func restore(_ emptyMessageView: UIView) {
        
        /* Hide the empty message view and show the actual message view */
        
        self.isHidden = false
        emptyMessageView.isHidden = true
    }
}

extension UIImageView{
    
    /* Apply a blur effect to any image (specifically, the background image
       of the empty table view */
    
    func blurImage()
    {
        // Get a reference to a dark blur effect
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        
        
        // Establish a UIView mask with the blur effect
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        
        // Set the frame of the mask to the frame of the image
        blurEffectView.frame = self.bounds
        
        
        // Add the mask as a subview to apply the blur
        self.addSubview(blurEffectView)
    }
}
