//
//  LabView.swift
//  AdversaryLabSwift
//
//  Created by Mafalda on 6/28/22.
//  Copyright © 2022 Operator Foundation. All rights reserved.
//

import SwiftUI

struct LabView: View
{
    @StateObject var labViewData = LabViewData()
    @State var selectedView = 1
    var labData: LabData = LabData()
    
    var body: some View
    {
        TabView(selection: $selectedView)
        {
            DataView(labData: labData)
            .padding()
            .tabItem
            {
                Text("Data")
            }
            .tag(1)
            
            ChartsView()
            .padding()
            .tabItem
            {
                Text("Charts")
            }
            .tag(2)
        }
        .environmentObject(labViewData)
    }
}

struct LabView_Previews: PreviewProvider {
    static var previews: some View {
        LabView()
    }
}
