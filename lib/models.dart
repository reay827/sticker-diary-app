import 'dart:math' as math;
import 'package:uuid/uuid.dart';

const uuid = Uuid();
String dateLabel(DateTime value) =>
    '${value.year}년 ${value.month}월 ${value.day}일';
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class Sticker {
  const Sticker({
    required this.id,
    required this.fileName,
    required this.name,
    required this.takenOn,
    required this.createdAt,
    this.visible = true,
  });
  final String id, fileName, name;
  final DateTime? takenOn;
  final DateTime createdAt;
  final bool visible;

  Sticker edit({String? name, DateTime? takenOn, bool? visible}) => Sticker(
    id: id,
    fileName: fileName,
    name: name ?? this.name,
    takenOn: takenOn ?? this.takenOn,
    createdAt: createdAt,
    visible: visible ?? this.visible,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'name': name,
    'takenOn': takenOn?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'visible': visible,
  };
  factory Sticker.fromJson(Map<String, dynamic> j) => Sticker(
    id: j['id'] as String,
    fileName: j['fileName'] as String,
    name: j['name'] as String,
    takenOn: j['takenOn'] == null
        ? null
        : DateTime.parse(j['takenOn'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
    visible: j['visible'] as bool,
  );
}

class Placement {
  Placement({
    required this.id,
    required this.stickerId,
    this.x = .5,
    this.y = .55,
    this.width = .3,
    this.angle = 0,
  });
  final String id, stickerId;
  double x, y, width, angle;
  Placement copy() => Placement(
    id: id,
    stickerId: stickerId,
    x: x,
    y: y,
    width: width,
    angle: angle,
  );
  void move(double dx, double dy) {
    x = (x + dx).clamp(.03, .97);
    y = (y + dy).clamp(.03, .97);
  }

  void resize(double value) {
    width = value.clamp(.12, .65);
  }

  void rotate(double value) {
    angle = value % (2 * math.pi);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'stickerId': stickerId,
    'x': x,
    'y': y,
    'width': width,
    'angle': angle,
  };
  factory Placement.fromJson(Map<String, dynamic> j) => Placement(
    id: j['id'] as String,
    stickerId: j['stickerId'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    width: (j['width'] as num).toDouble(),
    angle: (j['angle'] as num).toDouble(),
  );
}

class Diary {
  Diary({
    required this.id,
    required this.date,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.placements,
  });
  final String id;
  DateTime date;
  String body;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<Placement> placements;
  factory Diary.empty() {
    final now = DateTime.now();
    return Diary(
      id: uuid.v4(),
      date: dateOnly(now),
      body: '',
      createdAt: now,
      updatedAt: now,
      placements: [],
    );
  }
  Diary copy() => Diary(
    id: id,
    date: date,
    body: body,
    createdAt: createdAt,
    updatedAt: updatedAt,
    placements: placements.map((p) => p.copy()).toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'placements': placements.map((p) => p.toJson()).toList(),
  };
  factory Diary.fromJson(Map<String, dynamic> j) => Diary(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    body: j['body'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    placements: (j['placements'] as List)
        .map((p) => Placement.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
  );
}
