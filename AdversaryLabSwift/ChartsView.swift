//
//  ChartsView.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 6/30/22.
//  Copyright © 2022 Operator Foundation. All rights reserved.
//

import SwiftUI

import SwiftUICharts

struct ChartsView: View
{
    @EnvironmentObject var labViewData: LabViewData
    
    let defaultPointStyle = PointStyle(pointSize: 1.0,
                                       borderColour: .clear,
                                       fillColour: .black,
                                       lineWidth: 1.0,
                                       pointType: .filled,
                                       pointShape: .circle)
    
    let defaultStrokeStyle = Stroke(lineWidth: 1.0,
                                    lineCap: .round,
                                    lineJoin: .round,
                                    miterLimit: .leastNonzeroMagnitude)
    
    var body: some View
    {
        VStack
        {
            VStack
            {
                let lengthData = lengthChartData()
                createMultilineChart(data: lengthData)
            }
            .navigationTitle("Packet Lengths")
            
            VStack
            {
                let entropyData = entropyChartData()
                createMultilineChart(data: entropyData)
            }
            .navigationTitle("Entropy")
                
            VStack
            {
                let timeData = timeChartData()
                createMultilineChart(data: timeData)
            }
            .navigationTitle("Packet Timing")
        }
        .background(.white)
        
    }
    
    func createMultilineChart(data: MultiLineChartData) -> some View
    {
        MultiLineChart(chartData: data)
            .pointMarkers(chartData: data)
            .touchOverlay(chartData: data, specifier: "%.0f")
            .averageLine(chartData: data,
                         strokeStyle: StrokeStyle(lineWidth: 1.0, dash: [2, 4]))
            .xAxisGrid(chartData: data)
            .yAxisGrid(chartData: data)
            .xAxisLabels(chartData: data)
            .yAxisLabels(chartData: data)
            .infoBox(chartData: data)
            .headerBox(chartData: data)
            .legends(chartData: data, columns: [GridItem(.flexible()), GridItem(.flexible())])
            .id(data.id)
            .frame(minWidth: 150, maxWidth: 800, minHeight: 150, idealHeight: 250, maxHeight: 800, alignment: .center)
    }


    func lengthChartData() -> MultiLineChartData
    {
        let aOutLengths = labViewData.packetLengths.outgoingA.expanded
        let aInLengths = labViewData.packetLengths.incomingA.expanded
        let bOutLengths = labViewData.packetLengths.outgoingB.expanded
        let bInLengths = labViewData.packetLengths.incomingB.expanded

        let allowedInLengthsEntry = chartDataEntry(fromArray: aInLengths)
        let allowedOutLengthsEntry = chartDataEntry(fromArray: aOutLengths)
        let blockedInLengthsEntry = chartDataEntry(fromArray: bInLengths)
        let blockedOutLengthsEntry = chartDataEntry(fromArray: bOutLengths)

        let allowedInLine = LineDataSet(dataPoints: allowedInLengthsEntry, legendTitle: "\(labViewData.transportA) Incoming Packet Lengths", pointStyle: defaultPointStyle, style: LineStyle(lineColour: ColourStyle(colour: .teal), lineType: .curvedLine, strokeStyle: defaultStrokeStyle))

        let allowedOutLine = LineDataSet(dataPoints: allowedOutLengthsEntry, legendTitle: "\(labViewData.transportA) Outgoing Packet Lengths", pointStyle: defaultPointStyle, style: LineStyle(lineColour: ColourStyle(colour: .black), lineType: .curvedLine, strokeStyle: defaultStrokeStyle))

        let blockedInLine = LineDataSet(dataPoints: blockedInLengthsEntry, legendTitle: "\(labViewData.transportB) Incoming Packet Lengths", pointStyle: defaultPointStyle, style: LineStyle(lineColour: ColourStyle(colour: .pink), lineType: .curvedLine, strokeStyle: defaultStrokeStyle))

        let blockedOutLine = LineDataSet(dataPoints: blockedOutLengthsEntry, legendTitle: "\(labViewData.transportB) Outgoing Packet Lengths", pointStyle: defaultPointStyle, style: LineStyle(lineColour: ColourStyle(colour: .purple), lineType: .curvedLine, strokeStyle: defaultStrokeStyle))
        
        let metadata   = ChartMetadata(title: "Packet Length", subtitle: "")
        let chartStyle = defaultChartStyle()
        
        let multilineData = MultiLineDataSet(dataSets: [allowedInLine, allowedOutLine, blockedInLine, blockedOutLine])
        return MultiLineChartData(dataSets       : multilineData,
                             metadata       : metadata,
                             chartStyle     : chartStyle)
    }

