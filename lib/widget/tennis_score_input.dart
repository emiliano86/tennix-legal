import 'package:flutter/material.dart';

class TennisScoreInputField extends StatelessWidget {
  final TextEditingController controller;
  final String playerName;
  final bool enabled;
  final Function(String)? onChanged;

  const TennisScoreInputField({
    super.key,
    required this.controller,
    required this.playerName,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        children: [
          Text(
            playerName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                hintText: '0',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
