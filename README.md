# KomaReel

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
- WASM external source system
- Downloads
- Tracker integration (AniList, MyAnimeList, etc.)
- OCR dictionary lookup

## Video sources

The built-in **Video Samples** source supports searchable samples, HLS and MP4 playback with native controls, and local per-episode progress for resuming playback.

To try it, open `Aidoku.xcodeproj` in Xcode and run the `Aidoku` scheme on an iPhone simulator. In the app, open **Browse → Add Source → Video Samples**.

### WASM video extensions

Install a video `.aix` through the same source list or file import as manga extensions. In the API 0.7 `Payload/source.json`, set `"mediaType": "video"` inside `config`. Other manifest fields and the WASM ABI follow the standard Aidoku source format.

Use the existing catalog and detail functions for shows and episodes. Return each episode as a chapter from `get_manga_update`. For the selected episode, `get_page_list` must return exactly one URL page containing a direct HTTPS playback URL, such as an HLS playlist or MP4. The app resolves the URL when playback starts or is retried. Page context does not supply playback headers, so use a URL the player can request directly, such as a signed URL.

## WASM text extensions

Set `"mediaType": "text"` inside `config` in `Payload/source.json` to open chapters directly in the text reader. Use the existing catalog and chapter functions, and return one `PageContent::text` containing UTF-8 Markdown from `get_page_list` for each chapter. KomaReel lays out the chapter according to the reader's paged or scrolling preference.

Set `"showsListCovers": false` inside `config` to hide covers in the source home page's list rows and loading skeletons. The default is `true`.

## Upstream Aidoku

Official Aidoku installation options, including TestFlight and AltStore, are documented on the [Aidoku website](https://aidoku.app). Official IPA downloads are available from [upstream releases](https://github.com/Aidoku/Aidoku/releases).

See the [upstream repository](https://github.com/Aidoku/Aidoku) for its contribution guidelines and [Weblate](https://hosted.weblate.org/engage/aidoku/) for translations.

## License

The source code is licensed under [GPLv3](LICENSE). Translations are licensed separately under [Apache 2.0](https://spdx.org/licenses/Apache-2.0.html).
