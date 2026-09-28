import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingMessagesNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  PendingMessagesNotifier() : super([]);

  void addMessage(Map<String, dynamic> message) {
    state = [message, ...state];
  }

  void removeMessage(String tempId) {
    state = state.where((m) => m['id'] != tempId).toList();
  }

  void updateMessage(String tempId, Map<String, dynamic> updates) {
    state = state.map((m) {
      if (m['id'] == tempId) {
        return {...m, ...updates};
      }
      return m;
    }).toList();
  }
}

final pendingMessagesProvider = StateNotifierProvider.autoDispose
    .family<PendingMessagesNotifier, List<Map<String, dynamic>>, String>((
      ref,
      conversationId,
    ) {
      return PendingMessagesNotifier();
    });

class DeletedChatMessagesNotifier extends StateNotifier<Set<String>> {
  DeletedChatMessagesNotifier() : super({});

  void markDeleted(String messageId) {
    state = {...state, messageId};
  }

  void unmark(String messageId) {
    if (!state.contains(messageId)) return;
    state = {...state}..remove(messageId);
  }
}

final deletedChatMessagesProvider = StateNotifierProvider.autoDispose
    .family<DeletedChatMessagesNotifier, Set<String>, String>(
      (ref, conversationId) => DeletedChatMessagesNotifier(),
    );
