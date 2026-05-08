class InteractionPair {
  final String drug1;
  final String drug2;
  final String severity; // Major | Moderate | Minor
  final String description;
  final String action;

  InteractionPair({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.description,
    required this.action,
  });

  factory InteractionPair.fromJson(Map<String, dynamic> j) => InteractionPair(
        drug1: j['drug1'] as String? ?? '',
        drug2: j['drug2'] as String? ?? '',
        severity: j['severity'] as String? ?? 'Minor',
        description: j['description'] as String? ?? '',
        action: j['action'] as String? ?? '',
      );
}

class DrugInteractionResult {
  final List<InteractionPair> interactions;
  final String overallRisk; // High | Medium | Low | None
  final String summary;

  DrugInteractionResult({
    required this.interactions,
    required this.overallRisk,
    required this.summary,
  });

  factory DrugInteractionResult.fromJson(Map<String, dynamic> j) {
    final rawList = j['interactions'] as List? ?? [];
    return DrugInteractionResult(
      interactions:
          rawList.map((e) => InteractionPair.fromJson(e)).toList(),
      overallRisk: j['overall_risk'] as String? ?? 'None',
      summary: j['summary'] as String? ?? '',
    );
  }

  bool get hasInteractions => interactions.isNotEmpty;
}
