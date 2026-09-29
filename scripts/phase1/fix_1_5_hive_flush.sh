#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.5 — Hive flush after every write"

require_repo_root
require_clean_tree

OUTBOX="lib/core/storage/outbox/outbox_store.dart"
KV="lib/core/storage/key_value_store.dart"
NOTES="lib/features/cycles/data/local/cycle_notes_cache.dart"

backup_file "$OUTBOX"
backup_file "$KV"
backup_file "$NOTES"

# ── outbox_store.dart — full rewrite ──────────────────────────────────
cat > "$OUTBOX" <<'DART'
import 'package:hive/hive.dart';

import 'outbox_item.dart';
import 'outbox_status.dart';

class OutboxStore {
  static const _boxName = 'steriymed.outbox';
  final Box<dynamic> _box;

  OutboxStore(this._box);

  static Future<OutboxStore> open() async {
    final box = await Hive.openBox(_boxName);
    return OutboxStore(box);
  }

  Future<void> enqueue(OutboxItem item) async {
    await _box.put(item.id, item.toJson());
    await _box.flush();
  }

  List<OutboxItem> all() =>
      _box.values
          .map((e) => OutboxItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<OutboxItem> pending() =>
      all().where((i) => i.status == OutboxStatus.pending).toList();

  List<OutboxItem> manualReview() =>
      all().where((i) => i.status == OutboxStatus.manualReview).toList();

  int get pendingCount => pending().length;

  Future<void> update(OutboxItem item) async {
    await _box.put(item.id, item.toJson());
    await _box.flush();
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
    await _box.flush();
  }

  Future<void> removeMany(Iterable<String> ids) async {
    for (final id in ids) {
      await _box.delete(id);
    }
    await _box.flush();
  }

  Future<void> clear() async {
    await _box.clear();
    await _box.flush();
  }
}
DART
ok "Rewrote $OUTBOX"

# ── key_value_store.dart — full rewrite ───────────────────────────────
cat > "$KV" <<'DART'
import 'package:hive_flutter/hive_flutter.dart';

class KeyValueStore {
  final Box<dynamic> _box;

  KeyValueStore(this._box);

  static Future<KeyValueStore> open(String name) async {
    final box = await Hive.openBox(name);
    return KeyValueStore(box);
  }

  dynamic get(String key) => _box.get(key);

  Future<void> set(String key, dynamic value) async {
    await _box.put(key, value);
    await _box.flush();
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
    await _box.flush();
  }

  Future<void> clear() async {
    await _box.clear();
    await _box.flush();
  }
}
DART
ok "Rewrote $KV"

# ── cycle_notes_cache.dart — add flush() to save/remove ───────────────
python3 - "$NOTES" <<'PYEOF'
import sys, io

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

# save
src = src.replace(
    "await _box!.put(cycleId, jsonEncode({'notes': notes}));",
    "await _box!.put(cycleId, jsonEncode({'notes': notes}));\n    await _box!.flush();",
)
# remove
src = src.replace(
    "await _box!.delete(cycleId);",
    "await _box!.delete(cycleId);\n    await _box!.flush();",
)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Updated flush() calls in cycle_notes_cache.dart")
PYEOF

run_analyze
run_tests
commit_fix "fix(storage): flush Hive after every write — never lose queued work" "$OUTBOX" "$KV" "$NOTES"

ok "FIX 1.5 complete"