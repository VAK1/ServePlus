//
//  DataViewController.swift
//  PageViewPractice
//
//  Created by Vikram Khandelwal on 5/18/21.
//

import UIKit
import AVKit
import AVFoundation

class DataViewController: UIViewController {
    
    
    @IBOutlet var bigView: UIView!
    
    @IBOutlet weak var totalScoreLabel: UILabel!
    @IBOutlet weak var displayLabel: UILabel!
    @IBOutlet weak var feedbackBlurbLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var VideoPlayer: PlayerView!
    @IBOutlet weak var overlayLayer: UIView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var rankingLabel: UILabel!
    
    @IBOutlet weak var feedbackButton1: FeedbackButton!
    @IBAction func feedback1tapped(_ sender: ReturnButton) {
        updateScoreView(0)
    }
    
    @IBOutlet weak var detailsButton: UIButton!
    @IBAction func detailsButtonTapped(_ sender: Any) {
        if self.gestureState == "normal" {
            self.gestureState = "feedbackInfo"
            let originalHeight = self.VideoPlayer.frame.height
            let fblNewHeight = (originalHeight/2.0 + 50 + 20) + (self.view.bounds.maxY-(originalHeight/2.0 + 50 + 20))/2.0 - (self.feedbackBlurbLabel.frame.height)/2.0
            UIView.animate(withDuration:0.6) {
                self.VideoPlayer.playerLayer.opacity = 1
                for button in self.buttons {
                    button.alpha = 0
                }
                self.rankingLabel.alpha = 0
                self.detailsButton.alpha = 0
                self.scoreLabel.alpha = 0
                self.VideoPlayer.playerLayer.frame = CGRect(x: self.VideoPlayer.frame.minX, y: 25 , width: self.VideoPlayer.frame.width, height: self.VideoPlayer.frame.height/2.0)
                self.displayLabel.frame.origin = CGPoint(x: self.displayLabel.frame.minX, y: originalHeight/2.0 + 50 + self.categoryLabel.frame.height + 10)
                self.feedbackBlurbLabel.frame.origin = CGPoint(x: self.feedbackBlurbLabel.frame.minX, y: fblNewHeight)
                self.categoryLabel.frame.origin = CGPoint(x: self.categoryLabel.frame.minX, y: originalHeight/2.0 + 50)
                self.totalScoreLabel.frame.origin = CGPoint(x: self.totalScoreLabel.frame.minX, y: -(10+self.totalScoreLabel.frame.height))
            }
        } 
    }
    
    @IBOutlet weak var feedbackButton2: FeedbackButton!
    @IBAction func feedback2tapped(_ sender: ReturnButton) {
        updateScoreView(1)
    }
    @IBOutlet weak var feedbackButton3: FeedbackButton!
    @IBAction func feedback3tapped(_ sender: ReturnButton) {
        updateScoreView(2)
    }
    @IBOutlet weak var feedbackButton4: FeedbackButton!
    @IBAction func feedback4tapped(_ sender: ReturnButton) {
        updateScoreView(3)
    }
    @IBOutlet weak var feedbackButton5: FeedbackButton!
    @IBAction func feedback5tapped(_ sender: ReturnButton) {
        updateScoreView(4)
    }
    @IBOutlet weak var feedbackButton6: FeedbackButton!
    @IBAction func feedback6tapped(_ sender: ReturnButton) {
        updateScoreView(5)
    }
    @IBOutlet weak var feedbackButton7: FeedbackButton!
    @IBAction func feedback7tapped(_ sender: ReturnButton) {
        updateScoreView(6)
    }
    @IBOutlet weak var feedbackButton8: FeedbackButton!
    @IBAction func feedback8tapped(_ sender: ReturnButton) {
        updateScoreView(7)
    }
    @IBOutlet weak var cancelServe: UIButton!
    @IBAction func cancelServeTapped(_ sender: ReturnButton) {
        if thisIsTheLastPage!(self) {
            dismiss(animated: true, completion: nil)
        }
    }
    
    
    
    
    var index: Int?
    var url: URL?
    var serveVector: [Double]?
    var startEnd: [Int]?
    var thisIsTheLastPage: ((UIViewController) -> Bool)?
    var currentCategory = 6
    var percentScores: [String]?
    
    
    var gestureState = "normal"
    
    
    var buttons: [FeedbackButton] = []
    
    var feedbackCategories = ["Back arched", "Feet spacing", "Back leg follow through", "Jump height", "Left arm straight", "Legs bent", "Timing of shoulder rotation", "Toss height"]
    
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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        feedbackBlurbLabel.alpha = 1
        rankingLabel.isHidden = true
        detailsButton.isHidden = true
        
        scoreLabel.adjustsFontSizeToFitWidth = true
        scoreLabel.minimumScaleFactor = 0.5
                
        //serveVector = [Double](repeating: 1.0, count: 8)
        
        displayLabel.text = self.feedbackRankings[currentCategory][Int(serveVector![currentCategory])]
        
        categoryLabel.text = feedbackCategories[currentCategory]
        
