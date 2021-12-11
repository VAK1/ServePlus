//
//  GraphViewController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/4/21.
//

import UIKit
import Charts

class DataSetValueFormatter: ValueFormatter {
    
    func stringForValue(_ value: Double,
                        entry: ChartDataEntry,
                        dataSetIndex: Int,
                        viewPortHandler: ViewPortHandler?) -> String {
        ""
    }
}

// 2
class XAxisFormatter: AxisValueFormatter {
    
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
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        iconNames[Int(value) % iconNames.count]
    }
}

class blankFormat: AxisValueFormatter {

    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        ""
    }
}

// 3
class YAxisFormatter: AxisValueFormatter {
    let ratingNames = [
        "Worst", "", "OK", "", "Best", "", "", ""
    ]
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        //ratingNames[Int(value) % ratingNames.count]
        ""
    }
}

class ZeroFormat: AxisValueFormatter {
    let labels = [
        "", "", "No arch", "", "Perfect", "", "Too much arch", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+4) % labels.count]
    }
}
class OneFormat: AxisValueFormatter {
    let labels = [
        "", "", "Too close", "", "Perfect", "", "Too far apart", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+4) % labels.count]
    }
}
class TwoFormat: AxisValueFormatter {
    let labels = [
        "", "", "No Kick Back", "", "Perfect", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+2) % labels.count]
    }
}
class ThreeFormat: AxisValueFormatter {
    let labels = [
        "", "", "No jump", "", "Medium jump", "", "Perfect", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((4*value)+2) % labels.count]
    }
}
class FourFormat: AxisValueFormatter {
    let labels = [
        "", "", "Crooked Arm", "", "Straight Arm", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+2) % labels.count]
    }
}
class FiveFormat: AxisValueFormatter {
    let labels = [
        "", "", "No bending", "", "Great bend", "Perfect", "Too much bend", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((3*value)+5) % labels.count]
    }
}
class SixFormat: AxisValueFormatter {
    let labels = [
        "", "", "Too early", "", "Perfect", "", "Too late", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+4) % labels.count]
    }
}
class SevenFormat: AxisValueFormatter {
    let labels = [
        "", "", "Too low", "", "Perfect", "Too high", "", "", ""
    ]
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        labels[Int((2*value)+4) % labels.count]
    }
}


class GraphViewController: UIViewController, ChartViewDelegate {

    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var practices:[Practice]?
    @IBOutlet weak var leftButton1: UIButton?
    @IBAction func tappedLeftButton1(sender: UIButton) {
        setLineChart(self.currentCategory - 1)
    }
    @IBOutlet weak var rightButton1: UIButton?
    @IBAction func tappedRightButton1(sender: UIButton) {
        setLineChart(self.currentCategory + 1)
    }
    @IBOutlet weak var leftButton2: UIButton?
    @IBAction func tappedLeftButton2(sender: UIButton) {
        setLabels(currentPractice - 1)
    }
    @IBOutlet weak var rightButton2: UIButton?
    @IBAction func tappedRightButton2(sender: UIButton) {
        setLabels(currentPractice + 1)
    }
    @IBOutlet weak var category: UILabel?
    
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
    
    @IBOutlet weak var date: UILabel?
    @IBOutlet weak var serveCount: UILabel?
    var currentPractice = 0
    var currentCategory = 7
    
    @IBOutlet weak var RadarChart: RadarChartView!
    @IBOutlet weak var LineChart: LineChartView!
    @IBOutlet weak var emptyMessageView: UIView!
    @IBOutlet weak var emptyMessageLabel: UILabel!

    
    var BackArchData: [Double] = []
    
    var FeetSpacingData: [Double] = []

    var BackLegData: [Double] = []

    var JumpHeightData: [Double] = []

    var LeftArmData: [Double] = []

    var BendingLegsData: [Double] = []

    var ShoulderTurnData: [Double] = []

    var BallTossData: [Double] = []
    
