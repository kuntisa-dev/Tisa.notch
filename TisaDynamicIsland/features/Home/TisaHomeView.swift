//
//  TisaHomeView.swift
//  TisaDynamicIsland
//
//  The redesigned Home tab: a two-row grid of widget tiles (HomeWidgets.swift and
//  HomeCompactWidgets.swift). A tile is Small (1×1), Wide (2×1), Tall (1×2), Medium (2×2),
//  Large (3×2) or Extra large (4×2); tiles flow into the first free spot, so small ones pair
//  up in a column and as many fit as there is room for. A tile can also hold a stack of
//  widgets you swipe through sideways (HomeStack.swift), so a full Home still takes more.
//
//  Editing works like an iPhone home screen. Hold a tile and the tiles jiggle; keep
//  holding and the tile is already lifted, so the same press drags it onto another's
//  place. Press − to remove one (it asks first), drag the corner to step through the
//  widget's sizes, tap a tile to change what it shows, and + opens a widget gallery with a
//  live preview. Undo steps back through this session's changes; Done saves.
//  Right-click a tile for the same actions without entering edit mode.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
final class HomeEditor: ObservableObject {
    static let shared = HomeEditor()

    @Published private(set) var isEditing = false

    private init() {}

    /// Editing holds the notch open, so it doesn't close while you drag or pick.
    func setEditing(_ editing: Bool) {
        guard editing != isEditing else { return }
        if editing { TabBarEditor.shared.setEditing(false) }
        isEditing = editing
        if editing {
            HomeHaptics.tap()
            SharingStateManager.shared.beginInteraction()
        } else {
            SharingStateManager.shared.endInteraction()
        }
    }
}

enum HomeHaptics {
    /// A light tick on the trackpad, like the iPhone's when a widget lifts or settles.
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    /// A firmer bump for "that won't fit".
    static func refuse() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

enum HomeMetrics {
    static let gap: CGFloat = 8
    static let cornerRadius: CGFloat = 16
}

private enum GalleryMode: Equatable {
    case add
    case change(UUID)
}

/// The layout before a change, for Undo.
private struct HomeSnapshot: Equatable {
    var boxes: [HomeBox]
    var tiles: [HomeQuickTile]
}

struct TisaHomeView: View {
    @ObservedObject private var editor = HomeEditor.shared
    @ObservedObject private var coordinator = TisaViewCoordinator.shared
    @ObservedObject private var stacks = HomeStackState.shared
    @Default(.homeBoxes) private var boxes
    @Default(.homeQuickTiles) private var tiles
    @Default(.largeNotch) private var largeNotch

    @State private var gridSize: CGSize = .zero
    /// The tile that's lifted and following the pointer.
    @State private var draggingID: UUID?
    /// The tile lifted by the same press that started edit mode.
    @State private var heldID: UUID?
    /// The dragged tile's top-left corner, following the pointer.
    @State private var dragOrigin: CGPoint = .zero
    /// Where in the tile the pointer grabbed it.
    @State private var grabOffset: CGSize?
    @State private var lastMove = Date.distantPast
    @State private var lastDrop = Date.distantPast
    @State private var resizingID: UUID?
    /// Shown on a tile for a moment when a bigger size doesn't fit.
    @State private var noRoomID: UUID?
    @State private var confirmingRemoval: UUID?
    @State private var gallery: GalleryMode?
    /// Layouts before each change in this edit session.
    @State private var history: [HomeSnapshot] = []
    /// True while the pointer is down on a tile; it resets on release and if the system cancels the press.
    @GestureState private var pressing = false

    private let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    private let settle = Animation.spring(response: 0.35, dampingFraction: 0.8)

    private var columns: Int { HomeGrid.columns(largeNotch: largeNotch) }
    private var grid: HomeGrid { HomeGrid(boxes, columns: columns) }

