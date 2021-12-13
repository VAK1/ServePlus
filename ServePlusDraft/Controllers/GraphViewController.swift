//
//  GraphViewController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/4/21.
//
//  View controller responsible for letting users analyze their
//  serving progress. Lets users analyze their progress in separate
//  feedback categories through several linear graphs, as well as their
//  practice-by-practice improvements through several spider-web graphs.

import UIKit
import Charts

class DataSetValueFormatter: ValueFormatter {
    
    
    // Make sure no labels are included for the spider web charts
    func stringForValue(_ value: Double,
                        entry: ChartDataEntry,
                        dataSetIndex: Int,
                        viewPortHandler: ViewPortHandler?) -> String {
        ""
    }
}

// 2
class XAxisFormatter: AxisValueFormatter {
    
    
    // Labels for each axis of the spider web graph
    let iconNames: [String] = [
                               "Back Arch",
                               "Feet Spacing",
                               "Back Leg",
                               "Jump \nHeight",
                               "Left Arm",
                               "Bending \nLegs",
                               "Shoulder \nTurn",
                               "Ball Toss",
                               ]
    
    
    /* Return the proper axis label for each axis of the
       spider web graph */
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        iconNames[Int(value) % iconNames.count]
    }
}

class blankFormat: AxisValueFormatter {

    /* Blank formatter class for any axes */
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        ""
    }
}

class ZeroFormat: AxisValueFormatter {
    
    /* Y-axis formatting class for back arch */
    
    let labels = [
        "", "", "No arch", "", "Perfect", "", "Too much arch", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+4) % labels.count]
    }
}
class OneFormat: AxisValueFormatter {
    
    /* Y-axis formatting class for feet spacing */
    
    let labels = [
        "", "", "Too close", "", "Perfect", "", "Too far apart", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+4) % labels.count]
    }
}
class TwoFormat: AxisValueFormatter {
    
    /* Y-axis formatting class for back leg kick back */
    
    let labels = [
        "", "", "No Kick Back", "", "Perfect", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+2) % labels.count]
    }
}
class ThreeFormat: AxisValueFormatter {
    
    /* Y-axis formatting class for jump height */
    
    let labels = [
        "", "", "No jump", "", "Medium jump", "", "Perfect", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((4*value)+2) % labels.count]
    }
}
class FourFormat: AxisValueFormatter {
    
    /* Y-axis formatting class for left arm straightness */
    
    let labels = [
        "", "", "Crooked Arm", "", "Straight Arm", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+2) % labels.count]
    }
}
class FiveFormat: AxisValueFormatter {
    
    /* Y-axis formatting class for leg bending */
    
    let labels = [
        "", "", "No bending", "", "Great bend", "Perfect", "Too much bend", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((3*value)+5) % labels.count]
    }
}
class SixFormat: AxisValueFormatter {
    
    /* Y-axis formatting class for shoulder rotation timing */
    
    let labels = [
        "", "", "Too early", "", "Perfect", "", "Too late", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+4) % labels.count]
    }
}
class SevenFormat: AxisValueFormatter {
    
    /* Y-acis formatting for toss height */
    
    let labels = [
        "", "", "Too low", "", "Perfect", "Too high", "", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+4) % labels.count]
    }
}


class GraphViewController: UIViewController, ChartViewDelegate {
    