    var lineDatas: [[Double]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Analyze"
        // Do any additional setup after loading the view.
        
        fetchPractices()
        if self.practices!.count == 0 {
            self.LineChart.isHidden = true
            self.RadarChart.isHidden = true
            self.emptyMessageView.isHidden = false
            setEmptyMessage(emptyMessageView, label: emptyMessageLabel)
        }
        else {
            self.LineChart.isHidden = false
            self.RadarChart.isHidden = false
            self.emptyMessageView.isHidden = true
            setLineChart(self.currentCategory)
            setLabels(self.currentPractice)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Do any additional setup after loading the view.
        
        fetchPractices()
        if self.practices!.count == 0 {
            self.LineChart.isHidden = true
            self.RadarChart.isHidden = true
            self.emptyMessageView.isHidden = false
            setEmptyMessage(emptyMessageView, label: emptyMessageLabel)
        }
        else {
            self.LineChart.isHidden = false
            self.RadarChart.isHidden = false
            self.emptyMessageView.isHidden = true
            setLineChart(self.currentCategory)
            setLabels(self.currentPractice)
        }
        
    }
    
    func setEmptyMessage(_ view: UIView, label: UILabel) {

        view.backgroundColor = UIColor.systemBlue
        label.text = "Record or upload some serves to access practice-by-practice analytics."
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20)
        
        label.sizeToFit()
    }
    
    func setLineChart(_ num: Int) {
        if num == -1 {
            self.category?.text = self.categories[self.categories.count-1]
            self.currentCategory = self.categories.count-1
        }
        else {
            self.category?.text = self.categories[num % self.categories.count]
            self.currentCategory = num % self.categories.count
        }
        
        self.LineChart.backgroundColor = UIColor.white
        
        self.LineChart.rightAxis.enabled = false
        self.LineChart.leftAxis.axisLineColor = .white

        self.LineChart.legend.enabled = false
            
        let xAxis = self.LineChart.xAxis
        xAxis.valueFormatter = blankFormat()
        
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
                
        var y_values: [ChartDataEntry] = []
        for (index, y_val) in self.lineDatas[self.currentCategory].enumerated() {
            y_values.append(ChartDataEntry(x: Double(index), y: Double(y_val)))
        }
        if y_values.count == 1 {
            y_values.append(ChartDataEntry(x: y_values[0].x + 1, y: y_values[0].y))
        }
        
        let set1 = LineChartDataSet(entries: y_values)
        set1.mode = .linear
        set1.lineWidth = 3
        set1.setColor(UIColor.systemTeal)
        
        set1.drawCirclesEnabled = false
        set1.drawHorizontalHighlightIndicatorEnabled = false
        
        let data = LineChartData(dataSet: set1)
        data.setDrawValues(false)
        
        LineChart.data = data
    }
    
