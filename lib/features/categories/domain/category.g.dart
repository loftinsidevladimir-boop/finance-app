// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryImpl _$$CategoryImplFromJson(Map<String, dynamic> json) =>
    _$CategoryImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      type: json['type'] as String? ?? 'expense',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isSystem: json['is_system'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      userId: json['user_id'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$CategoryImplToJson(_$CategoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'icon': instance.icon,
      'color': instance.color,
      'type': instance.type,
      'sort_order': instance.sortOrder,
      'is_system': instance.isSystem,
      'is_archived': instance.isArchived,
      'user_id': instance.userId,
      'created_at': instance.createdAt?.toIso8601String(),
    };
