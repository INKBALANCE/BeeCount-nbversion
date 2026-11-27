/// 本分支自己的 GitHub 仓库信息。
///
/// 上游的更新检查、下载 Referer、Release 页面链接都写死了官方仓库
/// （TNT-Likely/BeeCount）。放到这里统一改一处，避免散落在三个文件里。
class RepoConfig {
  const RepoConfig._();

  static const String owner = 'INKBALANCE';
  static const String repo = 'BeeCount-nbversion';

  static const String repoUrl = 'https://github.com/$owner/$repo';

  static const String releasesPage = '$repoUrl/releases';

  /// 检查更新用的接口。返回的 tag_name 形如 v1.0.1，代码会自动去掉 v 前缀。
  static const String latestReleaseApi =
      'https://api.github.com/repos/$owner/$repo/releases/latest';
}
