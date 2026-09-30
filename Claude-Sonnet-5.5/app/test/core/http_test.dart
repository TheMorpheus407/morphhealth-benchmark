import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/http.dart';

void main() {
  test('Weiterleitungen führen nur auf https beim selben Host und Port', () {
    final base = Uri.parse('https://localhost:8788/api/v3.6/product/1.json');
    expect(
      IoHttpTransport.nextHop(base, '/api/v3.6/product/2.json').toString(),
      'https://localhost:8788/api/v3.6/product/2.json',
    );
    expect(IoHttpTransport.nextHop(base, 'https://localhost:8788/x')?.path, '/x');
    expect(IoHttpTransport.nextHop(base, 'http://localhost:8788/x'), isNull, reason: 'Herabstufung auf Klartext');
    expect(IoHttpTransport.nextHop(base, 'https://andere.example/x'), isNull, reason: 'anderer Host');
    expect(IoHttpTransport.nextHop(base, 'https://localhost:9999/x'), isNull, reason: 'anderer Port');
    expect(IoHttpTransport.nextHop(base, '//andere.example/x'), isNull, reason: 'schemarelativ auf anderen Host');
    expect(IoHttpTransport.nextHop(base, 'ht!tp://['), isNull, reason: 'ungültige Adresse');
  });
}