    var body: some View {
        Group {
            if !coordinator.firstLaunch {
                ZStack {
                    VStack(spacing: 7) {
                        gridView
                        if editor.isEditing {
                            bottomBar
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .opacity(gallery == nil ? 1 : 0)
                    .disabled(gallery != nil)

                    if let gallery {
                        WidgetGallery(mode: gallery, gridSize: gridSize, columns: columns,
                                      onDone: closeGallery, onCancel: cancelGallery)
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.top, 2)
        .onDisappear { editor.setEditing(false) }
        .onChange(of: editor.isEditing) { _, editing in
            if !editing { endSession() }
        }
        .onChange(of: pressing) { _, isPressing in
            if !isPressing { drop() }
        }
    }

    // MARK: Grid

    private var gridView: some View {
        GeometryReader { geometry in
            let grid = self.grid
            TimelineView(.animation(paused: !editor.isEditing || reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    ForEach(Array(boxes.enumerated()), id: \.element.id) { index, box in
                        if let frame = grid.frame(of: box.id, in: geometry.size, gap: HomeMetrics.gap) {
                            tile(box, index: index, frame: frame, time: time)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
            .coordinateSpace(name: "homeGrid")
            .onAppear { gridSize = geometry.size }
            .onChange(of: geometry.size) { gridSize = geometry.size }
        }
    }

    private func tile(_ box: HomeBox, index: Int, frame: CGRect, time: TimeInterval) -> some View {
        let editing = editor.isEditing
        let lifted = draggingID == box.id
        let still = !editing || lifted || reduceMotion || confirmingRemoval == box.id
        let wiggle = still ? Jiggle.none : Jiggle(time: time, index: index, size: frame.size)
        let origin = lifted ? dragOrigin : frame.origin

        return EditableBox(
            box: box, shown: stacks.current(in: box), editing: editing, canRemove: boxes.count > 1 || box.isStack,
            resizing: resizingID == box.id, noRoom: noRoomID == box.id, confirming: confirmingRemoval == box.id,
            onRemove: { withAnimation(.smooth(duration: 0.2)) { confirmingRemoval = box.id } },
            onConfirmRemove: { remove(box) },
            onCancelRemove: { withAnimation(.smooth(duration: 0.2)) { confirmingRemoval = nil } },
            onResizeStep: { resize(box, larger: $0) },
            onResizing: { setResizing($0, box) }
        )
        .frame(width: frame.width, height: frame.height)
        .rotationEffect(.degrees(wiggle.angle))
        .offset(y: wiggle.bob)
        .scaleEffect(lifted ? 1.05 : 1)
        .shadow(color: .black.opacity(lifted ? 0.55 : 0), radius: 12, y: 6)
        .offset(x: origin.x, y: origin.y)
        .zIndex(lifted ? 1 : 0)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .gesture(TapGesture().onEnded { tapped(box) }, including: editing ? .all : .subviews)
        .gesture(moveGesture(for: box), including: editing ? .all : .subviews)
        .simultaneousGesture(holdGesture(for: box))
        .simultaneousGesture(pressGesture(for: box))
        .contextMenu { menu(for: box) }
    }

    private var bottomBar: some View {
        let overflow = grid.overflow.count
        return HStack(spacing: 8) {
            Button {
                openGallery(.add)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HomeStyle.onAccent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.effectiveAccent))
            }
            .buttonStyle(GlassPressStyle())
            .disabled(!canAddAnything)
            .opacity(canAddAnything ? 1 : 0.4)
            .help(canAddAnything ? "Add a widget" : "Every widget is on Home")

            Group {
                if overflow > 0 {
                    Text("\(overflow) widget\(overflow == 1 ? " doesn't" : "s don't") fit. Make a tile smaller")
                        .foregroundStyle(HomeStyle.warning)
                } else if draggingID != nil {
                    Text("Let go to drop it here")
                        .foregroundStyle(HomeStyle.secondary)
                } else {
                    Text("Drag to move · tap to change · drag the corner to resize")
                        .foregroundStyle(HomeStyle.secondary)
                }
            }
            .font(.system(size: 10))
            .lineLimit(1)

            Spacer(minLength: 4)

            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(HomePillButtonStyle(prominent: false))
            .disabled(history.isEmpty)
            .opacity(history.isEmpty ? 0.4 : 1)
            .keyboardShortcut("z", modifiers: .command)
            .help("Undo (⌘Z)")

            Button("Reset", action: resetLayout)
                .buttonStyle(HomePillButtonStyle(prominent: false))
                .help("Go back to the default Home")

            Button("Done") {
                withAnimation(settle) { editor.setEditing(false) }
            }
            .buttonStyle(HomePillButtonStyle(prominent: true))
            .keyboardShortcut(.defaultAction)
        }
        .frame(height: 26)
        .background {
            // Esc closes a "Remove?" question, or finishes editing.
            Button("", action: escape)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }

    /// True while some widget not on Home has room for its own tile or can join a stack.
    private var canAddAnything: Bool {
        let onHome = Set(boxes.flatMap(\.members))
        return HomeWidget.allCases.contains { widget in
            !onHome.contains(widget)
                && (HomeGrid.fits(boxes + [HomeBox(widget: widget, size: widget.sizes[0])], columns: columns)
                    || boxes.contains { $0.canStack(widget) })
        }
    }

    @ViewBuilder
    private func menu(for box: HomeBox) -> some View {
        Button(editor.isEditing ? "Done Editing" : "Edit Home") {
            withAnimation(settle) { editor.setEditing(!editor.isEditing) }
        }
        Button("Change Widget…") {
            withAnimation(settle) { editor.setEditing(true) }
            openGallery(.change(box.id))
        }
        Picker("Size", selection: Binding(get: { box.size }, set: { setSize($0, of: box) })) {
            ForEach(box.sizes) { size in
                Text("\(size.title) (\(size.label))").tag(size)
            }
        }
        if box.isStack {
            Picker("Show", selection: Binding(get: { stacks.current(in: box) }, set: { stacks.show($0, in: box) })) {
                ForEach(box.members) { member in
                    Text(member.title).tag(member)
                }
            }
        }
        Divider()
        Button("Remove \(stacks.current(in: box).title)…") {
            withAnimation(settle) {
                editor.setEditing(true)
                confirmingRemoval = box.id
            }
        }
        .disabled(boxes.count <= 1 && !box.isStack)
    }

    // MARK: Moving

    /// Holding a tile on Home starts editing, as on an iPhone.
    private func holdGesture(for box: HomeBox) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .onEnded { _ in beginHold(box) }
    }

    /// Tracks the press: moves a tile lifted by holding, and notices the release.
    private func pressGesture(for box: HomeBox) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("homeGrid"))
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                if heldID == box.id { follow(box, value) }
            }
    }

    /// In edit mode a tile moves as soon as you drag it.
    private func moveGesture(for box: HomeBox) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("homeGrid"))
            .onChanged { value in
                guard heldID == nil, resizingID == nil, confirmingRemoval == nil else { return }
                if draggingID != box.id { lift(box) }
                follow(box, value)
            }
            .onEnded { _ in drop() }
    }

    private func beginHold(_ box: HomeBox) {
        guard !editor.isEditing, gallery == nil else { return }
        withAnimation(settle) { editor.setEditing(true) }
        // Still holding: lift the tile so this same press can move it.
        guard pressing else { return }
        heldID = box.id
        lift(box)
    }

    private func lift(_ box: HomeBox) {
        guard draggingID != box.id, let frame = grid.frame(of: box.id, in: gridSize, gap: HomeMetrics.gap) else { return }
        dragOrigin = frame.origin
        grabOffset = nil
        checkpoint()
        HomeHaptics.tap()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { draggingID = box.id }
    }

    /// The lifted tile follows the pointer; over another tile, it takes that tile's place.
    private func follow(_ box: HomeBox, _ value: DragGesture.Value) {
        let grid = self.grid
        guard draggingID == box.id,
              let index = boxes.firstIndex(where: { $0.id == box.id }),
              let frame = grid.frame(of: box.id, in: gridSize, gap: HomeMetrics.gap) else { return }
        let grab = grabOffset ?? CGSize(width: value.startLocation.x - frame.minX, height: value.startLocation.y - frame.minY)
        grabOffset = grab
        dragOrigin = CGPoint(
            x: Self.rubberBand(value.location.x - grab.width, lower: 0, upper: gridSize.width - frame.width),
            y: Self.rubberBand(value.location.y - grab.height, lower: 0, upper: gridSize.height - frame.height)
        )

        // Give the tiles a moment to settle after a move, so they don't swap back and forth.
        guard Date.now.timeIntervalSince(lastMove) > 0.25 else { return }
        guard let target = boxes.firstIndex(where: { other in
            other.id != box.id
                && (grid.frame(of: other.id, in: gridSize, gap: HomeMetrics.gap)?.contains(value.location) ?? false)
        }), target != index else { return }
        var moved = boxes
        moved.move(fromOffsets: IndexSet(integer: index), toOffset: target > index ? target + 1 : target)
        guard HomeGrid.fits(moved, columns: columns) else { return }
        lastMove = .now
        HomeHaptics.tap()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { boxes = moved }
    }

    private func drop() {
        guard draggingID != nil else {
            heldID = nil
            return
        }
        lastDrop = .now
        heldID = nil
        grabOffset = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { draggingID = nil }
        dropCheckpointIfUnchanged()
    }

    /// Past the grid's edges the tile still follows, but with resistance.
    private static func rubberBand(_ x: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        if x < lower { return lower - min(16, (lower - x) * 0.35) }
        if x > upper { return upper + min(16, (x - upper) * 0.35) }
        return x
    }

    // MARK: Changes

    private func tapped(_ box: HomeBox) {
        if confirmingRemoval != nil {
            withAnimation(.smooth(duration: 0.2)) { confirmingRemoval = nil }
            return
        }
        // The release that ends a drag isn't a tap.
        guard draggingID == nil, heldID == nil, Date.now.timeIntervalSince(lastDrop) > 0.3 else { return }
        openGallery(.change(box.id))
    }

    /// Removes the tile, or in a stack only the widget it's showing.
    private func remove(_ box: HomeBox) {
        guard let index = boxes.firstIndex(where: { $0.id == box.id }) else { return }
        guard box.isStack || boxes.count > 1 else { return }
        checkpoint()
        HomeHaptics.tap()
        withAnimation(settle) {
            confirmingRemoval = nil
            if box.isStack {
                boxes[index].remove(stacks.current(in: box))
            } else {
                boxes.remove(at: index)
            }
        }
    }

    /// Steps to the tile's next bigger (or smaller) size that still fits.
    private func resize(_ box: HomeBox, larger: Bool) {
        guard let index = boxes.firstIndex(where: { $0.id == box.id }) else { return }
        let sizes = boxes[index].sizes
        guard let current = sizes.firstIndex(of: boxes[index].size)
            ?? sizes.indices.min(by: { abs(sizes[$0].cells - box.size.cells) < abs(sizes[$1].cells - box.size.cells) })
        else { return }
        let candidates = larger ? Array(sizes[(current + 1)...]) : Array(sizes[..<current].reversed())
        for size in candidates {
            var resized = boxes
            resized[index].size = size
            if HomeGrid.fits(resized, columns: columns) {
                HomeHaptics.tap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { boxes = resized }
                return
            }
        }
        guard larger, !candidates.isEmpty else { return }
        HomeHaptics.refuse()
        withAnimation(.smooth(duration: 0.2)) { noRoomID = box.id }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.smooth(duration: 0.2)) { if noRoomID == box.id { noRoomID = nil } }
        }
    }

