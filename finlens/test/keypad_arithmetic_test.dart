import 'package:finlens/core/utils/arithmetic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an expression by replaying keypresses. Digits and `.` are typed;
/// `+ - * /` map to the four operators; `=` evaluates. [maxDecimals] caps the
/// typed fraction digits (2 for money), [precision] rounds `=`.
Expression build(String keys, {int maxDecimals = 2, int precision = 2}) {
  var e = Expression.empty;
  for (final ch in keys.split('')) {
    switch (ch) {
      case '+':
        e = e.pressOperator(Op.add);
      case '-':
        e = e.pressOperator(Op.subtract);
      case '*':
        e = e.pressOperator(Op.multiply);
      case '/':
        e = e.pressOperator(Op.divide);
      case '=':
        e = e.evaluated(precision);
      case '<':
        e = e.backspace();
      default:
        e = e.pressDigit(ch, maxDecimals: maxDecimals);
    }
  }
  return e;
}

void main() {
  group('evaluate — the four operations', () {
    test('1 + 2 = 3', () => expect(build('1+2').evaluate(2), 3));
    test('10 − 4 = 6', () => expect(build('10-4').evaluate(2), 6));
    test('6 × 7 = 42', () => expect(build('6*7').evaluate(2), 42));
    test('9 ÷ 3 = 3', () => expect(build('9/3').evaluate(2), 3));
  });

  group('evaluate — precedence and precision', () {
    test('100 + 50 × 2 = 200 (× before +)', () {
      expect(build('100+50*2').evaluate(2), 200);
    });
    test('100 ÷ 8 = 12.5 at two decimals', () {
      expect(build('100/8').evaluate(2), 12.5);
    });
    test('0.1 + 0.2 = 0.3 exactly (no double error)', () {
      expect(build('0.1+0.2').evaluate(2), 0.3);
    });
    test('1 ÷ 3 at rate precision (6dp) = 0.333333', () {
      expect(build('1/3', maxDecimals: 6).evaluate(6), 0.333333);
    });
    test('100 ÷ 8 at 0 decimals rounds half away from zero to 13', () {
      expect(build('100/8').evaluate(0), 13);
    });
  });

  group('evaluate — intermediate results are never rounded', () {
    test('1 ÷ 3 × 3 = 1, not 0.99', () {
      // Rounding 1÷3 to 0.33 first, then ×3, would give 0.99. The exact
      // rational path gives 1.
      expect(build('1/3*3').evaluate(2), 1);
    });
    test('2 ÷ 3 + 1 ÷ 3 = 1', () {
      expect(build('2/3+1/3').evaluate(2), 1);
    });
  });

  group('evaluate — unresolvable returns null', () {
    test('ends on an operator (569 +)', () {
      expect(build('569+').evaluate(2), isNull);
    });
    test('divides by zero (569 ÷ 0)', () {
      expect(build('569/0').evaluate(2), isNull);
    });
    test('a plain number has no operator, so canResolve is false', () {
      expect(build('569').canResolve(2), isFalse);
    });
  });

  group('evaluate — negative results resolve normally', () {
    test('100 − 150 = −50', () => expect(build('100-150').evaluate(2), -50));
    test('0 − 1 = −1', () => expect(build('0-1').evaluate(2), -1));
  });

  group('canResolve — the = key state (spec §4)', () {
    test('muted for a plain number', () => expect(build('569').canResolve(2), isFalse));
    test('muted while ending on an operator', () {
      expect(build('569+').canResolve(2), isFalse);
    });
    test('muted on divide by zero', () {
      expect(build('569/0').canResolve(2), isFalse);
    });
    test('accent when it resolves', () {
      expect(build('569+30').canResolve(2), isTrue);
    });
  });

  group('key handling (spec §3.1)', () {
    test('a second decimal point is ignored', () {
      final e = build('1.2.3');
      expect(e.pending, '1.23');
    });
    test('a second operator replaces the first — never two', () {
      var e = build('5');
      e = e.pressOperator(Op.add);
      e = e.pressOperator(Op.subtract);
      expect(e.operators, [Op.subtract]);
      expect(e.operands, ['5']);
      expect(e.pending, isEmpty);
    });
    test('an operator on an empty field is ignored', () {
      expect(Expression.empty.pressOperator(Op.add), Expression.empty);
    });
    test('backspace steps back across an operator boundary, reopening the operand', () {
      var e = build('12+3'); // operands:[12], op:[add], pending:3
      e = e.backspace(); // removes the 3 → pending empty, ends on operator
      expect(e.pending, isEmpty);
      expect(e.operators, [Op.add]);
      e = e.backspace(); // removes the operator, reopens 12 as pending
      expect(e.operators, isEmpty);
      expect(e.pending, '12');
    });
    test('a digit after = starts a new number, replacing the result', () {
      var e = build('2+3='); // pending is the result 5, afterEquals
      expect(e.afterEquals, isTrue);
      e = e.pressDigit('7', maxDecimals: 2);
      expect(e.pending, '7');
      expect(e.hasOperator, isFalse);
    });
    test('an operator after = continues from the result', () {
      var e = build('2+3='); // result 5
      e = e.pressOperator(Op.multiply); // 5 ×
      e = e.pressDigit('2', maxDecimals: 2);
      expect(e.evaluate(2), 10);
    });
  });

  group('value — silent resolve for Save (spec §5)', () {
    test('a plain number parses verbatim', () {
      expect(build('569').value(2), 569);
    });
    test('a complete expression resolves', () {
      expect(build('569+30').value(2), 599);
    });
    test('an incomplete expression is null (keeps Save disabled)', () {
      expect(build('569+').value(2), isNull);
    });
    test('empty is zero, exactly as the old AmountEntry.value', () {
      expect(Expression.empty.value(2), 0);
    });
  });

  group('display', () {
    test('operators are spaced one each; operands grouped', () {
      expect(expressionDisplay(build('1234+30')), '1,234 + 30');
    });
    test('a pending operator shows (569 +)', () {
      expect(expressionDisplay(build('569+')), '569 +');
    });
    test('a resolved negative shows a true minus', () {
      final e = build('100-150='); // −50
      expect(e.pendingIsNegative, isTrue);
      expect(expressionDisplay(e), '−50');
    });
  });
}
