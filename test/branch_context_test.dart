import 'package:flutter_test/flutter_test.dart';
import 'package:trexvenpos/src/features/auth/branch_context.dart';
import 'package:trexvenpos/src/models/business.dart';

void main() {
  const a = AuthorizedBranch(id: 'a', businessId: 'business', name: 'A');
  const b = AuthorizedBranch(id: 'b', businessId: 'business', name: 'B');
  test('No branch is selected automatically, even with one assignment', () {
    final context = BranchContext('business');
    expect(context.state, isNull);
    context.select(a, [a], hasCart: false);
    expect(context.state?.id, 'a');
    context.dispose();
  });
  test(
    'Multiple assignments allow explicit selection only within those assignments',
    () {
      final context = BranchContext('business');
      context.select(a, [a, b], hasCart: false);
      context.select(b, [a, b], hasCart: false);
      expect(context.state?.id, 'b');
      const forbidden = AuthorizedBranch(
        id: 'c',
        businessId: 'business',
        name: 'C',
      );
      expect(
        () => context.select(forbidden, [a, b], hasCart: false),
        throwsStateError,
      );
      expect(context.state?.id, 'b');
      context.dispose();
    },
  );
  test('Forged cross-business branch cannot become current context', () {
    final context = BranchContext('business');
    const other = AuthorizedBranch(
      id: 'other',
      businessId: 'other-business',
      name: 'Other',
    );
    expect(
      () => context.select(other, [other], hasCart: false),
      throwsStateError,
    );
    expect(context.state, isNull);
    context.dispose();
  });
  test(
    'Unfinished cart prevents switching and clearing its original branch',
    () {
      final context = BranchContext('business');
      context.select(a, [a, b], hasCart: false);
      expect(() => context.select(b, [a, b], hasCart: true), throwsStateError);
      expect(() => context.clear(hasCart: true), throwsStateError);
      expect(context.state?.id, 'a');
      context.clear(hasCart: false);
      expect(context.state, isNull);
      context.dispose();
    },
  );
  test('Legacy business payload does not activate branches', () {
    final legacy = Business.fromJson({'id': 'business'});
    expect(legacy.branchesEnabled, isFalse);
    expect(legacy.toJson().containsKey('branches_enabled'), isFalse);
    final enabled = Business.fromJson({
      'id': 'business',
      'branches_enabled': true,
    });
    expect(enabled.copyWith(name: 'Name').branchesEnabled, isTrue);
  });
}
