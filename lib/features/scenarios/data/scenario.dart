enum ScenarioStatus { draft, confirmed, discarded }

extension ScenarioStatusX on ScenarioStatus {
  String get label => switch (this) {
    ScenarioStatus.draft => 'Rascunho',
    ScenarioStatus.confirmed => 'Confirmado',
    ScenarioStatus.discarded => 'Descartado',
  };

  static ScenarioStatus fromApi(String value) => switch (value) {
    'draft' => ScenarioStatus.draft,
    'confirmed' => ScenarioStatus.confirmed,
    'discarded' => ScenarioStatus.discarded,
    _ => throw ArgumentError('Unknown scenario status: $value'),
  };
}

class Scenario {
  const Scenario({required this.id, required this.name, this.description, required this.status});

  final String id;
  final String name;
  final String? description;
  final ScenarioStatus status;

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: ScenarioStatusX.fromApi(json['status'] as String),
    );
  }
}

class ProjectionDay {
  const ProjectionDay({required this.date, required this.balance, required this.deficit});

  final DateTime date;
  final String balance;
  final bool deficit;

  factory ProjectionDay.fromJson(Map<String, dynamic> json) {
    return ProjectionDay(
      date: DateTime.parse(json['date'] as String),
      balance: json['balance'] as String,
      deficit: json['deficit'] as bool,
    );
  }
}

class SavingsImpact {
  const SavingsImpact({
    required this.entradas,
    required this.economiaBefore,
    required this.economiaAfter,
    required this.percentBefore,
    required this.percentAfter,
  });

  final String entradas;
  final String economiaBefore;
  final String economiaAfter;
  final String percentBefore;
  final String percentAfter;

  factory SavingsImpact.fromJson(Map<String, dynamic> json) {
    return SavingsImpact(
      entradas: json['entradas'] as String,
      economiaBefore: json['economiaBefore'] as String,
      economiaAfter: json['economiaAfter'] as String,
      percentBefore: json['percentBefore'] as String,
      percentAfter: json['percentAfter'] as String,
    );
  }
}

class ScenarioProjection {
  const ScenarioProjection({
    required this.before,
    required this.after,
    required this.deficitDaysBefore,
    required this.deficitDaysAfter,
    required this.savingsImpact,
  });

  final List<ProjectionDay> before;
  final List<ProjectionDay> after;
  final int deficitDaysBefore;
  final int deficitDaysAfter;
  final SavingsImpact savingsImpact;

  factory ScenarioProjection.fromJson(Map<String, dynamic> json) {
    return ScenarioProjection(
      before: (json['before'] as List).map((d) => ProjectionDay.fromJson(d as Map<String, dynamic>)).toList(),
      after: (json['after'] as List).map((d) => ProjectionDay.fromJson(d as Map<String, dynamic>)).toList(),
      deficitDaysBefore: json['deficitDaysBefore'] as int,
      deficitDaysAfter: json['deficitDaysAfter'] as int,
      savingsImpact: SavingsImpact.fromJson(json['savingsImpact'] as Map<String, dynamic>),
    );
  }
}
