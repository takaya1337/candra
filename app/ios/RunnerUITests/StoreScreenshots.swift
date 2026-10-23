import ImageIO
import XCTest

/// The App Store's screenshots, taken on the device itself.
///
/// Runs against a build made with `--dart-define=SHOTS=en` (or `id`),
/// which walks its own short sequence of screens (`app/lib/shots.dart`).
/// On each, once still, the app puts an invisible element in the
/// accessibility tree named `shot-ready-NN-name`; this test waits for it,
/// takes the screen as the device shows it (status bar, the glass bar
/// and all), and keeps it in the result bundle under that name.
/// `shot-done` ends the walk. Run by `app/tool/store_screenshots.sh`.
final class StoreScreenshots: XCTestCase {
  override func setUp() {
    continueAfterFailure = true
  }

  func testStoreScreenshots() throws {
    let device = XCUIDevice.shared
    // The iPad is pictured on its side, the iPhone upright.
    device.orientation =
      UIDevice.current.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait

    // A system question left on screen by an earlier build (the local
    // network prompt of a Profile build nobody answered) stays over
    // every app until it is answered, and would be in every picture.
    dismissSystemAlerts()

    let app = XCUIApplication()
    app.launch()
    dismissSystemAlerts()

    let ready = NSPredicate(
      format: "identifier BEGINSWITH 'shot-' OR label BEGINSWITH 'shot-'")
    let markers = app.descendants(matching: .any).matching(ready)
    var taken: [String] = []
    let deadline = Date().addingTimeInterval(600)

    while Date() < deadline {
      let marker = markers.firstMatch
      guard marker.waitForExistence(timeout: 60) else {
        XCTFail("No marker for a minute after \(taken.last ?? "launch")")
        break
      }
      let name = marker.identifier.isEmpty ? marker.label : marker.identifier
      if name == "shot-done" { break }
      let shot = String(name.dropFirst("shot-ready-".count))
      if name.hasPrefix("shot-ready-"), !taken.contains(shot) {
        let screenshot = XCUIScreen.main.screenshot()
        // Still there after the picture, so the screen was still while
        // it was taken; the app takes it down before it moves on.
        let same = app.descendants(matching: .any).matching(
          NSPredicate(format: "identifier == %@ OR label == %@", name, name)
        ).firstMatch
        if same.exists {
          let attachment = XCTAttachment(
            data: upright(screenshot.image), uniformTypeIdentifier: "public.png")
          attachment.name = shot
          attachment.lifetime = .keepAlways
          add(attachment)
          taken.append(shot)
        } else {
          XCTFail("\(shot) went before it could be taken")
          taken.append(shot)
        }
      }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTAssertFalse(taken.isEmpty, "No screenshots were taken")
    print("Store screenshots taken: \(taken)")
  }

  /// Pictures of the layout for the desk, not the store: run against a
  /// build made with `--dart-define=LOOK=1` (`app/lib/look.dart`), which
  /// writes and saves nothing. Only with `TEST_RUNNER_CANDRA_LOOK=1`
  /// (portrait) or `=landscape` given to `xcodebuild test`, and only
  /// this test (`-only-testing:RunnerUITests/StoreScreenshots/testLook`).
  /// `shot-ready-NAME` is one picture; `shot-burst-NAME` is pictures as
  /// fast as they come, NAME-b00, -b01..., for as long as it stands.
  func testLook() throws {
    let look = ProcessInfo.processInfo.environment["CANDRA_LOOK"] ?? ""
    try XCTSkipIf(look.isEmpty, "Only for a LOOK build")
    // The device's free room, in the log: the iPad runs close to full.
    if let free = try? URL(fileURLWithPath: NSHomeDirectory())
      .resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity
    {
      print("candra-look: \(free / 1_000_000) MB free on the device")
    }
    XCUIDevice.shared.orientation = look == "landscape" ? .landscapeLeft : .portrait
    dismissSystemAlerts()
    let app = XCUIApplication()
    app.launch()
    dismissSystemAlerts()

    let ready = NSPredicate(
      format: "identifier BEGINSWITH 'shot-' OR label BEGINSWITH 'shot-'")
    let markers = app.descendants(matching: .any).matching(ready)
    var taken: [String] = []
    let deadline = Date().addingTimeInterval(900)
    func keep(_ image: UIImage, _ name: String) {
      let attachment = XCTAttachment(
        data: upright(image), uniformTypeIdentifier: "public.png")
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }
    while Date() < deadline {
      let marker = markers.firstMatch
      guard marker.waitForExistence(timeout: 90) else {
        XCTFail("No marker for 90 s after \(taken.last ?? "launch")")
        break
      }
      let name = marker.identifier.isEmpty ? marker.label : marker.identifier
      if name == "shot-done" { break }
      if name.hasPrefix("shot-ready-") {
        let shot = String(name.dropFirst("shot-ready-".count))
        if !taken.contains(shot) {
          keep(XCUIScreen.main.screenshot().image, shot)
          taken.append(shot)
        }
      } else if name.hasPrefix("shot-burst-") {
        let shot = String(name.dropFirst("shot-burst-".count))
        if !taken.contains(shot) {
          taken.append(shot)
          // Taken first, kept after, so the camera is as quick as it can
          // be while the screen moves.
          var images: [UIImage] = []
          let same = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ OR label == %@", name, name)
          ).firstMatch
          let ends = Date().addingTimeInterval(8)
          var checked = Date()
          // At most 24, so the runner is not stopped for its memory.
          while Date() < ends && images.count < 24 {
            images.append(XCUIScreen.main.screenshot().image)
            if Date().timeIntervalSince(checked) > 1.5 {
              checked = Date()
              if !same.exists { break }
            }
          }
          for (i, image) in images.enumerated() {
            keep(image, String(format: "%@-b%02d", shot, i))
          }
        }
      }
      Thread.sleep(forTimeInterval: 0.3)
    }
    print("Look pictures taken: \(taken)")
  }

  /// The picture turned the way it is seen, as plain opaque pixels: a
  /// screenshot on its side comes as the upright pixels and a note of
  /// how to turn them, which not every tool reads, and Apple refuses an
  /// alpha channel.
  private func upright(_ image: UIImage) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    format.opaque = true
    let turned = UIGraphicsImageRenderer(size: image.size, format: format)
      .image { _ in image.draw(at: .zero) }.cgImage!
    let context = CGContext(
      data: nil, width: turned.width, height: turned.height,
      bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(turned, in: CGRect(x: 0, y: 0, width: turned.width, height: turned.height))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
      data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
  }

  /// Answers "no" to any question the system has up (Springboard's
  /// alerts), so that none is in a picture.
  private func dismissSystemAlerts() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    for _ in 0..<3 {
      let alert = springboard.alerts.firstMatch
      guard alert.waitForExistence(timeout: 2) else { return }
      let no = ["Don\u{2019}t Allow", "Don't Allow", "Not Now", "Cancel"]
        .map { alert.buttons[$0] }
        .first { $0.exists }
      (no ?? alert.buttons.firstMatch).tap()
    }
  }
}