        let feedbackKey = self.feedbackCategories[currentCategory] + String(Int(serveVector![currentCategory]))
                
        feedbackBlurbLabel.text = feedbackBlurbs[feedbackKey]
        
        self.buttons = [feedbackButton1,
                        feedbackButton2,
                        feedbackButton3,
                        feedbackButton4,
                        feedbackButton5,
                        feedbackButton6,
                        feedbackButton7,
                        feedbackButton8]
        
        
        let avPlayer = AVQueuePlayer(url: url!)
                
        
        self.VideoPlayer.playerLayer.player = avPlayer
        
        self.VideoPlayer.playerLayer.opacity = 0.2
                

        let gestureRecognizerTap = UILongPressGestureRecognizer(target: self, action: #selector(longPressFired(_:)))

        gestureRecognizerTap.minimumPressDuration = 0.3
        
        overlayLayer.addGestureRecognizer(gestureRecognizerTap)
        overlayLayer.isUserInteractionEnabled = true
        
        let playerItem = AVPlayerItem(url: url!)
        //let duration = Float64(CMTimeGetSeconds(AVAsset(url: url!).duration))
        let startFrame = Double(self.startEnd![0])
        let endFrame = Double(self.startEnd![1])
        let avAsset = AVURLAsset(url: url!, options: nil)
        
        let composition = AVVideoComposition(asset: avAsset, applyingCIFiltersWithHandler: { request in })
        let startTime = startFrame * CMTimeGetSeconds(composition.frameDuration)
        let endTime = endFrame * CMTimeGetSeconds(composition.frameDuration)

        self.VideoPlayer.playerLooper = AVPlayerLooper(player: self.VideoPlayer.playerLayer.player! as! AVQueuePlayer, templateItem: playerItem,
                                                       timeRange: CMTimeRange(start: CMTimeMakeWithSeconds(startTime, preferredTimescale: 1000), end: CMTimeMakeWithSeconds(endTime, preferredTimescale: 1000)) )
        self.VideoPlayer.playerLayer.player?.isMuted = true
        self.VideoPlayer.playerLayer.player?.play()

        // Do any additional setup after loading the view.
        
        
        let playerCenter = CGPoint(x: UIScreen.main.bounds.size.width*0.5,y: UIScreen.main.bounds.size.height*0.5)
        let centerX:CGFloat = playerCenter.x
        let centerY:CGFloat = playerCenter.y
        
        self.scoreLabel.center = CGPoint(centerX, centerY)
        self.rankingLabel.center = CGPoint(centerX, centerY)
        self.detailsButton.center = CGPoint(centerX, centerY + self.rankingLabel.frame.height)
        
        let scaleFactor:CGFloat = 0.35
        let scaledRadius:CGFloat = view.bounds.width * scaleFactor
                
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
        
        
        if self.serveVector != nil {
            let v = self.serveVector!
            for buttonIndex in 0...self.buttons.count - 1{
                var score = v[buttonIndex]
                score = max(score, 0.0)
                score = min(score, Double(self.feedbackRankings[buttonIndex].count - 1))
                self.buttons[buttonIndex].backgroundColor = self.feedbackColors[buttonIndex][Int(score)]
            }
        }
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
        let totalScore = (Int((2.0 - Double(abs(2-serveVector![0])))/(2.0)*100) + Int((2.0 - Double(abs(2-serveVector![1])))/(2.0)*100) + Int(serveVector![2]*100) + Int(serveVector![3]/4*100) + Int(serveVector![4]*100) + Int((3.0 - Double(abs(3-serveVector![5])))/(3.0)*100) + Int((2.0 - Double(abs(2-serveVector![6])))/(2.0)*100) + Int((2.0 - Double(abs(2-serveVector![7])))/(2.0)*100))/8
        self.scoreLabel.text = "Click a button to inspect categorical scores"
        self.totalScoreLabel.text = "Serve Rating: " + String(totalScore) + "/100"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        let seconds = 0.5
//        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
//            self.setPulse(self.currentCategory, true)
//        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.currentPulse?.removeFromSuperlayer()
    }
    
    func setPulse(_ newButtonIndex: Int, _ firstPulse: Bool) {
        
        if !firstPulse {
            self.currentPulse?.removeFromSuperlayer()
        }
        print(self.currentPulse)
        
        let score = self.serveVector![newButtonIndex]
        let newButton = self.buttons[newButtonIndex] as FeedbackButton
        let backgroundColor = self.feedbackColors[newButtonIndex][Int(score)].cgColor
        let newPulse = PulseAnimation(numberOfPulses: Float.infinity, radius: 100, position: CGPoint(x: newButton.frame.width/2, y: newButton.frame.height/2), backgroundColor: backgroundColor)
        newPulse.animationDuration = 1.0
        
        self.currentPulse = newPulse
        newButton.layer.addSublayer(self.currentPulse!)
        view.bringSubviewToFront(newButton)

        
    }

    
    func updateScoreView(_ newCategoryIndex: Int) {
        self.currentCategory = newCategoryIndex
        setPulse(newCategoryIndex, false)
        for button in self.buttons {
            button.layer.shadowColor   = UIColor.black.cgColor
        }
        self.buttons[newCategoryIndex].layer.shadowColor   = UIColor.clear.cgColor
        self.displayLabel.text = self.feedbackRankings[newCategoryIndex][Int(serveVector![newCategoryIndex])]
        let feedbackKey = self.feedbackCategories[newCategoryIndex] + String(Int(serveVector![newCategoryIndex]))
                
        feedbackBlurbLabel.text = feedbackBlurbs[feedbackKey]
        categoryLabel.text = feedbackCategories[newCategoryIndex]
        self.scoreLabel.isHidden = true
        self.rankingLabel.isHidden = false
        self.detailsButton.isHidden = false
        self.rankingLabel.text = self.percentScores![newCategoryIndex]
    }
    
