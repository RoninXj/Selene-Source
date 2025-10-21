import '../models/search_result.dart';
import 'api_service.dart';
import 'downstream_service.dart';

/// 搜索服务
class SearchService {
  /// 同步搜索（本地搜索）
  /// 并发调用所有资源的搜索，返回所有结果
  static Future<List<SearchResult>> searchSync(String query) async {
    try {
      // 获取搜索资源列表
      final allResources = await ApiService.getSearchResources();

      // 过滤掉被禁用的资源
      final resources =
          allResources.where((resource) => !resource.disabled).toList();

      if (resources.isEmpty) {
        return [];
      }

      // 并发调用所有资源的搜索，每个调用增加 20 秒超时
      final searchFutures = resources.map((resource) {
        return DownstreamService.searchFromApi(resource, query)
            .timeout(const Duration(seconds: 20))
            .catchError((error) {
          // 捕获错误，返回空列表
          return <SearchResult>[];
        });
      }).toList();

      // 等待所有搜索完成
      final allResults = await Future.wait(searchFutures);

      // 按照 resources 的顺序合并结果（allResults 的顺序与 resources 一致）
      final results = <SearchResult>[];
      for (int i = 0; i < allResults.length; i++) {
        if (allResults[i].isNotEmpty) {
          results.addAll(allResults[i]);
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }
}