    func entropyChartData() -> MultiLineChartData
    {
        print("ChartView Entropy \(labViewData.packetEntropies.incomingA.count)")
        var aInEntropy = labViewData.packetEntropies.incomingA.sorted()
        for index in 0 ..< aInEntropy.count
        {
            aInEntropy[index] = (aInEntropy[index]*1000).rounded()/1000
        }

        var aOutEntropy = labViewData.packetEntropies.outgoingA.sorted()
        for index in 0 ..< aOutEntropy.count
        {
            aOutEntropy[index] = (aOutEntropy[index]*1000).rounded()/1000
        }

        var bInEntropy = labViewData.packetEntropies.incomingB.sorted()
        for index in 0 ..< bInEntropy.count
        {
            bInEntropy[index] = (bInEntropy[index]*1000).rounded()/1000
        }

        var bOutEntropy = labViewData.packetEntropies.outgoingB.sorted()
        for index in 0 ..< bOutEntropy.count
        {
            bOutEntropy[index] = (bOutEntropy[index]*1000).rounded()/1000
        }

        let aInEntropyEntry = chartDataEntry(fromArray: aInEntropy)
        let aOutEntropyEntry = chartDataEntry(fromArray: aOutEntropy)
        let bInEntropyEntry = chartDataEntry(fromArray: bInEntropy)
        let bOutEntropyEntry = chartDataEntry(fromArray: bOutEntropy)

        let aInLine = LineDataSet(dataPoints: aInEntropyEntry, legendTitle: "\(labViewData.transportA) Incoming Entropy", pointStyle: defaultPointStyle, style: LineStyle(lineColour: ColourStyle(colour: .teal), lineType: .curvedLine, strokeStyle: defaultStrokeStyle))

        let aOutLine = LineDataSet(dataPoints: aOutEntropyEntry, legendTitle: "\(labViewData.transportA) Outgoing Entropy", pointStyle: defaultPointStyle, style: LineStyle(lineColour: ColourStyle(colour: .black), lineType: .curvedLine, strokeStyle: defaultStrokeStyle))

        let bInLine = LineDataSet(dataPoints: bInEntropyEntry, legendTitle: "\(labViewData.transportB) Incoming Entropy", pointStyle: defaultPointStyle, style: LineStyle(lineColour: ColourStyle(colour: .pink), lineType: .curvedLine, strokeStyle: defaultStrokeStyle))

        let bOutLine = LineDataSet(dataPoints: bOutEntropyEntry, legendTitle: "\(labViewData.transportB) Outgoing Entropy", pointStyle: defaultPointStyle, style: LineStyle(lineColour: ColourStyle(colour: .purple), lineType: .curvedLine, strokeStyle: defaultStrokeStyle))


        let metadata   = ChartMetadata(title: "Entropy", subtitle: "")
        let chartStyle = defaultChartStyle()
        
        let multilineData = MultiLineDataSet(dataSets: [aInLine, aOutLine, bInLine, bOutLine])
        return MultiLineChartData(dataSets       : multilineData,
                             metadata       : metadata,
                             chartStyle     : chartStyle)
    }