    /* context helps this controller link to the app's data model to retrieve
       and update the user's practices. */
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    
    // Array to keep track of all of the user's practices
    var practices:[Practice]?
    
    
    /* Get references to the toggle buttons that scroll through
       practices or feedback categories */
    @IBOutlet weak var leftButton1: UIButton?
    @IBOutlet weak var rightButton1: UIButton?
    @IBOutlet weak var leftButton2: UIButton?
    @IBOutlet weak var rightButton2: UIButton?

    
    /* References to actions that will happen when the toggle
       buttons are tapped */
    @IBAction func tappedLeftButton1(sender: UIButton) {
        setLineChart(self.currentCategory - 1)
    }
    @IBAction func tappedRightButton1(sender: UIButton) {
        setLineChart(self.currentCategory + 1)
    }
    @IBAction func tappedLeftButton2(sender: UIButton) {
        setLabels(currentPractice - 1)
    }
    @IBAction func tappedRightButton2(sender: UIButton) {
        setLabels(currentPractice + 1)
    }
    
    
    // Reference to the category label for the linear graph
    @IBOutlet weak var category: UILabel?
    
    
    // Array of all the possible feedback categories
    let categories: [String] = [
                               "Back Arch",
                               "Feet Spacing",
                               "Back Leg",
                               "Jump Height",
                               "Left Arm",
                               "Bending Legs",
                               "Shoulder Turn",
                               "Ball Toss",
                               ]
    
    
    // Reference to the date label for the spider web graph
    @IBOutlet weak var date: UILabel?
    
    
    // Reference to the serve count label for the spider web graph
    @IBOutlet weak var serveCount: UILabel?
    
    
    /* Reference to the current practice index for the spider web
       graph */
    var currentPractice = 0
    
    
    /* Reference to the current category index for the linear
       graph */
    var currentCategory = 7
    
    
    // References to the spider web and linear graphs
    @IBOutlet weak var RadarChart: RadarChartView!
    @IBOutlet weak var LineChart: LineChartView!
    
    
    /* Reference to the view and label that will show if no
       practices have been recorded */
    @IBOutlet weak var emptyMessageView: UIView!
    @IBOutlet weak var emptyMessageLabel: UILabel!

    
    // Arrays to keep track of categorical data
    var BackArchData: [Double] = []
    var FeetSpacingData: [Double] = []
    var BackLegData: [Double] = []
    var JumpHeightData: [Double] = []
    var LeftArmData: [Double] = []
    var BendingLegsData: [Double] = []
    var ShoulderTurnData: [Double] = []
    var BallTossData: [Double] = []

    
    // Array to collect all of the categorical data
    var lineDatas: [[Double]] = []

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Set title in the tab bar controller
        title = "Analyze"

        
        // Get the practices from the database
        fetchPractices()
        
        
        // Check if the user hasn't recorded any practices
        if self.practices!.count == 0 {
            
            // Hide the analysis graphs
            self.LineChart.isHidden = true
            self.RadarChart.isHidden = true
            
            
            /* Show the message if the user hasn't uploaded
               any practices */
            self.emptyMessageView.isHidden = false
            
            
            // Set the message
            setEmptyMessage(emptyMessageView, label: emptyMessageLabel)
        }
        
