class WindowSystem {
  final int? id;
  final String name;
  final int sortOrder;
  final double unitPrice;
  final List<WindowSeries> series;

  WindowSystem({
    this.id,
    required this.name,
    this.sortOrder = 0,
    this.unitPrice = 0.0,
    this.series = const [],
  });

  factory WindowSystem.fromMap(Map<String, dynamic> map) {
    return WindowSystem(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WindowSeries {
  final int? id;
  final int systemId;
  final String name;
  final int sortOrder;
  final double unitPrice;
  final List<WindowColor> colors;

  WindowSeries({
    this.id,
    required this.systemId,
    required this.name,
    this.sortOrder = 0,
    this.unitPrice = 0.0,
    this.colors = const [],
  });

  factory WindowSeries.fromMap(Map<String, dynamic> map) {
    return WindowSeries(
      id: map['id'] as int?,
      systemId: map['system_id'] as int,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WindowColor {
  final int? id;
  final int seriesId;
  final String name;
  final int sortOrder;
  final double unitPrice;

  WindowColor({
    this.id,
    required this.seriesId,
    required this.name,
    this.sortOrder = 0,
    this.unitPrice = 0.0,
  });

  factory WindowColor.fromMap(Map<String, dynamic> map) {
    return WindowColor(
      id: map['id'] as int?,
      seriesId: map['series_id'] as int,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
