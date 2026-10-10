import 'package:flutter/material.dart';

class EnrollmentLivenessProgress extends StatelessWidget {
  const EnrollmentLivenessProgress({super.key, required this.completedSteps});

  final int completedSteps;

  @override
  Widget build(BuildContext context) {
    const labels = ['Blink', 'Turn Left', 'Turn Right'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            Flexible(
              child: Semantics(
                label:
                    '${labels[i]}: ${i < completedSteps
                        ? "complete"
                        : i == completedSteps
                        ? "current step"
                        : "pending"}',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        i < completedSteps
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 20,
                        color: i < completedSteps
                            ? const Color(0xFF22C55E)
                            : i == completedSteps
                            ? const Color(0xFF60A5FA)
                            : Colors.white54,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
