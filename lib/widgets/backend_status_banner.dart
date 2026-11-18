import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../core/config/deposit_config.dart';

/// Slim amber banner that appears at the top of dashboards when a backend
/// call has failed and the app is showing demo/mock data.
class BackendStatusBanner extends StatelessWidget {
  const BackendStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SupabaseService.lastBackendError,
      builder: (context, error, _) {
        if (error == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFFFEF3C7), // amber-100
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 14, color: Color(0xFF92400E)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kDevTools
                      ? 'Backend problem, showing demo data. ($error)'
                      : 'Backend problem, showing demo data.',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
