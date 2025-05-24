# noor_player

A lightweight, customizable Flutter widget to show video thumbnails and play videos with auto-download, cache, mute toggle, and auto-play on visibility.

## Features

- Video thumbnail generation with shimmer placeholder
- Automatic video download and caching
- Auto-play/pause on visibility
- Mute/unmute toggle
- Rotation support for vertical videos

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  noor_player: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Usage

```dart
import 'package:noor_player/noor_player.dart';

NoorPlayer(videoUrl: 'https://example.com/video.mp4')
```

## Thumbnail only

```dart
VideoThumbnailWidget(videoUrl: 'https://example.com/video.mp4')
```

## License

MIT License.