import SwiftUI
import PDFKit

struct ContentView: View {
    @State private var isCalibrating = false
    @State private var showFilePicker = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var pdfDocument: PDFDocument? = nil
    
    // Adjustable grid state
    @State private var gridWidth: Int = 18
    @State private var gridHeight: Int = 24
    
    @State private var topLeft = CGPoint(x: 200, y: 200)
    @State private var topRight = CGPoint(x: 600, y: 200)
    @State private var bottomLeft = CGPoint(x: 200, y: 700)
    @State private var bottomRight = CGPoint(x: 600, y: 700)
    
    var body: some View {
        ZStack {
            // Background image
            Image("BackgroundImage")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(0.98)
            // PDF view (only if a PDF is loaded)
            if let doc = pdfDocument {
                PDFKitView(document: doc, scale: zoomScale)
                    .ignoresSafeArea()
            }
            
            // Calibration or regular grid overlays
            if isCalibrating {
                CalibrationGridOverlay(
                    rows: gridHeight, columns: gridWidth,
                    topLeft: topLeft, topRight: topRight,
                    bottomLeft: bottomLeft, bottomRight: bottomRight
                )
                DraggableCorner(position: $topLeft)
                DraggableCorner(position: $topRight)
                DraggableCorner(position: $bottomLeft)
                DraggableCorner(position: $bottomRight)
                VStack {
                    HStack {
                        Text("Grid Width:")
                        Picker("", selection: $gridWidth) {
                            ForEach(12...36, id: \.self) { Text("\($0)") }
                        }.frame(width: 60)
                        Text("Grid Height:")
                        Picker("", selection: $gridHeight) {
                            ForEach(12...36, id: \.self) { Text("\($0)") }
                        }.frame(width: 60)
                        Spacer()
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .padding()
                    Spacer()
                }
            } else {
                GridOverlayView(rows: 6, columns: 6)
            }
            
            //Floating compass controls in upper right
            VStack {
                HStack {
                    Spacer()
                    GeometryReader { geo in
                        let minSide = min(geo.size.width, geo.size.height)
                        // Make the compass scale down, never smaller than 120x120, never bigger than 220x220
                        CompassControls(
                            calibrateAction: { isCalibrating.toggle() },
                            openPDFAction: { showFilePicker = true },
                            zoomOutAction: { zoomScale = max(zoomScale - 0.1, 0.25) },
                            zoomInAction: { zoomScale = min(zoomScale + 0.1, 5.0) }
                        )
                        .padding([.top, .trailing], 24)
                    }
                    Spacer()
                }
                
                Text("Hello, zipPattern!")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result {
                    if let doc = PDFDocument(url: url) {
                        pdfDocument = doc
                    }
                }
            }
        }
    }
    
    // ---- Helper views (leave these below) ----
    
    struct GridOverlayView: View {
        let rows: Int
        let columns: Int
        
        var body: some View {
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    // Vertical lines
                    for col in 0...columns {
                        let x = width * CGFloat(col) / CGFloat(columns)
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    // Horizontal lines
                    for row in 0...rows {
                        let y = height * CGFloat(row) / CGFloat(rows)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
            }
            .allowsHitTesting(false)
        }
    }
    
    struct DraggableCorner: View {
        @Binding var position: CGPoint
        
        var body: some View {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(radius: 5)
                .position(position)
                .gesture(
                    DragGesture()
                        .onChanged { value in position = value.location }
                )
        }
    }
    
    struct CalibrationGridOverlay: View {
        let rows: Int
        let columns: Int
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
        
        var body: some View {
            GeometryReader { _ in
                Path { path in
                    for row in 0...rows {
                        let t = CGFloat(row) / CGFloat(rows)
                        let start = interpolate(from: topLeft, to: bottomLeft, t: t)
                        let end = interpolate(from: topRight, to: bottomRight, t: t)
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    for col in 0...columns {
                        let t = CGFloat(col) / CGFloat(columns)
                        let start = interpolate(from: topLeft, to: topRight, t: t)
                        let end = interpolate(from: bottomLeft, to: bottomRight, t: t)
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                }
                .stroke(Color.green.opacity(0.6), lineWidth: 1.2)
            }
            .allowsHitTesting(false)
        }
        
        private func interpolate(from: CGPoint, to: CGPoint, t: CGFloat) -> CGPoint {
            CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
    }
    
    struct CompassControls: View {
        let calibrateAction: () -> Void
        let openPDFAction: () -> Void
        let zoomOutAction: () -> Void
        let zoomInAction: () -> Void
        
        var body: some View {
            ZStack {
                // North: Calibrate
                VStack {
                    BlurryButton(action: calibrateAction, systemImage: "ruler", label: "Calibrate")
                    Spacer()
                }
                
                // South: Open PDF
                VStack {
                    Spacer()
                    BlurryButton(action: openPDFAction, systemImage: "doc.richtext", label: "Open PDF")
                }
                
                // West: Zoom Out
                HStack {
                    BlurryButton(action: zoomOutAction, systemImage: "minus.magnifyingglass", label: "Zoom Out")
                    Spacer()
                }
                
                // East: Zoom In
                HStack {
                    Spacer()
                    BlurryButton(action: zoomInAction, systemImage: "plus.magnifyingglass", label: "Zoom In")
                }
            }
            .frame(width: 220, height: 220)
            .allowsHitTesting(true)
        }
    }
    
    struct BlurryButton: View {
        let action: () -> Void
        let systemImage: String
        let label: String
        @State private var hovered = false
        
        var body: some View {
            Button(action: action) {
                VStack {
                    Image(systemName: systemImage)
                        .resizable()
                        .frame(width: 36, height: 36)
                    Text(label)
                        .font(.caption)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: Color.black.opacity(0.15), radius: hovered ? 10 : 6, x: 0, y: 2)
                .scaleEffect(hovered ? 1.08 : 1.0)
                .opacity(hovered ? 1.0 : 0.92)
                .animation(.easeOut(duration: 0.18), value: hovered)
            }
            .buttonStyle(.plain)
            .onHover { over in
                hovered = over
            }
        }
    }
    
    struct PDFKitView: NSViewRepresentable {
        var document: PDFDocument?
        var scale: CGFloat
        
        func makeNSView(context: Context) -> PDFView {
            let pdfView = PDFView()
            pdfView.autoScales = false
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
            pdfView.backgroundColor = .clear
            pdfView.minScaleFactor = 0.25
            pdfView.maxScaleFactor = 5.0
            return pdfView
        }
        
        func updateNSView(_ pdfView: PDFView, context: Context) {
            pdfView.document = document
            pdfView.scaleFactor = scale
        }
    }
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
