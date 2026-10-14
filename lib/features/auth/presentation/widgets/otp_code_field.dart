import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _code() => _controllers.map((c) => c.text).join();

  void _emit() {
    final code = _code();
    widget.onChanged?.call(code);
    final complete = _controllers.every((c) => c.text.isNotEmpty);
    if (complete) {
      widget.onCompleted?.call(code);
    }
  }

  void _applyPaste({required int startIndex, required String digits}) {
    if (digits.isEmpty) return;
    _updating = true;
    try {
      for (var k = startIndex; k < widget.length; k++) {
        _controllers[k].text = '';
      }

      for (var j = 0; j < digits.length && startIndex + j < widget.length; j++) {
        final idx = startIndex + j;
        _controllers[idx].text = digits[j];
        _controllers[idx].selection = const TextSelection.collapsed(offset: 1);
      }
    } finally {
      _updating = false;
    }

    final nextIndex = startIndex + digits.length;
    if (nextIndex >= widget.length) {
      _focusNodes[widget.length - 1].unfocus();
    } else {
      _focusNodes[nextIndex].requestFocus();
    }

    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (i) {
          final isLast = i == widget.length - 1;
          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: SizedBox(
              width: 44,
              height: 54,
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                expands: true,
                keyboardType: TextInputType.number,
                maxLines: null,
                minLines: null,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  height: 1.0,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: Color(0xffef233c), width: 1.6),
                  ),
                ),
                onChanged: (v) {
                  if (_updating) return;

                  final digits = v.replaceAll(RegExp(r'\\D'), '');
                  if (digits.length > 1) {
                    _applyPaste(startIndex: i, digits: digits);
                    return;
                  }

                  if (v != digits) {
                    _updating = true;
                    try {
                      _controllers[i].text = digits;
                      _controllers[i].selection = TextSelection.collapsed(offset: digits.length);
                    } finally {
                      _updating = false;
                    }
                  }

                  if (v.isEmpty) {
                    if (i > 0) {
                      _focusNodes[i - 1].requestFocus();
                      _controllers[i - 1].selection = TextSelection.fromPosition(
                        TextPosition(offset: _controllers[i - 1].text.length),
                      );
                    }
                    _emit();
                    return;
                  }

                  if (!isLast) {
                    _focusNodes[i + 1].requestFocus();
                  } else {
                    _focusNodes[i].unfocus();
                  }

                  _emit();
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}
