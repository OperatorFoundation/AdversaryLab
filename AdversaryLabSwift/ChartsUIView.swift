//
//  ChartsUIView.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 10/2/20.
//  Copyright © 2020 Operator Foundation. All rights reserved.
//

import SwiftUI

import Axis

struct ChartsUIView: View {
    let pointSet = PointSet(id: "123",
                            label: "A Label",
                            color: .red,
                            points: [Point(x: 0, y: 0), Point(x: 5, y: 5), Point(x: 10, y: 10)])
    
    var body: some View {
        
        VStack {
            LineChart(pointsets: [pointSet], xrange: Range<Int>(0...10), yrange: Range<Int>(0...10))
                .padding()
            Text("Axis Chart View")
        }
    }
}

struct ChartsUIView_Previews: PreviewProvider {
    static var previews: some View {
        ChartsUIView()
    }
}
