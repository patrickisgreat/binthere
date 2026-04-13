# Changelog

## [0.7.0](https://github.com/patrickisgreat/binthere/compare/v0.6.0...v0.7.0) (2026-04-13)


### Features

* add household UI — setup, members, invite, join ([81345c3](https://github.com/patrickisgreat/binthere/commit/81345c3e573ec51e357136de060cbf7f66fc1df5))
* add HouseholdService for multi-user management ([520898c](https://github.com/patrickisgreat/binthere/commit/520898c6c1278543e1be2b3e50357fa655560ffd))
* household management — create, invite, join, members ([bfc94d8](https://github.com/patrickisgreat/binthere/commit/bfc94d8d8bfd8bbeaff4cacf0d8b4f7fb52920cb))

## [0.6.0](https://github.com/patrickisgreat/binthere/compare/v0.5.0...v0.6.0) (2026-04-13)


### Features

* add sync fields to all models ([ab9e7a1](https://github.com/patrickisgreat/binthere/commit/ab9e7a1ec2b20e1ff4802c95b3e3cb800ea9e717))
* add SyncService for bidirectional Supabase sync ([e950c6a](https://github.com/patrickisgreat/binthere/commit/e950c6a56f4938349e6b37f8d95b4fcfb7dbbe0b))
* sync service with bidirectional Supabase sync ([4d0cfde](https://github.com/patrickisgreat/binthere/commit/4d0cfde6ebe9d72b8f367fbbfb4d71a87a55fb98))

## [0.5.0](https://github.com/patrickisgreat/binthere/compare/v0.4.0...v0.5.0) (2026-04-13)


### Features

* add account deletion (App Store requirement) ([78d5755](https://github.com/patrickisgreat/binthere/commit/78d5755ece0ca4589eaa66ae453c396aff832b85))
* add auth UI with gate, sign-in, sign-up, and account settings ([0f6c896](https://github.com/patrickisgreat/binthere/commit/0f6c8963d11aaad1a975ae3a6b28e4222692df84))
* add AuthService with Sign in with Apple and email auth ([e2f7744](https://github.com/patrickisgreat/binthere/commit/e2f7744cbc10543ee8c7a2464188ca6496b7f4a3))
* add Supabase database schema and RLS policies ([c8f22b3](https://github.com/patrickisgreat/binthere/commit/c8f22b3bdb09a9c4074a97eb529a70ae4363cfee))
* add supabase-swift SPM dependency and client singleton ([b1a8b3e](https://github.com/patrickisgreat/binthere/commit/b1a8b3ea6288da43cc65a687b233424dabdacede))
* authentication with Sign in with Apple and email/password ([6fce6c3](https://github.com/patrickisgreat/binthere/commit/6fce6c3e6f2bd287e589da41d0837452cdf3ce15))
* Supabase client setup, database schema, and RLS policies ([7d398b6](https://github.com/patrickisgreat/binthere/commit/7d398b6346d101579adf17a7c463c251da9bc321))


### Bug Fixes

* remove UI tests from CI pipeline ([c604c31](https://github.com/patrickisgreat/binthere/commit/c604c31cffab6cc3c77500a41c04580a9e4ece0a))
* replace stub UI tests with auth-aware tests ([88e94e9](https://github.com/patrickisgreat/binthere/commit/88e94e905a724fa2d09f986cf1007881df058d98))

## [0.4.0](https://github.com/patrickisgreat/binthere/compare/v0.3.0...v0.4.0) (2026-04-12)


### Features

* reports, manifests, and analytics dashboard ([ece92ff](https://github.com/patrickisgreat/binthere/commit/ece92ff202a537df69fef53e4d09383461b15008))

## [0.3.0](https://github.com/patrickisgreat/binthere/compare/v0.2.0...v0.3.0) (2026-04-12)


### Features

* add AI-powered item value estimation ([25c6f7c](https://github.com/patrickisgreat/binthere/commit/25c6f7c8e56b61db90c21fc208ce0b6b8e1d30a4))
* add CustomAttribute model and valuation fields ([901186f](https://github.com/patrickisgreat/binthere/commit/901186ff8e164e94e3e2b94a6c7e8ac50494e3dc))
* add NFC service for reading and writing bin tags ([869d797](https://github.com/patrickisgreat/binthere/commit/869d797d6a9a9de0df34b570384748a3c0076a09))
* add zone editing from bin detail and bin creation from zone detail ([bd2657b](https://github.com/patrickisgreat/binthere/commit/bd2657b26290b6a056f2b4e1701ee8ed5f4d3ab7))
* add Zones tab with color-coded grid cards ([c8d0a1d](https://github.com/patrickisgreat/binthere/commit/c8d0a1d9b2ee4250059baf6046a9dc5aef4e9391))
* bin identity overhaul with auto-codes and color coding ([19f6527](https://github.com/patrickisgreat/binthere/commit/19f652755ee2085641d8723eb3c4c08f3288dccc))
* display valuation rollups on bin, zone, and zone card views ([23d9cf8](https://github.com/patrickisgreat/binthere/commit/23d9cf8974b7c5b7551681636698eb83df3c975c))
* integrate NFC scanning and tag writing into UI ([75ed63e](https://github.com/patrickisgreat/binthere/commit/75ed63e9a6fdc8ffe798b66efac2f21392267382))
* item detail UI for value, notes, and custom attributes ([ee13a47](https://github.com/patrickisgreat/binthere/commit/ee13a47985b416f8644559f6ff84f6d5d8ef994b))
* item enrichment — notes, custom attributes, valuations ([0638805](https://github.com/patrickisgreat/binthere/commit/063880551c98a65840e04690fd36f694cee75ba7))
* NFC tag support + zone/bin cross-navigation + build fix ([512554d](https://github.com/patrickisgreat/binthere/commit/512554d9528ee21384c4d6a8bfd5f4315e28401c))
* show added items list during bin creation flow ([a8caee3](https://github.com/patrickisgreat/binthere/commit/a8caee38455747dcd58a8bc9982be45e7fd37364))
* update bin views with zone icons and group-by-zone ([964990b](https://github.com/patrickisgreat/binthere/commit/964990b08724e8fb6b37fbd336e7382578068250))
* zone overhaul with colors, icons, detail view, and HomeKit import ([a8e8689](https://github.com/patrickisgreat/binthere/commit/a8e86892c384aae573a7448394c1d8bf38d902b4))
* zone overhaul with colors, icons, detail view, and HomeKit import ([6c80f47](https://github.com/patrickisgreat/binthere/commit/6c80f4710cc3657e73754ab59b6d21392ed88746))


### Bug Fixes

* proper CI test pipeline with pre-booted simulator and retries ([b0ac66f](https://github.com/patrickisgreat/binthere/commit/b0ac66f11a978b7ba0676c030961d3687aa9cdd8))
* resolve build error in HomeKit import sheet ([8045913](https://github.com/patrickisgreat/binthere/commit/8045913b2bcf71b9df6c1100426c79230775e0fc))
* resolve SwiftLint violations and CI test failures ([457fb30](https://github.com/patrickisgreat/binthere/commit/457fb3045379dc17c7466185d8deaf65dfda5fed))
* run only unit tests in CI, skip UI tests ([a55b36b](https://github.com/patrickisgreat/binthere/commit/a55b36b2861d960beb38cd119e47f6ca02e6ba39))
