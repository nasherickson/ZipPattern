import SwiftUI
import PDFKit
import AppKit
import Foundation
import SwiftUICore
import Foundation
    extension Notification.Name {
    static let pdfNextPage = Notification.Name("PDFNextPage")
    static let pdfPrevPage = Notification.Name("PDFPrevPage")
}
@main
struct zipPatternApp: App {
    @State private var window: NSWindow?

    var body: some Scene {
        WindowGroup {
            zipPatternContentView(window: $window)
        }
    }
}
import SwiftUI
import PDFKit
struct zipPatternContentView: View {
    
    @Binding var window: NSWindow?
    @State private var zoomScale: CGFloat = 1.0
    @State private var pdfDoc: PDFDocument? = nil
    @State private var showFilePicker = false
    @State private var isFullScreen = false
    @State private var loadError: String? = nil
    @State private var showErrorAlert = false

    private var headerBar: some View {
        HStack {
            Button("Open PDF") { showFilePicker = true }
            Spacer()
            Button("Previous Page") {
                NotificationCenter.default.post(name: .pdfPrevPage, object: nil)
            }
            Button("Next Page") {
                NotificationCenter.default.post(name: .pdfNextPage, object: nil)
            }
            Spacer()
            Button(isFullScreen ? "Exit Fullscreen" : "Enter Fullscreen") {
                window?.toggleFullScreen(nil)
            }
        }
        .padding()
        .background(Color.blue)
    }

    private var zoomBar: some View {
        HStack {
            Text("Zoom: \(Int(zoomScale * 100))%")
            Slider(value: $zoomScale, in: 0.25...5.0, step: 0.05)
        }
        .padding()
        .background(Color.red)
    }

    private var pdfViewer: some View {
        zipPatternPDFKitView(pdfDocument: pdfDoc, zoomScale: zoomScale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            zoomBar
            pdfViewer
        }
        .ignoresSafeArea(edges: .bottom)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let doc = PDFDocument(url: url) {
                        pdfDoc = doc
                    } else {
                        loadError = "Failed to load PDF"
                        showErrorAlert = true
                    }
                } else {
                    loadError = "Cannot access file"
                    showErrorAlert = true
                }
            case .failure(let err):
                loadError = err.localizedDescription
                showErrorAlert = true
            }
        }
        .onChange(of: window) { newWindow in
            guard let window = newWindow else { return }
            NotificationCenter.default.addObserver(
                forName: NSWindow.willEnterFullScreenNotification,
                object: window, queue: .main) { _ in isFullScreen = true }
            NotificationCenter.default.addObserver(
                forName: NSWindow.willExitFullScreenNotification,
                object: window, queue: .main) { _ in isFullScreen = false }
        }
        .alert("Failed to Load PDF", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(loadError ?? "Unknown error occurred.")
        }
    }
}

struct zipPatternWindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async { self.window = nsView.window }
        return nsView
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct zipPatternPDFKitView: NSViewRepresentable {
    typealias NSViewType = NSScrollView
    let pdfDocument: PDFDocument?
    let zoomScale: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let pdfView = PanPDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = true
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 10.0
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        let scrollView = PanScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = pdfView
        return scrollView
    }

    func updateNSView(_ nsScrollView: NSScrollView, context: Context) {
        guard let pdfView = nsScrollView.documentView as? PDFView else { return }
        if pdfView.document !== pdfDocument {
            pdfView.document = pdfDocument
            pdfView.autoScales = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pdfView.scaleFactor = zoomScale
            }
        } else {
            DispatchQueue.main.async {
                pdfView.scaleFactor = zoomScale
            }
        }
    }

    class Coordinator: NSObject {
        let parent: zipPatternPDFKitView
        private var lastTranslation = CGPoint.zero

        init(_ parent: zipPatternPDFKitView) {
            self.parent = parent
        }

        @objc func handlePan(_ sender: NSPanGestureRecognizer) {
            guard let pdfView = sender.view as? PDFView,
                  let scrollView = pdfView.enclosingScrollView else { return }
            let translation = sender.translation(in: pdfView)
            // Invert vertical axis for natural dragging
            let deltaX = -translation.x
            let deltaY = translation.y
            var bounds = scrollView.contentView.bounds
            bounds.origin.x += deltaX
            bounds.origin.y += deltaY
            scrollView.contentView.setBoundsOrigin(bounds.origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            sender.setTranslation(.zero, in: pdfView)
        }
    }
}

class ResizablePDFView: PDFView {
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        super.viewWillMove(toSuperview: newSuperview)
        self.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(adjustFrame), name: NSView.frameDidChangeNotification, object: self)
    }

    @objc private func adjustFrame() {
        self.frame = self.superview?.bounds ?? .zero
    }

    override func layout() {
        super.layout()
        self.frame = self.superview?.bounds ?? .zero
    }
}
// Custom PDFView subclass to handle mouse drag panning
class PanPDFView: PDFView {
    private var lastDragLocation: NSPoint?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        lastDragLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let scrollView = self.enclosingScrollView,
              let last = lastDragLocation else { return }
        let newLocation = event.locationInWindow
        let deltaX = newLocation.x - last.x
        let deltaY = newLocation.y - last.y
        var origin = scrollView.contentView.bounds.origin
        origin.x -= deltaX
        origin.y += deltaY
        scrollView.contentView.setBoundsOrigin(origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        lastDragLocation = newLocation
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        lastDragLocation = nil
    }
}
// Custom NSScrollView subclass to handle mouse drag panning
class PanScrollView: NSScrollView {
    private var lastDragLocation: NSPoint?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        lastDragLocation = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let last = lastDragLocation else { return }
        let newLocation = convert(event.locationInWindow, from: nil)
        let deltaX = newLocation.x - last.x
        let deltaY = newLocation.y - last.y
        var origin = contentView.bounds.origin
        origin.x -= deltaX
        origin.y += deltaY
        contentView.setBoundsOrigin(origin)
        reflectScrolledClipView(contentView)
        lastDragLocation = newLocation
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        lastDragLocation = nil
    }
}
