# Bundled browser database runtime

These free runtime assets are copied into `web/` by `tool/bootstrap.dart`.
No runtime CDN is used for the database engine.

- sqlite3.wasm: official sqlite3.dart release sqlite3-3.8.0
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.8.0/sqlite3.wasm
  SHA-256 efd308be92a34f3aa15f289a37f213b0230fd80888a1364326ee29579d892d37
- drift_worker.js: drift 2.35.3 package from pub.dev
  SHA-256 a54b81412d4c4ab56653bb9e4c02912b0820bb37e2bba00722ddef4d78083d4a

Associated package licenses are included. SQLite itself is public domain.
Update the pinned package versions and matching runtime assets together.
