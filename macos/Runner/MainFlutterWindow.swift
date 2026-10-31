import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?
  private var folderAccess: PersistentFolderAccess?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    folderAccess = PersistentFolderAccess(messenger: flutterViewController.engine.binaryMessenger)

    collectionBehavior.insert(.fullScreenPrimary)
    windowChannel = FlutterMethodChannel(
      name: "localflix/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    windowChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setFullscreen" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let enabled = call.arguments as? Bool else {
        result(FlutterError(code: "invalid_argument", message: "Expected a boolean", details: nil))
        return
      }
      guard let window = self else {
        result(FlutterError(code: "window_closed", message: "Window is closed", details: nil))
        return
      }
      if window.styleMask.contains(.fullScreen) != enabled {
        window.toggleFullScreen(nil)
      }
      result(nil)
    }

    super.awakeFromNib()
  }
}


// The OS owns the grant. Flutter persists only the bookmark returned here.
final class PersistentFolderAccess: NSObject {
  private let channel: FlutterMethodChannel
  private var scopes: [String: URL] = [:]
  private var pendingPick: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "localflix/folders", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "closed", message: "Acesso encerrado", details: nil)); return }
      switch call.method {
      case "pickFolder":
        self.pickFolder(result)
      case "restoreFolders":
        let bookmarks = call.arguments as? [String: String] ?? [:]
        var restored: [[String: String]] = []
        for (oldPath, encoded) in bookmarks {
          do {
            guard let data = Data(base64Encoded: encoded) else { continue }
            var stale = false
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
              relativeTo: nil, bookmarkDataIsStale: &stale)
            #else
            let url = try URL(resolvingBookmarkData: data, options: [.withoutUI],
              relativeTo: nil, bookmarkDataIsStale: &stale)
            #endif
            var entry = try self.retainFolder(url)
            entry["oldPath"] = oldPath
            restored.append(entry)
          } catch { /* Keep unavailable bookmarks for the next user-authorized retry. */ }
        }
        result(restored)
      case "releaseFolder":
        if let path = call.arguments as? String, let url = self.scopes.removeValue(forKey: path) {
          url.stopAccessingSecurityScopedResource()
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func retainFolder(_ url: URL) throws -> [String: String] {
    let started = scopes[url.path] == nil && url.startAccessingSecurityScopedResource()
    do {
      guard started || scopes[url.path] != nil || FileManager.default.isReadableFile(atPath: url.path) else {
        throw CocoaError(.fileReadNoPermission)
      }
      #if os(macOS)
      let bookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
        includingResourceValuesForKeys: nil, relativeTo: nil)
      #else
      let bookmark = try url.bookmarkData(options: [.minimalBookmark],
        includingResourceValuesForKeys: nil, relativeTo: nil)
      #endif
      if started { scopes[url.path] = url }
      return ["path": url.path, "bookmark": bookmark.base64EncodedString()]
    } catch {
      if started { url.stopAccessingSecurityScopedResource() }
      throw error
    }
  }

  private func pickFolder(_ result: @escaping FlutterResult) {
    guard pendingPick == nil else { result(FlutterError(code: "picker_busy", message: "Seleção já aberta", details: nil)); return }
    pendingPick = result
    #if os(macOS)
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Autorizar pasta"
    panel.begin { [weak self] response in
      self?.finishPick(response == .OK ? panel.url : nil)
    }
    #else
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var presenter = scenes.filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let next = presenter?.presentedViewController { presenter = next }
    guard let presenter else { pendingPick = nil; result(FlutterError(code: "no_window", message: "Seletor indisponível", details: nil)); return }
    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    } else {
      picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
    }
    picker.allowsMultipleSelection = false
    picker.delegate = self
    presenter.present(picker, animated: true)
    #endif
  }

  fileprivate func finishPick(_ url: URL?) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    guard let url else { result(nil); return }
    do { result(try retainFolder(url)) }
    catch { result(FlutterError(code: "folder_access", message: "Não foi possível manter o acesso. Selecione a pasta novamente.", details: nil)) }
  }

  deinit {
    channel.setMethodCallHandler(nil)
    for url in scopes.values { url.stopAccessingSecurityScopedResource() }
  }
}

#if os(iOS)
extension PersistentFolderAccess: UIDocumentPickerDelegate {
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishPick(urls.first)
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finishPick(nil) }
}
#endif
