//
//  TisaHeader.swift
//  TisaDynamicIsland
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct TisaHeader: View {
    @EnvironmentObject var vm: TisaViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = TisaViewCoordinator.shared
    @StateObject var tvm = ShelfStateViewModel.shared
    @ObservedObject var homeEditor = HomeEditor.shared
    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geo in
                HStack {
                    if ((!tvm.isEmpty || coordinator.alwaysShowTabs) && Defaults[.tisaShelf]) || tabs.count > 1 {
                        TabSelectionView(availableWidth: geo.size.width)
                    } else if vm.notchState == .open {
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && Defaults[.showOpenNotchHUD] {
                        OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        if coordinator.currentView == .home && Defaults[.tisaHome] {
                            GlassCircleButton(icon: homeEditor.isEditing ? "checkmark" : "pencil", help: homeEditor.isEditing ? "Done editing Home" : "Edit Home") {
                                withAnimation(.smooth) { homeEditor.setEditing(!homeEditor.isEditing) }
                            }
                        }
                        if Defaults[.showMirror] {
                            GlassCircleButton(icon: vm.isCameraExpanded ? "web.camera.fill" : "web.camera", help: "Mirror") {
                                vm.toggleCameraPreview()
                            }
                        }
                        if Defaults[.settingsIconInNotch] {
                            GlassCircleButton(icon: "gearshape.fill", help: "Settings") {
                                DispatchQueue.main.async {
                                    SettingsWindowController.shared.showWindow()
                                }
                            }
                        }
                        if Defaults[.showBatteryIndicator] {
                            TisaBatteryView(
                                batteryWidth: 30,
                                isCharging: batteryModel.isCharging,
                                isInLowPowerMode: batteryModel.isInLowPowerMode,
                                isPluggedIn: batteryModel.isPluggedIn,
                                levelBattery: batteryModel.levelBattery,
                                maxCapacity: batteryModel.maxCapacity,
                                timeToFullCharge: batteryModel.timeToFullCharge,
                                isForNotification: false
                            )
                        }
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    func isHUDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }
}

#Preview {
    TisaHeader().environmentObject(TisaViewModel())
}
