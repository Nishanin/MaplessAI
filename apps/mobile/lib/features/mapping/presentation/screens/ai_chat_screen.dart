import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../ai/domain/semantic_knowledge_graph.dart';
import '../../../ai/state/ai_controller.dart';
import '../../state/mapping_controller.dart';

/// Conversational SLM Navigation Screen
/// Owner: Nishant (Presentation layer consuming Surabhi's aiProvider)
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();

  SemanticKnowledgeGraph _buildKnowledgeGraph() {
    final mappingState = ref.read(mappingProvider);
    final kg = SemanticKnowledgeGraph();
    for (final meta in mappingState.metadata) {
      kg.addMetadata(meta);
    }
    return kg;
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final mappingState = ref.read(mappingProvider);
    final kg = _buildKnowledgeGraph();

    ref.read(aiProvider.notifier).submitQuery(
          text,
          mappingState.building?.id ?? 'vit-ce',
          kg,
          currentNodeId: mappingState.visitorCurrentNodeId,
        );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiProvider);

    return AppScaffold(
      title: 'MapLess AI Assistant',
      body: Column(
        children: [
          // Security disclaimer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.amber.shade50,
            child: const Row(
              children: [
                Icon(Icons.security, size: 16, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Queries are parsed via SLM into validated structured operations (No direct SQL).',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: aiState.messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Ask for directions or room details:\n'
                        '• "Where is the nearest computer lab?"\n'
                        '• "Show me the emergency exit"\n'
                        '• "Take me to the library"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, height: 1.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: aiState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = aiState.messages[index];
                      return _ChatBubble(message: msg);
                    },
                  ),
          ),

          if (aiState.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type your navigation request...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            if (message.response != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Intent: ${message.response!.intent} (${(message.response!.confidence * 100).round()}%)',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
