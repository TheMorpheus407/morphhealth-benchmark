import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../model/dataset.dart';
import '../model/record.dart';
import '../model/settings.dart';
import '../storage/encrypted_store.dart';
import '../util/clock.dart';

/// A single change inside a batch.
sealed class Change {
  const Change(this.collection);
  final Collection collection;
}

class PutChange extends Change {
  const PutChange(super.collection, this.record);
  final Record record;
}

class DeleteChange extends Change {
  const DeleteChange(super.collection, this.id);
  final String id;
}

/// Encodes a snapshot; the app runs this in a background isolate.
typedef SnapshotEncoder =
    Future<Uint8List> Function(SnapshotJob job, StoreContents contents);

Future<Uint8List> _encodeInline(SnapshotJob job, StoreContents contents) async =>
    job.encode(contents);

/// Holds the data set in memory and persists every change to the encrypted
/// store before it becomes visible. All writes are serialized.
class Repository {
  Repository._(
    this._store,
    this.contents,
    this.clock,
    this._encoder,
    this.openWarnings,
  );

  static Future<Repository> open({
    required Directory directory,
    required List<int> masterKey,
    required Clock clock,
    SnapshotEncoder? encoder,
    SnapshotDecoder? decoder,
  }) async {
    final opened = await EncryptedStore.open(
      directory,
      masterKey,
      now: clock.nowUtc(),
      decoder: decoder,
    );
    return Repository._(
      opened.store,
      opened.contents,
      clock,
      encoder ?? _encodeInline,
      opened.warnings,
    );
  }

  final EncryptedStore _store;
  final StoreContents contents;
  final Clock clock;
  final SnapshotEncoder _encoder;

  /// Problems that were repaired while opening the store.
  final List<String> openWarnings;

  Dataset get data => contents.dataset;
  DeviceState get device => contents.device;
  Directory get directory => _store.directory;

  final List<void Function()> _listeners = [];
  Future<void> _queue = Future.value();
  bool _closed = false;

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    if (_closed) return Future.error(StateError('Repository is closed'));
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Validates the operation, makes it durable in the journal and only then
  /// applies it in memory, so the journal never contains invalid records.
  Future<void> _appendAndApply(Map<String, Object?> operation) =>
      _enqueue(() async {
        final apply = prepareOperation(operation, now: clock.nowUtc());
        await _store.append(operation);
        apply(contents);
        _notify();
        if (_store.needsCompaction) await _compact();
      });

  Future<void> put(Collection collection, Record record) =>
      _appendAndApply(putOperation(collection, record.toJson()));

  Future<void> delete(Collection collection, String id) =>
      _appendAndApply(deleteOperation(collection, id));

  /// Applies several changes atomically (one journal record).
  Future<void> batch(List<Change> changes) {
    if (changes.isEmpty) return Future.value();
    return _appendAndApply(
      batchOperation([
        for (final c in changes)
          switch (c) {
            PutChange() => putOperation(c.collection, c.record.toJson()),
            DeleteChange() => deleteOperation(c.collection, c.id),
          },
      ]),
    );
  }

  Future<void> updateSettings(Settings settings) =>
      _appendAndApply(settingsOperation(settings.toJson()));

  Future<void> updateDevice(DeviceState device) =>
      _appendAndApply(deviceOperation(device));

  /// Replaces the whole data set (import / restore) with a new snapshot.
  Future<void> replaceAll(Dataset replacement) => _enqueue(() async {
    final next = StoreContents(replacement, contents.device);
    final job = _store.prepareSnapshotJob(clock.nowUtc());
    final bytes = await _encoder(job, next);
    await _store.writeSnapshot(next, now: clock.nowUtc(), preEncoded: bytes);
    contents.dataset.replaceWith(replacement);
    _notify();
  });

  /// Writes a fresh snapshot and truncates the journal.
  Future<void> compact() => _enqueue(_compact);

  Future<void> _compact() async {
    final job = _store.prepareSnapshotJob(clock.nowUtc());
    final bytes = await _encoder(job, contents);
    await _store.writeSnapshot(contents, now: clock.nowUtc(), preEncoded: bytes);
  }

  /// Waits for pending writes and releases the store.
  Future<void> close() async {
    if (_closed) return;
    final done = _enqueue(() async {});
    _closed = true;
    await done;
    await _store.close();
    _listeners.clear();
  }
}
