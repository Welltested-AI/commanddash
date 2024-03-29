import 'package:commanddash/models/data_source.dart';
import 'package:commanddash/repositories/client/dio_client.dart';
import 'package:commanddash/server/task_assist.dart';
import 'package:dio/dio.dart';

class DashRepository {
  DashRepository(this.dio);
  final Dio dio;

  factory DashRepository.fromKeys(
      String githubAccessToken, TaskAssist taskAssist) {
    final client = getClient(
        githubAccessToken,
        () async => taskAssist
            .processOperation(kind: 'refresh_access_token', args: {}));
    final repo = DashRepository(client);
    return repo;
  }

  /// Error is handled and thrown back from the interceptor. Add a try catch at step level.
  Future<void> mockApi() async {
    final response = await dio.get('/path');
    return response.data;
  }

  // TODO: to be tested
  Future<DataSource> getDatasource(
      {required String agentName,
      required String agentVersion,
      required String query}) async {
    try {
      final response = await dio.post('/agent/get-reference', data: {
        "agent_name": agentName,
        "query": query,
        "agent_version": "0.0.1", //TODO: from the ide
        "testing": true,
      });
      return DataSource.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('Error fetching datasource');
    }
  }

  // TODO: to be tested
  Future<List<Map<String, dynamic>>> getAgents() async {
    try {
      final response = await dio.get(
        '/agent/get-reference',
      );
      return response.data;
    } catch (e) {
      throw Exception('Error fetching datasource');
    }
  }
}