    @objc func longPressFired(_ gesture: UITapGestureRecognizer) {
        if gesture.state == .began && self.gestureState == "normal" {
            self.gestureState = "zoom"
            UIView.animate(withDuration:0.6) {
                self.VideoPlayer.playerLayer.opacity = 1
                for button in self.buttons {
                    button.alpha = 0
                }
                self.scoreLabel.alpha = 0
                self.detailsButton.alpha = 0
                self.rankingLabel.alpha = 0
            }
        }
        if gesture.state == .ended && self.gestureState == "zoom" {
            UIView.animate(withDuration:0.25) {
                self.VideoPlayer.playerLayer.opacity = 0.2
                for button in self.buttons {
                    button.alpha = 1
                }
                self.scoreLabel.alpha = 1
                self.detailsButton.alpha = 1
                self.rankingLabel.alpha = 1

            }
            self.gestureState = "normal"
            
        }
    }
    
    
    @IBAction func swipeUpFired(_ sender: Any) {
        if self.gestureState == "normal" {
            self.gestureState = "feedbackInfo"
            let originalHeight = self.VideoPlayer.frame.height
            let fblNewHeight = (originalHeight/2.0 + 50 + 20) + (self.view.bounds.maxY-(originalHeight/2.0 + 50 + 20))/2.0 - (self.feedbackBlurbLabel.frame.height)/2.0
            UIView.animate(withDuration:0.6) {
                self.VideoPlayer.playerLayer.opacity = 1
                for button in self.buttons {
                    button.alpha = 0
                }
                self.rankingLabel.alpha = 0
                self.detailsButton.alpha = 0
                self.scoreLabel.alpha = 0
                self.VideoPlayer.playerLayer.frame = CGRect(x: self.VideoPlayer.frame.minX, y: 25 , width: self.VideoPlayer.frame.width, height: self.VideoPlayer.frame.height/2.0)
                self.displayLabel.frame.origin = CGPoint(x: self.displayLabel.frame.minX, y: originalHeight/2.0 + 50 + self.categoryLabel.frame.height + 10)
                self.feedbackBlurbLabel.frame.origin = CGPoint(x: self.feedbackBlurbLabel.frame.minX, y: fblNewHeight)
                self.categoryLabel.frame.origin = CGPoint(x: self.categoryLabel.frame.minX, y: originalHeight/2.0 + 50)
                self.totalScoreLabel.frame.origin = CGPoint(x: self.totalScoreLabel.frame.minX, y: -(10+self.totalScoreLabel.frame.height))
            }
        }
    }
    
    @IBAction func swipeDownFired(_ sender: Any) {
        if self.gestureState == "feedbackInfo" {
            UIView.animate(withDuration:0.6) {
                self.VideoPlayer.playerLayer.opacity = 0.2
                for button in self.buttons {
                    button.alpha = 1
                }
                self.rankingLabel.alpha = 1
                self.detailsButton.alpha = 1
                self.scoreLabel.alpha = 1
                self.categoryLabel.frame.origin = CGPoint(x: self.categoryLabel.frame.minX, y: self.view.bounds.height + 100)
                self.displayLabel.frame.origin = CGPoint(x: self.displayLabel.frame.minX,  y: self.view.bounds.height + 100)
                let newHeight1 = self.view.bounds.height-10-self.cancelServe.frame.height-25
                let newHeight2 = 37.5+self.totalScoreLabel.frame.height+25
                let newHeight = newHeight1-newHeight2
                self.VideoPlayer.playerLayer.frame = CGRect(x: self.VideoPlayer.frame.minX, y: 37.5+self.totalScoreLabel.frame.height+25, width: self.VideoPlayer.frame.width, height: newHeight)
                self.feedbackBlurbLabel.frame.origin = CGPoint(x: self.feedbackBlurbLabel.frame.minX, y: self.view.bounds.height + 100)
                self.totalScoreLabel.frame.origin = CGPoint(x: self.totalScoreLabel.frame.minX, y: 37.5)
            }
            self.gestureState = "normal"
        }
        else if self.gestureState == "normal" {
            //self.performSegue(withIdentifier:"segueBack", sender: self)
            dismiss(animated: true, completion: nil)

        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
