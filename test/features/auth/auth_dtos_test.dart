import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/error/app_exception.dart';
import 'package:rayuela_mobile/features/auth/data/models/auth_dtos.dart';

void main() {
  group('LoginResponseDto', () {
    test('parses backend snake_case shape', () {
      final dto = LoginResponseDto.fromJson({
        'access_token': 'jwt.here',
        'username': 'fran',
      });
      expect(dto.accessToken, 'jwt.here');
      expect(dto.username, 'fran');
      expect(dto.refreshToken, isNull);
    });

    test('parses future camelCase shape with refresh', () {
      final dto = LoginResponseDto.fromJson({
        'accessToken': 'jwt.here',
        'refreshToken': 'rfr',
        'expiresIn': 900,
      });
      expect(dto.accessToken, 'jwt.here');
      expect(dto.refreshToken, 'rfr');
      expect(dto.expiresIn, 900);
    });

    test('throws ValidationException when no token present', () {
      expect(
        () => LoginResponseDto.fromJson(<String, dynamic>{'username': 'x'}),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws ValidationException when payload is not a map', () {
      expect(
        () => LoginResponseDto.fromJson('garbage'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('UserDto — underscore-leak shape (today\'s backend)', () {
    test('parses User entity with private underscore fields', () {
      final dto = UserDto.fromJson({
        '_id': 'u1',
        '_username': 'fran',
        '_completeName': 'Fran Perez',
        '_email': 'fran@example.com',
        '_role': 'Volunteer',
        '_profileImage': 'https://cdn/p.png',
        '_verified': true,
        '_gameProfiles': [
          {
            'projectId': 'p1',
            'points': 42,
            'badges': ['First check-in'],
            'active': true,
          },
        ],
      });
      expect(dto.id, 'u1');
      expect(dto.username, 'fran');
      expect(dto.completeName, 'Fran Perez');
      expect(dto.email, 'fran@example.com');
      expect(dto.role, 'Volunteer');
      expect(dto.profileImage, 'https://cdn/p.png');
      expect(dto.verified, isTrue);
      expect(dto.gameProfiles, hasLength(1));
      expect(dto.gameProfiles.single.projectId, 'p1');
      expect(dto.gameProfiles.single.points, 42);
      expect(dto.gameProfiles.single.badges, ['First check-in']);
    });

    test('parses cleaned shape (post backend §4.1) too', () {
      final dto = UserDto.fromJson({
        'id': 'u1',
        'username': 'fran',
        'completeName': 'Fran Perez',
        'email': 'fran@example.com',
        'role': 'Volunteer',
        'profileImage': null,
        'verified': false,
        'gameProfiles': <dynamic>[],
      });
      expect(dto.id, 'u1');
      expect(dto.username, 'fran');
      expect(dto.profileImage, isNull);
      expect(dto.verified, isFalse);
      expect(dto.gameProfiles, isEmpty);
    });

    test('falls back gracefully when fields are missing', () {
      // Earlier crash repro: every required key is null.
      final dto = UserDto.fromJson(<String, dynamic>{});
      expect(dto.id, '');
      expect(dto.username, '');
      expect(dto.role, 'Volunteer'); // sane default
      expect(dto.verified, isFalse);
    });

    test('coerces numeric verified flags', () {
      final dto = UserDto.fromJson({'_verified': 1});
      expect(dto.verified, isTrue);
    });

    test('toEntity falls back completeName to username when blank', () {
      final user = UserDto.fromJson({
        '_username': 'fran',
        '_completeName': '',
        '_role': 'Volunteer',
      }).toEntity();
      expect(user.completeName, 'fran');
    });
  });
}
