import ActivityKit
import CoreLocation
import Flutter
import Photos
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import WidgetKit
import workmanager_apple

// The iOS side of the four channels the Dart code speaks to. Each does
// what MainActivity.kt does on Android, by the same method names and with
// the same answers, so nothing in Dart has to know which phone it is on.
//
// Compiles and runs (Xcode 26.6, iOS 26.6, 13 October 2026). Of the four
// channels only `candra/clock` has been exercised on a phone; location,
// files and the gallery put up system screens and have yet to be tried.

/// The phone's heading from magnetic north, in degrees, from the
/// location manager's compass (which needs no permission), with its error
/// in degrees as the phone reckons it.
final class HeadingStream: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CLLocationManager.headingAvailable() else {
      return FlutterError(code: "none", message: "no compass", details: nil)
    }
    sink = events
    manager.delegate = self
    manager.headingFilter = 1
    manager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    sink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    sink?(["heading": newHeading.magneticHeading, "accuracy": newHeading.headingAccuracy])
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  CLLocationManagerDelegate, UIDocumentPickerDelegate
{
  private let heading = HeadingStream()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets a reminder show while the app is open.
    UNUserNotificationCenter.current().delegate = self
    keepOutOfBackups()
    // The reminders' coming days handed over again in the background
    // (app/lib/reminders/rearm.dart). iOS wants the task named here,
    // before launching ends, or it stops the app when Dart first asks for
    // it; and the engine it runs in needs the plugins.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.suryamajapahit.candra.rearm",
      earliestBeginInSeconds: NSNumber(value: 12 * 60 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    // The zone the phone's clock is set to, by its tz database name.
    FlutterMethodChannel(name: "candra/clock", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        if call.method == "zone" {
          result(TimeZone.current.identifier)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

    // The app's own version, and handing a link or an address to
    // whatever on the phone opens it.
    FlutterMethodChannel(name: "candra/app", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "version":
          let info = Bundle.main.infoDictionary
          let name = info?["CFBundleShortVersionString"] as? String ?? ""
          let build = info?["CFBundleVersion"] as? String ?? ""
          result("\(name)+\(build)")
        case "open":
          guard let arguments = call.arguments as? [String: Any],
            let text = arguments["url"] as? String,
            let url = URL(string: text)
          else {
            result(false)
            return
          }
          UIApplication.shared.open(url) { opened in result(opened) }
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    // The Dynamic Island: a practice under way.
    let island = FlutterMethodChannel(name: "candra/island", binaryMessenger: messenger)
    AppDelegate.island = island
    island.setMethodCallHandler { call, result in
        // Whether it was a tap on the island that opened the app.
        if call.method == "launched" {
          result(AppDelegate.launchedByIsland)
          AppDelegate.launchedByIsland = false
          return
        }
        guard #available(iOS 16.2, *) else {
          result(FlutterMethodNotImplemented)
          return
        }
        switch call.method {
        case "show":
          Island.show(call.arguments as? [String: Any] ?? [:], result: result)
        case "end":
          Island.end(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    // The coming days as every calendar reads them, left where the
    // widgets can find them.
    FlutterMethodChannel(name: "candra/widgets", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "publish",
          let arguments = call.arguments as? [String: Any],
          let days = arguments["days"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        UserDefaults(suiteName: CandraShared.group)?.set(days, forKey: CandraShared.daysKey)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      }

    // The system's own glass, for the app to lay its bars on.
    engineBridge.pluginRegistry.registrar(forPlugin: "CandraGlass")?
      .register(GlassFactory(), withId: "candra/glass")

    // The bottom bar itself: one bar for the whole app, the phone's own
    // buttons in one capsule of glass, standing over the app. The app
    // sends its glyphs across once, as pictures to tint, and after that
    // only what the bar should hold.
    let bar = FlutterMethodChannel(name: "candra/bar", binaryMessenger: messenger)
    BarOverlay.shared.channel = bar
    bar.setMethodCallHandler { call, result in
      switch call.method {
      case "images":
        if let images = call.arguments as? [String: FlutterStandardTypedData] {
          for (name, bytes) in images {
            // Drawn 72 or 96 pixels square, shown 20 or 26 points.
            let scale: CGFloat = name.hasPrefix("system-") ? 96.0 / 26.0 : 72.0 / 20.0
            BarOverlay.images[name] = UIImage(data: bytes.data, scale: scale)?
              .withRenderingMode(.alwaysTemplate)
          }
          // Buttons made before the pictures came are given them now.
          BarOverlay.shared.forget()
        }
        result(nil)
      case "show":
        if let text = call.arguments as? String { BarOverlay.shared.show(text) }
        result(nil)
      case "hide":
        BarOverlay.shared.hide()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterMethodChannel(name: "candra/gallery", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "savePng",
          let arguments = call.arguments as? [String: Any],
          let bytes = arguments["bytes"] as? FlutterStandardTypedData
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.savePng(bytes.data, result: result)
      }

    FlutterMethodChannel(name: "candra/files", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "share":
          self?.share(path: arguments["path"] as? String ?? "", result: result)
        case "saveAs":
          self?.saveAs(
            path: arguments["path"] as? String ?? "",
            name: arguments["name"] as? String ?? "candra.zip",
            result: result)
        case "pick":
          self?.pick(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    // Where the top of the phone points, from magnetic north, while
    // Light's compass is on.
    FlutterEventChannel(name: "candra/heading", binaryMessenger: messenger)
      .setStreamHandler(heading)

    FlutterMethodChannel(name: "candra/location", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "current":
          self?.current(result: result)
        case "allowed":
          // Whether the app may already read where the phone is: asks
          // nothing.
          let status = self?.locator.authorizationStatus
          result(status == .authorizedWhenInUse || status == .authorizedAlways)
        case "cancel":
          self?.located(nil, problem: "cancelled")
          result(nil)
        case "open":
          self?.openInMaps(
            latitude: arguments["latitude"] as? Double ?? 0,
            longitude: arguments["longitude"] as? Double ?? 0,
            label: arguments["label"] as? String ?? "",
            result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  // For the scene, which is where a tap on the island arrives.
  static var island: FlutterMethodChannel?
  static var launchedByIsland = false

  static func islandTapped() {
    if let island = island {
      island.invokeMethod("opened", arguments: nil)
    } else {
      // The app is only now starting: Dart asks once it is up.
      launchedByIsland = true
    }
  }

  // The journal, the reminders and everything else the app keeps are
  // left out of iCloud and computer backups: what is written stays on
  // the phone unless the user sends it somewhere. (Flutter's
  // getApplicationSupportDirectory is this folder.)
  private func keepOutOfBackups() {
    guard
      var folder = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
    else { return }
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? folder.setResourceValues(values)
  }

  // The screen to put a system sheet over.
  private var presenter: UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let above = top?.presentedViewController { top = above }
    return top
  }

  // MARK: The gallery

  // Adds the picture to the photo library. Only the right to add is asked
  // for, never the right to read what is there.
  private func savePng(_ data: Data, result: @escaping FlutterResult) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async {
          result(FlutterError(code: "denied", message: "Photos not allowed", details: nil))
        }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
      }) { saved, error in
        DispatchQueue.main.async {
          if saved {
            result(nil)
          } else {
            result(FlutterError(code: "io", message: error?.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  // MARK: Files

  // The answer owed to Dart while the system's file screen is up, and
  // whether that screen is choosing a file to bring in.
  private var waiting: FlutterResult?
  private var picking = false

  // Hands a file in the exports folder to whichever app the user picks.
  private func share(path: String, result: @escaping FlutterResult) {
    let sheet = UIActivityViewController(
      activityItems: [URL(fileURLWithPath: path)], applicationActivities: nil)
    // An iPad wants to know where the sheet springs from.
    if let view = presenter?.view {
      sheet.popoverPresentationController?.sourceView = view
      sheet.popoverPresentationController?.sourceRect = CGRect(
        x: view.bounds.midX, y: view.bounds.maxY - 80, width: 1, height: 1)
    }
    presenter?.present(sheet, animated: true)
    result(nil)
  }

  // Lets the user choose where a copy goes, through the system's own file
  // screen.
  private func saveAs(path: String, name: String, result: @escaping FlutterResult) {
    guard waiting == nil else {
      result(FlutterError(code: "busy", message: "Another file screen is open", details: nil))
      return
    }
    // The file screen saves under the file's own name: give it the one
    // wanted first.
    let named = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    do {
      try? FileManager.default.removeItem(at: named)
      try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: named)
    } catch {
      result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
      return
    }
    waiting = result
    picking = false
    let screen = UIDocumentPickerViewController(forExporting: [named], asCopy: true)
    screen.delegate = self
    presenter?.present(screen, animated: true)
  }

  // Lets the user choose a file to import; it is copied into the app's
  // cache and the copy's path given back.
  private func pick(result: @escaping FlutterResult) {
    guard waiting == nil else {
      result(FlutterError(code: "busy", message: "Another file screen is open", details: nil))
      return
    }
    waiting = result
    picking = true
    let screen = UIDocumentPickerViewController(
      forOpeningContentTypes: [.zip, .data], asCopy: true)
    screen.delegate = self
    presenter?.present(screen, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
  ) {
    guard let result = waiting else { return }
    waiting = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    if !picking {
      result(true)
      return
    }
    do {
      let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("imports")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let copy = folder.appendingPathComponent("picked.zip")
      try? FileManager.default.removeItem(at: copy)
      try FileManager.default.copyItem(at: url, to: copy)
      result(copy.path)
    } catch {
      result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
    }
  }

  // Backed out of: not an error.
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    waiting?(nil)
    waiting = nil
  }

  // MARK: Location

  // The answer owed to Dart while the phone is being asked where it is.
  private var locating: FlutterResult?
  private var giveUp: Timer?
  private lazy var locator: CLLocationManager = {
    let manager = CLLocationManager()
    manager.delegate = self
    // The app rounds the answer to about a hundred metres itself.
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    return manager
  }()

  // A fix from cold can take most of a minute.
  private static let locateFor: TimeInterval = 45

  // Where the phone is now. Only ever called when the user presses for
  // it; the permission is asked for then, the first time.
  private func current(result: @escaping FlutterResult) {
    guard locating == nil else {
      result(FlutterError(code: "unavailable", message: "Already looking", details: nil))
      return
    }
    locating = result
    switch locator.authorizationStatus {
    case .notDetermined:
      // The answer comes to locationManagerDidChangeAuthorization.
      locator.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      locate()
    default:
      located(nil, problem: "denied")
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard locating != nil, giveUp == nil else { return }
    switch manager.authorizationStatus {
    case .notDetermined:
      break
    case .authorizedWhenInUse, .authorizedAlways:
      locate()
    default:
      located(nil, problem: "denied")
    }
  }

  private func locate() {
    giveUp = Timer.scheduledTimer(withTimeInterval: AppDelegate.locateFor, repeats: false) {
      [weak self] _ in
      // Settle for the last place the phone knew, if it is recent.
      if let last = self?.locator.location, last.timestamp.timeIntervalSinceNow > -600 {
        self?.located(last, problem: nil)
      } else {
        self?.located(nil, problem: "timeout")
      }
    }
    locator.requestLocation()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    located(locations.last, problem: nil)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    let code = (error as? CLError)?.code
    if code == .locationUnknown { return }  // Still trying.
    located(nil, problem: code == .denied ? "off" : "unavailable")
  }

  private func located(_ location: CLLocation?, problem: String?) {
    guard let result = locating else { return }
    locating = nil
    giveUp?.invalidate()
    giveUp = nil
    locator.stopUpdatingLocation()
    if let location = location {
      result([
        "latitude": location.coordinate.latitude,
        "longitude": location.coordinate.longitude,
        "accuracy": location.horizontalAccuracy,
      ])
    } else {
      result(FlutterError(code: problem ?? "unavailable", message: nil, details: nil))
    }
  }

  // Hands a place to Apple Maps.
  private func openInMaps(
    latitude: Double, longitude: Double, label: String, result: @escaping FlutterResult
  ) {
    var link = URLComponents(string: "https://maps.apple.com/")!
    link.queryItems = [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)")]
    if !label.isEmpty {
      link.queryItems?.append(URLQueryItem(name: "q", value: label))
    }
    guard let url = link.url else {
      result(false)
      return
    }
    UIApplication.shared.open(url) { opened in result(opened) }
  }
}

// MARK: The Dynamic Island

// Starts, changes and ends the one Live Activity. iOS only lets an app
// start one while it is in front, and ends it by itself after eight
// hours; the figures in it turn without the app.
@available(iOS 16.2, *)
enum Island {
  private static func state(_ map: [String: Any]) -> CandraActivityAttributes.ContentState {
    func date(_ key: String) -> Date? {
      (map[key] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
    }
    return CandraActivityAttributes.ContentState(
      title: map["title"] as? String ?? "",
      detail: map["detail"] as? String ?? "",
      color: (map["color"] as? NSNumber)?.intValue ?? 0xFFFF_FFFF,
      start: date("start") ?? Date(),
      end: date("end"))
  }

  static func show(_ map: [String: Any], result: @escaping FlutterResult) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(FlutterError(code: "off", message: "Live Activities are switched off", details: nil))
      return
    }
    let next = state(map)
    // Stale once a countdown has run out, should the app not be opened.
    let content = ActivityContent(state: next, staleDate: next.end)
    Task {
      if let running = Activity<CandraActivityAttributes>.activities.first {
        if running.content.state != next {
          await running.update(content)
        }
        result(nil)
        return
      }
      do {
        _ = try Activity.request(
          attributes: CandraActivityAttributes(), content: content, pushType: nil)
        result(nil)
      } catch {
        result(FlutterError(code: "refused", message: error.localizedDescription, details: nil))
      }
    }
  }

  static func end(result: @escaping FlutterResult) {
    Task {
      for running in Activity<CandraActivityAttributes>.activities {
        await running.end(nil, dismissalPolicy: .immediate)
      }
      result(nil)
    }
  }
}

// MARK: Glass

// A capsule of the system's glass, which bends and blurs whatever of the
// app is behind it. On a phone older than iOS 26 it is the system's
// thin dark blur instead.
final class GlassFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassView(frame: frame)
  }
}

final class GlassView: NSObject, FlutterPlatformView {
  private let glass: UIVisualEffectView

  init(frame: CGRect) {
    if #available(iOS 26.0, *) {
      // The system's glass, shaped by the system: a capsule. It is not
      // clipped or rounded through its layer, which is how a blur was
      // shaped before and which glass does not survive.
      let effect = UIGlassEffect()
      glass = UIVisualEffectView(effect: effect)
      glass.cornerConfiguration = .capsule()
    } else {
      let blur = Capsule(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
      blur.clipsToBounds = true
      blur.layer.cornerCurve = .continuous
      glass = blur
    }
    glass.frame = frame
    glass.isUserInteractionEnabled = false
    super.init()
  }

  func view() -> UIView { glass }
}

// Before iOS 26: a blur, rounded at both ends whatever size it is given.
final class Capsule: UIVisualEffectView {
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
  }
}

// MARK: The bottom bar

// The app's bottom bar as the phone's own: one capsule of the system's
// glass standing over the app, holding a real button for every button
// the screen in front lays out, each in the same place. It is made once.
// From screen to screen only its buttons change, each fading in or out;
// a button that stays (the way back, today) does not so much as flicker.
// Taps and holds go back to the app, which still decides what they do.
final class BarOverlay: NSObject {
  static let shared = BarOverlay()
  static var images: [String: UIImage] = [:]

  var channel: FlutterMethodChannel?

  private struct Reading: Decodable {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    // The top of the highest button as the row lays it out, before any
    // button is drawn moved (rising in, growing): where the glass stands.
    let top: CGFloat?
    // How many times the phone's bar is drawn larger: on an iPad upright,
    // the phone's bar scaled as the app's lower panel is; every place and
    // size above is already as drawn, and the glass's margins, the
    // glyphs, the words, the dot and the lens are scaled by it here.
    let scale: CGFloat?
    let items: [Item]
  }

  private struct Item: Decodable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let image: String?
    let title: String?
    let tint: UInt32
    let ink: UInt32
    let dot: UInt32
    let prominent: Bool
    let alpha: CGFloat
    let enabled: Bool
    let marked: Bool
    // The room the house is in: lit from behind, by the highlight.
    let selected: Bool?
    let hold: Bool
  }

  private var capsule: UIVisualEffectView?
  // The highlight behind the button of the room the house is in: it stays
  // while the house is there, and glides to the next room's button as
  // the house goes there, as the system's own tab bars light theirs.
  private var highlight: UIView?
  private var buttons: [String: UIButton] = [:]
  private var shown: [String: String] = [:]
  // The scale the bar is drawn at now (see Reading.scale), and the
  // glyphs drawn at it.
  private var scale: CGFloat = 1
  private var scaledImages: [String: UIImage] = [:]

  // A glyph at the bar's scale: the same picture, fewer pixels to a
  // point, so it shows that many times larger.
  private func image(_ name: String) -> UIImage? {
    guard let base = BarOverlay.images[name] else { return nil }
    if scale == 1 { return base }
    if let made = scaledImages[name] { return made }
    guard let picture = base.cgImage else { return base }
    let made = UIImage(cgImage: picture, scale: base.scale / scale, orientation: .up)
      .withRenderingMode(.alwaysTemplate)
    scaledImages[name] = made
    return made
  }

  // From iOS 26, the bar's glass stands in a glass container with a
  // second, smaller glass: the lens, which comes up under a finger
  // pressed on the bar and follows it from button to button, as the
  // system's own tab bars do, and goes where it is let go. The container
  // is a little larger than the bar, so the lens can stand out of it; it
  // lets every touch outside the bar through to the app.
  private var container: UIVisualEffectView?
  private var lens: UIVisualEffectView?
  private var drag: UIPanGestureRecognizer?
  private static let room: CGFloat = 14
  // The button a finger is down on, before any drag; whether a drag is
  // under way; the button the lens stands over; whether it is up.
  private weak var pressing: UIButton?
  private var dragging = false
  private weak var under: UIButton?
  private var lensUp = false
  private let tick = UISelectionFeedbackGenerator()

  // What fades when the bar comes and goes.
  private var outer: UIView? { container ?? capsule }

  private static func color(_ argb: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255, alpha: CGFloat((argb >> 24) & 0xFF) / 255)
  }

  // The app's own view, which the bar stands over.
  private var host: UIView? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController?.view
  }

  private func glass() -> UIVisualEffectView? {
    if let capsule = capsule { return capsule }
    guard let host = host else { return nil }
    let made: UIVisualEffectView
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect()
      // The glass answers the finger, as the system's own bars do.
      effect.isInteractive = true
      made = UIVisualEffectView(effect: effect)
      made.cornerConfiguration = .capsule()
      let around = PassThroughEffectView(effect: UIGlassContainerEffect())
      // The lens has no effect until it is wanted: glass comes and goes
      // by its effect being set and taken away, which the system
      // animates as glass forming and melting.
      let lens = UIVisualEffectView(effect: nil)
      lens.cornerConfiguration = .capsule()
      lens.isUserInteractionEnabled = false
      // The bar first and the lens over it, as the system's own lens
      // floats over its bar: the buttons under it show through, swelled
      // by its glass. It takes no touches, so the bar still has them all.
      around.contentView.addSubview(made)
      around.contentView.addSubview(lens)
      let drag = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
      drag.maximumNumberOfTouches = 1
      made.addGestureRecognizer(drag)
      around.alpha = 0
      host.addSubview(around)
      container = around
      self.lens = lens
      self.drag = drag
    } else {
      made = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
      made.clipsToBounds = true
      made.alpha = 0
      host.addSubview(made)
    }
    capsule = made
    return made
  }

  // Has every button's face set again the next time the bar is shown.
  func forget() {
    shown = [:]
    scaledImages = [:]
  }

  func hide() {
    guard let capsule = capsule, let outer = outer else { return }
    // A drag under way ends with nothing chosen.
    if dragging, let drag = drag {
      drag.isEnabled = false
      drag.isEnabled = true
    }
    pressing = nil
    lensDown()
    UIView.animate(withDuration: 0.15) { outer.alpha = 0 }
    capsule.isUserInteractionEnabled = false
  }

  func show(_ text: String) {
    guard let data = text.data(using: .utf8),
      let reading = try? JSONDecoder().decode(Reading.self, from: data),
      let capsule = glass()
    else { return }

    // The glass stands where the buttons are laid out, not where they
    // are drawn: a button rising into the bar as the others fade (the
    // pickers' tick, the utilities' way back) rises inside a glass that
    // holds still, rather than taking the glass down with it.
    guard let top = reading.top ?? reading.items.map({ $0.y }).min(),
      let tall = reading.items.map({ $0.h }).max()
    else {
      hide()
      return
    }
    // A new scale (the iPad turned): every face is set again at it.
    let s = max(reading.scale ?? 1, 0.1)
    if s != scale {
      scale = s
      scaledImages = [:]
      shown = [:]
    }
    // One capsule the width of the bar, whatever it holds, and as tall
    // as its buttons with a little room: not as tall as the bar's place,
    // which reaches down behind the keyboard when that is up. Scaled, the
    // phone's capsule scaled: its margins too.
    let origin = CGPoint(x: reading.x + 10 * s, y: reading.y + top - 6 * s)
    let frame = CGRect(
      x: origin.x, y: origin.y, width: reading.w - 20 * s, height: tall + 12 * s)
    if let container = container {
      let room = BarOverlay.room * s
      container.frame = frame.insetBy(dx: -room, dy: -room)
      capsule.frame = CGRect(x: room, y: room, width: frame.width, height: frame.height)
    } else {
      capsule.frame = frame
    }
    if #unavailable(iOS 26.0) { capsule.layer.cornerRadius = frame.height / 2 }
    capsule.isUserInteractionEnabled = true
    if let outer = outer, outer.alpha < 1 { UIView.animate(withDuration: 0.2) { outer.alpha = 1 } }

    var kept = Set<String>()
    for item in reading.items {
      kept.insert(item.id)
      let face = item.image ?? item.title ?? ""
      let button: UIButton
      if let old = buttons[item.id] {
        button = old
      } else {
        button = UIButton(type: .system)
        button.accessibilityIdentifier = item.id
        button.alpha = 0
        button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        press.minimumPressDuration = 0.6
        button.addGestureRecognizer(press)
        if container != nil {
          button.addTarget(self, action: #selector(pressed(_:)), for: .touchDown)
          button.addTarget(
            self, action: #selector(released(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        // A dot at its corner, for a button that is marked.
        let dot = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 5))
        dot.layer.cornerRadius = 2.5
        dot.isUserInteractionEnabled = false
        dot.tag = 77
        button.addSubview(dot)
        capsule.contentView.addSubview(button)
        buttons[item.id] = button
      }
      // Its picture or its words, changed with a short fade when they
      // change: the system's glyph, when the system does.
      if shown[item.id] != face {
        let fresh = shown[item.id] == nil
        shown[item.id] = face
        let change = {
          if let name = item.image {
            button.setTitle(nil, for: .normal)
            button.setImage(self.image(name), for: .normal)
          } else {
            button.setImage(nil, for: .normal)
            button.setTitle(item.title, for: .normal)
            button.titleLabel?.font = .monospacedSystemFont(ofSize: 14 * s, weight: .medium)
          }
        }
        if fresh {
          change()
        } else {
          UIView.transition(
            with: button, duration: 0.2, options: .transitionCrossDissolve, animations: change)
        }
      }
      // By its size and centre, not its frame: the lens may have it
      // drawn a little larger.
      button.bounds = CGRect(x: 0, y: 0, width: item.w, height: item.h)
      button.center = CGPoint(
        x: item.x - 10 * s + item.w / 2, y: item.y - top + 6 * s + item.h / 2)
      // The one a screen is for: filled with the accent, its glyph dark.
      button.backgroundColor = item.prominent ? BarOverlay.color(item.tint) : .clear
      button.layer.cornerRadius = item.prominent ? item.h / 2 : 0
      button.tintColor = BarOverlay.color(item.prominent ? item.ink : item.tint)
      button.setTitleColor(button.tintColor, for: .normal)
      button.isEnabled = item.enabled
      button.gestureRecognizers?.forEach { $0.isEnabled = item.hold }
      let alpha = item.alpha * (item.enabled ? 1 : 0.3)
      if abs(button.alpha - alpha) > 0.5 {
        UIView.animate(withDuration: 0.2) { button.alpha = alpha }
      } else {
        button.alpha = alpha
      }
      // The glyph's filled form, laid over it unseen: the lens fills it
      // as it comes over the button (see fill(near:)).
      let solid = item.selected == true ? nil : item.image.flatMap { self.image("\($0)-solid") }
      var fillView = button.viewWithTag(88) as? UIImageView
      if let solid = solid {
        if fillView == nil {
          let made = UIImageView()
          made.tag = 88
          made.isUserInteractionEnabled = false
          made.contentMode = .center
          made.alpha = 0
          button.addSubview(made)
          fillView = made
        }
        fillView?.image = solid
        fillView?.tintColor = button.tintColor
        fillView?.frame = button.bounds
      } else {
        fillView?.removeFromSuperview()
      }
      if let dot = button.viewWithTag(77) {
        dot.isHidden = !item.marked
        dot.backgroundColor = BarOverlay.color(item.dot)
        dot.bounds = CGRect(x: 0, y: 0, width: 5 * s, height: 5 * s)
        dot.layer.cornerRadius = 2.5 * s
        dot.center = CGPoint(x: item.w - 8 * s, y: 8 * s)
      }
    }
    // The highlight, behind the room's button.
    let here = reading.items.first { $0.selected == true }
    let lit: UIView
    if let made = highlight {
      lit = made
    } else {
      lit = UIView()
      lit.isUserInteractionEnabled = false
      lit.backgroundColor = UIColor.white.withAlphaComponent(0.14)
      lit.alpha = 0
      capsule.contentView.insertSubview(lit, at: 0)
      highlight = lit
    }
    if let here = here, let button = buttons[here.id] {
      let size = CGSize(width: here.w + 8 * s, height: here.h + 4 * s)
      let target = CGRect(
        x: button.center.x - size.width / 2, y: button.center.y - size.height / 2,
        width: size.width, height: size.height)
      if lit.alpha < 0.5 {
        lit.frame = target
        lit.layer.cornerRadius = size.height / 2
        UIView.animate(withDuration: 0.2) { lit.alpha = 1 }
      } else if lit.frame != target {
        UIView.animate(
          withDuration: still ? 0.2 : 0.45, delay: 0,
          usingSpringWithDamping: still ? 1 : 0.8, initialSpringVelocity: 0,
          options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
          lit.frame = target
          lit.layer.cornerRadius = size.height / 2
        }
      }
    } else if lit.alpha > 0 {
      UIView.animate(withDuration: 0.2) { lit.alpha = 0 }
    }

    // What the screen in front does not have goes.
    for (id, button) in buttons where !kept.contains(id) {
      buttons[id] = nil
      shown[id] = nil
      UIView.animate(
        withDuration: 0.15, animations: { button.alpha = 0 },
        completion: { _ in button.removeFromSuperview() })
    }
    // The lens keeps to its button as the bar changes under it, and goes
    // with it.
    if lensUp {
      if let under = under, buttons.values.contains(under) {
        place(over: under, at: nil)
      } else {
        lensDown()
      }
    }
  }

  @objc private func tapped(_ sender: UIButton) {
    channel?.invokeMethod("tap", arguments: sender.accessibilityIdentifier)
  }

  @objc private func held(_ press: UILongPressGestureRecognizer) {
    guard press.state == .began, let button = press.view as? UIButton else { return }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    pressing = nil
    lensDown()
    channel?.invokeMethod("hold", arguments: button.accessibilityIdentifier)
  }

  // MARK: The lens (iOS 26)

  // A finger down on a button: the lens comes up under it if it stays
  // down a moment, so that a plain tap never flashes it (the app's own
  // holds wait as long before they show).
  @objc private func pressed(_ button: UIButton) {
    pressing = button
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self, weak button] in
      guard let self = self, let button = button, self.pressing === button, !self.dragging,
        button.isTracking
      else { return }
      self.place(over: button, at: nil)
    }
  }

  // The finger up, or the touch taken over by a drag: the drag says so
  // itself before this is looked at.
  @objc private func released(_ button: UIButton) {
    if pressing === button { pressing = nil }
    DispatchQueue.main.async { [weak self] in
      guard let self = self, !self.dragging, self.pressing == nil else { return }
      self.lensDown()
    }
  }

  // A finger drawn along the bar. It takes over from the button it went
  // down on once it has moved (about ten points), so taps and holds are
  // as before; the lens follows it and lights the button under it, with a
  // tick for each new one, and letting go on the bar is a tap on that
  // button. Let go off the bar, nothing is chosen.
  @objc private func dragged(_ drag: UIPanGestureRecognizer) {
    guard let container = container, let capsule = capsule else { return }
    let finger = drag.location(in: container.contentView)
    let onBar = capsule.frame.insetBy(dx: -6 * scale, dy: -44).contains(finger)
    let choice = onBar ? nearest(to: finger.x) : nil
    switch drag.state {
    case .began, .changed:
      if drag.state == .began {
        dragging = true
        pressing = nil
        tick.prepare()
      }
      if let choice = choice {
        if let under = under, under !== choice {
          tick.selectionChanged()
          tick.prepare()
        }
        place(over: choice, at: finger.x)
      } else if lensUp {
        lensDown()
      }
    case .ended:
      dragging = false
      if let choice = choice {
        place(over: choice, at: nil)
        lensDown(settling: true)
        tapped(choice)
      } else {
        lensDown()
      }
    default:
      dragging = false
      lensDown()
    }
  }

  // The button nearest a point along the bar, of those that can be
  // pressed.
  private func nearest(to x: CGFloat) -> UIButton? {
    guard let capsule = capsule else { return nil }
    return buttons.values
      .filter { $0.isEnabled && $0.alpha > 0.05 && $0.superview != nil }
      .min { abs($0.center.x + capsule.frame.minX - x) < abs($1.center.x + capsule.frame.minX - x) }
  }

  private var still: Bool { UIAccessibility.isReduceMotionEnabled }

  // Where the lens stands over a button, in the container: a little wider
  // than the button and, pressed, a little taller than the bar, so it
  // stands out of it as a drop of glass; under Reduce Motion it keeps
  // inside the bar and does not grow. Following a finger, it is centred
  // on the finger, kept to the bar.
  private func lensFrame(over button: UIButton, at x: CGFloat?) -> CGRect {
    guard let capsule = capsule else { return .zero }
    let bar = capsule.frame
    let s = scale
    let height = still ? bar.height - 8 * s : bar.height + 10 * s
    let width = max(button.bounds.width + (still ? 12 : 30) * s, height * 1.2)
    let spill: CGFloat = (still ? -4 : 5) * s
    let centre = min(
      max(x ?? (bar.minX + button.center.x), bar.minX - spill + width / 2),
      bar.maxX + spill - width / 2)
    return CGRect(x: centre - width / 2, y: bar.midY - height / 2, width: width, height: height)
  }

  private func place(over button: UIButton, at x: CGFloat?) {
    guard #available(iOS 26.0, *), let lens = lens else { return }
    let target = lensFrame(over: button, at: x)
    let options: UIView.AnimationOptions = [.allowUserInteraction, .beginFromCurrentState]
    if !lensUp {
      lensUp = true
      // It forms from the button's own footprint and swells to the lens.
      if still {
        lens.frame = target
      } else {
        let size = button.bounds.size
        lens.frame = CGRect(
          x: target.midX - size.width / 2, y: target.midY - size.height / 2,
          width: size.width, height: size.height)
      }
      lens.effect = nil
      UIView.animate(
        springDuration: 0.4, bounce: 0.3, initialSpringVelocity: 0, delay: 0, options: options
      ) {
        // Clear glass, lit a little, so it reads over the bar's own.
        let glass = UIGlassEffect(style: .clear)
        glass.tintColor = UIColor.white.withAlphaComponent(0.1)
        glass.isInteractive = true
        lens.effect = glass
        lens.frame = target
      }
    } else {
      UIView.animate(
        springDuration: x == nil ? 0.4 : 0.28, bounce: x == nil ? 0.3 : 0.15,
        initialSpringVelocity: 0, delay: 0, options: options
      ) { lens.frame = target }
    }
    light(button)
    fill(near: x ?? (capsule.map { $0.frame.minX + button.center.x } ?? 0))
  }

  // Fills the glyph under the lens, as the system's own tab bars do:
  // each button's filled form shows as much as the lens is over it, full
  // under its middle and gone a button's width away (owner, 21 October
  // 2026: "like WhatsApp's and Telegram's"). Nil lets them all go.
  private func fill(near x: CGFloat?) {
    guard let capsule = capsule else { return }
    for button in buttons.values {
      guard let fillView = button.viewWithTag(88) else { continue }
      var amount: CGFloat = 0
      if let x = x {
        let centre = capsule.frame.minX + button.center.x
        let reach = max(button.bounds.width, 1)
        amount = max(0, 1 - abs(centre - x) / reach)
      }
      if abs(fillView.alpha - amount) < 0.01 { continue }
      if x == nil {
        UIView.animate(withDuration: 0.25) { fillView.alpha = 0 }
      } else {
        fillView.alpha = amount
      }
    }
  }

  // The lens melts away; let go on a button, it settles there first.
  private func lensDown(settling: Bool = false) {
    light(nil)
    fill(near: nil)
    guard #available(iOS 26.0, *), lensUp, let lens = lens, let capsule = capsule else { return }
    lensUp = false
    let bar = capsule.frame
    let shrunk =
      still
      ? lens.frame
      : lens.frame.insetBy(
        dx: 6 * scale, dy: (lens.frame.height - (bar.height - 12 * scale)) / 2)
    UIView.animate(
      springDuration: 0.35, bounce: 0, initialSpringVelocity: 0, delay: settling ? 0.12 : 0,
      options: [.allowUserInteraction, .beginFromCurrentState]
    ) {
      lens.effect = nil
      lens.frame = shrunk
    }
  }

  // The button under the lens is drawn a little larger, as through the
  // glass; the one it leaves goes back.
  private func light(_ button: UIButton?) {
    guard #available(iOS 26.0, *), under !== button else { return }
    let before = under
    under = button
    let grow = still ? CGAffineTransform.identity : CGAffineTransform(scaleX: 1.16, y: 1.16)
    UIView.animate(
      springDuration: 0.3, bounce: 0.25, initialSpringVelocity: 0, delay: 0,
      options: [.allowUserInteraction, .beginFromCurrentState]
    ) {
      before?.transform = .identity
      button?.transform = grow
    }
  }
}

// A glass container that is only there to be seen: a touch that finds
// nothing in it but its own background goes through to the app.
final class PassThroughEffectView: UIVisualEffectView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    return hit === self || hit === contentView ? nil : hit
  }
}
