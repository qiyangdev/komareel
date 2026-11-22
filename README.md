# Komareel

A manga and text reader with audio and video playback, based on [Aidoku](https://github.com/Aidoku/Aidoku).

Requires iOS 26.0 or later.

<p>
	<img src="https://raw.githubusercontent.com/Aidoku/Website/refs/heads/main/static/images/library-noframe.png" width="25%" alt="Library">
	<img src="https://raw.githubusercontent.com/Aidoku/Website/refs/heads/main/static/images/source-noframe.png" width="25%" alt="Source">
	<img src="https://raw.githubusercontent.com/Aidoku/Website/refs/heads/main/static/images/reader-noframe.png" width="25%" alt="Reader">
</p>

## Manga reading

- No ads
- Local file reading (CBZ)
- Built-in reading service providers (Komga, Kavita, Suwayomi)
- JavaScript extensions distributed as `.krx` packages
- Downloads
- Tracker integration (AniList, MyAnimeList, etc.)
- OCR dictionary lookup

## Video sources

The built-in **Video Samples** source supports searchable samples, HLS and MP4 playback with native controls, and local per-episode progress for resuming playback.

To try it, open `Komareel.xcodeproj` in Xcode and run the `Komareel` scheme on an iPhone simulator. In the app, open **Browse → Add Source → Video Samples**.

## JavaScript extensions

Import a `.krx` file from **Browse → Add Source → Import Source**, or install one from a source list. The archive contains `Payload/source.json` with `"scriptAPI": 1` and `Payload/main.js` with the script. Source IDs stay consistent across packages and versions.

Use `komareel://addSourceList?url=<encoded-source-list-url>` to open a source list in the app.

Scripts export `search`, `details`, and `pages` through `globalThis.source`. Declare optional methods such as `listing` in the manifest's `exports` array. The runtime provides asynchronous HTTP requests, HTML and XML XPath, source settings, and a source-scoped WebView for pages that need a browser. Scripts can send incremental homepage and detail results with `await Komareel.publish(value)`. See the [Komareel sources repository](https://github.com/qiyangdev/komareel-sources) for examples.

- For `"mediaType": "video"` or `"audio"`, return each episode as a chapter. Return one `{ url }` page for the selected episode. The app resolves the direct HTTPS URL when playback starts or is retried.
- For `"mediaType": "text"`, return a `{ text }` page containing UTF-8 Markdown. Set `"showsListCovers": false` to hide covers in source list rows and loading skeletons.

## Upstream Aidoku

Official Aidoku installation options, including TestFlight and AltStore, are documented on the [Aidoku website](https://aidoku.app). Official IPA downloads are available from [upstream releases](https://github.com/Aidoku/Aidoku/releases).

See the [upstream repository](https://github.com/Aidoku/Aidoku) for its contribution guidelines and [Weblate](https://hosted.weblate.org/engage/aidoku/) for translations.

## License

The source code is licensed under [GPLv3](LICENSE). Translations are licensed separately under [Apache 2.0](https://spdx.org/licenses/Apache-2.0.html).