    func setLabels(_ currentPractice: Int) {
        if !(currentPractice < 0 || currentPractice > self.practices!.count - 1) {
            self.currentPractice = currentPractice
            let date = self.practices![currentPractice].date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, y | hh:mm"
            self.date!.text = dateFormatter.string(from: date!)
            
            if (self.practices![currentPractice].vectors!.count) == 1 {
                self.serveCount!.text = "1 serve"
            }
            else {
                self.serveCount!.text = String(self.practices![currentPractice].vectors!.count) + " serves"
            }
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
            plotWebGraph(currentPractice)
        }
    }
    
    
    func plotWebGraph(_ num: Int) {
        var serveVectors = self.practices![num].vectors!
        let count = Double(serveVectors.count)
        RadarChart.backgroundColor = .white
        
        RadarChart.webLineWidth = 1.5
        RadarChart.innerWebLineWidth = 1.5
        RadarChart.webColor = .lightGray
        RadarChart.innerWebColor = .lightGray
        RadarChart.animate(yAxisDuration: 1.0, easingOption: .easeOutBounce)

        // 3
        let xAxis = RadarChart.xAxis
        xAxis.labelFont = .systemFont(ofSize: 12, weight: .bold)
        xAxis.labelTextColor = .black
        xAxis.xOffset = 10
        xAxis.yOffset = 10
        xAxis.valueFormatter = XAxisFormatter()

        // 4
        let yAxis = RadarChart.yAxis
        yAxis.labelFont = .systemFont(ofSize: 11, weight: .light)
        yAxis.labelTextColor = .white
        yAxis.drawTopYLabelEntryEnabled = false
        yAxis.axisMinimum = 0
        yAxis.valueFormatter = YAxisFormatter()

        // 5
        RadarChart.rotationEnabled = false
        RadarChart.legend.enabled = false

        if count == 1 {
            let redDataSet = RadarChartDataSet(
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
            
            redDataSet.lineWidth = 2

            // 2
            let redColor = UIColor.systemTeal
            let redFillColor = UIColor(red: 0.537, green: 0.812, blue: 0.941, alpha: 1)
            redDataSet.colors = [redColor]
            redDataSet.fillColor = redFillColor
            redDataSet.drawFilledEnabled = true
            
            redDataSet.valueFormatter = DataSetValueFormatter()
            redDataSet.setDrawHighlightIndicators(false)

            // 3
            
            let data = RadarChartData(dataSets: [redDataSet])
            
            RadarChart.data = data
            RadarChart.notifyDataSetChanged()
        }
        else {
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
            
            let greenDataSet = RadarChartDataSet(
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
            
            greenDataSet.setDrawHighlightIndicators(false)
            
            let redDataSet = RadarChartDataSet(
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
            redDataSet.setDrawHighlightIndicators(false)
            redDataSet.lineWidth = 2

            // 2
            let redColor = UIColor.systemTeal
            let redFillColor = UIColor(red: 0.537, green: 0.812, blue: 0.941, alpha: 1)
            redDataSet.colors = [redColor]
            redDataSet.fillColor = redFillColor
            redDataSet.drawFilledEnabled = true
            
            redDataSet.valueFormatter = DataSetValueFormatter()
            greenDataSet.lineWidth = 2

            // 2
            let greenColor = UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 1)
            let greenFillColor = UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 0.6)
            greenDataSet.colors = [greenColor]
            greenDataSet.fillColor = greenFillColor
            greenDataSet.drawFilledEnabled = true
            
            greenDataSet.valueFormatter = DataSetValueFormatter()
            
            let data = RadarChartData(dataSets: [redDataSet])
            
            RadarChart.data = data
            RadarChart.notifyDataSetChanged()
        }
        
        
    }
    
    func fetchPractices() {
        do {
            self.practices = try self.context.fetch(Practice.fetchRequest())
            var BackArchData: [Double] = []
            
            var FeetSpacingData: [Double] = []

            var BackLegData: [Double] = []

            var JumpHeightData: [Double] = []

            var LeftArmData: [Double] = []

            var BendingLegsData: [Double] = []

            var ShoulderTurnData: [Double] = []

            var BallTossData: [Double] = []
            
            for practice in self.practices! {
                let count = Double(practice.vectors!.count)
                var ba = 0.0
                
                var fs = 0.0

                var bl = 0.0

                var jh = 0.0

                var la = 0.0

                var beL = 0.0

                var st = 0.0

                var bt = 0.0
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
                BackArchData.append(ba)
                FeetSpacingData.append(fs)
                BackLegData.append(bl)
                JumpHeightData.append(jh)
                LeftArmData.append(la)
                BendingLegsData.append(beL)
                ShoulderTurnData.append(st)
                BallTossData.append(bt)
            }
            
            self.BackArchData = BackArchData
            
            self.FeetSpacingData = FeetSpacingData

            self.BackLegData = BackLegData

            self.JumpHeightData = JumpHeightData

            self.LeftArmData = LeftArmData

            self.BendingLegsData = BendingLegsData

            self.ShoulderTurnData = ShoulderTurnData

            self.BallTossData = BallTossData
            
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
            self.practices = self.practices!.reversed()
        } catch {
            
        }
    }
}


