#!/usr/bin/env swift

import AppKit
import Foundation
import WebKit

final class SVGRenderer: NSObject, WKNavigationDelegate {
    private let inputURL: URL
    private let outputURL: URL
    private let width: Int
    private let height: Int
    private var webView: WKWebView?

    init(inputURL: URL, outputURL: URL, width: Int, height: Int) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.width = width
        self.height = height
    }

    func start() {
        let configuration = WKWebViewConfiguration()
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        self.webView = webView

        let svgMarkup: String
        do {
            svgMarkup = try String(contentsOf: inputURL, encoding: .utf8)
        } catch {
            fputs("failed to read SVG: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        let html = """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            <style>
              html, body {
                margin: 0;
                width: 100%;
                height: 100%;
                background: transparent;
                overflow: hidden;
              }
              body {
                display: flex;
                align-items: stretch;
                justify-content: stretch;
              }
              svg {
                width: 100%;
                height: 100%;
                display: block;
              }
            </style>
          </head>
          <body>
            \(svgMarkup)
          </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: width, height: height)

        webView.takeSnapshot(with: configuration) { image, error in
            if let error {
                fputs("snapshot failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            }

            guard
                let image,
                let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff),
                let png = bitmap.representation(using: .png, properties: [:])
            else {
                fputs("failed to encode PNG\n", stderr)
                exit(1)
            }

            do {
                try FileManager.default.createDirectory(
                    at: self.outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try png.write(to: self.outputURL)
                exit(0)
            } catch {
                fputs("write failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fputs("navigation failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fputs("provisional navigation failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

func parseArguments() -> (URL, URL, Int, Int)? {
    let arguments = CommandLine.arguments
    guard arguments.count == 5 else {
        fputs("usage: render_svg.swift <input.svg> <output.png> <width> <height>\n", stderr)
        return nil
    }

    guard
        let width = Int(arguments[3]),
        let height = Int(arguments[4])
    else {
        fputs("width and height must be integers\n", stderr)
        return nil
    }

    return (
        URL(fileURLWithPath: arguments[1]),
        URL(fileURLWithPath: arguments[2]),
        width,
        height
    )
}

guard let (inputURL, outputURL, width, height) = parseArguments() else {
    exit(2)
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let renderer = SVGRenderer(inputURL: inputURL, outputURL: outputURL, width: width, height: height)
renderer.start()
RunLoop.main.run()
