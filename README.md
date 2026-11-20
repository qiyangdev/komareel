# Aidoku

This is an independently maintained fork of [Aidoku](https://github.com/Aidoku/Aidoku), an open-source manga reader for iOS, iPadOS, and macOS. Development here focuses on extending Aidoku's source system to support video playback alongside manga reading.

<p>
	<img src="https://raw.githubusercontent.com/Aidoku/Website/refs/heads/main/static/images/library-noframe.png" width="25%" alt="Library">
	<img src="https://raw.githubusercontent.com/Aidoku/Website/refs/heads/main/static/images/source-noframe.png" width="25%" alt="Source">
	<img src="https://raw.githubusercontent.com/Aidoku/Website/refs/heads/main/static/images/reader-noframe.png" width="25%" alt="Reader">
</p>

## Manga reading

- No ads
- Local file reading (CBZ)
- Built-in reading service providers (Komga, Kavita, Suwayomi)
- WASM external source system
- Downloads
- Tracker integration (AniList, MyAnimeList, etc.)
- OCR dictionary lookup

## Video sources

The [video development branch](https://github.com/qiyangdev/Aidoku/tree/feat/video-sources) adds a built-in **Video Samples** source. It supports searchable samples, HLS and MP4 playback with native controls, and local per-episode progress for resuming playback.

To try it, check out `feat/video-sources`, open `Aidoku.xcodeproj` in Xcode, and run the `Aidoku` scheme on an iPhone simulator. In the app, open **Browse → Add Source → Video Samples**.

## Upstream Aidoku

Official Aidoku installation options, including TestFlight and AltStore, are documented on the [Aidoku website](https://aidoku.app). Official IPA downloads are available from [upstream releases](https://github.com/Aidoku/Aidoku/releases).

See the [upstream repository](https://github.com/Aidoku/Aidoku) for its contribution guidelines and [Weblate](https://hosted.weblate.org/engage/aidoku/) for translations.

## License

The source code is licensed under [GPLv3](LICENSE). Translations are licensed separately under [Apache 2.0](https://spdx.org/licenses/Apache-2.0.html).