    func timeChartData() -> MultiLineChartData
    {
        var aTimeDifferences = labViewData.packetTimings.transportA.sorted()
        for index in 0 ..< aTimeDifferences.count
        {
            // Convert microseconds to milliseconds
            aTimeDifferences[index] = aTimeDifferences[index]/1000
        }

        var bTimeDifferences = labViewData.packetTimings.transportB.sorted()
        for index in 0 ..< bTimeDifferences.count
        {
            // Convert microseconds to milliseconds
            bTimeDifferences[index] = bTimeDifferences[index]/1000
        }

        let aLineChartEntry = chartDataEntry(fromArray: aTimeDifferences)
        let bLineChartEntry = chartDataEntry(fromArray: bTimeDifferences)

        let aData = LineDataSet(dataPoints: aLineChartEntry,
                                legendTitle: "\(labViewData.transportA)",
                                pointStyle: defaultPointStyle,
                                style: LineStyle(lineColour: ColourStyle(colour: .pink),
                                                 lineType: .curvedLine,
                                                 strokeStyle: defaultStrokeStyle))
        
        let bData = LineDataSet(dataPoints: bLineChartEntry,
                                legendTitle: "\(labViewData.transportB)",
                                pointStyle: defaultPointStyle,
                                style: LineStyle(lineColour: ColourStyle(colour: .purple),
                                                 lineType: .curvedLine,
                                                strokeStyle: defaultStrokeStyle))
        
        let metadata   = ChartMetadata(title: "Time Interval", subtitle: "")
        let chartStyle = defaultChartStyle()
        
        let multilineData = MultiLineDataSet(dataSets: [aData, bData])
        return MultiLineChartData(dataSets       : multilineData,
                             metadata       : metadata,
                             chartStyle     : chartStyle)
    }

    func chartDataEntry(fromArray dataArray:[Double]) -> [LineChartDataPoint]
    {
        var lineChartData = [LineChartDataPoint]()
        for i in 0..<dataArray.count
        {
            let value = LineChartDataPoint(value: Double(dataArray[i]), xAxisLabel: String(i), description: "")
            lineChartData.append(value)
        }

        return lineChartData
    }

    func chartDataEntry(fromArray dataArray:[Int]) -> [LineChartDataPoint]
    {
        var lineChartData = [LineChartDataPoint]()
        for i in 0..<dataArray.count
        {
            let value = LineChartDataPoint(value: Double(dataArray[i]), xAxisLabel: String(i), description: "")
            lineChartData.append(value)
        }

        return lineChartData
    }
    
    func defaultGridStyle() -> GridStyle
    {
        return GridStyle(numberOfLines: 5,
                                   lineColour   : Color(.lightGray).opacity(0.5),
                                   lineWidth    : 0.5,
                                   dash         : [4],
                                   dashPhase    : 0)
    }
    
    func defaultChartStyle() -> LineChartStyle
    {
        let gridStyle = defaultGridStyle()
        
        return LineChartStyle(infoBoxPlacement    : .infoBox(isStatic: false),
                                        infoBoxBorderColour : Color.primary,
                                        infoBoxBorderStyle  : StrokeStyle(lineWidth: 0.5, lineCap: .butt, lineJoin: .bevel, miterLimit: 1),
                                        
                                        markerType          : .none,
                                        
                                        xAxisGridStyle      : gridStyle,
                                        xAxisLabelPosition  : .bottom,
                                        xAxisLabelColour    : Color.primary,
                                        xAxisLabelsFrom     : .dataPoint(rotation: .degrees(0)),
                                        
                                        yAxisGridStyle      : gridStyle,
                                        yAxisLabelPosition  : .leading,
                                        yAxisLabelColour    : Color.primary,
                                        yAxisNumberOfLabels : 5,
                                        
                                        baseline            : .zero,
                                        topLine             : .maximumValue,
                                        
                                        globalAnimation     : .easeOut(duration: 1))
    }

}


struct ChartsView_Previews: PreviewProvider {
    static var previews: some View {
        ChartsView()
    }
}
