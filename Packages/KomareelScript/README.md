# KomareelScript

The C target embeds the core interpreter from [QuickJS-NG 0.18.0](https://github.com/quickjs-ng/quickjs/releases/tag/v0.18.0). The interpreter files in `Sources/CKomareelScript/QuickJS` are unmodified and retain their [upstream license](Sources/CKomareelScript/QuickJS/LICENSE).

`Runtime.c` owns the interpreter and hands asynchronous requests to the app. It exposes neither QuickJS's optional libc helpers nor its command-line tools.
