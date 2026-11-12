//
//  MusicVisualizer.swift
//  TisaDynamicIsland
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//
import AppKit
import Cocoa
import Defaults
import SwiftUI

class AudioSpectrum: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var isPlaying: Bool = true
    private var animationTimer: Timer?
    /// True while the bars follow real system audio instead of random heights.
    private var usesRealAudio = false
    private var holdsAnalyzer = false
    /// The setting's value when animation last started, to notice changes cheaply.
    private var realAudioSetting = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        let barWidth: CGFloat = 2
        let barCount = 4
        let spacing: CGFloat = barWidth
        let totalWidth = CGFloat(barCount) * (barWidth + spacing)
        let totalHeight: CGFloat = 14
        frame.size = CGSize(width: totalWidth, height: totalHeight)

        for i in 0 ..< barCount {
            let xPosition = CGFloat(i) * (barWidth + spacing)
            let barLayer = CAShapeLayer()
            barLayer.frame = CGRect(x: xPosition, y: 0, width: barWidth, height: totalHeight)
            barLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            barLayer.position = CGPoint(x: xPosition + barWidth / 2, y: totalHeight / 2)
            barLayer.fillColor = NSColor.white.cgColor
            barLayer.backgroundColor = NSColor.white.cgColor
            barLayer.allowsGroupOpacity = false
            barLayer.masksToBounds = true
            let path = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                                    xRadius: barWidth / 2,
                                    yRadius: barWidth / 2)
            barLayer.path = path.cgPath
            barLayers.append(barLayer)
            barScales.append(0.35)
            layer?.addSublayer(barLayer)
        }
    }
    
    private func startAnimating() {
        guard animationTimer == nil else { return }
        realAudioSetting = Defaults[.realAudioVisualizer]
        usesRealAudio = realAudioSetting && SystemAudioAnalyzer.hasPermission
        if usesRealAudio && !holdsAnalyzer {
            SystemAudioAnalyzer.shared.acquire()
            holdsAnalyzer = true
        }
        let interval: TimeInterval = usesRealAudio ? 1.0 / 30.0 : 0.3
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateBars()
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        if holdsAnalyzer {
            SystemAudioAnalyzer.shared.release()
            holdsAnalyzer = false
        }
        resetBars()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopAnimating()
        } else if isPlaying {
            startAnimating()
        }
    }

    private func updateBars() {
        // Follow the setting if it was changed while playing.
        if Defaults[.realAudioVisualizer] != realAudioSetting {
            stopAnimating()
            startAnimating()
            return
        }

        let realLevels = usesRealAudio ? SystemAudioAnalyzer.shared.currentLevels() : nil
        let isReal = realLevels?.count == barLayers.count

        for (i, barLayer) in barLayers.enumerated() {
            let currentScale = barScales[i]
            let targetScale: CGFloat
            if isReal, let levels = realLevels {
                targetScale = 0.35 + 0.65 * CGFloat(levels[i])
            } else {
                targetScale = CGFloat.random(in: 0.35 ... 1.0)
            }
            barScales[i] = targetScale
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = currentScale
            animation.toValue = targetScale
            animation.duration = isReal ? 1.0 / 30.0 : 0.3
            animation.autoreverses = !isReal
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            if #available(macOS 13.0, *) {
                animation.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 24, preferred: 24)
            }
            barLayer.add(animation, forKey: "scaleY")
        }
    }
    
    private func resetBars() {
        for (i, barLayer) in barLayers.enumerated() {
            barLayer.removeAllAnimations()
            barLayer.transform = CATransform3DMakeScale(1, 0.35, 1)
            barScales[i] = 0.35
        }
    }
    
    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        if isPlaying {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
}

struct AudioSpectrumView: NSViewRepresentable {
    @Binding var isPlaying: Bool
    
    func makeNSView(context: Context) -> AudioSpectrum {
        let spectrum = AudioSpectrum()
        spectrum.setPlaying(isPlaying)
        return spectrum
    }
    
    func updateNSView(_ nsView: AudioSpectrum, context: Context) {
        nsView.setPlaying(isPlaying)
    }
}

#Preview {
    AudioSpectrumView(isPlaying: .constant(true))
        .frame(width: 16, height: 20)
        .padding()
}
