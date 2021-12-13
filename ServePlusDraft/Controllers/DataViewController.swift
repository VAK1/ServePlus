//
//  DataViewController.swift
//  PageViewPractice
//
//  Created by Vikram Khandelwal on 5/18/21.
//
//  Template view controller for each individual page of the feedback controller.

import UIKit
import AVKit
import AVFoundation

class DataViewController: UIViewController {
    
    // Reference to this page's number in the feedback controller
    var index: Int?
    
    
    // Reference to the URL of the video this page will display
    var url: URL?
    
    
    // Reference to the score of the serve this page will display
    var serveVector: [Double]?
    
    
    /* Reference to the starting and ending frames of the serve
       this page will display */
    var startEnd: [Int]?
    
    
    /* Function to execute if this is the last serve left in the
       practice - will delete the entire practice */
    var thisIsTheLastPage: ((UIViewController) -> Bool)?
    
    
    // Reference to the current category the user is inspecting
    var currentCategory = 6
    
    
    // Reference to the percent scores of each array
    var percentScores: [String]?
    
    
    // Reference to the current feedback state of the page
    var gestureState = "normal"
    
    
    // Reference to the array of feedback buttnos
    var buttons: [FeedbackButton] = []
    
    
    // Reference to the names of the feedback categories available
    var feedbackCategories = ["Back arched", "Feet spacing", "Back leg follow through", "Jump height", "Left arm straight", "Legs bent", "Timing of shoulder rotation", "Toss height"]
    
    
    // Reference to the image names for each feedback category button
    var iconNames: [String] = [
                               "BendBackTransparent",
                               "FeetSpacingTransparent",
                               "LegKickBackTransparent",
                               "JumpTransparent",
                               "LeftArmTransparent",
                               "BendLegsTransparent",
                               "ShoulderTurnTransparent",
                               "BallTossTransparent",
                               ]
    
    
    /* Reference to the possible English rankings for each feedback
       category */
    var feedbackRankings = [
        ["Too little", "Just a little lacking", "Perfect!", "A little too much", "Way too much"],
        ["Too close", "A little too close", "Perfect!", "A little too far", "Too far apart"],
        ["Didn't kick back", "Perfect!"],
        ["Barely any jump", "Just a little jump", "Average jump", "Fantastic jump!", "Perfect!"],
        ["Crooked left arm", "Perfect!"],
        ["Barely any bending", "Average amount of bend", "Almost perfect", "Perfect!", "A little too much bend"],
        ["Too early", "Just a little early", "Perfect!", "Just a little late", "Too late"],
        ["Too low", "Just a little too low", "Perfect!", "A little too high"]
    ]
    
    
    /* Reference to the colors of each feedback button based on the
       score of that category. E.g. red for a bad scoor and green
       for a good score */
    var feedbackColors = [
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0)
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0)
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0)
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0)
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0)
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0)
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0)
        ]
    ]
    
    
    /* Reference to the possible feedback blurbs for each category, given
       the score of the category */
    var feedbackBlurbs = [
        "Back arched0" :  "Arching your back should be a result of a good service motion. Do it as subconsciously as possible; it should be more of a lean backwards to help you pull up and into the ball.",
        "Back arched1" :  "Lean over a little more for that extra recoil. You may need to toss higher to give yourself time to fully uncoil into the shot.",
        "Back arched2" :  "Perfect! No problems here.",
        "Back arched3" :  "You may be arching your back a little too much. If you are still achieving high mph's, stick with it, but if there is pain you should reduce your back arch.",
        "Back arched4" :  "Your back is arched too much, which will make your serve motion snappy and your placement variable. Arch your back less to generate more 'elastic' energy.",
        "Feet spacing0" :  "Your feet start too close together. Have a wider base to maintain a consistent toss and better balance.",
        "Feet spacing1" :  "Your feet are a little too close together at the beginning of your motion.",
        "Feet spacing2" :  "Perfect! No problems here.",
        "Feet spacing3" :  "Your feet may be a little too far apart at the beginning of your motion. Bring them closer so you can really lean into the serve and bring your racket over the ball.",
        "Feet spacing4" :  "Your feet are too far apart. Bring them closer so you can really lean into the serve and bring your racket on top of the ball.",
        "Back leg follow through0" :  "Your dominant leg isn't kicking back, likely because you aren't jumping forward into the serve. Toss slightly in front of you so you can pull yourself through the ball and kick back your leg to maintain your balance.",
        "Back leg follow through1" :  "Perfect! No problems here.",
        "Jump height0" :  "You aren't jumping at all. Jump higher to give yourself more margin over the net when hitting your serve.",
        "Jump height1" :  "Your jump is okay, but by jumping even higher you can hit the ball harder while still maintaining the same level of consistency.",
        "Jump height2" :  "Your jump is good, but it could be better. Try bending your knees a little bit more, or tossing the ball higher to force yourself to jump more.",
        "Jump height3" :  "Your jump is great! One more centimeter and it'll be perfect!",
        "Jump height4" :  "Perfect! No problems here.",
        "Left arm straight0" :  "Make sure to maintain a straight tossing arm. This will help to create a shoulder tilt, and if you pull your tossing arm into your body as you make contact with the ball, you can generate an additional 5-10 mph.",
        "Left arm straight1" :  "Perfect! No problems here.",
        "Legs bent0" :  "You should bend your legs more. Bend your legs as you toss the ball and bring your racket directly above your head.",
        "Legs bent1" :  "You are bending your legs a decent amount, but by bending more (and earlier) you can push yourself through the ball faster.",
        "Legs bent2" :  "You have great bend on your legs! Just a couple more degrees and you'll be rocking!",
        "Legs bent3" :  "Perfect! No problems here.",
        "Legs bent4" :  "Your legs are bent a little too much. It might get hard to time your jump and judge your toss, so bend your legs less to increase your consistency.",
        "Timing of shoulder rotation0" :  "Rotate your shoulders later, so you can take more advantage of the momentum of an explosive shoulder turn.",
        "Timing of shoulder rotation1" :  "Your shoulder rotation is just a little early. Rotate later for a more connected kinetic chain.",
        "Timing of shoulder rotation2" :  "Perfect! No problems here.",
        "Timing of shoulder rotation3" :  "You are rotating your shoulders a little late. Try pulling your tossing hand into your body and rotating towards your opponent sooner.",
        "Timing of shoulder rotation4" :  "You are rotating your shoulders too late. Start the rotational motion as soon as the ball reaches its peak so you can hit the ball as it's dipping.",
        "Toss height0" :  "You are tossing the ball too low, so you don't have enough time to generate the racket head speed required for a great serve. Toss around 2-3 feet above your maximum racket head height.",
        "Toss height1" :  "Your ball toss is good, but if you toss it higher you can generate the same amount of racket head speed over a longer time, increasing consistency.",
        "Toss height2" :  "Perfect! No problems here.",
        "Toss height3" :  "Your ball toss is too high, so you are losing all the momentum from bringing the racket above your head. Toss the ball a bit lower."
        ]
    
    var currentPulse: PulseAnimation?
    
    // Reference to the container view
    @IBOutlet var bigView: UIView!
    
    
    // Reference to the label for the amalgamated score of the serve
    @IBOutlet weak var totalScoreLabel: UILabel!
    
    
    /* Reference to the label that tells users individual category scores
       in English (e.g. Perfect or Just a little lacking) */
    @IBOutlet weak var displayLabel: UILabel!
    
    
    /* Reference to the label that gives in-depth details for each
       feedback category */
    @IBOutlet weak var feedbackBlurbLabel: UILabel!
    
    
    /* Reference to the label that will tell users to click on a
       category button to inspect categorical scores */
    @IBOutlet weak var scoreLabel: UILabel!
    
    
    /* Reference to the video player that will display the serve being
       analyzed */
    @IBOutlet weak var VideoPlayer: PlayerView!
    
    
    /* Reference to the layer that will be overlayed on top of the
       video player to detect if a user is tapping on the video */
    @IBOutlet weak var overlayLayer: UIView!
    
    
    /* Reference to the label that tells users what category they
       are inspecting */
    @IBOutlet weak var categoryLabel: UILabel!
    
    
    /* Reference to the numerical score that will display for each
       category */
    @IBOutlet weak var rankingLabel: UILabel!
    
    
    // References to the feedback buttons for each category
    @IBOutlet weak var feedbackButton1: FeedbackButton!
    @IBOutlet weak var feedbackButton2: FeedbackButton!
    @IBOutlet weak var feedbackButton3: FeedbackButton!
    @IBOutlet weak var feedbackButton4: FeedbackButton!
    @IBOutlet weak var feedbackButton5: FeedbackButton!
    @IBOutlet weak var feedbackButton6: FeedbackButton!
    @IBOutlet weak var feedbackButton7: FeedbackButton!
    @IBOutlet weak var feedbackButton8: FeedbackButton!


    /* References to the actions that will happen when each
       feedback button is pressed */
    @IBAction func feedback1tapped(_ sender: ReturnButton) {
        updateScoreView(0)
    }
    @IBAction func feedback2tapped(_ sender: ReturnButton) {
        updateScoreView(1)
    }
    @IBAction func feedback3tapped(_ sender: ReturnButton) {
        updateScoreView(2)
    }
    @IBAction func feedback4tapped(_ sender: ReturnButton) {
        updateScoreView(3)
    }
    @IBAction func feedback5tapped(_ sender: ReturnButton) {
        updateScoreView(4)
    }
    @IBAction func feedback6tapped(_ sender: ReturnButton) {
        updateScoreView(5)
    }
    @IBAction func feedback7tapped(_ sender: ReturnButton) {
        updateScoreView(6)
    }
    @IBAction func feedback8tapped(_ sender: ReturnButton) {
        updateScoreView(7)
    }
    
    
    // Reference to the button that will delete the page's serve
    @IBOutlet weak var cancelServe: UIButton!
    
    
    /* Reference to the action that will happen when the delete
       button is pressed */
    @IBAction func cancelServeTapped(_ sender: ReturnButton) {
        if thisIsTheLastPage!(self) {
            dismiss(animated: true, completion: nil)
        }
    }
    
    
    /* Reference to the details button - leads to more in-depth
       feedback for an individual feedback category */
    @IBOutlet weak var detailsButton: UIButton!
    
    
    /* Reference to the action that will happen when the details
       button is pressed */
    @IBAction func detailsButtonTapped(_ sender: Any) {
        
        // Check that the page is in it's normal display state
        if self.gestureState == "normal" {
            
            
            /* Set the state to "feedbackInfo" so the page knows that
               in-depth feedback is being presented */
            self.gestureState = "feedbackInfo"
            
            
            
            /* Execute some UI transitions */
            
            UIView.animate(withDuration:0.6) {
                
                // Make the video completely opaque
                self.VideoPlayer.playerLayer.opacity = 1
                
                
                /* Hide the feedback buttons, ranking labels, details button
                   and score label */
                for button in self.buttons {
                    button.alpha = 0
                }
                self.rankingLabel.alpha = 0
                self.detailsButton.alpha = 0
                self.scoreLabel.alpha = 0
                
                
                // Shrink the video player and move it near the top of the screen
                let originalHeight = self.VideoPlayer.frame.height
                let fblNewHeight = (originalHeight/2.0 + 50 + 20) + (self.view.bounds.maxY-(originalHeight/2.0 + 50 + 20))/2.0 - (self.feedbackBlurbLabel.frame.height)/2.0
                self.VideoPlayer.playerLayer.frame = CGRect(x: self.VideoPlayer.frame.minX, y: 25 , width: self.VideoPlayer.frame.width, height: self.VideoPlayer.frame.height/2.0)
                
                
                /* Present the specific category the user is inspecting, along
                   with that category's score and in-depth feedback blurb */
                self.displayLabel.frame.origin = CGPoint(x: self.displayLabel.frame.minX, y: originalHeight/2.0 + 50 + self.categoryLabel.frame.height + 10)
                self.feedbackBlurbLabel.frame.origin = CGPoint(x: self.feedbackBlurbLabel.frame.minX, y: fblNewHeight)
                self.categoryLabel.frame.origin = CGPoint(x: self.categoryLabel.frame.minX, y: originalHeight/2.0 + 50)
                self.totalScoreLabel.frame.origin = CGPoint(x: self.totalScoreLabel.frame.minX, y: -(10+self.totalScoreLabel.frame.height))
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        
        /* Show the feedback blurb label, although at this time the
           label will be offscreen */
        feedbackBlurbLabel.alpha = 1
        
        
        // Hide the numerical ranking for now
        rankingLabel.isHidden = true
        
        
        // Hide the details button until the user selects a category
        detailsButton.isHidden = true
        
        
        // Make the score label resizeable
        scoreLabel.adjustsFontSizeToFitWidth = true
        scoreLabel.minimumScaleFactor = 0.5
                
            
        // Set the text for the label that gives the english ranking
        displayLabel.text = self.feedbackRankings[currentCategory][Int(serveVector![currentCategory])]
        
        
        /* Set the text for the label that displays the selected
           feedback category */
        categoryLabel.text = feedbackCategories[currentCategory]
        
        
        // Access the feedback blurb for the current feedback category
        let feedbackKey = self.feedbackCategories[currentCategory] + String(Int(serveVector![currentCategory]))
        feedbackBlurbLabel.text = feedbackBlurbs[feedbackKey]
        
        
        // Reference to all of the feedback buttons
        self.buttons = [feedbackButton1,
                        feedbackButton2,
                        feedbackButton3,
                        feedbackButton4,
                        feedbackButton5,
                        feedbackButton6,
                        feedbackButton7,
                        feedbackButton8]
        
        
        /* Reference to the Queue Player that will replay the serve
           video in a loop */
        let avPlayer = AVQueuePlayer(url: url!)
                
        
        // Set the Video Player object's video player
        self.VideoPlayer.playerLayer.player = avPlayer
        
        /* Make the video player barely visible, so it blends with
           the page background */
        self.VideoPlayer.playerLayer.opacity = 0.2
                

        /* Initialize a gesture recognizer that recognizes when the
           user long-presses on the serve video in the background.
           If the user does this, then the video will become
           opaque and everything else will be hidden. */
        let gestureRecognizerTap = UILongPressGestureRecognizer(target: self, action: #selector(longPressFired(_:)))

        
        /* After the user long-presses for 0.3 seconds, the serve
           video will come to the forefront */
        gestureRecognizerTap.minimumPressDuration = 0.3
        
        
        // Add the gesture recognizer to the video's overlay layer
        overlayLayer.addGestureRecognizer(gestureRecognizerTap)
        
        
        // Enable the user to long-press the overlay layer
        overlayLayer.isUserInteractionEnabled = true
        
        
        // Initialize the video to be played as an AVPlayerItem
        let playerItem = AVPlayerItem(url: url!)
        
        
        // Initialize the video to be played as an AVURL Asset
        let avAsset = AVURLAsset(url: url!, options: nil)

        
        
        // Get the starting and ending frame of the serve
        let startFrame = Double(self.startEnd![0])
        let endFrame = Double(self.startEnd![1])
        
        
        // Initialize an immutable video composition from the AVURLAsset
        let composition = AVVideoComposition(asset: avAsset, applyingCIFiltersWithHandler: { request in })
        
        
        // Get the start and end time of the serve in seconds
        let startTime = startFrame * CMTimeGetSeconds(composition.frameDuration)
        let endTime = endFrame * CMTimeGetSeconds(composition.frameDuration)

        
        // Loop the input video from the start time to the end time
        self.VideoPlayer.playerLooper = AVPlayerLooper(player: self.VideoPlayer.playerLayer.player! as! AVQueuePlayer, templateItem: playerItem,
                                                       timeRange: CMTimeRange(start: CMTimeMakeWithSeconds(startTime, preferredTimescale: 1000), end: CMTimeMakeWithSeconds(endTime, preferredTimescale: 1000)) )
       
        // Remove any audio and play the video
        self.VideoPlayer.playerLayer.player?.isMuted = true
        self.VideoPlayer.playerLayer.player?.play()
        
        
        /* Get the center of the video player so the circular feedback
           buttons revolve around the video player's center */
        let playerCenter = CGPoint(x: UIScreen.main.bounds.size.width*0.5,y: UIScreen.main.bounds.size.height*0.5)
        let centerX:CGFloat = playerCenter.x
        let centerY:CGFloat = playerCenter.y
        
        
        /* Set the positions of the score label, ranking label and
           details button */
        self.scoreLabel.center = CGPoint(centerX, centerY)
        self.rankingLabel.center = CGPoint(centerX, centerY)
        self.detailsButton.center = CGPoint(centerX, centerY + self.rankingLabel.frame.height)
        
        
        /* Set the distance of each feedback button from the video
           player's center */
        let scaleFactor:CGFloat = 0.35
        let scaledRadius:CGFloat = view.bounds.width * scaleFactor
                
        
        // Style and position the feedback buttons
        var theta:CGFloat = 0.0
        let angle:CGFloat = (2 * .pi)/CGFloat(buttons.count)
        for (index, button) in buttons.enumerated() {
            let buttonX = scaledRadius * cos(theta) + centerX
            let buttonY = scaledRadius * sin(theta) + centerY
            button.center = CGPoint(x: buttonX, y: buttonY)
            button.setImage(UIImage(named: self.iconNames[index]), for: UIControl.State.normal)
            button.contentMode = .center
            button.imageView?.contentMode = .scaleAspectFit
            button.layer.cornerRadius  = button.frame.height / 2
            
            button.layer.borderWidth = 3
            button.layer.borderColor = UIColor.clear.cgColor

            button.layer.shadowColor   = UIColor.black.cgColor
            button.layer.shadowOffset  = CGSize(width: 0.0, height: 6.0)
            button.layer.shadowRadius  = 8
            button.layer.shadowOpacity       = 0.5
            theta = CGFloat(index+1) * angle
        }
        
        
        /* Give each feedback button a color depending on the category's
           score */
        if self.serveVector != nil {
            let v = self.serveVector!
            for buttonIndex in 0...self.buttons.count - 1{
                var score = v[buttonIndex]
                score = max(score, 0.0)
                score = min(score, Double(self.feedbackRankings[buttonIndex].count - 1))
                self.buttons[buttonIndex].backgroundColor = self.feedbackColors[buttonIndex][Int(score)]
            }
        }
        
        
        // Create an array of percent scores (scores out of 100)
        let final_1 = String(Int((2.0 - Double(abs(2-serveVector![0])))/(2.0)*100)) + "/100"
        let final_2 = String(Int((2.0 - Double(abs(2-serveVector![1])))/(2.0)*100)) + "/100"
        let final_3 = String(Int(serveVector![2]*100)) + "/100"
        let final_4 = String(Int(serveVector![3]/4*100)) + "/100"
        let final_5 = String(Int(serveVector![4]*100)) + "/100"
        let final_6 = String(Int((3.0 - Double(abs(3-serveVector![5])))/(3.0)*100)) + "/100"
        let final_7 = String(Int((2.0 - Double(abs(2-serveVector![6])))/(2.0)*100)) + "/100"
        let final_8 = String(Int((2.0 - Double(abs(2-serveVector![7])))/(2.0)*100)) + "/100"
        
        self.percentScores = [
            final_1,
            final_2,
            final_3,
            final_4,
            final_5,
            final_6,
            final_7,
            final_8
        ]
        
        
        // Calculate the amalgamated score of the serve
        let totalScore = (Int((2.0 - Double(abs(2-serveVector![0])))/(2.0)*100) + Int((2.0 - Double(abs(2-serveVector![1])))/(2.0)*100) + Int(serveVector![2]*100) + Int(serveVector![3]/4*100) + Int(serveVector![4]*100) + Int((3.0 - Double(abs(3-serveVector![5])))/(3.0)*100) + Int((2.0 - Double(abs(2-serveVector![6])))/(2.0)*100) + Int((2.0 - Double(abs(2-serveVector![7])))/(2.0)*100))/8
        
        
        // Set the instructional text
        self.scoreLabel.text = "Click a button to inspect categorical scores"
        
        // Set the text of the total score label
        self.totalScoreLabel.text = "Serve Rating: " + String(totalScore) + "/100"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        /* Remove the pulsating effect from the selected feedback
           button */
        self.currentPulse?.removeFromSuperlayer()
    }
    
    func setPulse(_ newButtonIndex: Int, _ firstPulse: Bool) {
        
        /* Give a pulse to the selected feedback button*/
        
        
        // If a pulse already exists on a separate button, remove it
        if !firstPulse {
            self.currentPulse?.removeFromSuperlayer()
        }

        // Get the pulse's color
        let score = self.serveVector![newButtonIndex]
        let newButton = self.buttons[newButtonIndex] as FeedbackButton
        let backgroundColor = self.feedbackColors[newButtonIndex][Int(score)].cgColor
        
        
        //Generate a new pulse
        let newPulse = PulseAnimation(numberOfPulses: Float.infinity, radius: 100, position: CGPoint(x: newButton.frame.width/2, y: newButton.frame.height/2), backgroundColor: backgroundColor)
        
        
        // The pulse will pulsate every second
        newPulse.animationDuration = 1.0
        
        
        // Save the pulse in memory for later reference
        self.currentPulse = newPulse
        
        
        // Apply the pulse
        newButton.layer.addSublayer(self.currentPulse!)
        
        
        /* Bring the feedback button to the front so the pulse
           overlaps other buttons near the feedback button */
        view.bringSubviewToFront(newButton)

        
    }

    
    func updateScoreView(_ newCategoryIndex: Int) {
        
        /* When the user selects a new category, the UI will update here */
        
        // Set the new feedback category index
        self.currentCategory = newCategoryIndex
        
        
        // Set the new button's pulse
        setPulse(newCategoryIndex, false)
        
        
        // Remove the shadow of the selected button
        for button in self.buttons {
            button.layer.shadowColor   = UIColor.black.cgColor
        }
        self.buttons[newCategoryIndex].layer.shadowColor   = UIColor.clear.cgColor
        
        
        // Set the english ranking text of the new category
        self.displayLabel.text = self.feedbackRankings[newCategoryIndex][Int(serveVector![newCategoryIndex])]
        
        
        // Set the in-depth feedback blurb text
        let feedbackKey = self.feedbackCategories[newCategoryIndex] + String(Int(serveVector![newCategoryIndex]))
        feedbackBlurbLabel.text = feedbackBlurbs[feedbackKey]
        
        
        // Set the category label text
        categoryLabel.text = feedbackCategories[newCategoryIndex]
        
        
        // Set the numerical ranking label text
        self.rankingLabel.text = self.percentScores![newCategoryIndex]

        
        /* Hide the instructional label and show the numerical label
           and in-depth details button */
        self.scoreLabel.isHidden = true
        self.rankingLabel.isHidden = false
        self.detailsButton.isHidden = false
    }
    
    @objc func longPressFired(_ gesture: UITapGestureRecognizer) {
        
        /* When the user long-presses on the video, bring the video
           to the forefront*/
        
        
        // When the gesture starts, bring the video to the front
        if gesture.state == .began && self.gestureState == "normal" {
            
            /* Set the state to "zoom" so the view controller knows the
               video is being focused on */
            self.gestureState = "zoom"
            
            
            // Animate the video being brought to the front
            UIView.animate(withDuration:0.6) {
                
                // Make the video completely opaque
                self.VideoPlayer.playerLayer.opacity = 1
                
                
                // Hide everything else
                for button in self.buttons {
                    button.alpha = 0
                }
                self.scoreLabel.alpha = 0
                self.detailsButton.alpha = 0
                self.rankingLabel.alpha = 0
            }
        }
        
        // When the gesture ends, put the video back
        if gesture.state == .ended && self.gestureState == "zoom" {
            
            // Animate the video being put back
            UIView.animate(withDuration:0.25) {
                
                // Make the video barely visible
                self.VideoPlayer.playerLayer.opacity = 0.2
                
                
                //Show everything else
                for button in self.buttons {
                    button.alpha = 1
                }
                self.scoreLabel.alpha = 1
                self.detailsButton.alpha = 1
                self.rankingLabel.alpha = 1

            }
            
            /* Set the state to "normal" so the view controller knows the
               video is not being focused on anymore */
            self.gestureState = "normal"
            
        }
    }
    
    
    @IBAction func swipeUpFired(_ sender: Any) {
        
        /* When the user swipes up, give them the in-depth feedback of the
           current category selected */
        
        // Check that the feedback controller is in the normal display mode
        if self.gestureState == "normal" {
            
            /* Set the state to "feedbackInfor" so the view controller knows the
               in-depth feedback is being presented */
            self.gestureState = "feedbackInfo"
            
            
            
            /* Execute some UI transitions */
            
            UIView.animate(withDuration:0.6) {
                
                // Make the video completely opaque
                self.VideoPlayer.playerLayer.opacity = 1
                
                
                /* Hide the feedback buttons, ranking labels, details button
                   and score label */
                for button in self.buttons {
                    button.alpha = 0
                }
                self.rankingLabel.alpha = 0
                self.detailsButton.alpha = 0
                self.scoreLabel.alpha = 0
                
                
                // Shrink the video player and move it near the top of the screen
                let originalHeight = self.VideoPlayer.frame.height
                let fblNewHeight = (originalHeight/2.0 + 50 + 20) + (self.view.bounds.maxY-(originalHeight/2.0 + 50 + 20))/2.0 - (self.feedbackBlurbLabel.frame.height)/2.0
                self.VideoPlayer.playerLayer.frame = CGRect(x: self.VideoPlayer.frame.minX, y: 25 , width: self.VideoPlayer.frame.width, height: self.VideoPlayer.frame.height/2.0)
                
                
                /* Present the specific category the user is inspecting, along
                   with that category's score and in-depth feedback blurb */
                self.displayLabel.frame.origin = CGPoint(x: self.displayLabel.frame.minX, y: originalHeight/2.0 + 50 + self.categoryLabel.frame.height + 10)
                self.feedbackBlurbLabel.frame.origin = CGPoint(x: self.feedbackBlurbLabel.frame.minX, y: fblNewHeight)
                self.categoryLabel.frame.origin = CGPoint(x: self.categoryLabel.frame.minX, y: originalHeight/2.0 + 50)
                self.totalScoreLabel.frame.origin = CGPoint(x: self.totalScoreLabel.frame.minX, y: -(10+self.totalScoreLabel.frame.height))
            }
        }
    }
    
    @IBAction func swipeDownFired(_ sender: Any) {
        
        /* If the user swipes down while in-depth feedback is being
           presented, then go back to the normal view. If the user
           swipes down from the normal view, then dismiss the feedback
           controller. */
        
        // Check if in-depth feedback is currently being presented
        if self.gestureState == "feedbackInfo" {
            
            /* Execute some UI transitions */
            
            UIView.animate(withDuration:0.6) {
                
                // Resize and reposition the video player
                let newHeight1 = self.view.bounds.height-10-self.cancelServe.frame.height-25
                let newHeight2 = 37.5+self.totalScoreLabel.frame.height+25
                let newHeight = newHeight1-newHeight2
                self.VideoPlayer.playerLayer.frame = CGRect(x: self.VideoPlayer.frame.minX, y: 37.5+self.totalScoreLabel.frame.height+25, width: self.VideoPlayer.frame.width, height: newHeight)
                
                
                // Make the video barely visible
                self.VideoPlayer.playerLayer.opacity = 0.2
                
            
                // Show everything else
                for button in self.buttons {
                    button.alpha = 1
                }
                self.rankingLabel.alpha = 1
                self.detailsButton.alpha = 1
                self.scoreLabel.alpha = 1
                
                
                /* Hide the category label, english ranking label and
                   feedback blurb */
                self.categoryLabel.frame.origin = CGPoint(x: self.categoryLabel.frame.minX, y: self.view.bounds.height + 100)
                self.displayLabel.frame.origin = CGPoint(x: self.displayLabel.frame.minX,  y: self.view.bounds.height + 100)
                self.feedbackBlurbLabel.frame.origin = CGPoint(x: self.feedbackBlurbLabel.frame.minX, y: self.view.bounds.height + 100)
                
                
                // Bring back the total score label
                self.totalScoreLabel.frame.origin = CGPoint(x: self.totalScoreLabel.frame.minX, y: 37.5)
            }
            
            /* Set the state to "normal" so the view controller knows the
               in-depth feedback is not being inspected anymore */
            self.gestureState = "normal"
        }
        
        /* Check if the state is already "normal" and the user wants
           to dismiss the feedback */
        else if self.gestureState == "normal" {
            
            // dismiss the feedback controller
            dismiss(animated: true, completion: nil)
        }
    }
}
