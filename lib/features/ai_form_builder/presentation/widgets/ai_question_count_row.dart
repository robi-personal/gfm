import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design.dart';

class AiQuestionCountRow extends StatefulWidget {
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const AiQuestionCountRow({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<AiQuestionCountRow> createState() => _AiQuestionCountRowState();
}

class _AiQuestionCountRowState extends State<AiQuestionCountRow> {
  late final TextEditingController _controller;

  static const _min = 3;
  static const _max = 50;
  static const _default = 10;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? '${widget.value}' : '$_default',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _current => widget.value ?? _default;

  void _increment() {
    final next = (_current + 1).clamp(_min, _max);
    _controller.text = '$next';
    widget.onChanged(next);
  }

  void _decrement() {
    final next = (_current - 1).clamp(_min, _max);
    _controller.text = '$next';
    widget.onChanged(next);
  }

  void _onFieldSubmitted(String raw) {
    final n = int.tryParse(raw);
    if (n == null) {
      _controller.text = '$_current';
      return;
    }
    final clamped = n.clamp(_min, _max);
    _controller.text = '$clamped';
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Number of questions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
        ),
        const Spacer(),
        _StepperButton(
          icon: CupertinoIcons.minus,
          enabled: widget.enabled && _current > _min,
          onTap: _decrement,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.purple600, width: 1.5),
              ),
            ),
            onSubmitted: _onFieldSubmitted,
            onTapOutside: (_) => _onFieldSubmitted(_controller.text),
          ),
        ),
        const SizedBox(width: 8),
        _StepperButton(
          icon: CupertinoIcons.plus,
          enabled: widget.enabled && _current < _max,
          onTap: _increment,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? AppColors.purple50 : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.purple600 : AppColors.muted2,
        ),
      ),
    );
  }
}
