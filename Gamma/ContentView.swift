import SwiftUI

class UndoablePoints: ObservableObject {
    @Published private(set) var points: [CGPoint]
    private var undoManager: UndoManager?
    
    func setUndoManager(newManager: UndoManager) {
        undoManager = newManager
    }
    
    init(points: [CGPoint], undoManager: UndoManager?) {
        self.points = points
        self.undoManager = undoManager
    }
    
    func updatePoints(_ newPoints: [CGPoint]) {
//        undoManager?.registerUndo(withTarget: self) { target in
//            target.updatePoints(oldPoints)
//        }
        points = newPoints
    }
    
    func updatePoint(at index: Int, to newPoint: CGPoint) {
        guard index < points.count else { return }
        let oldPoints = points
        undoManager?.registerUndo(withTarget: self) { target in
            target.updatePoints(oldPoints)
        }
        points[index] = newPoint
    }
    
    func addPoint(_ point: CGPoint) {
        let oldPoints = points
        undoManager?.registerUndo(withTarget: self) { target in
            target.updatePoints(oldPoints)
        }
        let insertionIndex = points.firstIndex { $0.x > point.x } ?? points.endIndex
        points.insert(point, at: insertionIndex)
    }
}

class GlobalUndoManager: ObservableObject {
    let undoManager: UndoManager
    
    init() {
        self.undoManager = UndoManager()
    }
}

struct GammaCurveView: View {
    @ObservedObject var undoablePoints: UndoablePoints
    let color: Color
    let size: CGSize
    
    @State private var draggedPointIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines
                Path { path in
                    for i in 0...4 {
                        let x = CGFloat(i) / 4 * geometry.size.width
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        
                        let y = CGFloat(i) / 4 * geometry.size.height
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                
                // Curve
                Path { path in
                    let scaledPoints = undoablePoints.points.map { CGPoint(x: $0.x * geometry.size.width, y: (1 - $0.y) * geometry.size.height) }
                    path.move(to: scaledPoints[0])
                    for i in 1..<scaledPoints.count {
                        path.addLine(to: scaledPoints[i])
                    }
                }
                .stroke(color, lineWidth: 2)
                
                // Control points
                ForEach(undoablePoints.points.indices, id: \.self) { index in
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                        .position(
                            x: undoablePoints.points[index].x * geometry.size.width,
                            y: (1 - undoablePoints.points[index].y) * geometry.size.height
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggedPointIndex = index
                                    updatePoint(at: index, with: value, in: geometry)
                                }
                                .onEnded { _ in
                                    draggedPointIndex = nil
                                }
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.white)
            .border(Color.gray, width: 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        addPoint(at: value.location, in: geometry)
                    }
            )
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func updatePoint(at index: Int, with value: DragGesture.Value, in geometry: GeometryProxy) {
        let newPoint = CGPoint(
            x: value.location.x / geometry.size.width,
            y: 1 - value.location.y / geometry.size.height
        )
        undoablePoints.updatePoint(at: index, to: newPoint)
    }
    
    private func addPoint(at location: CGPoint, in geometry: GeometryProxy) {
        let newPoint = CGPoint(
            x: location.x / geometry.size.width,
            y: 1 - location.y / geometry.size.height
        )
        undoablePoints.addPoint(newPoint)
    }
}

struct ContentView: View {
    @StateObject private var redPoints: UndoablePoints
    @StateObject private var greenPoints: UndoablePoints
    @StateObject private var bluePoints: UndoablePoints
    @StateObject private var undoManager: GlobalUndoManager
    
    init() {
        _undoManager = StateObject(wrappedValue: GlobalUndoManager())
        // Initialize with nil UndoManager, we'll set it in onAppear
        _redPoints = StateObject(wrappedValue: UndoablePoints(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)], undoManager: nil))
        _greenPoints = StateObject(wrappedValue: UndoablePoints(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)], undoManager: nil))
        _bluePoints = StateObject(wrappedValue: UndoablePoints(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)], undoManager: nil))
    }
    
    var body: some View {
        HStack {
            VStack {
                GammaCurveView(undoablePoints: redPoints, color: .red, size: CGSize(width: 200, height: 200))
                    .onChange(of: redPoints.points) { _ in
                        applyGamma(red: redPoints.points, green: greenPoints.points, blue: bluePoints.points)
                    }
                GammaCurveView(undoablePoints: greenPoints, color: .green, size: CGSize(width: 200, height: 200))
                    .onChange(of: greenPoints.points) { _ in
                        applyGamma(red: redPoints.points, green: greenPoints.points, blue: bluePoints.points)
                    }
                GammaCurveView(undoablePoints: bluePoints, color: .blue, size: CGSize(width: 200, height: 200))
                    .onChange(of: bluePoints.points) { _ in
                        applyGamma(red: redPoints.points, green: greenPoints.points, blue: bluePoints.points)
                    }
                
                Button("Apply Gamma") {
                    applyGamma(red: redPoints.points, green: greenPoints.points, blue: bluePoints.points)
                }
                
                Button("Reset Gamma Filter") {
                    CGDisplayRestoreColorSyncSettings()
                    redPoints.updatePoints([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
                    greenPoints.updatePoints([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
                    bluePoints.updatePoints([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
                }
                
                HStack {
                    Button("Undo") {
                        undoManager.undoManager.undo()
                    }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(undoManager.undoManager.canUndo != true)
                    
                    Button("Redo") {
                        undoManager.undoManager.redo()
                    }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(undoManager.undoManager.canRedo != true)
                }
            }
            .padding()
            Image("Image").resizable()
                .aspectRatio(contentMode: .fit)
            Image("Image 1").resizable()
                .aspectRatio(contentMode: .fit)
        }
        .padding()
        .onAppear {
            redPoints.setUndoManager(newManager: undoManager.undoManager)
            greenPoints.setUndoManager(newManager: undoManager.undoManager)
            bluePoints.setUndoManager(newManager: undoManager.undoManager)
           print("UndoManager after appearing: \(undoManager != nil ? "Exists" : "Null")")
        }
    }
    
    func applyGamma(red: [CGPoint], green: [CGPoint], blue: [CGPoint]) {
        let display = CGMainDisplayID()
        let tableSize = 256
        var redTable = [CGGammaValue](repeating: 0, count: tableSize)
        var greenTable = [CGGammaValue](repeating: 0, count: tableSize)
        var blueTable = [CGGammaValue](repeating: 0, count: tableSize)

        for i in 0..<tableSize {
            let value = Double(i) / Double(tableSize - 1)
            redTable[i] = CGGammaValue(interpolate(value: value, points: red))
            greenTable[i] = CGGammaValue(interpolate(value: value, points: green))
            blueTable[i] = CGGammaValue(interpolate(value: value, points: blue))
        }

        CGSetDisplayTransferByTable(display, UInt32(tableSize), &redTable, &greenTable, &blueTable)
    }
    
    func interpolate(value: Double, points: [CGPoint]) -> Double {
        guard let firstPoint = points.first(where: { Double($0.x) > value }) else {
            return Double(points.last?.y ?? CGFloat(value))
        }
        guard let lastPoint = points.last(where: { Double($0.x) <= value }) else {
            return Double(points.first?.y ?? CGFloat(value))
        }
        
        let t = (value - Double(lastPoint.x)) / (Double(firstPoint.x) - Double(lastPoint.x))
        return Double(lastPoint.y) + t * (Double(firstPoint.y) - Double(lastPoint.y))
    }
}
