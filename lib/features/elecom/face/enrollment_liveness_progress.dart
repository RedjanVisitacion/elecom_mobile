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
        color: const Color(0xFF1A202C).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: Colors.white38,
              ),
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
                            ? const Color(0xFF72E8DD)
                            : i == completedSteps
                            ? const Color(0xFF00F0FF)
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
        ],
      ),
    );
  }
}