    private func setResizing(_ active: Bool, _ box: HomeBox) {
        if active {
            guard resizingID != box.id else { return }
            resizingID = box.id
            checkpoint()
        } else {
            resizingID = nil
            dropCheckpointIfUnchanged()
        }
    }

    private func setSize(_ size: HomeBoxSize, of box: HomeBox) {
        guard let index = boxes.firstIndex(where: { $0.id == box.id }), boxes[index].size != size else { return }
        var resized = boxes
        resized[index].size = size
        guard HomeGrid.fits(resized, columns: columns) else {
            HomeHaptics.refuse()
            return
        }
        if editor.isEditing { checkpoint() }
        withAnimation(settle) { boxes = resized }
    }

    private func resetLayout() {
        checkpoint()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            confirmingRemoval = nil
            boxes = HomeBox.defaultLayout
            tiles = [.mic, .mirror]
        }
        dropCheckpointIfUnchanged()
    }

    private func openGallery(_ mode: GalleryMode) {
        checkpoint()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            confirmingRemoval = nil
            gallery = mode
        }
    }

    private func closeGallery() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { gallery = nil }
        dropCheckpointIfUnchanged()
    }

    /// Cancel also undoes Quick buttons switched on or off, and widgets taken out of a stack, in the gallery.
    private func cancelGallery() {
        if let before = history.last {
            tiles = before.tiles
            boxes = before.boxes
        }
        closeGallery()
    }

    private func escape() {
        if confirmingRemoval != nil {
            withAnimation(.smooth(duration: 0.2)) { confirmingRemoval = nil }
        } else {
            withAnimation(settle) { editor.setEditing(false) }
        }
    }

    private func endSession() {
        gallery = nil
        confirmingRemoval = nil
        draggingID = nil
        heldID = nil
        resizingID = nil
        noRoomID = nil
        grabOffset = nil
        history = []
    }

    // MARK: Undo

    private var snapshot: HomeSnapshot { HomeSnapshot(boxes: boxes, tiles: tiles) }

    private func checkpoint() {
        history.append(snapshot)
        if history.count > 40 { history.removeFirst() }
    }

    /// A lift, resize or gallery visit that changed nothing doesn't need an Undo step.
    private func dropCheckpointIfUnchanged() {
        if history.last == snapshot { history.removeLast() }
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        HomeHaptics.tap()
        withAnimation(settle) {
            confirmingRemoval = nil
            boxes = previous.boxes
            tiles = previous.tiles
        }
    }
}

