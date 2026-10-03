# Garden transition fixture follow-up

Fix / tested SHA: `d589595f7300acb52741ef4d3811d8ecae3a6118`. This changes only `tests/verify_garden_transition.gd`; product code remains identical to the prior source.

GitHub run37124127208 at6dc3fcf produced two garden failures. Its actual artifact11274389007 and Mac reproduction contain the same failures: exit position and actor restoration. The fixture teleported directly onto the exit, forced cooldown to zero, then ticked without movement input. The arrival latch intentionally rejects that neutral transition, so neither exit nor actor restoration occurred. This observed failure is a stale fixture assumption, rather than a failed intentional player return.

The fixture now uses normal player physics and movement actions to walk RETURN→ENTRY, FIELD_ENTRY→EXIT and RETURN→ENTRY. Clock progression stays explicit; combat pressure is frozen only in the fixture. It removes the forced cooldown and direct enter call, retains every original assertion, and adds release-only no-return and actor-count preservation assertions. It never mutates the latch or changes the product.

Official Mac Godot4.6 headless results on the fix SHA:

- Exact source, no parent mounts/final art: garden transition PASS using the default physics scheduler (same CLI mode as CI). All117 game `.gd`/`.tscn` files in the disposable copy matched the branch at this execution.
- Two existing parent mounts, without final art: garden transition PASS with default physics; hidden flow290 checks/0 failures; temple section0 failures with fixed-fps60.
- Unique private userdata, one headless process at a time;56 protected normal/preview JSON files remain byte-identical. No GUI or render rerun.

See `fixture-followup-report.json` for source hashes and adjacent `.txt` logs for actual output. This is source and existing-mount evidence. Parent final art assembly, the separate waterfall descendant fixture and aggregate CI remain unverified here; no final assembled PASS is claimed.

Progress:3단계 첫 권역·히든출입/표기 / 완료: 낡은정원fixture정상입력수정·관련headless / 다음: 통합담당mount+아트합본·fullCI / 사용자확인: 자연플레이·장소감·미감미검증.
