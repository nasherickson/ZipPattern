//
//  ContentView.swift
//  zipPattern
//
//  Created by Nash Erickson on 5/28/25.
//

import SwiftUI
import PDFKit
import AppKit
struct ContentView: View {
    @Binding var window: NSWindow?
    @State private var zoomScale: CGFloat = 1.0
    @State private var pdfDoc: PDFDocument? = nil
    @State private var showFilePicker = false
    @State private var isFullScreen = false
    @State private var loadError: String? = nil
    @State private var showErrorAlert = false
    @State private var contentOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            // Top controls bar
            HStack {
                Button(action: {
                    NotificationCenter.default.post(name: .pdfPrevPage, object: nil)
                }) {
                    Image(systemName: "chevron.left")
                }
                Button(action: {
                    NotificationCenter.default.post(name: .pdfNextPage, object: nil)
                }) {
                    Image(systemName: "chevron.right")
                }
                Button("Open PDF YAY!") {
                    showFilePicker = true
                }
                Spacer()
                Button(isFullScreen ? "Exit Fullscreen" : "Enter Fullscreen") {
                    window?.toggleFullScreen(nil)
                }
            }
            .padding()
            .background(Color.blue)

            // Zoom controls
            HStack {
                Text("Zoom: \(Int(zoomScale * 100))%")
                Slider(value: $zoomScale, in: 0.25...5.0, step: 0.05)
            }
            .padding()
            .background(Color.red)

            // PDF viewer fills remaining space
            PDFKitView(pdfDocument: pdfDoc,
                      zoomScale: zoomScale,
                      contentOffset: $contentOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
        }
        .ignoresSafeArea(edges: .bottom)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let doc = PDFDocument(url: url) {
                        pdfDoc = doc
                        print("PDF loaded from: \(url)")
                        print("Page count: \(doc.pageCount)")
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

struct PDFKitView: NSViewRepresentable {
    typealias NSViewType = NSScrollView
    let pdfDocument: PDFDocument?
    let zoomScale: CGFloat
    @Binding var contentOffset: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PDFKitView
        weak var pdfView: PDFView?
        init(_ parent: PDFKitView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(goToNextPage),
                name: .pdfNextPage,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(goToPrevPage),
                name: .pdfPrevPage,
                object: nil
            )
        }
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            print("Pan Δ:", translation)
            parent.$contentOffset.wrappedValue = CGSize(
                width: parent.$contentOffset.wrappedValue.width - translation.x,
                height: parent.$contentOffset.wrappedValue.height - translation.y
            )
            print("New offset:", parent.$contentOffset.wrappedValue)
            gesture.setTranslation(.zero, in: gesture.view)
        }
        @objc func goToNextPage() {
            pdfView?.goToNextPage(nil)
            
        }
        @objc func goToPrevPage() {
            pdfView?.goToPreviousPage(nil)
        }
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
    }

    func makeNSView(context: Context) -> NSScrollView {
        let pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = true
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 5.0
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = pdfView

        // Add pan gesture recognizer for click-and-drag on clip view
        let panGesture = NSPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.allowedTouchTypes = [.direct, .indirect]
        panGesture.delegate = context.coordinator as? any NSGestureRecognizerDelegate
        scrollView.contentView.addGestureRecognizer(panGesture)

        return scrollView
    }
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let pdfView = nsView.documentView as? PDFView else { return }
        context.coordinator.pdfView = pdfView
        pdfView.document = pdfDocument
        pdfView.scaleFactor = zoomScale
        var origin = nsView.contentView.bounds.origin
        origin.x = $contentOffset.wrappedValue.width
        origin.y = $contentOffset.wrappedValue.height
        nsView.contentView.setBoundsOrigin(origin)
        nsView.reflectScrolledClipView(nsView.contentView)
        if pdfDocument != nil {
            pdfView.goToFirstPage(nil)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async { self.window = nsView.window }
        return nsView
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
    
    

#Preview {
    ContentView(window: .constant(nil))
}
