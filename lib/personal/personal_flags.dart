/// 个人魔改分支的功能开关。
///
/// 原则：只「隐藏入口」，不删除任何实现代码。把某个开关改回 true，
/// 界面立刻恢复原样，底层逻辑从未被改动过。
///
/// 这样做的代价只有一个：与上游同步时需要人工合并这几处 if 判断，
/// 但换来的回退成本是「改一个单词」，非常划算。
class PersonalFlags {
  const PersonalFlags._();

  /// AI 能力：AI 对话记账、拍照/截图 OCR、语音记账。
  /// 关闭后：首页 AI 按钮、"我的 → 智能记账" 入口消失。
  /// 注：这些能力全部依赖外接第三方 AI 服务商，与纯本地诉求冲突。
  static const bool aiAssistant = false;

  /// 云同步与账号：BeeCount Cloud / Supabase / WebDAV / S3 / iCloud、
  /// 登录注册、共享账本、成员管理。
  /// 关闭后："我的"页的云服务与同步状态整组消失。
  static const bool cloudSync = false;

  /// 捐赠、求 Star、应用评分、推广文案复制。
  static const bool donationAndPromo = false;

  /// 社区与反馈链接：指向官方仓库的 issue 页、Telegram、小红书、抖音、
  /// 姐妹产品推荐位。个人自用版保留它们只会误导。
  static const bool communityLinks = false;

  /// 检查更新。
  /// 【当前必须为 false】：更新检查写死查询官方仓库 Releases，返回的是官方
  /// 签名包，与本应用的 applicationId / 签名都不一致，下载后必然安装失败。
  /// 待改成指向本仓库 Releases 后再打开。
  static const bool updateCheck = false;
}