/// The wiggle in edit mode. Each tile is out of step with the others, and big tiles tilt
/// less so their corners move about as much as a small tile's.
private struct Jiggle {
    var angle: Double = 0
    var bob: CGFloat = 0

    static let none = Jiggle()

    private init() {}

    init(time: TimeInterval, index: Int, size: CGSize) {
        let phase = Double(index) * 1.7
        let speed = 2 * Double.pi * (index.isMultiple(of: 2) ? 3.3 : 3.0)
        let reach = Double(max(size.width, size.height, 1))
        let amplitude = min(1.6, 180 / reach)
        angle = sin(time * speed + phase) * amplitude
        bob = CGFloat(cos(time * speed + phase)) * 0.5
    }
}

/// A tile on Home. In edit mode the widget stops taking clicks and shows a − badge,
/// a resize corner and, after −, a "Remove?" question.
private struct EditableBox: View {
    let box: HomeBox
    /// The widget showing, which is the one − removes from a stack.
    let shown: HomeWidget
    let editing: Bool
    let canRemove: Bool
    let resizing: Bool
    let noRoom: Bool
    let confirming: Bool
    let onRemove: () -> Void
    let onConfirmRemove: () -> Void
    let onCancelRemove: () -> Void
    let onResizeStep: (Bool) -> Void
    let onResizing: (Bool) -> Void

    @State private var consumed: CGFloat = 0
    @State private var hoveringCorner = false

    private let shape = RoundedRectangle(cornerRadius: HomeMetrics.cornerRadius, style: .continuous)