        // Check if the user has recorded practices
        else {
            
            // Show and configure the analysis graphs
            self.LineChart.isHidden = false
            self.RadarChart.isHidden = false
            setLineChart(self.currentCategory)
            setLabels(self.currentPractice)
            
            // Hide the "no practices" message
            self.emptyMessageView.isHidden = true
        }
        
    }
    
    func setEmptyMessage(_ view: UIView, label: UILabel) {

        /* Set the empty message if the user hasn't uploaded any
           practices */
        
        
        // Set the background color to a nice blue color
        view.backgroundColor = UIColor.systemBlue
        
        
        // Configure the message label
        label.text = "Record or upload some serves to access practice-by-practice analytics."
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20)
        label.sizeToFit()
    }
    
    func setLineChart(_ num: Int) {
        
        /* Configure the line chart, which will display the user's
           progress by category. This functin will take a new category
           number and redefine the line chart for the new category. */
        
        // Go to the final category if the category index is -1
        if num == -1 {
            self.category?.text = self.categories[self.categories.count-1]
            self.currentCategory = self.categories.count-1
        }
        
        // Go to the indicated category and reset the current category
        else {
            self.category?.text = self.categories[num % self.categories.count]
            self.currentCategory = num % self.categories.count
        }
        
        // Set the background of the line chart to white
        self.LineChart.backgroundColor = UIColor.white
        
        
        // Remove the rightmost and make the left one invisible
        self.LineChart.rightAxis.enabled = false
        self.LineChart.leftAxis.axisLineColor = .white

        
        // Remove the legend of the line chart
        self.LineChart.legend.enabled = false
            
        
        // Remove any x-axis labels for the line chart
        let xAxis = self.LineChart.xAxis
        xAxis.valueFormatter = blankFormat()
        
        
        /* Set up the y-axis with the proper labels depending on
           the category */
        let yAxis = self.LineChart.leftAxis
        yAxis.labelTextColor = UIColor.black
        yAxis.labelFont = .boldSystemFont(ofSize: 12)
        yAxis.labelPosition = .outsideChart
        
        if (self.currentCategory == 0) {
            yAxis.axisMinimum = -1
            yAxis.axisMaximum = 1
            yAxis.setLabelCount(5, force: true)
            yAxis.valueFormatter = ZeroFormat()
        }
        if (self.currentCategory == 1) {
            yAxis.axisMinimum = -1
            yAxis.axisMaximum = 1
            yAxis.setLabelCount(5, force: true)
            yAxis.valueFormatter = OneFormat()
        }
        if (self.currentCategory == 2) {
            yAxis.axisMinimum = 0
            yAxis.axisMaximum = 1
            yAxis.setLabelCount(3, force: true)
            yAxis.valueFormatter = TwoFormat()
        }
        if (self.currentCategory == 3) {
            yAxis.axisMinimum = 0
            yAxis.axisMaximum = 1
            yAxis.setLabelCount(5, force: true)
            yAxis.valueFormatter = ThreeFormat()
        }
        if (self.currentCategory == 4) {
            yAxis.axisMinimum = 0
            yAxis.axisMaximum = 1
            yAxis.setLabelCount(3, force: true)
            yAxis.valueFormatter = FourFormat()
        }
        if (self.currentCategory == 5) {
            yAxis.axisMinimum = -1
            yAxis.axisMaximum = (1/3)
            yAxis.setLabelCount(5, force: true)
            yAxis.valueFormatter = FiveFormat()
        }
        if (self.currentCategory == 6) {
            yAxis.axisMinimum = -1
            yAxis.axisMaximum = 1
            yAxis.setLabelCount(5, force: true)
            yAxis.valueFormatter = SixFormat()
        }
        if (self.currentCategory == 7) {
            yAxis.axisMinimum = -1
            yAxis.axisMaximum = 0.5
            yAxis.setLabelCount(4, force: true)
            yAxis.valueFormatter = SevenFormat()
        }
         
        /* Set up the actual y_values based on the scores of the
           current category over time */
        var y_values: [ChartDataEntry] = []
        for (index, y_val) in self.lineDatas[self.currentCategory].enumerated() {
            y_values.append(ChartDataEntry(x: Double(index), y: Double(y_val)))
        }
        
        /* If there is only one entry, duplicate it so a line can be
           drawn */
        if y_values.count == 1 {
            y_values.append(ChartDataEntry(x: y_values[0].x + 1, y: y_values[0].y))
        }
        
        
        // Define a dataset from the raw score values
        let set = LineChartDataSet(entries: y_values)
        set.mode = .linear
        
        
        // Style the graph
        set.lineWidth = 3
        set.setColor(UIColor.systemTeal)
        set.drawCirclesEnabled = false
        set.drawHorizontalHighlightIndicatorEnabled = false
        
        
        // Get the data ready to pass to the line chart
        let data = LineChartData(dataSet: set)
        data.setDrawValues(false)

        
        // Pass the data to the line chart
        LineChart.data = data
    }
    
    func setLabels(_ currentPractice: Int) {
        
        /* Sets the date labels and serve count labels of the
           spider web graph. This function will take a new
           practice number and reset the spider web graph
           for that practice. */
        
        // Check that the current practice is a valid one
        if !(currentPractice < 0 || currentPractice > self.practices!.count - 1) {
            
            // Reset the current practice object
            self.currentPractice = currentPractice
            
            
            // Get the date of the current practice
            let date = self.practices![currentPractice].date
            
            
            // Format the date nicely for the date label
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, y | hh:mm"
            self.date!.text = dateFormatter.string(from: date!)
            
            
            // Format and set the serve count label
            if (self.practices![currentPractice].vectors!.count) == 1 {
                self.serveCount!.text = "1 serve"
            }
            else {
                self.serveCount!.text = String(self.practices![currentPractice].vectors!.count) + " serves"
            }
            
            
            /* Hide specific toggle buttons if on the first and/or
               last practice */
            if currentPractice == 0 {
                self.leftButton2?.alpha = 0
            }
            else {
                self.leftButton2?.alpha = 1
            }
            if currentPractice == self.practices!.count - 1 {
                self.rightButton2?.alpha = 0
            }
            else {
                self.rightButton2?.alpha = 1
            }
            
            
            // Plot the web graph
            plotWebGraph(currentPractice)
        }
    }
    
    
    func plotWebGraph(_ num: Int) {
        
        /* Plots the web graph for a certain practice */
        
        
        // Get all the scores for the serves in that practice
        var serveVectors = self.practices![num].vectors!
        
        
        // Get the number of serves in that practice
        let count = Double(serveVectors.count)
        
        
        // Set the background of the spider web graph to white
        RadarChart.backgroundColor = .white
        
        
        // Style the spider web graph
        RadarChart.webLineWidth = 1.5
        RadarChart.innerWebLineWidth = 1.5
        RadarChart.webColor = .lightGray
        RadarChart.innerWebColor = .lightGray
        RadarChart.animate(yAxisDuration: 1.0, easingOption: .easeOutBounce)

        
        /* Format the categorical labels on the outside of
           the spider web graph */
        let xAxis = RadarChart.xAxis
        xAxis.labelFont = .systemFont(ofSize: 12, weight: .bold)
        xAxis.labelTextColor = .black
        xAxis.xOffset = 10
        xAxis.yOffset = 10
        xAxis.valueFormatter = XAxisFormatter()

        
        // Format a blank y-axis
        let yAxis = RadarChart.yAxis
        yAxis.valueFormatter = blankFormat()

        
        // Make sure the user can't rotate the spider web graph
        RadarChart.rotationEnabled = false
        
        
        // Remove the spider web graph's legend
        RadarChart.legend.enabled = false

        
        // Check if there is only one serve in the practice
        if count == 1 {
            
            /* Create a spider web data point from the 8
               scores in the score vector */
            let singleServeDataSet = RadarChartDataSet(
                entries: [
                    RadarChartDataEntry(value: 5.0*(2.0 - Double(abs(2-serveVectors[0][0])))/(2.0)),
                    RadarChartDataEntry(value: 5.0*(2.0 - Double(abs(2-serveVectors[0][1])))/(2.0)),
                    RadarChartDataEntry(value:5.0*serveVectors[0][2]),
                    RadarChartDataEntry(value: 5.0*serveVectors[0][3]/4),
                    RadarChartDataEntry(value: 5.0*serveVectors[0][4]),
                    RadarChartDataEntry(value: 5.0*(3.0 - Double(abs(3-serveVectors[0][5])))/(3.0)),
                    RadarChartDataEntry(value: 5.0*(2.0 - Double(abs(2-serveVectors[0][6])))/(2.0)),
                    RadarChartDataEntry(value: 5.0*(2.0 - Double(abs(2-serveVectors[0][7])))/(2.0))
                ]
            )
            
            // Style the data point
            singleServeDataSet.lineWidth = 2
            let singleServeColor = UIColor.systemTeal
            let singleServeFillColor = UIColor(red: 0.537, green: 0.812, blue: 0.941, alpha: 1)
            singleServeDataSet.colors = [singleServeColor]
            singleServeDataSet.fillColor = singleServeFillColor
            singleServeDataSet.drawFilledEnabled = true
            singleServeDataSet.valueFormatter = DataSetValueFormatter()
            singleServeDataSet.setDrawHighlightIndicators(false)


            /* Get the data ready to give to the spider-web
               graph */
            let data = RadarChartData(dataSets: [singleServeDataSet])
            
            
            // Give the spider web graph the data
            RadarChart.data = data
            RadarChart.notifyDataSetChanged()
        }
        
        // Check if there are multiple serves in the practice
        else {
            
            // Find the best serve score and average serve score
            var bestSum = 0.0
            var bestVector = [Double](repeating: 0.0, count: 8)
            var averageVector = [Double](repeating: 0.0, count: 8)
            for vector in serveVectors {
                let final_1 = (2.0 - Double(abs(2-vector[0])))/(2.0)
                let final_2 = (2.0 - Double(abs(2-vector[1])))/(2.0)
                let final_3 = vector[2]
                let final_4 = vector[3]/4
                let final_5 = vector[4]
                let final_6 = (3.0 - Double(abs(3-vector[5])))/(3.0)
                let final_7 = (2.0 - Double(abs(2-vector[6])))/(2.0)
                let final_8 = (2.0 - Double(abs(2-vector[7])))/(2.0)
                let weightedSum = (final_1+final_2+final_3+final_4+final_5+final_6+final_7+final_8)
                if weightedSum > bestSum {
                    bestSum = weightedSum
                    bestVector = [final_1, final_2, final_3, final_4, final_5, final_6, final_7, final_8]
                }
                averageVector[0] += final_1/count
                averageVector[1] += final_2/count
                averageVector[2] += final_3/count
                averageVector[3] += final_4/count
                averageVector[4] += final_5/count
                averageVector[5] += final_6/count
                averageVector[6] += final_7/count
                averageVector[7] += final_8/count
            }
            
            
            // Create a data point from the best serve scores
            let BestServeDataset = RadarChartDataSet(
                entries: [
                    RadarChartDataEntry(value: 5.0*bestVector[0]),
                    RadarChartDataEntry(value: 5.0*bestVector[1]),
                    RadarChartDataEntry(value: 5.0*bestVector[2]),
                    RadarChartDataEntry(value: 5.0*bestVector[3]),
                    RadarChartDataEntry(value: 5.0*bestVector[4]),
                    RadarChartDataEntry(value: 5.0*bestVector[5]),
                    RadarChartDataEntry(value: 5.0*bestVector[6]),
                    RadarChartDataEntry(value: 5.0*bestVector[7])
                ], label: "Best Serve"
            )
            
            
            // Create a data point from the average serve scores
            let AverageServeDataset = RadarChartDataSet(
                entries: [
                    RadarChartDataEntry(value: 5.0*averageVector[0]),
                    RadarChartDataEntry(value: 5.0*averageVector[1]),
                    RadarChartDataEntry(value: 5.0*averageVector[2]),
                    RadarChartDataEntry(value: 5.0*averageVector[3]),
                    RadarChartDataEntry(value: 5.0*averageVector[4]),
                    RadarChartDataEntry(value: 5.0*averageVector[5]),
                    RadarChartDataEntry(value: 5.0*averageVector[6]),
                    RadarChartDataEntry(value: 5.0*averageVector[7])
                ], label: "Average Serve"
            )
            
            
            // Style the average serve data point
            AverageServeDataset.setDrawHighlightIndicators(false)
            AverageServeDataset.lineWidth = 2
            let averageServeColor = UIColor.systemTeal
            let averageServeFillColor = UIColor(red: 0.537, green: 0.812, blue: 0.941, alpha: 1)
            AverageServeDataset.colors = [averageServeColor]
            AverageServeDataset.fillColor = averageServeFillColor
            AverageServeDataset.drawFilledEnabled = true
            AverageServeDataset.valueFormatter = DataSetValueFormatter()
           
            
            // Style the best serve datapoint
            BestServeDataset.setDrawHighlightIndicators(false)
            BestServeDataset.lineWidth = 2
            let bestServeColor = UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 1)
            let bestServeFillColor = UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 0.6)
            BestServeDataset.colors = [bestServeColor]
            BestServeDataset.fillColor = bestServeFillColor
            BestServeDataset.drawFilledEnabled = true
            BestServeDataset.valueFormatter = DataSetValueFormatter()
            
            
            // Get the data ready to pass to the spider web graph
            let data = RadarChartData(dataSets: [AverageServeDataset, BestServeDataset])
            
            
            // Give the data to the spider web graph
            RadarChart.data = data
            RadarChart.notifyDataSetChanged()
        }
    }
    
    func fetchPractices() {
        
        /* Fetches all of the practices, preprocesses the results and stores
           them in arrays the graphs can reference and present nicely. */
        
        do {
            
            // Get the practices from the database
            self.practices = try self.context.fetch(Practice.fetchRequest())
            
            
            // Initialize arrays to hold the scores of the practices
            var BackArchData: [Double] = []
            var FeetSpacingData: [Double] = []
            var BackLegData: [Double] = []
            var JumpHeightData: [Double] = []
            var LeftArmData: [Double] = []
            var BendingLegsData: [Double] = []
            var ShoulderTurnData: [Double] = []
            var BallTossData: [Double] = []
            
            
            // Loop through each practice
            for practice in self.practices! {
                
                // Count the number of serves
                let count = Double(practice.vectors!.count)
                
                
                // Initialize Doubles to hold the categorical scores
                var ba = 0.0
                var fs = 0.0
                var bl = 0.0
                var jh = 0.0
                var la = 0.0
                var beL = 0.0
                var st = 0.0
                var bt = 0.0
                
                
                /* Loop through each score vector and calculate the
                   average score by category over all the serves */
                for vector in practice.vectors! {
                    ba += (vector[0] - 2)/(2*count)
                    fs += (vector[1] - 2)/(2*count)
                    bl += (vector[2])/count
                    jh += (vector[3]/4)/count
                    la += (vector[4])/count
                    beL += (vector[5] - 3)/(3*count)
                    st += (vector[6] - 2)/(2*count)
                    bt += (vector[7] - 2)/(2*count)
                }
                
                // Append the averaged scores to their respective arrays
                BackArchData.append(ba)
                FeetSpacingData.append(fs)
                BackLegData.append(bl)
                JumpHeightData.append(jh)
                LeftArmData.append(la)
                BendingLegsData.append(beL)
                ShoulderTurnData.append(st)
                BallTossData.append(bt)
            }
            
            
            // Store the final data arrays in memory
            self.BackArchData = BackArchData
            self.FeetSpacingData = FeetSpacingData
            self.BackLegData = BackLegData
            self.JumpHeightData = JumpHeightData
            self.LeftArmData = LeftArmData
            self.BendingLegsData = BendingLegsData
            self.ShoulderTurnData = ShoulderTurnData
            self.BallTossData = BallTossData
        
            
            // Collect all of the data arrays into one
            self.lineDatas = [
                    BackArchData,
                    FeetSpacingData,
                    BackLegData,
                    JumpHeightData,
                    LeftArmData,
                    BendingLegsData,
                    ShoulderTurnData,
                    BallTossData
                ]
            
            
            /* Reverse the practices so the data in the spider web
               graph is displayed in chronological order */
            self.practices = self.practices!.reversed()
            
        } catch {
            print("Couldn't properly fetch practices.")
        }
    }
}


