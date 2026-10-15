// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(count) => "Fetched ${count} models";

  static String m1(kind, added, updated, removed) =>
      "${kind}: ${added} added, ${updated} changed, ${removed} removed";

  static String m2(ruleCount, nodeSetCount) =>
      "${ruleCount} rules · ${nodeSetCount} node groups";

  static String m3(label) => "Duplicate rule: ${label}";

  static String m4(count) =>
      "${Intl.plural(count, one: '1 day ago', other: '${count} days ago')}";

  static String m5(label) =>
      "Are you sure you want to delete the selected ${label}?";

  static String m6(label) =>
      "Are you sure you want to delete the current ${label}?";

  static String m7(label) => "${label} details";

  static String m8(label) => "${label} cannot be empty";

  static String m9(count) => "${count} entries";

  static String m10(label) => "Current ${label} already exists";

  static String m11(name) => "${name} is already up to date";

  static String m12(name) => "${name} updated";

  static String m13(name) => "Updating ${name}...";

  static String m14(count) =>
      "${Intl.plural(count, one: '1 hour ago', other: '${count} hours ago')}";

  static String m15(count) => "${count} hours";

  static String m16(target) => "${target} is an invalid policy";

  static String m17(proxyName) => "${proxyName} is an invalid proxy";

  static String m18(providerName) =>
      "${providerName} is an invalid proxy provider";

  static String m19(subRule) => "${subRule} is an invalid SUB_RULE";

  static String m20(appName) =>
      "1. Open System Settings > Privacy & Security\n2. Choose Location Services\n3. Find and check ${appName} in the right list\n\nAfter completing the setup, return to the app and use it normally. Thank you for your cooperation.";

  static String m21(count) =>
      "${Intl.plural(count, one: '1 minute ago', other: '${count} minutes ago')}";

  static String m22(count) =>
      "${Intl.plural(count, one: '1 month ago', other: '${count} months ago')}";

  static String m23(label) => "No ${label} yet";

  static String m24(label) => "${label} must be a number";

  static String m25(target) =>
      "Read the existing rules, nodes and subscription sources for target ${target}, then create a reviewable proposal to add rules using those resources. Preserve the existing order; do not reorder existing rules or add another remaining-traffic rule. Create a draft and wait for my confirmation before applying it.";

  static String m26(target) =>
      "Read the existing rules, nodes and subscription sources for target ${target}, and propose reviewable rule improvements. Keep the current order and existing remaining-traffic rule. Only prepare proposals; wait for my confirmation before applying changes.";

  static String m27(sampleAt) => "Last valid reading: ${sampleAt}";

  static String m28(startAt) => "Period started: ${startAt}";

  static String m29(seconds) =>
      "Capacity estimate: at least ${seconds} seconds of validity is recommended; actual completion can take longer.";

  static String m30(option) =>
      "This source uses an unsupported option: ${option}. Local controls were not applied; remove this option first.";

  static String m31(label) => "${label} must be between 1024 and 49151";

  static String m32(count) => "Rules ${count}";

  static String m33(count) => "Sources ${count}";

  static String m34(count) => "${count} seconds";

  static String m35(count) => "${count} items have been selected";

  static String m36(label) => "${label} must be a url";

  static String m37(count) =>
      "${Intl.plural(count, one: '1 year ago', other: '${count} years ago')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "accessControl": MessageLookupByLibrary.simpleMessage("AccessControl"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Only allow selected app to enter VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Configure application access proxy",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "The selected application will be excluded from VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "Access Control Settings",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "action_mode": MessageLookupByLibrary.simpleMessage("Switch mode"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "action_start": MessageLookupByLibrary.simpleMessage("Start/Stop"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("Show/Hide"),
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addProfile": MessageLookupByLibrary.simpleMessage("Add Profile"),
    "addProxies": MessageLookupByLibrary.simpleMessage("Add proxies"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("Add proxy group"),
    "addProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Add proxy providers",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Add rule"),
    "addSsid": MessageLookupByLibrary.simpleMessage("Add SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("Added rules"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Additional parameters",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Address"),
    "addressHelp": MessageLookupByLibrary.simpleMessage(
      "WebDAV server address",
    ),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid WebDAV address",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Advanced configuration",
    ),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Provide diverse configuration options",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Agree"),
    "aiAddConnection": MessageLookupByLibrary.simpleMessage("Add connection"),
    "aiAdvanced": MessageLookupByLibrary.simpleMessage("Request limits"),
    "aiAfter": MessageLookupByLibrary.simpleMessage("After"),
    "aiApiProtocol": MessageLookupByLibrary.simpleMessage("API protocol"),
    "aiApprovalTitle": MessageLookupByLibrary.simpleMessage(
      "Review configuration changes",
    ),
    "aiApprove": MessageLookupByLibrary.simpleMessage("Approve and apply"),
    "aiApproveScriptExecution": MessageLookupByLibrary.simpleMessage(
      "Authorize preview execution",
    ),
    "aiApproved": MessageLookupByLibrary.simpleMessage("Approved"),
    "aiAssistant": MessageLookupByLibrary.simpleMessage("AI"),
    "aiAssistantRole": MessageLookupByLibrary.simpleMessage("Assistant"),
    "aiAssistantTitle": MessageLookupByLibrary.simpleMessage("AI assistant"),
    "aiAuthFailed": MessageLookupByLibrary.simpleMessage(
      "Authentication failed. Check the key for this endpoint",
    ),
    "aiAwaitingApproval": MessageLookupByLibrary.simpleMessage(
      "Awaiting approval; changes have not been applied",
    ),
    "aiBackupKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Complete or re-save your connection keys in AI settings before backing up",
    ),
    "aiBaseUrl": MessageLookupByLibrary.simpleMessage("Base URL"),
    "aiBefore": MessageLookupByLibrary.simpleMessage("Before"),
    "aiCanHelp": MessageLookupByLibrary.simpleMessage("Can help with"),
    "aiCancelled": MessageLookupByLibrary.simpleMessage("Stopped"),
    "aiCapabilityHint": MessageLookupByLibrary.simpleMessage(
      "Request an action in natural language using the current capability catalog",
    ),
    "aiChangeCompleted": MessageLookupByLibrary.simpleMessage("Completed"),
    "aiChangeExpired": MessageLookupByLibrary.simpleMessage("Expired"),
    "aiChangeFailed": MessageLookupByLibrary.simpleMessage(
      "Failed or interrupted",
    ),
    "aiChangeSavedPending": MessageLookupByLibrary.simpleMessage(
      "Saved; application pending",
    ),
    "aiChangesUnavailable": MessageLookupByLibrary.simpleMessage(
      "Some related records are no longer available.",
    ),
    "aiCheckResult": MessageLookupByLibrary.simpleMessage("Check result"),
    "aiChinaApi": MessageLookupByLibrary.simpleMessage("China API"),
    "aiChinaCoding": MessageLookupByLibrary.simpleMessage("China coding plan"),
    "aiClearConversation": MessageLookupByLibrary.simpleMessage(
      "Clear conversation",
    ),
    "aiCodingPlan": MessageLookupByLibrary.simpleMessage("Coding plan"),
    "aiConfigurationInvalid": MessageLookupByLibrary.simpleMessage(
      "Local configuration validation failed; nothing was saved. Check the configuration and retry",
    ),
    "aiConfigurationSaveFailed": MessageLookupByLibrary.simpleMessage(
      "Local configuration was not saved successfully. Check change history before retrying",
    ),
    "aiConnection": MessageLookupByLibrary.simpleMessage("Connection"),
    "aiConversationHistory": MessageLookupByLibrary.simpleMessage(
      "Conversation history",
    ),
    "aiConversationHistoryHint": MessageLookupByLibrary.simpleMessage(
      "Keeps the latest 20 conversations on this device, up to 80 text messages each. Opening one restores text only; old actions are never resumed. Deleting a conversation keeps its change journal.",
    ),
    "aiCredentialMigrationRequired": MessageLookupByLibrary.simpleMessage(
      "The old key could not be imported. Enter and save it again; future use needs no Keychain access",
    ),
    "aiCredentialRecoveryFailed": MessageLookupByLibrary.simpleMessage(
      "Key recovery failed. Configure the key again before use",
    ),
    "aiCredentialUnavailable": MessageLookupByLibrary.simpleMessage(
      "Cannot read the saved key. Enter and save it again",
    ),
    "aiCurrentConnection": MessageLookupByLibrary.simpleMessage(
      "Current connection",
    ),
    "aiCustomProvider": MessageLookupByLibrary.simpleMessage(
      "Custom compatible service",
    ),
    "aiDeleteConnection": MessageLookupByLibrary.simpleMessage(
      "Delete connection",
    ),
    "aiDeleteKey": MessageLookupByLibrary.simpleMessage("Delete key"),
    "aiDeleteKeyHint": MessageLookupByLibrary.simpleMessage(
      "Deleting the key cancels the AI task; local policies continue",
    ),
    "aiDisabled": MessageLookupByLibrary.simpleMessage(
      "AI assistant is disabled",
    ),
    "aiDiscardChanges": MessageLookupByLibrary.simpleMessage("Discard changes"),
    "aiDraftInvalid": MessageLookupByLibrary.simpleMessage(
      "This draft is out of date. Read the current configuration and create a new plan.",
    ),
    "aiEditConnection": MessageLookupByLibrary.simpleMessage("Edit connection"),
    "aiEmptyConversation": MessageLookupByLibrary.simpleMessage(
      "Inspect the current configuration, then preview changes",
    ),
    "aiEmptyHistory": MessageLookupByLibrary.simpleMessage(
      "No saved conversations",
    ),
    "aiEnable": MessageLookupByLibrary.simpleMessage("Enable AI assistant"),
    "aiEnableHint": MessageLookupByLibrary.simpleMessage(
      "Models run only when you send a message; local policies run independently",
    ),
    "aiFetchModels": MessageLookupByLibrary.simpleMessage("Fetch models"),
    "aiFinalConfigDifferences": MessageLookupByLibrary.simpleMessage(
      "Validated final configuration changes",
    ),
    "aiGlobalApi": MessageLookupByLibrary.simpleMessage("Global API"),
    "aiGlobalCoding": MessageLookupByLibrary.simpleMessage(
      "Global coding plan",
    ),
    "aiHighRisk": MessageLookupByLibrary.simpleMessage(
      "This change affects networking, configuration or privacy. Review before approving",
    ),
    "aiHistoryLimit": MessageLookupByLibrary.simpleMessage(
      "Conversation limit reached. Clear it to start again",
    ),
    "aiHistorySaveFailed": MessageLookupByLibrary.simpleMessage(
      "Could not save conversation history",
    ),
    "aiHostUnavailable": MessageLookupByLibrary.simpleMessage(
      "AI runtime is unavailable. Use a macOS build containing it",
    ),
    "aiInvalidConnection": MessageLookupByLibrary.simpleMessage(
      "Check name, model, URL and request limits",
    ),
    "aiKey": MessageLookupByLibrary.simpleMessage("API key"),
    "aiKeyHide": MessageLookupByLibrary.simpleMessage("Hide key"),
    "aiKeyMissing": MessageLookupByLibrary.simpleMessage(
      "Save a key for this connection first",
    ),
    "aiKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Enter an API key for this endpoint",
    ),
    "aiKeyShow": MessageLookupByLibrary.simpleMessage("Show key"),
    "aiKeyStored": MessageLookupByLibrary.simpleMessage(
      "Encrypted in app configuration; leave blank to keep",
    ),
    "aiLatestMessage": MessageLookupByLibrary.simpleMessage("Latest message"),
    "aiLinkedChanges": MessageLookupByLibrary.simpleMessage("Related changes"),
    "aiLinkedChangesHint": MessageLookupByLibrary.simpleMessage(
      "Live records from the existing change journal. Review differences here; use change history for available undo or recovery.",
    ),
    "aiManageChanges": MessageLookupByLibrary.simpleMessage(
      "Open change history",
    ),
    "aiManualModel": MessageLookupByLibrary.simpleMessage(
      "Model ID (manual entry available)",
    ),
    "aiMaxTokens": MessageLookupByLibrary.simpleMessage(
      "Maximum output tokens",
    ),
    "aiModel": MessageLookupByLibrary.simpleMessage("Model ID"),
    "aiModelFetchHint": MessageLookupByLibrary.simpleMessage(
      "Fetching models does not verify chat or tool calling. You can also enter a model ID manually.",
    ),
    "aiModelsEmpty": MessageLookupByLibrary.simpleMessage(
      "No models returned. Enter a model ID manually.",
    ),
    "aiModelsFetched": m0,
    "aiModelsUnsupported": MessageLookupByLibrary.simpleMessage(
      "This service does not support model discovery. Enter a model ID manually.",
    ),
    "aiNewConversation": MessageLookupByLibrary.simpleMessage(
      "New conversation",
    ),
    "aiNoConnection": MessageLookupByLibrary.simpleMessage(
      "Add a connection to start chatting",
    ),
    "aiNoDifferences": MessageLookupByLibrary.simpleMessage(
      "No changes to apply",
    ),
    "aiPolicyPlanChanges": m1,
    "aiPolicyPlanCounts": m2,
    "aiPolicyPlanDisabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "aiPolicyPlanDuplicate": m3,
    "aiPolicyPlanNeedsRevision": MessageLookupByLibrary.simpleMessage(
      "The plan has conflicts and needs revision before applying",
    ),
    "aiPolicyPlanNoRules": MessageLookupByLibrary.simpleMessage(
      "No rules configured",
    ),
    "aiPolicyPlanOrder": MessageLookupByLibrary.simpleMessage(
      "Resulting rule order",
    ),
    "aiPolicyPlanReady": MessageLookupByLibrary.simpleMessage(
      "Plan ready, not applied",
    ),
    "aiPolicyPlanShadow": MessageLookupByLibrary.simpleMessage(
      "Matches all traffic; later rules are checked only when this rule is inactive or has no available nodes",
    ),
    "aiPolicyPlanTitle": MessageLookupByLibrary.simpleMessage(
      "Local rule plan",
    ),
    "aiPolicyUnknownMultiplierExcluded": MessageLookupByLibrary.simpleMessage(
      "Exclude nodes with unknown multiplier",
    ),
    "aiPolicyUnknownRegionAllowed": MessageLookupByLibrary.simpleMessage(
      "Include nodes with unknown region",
    ),
    "aiPresetDefault": MessageLookupByLibrary.simpleMessage(
      "Leave blank for preset URL",
    ),
    "aiPromptHint": MessageLookupByLibrary.simpleMessage(
      "Describe what to inspect or change…",
    ),
    "aiProvider": MessageLookupByLibrary.simpleMessage("Provider and endpoint"),
    "aiQuotaExceeded": MessageLookupByLibrary.simpleMessage(
      "Quota exceeded. Check your provider account",
    ),
    "aiRateLimited": MessageLookupByLibrary.simpleMessage(
      "Rate limit reached. Retry later",
    ),
    "aiReject": MessageLookupByLibrary.simpleMessage("Reject"),
    "aiRequestFailed": MessageLookupByLibrary.simpleMessage(
      "Request failed. Check the connection or retry later",
    ),
    "aiResourceActivationArtifactMissing": MessageLookupByLibrary.simpleMessage(
      "The approved configuration is unavailable. Prepare and approve the change again.",
    ),
    "aiResourcePanelRequired": MessageLookupByLibrary.simpleMessage(
      "Choose the file or destination in the local panel to continue.",
    ),
    "aiResourceScopeChanged": MessageLookupByLibrary.simpleMessage(
      "This resource changed while the proposal was open. Prepare a new proposal.",
    ),
    "aiResourceUpdateAccepted": MessageLookupByLibrary.simpleMessage(
      "The update request was accepted. Completion will be confirmed by the local Core.",
    ),
    "aiResultCompleted": MessageLookupByLibrary.simpleMessage("Completed"),
    "aiReviewPlan": MessageLookupByLibrary.simpleMessage("Review plan"),
    "aiSaveAndUse": MessageLookupByLibrary.simpleMessage("Save and use"),
    "aiSaveFailed": MessageLookupByLibrary.simpleMessage(
      "Save failed. Connection and key recovery was attempted; check before retrying",
    ),
    "aiSaved": MessageLookupByLibrary.simpleMessage("Connection saved"),
    "aiScriptExecutionOnly": MessageLookupByLibrary.simpleMessage(
      "This authorizes restricted script execution for a preview only. Applying the final result requires another approval.",
    ),
    "aiScriptRuntimeUnavailable": MessageLookupByLibrary.simpleMessage(
      "The packaged script runtime is unavailable. Reinstall the application before running scripts.",
    ),
    "aiScriptSandboxRejected": MessageLookupByLibrary.simpleMessage(
      "Script execution was stopped by the local isolation limits.",
    ),
    "aiSearchModels": MessageLookupByLibrary.simpleMessage("Search models"),
    "aiSelectConnection": MessageLookupByLibrary.simpleMessage(
      "Use connection",
    ),
    "aiSelected": MessageLookupByLibrary.simpleMessage("Selected"),
    "aiSend": MessageLookupByLibrary.simpleMessage("Send"),
    "aiServiceCredentials": MessageLookupByLibrary.simpleMessage(
      "Service and credentials",
    ),
    "aiSettingsTitle": MessageLookupByLibrary.simpleMessage("AI connections"),
    "aiStartedWithProfile": MessageLookupByLibrary.simpleMessage(
      "Profile at start",
    ),
    "aiStop": MessageLookupByLibrary.simpleMessage("Stop"),
    "aiTargetChanged": MessageLookupByLibrary.simpleMessage(
      "Endpoint changed. Re-enter the key for this destination",
    ),
    "aiTestConnection": MessageLookupByLibrary.simpleMessage(
      "Test tool calling",
    ),
    "aiTestPartial": MessageLookupByLibrary.simpleMessage(
      "Streaming and tool tests were incomplete; agent support is unverified",
    ),
    "aiTestPassed": MessageLookupByLibrary.simpleMessage(
      "Authentication, text streaming and tools passed",
    ),
    "aiTesting": MessageLookupByLibrary.simpleMessage("Testing connection…"),
    "aiTestingCharges": MessageLookupByLibrary.simpleMessage(
      "Testing calls the selected model and may incur provider charges",
    ),
    "aiThinking": MessageLookupByLibrary.simpleMessage("Thinking…"),
    "aiTimedOut": MessageLookupByLibrary.simpleMessage(
      "Model request timed out",
    ),
    "aiTimeout": MessageLookupByLibrary.simpleMessage(
      "Request timeout (seconds)",
    ),
    "aiToolWorking": MessageLookupByLibrary.simpleMessage(
      "Running app command…",
    ),
    "aiUnsavedChanges": MessageLookupByLibrary.simpleMessage(
      "Unsaved connection changes",
    ),
    "aiUsageClearIrreversible": MessageLookupByLibrary.simpleMessage(
      "Clearing usage history cannot be undone. Source budget accounting will be retained.",
    ),
    "aiUseProxy": MessageLookupByLibrary.simpleMessage(
      "Use current proxy for model requests",
    ),
    "aiYou": MessageLookupByLibrary.simpleMessage("You"),
    "allTraffic": MessageLookupByLibrary.simpleMessage("All"),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Allow applications to bypass VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Some apps can bypass VPN when turned on",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("AllowLan"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Allow access proxy through the LAN",
    ),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "App access control",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Append System DNS",
    ),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "Forcefully append system DNS to the configuration",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Application"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Modify application related settings",
    ),
    "authorized": MessageLookupByLibrary.simpleMessage("Authorized"),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Auto check updates",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Auto check for updates when the app starts",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Auto close connections",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Auto close connections after change node",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Auto launch"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Follow the system self startup",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("AutoRun"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Auto run when the application is opened",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Auto set system DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Auto update"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto update interval (minutes)",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Backup"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Backup and Restore",
    ),
    "backupAndRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "Sync data via WebDAV or files",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("Backup success"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Basic configuration"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Modify the basic configuration globally",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Basic info"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Basic strategy"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "To ensure background operation, please disable battery optimization for this app. Tap to go to settings.",
    ),
    "batteryOptimizationStatusTip": MessageLookupByLibrary.simpleMessage(
      "Affected by the system, this status may not always be accurate.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Bind"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Blacklist mode"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Bypass domain"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Only takes effect when the system proxy is enabled",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "The cache is corrupt. Do you want to clear it?",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Cancel select all",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Check for updates"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "The current application is already the latest version",
    ),
    "clearData": MessageLookupByLibrary.simpleMessage("Clear Data"),
    "clearUsageData": MessageLookupByLibrary.simpleMessage("Clear usage data"),
    "clearUsageDataConfirm": MessageLookupByLibrary.simpleMessage(
      "All usage buckets and processed batch records will be permanently deleted. Continue?",
    ),
    "clearUsageDataDesc": MessageLookupByLibrary.simpleMessage(
      "Delete all locally stored usage statistics without changing the recording switch",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("Export clipboard"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("Clipboard import"),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Color schemes"),
    "columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "compatible": MessageLookupByLibrary.simpleMessage("Compatibility mode"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "Data detected in configuration",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to clear all data?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to delete the current proxy group?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to exit the current window?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to force crash the core?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "Existing data will be overwritten after confirmation",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Connected"),
    "connecting": MessageLookupByLibrary.simpleMessage("Connecting..."),
    "connection": MessageLookupByLibrary.simpleMessage("Connection"),
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "View current connections data",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivity："),
    "content": MessageLookupByLibrary.simpleMessage("Content"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Content cannot be empty",
    ),
    "contentScheme": MessageLookupByLibrary.simpleMessage("Content"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Control global added rules",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copy"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copying environment variables",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copy success"),
    "core": MessageLookupByLibrary.simpleMessage("Core"),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Core status"),
    "country": MessageLookupByLibrary.simpleMessage("Country"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Crash detected"),
    "crashDetectedTip": MessageLookupByLibrary.simpleMessage(
      "The app crashed during the previous run. To prevent repeated crashes, the current profile has been cleared and automatic configuration setup was skipped.",
    ),
    "crashTest": MessageLookupByLibrary.simpleMessage("Crash test"),
    "crashlytics": MessageLookupByLibrary.simpleMessage("Crash Analysis"),
    "crashlyticsTip": MessageLookupByLibrary.simpleMessage(
      "When enabled, automatically uploads crash logs without sensitive information when the app crashes",
    ),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Create Profile"),
    "creationTime": MessageLookupByLibrary.simpleMessage("Creation time"),
    "currentSessionUsage": MessageLookupByLibrary.simpleMessage(
      "Current session · recording off",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Custom"),
    "cut": MessageLookupByLibrary.simpleMessage("Cut"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "Data changes detected, do you want to save?",
    ),
    "dataCollectionContent": MessageLookupByLibrary.simpleMessage(
      "This app uses Firebase Crashlytics to collect crash information to improve app stability.\nThe collected data includes device information and crash details, but does not contain personal sensitive data.\nYou can disable this feature in settings.",
    ),
    "dataCollectionTip": MessageLookupByLibrary.simpleMessage(
      "Data Collection Notice",
    ),
    "daysAgo": m4,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Default nameserver",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "For resolving DNS server",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Default"),
    "delay": MessageLookupByLibrary.simpleMessage("Delay"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Delay Test"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteMultipTip": m5,
    "deleteTip": m6,
    "desc": MessageLookupByLibrary.simpleMessage(
      "A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("Destination"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "Destination GeoIP",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "Destination IPASN",
    ),
    "details": m7,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Relying on third-party api is for reference only",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Developer mode"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Developer mode is enabled.",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "directTraffic": MessageLookupByLibrary.simpleMessage("Direct"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Disable UDP"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Disclaimer"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "This software is only used for non-commercial purposes such as learning exchanges and scientific research. It is strictly prohibited to use this software for commercial purposes. Any commercial activity, if any, has nothing to do with this software.",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Disconnected"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Discover the new version",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Update DNS related settings",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS hijacking"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS mode"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "Do you want to pass",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Domain"),
    "domainTargets": MessageLookupByLibrary.simpleMessage(
      "Hosts and target IPs",
    ),
    "download": MessageLookupByLibrary.simpleMessage("Download"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Edit global rules",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Edit proxy"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("Edit proxy group"),
    "editRule": MessageLookupByLibrary.simpleMessage("Edit rule"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Edit SSID"),
    "emptyTip": m8,
    "en": MessageLookupByLibrary.simpleMessage("English"),
    "enableUsageRecording": MessageLookupByLibrary.simpleMessage(
      "Enable recording",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" entries"),
    "entriesCount": m9,
    "exclude": MessageLookupByLibrary.simpleMessage("Hidden from recent tasks"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "When the app is in the background, the app is hidden from the recent task",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage(
      "Exclude proxy filter",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Exclude SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "When connected to an excluded SSID Wi-Fi, the app running state will be automatically switched.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("Exclude type"),
    "existsTip": m10,
    "exit": MessageLookupByLibrary.simpleMessage("Exit"),
    "expand": MessageLookupByLibrary.simpleMessage("Standard"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Expected status"),
    "exportCsv": MessageLookupByLibrary.simpleMessage("Export CSV"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Export file"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Export logs"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Export Success"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("Expressive"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "ExternalController",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Once enabled, the Clash kernel can be controlled on port 9090",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("External fetch"),
    "externalLink": MessageLookupByLibrary.simpleMessage("External link"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeip filter"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip range"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Generally use offshore DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback filter"),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("Fidelity"),
    "file": MessageLookupByLibrary.simpleMessage("File"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("Directly upload profile"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "The file has been modified. Do you want to save the changes?",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Find process"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "There is a certain performance loss after opening",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("FontFamily"),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to force restart the core?",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("FruitSalad"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("Auto Update"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto Update Interval",
    ),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "Auto update interval must be greater than 0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Geo Options"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo Resources"),
    "geoSkipped": m11,
    "geoUpdated": m12,
    "geoUpdating": m13,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo Low Memory Mode",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling will use the Geo low memory loader",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Geoip code"),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Go"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Go to download"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Go to configure script",
    ),
    "goToSettings": MessageLookupByLibrary.simpleMessage("Go to settings"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Do you want to cache the changes?",
    ),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper service unavailable; TUN mode cannot be enabled. Reinstall FlClash to restore it.",
    ),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Hide from list"),
    "host": MessageLookupByLibrary.simpleMessage("Host"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Add Hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("Hotkey conflict"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Hotkey Management",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Use keyboard to control applications",
    ),
    "hourlyDistribution": MessageLookupByLibrary.simpleMessage(
      "24-hour distribution",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("hours"),
    "hoursAgo": m14,
    "hoursCount": m15,
    "icon": MessageLookupByLibrary.simpleMessage("Icon"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("Icon records"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Icon style"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("Icon URL"),
    "identificationCoverage": MessageLookupByLibrary.simpleMessage(
      "Identification coverage",
    ),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignore Battery Optimization",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Import"),
    "importFile": MessageLookupByLibrary.simpleMessage("Import from file"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage(
      "Include all proxies",
    ),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "Import all proxies not containing proxy groups, additional proxy groups can be added below",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Include all proxy providers",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "When enabled, it will override the imported proxy providers",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Long term effective"),
    "init": MessageLookupByLibrary.simpleMessage("Init"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Please enter the correct hotkey",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Input proxy group name",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Input rule content",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Intelligent selection",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Interval"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Intranet IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Invalid backup file",
    ),
    "invalidPolicy": m16,
    "invalidProxy": m17,
    "invalidProxyProvider": m18,
    "invalidSubRule": m19,
    "ipcidr": MessageLookupByLibrary.simpleMessage("Ipcidr"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "When turned on it will be able to receive IPv6 traffic",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Allow IPv6 inbound",
    ),
    "ja": MessageLookupByLibrary.simpleMessage("Japanese"),
    "justNow": MessageLookupByLibrary.simpleMessage("Just now"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Tcp keep alive interval",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Key"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "last24Hours": MessageLookupByLibrary.simpleMessage("24 hours"),
    "last30Days": MessageLookupByLibrary.simpleMessage("30 days"),
    "last7Days": MessageLookupByLibrary.simpleMessage("7 days"),
    "layout": MessageLookupByLibrary.simpleMessage("Layout"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "listen": MessageLookupByLibrary.simpleMessage("Listen"),
    "loadMore": MessageLookupByLibrary.simpleMessage("Load more"),
    "loadTest": MessageLookupByLibrary.simpleMessage("Load test"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Back up configuration, AI connections and encrypted keys, local rules and history to a file",
    ),
    "localControlChangePassword": MessageLookupByLibrary.simpleMessage(
      "Change password",
    ),
    "localControlCommands": MessageLookupByLibrary.simpleMessage(
      "View commands",
    ),
    "localControlCopyPath": MessageLookupByLibrary.simpleMessage(
      "Copy tool path",
    ),
    "localControlDescription": MessageLookupByLibrary.simpleMessage(
      "Control FlClash using local commands",
    ),
    "localControlDisabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "localControlExitHint": MessageLookupByLibrary.simpleMessage(
      "CLI is unavailable after the app exits. Hiding the window does not affect it.",
    ),
    "localControlPassword": MessageLookupByLibrary.simpleMessage(
      "CLI password",
    ),
    "localControlPasswordHint": MessageLookupByLibrary.simpleMessage(
      "Generated randomly on first use and retained after restart. Saving a new password invalidates the old one.",
    ),
    "localControlPasswordValidation": MessageLookupByLibrary.simpleMessage(
      "Use 12–128 Unicode characters without control characters.",
    ),
    "localControlRandomPassword": MessageLookupByLibrary.simpleMessage(
      "Generate a new random password",
    ),
    "localControlReady": MessageLookupByLibrary.simpleMessage(
      "Ready, local access only",
    ),
    "localControlSaveFailed": MessageLookupByLibrary.simpleMessage(
      "Saving or secure shutdown failed. The original password remains valid.",
    ),
    "localControlSecurity": MessageLookupByLibrary.simpleMessage(
      "Security and operation approval",
    ),
    "localControlSecurityHint": MessageLookupByLibrary.simpleMessage(
      "Configuration changes require preview and confirmation. System permissions use system prompts.",
    ),
    "localControlTitle": MessageLookupByLibrary.simpleMessage("Local CLI"),
    "localControlUnavailable": MessageLookupByLibrary.simpleMessage(
      "Service unavailable. Retry.",
    ),
    "localControlUsage": MessageLookupByLibrary.simpleMessage("Usage"),
    "localControlUsageHint": MessageLookupByLibrary.simpleMessage(
      "Enter the password when running a command. Scripts can supply it through stdin or a separate file descriptor.",
    ),
    "localPolicies": MessageLookupByLibrary.simpleMessage("Local policies"),
    "localUsageNotice": MessageLookupByLibrary.simpleMessage(
      "Recorded locally; not billing-grade data",
    ),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Location Permission",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Location permission was denied, so the current Wi-Fi name cannot be obtained. Please open location permission manually in system settings.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "According to system requirements, obtaining the Wi-Fi name requires you to grant location permission.",
    ),
    "locationPermissionGuide": m20,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Location Permission Required",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Log"),
    "logLevel": MessageLookupByLibrary.simpleMessage("LogLevel"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Disabling will hide the log entry",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Logs"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("Log capture records"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Logs test"),
    "loopback": MessageLookupByLibrary.simpleMessage("Loopback unlock tool"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Used for UWP loopback unlocking",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Loose"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("Match source IP"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("Max failed times"),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Memory info"),
    "messageTest": MessageLookupByLibrary.simpleMessage("Message test"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "This is a message.",
    ),
    "min": MessageLookupByLibrary.simpleMessage("Min"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("Minimize on exit"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Modify the default system exit event",
    ),
    "minutesAgo": m21,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixed Port"),
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "monthsAgo": m22,
    "more": MessageLookupByLibrary.simpleMessage("More"),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Nameserver"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "For resolving domain",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Nameserver policy",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Specify the corresponding nameserver policy",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Network"),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Modify network-related settings",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage(
      "Network detection",
    ),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "Network exception, please check your connection and try again",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Network speed"),
    "networkType": MessageLookupByLibrary.simpleMessage("Network type"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("Neutral"),
    "noData": MessageLookupByLibrary.simpleMessage("No data"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("No HotKey"),
    "noInfo": MessageLookupByLibrary.simpleMessage("No info"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Don\'t remind again",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("No network"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("No network APP"),
    "noRecords": MessageLookupByLibrary.simpleMessage("No records"),
    "noResolve": MessageLookupByLibrary.simpleMessage("No resolve IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "No resolve hostname",
    ),
    "noUsageData": MessageLookupByLibrary.simpleMessage(
      "No usage data for the current filters",
    ),
    "none": MessageLookupByLibrary.simpleMessage("none"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "The current proxy group cannot be selected.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "No profile, Please add a profile",
    ),
    "nullTip": m23,
    "numberTip": m24,
    "onDemand": MessageLookupByLibrary.simpleMessage("On Demand"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "Configure the program running state for specific scenarios",
    ),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Icon"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Only statistics proxy",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "When turned on, only statistics proxy traffic",
    ),
    "openProcessSettings": MessageLookupByLibrary.simpleMessage(
      "Process recognition settings",
    ),
    "optional": MessageLookupByLibrary.simpleMessage("Optional"),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "other": MessageLookupByLibrary.simpleMessage("Other"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Other contributors",
    ),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Outbound mode"),
    "override": MessageLookupByLibrary.simpleMessage("Override"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Override Dns"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Turning it on will override the DNS options in the profile",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage("Override mode"),
    "overrideScript": MessageLookupByLibrary.simpleMessage("Override script"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("Custom"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Custom mode, fully customize proxy groups and rules",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Palette"),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "paste": MessageLookupByLibrary.simpleMessage("Paste"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Please bind WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Please enter a script name",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Please enter the admin password",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Please upload a valid QR code",
    ),
    "policyActionDirect": MessageLookupByLibrary.simpleMessage(
      "Direct connection",
    ),
    "policyActionProxy": MessageLookupByLibrary.simpleMessage("Node group"),
    "policyActionReject": MessageLookupByLibrary.simpleMessage("Block"),
    "policyActiveIntegration": MessageLookupByLibrary.simpleMessage(
      "Merged profile to use",
    ),
    "policyAddBackup": MessageLookupByLibrary.simpleMessage("Add fallback"),
    "policyAddBudget": MessageLookupByLibrary.simpleMessage(
      "Add traffic limit",
    ),
    "policyAddIntegration": MessageLookupByLibrary.simpleMessage(
      "Create merged profile",
    ),
    "policyAddRule": MessageLookupByLibrary.simpleMessage("Add rule"),
    "policyAddSubscription": MessageLookupByLibrary.simpleMessage(
      "Add subscription",
    ),
    "policyAdmission": MessageLookupByLibrary.simpleMessage(
      "Expiry and remaining quota",
    ),
    "policyAdvancedJson": MessageLookupByLibrary.simpleMessage(
      "Advanced structured JSON",
    ),
    "policyAdvancedTab": MessageLookupByLibrary.simpleMessage("Advanced"),
    "policyAiGenerate": MessageLookupByLibrary.simpleMessage(
      "Generate a plan with AI",
    ),
    "policyAiGenerationRequest": m25,
    "policyAiOptimizationRequest": m26,
    "policyAiOptimizeRule": MessageLookupByLibrary.simpleMessage(
      "Optimize rules with AI",
    ),
    "policyAiOrigin": MessageLookupByLibrary.simpleMessage("AI generated"),
    "policyAnyMultiplier": MessageLookupByLibrary.simpleMessage(
      "Any multiplier",
    ),
    "policyAnyRegion": MessageLookupByLibrary.simpleMessage("Any region"),
    "policyApplication": MessageLookupByLibrary.simpleMessage("Application"),
    "policyAppliedStatus": MessageLookupByLibrary.simpleMessage("Applied"),
    "policyAppsFailed": MessageLookupByLibrary.simpleMessage(
      "Could not read applications. Refresh to retry.",
    ),
    "policyAppsHint": MessageLookupByLibrary.simpleMessage(
      "Includes network helper processes inside each application. Process identification depends on permissions and connection type.",
    ),
    "policyAppsLoading": MessageLookupByLibrary.simpleMessage(
      "Reading installed applications…",
    ),
    "policyAppsUnsupported": MessageLookupByLibrary.simpleMessage(
      "Application selection is unavailable on this platform.",
    ),
    "policyAscending": MessageLookupByLibrary.simpleMessage("Ascending"),
    "policyAssumeHealthy": MessageLookupByLibrary.simpleMessage(
      "Assume all candidates healthy",
    ),
    "policyAutoCheck": MessageLookupByLibrary.simpleMessage("Automatic checks"),
    "policyAutoRecover": MessageLookupByLibrary.simpleMessage(
      "Recover to a higher-priority node",
    ),
    "policyAvailableMembers": MessageLookupByLibrary.simpleMessage(
      "Available members",
    ),
    "policyBalanceHint": MessageLookupByLibrary.simpleMessage(
      "Priority mode follows the ranking above; load balancing distributes connections across all eligible nodes.",
    ),
    "policyBalanceMode": MessageLookupByLibrary.simpleMessage("Load balancing"),
    "policyBudgetGiB": MessageLookupByLibrary.simpleMessage(
      "Monthly traffic limit on this device (GiB)",
    ),
    "policyBudgetHint": MessageLookupByLibrary.simpleMessage(
      "Counts managed connections on this device and limits new connections at the cap; excludes other devices and may not close existing connections immediately",
    ),
    "policyBudgetLastSample": m27,
    "policyBudgetPeriod": m28,
    "policyBudgetReached": MessageLookupByLibrary.simpleMessage(
      "Device traffic cap reached; new connections from this subscription are restricted",
    ),
    "policyBudgetReachedHint": MessageLookupByLibrary.simpleMessage(
      "When a source reaches its budget, local rules try other available nodes. If none are available, matching continues with the next rule.",
    ),
    "policyBudgetTab": MessageLookupByLibrary.simpleMessage("Traffic limits"),
    "policyCandidateHint": MessageLookupByLibrary.simpleMessage(
      "Only these nodes are considered, in order",
    ),
    "policyCandidates": MessageLookupByLibrary.simpleMessage(
      "Exact candidate order",
    ),
    "policyCheckCapacityHint": m29,
    "policyCheckCoreStopped": MessageLookupByLibrary.simpleMessage(
      "Core is stopped, so nodes cannot be checked. Start the connection, then reopen this node group.",
    ),
    "policyCheckFrequencyHint": MessageLookupByLibrary.simpleMessage(
      "Intervals are scheduling targets; many nodes may queue",
    ),
    "policyCheckFrequencySection": MessageLookupByLibrary.simpleMessage(
      "Check frequency",
    ),
    "policyCheckLocalInactive": MessageLookupByLibrary.simpleMessage(
      "The local configuration is not loaded, so this node group cannot be checked. Enable and select the local configuration in Local policies, then reopen this group.",
    ),
    "policyCheckMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "Measures connectivity and request latency, not download speed",
    ),
    "policyCheckMethodSection": MessageLookupByLibrary.simpleMessage(
      "Check method",
    ),
    "policyCheckNow": MessageLookupByLibrary.simpleMessage("Check now"),
    "policyCheckPending": MessageLookupByLibrary.simpleMessage(
      "Awaiting check",
    ),
    "policyCheckPreset": MessageLookupByLibrary.simpleMessage(
      "Check endpoint preset",
    ),
    "policyCheckReadFailed": MessageLookupByLibrary.simpleMessage(
      "Check status could not be read; node availability is unknown. Retry, or reopen this group if it still fails.",
    ),
    "policyCheckReadTimeout": MessageLookupByLibrary.simpleMessage(
      "Reading check status timed out. Node availability is unconfirmed. Retry.",
    ),
    "policyCheckRetry": MessageLookupByLibrary.simpleMessage(
      "Retry reading status",
    ),
    "policyCheckSave": MessageLookupByLibrary.simpleMessage("Check and save"),
    "policyCheckStatusSection": MessageLookupByLibrary.simpleMessage(
      "Check status",
    ),
    "policyCheckUnsaved": MessageLookupByLibrary.simpleMessage(
      "This is an unsaved draft. Members match draft conditions and have not been checked. Check and save first, then check nodes.",
    ),
    "policyCheckVersionMismatch": MessageLookupByLibrary.simpleMessage(
      "The running version does not match this node group. Old results are hidden. Wait for configuration application to finish, then reopen the group.",
    ),
    "policyChecksInFlight": MessageLookupByLibrary.simpleMessage(
      "Checks in progress",
    ),
    "policyChecksWaiting": MessageLookupByLibrary.simpleMessage(
      "Queued checks",
    ),
    "policyChoiceSection": MessageLookupByLibrary.simpleMessage("Processing"),
    "policyCollectionPending": MessageLookupByLibrary.simpleMessage(
      "Not configured",
    ),
    "policyCombinedConditions": MessageLookupByLibrary.simpleMessage(
      "Combined conditions",
    ),
    "policyConsistentHashing": MessageLookupByLibrary.simpleMessage(
      "Consistent hashing",
    ),
    "policyContinueEditing": MessageLookupByLibrary.simpleMessage(
      "Continue editing",
    ),
    "policyContinueNextRule": MessageLookupByLibrary.simpleMessage(
      "Continue with the next rule",
    ),
    "policyCooldownSeconds": MessageLookupByLibrary.simpleMessage(
      "Switch cooldown (seconds)",
    ),
    "policyCoreStopped": MessageLookupByLibrary.simpleMessage(
      "Core stopped; policies are not running",
    ),
    "policyCurrentEffect": MessageLookupByLibrary.simpleMessage(
      "Current effect",
    ),
    "policyCustomCheck": MessageLookupByLibrary.simpleMessage("Custom"),
    "policyDeclaredAttribute": MessageLookupByLibrary.simpleMessage(
      "Declared by subscription",
    ),
    "policyDeleteLinked": MessageLookupByLibrary.simpleMessage(
      "Integration is referenced by rules. Update them first",
    ),
    "policyDescending": MessageLookupByLibrary.simpleMessage("Descending"),
    "policyDestinationRegion": MessageLookupByLibrary.simpleMessage(
      "Destination region",
    ),
    "policyDiscardChanges": MessageLookupByLibrary.simpleMessage(
      "Discard changes",
    ),
    "policyDomainKeyword": MessageLookupByLibrary.simpleMessage(
      "Domain keyword",
    ),
    "policyDomainScope": MessageLookupByLibrary.simpleMessage("Exact domain"),
    "policyDomainSuffix": MessageLookupByLibrary.simpleMessage("Domain suffix"),
    "policyDomestic": MessageLookupByLibrary.simpleMessage("Domestic (China)"),
    "policyDraftStatus": MessageLookupByLibrary.simpleMessage(
      "Pending approval",
    ),
    "policyDraftStatusHint": MessageLookupByLibrary.simpleMessage(
      "Draft changed; save to view check results",
    ),
    "policyEarlierFirst": MessageLookupByLibrary.simpleMessage("Earlier first"),
    "policyEditIntegration": MessageLookupByLibrary.simpleMessage(
      "Edit merged profile",
    ),
    "policyEditRule": MessageLookupByLibrary.simpleMessage("Edit rule"),
    "policyEligible": MessageLookupByLibrary.simpleMessage("Eligible now"),
    "policyEmptyBudgets": MessageLookupByLibrary.simpleMessage(
      "No traffic limits set on this device",
    ),
    "policyEmptyHistory": MessageLookupByLibrary.simpleMessage(
      "No change history yet",
    ),
    "policyEmptyIntegrations": MessageLookupByLibrary.simpleMessage(
      "No merged profile yet; ordinary rules can use existing profiles directly",
    ),
    "policyEmptyRules": MessageLookupByLibrary.simpleMessage(
      "No local rules yet",
    ),
    "policyEnableBudgets": MessageLookupByLibrary.simpleMessage(
      "Enable traffic limits on this device",
    ),
    "policyEnableIntegrations": MessageLookupByLibrary.simpleMessage(
      "Use merged profile",
    ),
    "policyEnableRules": MessageLookupByLibrary.simpleMessage(
      "Enable routing rules",
    ),
    "policyEndTime": MessageLookupByLibrary.simpleMessage("End time (HH:mm)"),
    "policyEveryday": MessageLookupByLibrary.simpleMessage("Every day"),
    "policyExcludeRegions": MessageLookupByLibrary.simpleMessage(
      "Exclude regions",
    ),
    "policyExcludeSources": MessageLookupByLibrary.simpleMessage(
      "Exclude providers",
    ),
    "policyExcluded": MessageLookupByLibrary.simpleMessage("Excluded now"),
    "policyExcludedNodes": MessageLookupByLibrary.simpleMessage(
      "Excluded nodes",
    ),
    "policyExistingApps": MessageLookupByLibrary.simpleMessage(
      "Previously selected applications",
    ),
    "policyExpectedStatus": MessageLookupByLibrary.simpleMessage(
      "Expected HTTP status",
    ),
    "policyExpiryMargin": MessageLookupByLibrary.simpleMessage(
      "Exclude before expiry (hours)",
    ),
    "policyExpiryUnknown": MessageLookupByLibrary.simpleMessage(
      "No expiry information provided",
    ),
    "policyFailures": MessageLookupByLibrary.simpleMessage(
      "Consecutive failures",
    ),
    "policyFallback": MessageLookupByLibrary.simpleMessage(
      "When no candidate qualifies",
    ),
    "policyFallbackDirect": MessageLookupByLibrary.simpleMessage(
      "Allow direct connection",
    ),
    "policyFallbackReject": MessageLookupByLibrary.simpleMessage(
      "Reject connections",
    ),
    "policyFixedNode": MessageLookupByLibrary.simpleMessage("Specific node"),
    "policyForeign": MessageLookupByLibrary.simpleMessage("Outside China"),
    "policyGlobalScope": MessageLookupByLibrary.simpleMessage("All traffic"),
    "policyGroupScope": MessageLookupByLibrary.simpleMessage(
      "Existing proxy group",
    ),
    "policyHideUnavailable": MessageLookupByLibrary.simpleMessage(
      "Automatically hide unavailable nodes",
    ),
    "policyHigherFirst": MessageLookupByLibrary.simpleMessage("Higher first"),
    "policyHistoryTab": MessageLookupByLibrary.simpleMessage("History"),
    "policyImprovementPercent": MessageLookupByLibrary.simpleMessage(
      "Latency improvement threshold (%)",
    ),
    "policyIncludeRegions": MessageLookupByLibrary.simpleMessage(
      "Include regions",
    ),
    "policyIncludeSources": MessageLookupByLibrary.simpleMessage(
      "Include providers",
    ),
    "policyIncludeSubdomains": MessageLookupByLibrary.simpleMessage(
      "Include subdomains",
    ),
    "policyInstalledApps": MessageLookupByLibrary.simpleMessage(
      "Installed applications",
    ),
    "policyIntegrationHint": MessageLookupByLibrary.simpleMessage(
      "Combine nodes from selected subscriptions into a separate profile while keeping the originals. Remaining traffic is shown only when the provider supplies it",
    ),
    "policyIntegrationTab": MessageLookupByLibrary.simpleMessage(
      "Merge subscriptions",
    ),
    "policyInvalidData": MessageLookupByLibrary.simpleMessage(
      "Invalid fields, order or references. Check and retry",
    ),
    "policyIpNetworks": MessageLookupByLibrary.simpleMessage(
      "IP address or network",
    ),
    "policyJsonHint": MessageLookupByLibrary.simpleMessage(
      "Only the current schema is accepted; invalid fields or references cannot be applied",
    ),
    "policyLatencyFirst": MessageLookupByLibrary.simpleMessage(
      "Lowest latency first",
    ),
    "policyLaterFirst": MessageLookupByLibrary.simpleMessage("Later first"),
    "policyLedgerUntrusted": MessageLookupByLibrary.simpleMessage(
      "Ledger untrusted; source restricted",
    ),
    "policyLegacySelections": MessageLookupByLibrary.simpleMessage(
      "This existing rule keeps all previous selections until you choose a replacement.",
    ),
    "policyLessFirst": MessageLookupByLibrary.simpleMessage("Less first"),
    "policyLoadNodes": MessageLookupByLibrary.simpleMessage(
      "Load available nodes",
    ),
    "policyLocalAdvancedHint": MessageLookupByLibrary.simpleMessage(
      "These settings are optional and can be skipped during initial setup.",
    ),
    "policyLocalChoose": MessageLookupByLibrary.simpleMessage(
      "Select on Profiles",
    ),
    "policyLocalCollection": MessageLookupByLibrary.simpleMessage(
      "Local configuration",
    ),
    "policyLocalDefaultReject": MessageLookupByLibrary.simpleMessage(
      "Connections are blocked when no rule produces an available result.",
    ),
    "policyLocalMigrationReview": MessageLookupByLibrary.simpleMessage(
      "Previous rules are preserved and paused. Review them before selecting the local configuration.",
    ),
    "policyLocalNoSubscriptions": MessageLookupByLibrary.simpleMessage(
      "No subscriptions yet. Add one to continue.",
    ),
    "policyLocalProfileHint": MessageLookupByLibrary.simpleMessage(
      "Combine subscription nodes and define routing rules",
    ),
    "policyLocalSelected": MessageLookupByLibrary.simpleMessage(
      "Local configuration selected",
    ),
    "policyLocalSourceLimit": MessageLookupByLibrary.simpleMessage(
      "Select up to 20 subscription sources",
    ),
    "policyLocalSourcesEmpty": MessageLookupByLibrary.simpleMessage(
      "Select subscription sources to use proxy nodes. Direct and block rules do not need sources.",
    ),
    "policyLocalSourcesHint": MessageLookupByLibrary.simpleMessage(
      "Select the subscriptions whose nodes you want to use, then set up node groups and routing rules. Only nodes are combined; subscription rules, groups, scripts and DNS are not inherited. Select up to 20 sources.",
    ),
    "policyLowerFirst": MessageLookupByLibrary.simpleMessage("Lower first"),
    "policyManualAttribute": MessageLookupByLibrary.simpleMessage(
      "Manually confirmed",
    ),
    "policyManualOrigin": MessageLookupByLibrary.simpleMessage(
      "Manually added",
    ),
    "policyMatchAll": MessageLookupByLibrary.simpleMessage(
      "All conditions (advanced)",
    ),
    "policyMatchAny": MessageLookupByLibrary.simpleMessage(
      "Any condition (advanced)",
    ),
    "policyMatchConditions": MessageLookupByLibrary.simpleMessage(
      "Traffic conditions",
    ),
    "policyMatchNot": MessageLookupByLibrary.simpleMessage(
      "Negated condition (advanced)",
    ),
    "policyMemberPreview": MessageLookupByLibrary.simpleMessage(
      "Member preview",
    ),
    "policyMembersAllSources": MessageLookupByLibrary.simpleMessage(
      "All providers",
    ),
    "policyMembersAllStates": MessageLookupByLibrary.simpleMessage(
      "All statuses",
    ),
    "policyMembersChecking": MessageLookupByLibrary.simpleMessage("Checking"),
    "policyMembersDraft": MessageLookupByLibrary.simpleMessage(
      "Save to refresh check results",
    ),
    "policyMembersExpired": MessageLookupByLibrary.simpleMessage(
      "Result expired",
    ),
    "policyMembersExpiry": MessageLookupByLibrary.simpleMessage("Expiry"),
    "policyMembersFailed": MessageLookupByLibrary.simpleMessage(
      "Connection failed",
    ),
    "policyMembersFilters": MessageLookupByLibrary.simpleMessage(
      "List filters",
    ),
    "policyMembersHealthy": MessageLookupByLibrary.simpleMessage("Available"),
    "policyMembersLastCheck": MessageLookupByLibrary.simpleMessage(
      "Last checked",
    ),
    "policyMembersNoResult": MessageLookupByLibrary.simpleMessage("No result"),
    "policyMembersQuota": MessageLookupByLibrary.simpleMessage(
      "Provider quota",
    ),
    "policyMembersRestricted": MessageLookupByLibrary.simpleMessage(
      "Restricted",
    ),
    "policyMembersSource": MessageLookupByLibrary.simpleMessage("Provider"),
    "policyMembersTitle": MessageLookupByLibrary.simpleMessage("Group nodes"),
    "policyMembersUnchecked": MessageLookupByLibrary.simpleMessage(
      "Not checked",
    ),
    "policyMetadataAge": MessageLookupByLibrary.simpleMessage(
      "Metadata maximum age (hours)",
    ),
    "policyMethod": MessageLookupByLibrary.simpleMessage("Request method"),
    "policyMissingNode": MessageLookupByLibrary.simpleMessage("Node missing"),
    "policyModule": MessageLookupByLibrary.simpleMessage(
      "Enable local rule features",
    ),
    "policyModuleOffHint": MessageLookupByLibrary.simpleMessage(
      "Turning this off stops local rules, subscription merging and traffic limits; saved settings are kept",
    ),
    "policyMoreFirst": MessageLookupByLibrary.simpleMessage("More first"),
    "policyMoreSettings": MessageLookupByLibrary.simpleMessage("More settings"),
    "policyMoveDown": MessageLookupByLibrary.simpleMessage("Move down"),
    "policyMoveUp": MessageLookupByLibrary.simpleMessage("Move up"),
    "policyMultiplierFirst": MessageLookupByLibrary.simpleMessage(
      "Lowest multiplier first",
    ),
    "policyMultiplierLimit": MessageLookupByLibrary.simpleMessage(
      "Multiplier limit",
    ),
    "policyNameAttribute": MessageLookupByLibrary.simpleMessage(
      "Detected from name",
    ),
    "policyNameExcludes": MessageLookupByLibrary.simpleMessage(
      "Node name excludes (one per line)",
    ),
    "policyNameFilter": MessageLookupByLibrary.simpleMessage(
      "Node name contains (optional)",
    ),
    "policyNameIncludes": MessageLookupByLibrary.simpleMessage(
      "Node name contains (one per line)",
    ),
    "policyNoMembers": MessageLookupByLibrary.simpleMessage(
      "No available members; continue with the next rule.",
    ),
    "policyNoNodeContinue": MessageLookupByLibrary.simpleMessage(
      "If no node is available, continue with the next rule.",
    ),
    "policyNoProfilesHint": MessageLookupByLibrary.simpleMessage(
      "No subscription sources yet; direct and block rules can still be added",
    ),
    "policyNodeSet": MessageLookupByLibrary.simpleMessage("Node group"),
    "policyNodeSetConditions": MessageLookupByLibrary.simpleMessage(
      "Group conditions",
    ),
    "policyNodeSetEditTitle": MessageLookupByLibrary.simpleMessage(
      "Edit node group",
    ),
    "policyNodeSetExclusions": MessageLookupByLibrary.simpleMessage(
      "Names and exclusions",
    ),
    "policyNodeSetHint": MessageLookupByLibrary.simpleMessage(
      "Filter by provider, region, name and multiplier, then select by priority or distribute connections with load balancing.",
    ),
    "policyNodeSetStrategy": MessageLookupByLibrary.simpleMessage(
      "Node selection",
    ),
    "policyNodeSetStrategyHint": MessageLookupByLibrary.simpleMessage(
      "Stable keeps the current node when possible; low latency uses probe delay; low multiplier uses the provider’s traffic charging multiplier",
    ),
    "policyNodeSetTarget": MessageLookupByLibrary.simpleMessage(
      "Profile that uses this group",
    ),
    "policyNodeSetTimed": MessageLookupByLibrary.simpleMessage(
      "Time windows set",
    ),
    "policyNodeSets": MessageLookupByLibrary.simpleMessage("Node groups"),
    "policyNodes": MessageLookupByLibrary.simpleMessage("Nodes"),
    "policyNotCollected": MessageLookupByLibrary.simpleMessage("Not collected"),
    "policyNotRunning": MessageLookupByLibrary.simpleMessage("Not running"),
    "policyOperationFailed": MessageLookupByLibrary.simpleMessage(
      "Operation incomplete. Check status or retry later",
    ),
    "policyOverrideMinutes": MessageLookupByLibrary.simpleMessage(
      "Valid minutes",
    ),
    "policyPageSampleAt": MessageLookupByLibrary.simpleMessage(
      "Status sampled at",
    ),
    "policyPendingMembers": MessageLookupByLibrary.simpleMessage(
      "Pending checks",
    ),
    "policyPreferenceExpiry": MessageLookupByLibrary.simpleMessage(
      "Subscription expiry",
    ),
    "policyPreferenceLatency": MessageLookupByLibrary.simpleMessage("Latency"),
    "policyPreferenceMultiplier": MessageLookupByLibrary.simpleMessage(
      "Billing multiplier",
    ),
    "policyPreferenceRemaining": MessageLookupByLibrary.simpleMessage(
      "Remaining allowance",
    ),
    "policyPreferenceSource": MessageLookupByLibrary.simpleMessage(
      "Provider order",
    ),
    "policyPreferences": MessageLookupByLibrary.simpleMessage(
      "Selection priorities",
    ),
    "policyPreferencesHint": MessageLookupByLibrary.simpleMessage(
      "Drag to reorder. Earlier criteria take precedence; unavailable nodes are excluded.",
    ),
    "policyPreferred": MessageLookupByLibrary.simpleMessage("Preferred"),
    "policyPreparingStatus": MessageLookupByLibrary.simpleMessage("Processing"),
    "policyPreviewHint": MessageLookupByLibrary.simpleMessage(
      "Node selection preview; no real request verification",
    ),
    "policyPriority": MessageLookupByLibrary.simpleMessage(
      "Priority (smaller first)",
    ),
    "policyPriorityMode": MessageLookupByLibrary.simpleMessage(
      "Priority selection",
    ),
    "policyProbe": MessageLookupByLibrary.simpleMessage("Health probes"),
    "policyProbeInterval": MessageLookupByLibrary.simpleMessage(
      "Probe interval (seconds)",
    ),
    "policyProbeTimeout": MessageLookupByLibrary.simpleMessage(
      "Probe timeout (seconds)",
    ),
    "policyProbeUrl": MessageLookupByLibrary.simpleMessage("Probe URL"),
    "policyProcessHint": MessageLookupByLibrary.simpleMessage(
      "Process detection depends on system permissions and connection mode",
    ),
    "policyProcessName": MessageLookupByLibrary.simpleMessage("Process name"),
    "policyProcessPath": MessageLookupByLibrary.simpleMessage("Process path"),
    "policyProcessing": MessageLookupByLibrary.simpleMessage("Processing"),
    "policyQuotaExpired": MessageLookupByLibrary.simpleMessage("Expired"),
    "policyQuotaExpiringLater": MessageLookupByLibrary.simpleMessage(
      "Expires later",
    ),
    "policyQuotaExpiringSoon": MessageLookupByLibrary.simpleMessage(
      "Expires within 30 days",
    ),
    "policyQuotaNoSources": MessageLookupByLibrary.simpleMessage(
      "No subscriptions selected",
    ),
    "policyQuotaOverage": MessageLookupByLibrary.simpleMessage("Over quota"),
    "policyQuotaOverview": MessageLookupByLibrary.simpleMessage(
      "Subscription overview",
    ),
    "policyQuotaPartiallyUnknown": MessageLookupByLibrary.simpleMessage(
      "Some quotas are unknown",
    ),
    "policyQuotaRemaining": MessageLookupByLibrary.simpleMessage("Remaining"),
    "policyQuotaTotal": MessageLookupByLibrary.simpleMessage("Total quota"),
    "policyQuotaUnknown": MessageLookupByLibrary.simpleMessage("Quota unknown"),
    "policyQuotaUnknownExpiry": MessageLookupByLibrary.simpleMessage(
      "Expiry unknown",
    ),
    "policyQuotaUnlimited": MessageLookupByLibrary.simpleMessage("No expiry"),
    "policyQuotaUsed": MessageLookupByLibrary.simpleMessage("Used"),
    "policyRecovery": MessageLookupByLibrary.simpleMessage(
      "Recovery and cooldown",
    ),
    "policyRecoveryCheck": MessageLookupByLibrary.simpleMessage(
      "Check and recover",
    ),
    "policyRecoveryKeep": MessageLookupByLibrary.simpleMessage(
      "Keep the checked current settings",
    ),
    "policyRecoverySeconds": MessageLookupByLibrary.simpleMessage(
      "Recovery observation (seconds)",
    ),
    "policyRecoveryStatus": MessageLookupByLibrary.simpleMessage(
      "Recovery required",
    ),
    "policyRegionAU": MessageLookupByLibrary.simpleMessage("Australia"),
    "policyRegionCA": MessageLookupByLibrary.simpleMessage("Canada"),
    "policyRegionCN": MessageLookupByLibrary.simpleMessage("China"),
    "policyRegionDE": MessageLookupByLibrary.simpleMessage("Germany"),
    "policyRegionFR": MessageLookupByLibrary.simpleMessage("France"),
    "policyRegionGB": MessageLookupByLibrary.simpleMessage("United Kingdom"),
    "policyRegionHK": MessageLookupByLibrary.simpleMessage("Hong Kong"),
    "policyRegionID": MessageLookupByLibrary.simpleMessage("Indonesia"),
    "policyRegionIN": MessageLookupByLibrary.simpleMessage("India"),
    "policyRegionJP": MessageLookupByLibrary.simpleMessage("Japan"),
    "policyRegionKR": MessageLookupByLibrary.simpleMessage("South Korea"),
    "policyRegionMO": MessageLookupByLibrary.simpleMessage("Macao"),
    "policyRegionMY": MessageLookupByLibrary.simpleMessage("Malaysia"),
    "policyRegionNL": MessageLookupByLibrary.simpleMessage("Netherlands"),
    "policyRegionPH": MessageLookupByLibrary.simpleMessage("Philippines"),
    "policyRegionRU": MessageLookupByLibrary.simpleMessage("Russia"),
    "policyRegionSG": MessageLookupByLibrary.simpleMessage("Singapore"),
    "policyRegionTH": MessageLookupByLibrary.simpleMessage("Thailand"),
    "policyRegionTR": MessageLookupByLibrary.simpleMessage("Turkey"),
    "policyRegionTW": MessageLookupByLibrary.simpleMessage("Taiwan"),
    "policyRegionUS": MessageLookupByLibrary.simpleMessage("United States"),
    "policyRegionVN": MessageLookupByLibrary.simpleMessage("Vietnam"),
    "policyRegions": MessageLookupByLibrary.simpleMessage("Regions"),
    "policyRejectedStatus": MessageLookupByLibrary.simpleMessage("Rejected"),
    "policyRemainingGiB": MessageLookupByLibrary.simpleMessage(
      "Minimum remaining (GiB)",
    ),
    "policyRemainingTraffic": MessageLookupByLibrary.simpleMessage(
      "All traffic",
    ),
    "policyRemoveCandidate": MessageLookupByLibrary.simpleMessage(
      "Remove candidate",
    ),
    "policyRemoveOverride": MessageLookupByLibrary.simpleMessage(
      "Remove temporary override",
    ),
    "policyResetDay": MessageLookupByLibrary.simpleMessage(
      "Monthly reset day (1–28)",
    ),
    "policyRestoredStatus": MessageLookupByLibrary.simpleMessage("Restored"),
    "policyRestrictedMembers": MessageLookupByLibrary.simpleMessage(
      "Restricted members",
    ),
    "policyRetrySeconds": MessageLookupByLibrary.simpleMessage(
      "Retry unavailable nodes (seconds)",
    ),
    "policyRoundRobin": MessageLookupByLibrary.simpleMessage("Round robin"),
    "policyRuleOrderHint": MessageLookupByLibrary.simpleMessage(
      "Match from top to bottom; if no node is available, continue with the next rule.",
    ),
    "policyRuleType": MessageLookupByLibrary.simpleMessage("Rule type"),
    "policyRulesHint": MessageLookupByLibrary.simpleMessage(
      "Set ordered traffic rules, active times and actions for the local configuration",
    ),
    "policyRulesTab": MessageLookupByLibrary.simpleMessage("Rules"),
    "policyRuntimeState": MessageLookupByLibrary.simpleMessage(
      "Runtime status",
    ),
    "policySaved": MessageLookupByLibrary.simpleMessage("Saved"),
    "policySavedInactive": MessageLookupByLibrary.simpleMessage(
      "Saved; not currently running",
    ),
    "policySchedule": MessageLookupByLibrary.simpleMessage("Schedule"),
    "policyScheduleAllDay": MessageLookupByLibrary.simpleMessage("All day"),
    "policyScheduleEnabled": MessageLookupByLibrary.simpleMessage(
      "Restrict active hours",
    ),
    "policyScheduleHint": MessageLookupByLibrary.simpleMessage(
      "Uses the selected time zone. An earlier end crosses midnight; weekdays refer to the starting day.",
    ),
    "policyScheduleSkip": MessageLookupByLibrary.simpleMessage(
      "Outside the schedule, skip to subsequent rules",
    ),
    "policyScheduleTimezone": MessageLookupByLibrary.simpleMessage("Time zone"),
    "policyScope": MessageLookupByLibrary.simpleMessage("Scope"),
    "policyScopeValues": MessageLookupByLibrary.simpleMessage(
      "One domain, group or process per line",
    ),
    "policySearchNodes": MessageLookupByLibrary.simpleMessage(
      "Search nodes or sources",
    ),
    "policySelectCollection": MessageLookupByLibrary.simpleMessage(
      "Select and use",
    ),
    "policySelectValues": MessageLookupByLibrary.simpleMessage("Select…"),
    "policySelectedNode": MessageLookupByLibrary.simpleMessage("Selected node"),
    "policySelectedOffline": MessageLookupByLibrary.simpleMessage(
      "Selected; used when connected",
    ),
    "policySelectionMode": MessageLookupByLibrary.simpleMessage(
      "Distribution mode",
    ),
    "policySelectionRecoverySection": MessageLookupByLibrary.simpleMessage(
      "Selection and recovery",
    ),
    "policySharedSetImpact": MessageLookupByLibrary.simpleMessage(
      "Changes to a shared set affect rules referencing it",
    ),
    "policyShowUnavailable": MessageLookupByLibrary.simpleMessage(
      "Show all members",
    ),
    "policySimulation": MessageLookupByLibrary.simpleMessage(
      "Scenario simulation",
    ),
    "policySimulationCoreRequired": MessageLookupByLibrary.simpleMessage(
      "Simulation requires a running proxy core",
    ),
    "policySimulationHint": MessageLookupByLibrary.simpleMessage(
      "Independent cold-start scenario. Health flags and usage are input assumptions; live selection, probe age, latency, cooldown and recovery state are not restored. Results do not predict current runtime behavior. No real probes or configuration writes.",
    ),
    "policySimulationSteps": MessageLookupByLibrary.simpleMessage(
      "Scenario steps (advanced JSON)",
    ),
    "policySimulationStepsHint": MessageLookupByLibrary.simpleMessage(
      "Up to 32 steps: at is epoch milliseconds; probes contain nodeId and success; sources change metadata; usage contains bytes used per source. Simulation performs no probes or configuration writes.",
    ),
    "policySimulationTimeline": MessageLookupByLibrary.simpleMessage(
      "Candidate transition timeline",
    ),
    "policySourceChangeAdded": MessageLookupByLibrary.simpleMessage(
      "Added subscriptions",
    ),
    "policySourceChangeIncomplete": MessageLookupByLibrary.simpleMessage(
      "Some data is missing from the totals",
    ),
    "policySourceChangeNodeTotal": MessageLookupByLibrary.simpleMessage(
      "Total nodes",
    ),
    "policySourceChangeNodesUnavailable": MessageLookupByLibrary.simpleMessage(
      "Nodes not parsed",
    ),
    "policySourceChangePartiallyUnknown": MessageLookupByLibrary.simpleMessage(
      "Partially unknown",
    ),
    "policySourceChangeRemaining": MessageLookupByLibrary.simpleMessage(
      "Remaining quota",
    ),
    "policySourceChangeRemoved": MessageLookupByLibrary.simpleMessage(
      "Removed subscriptions",
    ),
    "policySourceChangeTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm subscription sources",
    ),
    "policySourceChangeUnresolvedNodes": MessageLookupByLibrary.simpleMessage(
      "Sources with unresolved nodes",
    ),
    "policySourceExpiry": MessageLookupByLibrary.simpleMessage(
      "Subscription expiry",
    ),
    "policySourceMissing": MessageLookupByLibrary.simpleMessage(
      "Source or node missing; select again",
    ),
    "policySourceOrderHint": MessageLookupByLibrary.simpleMessage(
      "Drag providers into the order used by the provider preference.",
    ),
    "policySourceQuota": MessageLookupByLibrary.simpleMessage(
      "Provider-reported remaining traffic",
    ),
    "policySourceQuotaUnknown": MessageLookupByLibrary.simpleMessage(
      "Traffic information not supplied",
    ),
    "policySources": MessageLookupByLibrary.simpleMessage(
      "Subscription sources",
    ),
    "policySourcesCollection": MessageLookupByLibrary.simpleMessage(
      "Node sources",
    ),
    "policySpecificRegions": MessageLookupByLibrary.simpleMessage(
      "Selected regions",
    ),
    "policyStableFirst": MessageLookupByLibrary.simpleMessage(
      "Stability first",
    ),
    "policyStartTime": MessageLookupByLibrary.simpleMessage(
      "Start time (HH:mm)",
    ),
    "policyStickySessions": MessageLookupByLibrary.simpleMessage(
      "Sticky sessions",
    ),
    "policySubscriptionExhausted": MessageLookupByLibrary.simpleMessage(
      "Subscription traffic exhausted",
    ),
    "policySubscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "Subscription expired",
    ),
    "policySubscriptionSources": MessageLookupByLibrary.simpleMessage(
      "Subscription sources",
    ),
    "policySuccesses": MessageLookupByLibrary.simpleMessage(
      "Consecutive successes",
    ),
    "policySupersededStatus": MessageLookupByLibrary.simpleMessage(
      "Superseded",
    ),
    "policyTarget": MessageLookupByLibrary.simpleMessage(
      "Profile for these rules",
    ),
    "policyTargetHint": MessageLookupByLibrary.simpleMessage(
      "Applies while this profile is active; changing this field does not switch the running profile",
    ),
    "policyTemporaryOverride": MessageLookupByLibrary.simpleMessage(
      "Temporary override",
    ),
    "policyTerminate": MessageLookupByLibrary.simpleMessage(
      "Terminate affected connections on exclusion",
    ),
    "policyTerminateHint": MessageLookupByLibrary.simpleMessage(
      "This interrupts existing connections and requires approval",
    ),
    "policyTrafficSection": MessageLookupByLibrary.simpleMessage(
      "Which traffic",
    ),
    "policyTrafficUnknown": MessageLookupByLibrary.simpleMessage(
      "No traffic information provided",
    ),
    "policyUndo": MessageLookupByLibrary.simpleMessage("Undo change"),
    "policyUnknownAttribute": MessageLookupByLibrary.simpleMessage("Unknown"),
    "policyUnknownHealth": MessageLookupByLibrary.simpleMessage(
      "Health unknown",
    ),
    "policyUnknownMetadata": MessageLookupByLibrary.simpleMessage(
      "Exclude sources with unknown metadata",
    ),
    "policyUnknownMultiplierAllowed": MessageLookupByLibrary.simpleMessage(
      "Allow unknown without assuming a multiplier",
    ),
    "policyUnknownNameOrigin": MessageLookupByLibrary.simpleMessage(
      "Unknown origin",
    ),
    "policyUnknownOne": MessageLookupByLibrary.simpleMessage(
      "Treat unknown multiplier as 1×",
    ),
    "policyUnknownOneHint": MessageLookupByLibrary.simpleMessage(
      "For filtering and sorting only; still marked unknown",
    ),
    "policyUnsavedTitle": MessageLookupByLibrary.simpleMessage(
      "Unsaved changes",
    ),
    "policyUnsupportedSourceOption": m30,
    "policyUpdateProxyUnavailable": MessageLookupByLibrary.simpleMessage(
      "The proxy is unavailable. Start it or explicitly choose direct subscription updates.",
    ),
    "policyUpdateRoute": MessageLookupByLibrary.simpleMessage(
      "Subscription update route",
    ),
    "policyUpdateRouteDirect": MessageLookupByLibrary.simpleMessage(
      "Direct connection",
    ),
    "policyUpdateRouteHint": MessageLookupByLibrary.simpleMessage(
      "Subscription updates for the local configuration. Unavailable proxy stops updates; direct access requires approval.",
    ),
    "policyUpdateRouteProxy": MessageLookupByLibrary.simpleMessage(
      "Use current proxy",
    ),
    "policyUsage": MessageLookupByLibrary.simpleMessage("Local usage"),
    "policyUsageUnknown": MessageLookupByLibrary.simpleMessage(
      "Usage awaiting verification",
    ),
    "policyValiditySeconds": MessageLookupByLibrary.simpleMessage(
      "Measurement validity (seconds)",
    ),
    "policyViewChanges": MessageLookupByLibrary.simpleMessage("View changes"),
    "policyWebsite": MessageLookupByLibrary.simpleMessage("Website"),
    "policyWeekdayFri": MessageLookupByLibrary.simpleMessage("Fri"),
    "policyWeekdayMon": MessageLookupByLibrary.simpleMessage("Mon"),
    "policyWeekdaySat": MessageLookupByLibrary.simpleMessage("Sat"),
    "policyWeekdaySun": MessageLookupByLibrary.simpleMessage("Sun"),
    "policyWeekdayThu": MessageLookupByLibrary.simpleMessage("Thu"),
    "policyWeekdayTue": MessageLookupByLibrary.simpleMessage("Tue"),
    "policyWeekdayWed": MessageLookupByLibrary.simpleMessage("Wed"),
    "policyWeekdays": MessageLookupByLibrary.simpleMessage(
      "Weekdays (1=Monday, 7=Sunday)",
    ),
    "policyWorkbenchTitle": MessageLookupByLibrary.simpleMessage("Local rules"),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a different port",
    ),
    "portTip": m31,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Prioritize the use of DOH\'s http/3",
    ),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prerequisites"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Please press the keyboard.",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Preview"),
    "process": MessageLookupByLibrary.simpleMessage("Process"),
    "processRecognitionOff": MessageLookupByLibrary.simpleMessage(
      "Process recognition is off. App usage will be grouped as unknown where FlClash cannot identify it.",
    ),
    "processRecognitionUnavailable": MessageLookupByLibrary.simpleMessage(
      "Process recognition is enabled, but no app was identified in this time range. Previously recorded unknown traffic cannot be backfilled.",
    ),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Please input a valid interval time format",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Please enter the auto update interval time",
        ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "The profile has been modified. Do you want to disable auto update?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please input the profile name",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please input a valid profile URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please input the profile URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Profiles"),
    "profilesRuleCount": m32,
    "profilesSort": MessageLookupByLibrary.simpleMessage("Profiles sort"),
    "profilesSourceCount": m33,
    "profilesUpdateAll": MessageLookupByLibrary.simpleMessage("Update all"),
    "profilesUpdateSubscription": MessageLookupByLibrary.simpleMessage(
      "Update subscription",
    ),
    "project": MessageLookupByLibrary.simpleMessage("Project"),
    "providers": MessageLookupByLibrary.simpleMessage("Providers"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesEmpty": MessageLookupByLibrary.simpleMessage("Proxies is empty"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Proxy chains"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Detected selected proxies are abnormal",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("Proxy filter"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Proxy group"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Detected current proxy group is abnormal",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy group is empty",
    ),
    "proxyGroupNameDuplicate": MessageLookupByLibrary.simpleMessage(
      "Proxy group name is duplicate",
    ),
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy group name cannot be empty",
    ),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("Proxy nameserver"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Domain for resolving proxy nodes",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("ProxyPort"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Detected selected proxy providers are abnormal",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Proxy providers"),
    "proxyProvidersEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy providers is empty",
    ),
    "proxyProvidersNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy providers cannot be empty",
    ),
    "proxyTraffic": MessageLookupByLibrary.simpleMessage("Proxy"),
    "proxyType": MessageLookupByLibrary.simpleMessage("Proxy type"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Prune cache"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Pure black mode"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR code"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Scan QR code to obtain profile",
    ),
    "quickFill": MessageLookupByLibrary.simpleMessage("Quick fill"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("Rainbow"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir Port"),
    "redo": MessageLookupByLibrary.simpleMessage("redo"),
    "remote": MessageLookupByLibrary.simpleMessage("Remote"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Back up configuration, AI connections and encrypted keys, local rules and history to WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Remote destination",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Remove"),
    "rename": MessageLookupByLibrary.simpleMessage("Rename"),
    "request": MessageLookupByLibrary.simpleMessage("Request"),
    "requests": MessageLookupByLibrary.simpleMessage("Requests"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "View recently request records",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "resetFilters": MessageLookupByLibrary.simpleMessage("Reset filters"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "The current page has changes. Are you sure you want to reset?",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage("Make sure to reset"),
    "resources": MessageLookupByLibrary.simpleMessage("Resources"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "External resource related info",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respect rules"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS connection following rules, need to configure proxy-server-nameserver",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Restart"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to restart the core?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restore"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Restore configuration, AI and local rules",
    ),
    "restoreException": MessageLookupByLibrary.simpleMessage(
      "Recovery exception",
    ),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "Restore a backup file; full restore includes AI and local rules",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "Restore a WebDAV backup; full restore includes AI and local rules",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Restore configuration files only",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("Restore strategy"),
    "restoreStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "restoreStrategy_override": MessageLookupByLibrary.simpleMessage(
      "Override",
    ),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("Restore success"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Route address"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Config listen route address",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Route mode"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Bypass private route address",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("Use config"),
    "ru": MessageLookupByLibrary.simpleMessage("Russian"),
    "rule": MessageLookupByLibrary.simpleMessage("Rule"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Logical rule AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Match full domain",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Match domain keyword",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Wildcard match, only supports * and ? wildcards",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match domain suffix",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Match DSCP mark (tproxy udp inbound only)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match request target port range",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Match IP\'s country code",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Match domains within Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match inbound name",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match inbound port",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Match inbound type",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Match inbound username, supports multiple usernames separated by /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Match IP\'s ASN",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Match IP address range, IP-CIDR6 is just an alias",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Match IP address range",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match IP suffix range",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Match all requests, no conditions needed",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Match TCP or UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Logical rule NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("Logical rule OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match using process name, matches package name on Android",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match using process name regex, matches package name on Android",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Match using full process path",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match using process path regex",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Reference rule set, requires rule-providers configuration",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Match source IP\'s country code",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Match source IP\'s ASN",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Match source IP address range",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match source IP suffix range",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match request source port range",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Match to sub-rule, pay attention to the use of parentheses",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Match Linux USER ID",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("Rule is empty"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Rule name"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Rule providers"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Rule set"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Rule target"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "Do you want to save the changes?",
    ),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Script mode, use external extension scripts, provide one-click override configuration capability",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "seconds": MessageLookupByLibrary.simpleMessage("Seconds"),
    "secondsCount": m34,
    "selectAll": MessageLookupByLibrary.simpleMessage("Select all"),
    "selectProxies": MessageLookupByLibrary.simpleMessage("Select proxies"),
    "selectProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Select proxy providers",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Please select rule set",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Please select split strategy",
    ),
    "selectSubRule": MessageLookupByLibrary.simpleMessage(
      "Please select sub rule",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Selected"),
    "selectedCountTitle": m35,
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "show": MessageLookupByLibrary.simpleMessage("Show"),
    "shrink": MessageLookupByLibrary.simpleMessage("Shrink"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("SilentLaunch"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Start in the background",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Size"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks Port"),
    "sort": MessageLookupByLibrary.simpleMessage("Sort"),
    "sortByConnections": MessageLookupByLibrary.simpleMessage("Connections"),
    "sortByDownload": MessageLookupByLibrary.simpleMessage("Download"),
    "sortByTotal": MessageLookupByLibrary.simpleMessage("Total"),
    "sortByUpload": MessageLookupByLibrary.simpleMessage("Upload"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Source IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Special proxy"),
    "specialRules": MessageLookupByLibrary.simpleMessage("special rules"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("Speed statistics"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("Split strategy"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Split strategy cannot be empty",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs is empty"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Stack mode"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Standard mode, override basic configuration, provide simple rule addition capability",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Start"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Starting VPN..."),
    "status": MessageLookupByLibrary.simpleMessage("Status"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "System DNS will be used when turned off",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Stopping VPN..."),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "subRule": MessageLookupByLibrary.simpleMessage("Sub rule"),
    "subRuleEmpty": MessageLookupByLibrary.simpleMessage("Sub rule is empty"),
    "subRuleNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Sub rule cannot be empty",
    ),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "suspended": MessageLookupByLibrary.simpleMessage("Suspended..."),
    "sync": MessageLookupByLibrary.simpleMessage("Sync"),
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "systemApp": MessageLookupByLibrary.simpleMessage("System APP"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Attach HTTP proxy to VpnService",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Tab"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Tab animation"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Effective only in mobile view",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("Tap to authorize"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP concurrent"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Enabling it will allow TCP concurrency",
    ),
    "testInterval": MessageLookupByLibrary.simpleMessage("Test interval"),
    "testUrl": MessageLookupByLibrary.simpleMessage("Test url"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("Test when used"),
    "textScale": MessageLookupByLibrary.simpleMessage("Text Scaling"),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Theme color"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "Set dark mode,adjust the color",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("Theme mode"),
    "tight": MessageLookupByLibrary.simpleMessage("Tight"),
    "time": MessageLookupByLibrary.simpleMessage("Time"),
    "timeTrend": MessageLookupByLibrary.simpleMessage("Time trend"),
    "timeout": MessageLookupByLibrary.simpleMessage("Timeout"),
    "tip": MessageLookupByLibrary.simpleMessage("tip"),
    "todayProxyUsage": MessageLookupByLibrary.simpleMessage(
      "Today\'s proxy usage",
    ),
    "toggle": MessageLookupByLibrary.simpleMessage("Toggle"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("TonalSpot"),
    "tools": MessageLookupByLibrary.simpleMessage("Tools"),
    "topApplications": MessageLookupByLibrary.simpleMessage("Top apps"),
    "topDomains": MessageLookupByLibrary.simpleMessage("Top domains"),
    "topNodes": MessageLookupByLibrary.simpleMessage("Top nodes"),
    "topProfiles": MessageLookupByLibrary.simpleMessage("Top config profiles"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy Port"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Traffic usage"),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "only effective in administrator mode",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Turn Off"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Turn On"),
    "undo": MessageLookupByLibrary.simpleMessage("undo"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Unified delay"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Remove extra delays such as handshaking",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "unknownApplication": MessageLookupByLibrary.simpleMessage("Unknown app"),
    "unknownDomain": MessageLookupByLibrary.simpleMessage(
      "Unknown domain or IP",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Unknown network error",
    ),
    "unknownNode": MessageLookupByLibrary.simpleMessage("Unknown node"),
    "unknownProfile": MessageLookupByLibrary.simpleMessage(
      "Unknown config profile",
    ),
    "unnamed": MessageLookupByLibrary.simpleMessage("Unnamed"),
    "update": MessageLookupByLibrary.simpleMessage("Update"),
    "upload": MessageLookupByLibrary.simpleMessage("Upload"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "Obtain profile through URL",
    ),
    "urlTip": m36,
    "usage": MessageLookupByLibrary.simpleMessage("Usage"),
    "usageApplications": MessageLookupByLibrary.simpleMessage("Apps"),
    "usageConnections": MessageLookupByLibrary.simpleMessage("Connections"),
    "usageDegradedIssue": MessageLookupByLibrary.simpleMessage(
      "Usage detail was compressed because the pending queue reached its safety limit. Totals are retained, but some app, domain, node, subscription, or minute details are unavailable.",
    ),
    "usageDesc": MessageLookupByLibrary.simpleMessage(
      "Local traffic usage by time, node, app, domain, and profile",
    ),
    "usageDomains": MessageLookupByLibrary.simpleMessage("Domains"),
    "usageNodes": MessageLookupByLibrary.simpleMessage("Nodes"),
    "usageNotEnabled": MessageLookupByLibrary.simpleMessage(
      "Usage recording is off",
    ),
    "usageNotEnabledDesc": MessageLookupByLibrary.simpleMessage(
      "Turn it on manually in Application settings to start local statistics. Historical traffic cannot be recovered.",
    ),
    "usageOverview": MessageLookupByLibrary.simpleMessage("Overview"),
    "usagePersistenceIssue": MessageLookupByLibrary.simpleMessage(
      "Usage data could not be saved. Recording will retry automatically; do not turn it off or quit until this warning clears.",
    ),
    "usagePrivacyDesc": MessageLookupByLibrary.simpleMessage(
      "FlClash will store traffic amounts, process paths, domains, target IPs, nodes, and profile snapshots locally on this Mac. Minute-level details are retained for 90 days, are not included in configuration or WebDAV backups, and cannot be backfilled. The figures are local measurements, not billing data.",
    ),
    "usagePrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Enable local usage recording?",
    ),
    "usageProfiles": MessageLookupByLibrary.simpleMessage("Config profiles"),
    "usageProfilesDesc": MessageLookupByLibrary.simpleMessage(
      "Grouped by the FlClash configuration profile active when each connection began. This is not provider quota or billing usage.",
    ),
    "usageRecording": MessageLookupByLibrary.simpleMessage("Usage recording"),
    "usageRecordingDesc": MessageLookupByLibrary.simpleMessage(
      "Store minute-level traffic, app, and domain statistics on this Mac for 90 days",
    ),
    "usageToday": MessageLookupByLibrary.simpleMessage("Today"),
    "usageTotal": MessageLookupByLibrary.simpleMessage("Total"),
    "useHosts": MessageLookupByLibrary.simpleMessage("Use hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("Use system hosts"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "value": MessageLookupByLibrary.simpleMessage("Value"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("Vibrant"),
    "view": MessageLookupByLibrary.simpleMessage("View"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN configuration change detected",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Auto routes all system traffic through VpnService",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Changes take effect after restarting the VPN",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "WebDAV configuration",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Whitelist mode"),
    "yearsAgo": m37,
    "zh_CN": MessageLookupByLibrary.simpleMessage("Simplified Chinese"),
  };
}
