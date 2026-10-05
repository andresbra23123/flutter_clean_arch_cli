import 'package:flutter_clean_arch/flutter_clean_arch.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureName.parse', () {
    test('single word', () {
      final n = FeatureName.parse('songs');
      expect(n.snake, 'songs');
      expect(n.pascal, 'Songs');
      expect(n.camel, 'songs');
      expect(n.title, 'Songs');
      expect(n.lowerWords, 'songs');
    });

    for (final input in [
      'user_profile',
      'UserProfile',
      'user-profile',
      'userProfile',
      'user profile',
    ]) {
      test('"$input" gives every case of user_profile', () {
        final n = FeatureName.parse(input);
        expect(n.snake, 'user_profile');
        expect(n.pascal, 'UserProfile');
        expect(n.camel, 'userProfile');
        expect(n.title, 'User profile');
        expect(n.lowerWords, 'user profile');
      });
    }

    for (final input in ['', '1songs', r'so$ngs', 'class', 'core', 'home']) {
      test('rejects "$input"', () {
        expect(() => FeatureName.parse(input), throwsFormatException);
      });
    }

    test('allowTaken accepts names used by the base structure', () {
      expect(FeatureName.parse('home', allowTaken: true).pascal, 'Home');
      expect(
        () => FeatureName.parse('class', allowTaken: true),
        throwsFormatException,
      );
    });
  });

  test('todoTagFromPackage', () {
    expect(todoTagFromPackage('demo_app'), 'demo-app');
  });

  test('appTitleFromPackage', () {
    expect(appTitleFromPackage('demo_app'), 'Demo App');
    expect(appTitleFromPackage('music_player'), 'Music Player');
  });
}
