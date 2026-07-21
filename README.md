# photo_gallery_gdx_plus

[![pub package](https://img.shields.io/pub/v/photo_gallery_gdx_plus.svg)](https://pub.dev/packages/photo_gallery_gdx_plus)
[![BSD-3-Clause license](https://img.shields.io/github/license/47gurvinder/photo_gallery)](https://github.com/47gurvinder/photo_gallery/blob/master/LICENSE)

A community-maintained Flutter plugin for retrieving images and videos from the native gallery on Android and iOS.

The package supports album discovery, paginated media queries, image and video metadata, thumbnails, original files, deletion, cache cleanup, and Flutter `ImageProvider` integrations.

## Compatibility

| Component | Supported version |
| --- | --- |
| Dart | `>=3.12.0 <4.0.0` |
| Flutter | `>=3.44.0` |
| Android | API 24+; compile SDK 36 |
| iOS | 13.0+ |

Only Android and iOS are registered as plugin platforms. Web, macOS, Windows, and Linux are not supported.

iOS integration currently uses CocoaPods. Native Swift Package Manager support is not yet available for this fork.

## Installation

Add the package to your application:

```shell
flutter pub add photo_gallery_gdx_plus
```

Or add it manually to `pubspec.yaml`:

```yaml
dependencies:
  photo_gallery_gdx_plus: ^2.3.0
```

Import the public library:

```dart
import 'dart:io';

import 'package:photo_gallery_gdx_plus/photo_gallery_gdx_plus.dart';
```

### iOS setup

Add a photo-library usage description to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library.</string>
```

Your app is responsible for requesting photo-library permission at runtime before calling the plugin.

### Android setup

Declare the gallery permissions used by the Android versions your app supports in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <uses-permission
        android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <application ... />
</manifest>
```

Request the corresponding runtime permissions in your application. On Android 13 (API 33) and newer, images and videos use separate permissions.

## Usage

### List albums

```dart
final List<Album> imageAlbums = await PhotoGallery.listAlbums(
  mediumType: MediumType.image,
);

final List<Album> videoAlbums = await PhotoGallery.listAlbums(
  mediumType: MediumType.video,
  newest: false,
  hideIfEmpty: false,
);
```

Omit `mediumType` to include both images and videos. On iOS, `approximateCount: true` can reduce the work required to calculate album counts.

### List media with pagination

```dart
final MediaPage firstPage = await imageAlbum.listMedia(
  skip: 0,
  take: 20,
);

final List<Medium> media = firstPage.items;

if (!firstPage.isLast) {
  final MediaPage nextPage = await firstPage.nextPage();
  media.addAll(nextPage.items);
}
```

Pass `lightWeight: true` to return a smaller metadata set when full media details are not needed.

### Get media metadata and files

```dart
final Medium medium = await PhotoGallery.getMedium(
  mediumId: '10',
  mediumType: MediumType.image,
);

final File fileFromMedium = await medium.getFile();
final File fileFromId = await PhotoGallery.getFile(
  mediumId: medium.id,
  mediumType: medium.mediumType,
);
```

### Get thumbnail data

```dart
final List<int> mediumThumbnail = await medium.getThumbnail(
  width: 128,
  height: 128,
  highQuality: true,
);

final List<int> albumThumbnail = await album.getThumbnail(
  width: 128,
  height: 128,
  highQuality: true,
);
```

You can also call `PhotoGallery.getThumbnail` or `PhotoGallery.getAlbumThumbnail` directly. Custom thumbnail dimensions are supported on Android API 29+ and iOS. The `highQuality` option is primarily relevant on iOS.

### Display thumbnails

The package includes image providers that work with Flutter image widgets. This example uses [`transparent_image`](https://pub.dev/packages/transparent_image) for the placeholder:

```dart
FadeInImage(
  fit: BoxFit.cover,
  placeholder: MemoryImage(kTransparentImage),
  image: ThumbnailProvider(
    mediumId: medium.id,
    mediumType: medium.mediumType,
    width: 128,
    height: 128,
    highQuality: true,
  ),
)
```

Use `AlbumThumbnailProvider` for an album:

```dart
FadeInImage(
  fit: BoxFit.cover,
  placeholder: MemoryImage(kTransparentImage),
  image: AlbumThumbnailProvider(
    album: album,
    width: 128,
    height: 128,
    highQuality: true,
  ),
)
```

Use `PhotoProvider` for a full-size image:

```dart
FadeInImage(
  fit: BoxFit.cover,
  placeholder: MemoryImage(kTransparentImage),
  image: PhotoProvider(mediumId: medium.id),
)
```

### Delete media and clear cached files

```dart
await PhotoGallery.deleteMedium(
  mediumId: medium.id,
  mediumType: medium.mediumType,
);

await PhotoGallery.cleanCache();
```

Deletion behavior and any confirmation UI are controlled by the operating system. Treat deletion as destructive and confirm the action with the user first.

See the complete runnable application in the [`example`](https://github.com/47gurvinder/photo_gallery/tree/master/example) directory.

## Maintained Package

`photo_gallery_gdx_plus` is a community-maintained continuation of the original [`photo_gallery`](https://github.com/Firelands128/photo_gallery) project because upstream is no longer actively maintained. The original project credits, copyright notice, license, and Git history remain intact.

The original project was authored by [Wenqi Li](https://github.com/Firelands128). Thanks to Wenqi Li and all [upstream and fork contributors](https://github.com/47gurvinder/photo_gallery/graphs/contributors) for their work.

This maintained package is not presented as being endorsed by the original author or contributors.

## Feature Requests

Feature requests and Pull Requests are always welcome.

- [Request a feature](https://github.com/47gurvinder/photo_gallery/issues/new?template=feature_request.yml)
- [Report a bug](https://github.com/47gurvinder/photo_gallery/issues)
- [Open or review Pull Requests](https://github.com/47gurvinder/photo_gallery/pulls)
- [Read the contribution guide](https://github.com/47gurvinder/photo_gallery/blob/master/CONTRIBUTING.md)

## Need Help?

Professional help is available for package integration, consulting, Flutter development, and ongoing plugin maintenance. Visit [gurwinderdevx.com](https://gurwinderdevx.com) to get in touch.

## Maintainer

Maintained by Gurwinder Singh.

- [Website](https://gurwinderdevx.com)
- [GitHub](https://github.com/47gurvinder)
- [LinkedIn](https://www.linkedin.com/in/47gurvinder)
- [Upwork](https://www.upwork.com/freelancers/~01281f2b994bae6a1e)

## License

This project remains available under the [BSD 3-Clause License](LICENSE). Copyright (c) 2020, Wenqi Li. See the license file for the complete terms and disclaimer.