    var body: some View {
        HomeStackView(box: box)
            .allowsHitTesting(!editing)
            .blur(radius: confirming ? 4 : 0)
            .overlay {
                if editing {
                    shape.strokeBorder(resizing ? Color.effectiveAccent : Color.white.opacity(0.18), lineWidth: resizing ? 2 : 1)
                }
            }
            .overlay {
                if resizing || noRoom {
                    Text(noRoom ? "No room" : "\(box.size.title) · \(box.size.label)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(noRoom ? .white : HomeStyle.onAccent)
                        .padding(.horizontal, 9)
                        .frame(height: 20)
                        .background(Capsule().fill(noRoom ? HomeStyle.destructive : Color.effectiveAccent))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay {
                if confirming {
                    removeQuestion
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .contentShape(shape)
            .overlay(alignment: .topLeading) {
                if editing && canRemove && !confirming {
                    removeBadge
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if editing && !confirming && box.sizes.count > 1 {
                    resizeCorner
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
    }

    private var removeBadge: some View {
        Button(action: onRemove) {
            Image(systemName: "minus")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color(white: 0.82)))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
        .buttonStyle(GlassPressStyle())
        .offset(x: -6, y: -6)
        .help("Remove \(shown.title)")
    }

    /// Asks first, like the iPhone's "Remove Widget?" alert. One-row tiles get a shorter version.
    private var removeQuestion: some View {
        VStack(spacing: 5) {
            Text("Remove \(shown.title)?")
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if !box.size.isCompact {
                Text(box.isStack ? "The rest of the stack stays." : "Nothing is deleted. Add it back with +.")
                    .font(.system(size: 10))
                    .foregroundStyle(HomeStyle.secondary)
            }
            ViewThatFits {
                HStack(spacing: 6) { removeButtons }
                HStack(spacing: 4) { compactRemoveButtons }
            }
        }
        .multilineTextAlignment(.center)
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(Color.black.opacity(0.72)))
    }

    @ViewBuilder
    private var removeButtons: some View {
        Button("Cancel", action: onCancelRemove)
            .buttonStyle(HomePillButtonStyle(prominent: false))
        Button("Remove", action: onConfirmRemove)
            .buttonStyle(HomePillButtonStyle(prominent: true, destructive: true))
    }

    /// Icon buttons for a Small tile, where the words don't fit.
    @ViewBuilder
    private var compactRemoveButtons: some View {
        Button(action: onCancelRemove) { Image(systemName: "xmark") }
            .buttonStyle(HomePillButtonStyle(prominent: false))
            .help("Cancel")
        Button(action: onConfirmRemove) { Image(systemName: "trash") }
            .buttonStyle(HomePillButtonStyle(prominent: true, destructive: true))
            .help("Remove")
    }

    /// The arc in the bottom-right corner. Drag it out to grow the tile, in to shrink it.
    private var resizeCorner: some View {
        ResizeArc()
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 14, height: 14)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .padding(5)
            .frame(width: 28, height: 28, alignment: .bottomTrailing)
            .contentShape(Rectangle())
            .onHover { inside in
                guard inside != hoveringCorner else { return }
                hoveringCorner = inside
                if inside { NSCursor.crosshair.push() } else { NSCursor.pop() }
            }
            .onDisappear {
                if hoveringCorner {
                    hoveringCorner = false
                    NSCursor.pop()
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !resizing { onResizing(true) }
                        // Out to the right or down grows the tile; back in shrinks it.
                        let reach = value.translation.width + value.translation.height
                        let delta = reach - consumed
                        if abs(delta) >= 30 {
                            onResizeStep(delta > 0)
                            consumed += delta > 0 ? 30 : -30
                        }
                    }
                    .onEnded { _ in
                        consumed = 0
                        withAnimation(.smooth) { onResizing(false) }
                    }
            )
            .help("Drag to resize")
    }
}

private struct ResizeArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.minX, y: rect.minY), radius: rect.width,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        return path
    }
}

// MARK: - Widget gallery

/// The + sheet (and the one a tap on a tile opens): pick a widget and a size with a live preview.
/// When Home has no room, Add to Stack puts the widget in a tile that's already there: a map of
/// Home shows which tiles it can join.
private struct WidgetGallery: View {
    let mode: GalleryMode
    let gridSize: CGSize
    let columns: Int
    let onDone: () -> Void
    let onCancel: () -> Void

    @Default(.homeBoxes) private var boxes
    @Default(.homeQuickTiles) private var tiles
    @ObservedObject private var stacks = HomeStackState.shared
    @State private var selected: HomeWidget = .nowPlaying
    @State private var size: HomeBoxSize = .medium
    /// The widget being changed in the tapped tile (in a stack, the one it was showing).
    @State private var replacing: HomeWidget?
    /// Showing the map of Home to pick a tile to stack on.
    @State private var choosingStack = false

    private var editingIndex: Int? {
        if case .change(let id) = mode { return boxes.firstIndex { $0.id == id } }
        return nil
    }

    /// Widgets already on Home, apart from the one being changed.
    private var taken: Set<HomeWidget> {
        var all = Set(boxes.flatMap(\.members))
        if let replacing { all.remove(replacing) }
        return all
    }

    /// Home with this choice applied.
    private func layout(with widget: HomeWidget, size: HomeBoxSize) -> [HomeBox] {
        var result = boxes
        if let editingIndex, let replacing {
            result[editingIndex].replace(replacing, with: widget)
            result[editingIndex].size = size
        } else {
            result.append(HomeBox(widget: widget, size: size))
        }
        return result
    }

    /// Room on Home, and in a stack a size every widget in it comes in.
    private func fits(_ widget: HomeWidget, _ size: HomeBoxSize) -> Bool {
        let result = layout(with: widget, size: size)
        if let editingIndex, !result[editingIndex].sizes.contains(size) { return false }
        return HomeGrid.fits(result, columns: columns)
    }

    private var canApply: Bool { !taken.contains(selected) && fits(selected, size) }

    /// Tiles the selected widget can join: when adding, any tile of a size it comes in;
    /// when changing a tile, just that one.
    private var stackTargets: [HomeBox] {
        guard !taken.contains(selected) else { return [] }
        if let editingIndex { return boxes[editingIndex].canStack(selected) ? [boxes[editingIndex]] : [] }
        return boxes.filter { $0.canStack(selected) }
    }

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(HomeWidget.allCases) { widget in
                        widgetRow(widget)
                    }
                }
            }
            .frame(width: 150)

