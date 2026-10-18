abstract class DurableState {
  Future<Map<String, dynamic>> read();
  Future<T> mutate<T>(T Function(Map<String, dynamic>) change);
}
