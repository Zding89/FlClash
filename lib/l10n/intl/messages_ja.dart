// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ja';

  static String m0(count) => "${count} 個のモデルを取得";

  static String m1(count) => "${count}日前";

  static String m2(label) => "選択された${label}を削除してもよろしいですか？";

  static String m3(label) => "現在の${label}を削除してもよろしいですか？";

  static String m4(label) => "${label}詳細";

  static String m5(label) => "${label}は空欄にできません";

  static String m6(count) => "${count} エントリ";

  static String m7(label) => "現在の${label}は既に存在しています";

  static String m8(name) => "${name} はすでに最新です";

  static String m9(name) => "${name} 更新済み";

  static String m10(name) => "${name}を更新中...";

  static String m11(count) => "${count}時間前";

  static String m12(count) => "${count} 時間";

  static String m13(target) => "${target} は無効なポリシーです";

  static String m14(proxyName) => "${proxyName} は無効なプロキシです";

  static String m15(providerName) => "${providerName} は無効なプロキシプロバイダーです";

  static String m16(subRule) => "${subRule} は無効なSUB_RULEです";

  static String m17(appName) =>
      "1. Open System Settings > Privacy & Security\n2. Choose Location Services\n3. Find and check ${appName} in the right list\n\nAfter completing the setup, return to the app and use it normally. Thank you for your cooperation.";

  static String m18(count) => "${count}分前";

  static String m19(count) => "${count}ヶ月前";

  static String m20(label) => "まだ${label}はありません";

  static String m21(label) => "${label}は数字でなければなりません";

  static String m22(target) =>
      "対象 ${target} の既存ルール、ノード、購読ソースを読み、それらを使う追加案をレビュー可能な提案として作成してください。既存の順序を保持し、既存ルールを並べ替えず、その他の通信ルールを重複追加しないでください。適用せず、私の確認を待ってください。";

  static String m23(target) =>
      "対象 ${target} の既存ルール、ノード、サブスクリプションを確認し、レビュー可能な最適化案を提案してください。現在の順序と残りの通信ルールを維持し、提案のみを作成して、変更の適用は私の確認を待ってください。";

  static String m24(sampleAt) => "最後の有効な読み取り：${sampleAt}";

  static String m25(startAt) => "集計期間の開始：${startAt}";

  static String m26(seconds) =>
      "現在の処理容量の見積もりでは、有効期間を少なくとも ${seconds} 秒にすることを推奨します。これは待ち時間の見積もりで、実際の完了までにはさらに時間がかかる場合があります。";

  static String m27(option) =>
      "未対応のソース設定：${option}。ローカル制御を適用していません。この設定を先に削除してください。";

  static String m28(label) => "${label} は 1024 から 49151 の間でなければなりません";

  static String m29(count) => "${count} 秒";

  static String m30(count) => "${count} 項目が選択されています";

  static String m31(label) => "${label}はURLである必要があります";

  static String m32(count) => "${count}年前";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("について"),
    "accessControl": MessageLookupByLibrary.simpleMessage("アクセス制御"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリのみVPNを許可",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "アプリケーションのプロキシアクセスを設定",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "選択したアプリをVPNから除外",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage("アクセス制御設定"),
    "account": MessageLookupByLibrary.simpleMessage("アカウント"),
    "action": MessageLookupByLibrary.simpleMessage("アクション"),
    "action_mode": MessageLookupByLibrary.simpleMessage("モード切替"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "action_start": MessageLookupByLibrary.simpleMessage("開始/停止"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("表示/非表示"),
    "add": MessageLookupByLibrary.simpleMessage("追加"),
    "addProfile": MessageLookupByLibrary.simpleMessage("プロファイルを追加"),
    "addProxies": MessageLookupByLibrary.simpleMessage("プロキシを追加"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを追加"),
    "addProxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダーを追加"),
    "addRule": MessageLookupByLibrary.simpleMessage("ルールを追加"),
    "addSsid": MessageLookupByLibrary.simpleMessage("SSIDを追加"),
    "addedRules": MessageLookupByLibrary.simpleMessage("追加ルール"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage("追加パラメータ"),
    "address": MessageLookupByLibrary.simpleMessage("アドレス"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("WebDAVサーバーアドレス"),
    "addressTip": MessageLookupByLibrary.simpleMessage("有効なWebDAVアドレスを入力"),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("高度な設定"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage("多様な設定を提供"),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "aiAddConnection": MessageLookupByLibrary.simpleMessage("接続を追加"),
    "aiAdvanced": MessageLookupByLibrary.simpleMessage("リクエスト制限"),
    "aiAfter": MessageLookupByLibrary.simpleMessage("変更後"),
    "aiApiProtocol": MessageLookupByLibrary.simpleMessage("API プロトコル"),
    "aiApprovalTitle": MessageLookupByLibrary.simpleMessage("設定変更を確認"),
    "aiApprove": MessageLookupByLibrary.simpleMessage("承認して適用"),
    "aiApproveScriptExecution": MessageLookupByLibrary.simpleMessage(
      "プレビュー実行を承認",
    ),
    "aiApproved": MessageLookupByLibrary.simpleMessage("承認済み"),
    "aiAssistant": MessageLookupByLibrary.simpleMessage("AI"),
    "aiAssistantRole": MessageLookupByLibrary.simpleMessage("アシスタント"),
    "aiAssistantTitle": MessageLookupByLibrary.simpleMessage("AI アシスタント"),
    "aiAuthFailed": MessageLookupByLibrary.simpleMessage(
      "認証失敗。この接続先のキーを確認してください",
    ),
    "aiAwaitingApproval": MessageLookupByLibrary.simpleMessage("確認待ち・変更は未適用"),
    "aiBackupKeyRequired": MessageLookupByLibrary.simpleMessage(
      "バックアップ前に AI 設定で接続キーを入力するか再保存してください",
    ),
    "aiBaseUrl": MessageLookupByLibrary.simpleMessage("サービス URL"),
    "aiBefore": MessageLookupByLibrary.simpleMessage("変更前"),
    "aiCanHelp": MessageLookupByLibrary.simpleMessage("できること"),
    "aiCancelled": MessageLookupByLibrary.simpleMessage("停止しました"),
    "aiCapabilityHint": MessageLookupByLibrary.simpleMessage(
      "現在の機能一覧から自然言語で操作を依頼できます",
    ),
    "aiChangeCompleted": MessageLookupByLibrary.simpleMessage("完了"),
    "aiChangeExpired": MessageLookupByLibrary.simpleMessage("期限切れ"),
    "aiChangeFailed": MessageLookupByLibrary.simpleMessage("失敗または中断"),
    "aiChangesUnavailable": MessageLookupByLibrary.simpleMessage(
      "一部の関連記録は利用できません。",
    ),
    "aiCheckResult": MessageLookupByLibrary.simpleMessage("確認結果"),
    "aiChinaApi": MessageLookupByLibrary.simpleMessage("中国 API"),
    "aiChinaCoding": MessageLookupByLibrary.simpleMessage("中国 Coding プラン"),
    "aiClearConversation": MessageLookupByLibrary.simpleMessage("会話を消去"),
    "aiCodingPlan": MessageLookupByLibrary.simpleMessage("Coding プラン"),
    "aiConfigurationInvalid": MessageLookupByLibrary.simpleMessage(
      "ローカル設定の検証に失敗し、保存されていません。設定を確認して再試行してください",
    ),
    "aiConfigurationSaveFailed": MessageLookupByLibrary.simpleMessage(
      "ローカル設定を保存できませんでした。変更履歴を確認して再試行してください",
    ),
    "aiConnection": MessageLookupByLibrary.simpleMessage("モデル接続"),
    "aiConversationHistory": MessageLookupByLibrary.simpleMessage("会話履歴"),
    "aiConversationHistoryHint": MessageLookupByLibrary.simpleMessage(
      "この端末に最新20件、各80件までのテキストを保存します。履歴を開いても過去の操作は再実行しません。会話を削除しても変更履歴は残ります。",
    ),
    "aiCredentialMigrationRequired": MessageLookupByLibrary.simpleMessage(
      "以前のキーを移行できませんでした。再入力して保存すると、以後キーチェーンへのアクセスは不要です",
    ),
    "aiCredentialRecoveryFailed": MessageLookupByLibrary.simpleMessage(
      "キーの復元に失敗しました。使用前に再設定してください",
    ),
    "aiCredentialUnavailable": MessageLookupByLibrary.simpleMessage(
      "保存済みキーを読み取れません。再入力して保存してください",
    ),
    "aiCurrentConnection": MessageLookupByLibrary.simpleMessage("現在の接続"),
    "aiCustomProvider": MessageLookupByLibrary.simpleMessage("カスタム互換サービス"),
    "aiDeleteConnection": MessageLookupByLibrary.simpleMessage("接続を削除"),
    "aiDeleteKey": MessageLookupByLibrary.simpleMessage("キーを削除"),
    "aiDeleteKeyHint": MessageLookupByLibrary.simpleMessage(
      "キーを削除すると AI タスクを中止します。ローカルポリシーは継続します",
    ),
    "aiDisabled": MessageLookupByLibrary.simpleMessage("AI アシスタントは無効です"),
    "aiDiscardChanges": MessageLookupByLibrary.simpleMessage("変更を破棄"),
    "aiEditConnection": MessageLookupByLibrary.simpleMessage("接続を編集"),
    "aiEmptyConversation": MessageLookupByLibrary.simpleMessage(
      "現在の設定を確認して、変更をプレビューできます",
    ),
    "aiEmptyHistory": MessageLookupByLibrary.simpleMessage("会話履歴はありません"),
    "aiEnable": MessageLookupByLibrary.simpleMessage("AI アシスタントを有効化"),
    "aiEnableHint": MessageLookupByLibrary.simpleMessage(
      "送信時のみモデルを呼び出します。ローカルポリシーは独立して動作します",
    ),
    "aiFetchModels": MessageLookupByLibrary.simpleMessage("モデルを取得"),
    "aiFinalConfigDifferences": MessageLookupByLibrary.simpleMessage(
      "検証済みの最終設定差分",
    ),
    "aiGlobalApi": MessageLookupByLibrary.simpleMessage("グローバル API"),
    "aiGlobalCoding": MessageLookupByLibrary.simpleMessage("グローバル Coding プラン"),
    "aiHighRisk": MessageLookupByLibrary.simpleMessage(
      "ネットワーク、設定、プライバシーに影響します。確認してください",
    ),
    "aiHistoryLimit": MessageLookupByLibrary.simpleMessage(
      "会話の上限に達しました。消去して再開してください",
    ),
    "aiHistorySaveFailed": MessageLookupByLibrary.simpleMessage(
      "会話履歴を保存できませんでした",
    ),
    "aiHostUnavailable": MessageLookupByLibrary.simpleMessage(
      "AI 実行コンポーネントがありません。対応する macOS ビルドを使用してください",
    ),
    "aiInvalidConnection": MessageLookupByLibrary.simpleMessage(
      "名前、モデル、URL、制限を確認してください",
    ),
    "aiKey": MessageLookupByLibrary.simpleMessage("API キー"),
    "aiKeyHide": MessageLookupByLibrary.simpleMessage("キーを非表示"),
    "aiKeyMissing": MessageLookupByLibrary.simpleMessage("先にこの接続のキーを保存してください"),
    "aiKeyRequired": MessageLookupByLibrary.simpleMessage(
      "このエンドポイントの API キーを入力",
    ),
    "aiKeyShow": MessageLookupByLibrary.simpleMessage("キーを表示"),
    "aiKeyStored": MessageLookupByLibrary.simpleMessage("設定に暗号化して保存済み。空欄で保持"),
    "aiLinkedChanges": MessageLookupByLibrary.simpleMessage("関連する変更"),
    "aiLinkedChangesHint": MessageLookupByLibrary.simpleMessage(
      "既存の変更履歴の最新状態と差分を表示します。取り消しや復旧は変更履歴で行います。",
    ),
    "aiManageChanges": MessageLookupByLibrary.simpleMessage("変更履歴を開く"),
    "aiManualModel": MessageLookupByLibrary.simpleMessage("モデル ID（手入力可能）"),
    "aiMaxTokens": MessageLookupByLibrary.simpleMessage("最大出力トークン"),
    "aiModel": MessageLookupByLibrary.simpleMessage("モデル ID"),
    "aiModelFetchHint": MessageLookupByLibrary.simpleMessage(
      "取得成功は会話やツール利用を保証しません。モデル ID を手入力することもできます。",
    ),
    "aiModelsEmpty": MessageLookupByLibrary.simpleMessage(
      "モデルが返されませんでした。ID を手入力できます。",
    ),
    "aiModelsFetched": m0,
    "aiModelsUnsupported": MessageLookupByLibrary.simpleMessage(
      "このサービスはモデル取得に対応していません。ID を手入力してください。",
    ),
    "aiNewConversation": MessageLookupByLibrary.simpleMessage("新しい会話"),
    "aiNoConnection": MessageLookupByLibrary.simpleMessage("接続を追加して会話を開始"),
    "aiNoDifferences": MessageLookupByLibrary.simpleMessage("適用する変更はありません"),
    "aiPresetDefault": MessageLookupByLibrary.simpleMessage("空欄で既定の URL を使用"),
    "aiPromptHint": MessageLookupByLibrary.simpleMessage("確認・変更したい設定を入力…"),
    "aiProvider": MessageLookupByLibrary.simpleMessage("プロバイダーとエンドポイント"),
    "aiQuotaExceeded": MessageLookupByLibrary.simpleMessage(
      "残高・利用枠不足。アカウントを確認してください",
    ),
    "aiRateLimited": MessageLookupByLibrary.simpleMessage(
      "リクエスト制限に達しました。後で再試行してください",
    ),
    "aiReject": MessageLookupByLibrary.simpleMessage("拒否"),
    "aiRequestFailed": MessageLookupByLibrary.simpleMessage(
      "リクエスト失敗。接続を確認するか後で再試行してください",
    ),
    "aiResourceActivationArtifactMissing": MessageLookupByLibrary.simpleMessage(
      "承認済み設定を利用できません。変更を再作成して承認してください。",
    ),
    "aiResourcePanelRequired": MessageLookupByLibrary.simpleMessage(
      "続行するにはローカル画面でファイルまたは保存先を選択してください。",
    ),
    "aiResourceScopeChanged": MessageLookupByLibrary.simpleMessage(
      "提案を開いている間にリソースが変更されました。新しい提案を作成してください。",
    ),
    "aiResourceUpdateAccepted": MessageLookupByLibrary.simpleMessage(
      "更新リクエストを受け付けました。完了はローカル Core が確認します。",
    ),
    "aiResultCompleted": MessageLookupByLibrary.simpleMessage("完了"),
    "aiReviewPlan": MessageLookupByLibrary.simpleMessage("プランを確認"),
    "aiSaveAndUse": MessageLookupByLibrary.simpleMessage("保存して使用"),
    "aiSaveFailed": MessageLookupByLibrary.simpleMessage(
      "保存に失敗しました。接続とキーの復元を試みました。確認して再試行してください",
    ),
    "aiSaved": MessageLookupByLibrary.simpleMessage("接続を保存しました"),
    "aiScriptExecutionOnly": MessageLookupByLibrary.simpleMessage(
      "今回は制限環境でのスクリプト実行とプレビュー生成のみ承認します。適用には最終差分の再確認が必要です。",
    ),
    "aiScriptRuntimeUnavailable": MessageLookupByLibrary.simpleMessage(
      "同梱のスクリプト実行環境を利用できません。実行前にアプリを再インストールしてください。",
    ),
    "aiScriptSandboxRejected": MessageLookupByLibrary.simpleMessage(
      "ローカルの隔離制限によりスクリプトの実行を停止しました。",
    ),
    "aiSearchModels": MessageLookupByLibrary.simpleMessage("モデルを検索"),
    "aiSelectConnection": MessageLookupByLibrary.simpleMessage("この接続を使用"),
    "aiSelected": MessageLookupByLibrary.simpleMessage("現在の接続"),
    "aiSend": MessageLookupByLibrary.simpleMessage("送信"),
    "aiServiceCredentials": MessageLookupByLibrary.simpleMessage("サービスと認証情報"),
    "aiSettingsTitle": MessageLookupByLibrary.simpleMessage("AI 接続とモデル"),
    "aiStartedWithProfile": MessageLookupByLibrary.simpleMessage("開始時のプロファイル"),
    "aiStop": MessageLookupByLibrary.simpleMessage("停止"),
    "aiTargetChanged": MessageLookupByLibrary.simpleMessage(
      "接続先が変更されました。新しい接続先のキーを再入力",
    ),
    "aiTestConnection": MessageLookupByLibrary.simpleMessage("ツール呼び出しをテスト"),
    "aiTestPartial": MessageLookupByLibrary.simpleMessage(
      "ストリームとツールのテストが未完了です。Agent 対応は未確認",
    ),
    "aiTestPassed": MessageLookupByLibrary.simpleMessage(
      "認証、テキストストリーム、ツール呼び出し成功",
    ),
    "aiTesting": MessageLookupByLibrary.simpleMessage("接続を検証中…"),
    "aiTestingCharges": MessageLookupByLibrary.simpleMessage(
      "テストは選択したモデルを呼び出し、利用料が発生する場合があります",
    ),
    "aiThinking": MessageLookupByLibrary.simpleMessage("分析中…"),
    "aiTimedOut": MessageLookupByLibrary.simpleMessage("モデルリクエストがタイムアウトしました"),
    "aiTimeout": MessageLookupByLibrary.simpleMessage("タイムアウト（秒）"),
    "aiToolWorking": MessageLookupByLibrary.simpleMessage("アプリのコマンドを実行中…"),
    "aiUnsavedChanges": MessageLookupByLibrary.simpleMessage("接続の変更が未保存です"),
    "aiUsageClearIrreversible": MessageLookupByLibrary.simpleMessage(
      "使用量履歴の削除は取り消せません。ソースの上限カウンターは保持されます。",
    ),
    "aiUseProxy": MessageLookupByLibrary.simpleMessage("現在のプロキシでモデルに接続"),
    "aiYou": MessageLookupByLibrary.simpleMessage("あなた"),
    "allTraffic": MessageLookupByLibrary.simpleMessage("すべて"),
    "allowBypass": MessageLookupByLibrary.simpleMessage("アプリがVPNをバイパスすることを許可"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "有効化すると一部アプリがVPNをバイパス",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("LANを許可"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage("LAN経由でのプロキシアクセスを許可"),
    "app": MessageLookupByLibrary.simpleMessage("アプリ"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("アプリアクセス制御"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("システムDNSを追加"),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "設定にシステムDNSを強制的に追加します",
    ),
    "application": MessageLookupByLibrary.simpleMessage("アプリケーション"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage("アプリ関連設定を変更"),
    "authorized": MessageLookupByLibrary.simpleMessage("許可済み"),
    "auto": MessageLookupByLibrary.simpleMessage("自動"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自動更新チェック"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "起動時に更新を自動チェック",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("接続を自動閉じる"),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "ノード変更後に接続を自動閉じる",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自動起動"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage("システムの自動起動に従う"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自動実行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("アプリ起動時に自動実行"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("オートセットシステムDNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔（分）"),
    "backup": MessageLookupByLibrary.simpleMessage("バックアップ"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("バックアップと復元"),
    "backupAndRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAVまたはファイルを介してデータを同期する",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("バックアップ成功"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("基本設定"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage("基本設定をグローバルに変更"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("基本情報"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("基本戦略"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "To ensure background operation, please disable battery optimization for this app. Tap to go to settings.",
    ),
    "batteryOptimizationStatusTip": MessageLookupByLibrary.simpleMessage(
      "システムの影響により、この状態は必ずしも正確とは限りません。",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("バインド"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("ブラックリストモード"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("バイパスドメイン"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage("システムプロキシ有効時のみ適用"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "キャッシュが破損しています。クリアしますか？",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("キャンセル"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("全選択解除"),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("更新を確認"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("アプリは最新版です"),
    "clearData": MessageLookupByLibrary.simpleMessage("データを消去"),
    "clearUsageData": MessageLookupByLibrary.simpleMessage("使用量データを消去"),
    "clearUsageDataConfirm": MessageLookupByLibrary.simpleMessage(
      "すべての使用量バケットと処理済みバッチ記録を完全に削除します。続行しますか？",
    ),
    "clearUsageDataDesc": MessageLookupByLibrary.simpleMessage(
      "記録スイッチを変更せず、ローカルの使用量統計をすべて削除します",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("クリップボードにエクスポート"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("クリップボードからインポート"),
    "color": MessageLookupByLibrary.simpleMessage("カラー"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("カラースキーム"),
    "columns": MessageLookupByLibrary.simpleMessage("列"),
    "compatible": MessageLookupByLibrary.simpleMessage("互換モード"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "設定内にデータが検出されました",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("確認"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "すべてのデータをクリアしてもよろしいですか？",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループを削除してもよろしいですか？",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "現在のウィンドウを閉じてもよろしいですか？",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "コアを強制的にクラッシュさせてもよろしいですか？",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "確認後、既存のデータは上書きされます",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("接続済み"),
    "connecting": MessageLookupByLibrary.simpleMessage("接続中..."),
    "connection": MessageLookupByLibrary.simpleMessage("接続"),
    "connections": MessageLookupByLibrary.simpleMessage("接続"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage("現在の接続データを表示"),
    "connectivity": MessageLookupByLibrary.simpleMessage("接続性："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("内容は空にできません"),
    "contentScheme": MessageLookupByLibrary.simpleMessage("コンテンツテーマ"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "グローバル追加ルールを制御",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("コピー"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("環境変数をコピー"),
    "copyLink": MessageLookupByLibrary.simpleMessage("リンクをコピー"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("コピー成功"),
    "core": MessageLookupByLibrary.simpleMessage("コア"),
    "coreStatus": MessageLookupByLibrary.simpleMessage("コアステータス"),
    "country": MessageLookupByLibrary.simpleMessage("国"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("クラッシュを検出しました"),
    "crashDetectedTip": MessageLookupByLibrary.simpleMessage(
      "前回の実行中にアプリがクラッシュしました。クラッシュの繰り返しを防ぐため、現在のプロファイルを解除し、設定の自動セットアップをスキップしました。",
    ),
    "crashTest": MessageLookupByLibrary.simpleMessage("クラッシュテスト"),
    "crashlytics": MessageLookupByLibrary.simpleMessage("クラッシュ分析"),
    "crashlyticsTip": MessageLookupByLibrary.simpleMessage(
      "有効にすると、アプリがクラッシュした際に機密情報を含まないクラッシュログを自動的にアップロードします",
    ),
    "create": MessageLookupByLibrary.simpleMessage("作成"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Create Profile"),
    "creationTime": MessageLookupByLibrary.simpleMessage("作成時間"),
    "currentSessionUsage": MessageLookupByLibrary.simpleMessage(
      "現在のセッション・記録オフ",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "cut": MessageLookupByLibrary.simpleMessage("切り取り"),
    "dark": MessageLookupByLibrary.simpleMessage("ダーク"),
    "dashboard": MessageLookupByLibrary.simpleMessage("ダッシュボード"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "データの変更が検出されました。保存しますか？",
    ),
    "dataCollectionContent": MessageLookupByLibrary.simpleMessage(
      "本アプリはFirebase Crashlyticsを使用してクラッシュ情報を収集し、アプリの安定性を向上させます。\n収集されるデータにはデバイス情報とクラッシュ詳細が含まれますが、個人の機密データは含まれません。\n設定でこの機能を無効にすることができます。",
    ),
    "dataCollectionTip": MessageLookupByLibrary.simpleMessage("データ収集説明"),
    "daysAgo": m1,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage("デフォルトネームサーバー"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNSサーバーの解決用",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("デフォルト"),
    "delay": MessageLookupByLibrary.simpleMessage("遅延"),
    "delayTest": MessageLookupByLibrary.simpleMessage("遅延テスト"),
    "delete": MessageLookupByLibrary.simpleMessage("削除"),
    "deleteMultipTip": m2,
    "deleteTip": m3,
    "desc": MessageLookupByLibrary.simpleMessage(
      "ClashMetaベースのマルチプラットフォームプロキシクライアント。シンプルで使いやすく、オープンソースで広告なし。",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("宛先"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("宛先地理情報"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("宛先IP ASN"),
    "details": m4,
    "detectionTip": MessageLookupByLibrary.simpleMessage("サードパーティAPIに依存（参考値）"),
    "developerMode": MessageLookupByLibrary.simpleMessage("デベロッパーモード"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "デベロッパーモードが有効になりました。",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "directTraffic": MessageLookupByLibrary.simpleMessage("ダイレクト"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("UDPを無効化"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免責事項"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "本ソフトウェアは学習交流や科学研究などの非営利目的でのみ使用されます。商用利用は厳禁です。いかなる商用活動も本ソフトウェアとは無関係です。",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("切断済み"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("新バージョンを発見"),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS関連設定の更新"),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNSハイジャッキング"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNSモード"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage("通過させますか？"),
    "domain": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "domainTargets": MessageLookupByLibrary.simpleMessage("完全なホスト名と宛先 IP"),
    "download": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "edit": MessageLookupByLibrary.simpleMessage("編集"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("グローバルルールを編集"),
    "editProxy": MessageLookupByLibrary.simpleMessage("プロキシを編集"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループを編集"),
    "editRule": MessageLookupByLibrary.simpleMessage("ルールを編集"),
    "editSsid": MessageLookupByLibrary.simpleMessage("SSIDを編集"),
    "emptyTip": m5,
    "en": MessageLookupByLibrary.simpleMessage("英語"),
    "enableUsageRecording": MessageLookupByLibrary.simpleMessage("記録を有効化"),
    "entries": MessageLookupByLibrary.simpleMessage(" エントリ"),
    "entriesCount": m6,
    "exclude": MessageLookupByLibrary.simpleMessage("最近のタスクから非表示"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "アプリがバックグラウンド時に最近のタスクから非表示",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage("除外プロキシフィルター"),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Exclude SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "When connected to an excluded SSID Wi-Fi, the app running state will be automatically switched.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("除外タイプ"),
    "existsTip": m7,
    "exit": MessageLookupByLibrary.simpleMessage("終了"),
    "expand": MessageLookupByLibrary.simpleMessage("標準"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("期待されるステータス"),
    "exportCsv": MessageLookupByLibrary.simpleMessage("CSV を書き出す"),
    "exportFile": MessageLookupByLibrary.simpleMessage("ファイルをエクスポート"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("ログをエクスポート"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("エクスポート成功"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("エクスプレッシブ"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部コントローラー"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとClashコアをポート9090で制御可能",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("外部取得"),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部リンク"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeipフィルター"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip範囲"),
    "fallback": MessageLookupByLibrary.simpleMessage("フォールバック"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("通常はオフショアDNSを使用"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("フォールバックフィルター"),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("ハイファイデリティー"),
    "file": MessageLookupByLibrary.simpleMessage("ファイル"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("プロファイルを直接アップロード"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "ファイルが変更されました。保存しますか？",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("プロセス検出"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとパフォーマンスが若干低下します",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("フォントファミリー"),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "コアを強制再起動してもよろしいですか？",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("フルーツサラダ"),
    "general": MessageLookupByLibrary.simpleMessage("一般"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("自動更新"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage("自動更新間隔"),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自動更新間隔は0より大きくなければなりません",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Geoオプション"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geoリソース"),
    "geoSkipped": m8,
    "geoUpdated": m9,
    "geoUpdating": m10,
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低メモリモード"),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとGeo低メモリローダーを使用",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("GeoIPコード"),
    "global": MessageLookupByLibrary.simpleMessage("グローバル"),
    "go": MessageLookupByLibrary.simpleMessage("移動"),
    "goDownload": MessageLookupByLibrary.simpleMessage("ダウンロードへ"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("スクリプト設定に移動"),
    "goToSettings": MessageLookupByLibrary.simpleMessage("設定へ"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("変更をキャッシュしますか？"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper サービスが利用できないため、TUN モードを有効にできません。再インストールしてください。",
    ),
    "hideFromList": MessageLookupByLibrary.simpleMessage("リストから隠す"),
    "host": MessageLookupByLibrary.simpleMessage("ホスト"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("ホストを追加"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("ホットキー競合"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("ホットキー管理"),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "キーボードでアプリを制御",
    ),
    "hourlyDistribution": MessageLookupByLibrary.simpleMessage("24時間分布"),
    "hours": MessageLookupByLibrary.simpleMessage("時間"),
    "hoursAgo": m11,
    "hoursCount": m12,
    "icon": MessageLookupByLibrary.simpleMessage("アイコン"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("アイコン履歴"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("アイコンスタイル"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("アイコンURL"),
    "identificationCoverage": MessageLookupByLibrary.simpleMessage("識別カバー率"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignore Battery Optimization",
    ),
    "import": MessageLookupByLibrary.simpleMessage("インポート"),
    "importFile": MessageLookupByLibrary.simpleMessage("ファイルからインポート"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "importUrl": MessageLookupByLibrary.simpleMessage("URLからインポート"),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage("すべてのプロキシを含める"),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "プロキシグループに含まれないすべてのプロキシをインポートします。下でさらにプロキシグループを追加できます",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "すべてのプロキシプロバイダーを含める",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "有効にすると、インポートされたプロキシプロバイダーを上書きします",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("長期有効"),
    "init": MessageLookupByLibrary.simpleMessage("初期化"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage("正しいホットキーを入力"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage("プロキシグループ名を入力"),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("ルール内容を入力"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("インテリジェント選択"),
    "internet": MessageLookupByLibrary.simpleMessage("インターネット"),
    "interval": MessageLookupByLibrary.simpleMessage("インターバル"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("イントラネットIP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("無効なバックアップファイル"),
    "invalidPolicy": m13,
    "invalidProxy": m14,
    "invalidProxyProvider": m15,
    "invalidSubRule": m16,
    "ipcidr": MessageLookupByLibrary.simpleMessage("IPCIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("有効化するとIPv6トラフィックを受信可能"),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage("IPv6インバウンドを許可"),
    "ja": MessageLookupByLibrary.simpleMessage("日本語"),
    "justNow": MessageLookupByLibrary.simpleMessage("たった今"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCPキープアライブ間隔",
    ),
    "key": MessageLookupByLibrary.simpleMessage("キー"),
    "language": MessageLookupByLibrary.simpleMessage("言語"),
    "last24Hours": MessageLookupByLibrary.simpleMessage("24時間"),
    "last30Days": MessageLookupByLibrary.simpleMessage("30日間"),
    "last7Days": MessageLookupByLibrary.simpleMessage("7日間"),
    "layout": MessageLookupByLibrary.simpleMessage("レイアウト"),
    "light": MessageLookupByLibrary.simpleMessage("ライト"),
    "list": MessageLookupByLibrary.simpleMessage("リスト"),
    "listen": MessageLookupByLibrary.simpleMessage("リスン"),
    "loadMore": MessageLookupByLibrary.simpleMessage("さらに読み込む"),
    "loadTest": MessageLookupByLibrary.simpleMessage("読み込みテスト"),
    "loading": MessageLookupByLibrary.simpleMessage("読み込み中..."),
    "local": MessageLookupByLibrary.simpleMessage("ローカル"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "設定、AI 接続と暗号化キー、ローカルルールと履歴をファイルにバックアップ",
    ),
    "localControlChangePassword": MessageLookupByLibrary.simpleMessage(
      "パスワードを変更",
    ),
    "localControlCommands": MessageLookupByLibrary.simpleMessage("コマンドを表示"),
    "localControlCopyPath": MessageLookupByLibrary.simpleMessage("ツールのパスをコピー"),
    "localControlDescription": MessageLookupByLibrary.simpleMessage(
      "ローカルコマンドで FlClash を操作",
    ),
    "localControlDisabled": MessageLookupByLibrary.simpleMessage("無効"),
    "localControlExitHint": MessageLookupByLibrary.simpleMessage(
      "アプリ終了後は CLI を利用できません。ウィンドウを隠しても利用できます。",
    ),
    "localControlPassword": MessageLookupByLibrary.simpleMessage("CLI パスワード"),
    "localControlPasswordHint": MessageLookupByLibrary.simpleMessage(
      "初回にランダム生成され、再起動後も保持されます。新しいパスワードの保存後は古いものが無効になります。",
    ),
    "localControlPasswordValidation": MessageLookupByLibrary.simpleMessage(
      "制御文字を含まない 12～128 文字の Unicode 文字列を使用してください。",
    ),
    "localControlRandomPassword": MessageLookupByLibrary.simpleMessage(
      "ランダムに再生成",
    ),
    "localControlReady": MessageLookupByLibrary.simpleMessage("利用可能、この端末のみ"),
    "localControlSaveFailed": MessageLookupByLibrary.simpleMessage(
      "保存または安全な終了に失敗しました。元のパスワードは引き続き有効です。",
    ),
    "localControlSecurity": MessageLookupByLibrary.simpleMessage("安全と操作の確認"),
    "localControlSecurityHint": MessageLookupByLibrary.simpleMessage(
      "設定変更はプレビュー後に確認します。システム権限はシステムの画面で許可します。",
    ),
    "localControlTitle": MessageLookupByLibrary.simpleMessage("ローカル CLI"),
    "localControlUnavailable": MessageLookupByLibrary.simpleMessage(
      "サービスを利用できません。再試行してください。",
    ),
    "localControlUsage": MessageLookupByLibrary.simpleMessage("使用方法"),
    "localControlUsageHint": MessageLookupByLibrary.simpleMessage(
      "実行時にパスワードを入力します。スクリプトでは標準入力または専用ファイル記述子から渡せます。",
    ),
    "localPolicies": MessageLookupByLibrary.simpleMessage("ローカルルール"),
    "localUsageNotice": MessageLookupByLibrary.simpleMessage(
      "ローカル記録であり、請求精度を保証しません",
    ),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Location Permission",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "位置情報の権限が拒否されたため、現在の Wi-Fi 名を取得できません。システム設定で位置情報の権限を手動で有効にしてください。",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "According to system requirements, obtaining the Wi-Fi name requires you to grant location permission.",
    ),
    "locationPermissionGuide": m17,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Location Permission Required",
    ),
    "log": MessageLookupByLibrary.simpleMessage("ログ"),
    "logLevel": MessageLookupByLibrary.simpleMessage("ログレベル"),
    "logcat": MessageLookupByLibrary.simpleMessage("ログキャット"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("無効化するとログエントリを非表示"),
    "logs": MessageLookupByLibrary.simpleMessage("ログ"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("ログキャプチャ記録"),
    "logsTest": MessageLookupByLibrary.simpleMessage("ログテスト"),
    "loopback": MessageLookupByLibrary.simpleMessage("ループバック解除ツール"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage("UWPループバック解除用"),
    "loose": MessageLookupByLibrary.simpleMessage("疎"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("送信元IPをマッチング"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("最大失敗回数"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("メモリ情報"),
    "messageTest": MessageLookupByLibrary.simpleMessage("メッセージテスト"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("これはメッセージです。"),
    "min": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("終了時に最小化"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "システムの終了イベントを変更",
    ),
    "minutesAgo": m18,
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合ポート"),
    "mode": MessageLookupByLibrary.simpleMessage("モード"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("モノクローム"),
    "monthsAgo": m19,
    "more": MessageLookupByLibrary.simpleMessage("詳細"),
    "name": MessageLookupByLibrary.simpleMessage("名前"),
    "nameserver": MessageLookupByLibrary.simpleMessage("ネームサーバー"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage("ドメイン解決用"),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage("ネームサーバーポリシー"),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "対応するネームサーバーポリシーを指定",
    ),
    "network": MessageLookupByLibrary.simpleMessage("ネットワーク"),
    "networkDesc": MessageLookupByLibrary.simpleMessage("ネットワーク関連設定の変更"),
    "networkDetection": MessageLookupByLibrary.simpleMessage("ネットワーク検出"),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "ネットワーク例外、接続を確認してもう一度お試しください",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("ネットワーク速度"),
    "networkType": MessageLookupByLibrary.simpleMessage("ネットワーク種別"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("ニュートラル"),
    "noData": MessageLookupByLibrary.simpleMessage("データなし"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("ホットキーなし"),
    "noInfo": MessageLookupByLibrary.simpleMessage("情報なし"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("今後表示しない"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("ネットワークなし"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("ネットワークなしアプリ"),
    "noRecords": MessageLookupByLibrary.simpleMessage("履歴なし"),
    "noResolve": MessageLookupByLibrary.simpleMessage("IPを解決しない"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("ホスト名を解決しない"),
    "noUsageData": MessageLookupByLibrary.simpleMessage(
      "現在のフィルターに該当するデータはありません",
    ),
    "none": MessageLookupByLibrary.simpleMessage("なし"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループは選択できません",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルがありません。追加してください",
    ),
    "nullTip": m20,
    "numberTip": m21,
    "onDemand": MessageLookupByLibrary.simpleMessage("On Demand"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "Configure the program running state for specific scenarios",
    ),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("アイコンのみ"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("プロキシのみ統計"),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロキシトラフィックのみ統計",
    ),
    "openProcessSettings": MessageLookupByLibrary.simpleMessage("プロセス識別設定"),
    "optional": MessageLookupByLibrary.simpleMessage("オプション"),
    "options": MessageLookupByLibrary.simpleMessage("オプション"),
    "other": MessageLookupByLibrary.simpleMessage("その他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("その他の貢献者"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("アウトバウンドモード"),
    "override": MessageLookupByLibrary.simpleMessage("上書き"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("DNS上書き"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "有効化するとプロファイルのDNS設定を上書き",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage("上書きモード"),
    "overrideScript": MessageLookupByLibrary.simpleMessage("上書きスクリプト"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("カスタム"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "カスタムモード、プロキシグループとルールを完全にカスタマイズ可能",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("パレット"),
    "password": MessageLookupByLibrary.simpleMessage("パスワード"),
    "paste": MessageLookupByLibrary.simpleMessage("貼り付け"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "WebDAVをバインドしてください",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "スクリプト名を入力してください",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "管理者パスワードを入力",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "有効なQRコードをアップロードしてください",
    ),
    "policyActiveIntegration": MessageLookupByLibrary.simpleMessage(
      "使用する統合プロファイル",
    ),
    "policyAddBackup": MessageLookupByLibrary.simpleMessage("予備を追加"),
    "policyAddBudget": MessageLookupByLibrary.simpleMessage("通信量制限を追加"),
    "policyAddIntegration": MessageLookupByLibrary.simpleMessage("統合プロファイルを作成"),
    "policyAddRule": MessageLookupByLibrary.simpleMessage("ルールを追加"),
    "policyAdmission": MessageLookupByLibrary.simpleMessage("有効期限と残量"),
    "policyAdvancedJson": MessageLookupByLibrary.simpleMessage("詳細 JSON"),
    "policyAdvancedTab": MessageLookupByLibrary.simpleMessage("詳細"),
    "policyAiGenerate": MessageLookupByLibrary.simpleMessage("AI でプランを生成"),
    "policyAiGenerationRequest": m22,
    "policyAiOptimizationRequest": m23,
    "policyAiOptimizeRule": MessageLookupByLibrary.simpleMessage("AIでルールを最適化"),
    "policyAiOrigin": MessageLookupByLibrary.simpleMessage("AI 生成"),
    "policyApplication": MessageLookupByLibrary.simpleMessage("アプリ"),
    "policyAppliedStatus": MessageLookupByLibrary.simpleMessage("適用済み"),
    "policyAssumeHealthy": MessageLookupByLibrary.simpleMessage("全候補を正常と仮定"),
    "policyAutoCheck": MessageLookupByLibrary.simpleMessage("自動チェック"),
    "policyAutoRecover": MessageLookupByLibrary.simpleMessage("優先ノードへ自動復帰"),
    "policyAvailableMembers": MessageLookupByLibrary.simpleMessage("利用可能なメンバー"),
    "policyBudgetGiB": MessageLookupByLibrary.simpleMessage(
      "この端末の月間通信量上限（GiB）",
    ),
    "policyBudgetHint": MessageLookupByLibrary.simpleMessage(
      "この端末の管理対象接続のみ集計し、上限で新規接続を制限します。他の端末は含まず、既存の接続がすぐ切断されるとは限りません",
    ),
    "policyBudgetLastSample": m24,
    "policyBudgetPeriod": m25,
    "policyBudgetReached": MessageLookupByLibrary.simpleMessage(
      "この端末の上限に達したため、この購読の新規接続を制限しています",
    ),
    "policyBudgetReachedHint": MessageLookupByLibrary.simpleMessage(
      "ローカルルールでノードを選ぶ場合は、他の利用可能な候補を試します。候補がない場合は、ルールのフォールバック設定に従います。",
    ),
    "policyBudgetTab": MessageLookupByLibrary.simpleMessage("通信量制限"),
    "policyCandidateHint": MessageLookupByLibrary.simpleMessage(
      "このリスト内のノードのみ、指定順に選択します",
    ),
    "policyCandidates": MessageLookupByLibrary.simpleMessage("ノードの順序"),
    "policyCheckCapacityHint": m26,
    "policyCheckFrequencyHint": MessageLookupByLibrary.simpleMessage(
      "間隔は実行目安です。ノード数が多い場合は待機が発生します",
    ),
    "policyCheckFrequencySection": MessageLookupByLibrary.simpleMessage(
      "チェック頻度",
    ),
    "policyCheckMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "接続性と応答遅延を測定します。ダウンロード速度ではありません",
    ),
    "policyCheckMethodSection": MessageLookupByLibrary.simpleMessage("チェック方法"),
    "policyCheckNow": MessageLookupByLibrary.simpleMessage("今すぐチェック"),
    "policyCheckPending": MessageLookupByLibrary.simpleMessage("チェック待ち"),
    "policyCheckPreset": MessageLookupByLibrary.simpleMessage("チェック先のプリセット"),
    "policyCheckSave": MessageLookupByLibrary.simpleMessage("確認して保存"),
    "policyCheckStatusSection": MessageLookupByLibrary.simpleMessage("チェック状態"),
    "policyChecksInFlight": MessageLookupByLibrary.simpleMessage("確認中"),
    "policyChecksWaiting": MessageLookupByLibrary.simpleMessage("待機中の確認"),
    "policyChoiceSection": MessageLookupByLibrary.simpleMessage("優先と予備"),
    "policyCollectionPending": MessageLookupByLibrary.simpleMessage("未設定"),
    "policyCombinedConditions": MessageLookupByLibrary.simpleMessage("複合条件"),
    "policyContinueEditing": MessageLookupByLibrary.simpleMessage("編集を続ける"),
    "policyCooldownSeconds": MessageLookupByLibrary.simpleMessage("切替間隔（秒）"),
    "policyCoreStopped": MessageLookupByLibrary.simpleMessage(
      "Core が停止中。ポリシーは実行されません",
    ),
    "policyCurrentEffect": MessageLookupByLibrary.simpleMessage("現在の動作"),
    "policyCustomCheck": MessageLookupByLibrary.simpleMessage("カスタム"),
    "policyDeclaredAttribute": MessageLookupByLibrary.simpleMessage("購読による宣言"),
    "policyDeleteLinked": MessageLookupByLibrary.simpleMessage(
      "ルールから参照されています。先にルールを変更してください",
    ),
    "policyDiscardChanges": MessageLookupByLibrary.simpleMessage("変更を破棄"),
    "policyDomainKeyword": MessageLookupByLibrary.simpleMessage("ドメインキーワード"),
    "policyDomainScope": MessageLookupByLibrary.simpleMessage("完全一致のドメイン"),
    "policyDomainSuffix": MessageLookupByLibrary.simpleMessage("ドメイン末尾"),
    "policyDraftStatus": MessageLookupByLibrary.simpleMessage("確認待ち"),
    "policyDraftStatusHint": MessageLookupByLibrary.simpleMessage(
      "下書きが変更されています。保存後にチェック結果を表示",
    ),
    "policyEditIntegration": MessageLookupByLibrary.simpleMessage(
      "統合プロファイルを編集",
    ),
    "policyEditRule": MessageLookupByLibrary.simpleMessage("ルールを編集"),
    "policyEligible": MessageLookupByLibrary.simpleMessage("現在の条件に適合"),
    "policyEmptyBudgets": MessageLookupByLibrary.simpleMessage(
      "この端末の通信量制限は未設定です",
    ),
    "policyEmptyHistory": MessageLookupByLibrary.simpleMessage("変更履歴がありません"),
    "policyEmptyIntegrations": MessageLookupByLibrary.simpleMessage(
      "統合プロファイルはありません。通常のルールは既存のプロファイルに直接設定できます",
    ),
    "policyEmptyRules": MessageLookupByLibrary.simpleMessage("ローカルルールがありません"),
    "policyEnableBudgets": MessageLookupByLibrary.simpleMessage(
      "この端末の通信量制限を有効化",
    ),
    "policyEnableIntegrations": MessageLookupByLibrary.simpleMessage(
      "統合プロファイルを使用",
    ),
    "policyEnableRules": MessageLookupByLibrary.simpleMessage("振り分けルールを有効化"),
    "policyEndTime": MessageLookupByLibrary.simpleMessage("終了時刻（HH:mm）"),
    "policyExcluded": MessageLookupByLibrary.simpleMessage("現在の条件に不適合"),
    "policyExcludedNodes": MessageLookupByLibrary.simpleMessage("除外するノード"),
    "policyExpectedStatus": MessageLookupByLibrary.simpleMessage(
      "有効な HTTP ステータス",
    ),
    "policyExpiryMargin": MessageLookupByLibrary.simpleMessage("期限前に除外（時間）"),
    "policyFailures": MessageLookupByLibrary.simpleMessage("連続失敗回数"),
    "policyFallback": MessageLookupByLibrary.simpleMessage("候補がない場合"),
    "policyFallbackDirect": MessageLookupByLibrary.simpleMessage("直接接続を許可"),
    "policyFallbackReject": MessageLookupByLibrary.simpleMessage("接続を拒否"),
    "policyFixedNode": MessageLookupByLibrary.simpleMessage("指定ノード"),
    "policyGlobalScope": MessageLookupByLibrary.simpleMessage("すべての通信"),
    "policyGroupScope": MessageLookupByLibrary.simpleMessage("既存のグループ"),
    "policyHideUnavailable": MessageLookupByLibrary.simpleMessage(
      "利用不可のノードを自動非表示",
    ),
    "policyHistoryTab": MessageLookupByLibrary.simpleMessage("履歴"),
    "policyImprovementPercent": MessageLookupByLibrary.simpleMessage(
      "遅延改善のしきい値（%）",
    ),
    "policyIncludeSubdomains": MessageLookupByLibrary.simpleMessage(
      "サブドメインを含む",
    ),
    "policyIntegrationHint": MessageLookupByLibrary.simpleMessage(
      "選択した購読のノードを独立したプロファイルにまとめ、元の購読は保持します。残り通信量は事業者から提供された場合のみ表示します",
    ),
    "policyIntegrationTab": MessageLookupByLibrary.simpleMessage("購読の統合"),
    "policyInvalidData": MessageLookupByLibrary.simpleMessage(
      "項目、順序、参照が不正です。確認してください",
    ),
    "policyJsonHint": MessageLookupByLibrary.simpleMessage(
      "現行スキーマのみ対応。不正な項目・参照は適用できません",
    ),
    "policyLatencyFirst": MessageLookupByLibrary.simpleMessage("低遅延を優先"),
    "policyLedgerUntrusted": MessageLookupByLibrary.simpleMessage(
      "台帳を確認できないためソースを制限",
    ),
    "policyLoadNodes": MessageLookupByLibrary.simpleMessage("利用可能なノードを読み込む"),
    "policyLocalCollection": MessageLookupByLibrary.simpleMessage("統合プロファイル"),
    "policyManualAttribute": MessageLookupByLibrary.simpleMessage("手動確認"),
    "policyManualOrigin": MessageLookupByLibrary.simpleMessage("手動追加"),
    "policyMatchAll": MessageLookupByLibrary.simpleMessage("全条件（詳細）"),
    "policyMatchAny": MessageLookupByLibrary.simpleMessage("いずれか（詳細）"),
    "policyMatchNot": MessageLookupByLibrary.simpleMessage("否定条件（詳細）"),
    "policyMemberPreview": MessageLookupByLibrary.simpleMessage("メンバーのプレビュー"),
    "policyMetadataAge": MessageLookupByLibrary.simpleMessage("メタデータの有効時間（時間）"),
    "policyMethod": MessageLookupByLibrary.simpleMessage("リクエスト方式"),
    "policyMissingNode": MessageLookupByLibrary.simpleMessage("ノードがありません"),
    "policyModule": MessageLookupByLibrary.simpleMessage("ローカルルール機能を有効化"),
    "policyModuleOffHint": MessageLookupByLibrary.simpleMessage(
      "無効にするとルール、購読統合、通信量制限を停止します。保存済み設定は残ります",
    ),
    "policyMoreSettings": MessageLookupByLibrary.simpleMessage("その他の設定"),
    "policyMoveDown": MessageLookupByLibrary.simpleMessage("下へ"),
    "policyMoveUp": MessageLookupByLibrary.simpleMessage("上へ"),
    "policyMultiplierFirst": MessageLookupByLibrary.simpleMessage("低倍率を優先"),
    "policyMultiplierLimit": MessageLookupByLibrary.simpleMessage("倍率の上限"),
    "policyNameAttribute": MessageLookupByLibrary.simpleMessage("名前から識別"),
    "policyNameFilter": MessageLookupByLibrary.simpleMessage("ノード名に含む文字（任意）"),
    "policyNoMembers": MessageLookupByLibrary.simpleMessage(
      "一致するメンバーがなく、予備または最終処理を使用",
    ),
    "policyNoProfilesHint": MessageLookupByLibrary.simpleMessage(
      "ルールや候補ノードグループを作る前に、「プロファイル」で購読またはローカル設定を追加してください",
    ),
    "policyNodeSet": MessageLookupByLibrary.simpleMessage("候補ノードグループ"),
    "policyNodeSetHint": MessageLookupByLibrary.simpleMessage(
      "地域、配信元、通信量倍率で絞り込み、条件に合うノードを1つ選びます。通信量の均等分散は行いません",
    ),
    "policyNodeSetStrategy": MessageLookupByLibrary.simpleMessage("ノード選択方法"),
    "policyNodeSetStrategyHint": MessageLookupByLibrary.simpleMessage(
      "安定優先は現在のノードを維持し、低遅延優先は検査の遅延で選び、低倍率優先は事業者の通信量課金倍率で選びます",
    ),
    "policyNodeSetTarget": MessageLookupByLibrary.simpleMessage("ノードの所属プロファイル"),
    "policyNodeSets": MessageLookupByLibrary.simpleMessage("候補ノードグループ"),
    "policyNodes": MessageLookupByLibrary.simpleMessage("ノード"),
    "policyNotCollected": MessageLookupByLibrary.simpleMessage("未収集"),
    "policyNotRunning": MessageLookupByLibrary.simpleMessage("現在停止中"),
    "policyOperationFailed": MessageLookupByLibrary.simpleMessage(
      "操作が未完了です。状態を確認してください",
    ),
    "policyOverrideMinutes": MessageLookupByLibrary.simpleMessage("有効な分数"),
    "policyPageSampleAt": MessageLookupByLibrary.simpleMessage("状態の取得時刻"),
    "policyPendingMembers": MessageLookupByLibrary.simpleMessage("確認待ちのメンバー"),
    "policyPreferred": MessageLookupByLibrary.simpleMessage("優先"),
    "policyPreparingStatus": MessageLookupByLibrary.simpleMessage("処理中"),
    "policyPreviewHint": MessageLookupByLibrary.simpleMessage(
      "ノード選択のプレビュー。実際の通信は検証しません",
    ),
    "policyPriority": MessageLookupByLibrary.simpleMessage("優先度（小さい順）"),
    "policyProbe": MessageLookupByLibrary.simpleMessage("死活確認"),
    "policyProbeInterval": MessageLookupByLibrary.simpleMessage("確認間隔（秒）"),
    "policyProbeTimeout": MessageLookupByLibrary.simpleMessage("確認タイムアウト（秒）"),
    "policyProbeUrl": MessageLookupByLibrary.simpleMessage("確認 URL"),
    "policyProcessHint": MessageLookupByLibrary.simpleMessage(
      "プロセス識別はシステム権限と接続方式に依存します",
    ),
    "policyProcessName": MessageLookupByLibrary.simpleMessage("プロセス名"),
    "policyProcessPath": MessageLookupByLibrary.simpleMessage("プロセスのパス"),
    "policyRecovery": MessageLookupByLibrary.simpleMessage("復旧とクールダウン"),
    "policyRecoveryCheck": MessageLookupByLibrary.simpleMessage("確認して復元"),
    "policyRecoveryKeep": MessageLookupByLibrary.simpleMessage("確認済みの現在の設定を保持"),
    "policyRecoverySeconds": MessageLookupByLibrary.simpleMessage("復旧確認時間（秒）"),
    "policyRecoveryStatus": MessageLookupByLibrary.simpleMessage("復元が必要"),
    "policyRegions": MessageLookupByLibrary.simpleMessage("地域"),
    "policyRejectedStatus": MessageLookupByLibrary.simpleMessage("拒否済み"),
    "policyRemainingGiB": MessageLookupByLibrary.simpleMessage("残量の下限（GiB）"),
    "policyRemainingTraffic": MessageLookupByLibrary.simpleMessage("その他の通信"),
    "policyRemoveCandidate": MessageLookupByLibrary.simpleMessage("候補を削除"),
    "policyRemoveOverride": MessageLookupByLibrary.simpleMessage("一時指定を解除"),
    "policyResetDay": MessageLookupByLibrary.simpleMessage("月次リセット日（1–28）"),
    "policyRestoredStatus": MessageLookupByLibrary.simpleMessage("復元済み"),
    "policyRestrictedMembers": MessageLookupByLibrary.simpleMessage(
      "制限されたメンバー",
    ),
    "policyRetrySeconds": MessageLookupByLibrary.simpleMessage(
      "利用不可ノードの再確認（秒）",
    ),
    "policyRuleOrderHint": MessageLookupByLibrary.simpleMessage(
      "上から順に確認し、最初の一致を使用",
    ),
    "policyRuleType": MessageLookupByLibrary.simpleMessage("ルールの種類"),
    "policyRulesHint": MessageLookupByLibrary.simpleMessage(
      "選択したプロファイルのサイトやアプリに優先・予備ノードを設定します。そのプロファイルをルールモードで使用中に適用されます",
    ),
    "policyRulesTab": MessageLookupByLibrary.simpleMessage("ルール"),
    "policyRuntimeState": MessageLookupByLibrary.simpleMessage("実行状態"),
    "policySaved": MessageLookupByLibrary.simpleMessage("保存しました"),
    "policySavedInactive": MessageLookupByLibrary.simpleMessage("保存済み、現在停止中"),
    "policySchedule": MessageLookupByLibrary.simpleMessage("有効時間"),
    "policyScheduleEnabled": MessageLookupByLibrary.simpleMessage("有効時間を制限"),
    "policyScheduleHint": MessageLookupByLibrary.simpleMessage(
      "北京時間を使用。日をまたぐ時間帯は分割してください",
    ),
    "policyScheduleSkip": MessageLookupByLibrary.simpleMessage(
      "時間外はスキップして次のルールを確認",
    ),
    "policyScope": MessageLookupByLibrary.simpleMessage("適用範囲"),
    "policyScopeValues": MessageLookupByLibrary.simpleMessage(
      "ドメイン、グループ、プロセスを各行に入力",
    ),
    "policySearchNodes": MessageLookupByLibrary.simpleMessage("ノードやソースを検索"),
    "policySelectCollection": MessageLookupByLibrary.simpleMessage("選択して使用"),
    "policySelectedNode": MessageLookupByLibrary.simpleMessage("現在のノード"),
    "policySelectedOffline": MessageLookupByLibrary.simpleMessage(
      "選択済み、接続後に使用",
    ),
    "policySelectionRecoverySection": MessageLookupByLibrary.simpleMessage(
      "選択と復帰",
    ),
    "policySharedSetImpact": MessageLookupByLibrary.simpleMessage(
      "共有集合の変更は参照するルールに影響します",
    ),
    "policyShowUnavailable": MessageLookupByLibrary.simpleMessage(
      "すべてのメンバーを表示",
    ),
    "policySimulation": MessageLookupByLibrary.simpleMessage("シナリオシミュレーション"),
    "policySimulationCoreRequired": MessageLookupByLibrary.simpleMessage(
      "シミュレーションには稼働中のプロキシコアが必要です",
    ),
    "policySimulationHint": MessageLookupByLibrary.simpleMessage(
      "独立したコールドスタートのシナリオです。稼働フラグと使用量を入力の仮定として使い、現在の選択、検査時刻、遅延、待機、復旧の進行状態は引き継ぎません。現在の動作予測ではありません。実際の検査や設定変更は行いません。",
    ),
    "policySimulationSteps": MessageLookupByLibrary.simpleMessage(
      "シナリオ手順（高度な JSON）",
    ),
    "policySimulationStepsHint": MessageLookupByLibrary.simpleMessage(
      "最大32手順。at はミリ秒、probes は nodeId と success、sources はメタデータ、usage はソース別使用バイト数です。実際の検査や設定変更は行いません。",
    ),
    "policySimulationTimeline": MessageLookupByLibrary.simpleMessage(
      "候補の切り替え履歴",
    ),
    "policySourceExpiry": MessageLookupByLibrary.simpleMessage("サブスクリプション期限"),
    "policySourceMissing": MessageLookupByLibrary.simpleMessage(
      "ソースまたはノードがありません。再選択してください",
    ),
    "policySourceQuota": MessageLookupByLibrary.simpleMessage("事業者が報告した残り通信量"),
    "policySourceQuotaUnknown": MessageLookupByLibrary.simpleMessage(
      "購読に通信量情報がありません",
    ),
    "policySources": MessageLookupByLibrary.simpleMessage("購読元を選択"),
    "policySourcesCollection": MessageLookupByLibrary.simpleMessage("ノードの配信元"),
    "policyStableFirst": MessageLookupByLibrary.simpleMessage("安定性を優先"),
    "policyStartTime": MessageLookupByLibrary.simpleMessage("開始時刻（HH:mm）"),
    "policySubscriptionExhausted": MessageLookupByLibrary.simpleMessage(
      "プランの通信量を使い切りました",
    ),
    "policySubscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "購読の期限切れ",
    ),
    "policySuccesses": MessageLookupByLibrary.simpleMessage("連続成功回数"),
    "policySupersededStatus": MessageLookupByLibrary.simpleMessage("後続の変更で置換"),
    "policyTarget": MessageLookupByLibrary.simpleMessage("ルールを適用するプロファイル"),
    "policyTargetHint": MessageLookupByLibrary.simpleMessage(
      "このプロファイルを使用中に適用されます。ここで選択しても使用中のプロファイルは切り替わりません",
    ),
    "policyTemporaryOverride": MessageLookupByLibrary.simpleMessage("一時的な指定"),
    "policyTerminate": MessageLookupByLibrary.simpleMessage("ソース除外時に関連接続を終了"),
    "policyTerminateHint": MessageLookupByLibrary.simpleMessage(
      "既存の接続を切断します。適用前に確認が必要です",
    ),
    "policyTrafficSection": MessageLookupByLibrary.simpleMessage("対象の通信"),
    "policyUndo": MessageLookupByLibrary.simpleMessage("この変更を元に戻す"),
    "policyUnknownAttribute": MessageLookupByLibrary.simpleMessage("不明"),
    "policyUnknownHealth": MessageLookupByLibrary.simpleMessage("死活状態が不明"),
    "policyUnknownMetadata": MessageLookupByLibrary.simpleMessage(
      "不明なソース情報を除外",
    ),
    "policyUnknownMultiplierAllowed": MessageLookupByLibrary.simpleMessage(
      "倍率を仮定せず不明を許可",
    ),
    "policyUnknownNameOrigin": MessageLookupByLibrary.simpleMessage("出所不明"),
    "policyUnknownOne": MessageLookupByLibrary.simpleMessage("不明な倍率を 1× として扱う"),
    "policyUnknownOneHint": MessageLookupByLibrary.simpleMessage(
      "絞り込みと並べ替えのみに使用し、不明表示を維持",
    ),
    "policyUnsavedTitle": MessageLookupByLibrary.simpleMessage("未保存の変更"),
    "policyUnsupportedSourceOption": m27,
    "policyUpdateProxyUnavailable": MessageLookupByLibrary.simpleMessage(
      "プロキシを利用できないため更新を停止しました。起動するか、直接更新を明示的に選択してください。",
    ),
    "policyUpdateRoute": MessageLookupByLibrary.simpleMessage("サブスクリプション更新経路"),
    "policyUpdateRouteDirect": MessageLookupByLibrary.simpleMessage("直接接続"),
    "policyUpdateRouteHint": MessageLookupByLibrary.simpleMessage(
      "ローカルポリシー、統合、予算の有効時に使用します。プロキシ停止中は更新しません。直接接続には確認が必要です。",
    ),
    "policyUpdateRouteProxy": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシを使用",
    ),
    "policyUsage": MessageLookupByLibrary.simpleMessage("ローカル使用量"),
    "policyUsageUnknown": MessageLookupByLibrary.simpleMessage("使用量は確認待ち"),
    "policyValiditySeconds": MessageLookupByLibrary.simpleMessage("測定の有効期間（秒）"),
    "policyViewChanges": MessageLookupByLibrary.simpleMessage("差分を見る"),
    "policyWebsite": MessageLookupByLibrary.simpleMessage("ウェブサイト"),
    "policyWeekdays": MessageLookupByLibrary.simpleMessage("曜日（1=月、7=日）"),
    "policyWorkbenchTitle": MessageLookupByLibrary.simpleMessage("ローカルルール"),
    "port": MessageLookupByLibrary.simpleMessage("ポート"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("別のポートを入力してください"),
    "portTip": m28,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage("DOHのHTTP/3を優先使用"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prerequisites"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("キーボードを押してください"),
    "preview": MessageLookupByLibrary.simpleMessage("プレビュー"),
    "process": MessageLookupByLibrary.simpleMessage("プロセス"),
    "processRecognitionOff": MessageLookupByLibrary.simpleMessage(
      "プロセス識別がオフです。識別できないアプリの使用量は不明として集計されます。",
    ),
    "processRecognitionUnavailable": MessageLookupByLibrary.simpleMessage(
      "プロセス識別は有効ですが、この期間ではアプリを識別できませんでした。過去の不明な通信量は補完できません。",
    ),
    "profile": MessageLookupByLibrary.simpleMessage("プロファイル"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("有効な間隔形式を入力してください"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("自動更新間隔を入力してください"),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "プロファイルが変更されました。自動更新を無効化しますか？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイル名を入力してください",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "有効なプロファイルURLを入力してください",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "プロファイルURLを入力してください",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("プロファイル一覧"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("プロファイルの並び替え"),
    "project": MessageLookupByLibrary.simpleMessage("プロジェクト"),
    "providers": MessageLookupByLibrary.simpleMessage("プロバイダー"),
    "proxies": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxiesEmpty": MessageLookupByLibrary.simpleMessage("プロキシが空です"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("プロキシチェーン"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "選択されたプロキシに異常があることを検出しました",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("プロキシフィルター"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("プロキシグループ"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "現在のプロキシグループが異常であることを検出しました",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("プロキシグループが空です"),
    "proxyGroupNameDuplicate": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名が重複しています",
    ),
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシグループ名は空にできません",
    ),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("プロキシネームサーバー"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "プロキシノード解決用ドメイン",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("プロキシポート"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "選択されたプロキシプロバイダーに異常があることを検出しました",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("プロキシプロバイダー"),
    "proxyProvidersEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーが空です",
    ),
    "proxyProvidersNotEmpty": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーは空にできません",
    ),
    "proxyTraffic": MessageLookupByLibrary.simpleMessage("プロキシ"),
    "proxyType": MessageLookupByLibrary.simpleMessage("プロキシタイプ"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("キャッシュの削除"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("純黒モード"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QRコード"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("QRコードをスキャンしてプロファイルを取得"),
    "quickFill": MessageLookupByLibrary.simpleMessage("クイック入力"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("レインボー"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redirポート"),
    "redo": MessageLookupByLibrary.simpleMessage("やり直す"),
    "remote": MessageLookupByLibrary.simpleMessage("リモート"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "設定、AI 接続と暗号化キー、ローカルルールと履歴を WebDAV にバックアップ",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("リモート宛先"),
    "remove": MessageLookupByLibrary.simpleMessage("削除"),
    "rename": MessageLookupByLibrary.simpleMessage("リネーム"),
    "request": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requests": MessageLookupByLibrary.simpleMessage("リクエスト"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("最近のリクエスト記録を表示"),
    "reset": MessageLookupByLibrary.simpleMessage("リセット"),
    "resetFilters": MessageLookupByLibrary.simpleMessage("フィルターをリセット"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "現在のページに変更があります。リセットしてもよろしいですか？",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage("リセットを確定"),
    "resources": MessageLookupByLibrary.simpleMessage("リソース"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("外部リソース関連情報"),
    "respectRules": MessageLookupByLibrary.simpleMessage("ルール尊重"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS接続がルールに従う（proxy-server-nameserverの設定が必要）",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("再起動"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("コアを再起動してもよろしいですか？"),
    "restore": MessageLookupByLibrary.simpleMessage("復元"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("設定、AI、ローカルルールを復元"),
    "restoreException": MessageLookupByLibrary.simpleMessage("復元例外"),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "バックアップファイルから復元。完全復元には AI とローカルルールを含みます",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAV バックアップから復元。完全復元には AI とローカルルールを含みます",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("設定ファイルのみを復元する"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("復元ストラテジー"),
    "restoreStrategy_compatible": MessageLookupByLibrary.simpleMessage("互換"),
    "restoreStrategy_override": MessageLookupByLibrary.simpleMessage("上書き"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("復元に成功しました"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("ルートアドレス"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage("ルートアドレスを設定"),
    "routeMode": MessageLookupByLibrary.simpleMessage("ルートモード"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "プライベートルートをバイパス",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("設定を使用"),
    "ru": MessageLookupByLibrary.simpleMessage("ロシア語"),
    "rule": MessageLookupByLibrary.simpleMessage("ルール"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("論理ルール AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "完全なドメインをマッチング",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "ドメインキーワードをマッチング",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "ワイルドカードマッチング（*と?のみサポート）",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "ドメイン接尾辞をマッチング",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "DSCPマークをマッチング (tproxy udp inboundのみ)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "宛先ポート範囲をマッチング",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "IPの国コードをマッチング",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Match domains within Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンド名をマッチング",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドポートをマッチング",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドタイプをマッチング",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "インバウンドユーザー名をマッチング（/で複数指定可）",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage("IPのASNをマッチング"),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "IPアドレス範囲をマッチング（IP-CIDR6はエイリアスです）",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "IPアドレス範囲をマッチング",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "IP接尾辞範囲をマッチング",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "すべてのリクエストにマッチ（条件なし）",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "TCPまたはUDPをマッチング",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("論理ルール NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("論理ルール OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名でマッチング（Androidではパッケージ名）",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセス名正規表現でマッチング（Androidではパッケージ名）",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "フルプロセスパスでマッチング",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "プロセスパス正規表現でマッチング",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "ルールセットを参照。rule-providersの設定が必要",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPの国コードをマッチング",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPのASNをマッチング",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IPアドレス範囲をマッチング",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "送信元IP接尾辞範囲をマッチング",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "送信元ポート範囲をマッチング",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "サブルールにマッチング。括弧の使用に注意",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Linux USER IDをマッチング",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("ルールが空です"),
    "ruleName": MessageLookupByLibrary.simpleMessage("ルール名"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("ルールプロバイダー"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("ルールセット"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("ルール対象"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("変更を保存しますか？"),
    "script": MessageLookupByLibrary.simpleMessage("スクリプト"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "スクリプトモード、外部拡張スクリプトを使用し、ワンクリックで設定を上書きする機能を提供",
    ),
    "search": MessageLookupByLibrary.simpleMessage("検索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "secondsCount": m29,
    "selectAll": MessageLookupByLibrary.simpleMessage("すべて選択"),
    "selectProxies": MessageLookupByLibrary.simpleMessage("プロキシを選択"),
    "selectProxyProviders": MessageLookupByLibrary.simpleMessage(
      "プロキシプロバイダーを選択",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("ルールセットを選択してください"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "分流戦略を選択してください",
    ),
    "selectSubRule": MessageLookupByLibrary.simpleMessage("サブルールを選択してください"),
    "selected": MessageLookupByLibrary.simpleMessage("選択済み"),
    "selectedCountTitle": m30,
    "settings": MessageLookupByLibrary.simpleMessage("設定"),
    "show": MessageLookupByLibrary.simpleMessage("表示"),
    "shrink": MessageLookupByLibrary.simpleMessage("縮小"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("バックグラウンド起動"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage("バックグラウンドで起動"),
    "size": MessageLookupByLibrary.simpleMessage("サイズ"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socksポート"),
    "sort": MessageLookupByLibrary.simpleMessage("並び替え"),
    "sortByConnections": MessageLookupByLibrary.simpleMessage("接続数"),
    "sortByDownload": MessageLookupByLibrary.simpleMessage("ダウンロード"),
    "sortByTotal": MessageLookupByLibrary.simpleMessage("合計"),
    "sortByUpload": MessageLookupByLibrary.simpleMessage("アップロード"),
    "source": MessageLookupByLibrary.simpleMessage("ソース"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("送信元IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊プロキシ"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊ルール"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("速度統計"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("分流戦略"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "分流戦略は空にできません",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs is empty"),
    "stackMode": MessageLookupByLibrary.simpleMessage("スタックモード"),
    "standard": MessageLookupByLibrary.simpleMessage("標準"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "標準モード、基本設定を上書きし、シンプルなルール追加機能を提供",
    ),
    "start": MessageLookupByLibrary.simpleMessage("開始"),
    "startVpn": MessageLookupByLibrary.simpleMessage("VPNを開始中..."),
    "status": MessageLookupByLibrary.simpleMessage("ステータス"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("無効時はシステムDNSを使用"),
    "stop": MessageLookupByLibrary.simpleMessage("停止"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("VPNを停止中..."),
    "style": MessageLookupByLibrary.simpleMessage("スタイル"),
    "subRule": MessageLookupByLibrary.simpleMessage("サブルール"),
    "subRuleEmpty": MessageLookupByLibrary.simpleMessage("サブルールが空です"),
    "subRuleNotEmpty": MessageLookupByLibrary.simpleMessage("サブルールは空にできません"),
    "submit": MessageLookupByLibrary.simpleMessage("送信"),
    "suspended": MessageLookupByLibrary.simpleMessage("一時停止中..."),
    "sync": MessageLookupByLibrary.simpleMessage("同期"),
    "system": MessageLookupByLibrary.simpleMessage("システム"),
    "systemApp": MessageLookupByLibrary.simpleMessage("システムアプリ"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("システムプロキシ"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "HTTPプロキシをVpnServiceに接続",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("タブ"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("タブアニメーション"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage("モバイル表示でのみ有効"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("タップして許可"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP並列処理"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage("TCP並列処理を許可"),
    "testInterval": MessageLookupByLibrary.simpleMessage("テスト間隔"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URLテスト"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("使用時にテスト"),
    "textScale": MessageLookupByLibrary.simpleMessage("テキストスケーリング"),
    "theme": MessageLookupByLibrary.simpleMessage("テーマ"),
    "themeColor": MessageLookupByLibrary.simpleMessage("テーマカラー"),
    "themeDesc": MessageLookupByLibrary.simpleMessage("ダークモードの設定、色の調整"),
    "themeMode": MessageLookupByLibrary.simpleMessage("テーマモード"),
    "tight": MessageLookupByLibrary.simpleMessage("密"),
    "time": MessageLookupByLibrary.simpleMessage("時間"),
    "timeTrend": MessageLookupByLibrary.simpleMessage("時間推移"),
    "timeout": MessageLookupByLibrary.simpleMessage("タイムアウト"),
    "tip": MessageLookupByLibrary.simpleMessage("ヒント"),
    "todayProxyUsage": MessageLookupByLibrary.simpleMessage("今日のプロキシ使用量"),
    "toggle": MessageLookupByLibrary.simpleMessage("トグル"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("トーンスポット"),
    "tools": MessageLookupByLibrary.simpleMessage("ツール"),
    "topApplications": MessageLookupByLibrary.simpleMessage("上位アプリ"),
    "topDomains": MessageLookupByLibrary.simpleMessage("上位ドメイン"),
    "topNodes": MessageLookupByLibrary.simpleMessage("上位ノード"),
    "topProfiles": MessageLookupByLibrary.simpleMessage("上位の設定プロファイル"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxyポート"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("トラフィック使用量"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage("管理者モードでのみ有効"),
    "turnOff": MessageLookupByLibrary.simpleMessage("オフ"),
    "turnOn": MessageLookupByLibrary.simpleMessage("オン"),
    "undo": MessageLookupByLibrary.simpleMessage("元に戻す"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("統一遅延"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "ハンドシェイクなどの余分な遅延を削除",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("不明"),
    "unknownApplication": MessageLookupByLibrary.simpleMessage("不明なアプリ"),
    "unknownDomain": MessageLookupByLibrary.simpleMessage("不明なドメインまたは IP"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage("不明なネットワークエラー"),
    "unknownNode": MessageLookupByLibrary.simpleMessage("不明なノード"),
    "unknownProfile": MessageLookupByLibrary.simpleMessage("不明な設定プロファイル"),
    "unnamed": MessageLookupByLibrary.simpleMessage("無題"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "upload": MessageLookupByLibrary.simpleMessage("アップロード"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage("URL経由でプロファイルを取得"),
    "urlTip": m31,
    "usage": MessageLookupByLibrary.simpleMessage("使用量"),
    "usageApplications": MessageLookupByLibrary.simpleMessage("アプリ"),
    "usageConnections": MessageLookupByLibrary.simpleMessage("接続数"),
    "usageDegradedIssue": MessageLookupByLibrary.simpleMessage(
      "保留キューが安全上限に達したため、使用量の詳細を縮約しました。合計バイト数は保持されますが、一部のアプリ、ドメイン、ノード、購読、または分単位の詳細は利用できません。",
    ),
    "usageDesc": MessageLookupByLibrary.simpleMessage(
      "時間、ノード、アプリ、ドメイン、プロファイル別のローカルトラフィック",
    ),
    "usageDomains": MessageLookupByLibrary.simpleMessage("ドメイン"),
    "usageNodes": MessageLookupByLibrary.simpleMessage("ノード"),
    "usageNotEnabled": MessageLookupByLibrary.simpleMessage("使用量の記録はオフです"),
    "usageNotEnabledDesc": MessageLookupByLibrary.simpleMessage(
      "アプリケーション設定で手動で有効にしてください。過去の通信量は復元できません。",
    ),
    "usageOverview": MessageLookupByLibrary.simpleMessage("概要"),
    "usagePersistenceIssue": MessageLookupByLibrary.simpleMessage(
      "使用量データを保存できません。自動的に再試行します。この警告が消えるまで記録を無効にしたりアプリを終了したりしないでください。",
    ),
    "usagePrivacyDesc": MessageLookupByLibrary.simpleMessage(
      "FlClash は通信量、プロセスパス、ドメイン、宛先 IP、ノード、プロファイルのスナップショットをこの Mac に保存します。分単位の詳細は90日間保持され、設定や WebDAV バックアップには含まれません。過去のデータは復元できず、請求データではありません。",
    ),
    "usagePrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "ローカル使用量記録を有効にしますか？",
    ),
    "usageProfiles": MessageLookupByLibrary.simpleMessage("設定プロファイル"),
    "usageProfilesDesc": MessageLookupByLibrary.simpleMessage(
      "各接続の開始時に有効だった FlClash 設定プロファイル別に集計します。プロバイダーの容量や請求通信量ではありません。",
    ),
    "usageRecording": MessageLookupByLibrary.simpleMessage("使用量の記録"),
    "usageRecordingDesc": MessageLookupByLibrary.simpleMessage(
      "この Mac に分単位の通信量・アプリ・ドメイン統計を90日間保存します",
    ),
    "usageToday": MessageLookupByLibrary.simpleMessage("今日"),
    "usageTotal": MessageLookupByLibrary.simpleMessage("合計"),
    "useHosts": MessageLookupByLibrary.simpleMessage("ホストを使用"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("システムホストを使用"),
    "userAgent": MessageLookupByLibrary.simpleMessage("ユーザーエージェント"),
    "value": MessageLookupByLibrary.simpleMessage("値"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("ビブラント"),
    "view": MessageLookupByLibrary.simpleMessage("表示"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN設定の変更が検出されました",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "VpnService経由で全システムトラフィックをルーティング",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage("変更はVPN再起動後に有効"),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV設定"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("ホワイトリストモード"),
    "yearsAgo": m32,
    "zh_CN": MessageLookupByLibrary.simpleMessage("簡体字中国語"),
  };
}