            VStack(alignment: .leading, spacing: 6) {
                if choosingStack {
                    stackMap
                        .transition(.opacity)
                } else {
                    preview
                        .transition(.opacity)
                    if selected == .quick {
                        quickTileToggles
                    }
                    if let editingIndex, boxes[editingIndex].isStack {
                        stackStrip(boxes[editingIndex])
                    }
                }

                HStack(spacing: 6) {
                    if choosingStack {
                        Text("Pick a tile for \(selected.title)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(HomeStyle.secondary)
                        Spacer(minLength: 4)
                        Button("Back") {
                            withAnimation(.smooth(duration: 0.2)) { choosingStack = false }
                        }
                        .buttonStyle(HomePillButtonStyle(prominent: false))
                        .keyboardShortcut(.cancelAction)
                    } else {
                        actionRow
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: HomeMetrics.cornerRadius, style: .continuous).fill(Color(white: 0.09)))
        .overlay(RoundedRectangle(cornerRadius: HomeMetrics.cornerRadius, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .onAppear {
            if let editingIndex {
                let box = boxes[editingIndex]
                replacing = stacks.current(in: box)
                selected = replacing ?? box.widget
                size = box.size
            } else {
                let free = HomeWidget.allCases.filter { !taken.contains($0) }
                selected = free.first { fits($0, $0.sizes[0]) }
                    ?? free.first { widget in boxes.contains { $0.canStack(widget) } }
                    ?? .nowPlaying
                size = bestSize(for: selected, near: selected.defaultSize)
            }
        }
    }

    private var preview: some View {
        GeometryReader { geometry in
            let unit = HomeGrid.unit(in: gridSize, columns: columns, gap: HomeMetrics.gap)
            let natural = CGSize(
                width: CGFloat(size.columns) * unit.width + CGFloat(size.columns - 1) * HomeMetrics.gap,
                height: CGFloat(size.rows) * unit.height + CGFloat(size.rows - 1) * HomeMetrics.gap
            )
            let scale = min(1, geometry.size.width / max(natural.width, 1), geometry.size.height / max(natural.height, 1))
            HomeWidgetView(box: HomeBox(widget: selected, size: size))
                .allowsHitTesting(false)
                .frame(width: natural.width, height: natural.height)
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: size)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        let room = fits(selected, size)
        let canStack = !stackTargets.isEmpty
        sizePicker
        Spacer(minLength: 4)
        if !room && !taken.contains(selected) {
            Text("No room")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HomeStyle.warning)
        }
        Button("Cancel", action: onCancel)
            .buttonStyle(HomePillButtonStyle(prominent: false))
            .keyboardShortcut(.cancelAction)
        if canStack {
            Button(action: stackTapped) {
                Label(editingIndex == nil && room ? "Stack" : "Add to Stack", systemImage: "square.stack")
            }
            .buttonStyle(HomePillButtonStyle(prominent: !room && editingIndex == nil))
            .help(editingIndex == nil
                ? "Put \(selected.title) in a tile that's already on Home, and swipe sideways to switch"
                : "Keep this tile's widgets and add \(selected.title) to them")
        }
        if room || !canStack || editingIndex != nil {
            Button(editingIndex == nil ? "Add Widget" : "Done", action: apply)
                .buttonStyle(HomePillButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(!canApply)
                .opacity(canApply ? 1 : 0.4)
        }
    }

    /// The size closest to `near` that this widget offers and that fits, else its smallest.
    private func bestSize(for widget: HomeWidget, near: HomeBoxSize) -> HomeBoxSize {
        let preferred = widget.closestSize(to: near)
        if fits(widget, preferred) { return preferred }
        return widget.sizes.first { fits(widget, $0) } ?? widget.sizes[0]
    }

    private func widgetRow(_ widget: HomeWidget) -> some View {
        let isSelected = widget == selected
        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                selected = widget
                size = bestSize(for: widget, near: size)
                choosingStack = false
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: widget.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                VStack(alignment: .leading, spacing: 0) {
                    Text(widget.title)
                        .font(.system(size: 11, weight: .semibold))
                    Text(taken.contains(widget) ? "On Home" : widget.summary)
                        .font(.system(size: 9))
                        .foregroundStyle(HomeStyle.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 9).fill(isSelected ? Color.effectiveAccent.opacity(0.25) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isSelected ? Color.effectiveAccent.opacity(0.7) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(taken.contains(widget) ? 0.5 : 1)
    }

    /// The sizes this widget comes in; ones without room are dimmed.
    private var sizePicker: some View {
        HStack(spacing: 2) {
            ForEach(selected.sizes) { option in
                let room = fits(selected, option)
                Button {
                    size = option
                } label: {
                    Text(option.label)
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(size == option ? HomeStyle.onAccent : Color(white: room ? 0.85 : 0.45))
                        .frame(minWidth: 28)
                        .frame(height: 20)
                        .background(Capsule().fill(size == option ? Color.effectiveAccent : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(room ? option.title : "\(option.title): no room")
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    /// Which buttons the Quick box shows. Booth and Shelf are also tabs.
    private var quickTileToggles: some View {
        HStack(spacing: 4) {
            ForEach(HomeQuickTile.allCases) { tile in
                let on = tiles.contains(tile)
                Button {
                    withAnimation(.smooth(duration: 0.2)) {
                        if on { tiles.removeAll { $0 == tile } } else { tiles.append(tile) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        Text(tile.title)
                        if tile.isAlsoATab {
                            Text("· tab").foregroundStyle(HomeStyle.warning)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Capsule().fill(on ? Color.white.opacity(0.14) : Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help(tile.isAlsoATab ? "\(tile.title) is also a tab in the top bar" : "Show \(tile.title) in the Quick box")
            }
        }
    }

    // MARK: Stacks

    /// The widgets in the tapped stack: click one to change it, − to take it out.
    private func stackStrip(_ box: HomeBox) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "square.stack")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HomeStyle.secondary)
                .help("This tile is a stack")
            ForEach(box.members) { member in
                let current = member == replacing
                HStack(spacing: 3) {
                    Button {
                        withAnimation(.smooth(duration: 0.2)) {
                            replacing = member
                            selected = member
                            size = box.size
                        }
                    } label: {
                        Label(member.title, systemImage: member.symbol)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help("Change \(member.title)")
                    Button {
                        takeOut(member)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Color(white: 0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Take \(member.title) out of the stack")
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(Capsule().fill(current ? Color.effectiveAccent.opacity(0.3) : Color.white.opacity(0.07)))
                .overlay(Capsule().strokeBorder(current ? Color.effectiveAccent.opacity(0.7) : .clear))
            }
        }
    }

    /// Home in miniature. Tiles the widget can join are lit; click one to add it there.
    private var stackMap: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / max(gridSize.width, 1), geometry.size.height / max(gridSize.height, 1))
            let mapSize = CGSize(width: gridSize.width * scale, height: gridSize.height * scale)
            let gap = HomeMetrics.gap * scale
            let grid = HomeGrid(boxes, columns: columns)
            ZStack(alignment: .topLeading) {
                ForEach(boxes) { box in
                    if let frame = grid.frame(of: box.id, in: mapSize, gap: gap) {
                        mapTile(box)
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX, y: frame.minY)
                    }
                }
            }
            .frame(width: mapSize.width, height: mapSize.height, alignment: .topLeading)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func mapTile(_ box: HomeBox) -> some View {
        let open = box.canStack(selected)
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return Button {
            stack(onto: box)
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    ForEach(box.members.prefix(3)) { member in
                        Image(systemName: member.symbol)
                    }
                    if open {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.effectiveAccent)
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                if !box.size.isCompact {
                    Text(box.members.count > 1 ? "\(box.members.count) widgets" : box.widget.title)
                        .font(.system(size: 9))
                        .foregroundStyle(HomeStyle.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(open ? Color.effectiveAccent.opacity(0.18) : Color.white.opacity(0.05)))
            .overlay(shape.strokeBorder(open ? Color.effectiveAccent.opacity(0.8) : Color.white.opacity(0.08), lineWidth: open ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(GlassPressStyle())
        .disabled(!open)
        .opacity(open ? 1 : 0.4)
        .help(open
            ? "Add \(selected.title) to this tile"
            : box.members.contains(selected) ? "\(selected.title) is already here" : "\(selected.title) doesn't come in \(box.size.title) (\(box.size.label))")
    }

    private func stackTapped() {
        if let editingIndex {
            stack(onto: boxes[editingIndex])
        } else if stackTargets.count == 1, let only = stackTargets.first {
            stack(onto: only)
        } else {
            withAnimation(.smooth(duration: 0.2)) { choosingStack = true }
        }
    }

    private func stack(onto box: HomeBox) {
        guard let index = boxes.firstIndex(where: { $0.id == box.id }), boxes[index].canStack(selected) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            boxes[index].stack.append(selected)
        }
        stacks.show(selected, in: boxes[index])
        HomeHaptics.tap()
        onDone()
    }

    private func takeOut(_ member: HomeWidget) {
        guard let editingIndex, boxes[editingIndex].isStack else { return }
        HomeHaptics.tap()
        withAnimation(.smooth(duration: 0.2)) {
            boxes[editingIndex].remove(member)
            if replacing == member {
                replacing = boxes[editingIndex].widget
                selected = boxes[editingIndex].widget
                size = boxes[editingIndex].size
            }
        }
    }

    private func apply() {
        guard canApply else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            boxes = layout(with: selected, size: size)
        }
        if let editingIndex { stacks.show(selected, in: boxes[editingIndex]) }
        HomeHaptics.tap()
        onDone()
    }
}

// MARK: - Shared style

enum HomeStyle {
    static let secondary = Color(white: 0.63)
    static let tertiary = Color(white: 0.55)
    static let warning = Color(red: 0.96, green: 0.73, blue: 0.44)
    static let alert = Color(red: 1.0, green: 0.54, blue: 0.46)
    static let destructive = Color(red: 0.92, green: 0.27, blue: 0.24)

    /// Text on the accent color: dark on light accents, white on dark ones.
    static var onAccent: Color {
        guard let color = NSColor(Color.effectiveAccent).usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
        return luminance > 0.55 ? .black : .white
    }
}

struct HomeCardModifier: ViewModifier {
    var highlight: Color?
    @Default(.notchTheme) private var theme
    @Default(.themeGlowTiles) private var glowTiles
    @Default(.cardGlassChoice) private var glassChoice

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: HomeMetrics.cornerRadius, style: .continuous)
        let _ = glassChoice
        if let glass = theme.effectiveGlass {
            clear(content, shape: shape, glass: glass)
        } else if theme != .classic && glowTiles {
            glowing(content, shape: shape)
        } else {
            plain(content, shape: shape)
        }
    }

    /// Dark glass with a glossy top and an edge lit in the theme's color, glowing softly outward.
    private func glowing(_ content: Content, shape: RoundedRectangle) -> some View {
        let glow = highlight ?? Color.effectiveAccent
        return content
            .background {
                shape.fill(Color.black.opacity(theme.cardShade + 0.06))
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0.03), .clear],
                                          startPoint: .top, endPoint: .center))
                if highlight != nil { shape.fill(glow.opacity(0.16)) }
            }
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [glow.opacity(0.95), glow.opacity(0.25), Color.white.opacity(0.10), glow.opacity(0.45)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
            )
            .shadow(color: glow.opacity(0.32), radius: 9)
    }

    /// See-through glass for the picture themes: a light tint, a shine across the top-left,
    /// a bright rim like the edge of a lens, and a shadow under the text so it reads over the picture.
    /// Crystal is the clearest; liquid is a touch more tinted; smoky is tinted dark instead of
    /// white, so a white shirt or sky behind the tile is darkened rather than brightened.
    private func clear(_ content: Content, shape: RoundedRectangle, glass: NotchTheme.CardGlass) -> some View {
        let tint: Double = glass == .crystal ? 0.1 : glass == .liquid ? 0.2 : 0.36
        let shine: Double = glass == .smoky ? 0.1 : glass == .crystal ? 0.2 : 0.24
        let rim: Double = glass == .smoky ? 0.35 : 0.7
        return content
            .shadow(color: .black.opacity(0.75), radius: 1.5, y: 1)
            .background {
                shape.fill(glass == .smoky ? Color(red: 0.02, green: 0.04, blue: 0.07).opacity(tint) : Color.black.opacity(tint))
                shape.fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(shine), location: 0),
                        .init(color: .white.opacity(glass == .smoky ? 0 : 0.03), location: 0.38),
                        .init(color: .clear, location: 0.6),
                        .init(color: .white.opacity(glass == .smoky ? 0.04 : 0.1), location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                if let highlight { shape.fill(highlight.opacity(0.16)) }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(glass == .smoky ? 0.22 : glass == .crystal ? 0.55 : 0.45), lineWidth: 1))
            .overlay(
                shape.inset(by: 1).strokeBorder(
                    LinearGradient(colors: [.white.opacity(rim), .clear, .clear, .white.opacity(rim * 0.4)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
    }

    private func plain(_ content: Content, shape: RoundedRectangle) -> some View {
        content
            .background {
                // Over a theme's art the card gets darker glass, so text stays readable.
                if theme.cardShade > 0 {
                    shape.fill(Color.black.opacity(theme.cardShade))
                }
                if let highlight {
                    shape.fill(highlight.opacity(0.16))
                        .overlay(shape.strokeBorder(highlight.opacity(0.5), lineWidth: 1))
                } else {
                    shape.fill(Color.white.opacity(theme.cardShade > 0 ? 0.07 : 0.055))
                        .overlay(shape.strokeBorder(Color.white.opacity(theme.cardShade > 0 ? 0.14 : 0.07), lineWidth: 1))
                }
            }
            .clipShape(shape)
    }
}

extension View {
    func homeCard(highlight: Color? = nil) -> some View {
        modifier(HomeCardModifier(highlight: highlight))
    }
}

struct HomePillButtonStyle: ButtonStyle {
    var prominent: Bool
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: prominent ? .semibold : .medium))
            .foregroundStyle(destructive ? Color.white : prominent ? HomeStyle.onAccent : Color(white: 0.9))
            .padding(.horizontal, 11)
            .frame(height: 24)
            .background(Capsule().fill(destructive ? HomeStyle.destructive : prominent ? Color.effectiveAccent : Color.white.opacity(0.1)))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .contentShape(Capsule())
    }
}

struct HomeLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.6)
                .ink(Color.effectiveAccent, Ink.detail)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 9.5))
                    .lineLimit(1)
                    .ink(HomeStyle.secondary, Ink.reset)
            }
        }
    }
}
