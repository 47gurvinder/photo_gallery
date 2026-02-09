import Foundation
import MobileCoreServices
import Flutter
import UIKit
import Photos
import AVFoundation

public class PhotoGalleryPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "photo_gallery", binaryMessenger: registrar.messenger())
    let instance = PhotoGalleryPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if(call.method == "listAlbums") {
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let mediumType = arguments["mediumType"] as? String
      let hideIfEmpty = arguments["hideIfEmpty"] as? Bool
      result(listAlbums(mediumType: mediumType, hideIfEmpty: hideIfEmpty))
    }
    else if(call.method == "listMedia") {
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let albumId = arguments["albumId"] as! String
      let mediumType = arguments["mediumType"] as? String
      let newest = arguments["newest"] as! Bool
      let skip = arguments["skip"] as? NSNumber
      let take = arguments["take"] as? NSNumber
      let lightWeight = arguments["lightWeight"] as? Bool
      result(listMedia(
        albumId: albumId,
        mediumType: mediumType,
        newest: newest,
        skip: skip,
        take: take,
        lightWeight: lightWeight
      ))
    }
    else if(call.method == "getMedium") {
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let mediumId = arguments["mediumId"] as! String
      do {
        let medium = try getMedium(mediumId: mediumId)
        result(medium)
      } catch {
        result(nil)
      }
    }
    else if(call.method == "getThumbnail") {
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let mediumId = arguments["mediumId"] as! String
      let width = arguments["width"] as? NSNumber
      let height = arguments["height"] as? NSNumber
      let highQuality = arguments["highQuality"] as? Bool
      getThumbnail(
        mediumId: mediumId,
        width: width,
        height: height,
        highQuality: highQuality,
        completion: { (data: Data?, error: Error?) -> Void in
          result(data)
        }
      )
    }
    else if(call.method == "getAlbumThumbnail") {
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let albumId = arguments["albumId"] as! String
      let mediumType = arguments["mediumType"] as? String
      let newest = arguments["newest"] as! Bool
      let width = arguments["width"] as? Int
      let height = arguments["height"] as? Int
      let highQuality = arguments["highQuality"] as? Bool
      getAlbumThumbnail(
        albumId: albumId,
        mediumType: mediumType,
        newest: newest,
        width: width,
        height: height,
        highQuality: highQuality,
        completion: { (data: Data?, error: Error?) -> Void in
          result(data)
        }
      )
    }
    else if(call.method == "getFile") {
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let mediumId = arguments["mediumId"] as! String
      let mimeType = arguments["mimeType"] as? String
      getFile(
        mediumId: mediumId,
        mimeType: mimeType,
        completion: { (filepath: String?, error: Error?) -> Void in
          result(filepath?.replacingOccurrences(of: "file://", with: ""))
        }
      )
    }
    else if(call.method == "deleteMedium") {
      let arguments = call.arguments as! Dictionary<String, AnyObject>
      let mediumId = arguments["mediumId"] as! String
      deleteMedium(
        mediumId: mediumId,
        completion: { (success: Bool, error: Error?) -> Void in
          result(success)
        }
      )
    }
    else if(call.method == "cleanCache") {
      cleanCache()
      result(nil)
    }
    else {
      result(FlutterMethodNotImplemented)
    }
  }

  private var assetCollections: [PHAssetCollection] = []

  private func listAlbums(mediumType: String?, hideIfEmpty: Bool? = true) -> [[String: Any?]] {
    self.assetCollections = []
    let fetchOptions = PHFetchOptions()
    if #available(iOS 9, *) {
      fetchOptions.fetchLimit = 1
    }
    var albums = [[String: Any?]]()
    var albumIds = Set<String>()

    func addCollection (collection: PHAssetCollection, hideIfEmpty: Bool) -> Void {
      let kRecentlyDeletedCollectionSubtype = PHAssetCollectionSubtype(rawValue: 1000000201)
      guard collection.assetCollectionSubtype != kRecentlyDeletedCollectionSubtype else { return }

      // De-duplicate by id.
      let albumId = collection.localIdentifier
      guard !albumIds.contains(albumId) else { return }
      albumIds.insert(albumId)

      let count = countMedia(collection: collection, mediumType: mediumType)
      if(count > 0 || !hideIfEmpty) {
        self.assetCollections.append(collection)
        albums.append([
          "id": collection.localIdentifier,
          "name": collection.localizedTitle ?? "Unknown",
          "count": count,
        ])
      }
    }

    func processPHAssetCollections(fetchResult: PHFetchResult<PHAssetCollection>, hideIfEmpty: Bool) -> Void {
      fetchResult.enumerateObjects { (assetCollection, _, _) in
        addCollection(collection: assetCollection, hideIfEmpty: hideIfEmpty)
      }
    }

    func processPHCollections (fetchResult: PHFetchResult<PHCollection>, hideIfEmpty: Bool) -> Void {
      fetchResult.enumerateObjects { (collection, _, _) in
        if let assetCollection = collection as? PHAssetCollection {
          addCollection(collection: assetCollection, hideIfEmpty: hideIfEmpty)
        } else if let collectionList = collection as? PHCollectionList {
          processPHCollections(
            fetchResult: PHCollectionList.fetchCollections(in: collectionList, options: nil),
            hideIfEmpty: hideIfEmpty
          )
        }
      }
    }

    // Smart Albums.
    processPHAssetCollections(
      fetchResult: PHAssetCollection.fetchAssetCollections(
        with: .smartAlbum,
        subtype: .albumRegular,
        options: fetchOptions
      ),
      hideIfEmpty: hideIfEmpty ?? true
    )

    // User-created collections.
    processPHCollections(
      fetchResult: PHAssetCollection.fetchTopLevelUserCollections(with: fetchOptions),
      hideIfEmpty: hideIfEmpty ?? true
    )

    albums.insert([
      "id": "__ALL__",
      "name": "All",
      "count": countMedia(collection: nil, mediumType: mediumType),
    ], at: 0)

    return albums
  }

  private func countMedia(collection: PHAssetCollection?, mediumType: String?) -> Int {
    let options = PHFetchOptions()
    options.predicate = self.predicateFromMediumType(mediumType: mediumType)
    if(collection == nil) {
      return PHAsset.fetchAssets(with: options).count
    }

    return PHAsset.fetchAssets(in: collection ?? PHAssetCollection.init(), options: options).count
  }

  private func listMedia(
    albumId: String,
    mediumType: String?,
    newest: Bool,
    skip: NSNumber?,
    take: NSNumber?,
    lightWeight: Bool? = false
  ) -> NSDictionary {
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = predicateFromMediumType(mediumType: mediumType)
    fetchOptions.sortDescriptors = [
      NSSortDescriptor(key: "creationDate", ascending: newest ? false : true),
      NSSortDescriptor(key: "modificationDate", ascending: newest ? false : true)
    ]

    let collection = self.assetCollections.first(where: { (collection) -> Bool in
      collection.localIdentifier == albumId
    })

    let fetchResult: PHFetchResult<PHAsset>
    if(albumId == "__ALL__") {
      fetchResult = PHAsset.fetchAssets(with: fetchOptions)
    } else {
      fetchResult = PHAsset.fetchAssets(
        in: collection ?? PHAssetCollection.init(),
        options: fetchOptions
      )
    }
    let start = skip?.intValue ?? 0
    let total = fetchResult.count
    let end = take == nil ? total : min(start + take!.intValue, total)
    var items = [[String: Any?]]()

    if start < end {
      for index in start..<end {
        let asset = fetchResult.object(at: index) as PHAsset
        // Skip iCloud videos that are not available locally
        if asset.mediaType == .video && !isAssetLocallyAvailable(asset: asset) {
          continue
        }
        if(lightWeight == true) {
          items.append(getMediumFromAssetLightWeight(asset: asset))
        } else {
          items.append(getMediumFromAsset(asset: asset))
        }
      }
    }
    

    return [
      "start": start,
      "items": items,
    ]
  }

  private func getMedium(mediumId: String) throws -> [String: Any?] {
    let fetchOptions = PHFetchOptions()
    if #available(iOS 9, *) {
      fetchOptions.fetchLimit = 1
    }
    let assets: PHFetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [mediumId], options: fetchOptions)

    if (assets.count <= 0) {
      throw NSError(domain: "photo_gallery", code: 404)
    } else {
      let asset: PHAsset = assets[0]
      return getMediumFromAsset(asset: asset)
    }
  }

  private func getThumbnail(
    mediumId: String,
    width: NSNumber?,
    height: NSNumber?,
    highQuality: Bool?,
    completion: @escaping (Data?, Error?) -> Void
  ) {
    let manager = PHImageManager.default()
    let fetchOptions = PHFetchOptions()
    if #available(iOS 9, *) {
      fetchOptions.fetchLimit = 1
    }
    let assets: PHFetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [mediumId], options: fetchOptions)

    if (assets.count > 0) {
      let asset: PHAsset = assets[0]

      let options = PHImageRequestOptions()
      options.isSynchronous = false
      options.version = .current
      options.deliveryMode = (highQuality ?? false) ? .highQualityFormat : .fastFormat
      options.isNetworkAccessAllowed = true

      let imageSize = CGSize(width: width?.intValue ?? 128, height: height?.intValue ?? 128)
      manager.requestImage(
        for: asset,
        targetSize: CGSize(
          width: imageSize.width * UIScreen.main.scale,
          height: imageSize.height * UIScreen.main.scale
        ),
        contentMode: PHImageContentMode.aspectFill,
        options: options,
        resultHandler: { (uiImage: UIImage?, info) in
          guard let image = uiImage else {
            completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
            return
          }
          let bytes = image.jpegData(compressionQuality: CGFloat(70))
          completion(bytes, nil)
        }
      )
      return
    }

    completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
  }

  private func getAlbumThumbnail(
    albumId: String,
    mediumType: String?,
    newest: Bool,
    width: Int?,
    height: Int?,
    highQuality: Bool?,
    completion: @escaping (Data?, Error?) -> Void
  ) {
    let manager = PHImageManager.default()
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = self.predicateFromMediumType(mediumType: mediumType)
    fetchOptions.sortDescriptors = [
      NSSortDescriptor(key: "creationDate", ascending: !newest),
      NSSortDescriptor(key: "modificationDate", ascending: !newest)
    ]
    if #available(iOS 9, *) {
      fetchOptions.fetchLimit = 1
    }

   var assets: PHFetchResult<PHAsset>

   if albumId == "__ALL__" {
       assets = PHAsset.fetchAssets(with: fetchOptions)
   } else if let collection = self.assetCollections.first(where: { $0.localIdentifier == albumId }) {
       assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
   } else {
       // Handle the case where the collection is nil
       print("Error: Collection with ID \(albumId) not found")
       // You might want to provide a default value or handle this case according to your app's logic
       // For now, let's just assign an empty fetch result
       assets = PHAsset.fetchAssets(with: fetchOptions)
   }

    if (assets.count > 0) {
      let asset: PHAsset = assets[0]

      let options = PHImageRequestOptions()
      options.isSynchronous = false
      options.version = .current
      options.deliveryMode = (highQuality ?? false) ? .highQualityFormat : .fastFormat
      options.isNetworkAccessAllowed = true

      let imageSize = CGSize(width: width ?? 128, height: height ?? 128)
      manager.requestImage(
        for: asset,
        targetSize: CGSize(
          width: imageSize.width * UIScreen.main.scale,
          height: imageSize.height * UIScreen.main.scale
        ),
        contentMode: PHImageContentMode.aspectFill,
        options: options,
        resultHandler: { (uiImage: UIImage?, info) in
          guard let image = uiImage else {
            completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
            return
          }
          let bytes = image.jpegData(compressionQuality: CGFloat(80))
          completion(bytes, nil)
        }
      )
      return
    }

    completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
  }

  private func getFile(mediumId: String, mimeType: String?, completion: @escaping (String?, Error?) -> Void) {
    print("[PhotoGallery] getFile called for mediumId: \(mediumId), mimeType: \(mimeType ?? "null")")
    
    DispatchQueue.global(qos: .userInitiated).async {
      let manager = PHImageManager.default()

      let fetchOptions = PHFetchOptions()
      if #available(iOS 9, *) {
        fetchOptions.fetchLimit = 1
      }
      // Request prefetched properties to avoid main-queue access
      if #available(iOS 13, *) {
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
      }
      let assets: PHFetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [mediumId], options: fetchOptions)
      print("[PhotoGallery] Found \(assets.count) assets for mediumId: \(mediumId)")

      if (assets.count > 0) {
        let asset: PHAsset = assets[0]
        print("[PhotoGallery] Asset mediaType: \(asset.mediaType.rawValue), size: \(asset.pixelWidth)x\(asset.pixelHeight)")
        if(asset.mediaType == PHAssetMediaType.image) {
          print("[PhotoGallery] Processing as image")
          
          let options = PHImageRequestOptions()
          options.isSynchronous = false
          options.version = .original
          options.deliveryMode = .highQualityFormat
          options.isNetworkAccessAllowed = true

          let resource = self.bestResource(for: asset)
          print("[PhotoGallery] Best resource for image: \(resource?.originalFilename ?? "nil")")

          let handleImageData: (Data?, String?) -> Void = { (data, uti) in
            guard let imageData = data else {
              if let resource = resource {
                self.exportResourceToFile(resource: resource, asset: asset, completion: completion)
              } else {
                DispatchQueue.main.async {
                  completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
                }
              }
              return
            }

            let fallbackUTI = resource?.uniformTypeIdentifier ?? (kUTTypeJPEG as String)
            let assetUTI = uti ?? fallbackUTI

            if let requestedMimeType = mimeType {
              let type = self.extractMimeTypeFromUTI(uti: assetUTI)
              if type != requestedMimeType {
                let path = self.cacheImage(asset: asset, data: imageData, mimeType: requestedMimeType)
                DispatchQueue.main.async {
                  completion(path, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
                }
                return
              }
            }

            var fileExt = self.extractFileExtensionFromUTI(uti: assetUTI)
            if fileExt.isEmpty {
              fileExt = self.extractFileExtensionFromFilename(filename: resource?.originalFilename)
            }
            let filepath = self.exportPathForAsset(asset: asset, ext: fileExt)
            do {
              try imageData.write(to: filepath, options: .atomic)
              DispatchQueue.main.async {
                completion(filepath.absoluteString, nil)
              }
            } catch {
              DispatchQueue.main.async {
                completion(nil, error)
              }
            }
          }

          if #available(iOS 13, *) {
            manager.requestImageDataAndOrientation(
              for: asset,
              options: options,
              resultHandler: { (data: Data?, uti: String?, orientation, info) in
                handleImageData(data, uti)
              }
            )
          } else {
            manager.requestImageData(
              for: asset,
              options: options,
              resultHandler: { (data: Data?, uti: String?, orientation, info) in
                handleImageData(data, uti)
              }
            )
          }
        } else if(asset.mediaType == PHAssetMediaType.video || asset.mediaType == PHAssetMediaType.audio) {
          print("[PhotoGallery] Processing as video/audio")
          guard let resource = self.bestResource(for: asset) else {
            print("[PhotoGallery] No resource found for video/audio")
            DispatchQueue.main.async {
              completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
            }
            return
          }
          print("[PhotoGallery] Found resource: \(resource.originalFilename ?? "unknown"), type: \(resource.type.rawValue)")

          self.exportResourceToFile(resource: resource, asset: asset, completion: completion)
        } else {
          print("[PhotoGallery] Unknown media type: \(asset.mediaType.rawValue)")
          DispatchQueue.main.async {
            completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
          }
        }
      } else {
        print("[PhotoGallery] Asset not found for mediumId: \(mediumId)")
        DispatchQueue.main.async {
          completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
        }
      }
    }
  }

  private func cacheImage(asset: PHAsset, data: Data, mimeType: String) -> String? {
    if mimeType == "image/jpeg" {
      let filepath = self.exportPathForAsset(asset: asset, ext: ".jpeg")
      let uiImage = UIImage(data: data)
      try! uiImage?.jpegData(compressionQuality: 100)?.write(to: filepath, options: .atomic)
      return filepath.absoluteString
    } else if mimeType == "image/png" {
      let filepath = self.exportPathForAsset(asset: asset, ext: ".png")
      let uiImage = UIImage(data: data)
      try! uiImage?.pngData()?.write(to: filepath, options: .atomic)
      return filepath.absoluteString
    } else {
      return nil
    }
  }

  private func getMediumFromAsset(asset: PHAsset) -> [String: Any?] {
    let filename = self.extractFilenameFromAsset(asset: asset)
    let mimeType = self.extractMimeTypeFromAsset(asset: asset)
    let resource = self.extractResourceFromAsset(asset: asset)
    let size = self.extractSizeFromResource(resource: resource)
    //let orientation = self.toOrientationValue(orientation: asset.value(forKey: "orientation") as? UIImage.Orientation)

    // To get orientation from PHAsset more securely
    let orientation: Int
    if #available(iOS 18, *) {
        // Safe method for iOS 18+ (you may need to use another API from PHAsset)
        orientation = 0 // Or other default value
    } else {
        // Use existing method for older iOS versions
        orientation = self.toOrientationValue(orientation: asset.value(forKey: "orientation") as? UIImage.Orientation)
    }

    return [
      "id": asset.localIdentifier,
      "filename": filename,
      "title": self.extractTitleFromFilename(filename: filename),
      "mediumType": toDartMediumType(value: asset.mediaType),
      "mimeType": mimeType,
      "height": asset.pixelHeight,
      "width": asset.pixelWidth,
      "size": size,
      "orientation": orientation,
      "duration": NSInteger(asset.duration * 1000),
      "creationDate": (asset.creationDate != nil) ? NSInteger(asset.creationDate!.timeIntervalSince1970 * 1000) : nil,
      "modifiedDate": (asset.modificationDate != nil) ? NSInteger(asset.modificationDate!.timeIntervalSince1970 * 1000) : nil
    ]
  }

  private func getMediumFromAssetLightWeight(asset: PHAsset) -> [String: Any?] {
    return [
      "id": asset.localIdentifier,
      "mediumType": toDartMediumType(value: asset.mediaType),
      "height": asset.pixelHeight,
      "width": asset.pixelWidth,
      "duration": NSInteger(asset.duration * 1000),
      "creationDate": (asset.creationDate != nil) ? NSInteger(asset.creationDate!.timeIntervalSince1970 * 1000) : nil,
      "modifiedDate": (asset.modificationDate != nil) ? NSInteger(asset.modificationDate!.timeIntervalSince1970 * 1000) : nil
    ]
  }

  private func exportPathForAsset(asset: PHAsset, ext: String) -> URL {
    let mediumId = asset.localIdentifier
      .replacingOccurrences(of: "/", with: "__")
      .replacingOccurrences(of: "\\", with: "__")
    let cachePath = self.cachePath()
    return cachePath.appendingPathComponent(mediumId + ext)
  }

  private func toSwiftMediumType(value: String) -> PHAssetMediaType? {
    switch value {
    case "image": return PHAssetMediaType.image
    case "video": return PHAssetMediaType.video
    case "audio": return PHAssetMediaType.audio
    default: return nil
    }
  }

  private func toDartMediumType(value: PHAssetMediaType) -> String? {
    switch value {
    case PHAssetMediaType.image: return "image"
    case PHAssetMediaType.video: return "video"
    case PHAssetMediaType.audio: return "audio"
    default: return nil
    }
  }

  private func toOrientationValue(orientation: UIImage.Orientation?) -> Int {
    guard let orientation = orientation else {
      return 0
    }
    switch orientation {
    case UIImage.Orientation.up:
      return 1
    case UIImage.Orientation.down:
      return 3
    case UIImage.Orientation.left:
      return 6
    case UIImage.Orientation.right:
      return 8
    case UIImage.Orientation.upMirrored:
      return 2
    case UIImage.Orientation.downMirrored:
      return 4
    case UIImage.Orientation.leftMirrored:
      return 5
    case UIImage.Orientation.rightMirrored:
      return 7
    @unknown default:
      return 0
    }
  }

  private func predicateFromMediumType(mediumType: String?) -> NSPredicate? {
    guard let type = mediumType else {
      return nil
    }
    guard let swiftType = toSwiftMediumType(value: type) else {
      return nil
    }
    return NSPredicate(format: "mediaType = %d", swiftType.rawValue)
  }

  private func extractFileExtensionFromUTI(uti: String?) -> String {
    guard let assetUTI = uti else {
      return ""
    }
    guard let ext = UTTypeCopyPreferredTagWithClass(
      assetUTI as CFString,
      kUTTagClassFilenameExtension as CFString
    )?.takeRetainedValue() as String? else {
      return ""
    }
    return "." + ext
  }

  private func extractMimeTypeFromUTI(uti: String?) -> String? {
    guard let assetUTI = uti else {
      return nil
    }
    guard let mimeType = UTTypeCopyPreferredTagWithClass(
      assetUTI as CFString,
      kUTTagClassMIMEType as CFString
    )?.takeRetainedValue() as String? else {
      return nil
    }
    return mimeType
  }

  private func extractFileExtensionFromAsset(asset: PHAsset) -> String {
    let uti = self.bestResource(for: asset)?.uniformTypeIdentifier
    return self.extractFileExtensionFromUTI(uti: uti)
  }

  private func extractFileExtensionFromFilename(filename: String?) -> String {
    guard let filename = filename else {
      return ""
    }
    let ext = (filename as NSString).pathExtension
    if ext.isEmpty {
      return ""
    }
    return "." + ext
  }

  private func isAssetLocallyAvailable(asset: PHAsset) -> Bool {
    // For images, they're generally available
    if asset.mediaType == .image {
      return true
    }
    
    // For videos and audio, check if they have local file size
    // iCloud videos that aren't downloaded won't have a valid file size
    let resources = PHAssetResource.assetResources(for: asset)
    guard let resource = resources.first else {
      return false
    }
    
    // Try to get the file size - if it's nil or 0, the resource might be in iCloud
    if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
      return fileSize > 0
    }
    
    // If we can't determine, skip to be safe
    return false
  }

  private func extractMimeTypeFromAsset(asset: PHAsset) -> String? {
    let uti = self.bestResource(for: asset)?.uniformTypeIdentifier
    return self.extractMimeTypeFromUTI(uti: uti)
  }

  private func extractFilenameFromAsset(asset: PHAsset) -> String? {
    return self.bestResource(for: asset)?.originalFilename
  }

  private func extractTitleFromFilename(filename: String?) -> String? {
    if let name = filename {
      return (name as NSString).deletingPathExtension
    }
    return nil
  }

  private func extractResourceFromAsset(asset: PHAsset) -> PHAssetResource? {
    return self.bestResource(for: asset)
  }

  private func bestResource(for asset: PHAsset) -> PHAssetResource? {
    if #available(iOS 9, *) {
      let resources = PHAssetResource.assetResources(for: asset)
      if resources.isEmpty {
        return nil
      }
      switch asset.mediaType {
      case .video:
        if let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) {
          return resource
        }
      case .audio:
        if let resource = resources.first(where: { $0.type == .audio }) {
          return resource
        }
      case .image:
        if let resource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) {
          return resource
        }
      default:
        break
      }
      return resources.first
    }
    return nil
  }

  private func exportResourceToFile(
    resource: PHAssetResource,
    asset: PHAsset,
    completion: @escaping (String?, Error?) -> Void
  ) {
    print("[PhotoGallery] exportResourceToFile called for: \(resource.originalFilename ?? "unknown"), UTI: \(resource.uniformTypeIdentifier ?? "nil")")
    print("[PhotoGallery] Resource type: \(resource.type.rawValue)")
    print("[PhotoGallery] Asset ID: \(asset.localIdentifier)")
    
    var fileExt = self.extractFileExtensionFromUTI(uti: resource.uniformTypeIdentifier)
    if fileExt.isEmpty {
      fileExt = self.extractFileExtensionFromFilename(filename: resource.originalFilename)
    }
    print("[PhotoGallery] File extension determined: '\(fileExt)'")
    
    let filepath = self.exportPathForAsset(asset: asset, ext: fileExt)
    print("[PhotoGallery] Export filepath: \(filepath.absoluteString)")
    
    // Check if directory exists
    let directory = filepath.deletingLastPathComponent()
    let dirExists = FileManager.default.fileExists(atPath: directory.path)
    print("[PhotoGallery] Cache directory exists: \(dirExists)")

    let resourceManager = PHAssetResourceManager.default()
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    print("[PhotoGallery] PHAssetResourceRequestOptions: isNetworkAccessAllowed=true")

    print("[PhotoGallery] Starting writeData for resource")
    
    resourceManager.writeData(
      for: resource,
      toFile: filepath,
      options: options,
      completionHandler: { (error) in
        print("[PhotoGallery] writeData completionHandler called")
        
        if let error = error {
          let nsError = error as NSError
          print("[PhotoGallery] writeData error occurred")
          print("[PhotoGallery] Error domain: \(nsError.domain)")
          print("[PhotoGallery] Error code: \(nsError.code)")
          print("[PhotoGallery] Error description: \(nsError.localizedDescription)")
          print("[PhotoGallery] Error details: \(nsError.userInfo)")
          print("[PhotoGallery] Initiating AVAsset fallback")
          
          // Try fallback using AVAsset
          DispatchQueue.global(qos: .userInitiated).async {
            self.exportVideoUsingAVAsset(asset: asset, filepath: filepath, completion: completion)
          }
        } else {
          print("[PhotoGallery] writeData completed successfully")
          let fileExists = FileManager.default.fileExists(atPath: filepath.path)
          print("[PhotoGallery] File exists after writeData: \(fileExists)")
          
          if fileExists {
            do {
              let fileSize = try FileManager.default.attributesOfItem(atPath: filepath.path)[.size] as? Int64 ?? 0
              print("[PhotoGallery] File size: \(fileSize) bytes")
            } catch {
              print("[PhotoGallery] Failed to get file size: \(error)")
            }
          }
          
          DispatchQueue.main.async {
            print("[PhotoGallery] Calling completion with filepath: \(filepath.absoluteString)")
            completion(filepath.absoluteString, nil)
          }
        }
      }
    )
  }

  private func exportVideoUsingAVAsset(asset: PHAsset, filepath: URL, completion: @escaping (String?, Error?) -> Void) {
    print("[PhotoGallery] Attempting AVAsset fallback export for asset: \(asset.localIdentifier)")
    print("[PhotoGallery] Target filepath: \(filepath.absoluteString)")
    
    PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { (avAsset, audioMix, info) in
      print("[PhotoGallery] requestAVAsset callback called")
      print("[PhotoGallery] avAsset type: \(type(of: avAsset))")
      print("[PhotoGallery] audioMix: \(audioMix != nil)")
      print("[PhotoGallery] info keys: \(info?.keys.map { String(describing: $0) } ?? [])")
      
      guard let avAsset = avAsset else {
        print("[PhotoGallery] AVAsset is nil")
        DispatchQueue.main.async {
          completion(nil, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
        }
        return
      }
      
      guard let avURLAsset = avAsset as? AVURLAsset else {
        print("[PhotoGallery] AVAsset is not AVURLAsset, type: \(type(of: avAsset))")
        
        // Try to extract URL from composition
        if let composition = avAsset as? AVComposition {
          print("[PhotoGallery] AVAsset is AVComposition, duration: \(composition.duration.seconds)")
        }
        
        DispatchQueue.main.async {
          completion(nil, NSError(domain: "photo_gallery", code: 405, userInfo: ["message": "AVAsset is not AVURLAsset"]))
        }
        return
      }
      
      print("[PhotoGallery] Got AVURLAsset from: \(avURLAsset.url.absoluteString)")
      print("[PhotoGallery] Source file exists: \(FileManager.default.fileExists(atPath: avURLAsset.url.path))")
      
      do {
        let sourceSize = try FileManager.default.attributesOfItem(atPath: avURLAsset.url.path)[.size] as? Int64 ?? 0
        print("[PhotoGallery] Source file size: \(sourceSize) bytes")
        
        // Ensure directory exists
        let directory = filepath.deletingLastPathComponent()
        print("[PhotoGallery] Ensuring directory exists: \(directory.absoluteString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        print("[PhotoGallery] Directory created/verified")
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: filepath.path) {
          print("[PhotoGallery] Removing existing file at: \(filepath.absoluteString)")
          try FileManager.default.removeItem(at: filepath)
        }
        
        // Copy the file
        print("[PhotoGallery] Copying file from: \(avURLAsset.url.absoluteString) to: \(filepath.absoluteString)")
        try FileManager.default.copyItem(at: avURLAsset.url, to: filepath)
        
        let destSize = try FileManager.default.attributesOfItem(atPath: filepath.path)[.size] as? Int64 ?? 0
        print("[PhotoGallery] Destination file size: \(destSize) bytes")
        print("[PhotoGallery] AVAsset fallback succeeded")
        
        DispatchQueue.main.async {
          completion(filepath.absoluteString, nil)
        }
      } catch {
        let nsError = error as NSError
        print("[PhotoGallery] AVAsset fallback copy failed")
        print("[PhotoGallery] Error domain: \(nsError.domain)")
        print("[PhotoGallery] Error code: \(nsError.code)")
        print("[PhotoGallery] Error description: \(nsError.localizedDescription)")
        print("[PhotoGallery] Error details: \(nsError.userInfo)")
        
        DispatchQueue.main.async {
          completion(nil, error)
        }
      }
    }
  }

  private func extractSizeFromResource(resource: PHAssetResource?) -> Int64? {
    if let assetResource = resource {
      return assetResource.value(forKey: "fileSize") as? Int64
    }
    return nil
  }

  private func cachePath() -> URL {
    let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    let cacheFolder = paths[0].appendingPathComponent("photo_gallery")
    print("[PhotoGallery] Cache folder path: \(cacheFolder.absoluteString)")
    do {
      try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
      print("[PhotoGallery] Cache folder created/verified successfully")
    } catch {
      print("[PhotoGallery] Failed to create cache folder: \(error)")
    }
    return cacheFolder
  }

  private func deleteMedium(mediumId: String, completion: @escaping (Bool, Error?) -> Void) {
    let fetchOptions = PHFetchOptions()
    if #available(iOS 9, *) {
      fetchOptions.fetchLimit = 1
    }
    let assets: PHFetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [mediumId], options: fetchOptions)

    if assets.count <= 0 {
      completion(false, NSError(domain: "photo_gallery", code: 404, userInfo: nil))
    } else {
      let asset: PHAsset = assets[0]
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.deleteAssets([asset] as NSFastEnumeration)
      }, completionHandler: completion)
    }
  }

  private func cleanCache() {
    try? FileManager.default.removeItem(at: self.cachePath())
  }
}
