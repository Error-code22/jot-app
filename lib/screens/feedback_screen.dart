import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  FeedbackType _type = FeedbackType.bug;
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<FeedbackItem> _myFeedback = [];

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    final feedback = Provider.of<FeedbackService>(context, listen: false);
    final items = await feedback.getMyFeedback();
    if (mounted) setState(() { _myFeedback = items; _isLoading = false; });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final feedback = Provider.of<FeedbackService>(context, listen: false);
      await feedback.submit(
        type: _type,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      _titleController.clear();
      _descriptionController.clear();
      await _loadFeedback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted! Thank you for your feedback.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bug Reports & Features', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Submit form
          Text('Submit Feedback', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Type toggle
                SegmentedButton<FeedbackType>(
                  segments: const [
                    ButtonSegment(value: FeedbackType.bug, label: Text('Bug'), icon: Icon(Icons.bug_report_outlined)),
                    ButtonSegment(value: FeedbackType.feature, label: Text('Feature'), icon: Icon(Icons.lightbulb_outline)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'Brief summary...'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What happened? What did you expect?',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // My submissions
          Text('My Submissions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_myFeedback.isEmpty)
            const Text('No submissions yet.', style: TextStyle(color: Colors.grey))
          else
            ..._myFeedback.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  item.type == FeedbackType.bug ? Icons.bug_report : Icons.lightbulb,
                  color: item.type == FeedbackType.bug ? Colors.orange : Colors.green,
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(item.status, style: TextStyle(fontSize: 11, color: _statusColor(item.status))),
                ),
              ),
            )),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open': return Colors.blue;
      case 'in_progress': return Colors.orange;
      case 'resolved': return Colors.green;
      case 'closed': return Colors.grey;
      default: return Colors.grey;
    }
  }
}
