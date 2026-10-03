# Windows first-region preview validation candidate

Runtime starts from delivered Mac v46 d1eb0f1; this patch changes validation/packaging only. The existing Windows smoke keeps ordinary mode and gains --preview-label. It exports a disposable project copy with the same field_preview_entry and shared v45 save namespace, leaving original checkout bytes intact for the following historical price-trial tests.

Native Windows 2022 runner is required; this is not a Linux/Wine substitute. Official archives retain SHA-512 verification. AppData/LocalAppData and all seeded data live under newly created runner scratch. A marker/schema/slot/path guard protects fixture writes. Pure helper tests run before the native export.

The planned result covers default camp, temple circuit, jungle south circuit, wetland construction sample and the playable wetland run through the fixed packaged whitelist. Remapped scene resource plus the existing Hybrid ready marker are required. Gameplay scenes must advance generation with a new launch ID without granting settlement. The construction sample must leave shared record bytes unchanged. Only the last wetland start receives explicit synthetic prior access in runner-owned v7 slots; it is not natural campaign completion.

Only standalone deployment outputs are zipped. The archive is extracted into a fresh folder and the exported GUI exe is restarted with another new AppData home. The workflow uploads that ZIP and reports. Nine pure guard checks and Python compilation passed locally; native Windows results remain pending until the PR workflow succeeds. User-device GUI/SmartScreen/graphics/sound/input/long-session/gameplay acceptance remain unverified.

## Verified result

Head8b66552 native Windows run37092592039 and full Godot verification37092591993 passed. PR45 was reviewed and merged into production as a0796ee. Only packaging/validation files differ from delivered v46 runtime d1eb0f1. Source project bytes remained unchanged.

All five requested starts succeeded. Temple started shared generation1 with0 currency and no conquests, jungle advanced to2 without a dev clear, construction sample kept both shared records unchanged. Only then did the runner seed prior access, and playable wetland advanced generation2→3 with a new launch ID and no settlement/currency grant.

Verified ZIP:36,465,337 bytes, SHA256562740c81dfb1ff15e17e3bf1a398cddee47a9d2c24a479225380628b21a76ee. It contains LoopConquest.exe and PLAYTEST.txt only, no fixture records. Extraction preserved executable bytes; extracted release loaded the packed camp under another fresh APPDATA. Windows archive is prepared, not evidence of user download or device play.

Price-trial guards:7passed,2 historical pre-v7 engine cases intentionally skipped. User-device GUI/SmartScreen/graphics/audio/input/long-session acceptance remains open.
