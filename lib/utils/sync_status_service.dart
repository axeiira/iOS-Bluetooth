import 'package:flutter/material.dart';

enum SyncStatus { idle, syncing, completed, error }

class SyncStatusService extends ValueNotifier<SyncStatus> {
  SyncStatusService._privateConstructor() : super(SyncStatus.idle);
  static final SyncStatusService instance = SyncStatusService._privateConstructor();

  void updateStatus(SyncStatus newStatus) {
    value = newStatus;
  }
}