// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru locale. All the
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
  String get localeName => 'ru';

  static String m0(count) => "Получено моделей: ${count}";

  static String m1(count) =>
      "${Intl.plural(count, one: '${count} день назад', few: '${count} дня назад', many: '${count} дней назад', other: '${count} дня назад')}";

  static String m2(label) =>
      "Вы уверены, что хотите удалить выбранные ${label}?";

  static String m3(label) => "Вы уверены, что хотите удалить текущий ${label}?";

  static String m4(label) => "Детали {}";

  static String m5(label) => "${label} не может быть пустым";

  static String m6(count) => "${count} записей";

  static String m7(label) => "Текущий ${label} уже существует";

  static String m8(name) => "Для ${name} уже установлена последняя версия";

  static String m9(name) => "${name} обновлено";

  static String m10(name) => "Обновление ${name}...";

  static String m11(count) =>
      "${Intl.plural(count, one: '${count} час назад', few: '${count} часа назад', many: '${count} часов назад', other: '${count} часа назад')}";

  static String m12(count) => "${count} часов";

  static String m13(target) => "${target} является недопустимой политикой";

  static String m14(proxyName) => "${proxyName} является недопустимым прокси";

  static String m15(providerName) =>
      "${providerName} является недопустимым провайдером прокси";

  static String m16(subRule) => "${subRule} является недопустимым подправилом";

  static String m17(appName) =>
      "1. Open System Settings > Privacy & Security\n2. Choose Location Services\n3. Find and check ${appName} in the right list\n\nAfter completing the setup, return to the app and use it normally. Thank you for your cooperation.";

  static String m18(count) =>
      "${Intl.plural(count, one: '${count} минута назад', few: '${count} минуты назад', many: '${count} минут назад', other: '${count} минуты назад')}";

  static String m19(count) =>
      "${Intl.plural(count, one: '${count} месяц назад', few: '${count} месяца назад', many: '${count} месяцев назад', other: '${count} месяца назад')}";

  static String m20(label) => "${label} пока отсутствуют";

  static String m21(label) => "${label} должно быть числом";

  static String m22(target) =>
      "Прочитайте существующие правила, узлы и источники подписок для цели ${target}, затем создайте проверяемое предложение новых правил на их основе. Сохраните порядок, не переставляйте существующие правила и не добавляйте второе правило для остального трафика. Создайте черновик и дождитесь моего подтверждения перед применением.";

  static String m23(sampleAt) =>
      "Последнее действительное показание: ${sampleAt}";

  static String m24(startAt) => "Начало периода: ${startAt}";

  static String m25(seconds) =>
      "По оценке текущей пропускной способности рекомендуется срок действия не менее ${seconds} секунд. Это оценка очереди; фактическое завершение может занять больше времени.";

  static String m26(option) =>
      "Источник использует неподдерживаемый параметр: ${option}. Локальные ограничения не применены; сначала удалите этот параметр.";

  static String m27(label) => "${label} должен быть числом от 1024 до 49151";

  static String m28(count) => "${count} секунд";

  static String m29(count) => "Выбрано ${count} элементов";

  static String m30(label) => "${label} должен быть URL";

  static String m31(count) =>
      "${Intl.plural(count, one: '${count} год назад', few: '${count} года назад', many: '${count} лет назад', other: '${count} года назад')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("О программе"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Контроль доступа"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить только выбранным приложениям доступ к VPN",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка доступа приложений к прокси",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Выбранные приложения будут исключены из VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "Настройки контроля доступа",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Аккаунт"),
    "action": MessageLookupByLibrary.simpleMessage("Действие"),
    "action_mode": MessageLookupByLibrary.simpleMessage("Переключить режим"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "action_start": MessageLookupByLibrary.simpleMessage("Старт/Стоп"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("Показать/Скрыть"),
    "add": MessageLookupByLibrary.simpleMessage("Добавить"),
    "addProfile": MessageLookupByLibrary.simpleMessage("Добавить профиль"),
    "addProxies": MessageLookupByLibrary.simpleMessage("Добавить прокси"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Добавить группу прокси",
    ),
    "addProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Добавить провайдеров прокси",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Добавить правило"),
    "addSsid": MessageLookupByLibrary.simpleMessage("Добавить SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("Добавленные правила"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Дополнительные параметры",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Адрес"),
    "addressHelp": MessageLookupByLibrary.simpleMessage("Адрес сервера WebDAV"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите действительный адрес WebDAV",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Расширенная конфигурация",
    ),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Предоставляет разнообразные варианты конфигурации",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Согласен"),
    "aiAddConnection": MessageLookupByLibrary.simpleMessage(
      "Добавить подключение",
    ),
    "aiAdvanced": MessageLookupByLibrary.simpleMessage("Ограничения запросов"),
    "aiAfter": MessageLookupByLibrary.simpleMessage("После"),
    "aiApiProtocol": MessageLookupByLibrary.simpleMessage("Протокол API"),
    "aiApprovalTitle": MessageLookupByLibrary.simpleMessage(
      "Подтвердите изменения",
    ),
    "aiApprove": MessageLookupByLibrary.simpleMessage(
      "Подтвердить и применить",
    ),
    "aiApproveScriptExecution": MessageLookupByLibrary.simpleMessage(
      "Разрешить выполнение для предпросмотра",
    ),
    "aiAssistant": MessageLookupByLibrary.simpleMessage("AI"),
    "aiAssistantRole": MessageLookupByLibrary.simpleMessage("Помощник"),
    "aiAssistantTitle": MessageLookupByLibrary.simpleMessage("ИИ-помощник"),
    "aiAuthFailed": MessageLookupByLibrary.simpleMessage(
      "Ошибка авторизации. Проверьте ключ для этого адреса",
    ),
    "aiBaseUrl": MessageLookupByLibrary.simpleMessage("Адрес сервиса"),
    "aiBefore": MessageLookupByLibrary.simpleMessage("До"),
    "aiCancelled": MessageLookupByLibrary.simpleMessage("Остановлено"),
    "aiChinaApi": MessageLookupByLibrary.simpleMessage("API Китая"),
    "aiChinaCoding": MessageLookupByLibrary.simpleMessage("Coding-тариф Китая"),
    "aiClearConversation": MessageLookupByLibrary.simpleMessage(
      "Очистить диалог",
    ),
    "aiCodingPlan": MessageLookupByLibrary.simpleMessage("Coding-тариф"),
    "aiConnection": MessageLookupByLibrary.simpleMessage("Подключение"),
    "aiCredentialRecoveryFailed": MessageLookupByLibrary.simpleMessage(
      "Восстановить ключ не удалось. Настройте его заново перед использованием",
    ),
    "aiCredentialUnavailable": MessageLookupByLibrary.simpleMessage(
      "Связка ключей недоступна. Проверьте системный запрос доступа",
    ),
    "aiCurrentConnection": MessageLookupByLibrary.simpleMessage(
      "Текущее подключение",
    ),
    "aiCustomProvider": MessageLookupByLibrary.simpleMessage(
      "Совместимый сервис",
    ),
    "aiDeleteConnection": MessageLookupByLibrary.simpleMessage(
      "Удалить подключение",
    ),
    "aiDeleteKey": MessageLookupByLibrary.simpleMessage("Удалить ключ"),
    "aiDeleteKeyHint": MessageLookupByLibrary.simpleMessage(
      "Удаление ключа отменит задачу ИИ; локальные политики продолжат работу",
    ),
    "aiDisabled": MessageLookupByLibrary.simpleMessage("ИИ-помощник выключен"),
    "aiEditConnection": MessageLookupByLibrary.simpleMessage(
      "Изменить подключение",
    ),
    "aiEmptyConversation": MessageLookupByLibrary.simpleMessage(
      "Проверьте текущую конфигурацию и просмотрите изменения",
    ),
    "aiEnable": MessageLookupByLibrary.simpleMessage("Включить ИИ-помощника"),
    "aiEnableHint": MessageLookupByLibrary.simpleMessage(
      "Модель вызывается только при отправке сообщения; локальные политики работают независимо",
    ),
    "aiFetchModels": MessageLookupByLibrary.simpleMessage("Получить модели"),
    "aiFinalConfigDifferences": MessageLookupByLibrary.simpleMessage(
      "Проверенные изменения итоговой конфигурации",
    ),
    "aiGlobalApi": MessageLookupByLibrary.simpleMessage("Глобальный API"),
    "aiGlobalCoding": MessageLookupByLibrary.simpleMessage(
      "Глобальный Coding-тариф",
    ),
    "aiHighRisk": MessageLookupByLibrary.simpleMessage(
      "Изменение затронет сеть, конфигурацию или конфиденциальность. Проверьте его",
    ),
    "aiHistoryLimit": MessageLookupByLibrary.simpleMessage(
      "Достигнут лимит диалога. Очистите его для продолжения",
    ),
    "aiHostUnavailable": MessageLookupByLibrary.simpleMessage(
      "Среда ИИ недоступна. Используйте сборку macOS с этим компонентом",
    ),
    "aiInvalidConnection": MessageLookupByLibrary.simpleMessage(
      "Проверьте имя, модель, адрес и ограничения",
    ),
    "aiKey": MessageLookupByLibrary.simpleMessage("API-ключ"),
    "aiKeyHide": MessageLookupByLibrary.simpleMessage("Скрыть ключ"),
    "aiKeyMissing": MessageLookupByLibrary.simpleMessage(
      "Сначала сохраните ключ для подключения",
    ),
    "aiKeyRequired": MessageLookupByLibrary.simpleMessage(
      "Введите API-ключ для этого адреса",
    ),
    "aiKeyShow": MessageLookupByLibrary.simpleMessage("Показать ключ"),
    "aiKeyStored": MessageLookupByLibrary.simpleMessage(
      "Сохранён в Связке ключей; оставьте пустым для сохранения",
    ),
    "aiManualModel": MessageLookupByLibrary.simpleMessage(
      "ID модели (можно ввести вручную)",
    ),
    "aiMaxTokens": MessageLookupByLibrary.simpleMessage(
      "Максимум выходных токенов",
    ),
    "aiModel": MessageLookupByLibrary.simpleMessage("ID модели"),
    "aiModelFetchHint": MessageLookupByLibrary.simpleMessage(
      "Получение моделей не проверяет диалог и инструменты. ID можно ввести вручную.",
    ),
    "aiModelsEmpty": MessageLookupByLibrary.simpleMessage(
      "Модели не найдены. Введите ID вручную.",
    ),
    "aiModelsFetched": m0,
    "aiModelsUnsupported": MessageLookupByLibrary.simpleMessage(
      "Этот сервис не поддерживает получение моделей. Введите ID вручную.",
    ),
    "aiNoConnection": MessageLookupByLibrary.simpleMessage(
      "Добавьте подключение для начала диалога",
    ),
    "aiNoDifferences": MessageLookupByLibrary.simpleMessage(
      "Нет изменений для применения",
    ),
    "aiPresetDefault": MessageLookupByLibrary.simpleMessage(
      "Пустое поле — адрес по умолчанию",
    ),
    "aiPromptHint": MessageLookupByLibrary.simpleMessage(
      "Опишите, что проверить или изменить…",
    ),
    "aiProvider": MessageLookupByLibrary.simpleMessage("Провайдер и адрес"),
    "aiQuotaExceeded": MessageLookupByLibrary.simpleMessage(
      "Квота исчерпана. Проверьте аккаунт провайдера",
    ),
    "aiRateLimited": MessageLookupByLibrary.simpleMessage(
      "Слишком много запросов. Повторите позже",
    ),
    "aiReject": MessageLookupByLibrary.simpleMessage("Отклонить"),
    "aiRequestFailed": MessageLookupByLibrary.simpleMessage(
      "Ошибка запроса. Проверьте подключение или повторите позже",
    ),
    "aiResourceActivationArtifactMissing": MessageLookupByLibrary.simpleMessage(
      "Одобренная конфигурация недоступна. Подготовьте и одобрите изменение заново.",
    ),
    "aiResourcePanelRequired": MessageLookupByLibrary.simpleMessage(
      "Выберите файл или папку назначения в локальной панели, чтобы продолжить.",
    ),
    "aiResourceScopeChanged": MessageLookupByLibrary.simpleMessage(
      "Ресурс изменился, пока предложение было открыто. Подготовьте новое предложение.",
    ),
    "aiResourceUpdateAccepted": MessageLookupByLibrary.simpleMessage(
      "Запрос обновления принят. Локальное ядро подтвердит завершение.",
    ),
    "aiSaveAndUse": MessageLookupByLibrary.simpleMessage(
      "Сохранить и использовать",
    ),
    "aiSaveFailed": MessageLookupByLibrary.simpleMessage(
      "Сохранение не удалось. Предпринято восстановление подключения и ключа; проверьте перед повтором",
    ),
    "aiSaved": MessageLookupByLibrary.simpleMessage("Подключение сохранено"),
    "aiScriptExecutionOnly": MessageLookupByLibrary.simpleMessage(
      "Разрешается только выполнение скрипта в ограниченной среде для предпросмотра. Применение результата потребует отдельного подтверждения.",
    ),
    "aiScriptRuntimeUnavailable": MessageLookupByLibrary.simpleMessage(
      "Встроенная среда скриптов недоступна. Переустановите приложение перед запуском скриптов.",
    ),
    "aiScriptSandboxRejected": MessageLookupByLibrary.simpleMessage(
      "Выполнение скрипта остановлено локальными ограничениями изоляции.",
    ),
    "aiSearchModels": MessageLookupByLibrary.simpleMessage("Поиск моделей"),
    "aiSelectConnection": MessageLookupByLibrary.simpleMessage(
      "Использовать подключение",
    ),
    "aiSelected": MessageLookupByLibrary.simpleMessage("Выбрано"),
    "aiSend": MessageLookupByLibrary.simpleMessage("Отправить"),
    "aiSettingsTitle": MessageLookupByLibrary.simpleMessage("Подключения ИИ"),
    "aiStop": MessageLookupByLibrary.simpleMessage("Остановить"),
    "aiTargetChanged": MessageLookupByLibrary.simpleMessage(
      "Адрес изменён. Введите ключ для нового сервиса",
    ),
    "aiTestConnection": MessageLookupByLibrary.simpleMessage(
      "Проверить вызов инструментов",
    ),
    "aiTestPartial": MessageLookupByLibrary.simpleMessage(
      "Проверка потока и инструмента не завершена; работа агента не подтверждена",
    ),
    "aiTestPassed": MessageLookupByLibrary.simpleMessage(
      "Авторизация, поток текста и вызов инструмента проверены",
    ),
    "aiTesting": MessageLookupByLibrary.simpleMessage("Проверка подключения…"),
    "aiTestingCharges": MessageLookupByLibrary.simpleMessage(
      "Тест вызывает выбранную модель и может расходовать платную квоту",
    ),
    "aiThinking": MessageLookupByLibrary.simpleMessage("Анализ…"),
    "aiTimedOut": MessageLookupByLibrary.simpleMessage(
      "Истёк тайм-аут запроса модели",
    ),
    "aiTimeout": MessageLookupByLibrary.simpleMessage("Тайм-аут (секунды)"),
    "aiToolWorking": MessageLookupByLibrary.simpleMessage(
      "Выполнение команды приложения…",
    ),
    "aiUsageClearIrreversible": MessageLookupByLibrary.simpleMessage(
      "Удаление истории использования нельзя отменить. Счетчики лимитов источников сохранятся.",
    ),
    "aiUseProxy": MessageLookupByLibrary.simpleMessage(
      "Использовать текущий прокси",
    ),
    "aiYou": MessageLookupByLibrary.simpleMessage("Вы"),
    "allTraffic": MessageLookupByLibrary.simpleMessage("Весь"),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Разрешить приложениям обходить VPN",
    ),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Некоторые приложения могут обходить VPN при включении",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Разрешить LAN"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить доступ к прокси через локальную сеть",
    ),
    "app": MessageLookupByLibrary.simpleMessage("Приложение"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа приложений",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Добавить системный DNS",
    ),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "Принудительно добавить системный DNS к конфигурации",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Приложение"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Изменение настроек, связанных с приложением",
    ),
    "authorized": MessageLookupByLibrary.simpleMessage("Разрешено"),
    "auto": MessageLookupByLibrary.simpleMessage("Авто"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Автопроверка обновлений",
    ),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически проверять обновления при запуске приложения",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Автоматическое закрытие соединений",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически закрывать соединения после смены узла",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Автозапуск"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Следовать автозапуску системы",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Автозапуск"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматический запуск при открытии приложения",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Автоматическая настройка системного DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления (минуты)",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Резервное копирование"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование и восстановление",
    ),
    "backupAndRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "Синхронизация данных через WebDAV или файлы",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование успешно",
    ),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Базовая конфигурация"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Глобальное изменение базовых настроек",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Основная информация"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Базовая стратегия"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "To ensure background operation, please disable battery optimization for this app. Tap to go to settings.",
    ),
    "batteryOptimizationStatusTip": MessageLookupByLibrary.simpleMessage(
      "Из-за особенностей системы этот статус не всегда может быть точным.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Привязать"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage(
      "Режим черного списка",
    ),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Обход домена"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только при включенном системном прокси",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Кэш поврежден. Хотите очистить его?",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Отменить выбор всего",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Проверить обновления"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "Текущее приложение уже является последней версией",
    ),
    "clearData": MessageLookupByLibrary.simpleMessage("Очистить данные"),
    "clearUsageData": MessageLookupByLibrary.simpleMessage(
      "Очистить данные расхода",
    ),
    "clearUsageDataConfirm": MessageLookupByLibrary.simpleMessage(
      "Все данные расхода и записи обработанных пакетов будут удалены безвозвратно. Продолжить?",
    ),
    "clearUsageDataDesc": MessageLookupByLibrary.simpleMessage(
      "Удалить всю локальную статистику, не меняя переключатель записи",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Экспорт в буфер обмена",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Импорт из буфера обмена",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Цвет"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Цветовые схемы"),
    "columns": MessageLookupByLibrary.simpleMessage("Столбцы"),
    "compatible": MessageLookupByLibrary.simpleMessage("Режим совместимости"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "Данные обнаружены в конфигурации",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Подтвердить"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите очистить все данные?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить текущую группу прокси?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите выйти из текущего окна?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите принудительно аварийно завершить работу ядра?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "Существующие данные будут перезаписаны после подтверждения",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Подключено"),
    "connecting": MessageLookupByLibrary.simpleMessage("Подключение..."),
    "connection": MessageLookupByLibrary.simpleMessage("Соединение"),
    "connections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр текущих данных о соединениях",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Связь："),
    "content": MessageLookupByLibrary.simpleMessage("Содержание"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Содержимое не может быть пустым",
    ),
    "contentScheme": MessageLookupByLibrary.simpleMessage("Контентная тема"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Управление глобальными добавленными правилами",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Копировать"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Копирование переменных окружения",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Копировать ссылку"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Копирование успешно"),
    "core": MessageLookupByLibrary.simpleMessage("Ядро"),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Основной статус"),
    "country": MessageLookupByLibrary.simpleMessage("Страна"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Обнаружен сбой"),
    "crashDetectedTip": MessageLookupByLibrary.simpleMessage(
      "Во время предыдущего запуска произошёл сбой приложения. Чтобы предотвратить повторный сбой, текущий профиль был сброшен, а автоматическая настройка конфигурации пропущена.",
    ),
    "crashTest": MessageLookupByLibrary.simpleMessage("Тест на сбои"),
    "crashlytics": MessageLookupByLibrary.simpleMessage("Анализ сбоев"),
    "crashlyticsTip": MessageLookupByLibrary.simpleMessage(
      "При включении автоматически загружает журналы сбоев без конфиденциальной информации, когда приложение выходит из строя",
    ),
    "create": MessageLookupByLibrary.simpleMessage("Создать"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Create Profile"),
    "creationTime": MessageLookupByLibrary.simpleMessage("Время создания"),
    "currentSessionUsage": MessageLookupByLibrary.simpleMessage(
      "Текущий сеанс · запись выключена",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Пользовательский"),
    "cut": MessageLookupByLibrary.simpleMessage("Вырезать"),
    "dark": MessageLookupByLibrary.simpleMessage("Темный"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Панель управления"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "Обнаружены изменения данных, хотите сохранить?",
    ),
    "dataCollectionContent": MessageLookupByLibrary.simpleMessage(
      "Это приложение использует Firebase Crashlytics для сбора информации о сбоях nhằm улучшения стабильности приложения.\nСобираемые данные включают информацию об устройстве и подробности о сбоях, но не содержат персональных конфиденциальных данных.\nВы можете отключить эту функцию в настройках.",
    ),
    "dataCollectionTip": MessageLookupByLibrary.simpleMessage(
      "Уведомление о сборе данных",
    ),
    "daysAgo": m1,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Сервер имен по умолчанию",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Для разрешения DNS-сервера",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("По умолчанию"),
    "delay": MessageLookupByLibrary.simpleMessage("Задержка"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Тест задержки"),
    "delete": MessageLookupByLibrary.simpleMessage("Удалить"),
    "deleteMultipTip": m2,
    "deleteTip": m3,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Многоплатформенный прокси-клиент на основе ClashMeta, простой и удобный в использовании, с открытым исходным кодом и без рекламы.",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("Назначение"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "Геолокация назначения",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("ASN назначения"),
    "details": m4,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Опирается на сторонний API, только для справки",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Режим разработчика"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Режим разработчика активирован.",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Прямой"),
    "directTraffic": MessageLookupByLibrary.simpleMessage("Прямой"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Отключить UDP"),
    "disclaimer": MessageLookupByLibrary.simpleMessage(
      "Отказ от ответственности",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Это программное обеспечение используется только в некоммерческих целях, таких как учебные обмены и научные исследования. Запрещено использовать это программное обеспечение в коммерческих целях. Любая коммерческая деятельность, если таковая имеется, не имеет отношения к этому программному обеспечению.",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Отключено"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Обнаружена новая версия",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage(
      "Обновление настроек, связанных с DNS",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS-перехват"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Режим DNS"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "Вы хотите пропустить",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Домен"),
    "domainTargets": MessageLookupByLibrary.simpleMessage(
      "Полные имена хостов и целевые IP",
    ),
    "download": MessageLookupByLibrary.simpleMessage("Скачивание"),
    "edit": MessageLookupByLibrary.simpleMessage("Редактировать"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Редактировать глобальные правила",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Редактировать прокси"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Редактировать группу прокси",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("Редактировать правило"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Изменить SSID"),
    "emptyTip": m5,
    "en": MessageLookupByLibrary.simpleMessage("Английский"),
    "enableUsageRecording": MessageLookupByLibrary.simpleMessage(
      "Включить запись",
    ),
    "entries": MessageLookupByLibrary.simpleMessage(" записей"),
    "entriesCount": m6,
    "exclude": MessageLookupByLibrary.simpleMessage(
      "Скрыть из последних задач",
    ),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Когда приложение находится в фоновом режиме, оно скрыто из последних задач",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage(
      "Исключить фильтр прокси",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Exclude SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "When connected to an excluded SSID Wi-Fi, the app running state will be automatically switched.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("Тип исключения"),
    "existsTip": m7,
    "exit": MessageLookupByLibrary.simpleMessage("Выход"),
    "expand": MessageLookupByLibrary.simpleMessage("Стандартный"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Ожидаемый статус"),
    "exportCsv": MessageLookupByLibrary.simpleMessage("Экспорт CSV"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Экспорт файла"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Экспорт логов"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Экспорт успешен"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("Экспрессивные"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Внешний контроллер",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "При включении ядро Clash можно контролировать на порту 9090",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("Внешнее получение"),
    "externalLink": MessageLookupByLibrary.simpleMessage("Внешняя ссылка"),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Фильтр Fakeip"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Диапазон Fakeip"),
    "fallback": MessageLookupByLibrary.simpleMessage("Резервный"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Обычно используется оффшорный DNS",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage(
      "Фильтр резервного DNS",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("Точная передача"),
    "file": MessageLookupByLibrary.simpleMessage("Файл"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("Прямая загрузка профиля"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "Файл был изменен. Хотите сохранить изменения?",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage(
      "Режим поиска процесса",
    ),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "При включении возможны небольшие потери производительности",
    ),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Семейство шрифтов"),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите принудительно перезапустить ядро?",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("Фруктовый микс"),
    "general": MessageLookupByLibrary.simpleMessage("Общие"),
    "geoAutoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "geoAutoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления",
    ),
    "geoAutoUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления должен быть больше 0",
    ),
    "geoOptions": MessageLookupByLibrary.simpleMessage("Настройки Geo"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Ресурсы Geo"),
    "geoSkipped": m8,
    "geoUpdated": m9,
    "geoUpdating": m10,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Режим низкого потребления памяти для геоданных",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Включение будет использовать загрузчик геоданных с низким потреблением памяти",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Код Geoip"),
    "global": MessageLookupByLibrary.simpleMessage("Глобальный"),
    "go": MessageLookupByLibrary.simpleMessage("Перейти"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Перейти к загрузке"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Перейти к настройке скрипта",
    ),
    "goToSettings": MessageLookupByLibrary.simpleMessage("Открыть настройки"),
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Хотите сохранить изменения в кэше?",
    ),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Служба Helper недоступна, поэтому TUN-режим включить нельзя. Переустановите FlClash.",
    ),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Скрыть из списка"),
    "host": MessageLookupByLibrary.simpleMessage("Хост"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Добавить Hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage(
      "Конфликт горячих клавиш",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Управление горячими клавишами",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Использование клавиатуры для управления приложением",
    ),
    "hourlyDistribution": MessageLookupByLibrary.simpleMessage(
      "Распределение по 24 часам",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("часов"),
    "hoursAgo": m11,
    "hoursCount": m12,
    "icon": MessageLookupByLibrary.simpleMessage("Иконка"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("История иконок"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Стиль иконки"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL иконки"),
    "identificationCoverage": MessageLookupByLibrary.simpleMessage(
      "Покрытие распознавания",
    ),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignore Battery Optimization",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Импорт"),
    "importFile": MessageLookupByLibrary.simpleMessage("Импорт из файла"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Импорт из URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Импорт по URL"),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage(
      "Включить все прокси",
    ),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "Импорт всех прокси, не содержащих группы прокси, дополнительные группы прокси можно добавить ниже",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Включить всех провайдеров прокси",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "При включении это переопределит импортированных провайдеров прокси",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage(
      "Долгосрочное действие",
    ),
    "init": MessageLookupByLibrary.simpleMessage("Инициализация"),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите правильную горячую клавишу",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Введите имя группы прокси",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Введите содержимое правила",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Интеллектуальный выбор",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Интернет"),
    "interval": MessageLookupByLibrary.simpleMessage("Интервал"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Внутренний IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Неверный файл резервной копии",
    ),
    "invalidPolicy": m13,
    "invalidProxy": m14,
    "invalidProxyProvider": m15,
    "invalidSubRule": m16,
    "ipcidr": MessageLookupByLibrary.simpleMessage("IPCIDR"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "При включении будет возможно получать IPv6 трафик",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешить входящий IPv6",
    ),
    "ja": MessageLookupByLibrary.simpleMessage("Японский"),
    "justNow": MessageLookupByLibrary.simpleMessage("Только что"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Интервал поддержания TCP-соединения",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Ключ"),
    "language": MessageLookupByLibrary.simpleMessage("Язык"),
    "last24Hours": MessageLookupByLibrary.simpleMessage("24 часа"),
    "last30Days": MessageLookupByLibrary.simpleMessage("30 дней"),
    "last7Days": MessageLookupByLibrary.simpleMessage("7 дней"),
    "layout": MessageLookupByLibrary.simpleMessage("Макет"),
    "light": MessageLookupByLibrary.simpleMessage("Светлый"),
    "list": MessageLookupByLibrary.simpleMessage("Список"),
    "listen": MessageLookupByLibrary.simpleMessage("Слушать"),
    "loadMore": MessageLookupByLibrary.simpleMessage("Загрузить ещё"),
    "loadTest": MessageLookupByLibrary.simpleMessage("Тест загрузки"),
    "loading": MessageLookupByLibrary.simpleMessage("Загрузка..."),
    "local": MessageLookupByLibrary.simpleMessage("Локальный"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование локальных данных на локальный диск",
    ),
    "localControlChangePassword": MessageLookupByLibrary.simpleMessage(
      "Изменить пароль",
    ),
    "localControlCommands": MessageLookupByLibrary.simpleMessage(
      "Посмотреть команды",
    ),
    "localControlCopyPath": MessageLookupByLibrary.simpleMessage(
      "Копировать путь к инструменту",
    ),
    "localControlDescription": MessageLookupByLibrary.simpleMessage(
      "Управление FlClash локальными командами",
    ),
    "localControlDisabled": MessageLookupByLibrary.simpleMessage("Отключён"),
    "localControlExitHint": MessageLookupByLibrary.simpleMessage(
      "После выхода из приложения CLI недоступен. Скрытие окна не влияет на его работу.",
    ),
    "localControlPassword": MessageLookupByLibrary.simpleMessage("Пароль CLI"),
    "localControlPasswordHint": MessageLookupByLibrary.simpleMessage(
      "Создаётся случайно при первом запуске и сохраняется после перезапуска. Новый пароль отменяет старый.",
    ),
    "localControlPasswordValidation": MessageLookupByLibrary.simpleMessage(
      "От 12 до 128 символов Unicode без управляющих символов.",
    ),
    "localControlRandomPassword": MessageLookupByLibrary.simpleMessage(
      "Создать новый случайный пароль",
    ),
    "localControlReady": MessageLookupByLibrary.simpleMessage(
      "Готов, только локальный доступ",
    ),
    "localControlSaveFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось сохранить или безопасно завершить работу. Старый пароль остаётся действительным.",
    ),
    "localControlSecurity": MessageLookupByLibrary.simpleMessage(
      "Безопасность и подтверждение операций",
    ),
    "localControlSecurityHint": MessageLookupByLibrary.simpleMessage(
      "Изменения настроек требуют предварительного просмотра и подтверждения. Системные разрешения запрашиваются системой.",
    ),
    "localControlTitle": MessageLookupByLibrary.simpleMessage("Локальный CLI"),
    "localControlUnavailable": MessageLookupByLibrary.simpleMessage(
      "Сервис недоступен. Повторите попытку.",
    ),
    "localControlUsage": MessageLookupByLibrary.simpleMessage("Использование"),
    "localControlUsageHint": MessageLookupByLibrary.simpleMessage(
      "Введите пароль при выполнении команды. Скрипты могут передавать его через stdin или отдельный файловый дескриптор.",
    ),
    "localPolicies": MessageLookupByLibrary.simpleMessage("Локальные правила"),
    "localUsageNotice": MessageLookupByLibrary.simpleMessage(
      "Локальная запись, не для точного биллинга",
    ),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Location Permission",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Разрешение на геолокацию отклонено, поэтому невозможно получить имя текущей Wi-Fi сети. Включите разрешение на геолокацию вручную в системных настройках.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "According to system requirements, obtaining the Wi-Fi name requires you to grant location permission.",
    ),
    "locationPermissionGuide": m17,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Location Permission Required",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Журнал"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Уровень логов"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Отключение скроет запись логов",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Логи"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("Записи захвата логов"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Тест журналов"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "Инструмент разблокировки Loopback",
    ),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Используется для разблокировки Loopback UWP",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Свободный"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage(
      "Сопоставить исходный IP",
    ),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage(
      "Макс. количество неудач",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Информация о памяти"),
    "messageTest": MessageLookupByLibrary.simpleMessage(
      "Тестирование сообщения",
    ),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("Это сообщение."),
    "min": MessageLookupByLibrary.simpleMessage("Мин"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Свернуть при выходе",
    ),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Изменить стандартное событие выхода из системы",
    ),
    "minutesAgo": m18,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Смешанный порт"),
    "mode": MessageLookupByLibrary.simpleMessage("Режим"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Монохром"),
    "monthsAgo": m19,
    "more": MessageLookupByLibrary.simpleMessage("Еще"),
    "name": MessageLookupByLibrary.simpleMessage("Имя"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Сервер имен"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Для разрешения домена",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Политика сервера имен",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Указать соответствующую политику сервера имен",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Сеть"),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "Изменение настроек, связанных с сетью",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage(
      "Обнаружение сети",
    ),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "Ошибка сети, проверьте соединение и попробуйте еще раз",
    ),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Скорость сети"),
    "networkType": MessageLookupByLibrary.simpleMessage("Тип сети"),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("Нейтральные"),
    "noData": MessageLookupByLibrary.simpleMessage("Нет данных"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("Нет горячей клавиши"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Нет информации"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Больше не напоминать",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Нет сети"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Приложение без сети"),
    "noRecords": MessageLookupByLibrary.simpleMessage("Нет записей"),
    "noResolve": MessageLookupByLibrary.simpleMessage("Не разрешать IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "Не разрешать имя хоста",
    ),
    "noUsageData": MessageLookupByLibrary.simpleMessage(
      "Нет данных для текущих фильтров",
    ),
    "none": MessageLookupByLibrary.simpleMessage("Нет"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Текущая группа прокси не может быть выбрана.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Нет профиля, пожалуйста, добавьте профиль",
    ),
    "nullTip": m20,
    "numberTip": m21,
    "onDemand": MessageLookupByLibrary.simpleMessage("On Demand"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "Configure the program running state for specific scenarios",
    ),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Только иконка"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Только статистика прокси",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "При включении будет учитываться только трафик прокси",
    ),
    "openProcessSettings": MessageLookupByLibrary.simpleMessage(
      "Настройки распознавания процессов",
    ),
    "optional": MessageLookupByLibrary.simpleMessage("Необязательно"),
    "options": MessageLookupByLibrary.simpleMessage("Опции"),
    "other": MessageLookupByLibrary.simpleMessage("Другое"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Другие участники",
    ),
    "outboundMode": MessageLookupByLibrary.simpleMessage(
      "Режим исходящего трафика",
    ),
    "override": MessageLookupByLibrary.simpleMessage("Переопределить"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Переопределить DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Включение переопределит настройки DNS в профиле",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage(
      "Режим переопределения",
    ),
    "overrideScript": MessageLookupByLibrary.simpleMessage(
      "Скрипт переопределения",
    ),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage(
      "Пользовательский",
    ),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Пользовательский режим, полная настройка групп прокси и правил",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Палитра"),
    "password": MessageLookupByLibrary.simpleMessage("Пароль"),
    "paste": MessageLookupByLibrary.simpleMessage("Вставить"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, привяжите WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите название скрипта",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите пароль администратора",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, загрузите действительный QR-код",
    ),
    "policyActiveIntegration": MessageLookupByLibrary.simpleMessage(
      "Активное объединение",
    ),
    "policyAddBackup": MessageLookupByLibrary.simpleMessage("Добавить резерв"),
    "policyAddBudget": MessageLookupByLibrary.simpleMessage("Добавить лимит"),
    "policyAddIntegration": MessageLookupByLibrary.simpleMessage(
      "Создать объединение",
    ),
    "policyAddRule": MessageLookupByLibrary.simpleMessage("Добавить правило"),
    "policyAdmission": MessageLookupByLibrary.simpleMessage(
      "Срок действия и остаток квоты",
    ),
    "policyAdvancedJson": MessageLookupByLibrary.simpleMessage(
      "Расширенный JSON",
    ),
    "policyAiGenerate": MessageLookupByLibrary.simpleMessage(
      "Создать план с ИИ",
    ),
    "policyAiGenerationRequest": m22,
    "policyAiOrigin": MessageLookupByLibrary.simpleMessage("Создано ИИ"),
    "policyApplication": MessageLookupByLibrary.simpleMessage("Приложение"),
    "policyAppliedStatus": MessageLookupByLibrary.simpleMessage("Применено"),
    "policyAssumeHealthy": MessageLookupByLibrary.simpleMessage(
      "Считать все узлы доступными",
    ),
    "policyAutoCheck": MessageLookupByLibrary.simpleMessage(
      "Автоматические проверки",
    ),
    "policyAutoRecover": MessageLookupByLibrary.simpleMessage(
      "Возвращаться к более приоритетному узлу",
    ),
    "policyAvailableMembers": MessageLookupByLibrary.simpleMessage(
      "Доступные участники",
    ),
    "policyBudgetGiB": MessageLookupByLibrary.simpleMessage(
      "Лимит устройства (GiB)",
    ),
    "policyBudgetHint": MessageLookupByLibrary.simpleMessage(
      "Учитывается только трафик FlClash этого устройства, не весь аккаунт и не точный побайтовый лимит",
    ),
    "policyBudgetLastSample": m23,
    "policyBudgetPeriod": m24,
    "policyBudgetReached": MessageLookupByLibrary.simpleMessage(
      "Локальный лимит достигнут; новые подключения через источник ограничены",
    ),
    "policyBudgetReachedHint": MessageLookupByLibrary.simpleMessage(
      "При выборе узла по локальным правилам будут проверены другие доступные варианты. Если их нет, применяется резервное действие правила.",
    ),
    "policyBudgetTab": MessageLookupByLibrary.simpleMessage("Лимиты"),
    "policyCandidateHint": MessageLookupByLibrary.simpleMessage(
      "Выбираются только эти узлы и в указанном порядке",
    ),
    "policyCandidates": MessageLookupByLibrary.simpleMessage(
      "Точный порядок узлов",
    ),
    "policyCheckCapacityHint": m25,
    "policyCheckMeasurementHint": MessageLookupByLibrary.simpleMessage(
      "Измеряется доступность и задержка запроса, а не скорость загрузки",
    ),
    "policyCheckNow": MessageLookupByLibrary.simpleMessage("Проверить сейчас"),
    "policyCheckPending": MessageLookupByLibrary.simpleMessage(
      "Ожидает проверки",
    ),
    "policyCheckPreset": MessageLookupByLibrary.simpleMessage(
      "Предустановка адреса проверки",
    ),
    "policyCheckSave": MessageLookupByLibrary.simpleMessage(
      "Проверить и сохранить",
    ),
    "policyChecksInFlight": MessageLookupByLibrary.simpleMessage(
      "Проверки выполняются",
    ),
    "policyChecksWaiting": MessageLookupByLibrary.simpleMessage(
      "Проверки в очереди",
    ),
    "policyCollectionPending": MessageLookupByLibrary.simpleMessage(
      "Не настроено",
    ),
    "policyCombinedConditions": MessageLookupByLibrary.simpleMessage(
      "Составные условия",
    ),
    "policyContinueEditing": MessageLookupByLibrary.simpleMessage(
      "Продолжить редактирование",
    ),
    "policyCooldownSeconds": MessageLookupByLibrary.simpleMessage(
      "Пауза между переключениями (секунды)",
    ),
    "policyCoreStopped": MessageLookupByLibrary.simpleMessage(
      "Core остановлен; политики не выполняются",
    ),
    "policyCustomCheck": MessageLookupByLibrary.simpleMessage("Свой"),
    "policyDeclaredAttribute": MessageLookupByLibrary.simpleMessage(
      "Заявлено подпиской",
    ),
    "policyDeleteLinked": MessageLookupByLibrary.simpleMessage(
      "Объединение используется правилами. Сначала измените их",
    ),
    "policyDiscardChanges": MessageLookupByLibrary.simpleMessage(
      "Отменить изменения",
    ),
    "policyDomainKeyword": MessageLookupByLibrary.simpleMessage(
      "Ключевое слово домена",
    ),
    "policyDomainScope": MessageLookupByLibrary.simpleMessage("Точный домен"),
    "policyDomainSuffix": MessageLookupByLibrary.simpleMessage(
      "Суффикс домена",
    ),
    "policyDraftStatus": MessageLookupByLibrary.simpleMessage(
      "Ожидает подтверждения",
    ),
    "policyEditIntegration": MessageLookupByLibrary.simpleMessage(
      "Изменить объединение",
    ),
    "policyEditRule": MessageLookupByLibrary.simpleMessage("Изменить правило"),
    "policyEligible": MessageLookupByLibrary.simpleMessage("Подходит сейчас"),
    "policyEmptyBudgets": MessageLookupByLibrary.simpleMessage(
      "Нет лимитов источников",
    ),
    "policyEmptyHistory": MessageLookupByLibrary.simpleMessage(
      "Нет истории изменений",
    ),
    "policyEmptyIntegrations": MessageLookupByLibrary.simpleMessage(
      "Нет объединений",
    ),
    "policyEmptyRules": MessageLookupByLibrary.simpleMessage(
      "Нет локальных правил",
    ),
    "policyEnableBudgets": MessageLookupByLibrary.simpleMessage(
      "Включить лимиты источников",
    ),
    "policyEnableIntegrations": MessageLookupByLibrary.simpleMessage(
      "Включить объединение",
    ),
    "policyEnableRules": MessageLookupByLibrary.simpleMessage(
      "Включить локальные правила",
    ),
    "policyEndTime": MessageLookupByLibrary.simpleMessage("Окончание (HH:mm)"),
    "policyExcluded": MessageLookupByLibrary.simpleMessage("Исключён сейчас"),
    "policyExcludedNodes": MessageLookupByLibrary.simpleMessage(
      "Исключённые узлы",
    ),
    "policyExpectedStatus": MessageLookupByLibrary.simpleMessage(
      "Ожидаемый статус HTTP",
    ),
    "policyExpiryMargin": MessageLookupByLibrary.simpleMessage(
      "Исключать до истечения (часы)",
    ),
    "policyFailures": MessageLookupByLibrary.simpleMessage("Ошибок подряд"),
    "policyFallback": MessageLookupByLibrary.simpleMessage(
      "Если подходящих узлов нет",
    ),
    "policyFallbackDirect": MessageLookupByLibrary.simpleMessage(
      "Разрешить прямое соединение",
    ),
    "policyFallbackReject": MessageLookupByLibrary.simpleMessage(
      "Блокировать соединения",
    ),
    "policyFixedNode": MessageLookupByLibrary.simpleMessage("Конкретный узел"),
    "policyGlobalScope": MessageLookupByLibrary.simpleMessage("Весь трафик"),
    "policyGroupScope": MessageLookupByLibrary.simpleMessage(
      "Существующая группа",
    ),
    "policyHideUnavailable": MessageLookupByLibrary.simpleMessage(
      "Автоматически скрывать недоступные узлы",
    ),
    "policyHistoryTab": MessageLookupByLibrary.simpleMessage("История"),
    "policyImprovementPercent": MessageLookupByLibrary.simpleMessage(
      "Порог улучшения задержки (%)",
    ),
    "policyIncludeSubdomains": MessageLookupByLibrary.simpleMessage(
      "Включая поддомены",
    ),
    "policyIntegrationHint": MessageLookupByLibrary.simpleMessage(
      "Исходные подписки сохраняются; выбранные источники объединяются в отдельную конфигурацию",
    ),
    "policyIntegrationTab": MessageLookupByLibrary.simpleMessage("Объединение"),
    "policyInvalidData": MessageLookupByLibrary.simpleMessage(
      "Неверные поля, порядок или ссылки. Проверьте их",
    ),
    "policyJsonHint": MessageLookupByLibrary.simpleMessage(
      "Принимается только текущая схема; неверные поля и ссылки не применяются",
    ),
    "policyLatencyFirst": MessageLookupByLibrary.simpleMessage(
      "Приоритет низкой задержки",
    ),
    "policyLedgerUntrusted": MessageLookupByLibrary.simpleMessage(
      "Учёт недостоверен; источник ограничен",
    ),
    "policyLoadNodes": MessageLookupByLibrary.simpleMessage(
      "Загрузить доступные узлы",
    ),
    "policyLocalCollection": MessageLookupByLibrary.simpleMessage(
      "Локальная коллекция подписок",
    ),
    "policyManualAttribute": MessageLookupByLibrary.simpleMessage(
      "Подтверждено вручную",
    ),
    "policyManualOrigin": MessageLookupByLibrary.simpleMessage(
      "Добавлено вручную",
    ),
    "policyMatchAll": MessageLookupByLibrary.simpleMessage(
      "Все условия (расширенно)",
    ),
    "policyMatchAny": MessageLookupByLibrary.simpleMessage(
      "Любое условие (расширенно)",
    ),
    "policyMatchNot": MessageLookupByLibrary.simpleMessage(
      "Отрицание (расширенно)",
    ),
    "policyMemberPreview": MessageLookupByLibrary.simpleMessage(
      "Предпросмотр участников",
    ),
    "policyMetadataAge": MessageLookupByLibrary.simpleMessage(
      "Срок актуальности данных (часы)",
    ),
    "policyMethod": MessageLookupByLibrary.simpleMessage("Метод запроса"),
    "policyMissingNode": MessageLookupByLibrary.simpleMessage(
      "Узел отсутствует",
    ),
    "policyModule": MessageLookupByLibrary.simpleMessage(
      "Модуль локальных правил",
    ),
    "policyModuleOffHint": MessageLookupByLibrary.simpleMessage(
      "Отключение сохраняет правила, наборы узлов и бюджет",
    ),
    "policyMoreSettings": MessageLookupByLibrary.simpleMessage(
      "Другие настройки",
    ),
    "policyMoveDown": MessageLookupByLibrary.simpleMessage("Вниз"),
    "policyMoveUp": MessageLookupByLibrary.simpleMessage("Вверх"),
    "policyMultiplierFirst": MessageLookupByLibrary.simpleMessage(
      "Приоритет низкого множителя",
    ),
    "policyMultiplierLimit": MessageLookupByLibrary.simpleMessage(
      "Предел множителя",
    ),
    "policyNameAttribute": MessageLookupByLibrary.simpleMessage(
      "Определено по имени",
    ),
    "policyNameFilter": MessageLookupByLibrary.simpleMessage(
      "Имя узла содержит (необязательно)",
    ),
    "policyNoMembers": MessageLookupByLibrary.simpleMessage(
      "Нет подходящих участников; будет использован резерв или конечное действие",
    ),
    "policyNodeSet": MessageLookupByLibrary.simpleMessage("Набор узлов"),
    "policyNodeSets": MessageLookupByLibrary.simpleMessage("Наборы узлов"),
    "policyNodes": MessageLookupByLibrary.simpleMessage("Узлы"),
    "policyNotCollected": MessageLookupByLibrary.simpleMessage(
      "Данные не собраны",
    ),
    "policyNotRunning": MessageLookupByLibrary.simpleMessage(
      "Сейчас не работает",
    ),
    "policyOperationFailed": MessageLookupByLibrary.simpleMessage(
      "Операция не завершена. Проверьте состояние",
    ),
    "policyOverrideMinutes": MessageLookupByLibrary.simpleMessage(
      "Срок в минутах",
    ),
    "policyPageSampleAt": MessageLookupByLibrary.simpleMessage(
      "Время снимка состояния",
    ),
    "policyPendingMembers": MessageLookupByLibrary.simpleMessage(
      "Ожидают проверки",
    ),
    "policyPreferred": MessageLookupByLibrary.simpleMessage("Основной"),
    "policyPreparingStatus": MessageLookupByLibrary.simpleMessage("Обработка"),
    "policyPreviewHint": MessageLookupByLibrary.simpleMessage(
      "Предпросмотр выбора узлов без проверки реальных запросов",
    ),
    "policyPriority": MessageLookupByLibrary.simpleMessage(
      "Приоритет (меньший первым)",
    ),
    "policyProbe": MessageLookupByLibrary.simpleMessage("Проверка доступности"),
    "policyProbeInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал (секунды)",
    ),
    "policyProbeTimeout": MessageLookupByLibrary.simpleMessage(
      "Тайм-аут (секунды)",
    ),
    "policyProbeUrl": MessageLookupByLibrary.simpleMessage("Адрес проверки"),
    "policyProcessHint": MessageLookupByLibrary.simpleMessage(
      "Определение процесса зависит от системных разрешений и способа подключения",
    ),
    "policyProcessName": MessageLookupByLibrary.simpleMessage("Имя процесса"),
    "policyProcessPath": MessageLookupByLibrary.simpleMessage("Путь процесса"),
    "policyRecovery": MessageLookupByLibrary.simpleMessage(
      "Восстановление и пауза",
    ),
    "policyRecoveryCheck": MessageLookupByLibrary.simpleMessage(
      "Проверить и восстановить",
    ),
    "policyRecoveryKeep": MessageLookupByLibrary.simpleMessage(
      "Сохранить проверенные текущие настройки",
    ),
    "policyRecoverySeconds": MessageLookupByLibrary.simpleMessage(
      "Наблюдение восстановления (секунды)",
    ),
    "policyRecoveryStatus": MessageLookupByLibrary.simpleMessage(
      "Требуется восстановление",
    ),
    "policyRegions": MessageLookupByLibrary.simpleMessage("Регионы"),
    "policyRejectedStatus": MessageLookupByLibrary.simpleMessage("Отклонено"),
    "policyRemainingGiB": MessageLookupByLibrary.simpleMessage(
      "Минимальный остаток (GiB)",
    ),
    "policyRemainingTraffic": MessageLookupByLibrary.simpleMessage(
      "Остальной трафик",
    ),
    "policyRemoveCandidate": MessageLookupByLibrary.simpleMessage(
      "Убрать узел",
    ),
    "policyRemoveOverride": MessageLookupByLibrary.simpleMessage(
      "Убрать временный выбор",
    ),
    "policyResetDay": MessageLookupByLibrary.simpleMessage(
      "День сброса (1–28)",
    ),
    "policyRestoredStatus": MessageLookupByLibrary.simpleMessage(
      "Восстановлено",
    ),
    "policyRestrictedMembers": MessageLookupByLibrary.simpleMessage(
      "Ограниченные участники",
    ),
    "policyRetrySeconds": MessageLookupByLibrary.simpleMessage(
      "Повторная проверка недоступных узлов (сек.)",
    ),
    "policyRuleOrderHint": MessageLookupByLibrary.simpleMessage(
      "Проверка сверху вниз; используется первое совпадение",
    ),
    "policyRuleType": MessageLookupByLibrary.simpleMessage("Тип правила"),
    "policyRulesHint": MessageLookupByLibrary.simpleMessage(
      "Выбор доступных узлов в указанном порядке, без вызова ИИ",
    ),
    "policyRulesTab": MessageLookupByLibrary.simpleMessage("Правила"),
    "policyRuntimeState": MessageLookupByLibrary.simpleMessage("Состояние"),
    "policySaved": MessageLookupByLibrary.simpleMessage(
      "Сохранено и применено",
    ),
    "policySavedInactive": MessageLookupByLibrary.simpleMessage(
      "Сохранено; сейчас не работает",
    ),
    "policySchedule": MessageLookupByLibrary.simpleMessage("Расписание"),
    "policyScheduleEnabled": MessageLookupByLibrary.simpleMessage(
      "Ограничить часы работы",
    ),
    "policyScheduleHint": MessageLookupByLibrary.simpleMessage(
      "Используйте время Пекина; ночной период разделите на два окна",
    ),
    "policyScheduleSkip": MessageLookupByLibrary.simpleMessage(
      "Вне расписания перейти к следующим правилам",
    ),
    "policyScope": MessageLookupByLibrary.simpleMessage("Область действия"),
    "policyScopeValues": MessageLookupByLibrary.simpleMessage(
      "Один домен, группа или процесс в строке",
    ),
    "policySearchNodes": MessageLookupByLibrary.simpleMessage(
      "Поиск узлов и источников",
    ),
    "policySelectCollection": MessageLookupByLibrary.simpleMessage(
      "Выбрать и использовать",
    ),
    "policySelectedNode": MessageLookupByLibrary.simpleMessage(
      "Выбранный узел",
    ),
    "policySelectedOffline": MessageLookupByLibrary.simpleMessage(
      "Выбрано; используется после подключения",
    ),
    "policySharedSetImpact": MessageLookupByLibrary.simpleMessage(
      "Изменения общего набора влияют на связанные правила",
    ),
    "policyShowUnavailable": MessageLookupByLibrary.simpleMessage(
      "Показать всех участников",
    ),
    "policySimulation": MessageLookupByLibrary.simpleMessage(
      "Моделирование политик",
    ),
    "policySimulationCoreRequired": MessageLookupByLibrary.simpleMessage(
      "Для моделирования нужно запущенное ядро прокси",
    ),
    "policySimulationHint": MessageLookupByLibrary.simpleMessage(
      "Прогноз по текущим источникам, состоянию и использованию; шаги сценария показывают проверки, паузы и восстановление. Реальные проверки и запись конфигурации не выполняются.",
    ),
    "policySimulationSteps": MessageLookupByLibrary.simpleMessage(
      "Шаги сценария (расширенный JSON)",
    ),
    "policySimulationStepsHint": MessageLookupByLibrary.simpleMessage(
      "До 32 шагов: at — время в миллисекундах; probes — nodeId и success; sources — метаданные; usage — использованные байты по источникам. Проверки и запись конфигурации не выполняются.",
    ),
    "policySimulationTimeline": MessageLookupByLibrary.simpleMessage(
      "Временная шкала смены кандидатов",
    ),
    "policySourceExpiry": MessageLookupByLibrary.simpleMessage("Срок подписки"),
    "policySourceMissing": MessageLookupByLibrary.simpleMessage(
      "Источник или узел отсутствует; выберите снова",
    ),
    "policySourceQuota": MessageLookupByLibrary.simpleMessage(
      "Остаток лимита подписки",
    ),
    "policySources": MessageLookupByLibrary.simpleMessage("Источники"),
    "policySourcesCollection": MessageLookupByLibrary.simpleMessage(
      "Источники и коллекция",
    ),
    "policyStableFirst": MessageLookupByLibrary.simpleMessage(
      "Приоритет стабильности",
    ),
    "policyStartTime": MessageLookupByLibrary.simpleMessage("Начало (HH:mm)"),
    "policySubscriptionExhausted": MessageLookupByLibrary.simpleMessage(
      "Трафик подписки исчерпан",
    ),
    "policySubscriptionExpired": MessageLookupByLibrary.simpleMessage(
      "Подписка истекла",
    ),
    "policySuccesses": MessageLookupByLibrary.simpleMessage(
      "Успешных проверок подряд",
    ),
    "policySupersededStatus": MessageLookupByLibrary.simpleMessage(
      "Заменено последующим изменением",
    ),
    "policyTarget": MessageLookupByLibrary.simpleMessage(
      "Целевая конфигурация",
    ),
    "policyTemporaryOverride": MessageLookupByLibrary.simpleMessage(
      "Временный выбор",
    ),
    "policyTerminate": MessageLookupByLibrary.simpleMessage(
      "Завершать связанные соединения при исключении",
    ),
    "policyTerminateHint": MessageLookupByLibrary.simpleMessage(
      "Это прервёт существующие соединения и требует подтверждения",
    ),
    "policyUndo": MessageLookupByLibrary.simpleMessage("Отменить изменение"),
    "policyUnknownAttribute": MessageLookupByLibrary.simpleMessage(
      "Неизвестно",
    ),
    "policyUnknownHealth": MessageLookupByLibrary.simpleMessage(
      "Доступность неизвестна",
    ),
    "policyUnknownMetadata": MessageLookupByLibrary.simpleMessage(
      "Исключать источники с неизвестными данными",
    ),
    "policyUnknownMultiplierAllowed": MessageLookupByLibrary.simpleMessage(
      "Разрешать неизвестный множитель без предположений",
    ),
    "policyUnknownNameOrigin": MessageLookupByLibrary.simpleMessage(
      "Неизвестный источник",
    ),
    "policyUnknownOne": MessageLookupByLibrary.simpleMessage(
      "Считать неизвестный множитель равным 1×",
    ),
    "policyUnknownOneHint": MessageLookupByLibrary.simpleMessage(
      "Только для фильтрации и сортировки; значение остаётся неизвестным",
    ),
    "policyUnsavedTitle": MessageLookupByLibrary.simpleMessage(
      "Несохранённые изменения",
    ),
    "policyUnsupportedSourceOption": m26,
    "policyUpdateProxyUnavailable": MessageLookupByLibrary.simpleMessage(
      "Прокси недоступен. Запустите его или явно выберите прямое обновление подписок.",
    ),
    "policyUpdateRoute": MessageLookupByLibrary.simpleMessage(
      "Маршрут обновления подписок",
    ),
    "policyUpdateRouteDirect": MessageLookupByLibrary.simpleMessage(
      "Прямое соединение",
    ),
    "policyUpdateRouteHint": MessageLookupByLibrary.simpleMessage(
      "Действует при включённых локальных политиках, объединении или бюджетах. Недоступный прокси останавливает обновления; прямой доступ требует подтверждения.",
    ),
    "policyUpdateRouteProxy": MessageLookupByLibrary.simpleMessage(
      "Через текущий прокси",
    ),
    "policyUsage": MessageLookupByLibrary.simpleMessage(
      "Использовано устройством",
    ),
    "policyUsageUnknown": MessageLookupByLibrary.simpleMessage(
      "Расход ожидает проверки",
    ),
    "policyValiditySeconds": MessageLookupByLibrary.simpleMessage(
      "Срок действия измерения (сек.)",
    ),
    "policyViewChanges": MessageLookupByLibrary.simpleMessage(
      "Просмотреть изменения",
    ),
    "policyWebsite": MessageLookupByLibrary.simpleMessage("Сайт"),
    "policyWeekdays": MessageLookupByLibrary.simpleMessage(
      "Дни (1=понедельник, 7=воскресенье)",
    ),
    "policyWorkbenchTitle": MessageLookupByLibrary.simpleMessage(
      "Локальные политики",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Порт"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Введите другой порт",
    ),
    "portTip": m27,
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Приоритетное использование HTTP/3 для DOH",
    ),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prerequisites"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, нажмите клавишу.",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Предпросмотр"),
    "process": MessageLookupByLibrary.simpleMessage("процесс"),
    "processRecognitionOff": MessageLookupByLibrary.simpleMessage(
      "Распознавание процессов выключено. Неопознанный трафик приложений будет отнесён к неизвестному.",
    ),
    "processRecognitionUnavailable": MessageLookupByLibrary.simpleMessage(
      "Распознавание процессов включено, но за выбранный период приложения не определены. Ранее записанный неизвестный трафик восстановить нельзя.",
    ),
    "profile": MessageLookupByLibrary.simpleMessage("Профиль"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Пожалуйста, введите действительный формат интервала времени",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Пожалуйста, введите интервал времени для автообновления",
        ),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Профиль был изменен. Хотите отключить автообновление?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите имя профиля",
    ),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите действительный URL профиля",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, введите URL профиля",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Профили"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Сортировка профилей"),
    "project": MessageLookupByLibrary.simpleMessage("Проект"),
    "providers": MessageLookupByLibrary.simpleMessage("Провайдеры"),
    "proxies": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxiesEmpty": MessageLookupByLibrary.simpleMessage("Список прокси пуст"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Цепочки прокси"),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружена аномалия выбранных прокси",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("Фильтр прокси"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Группа прокси"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружена аномалия текущей группы прокси",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Группа прокси пуста",
    ),
    "proxyGroupNameDuplicate": MessageLookupByLibrary.simpleMessage(
      "Имя группы прокси дублируется",
    ),
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "Имя группы прокси не может быть пустым",
    ),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage(
      "Прокси-сервер имен",
    ),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Домен для разрешения прокси-узлов",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("Порт прокси"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Обнаружена аномалия выбранных провайдеров прокси",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Провайдеры прокси"),
    "proxyProvidersEmpty": MessageLookupByLibrary.simpleMessage(
      "Провайдеры прокси пусты",
    ),
    "proxyProvidersNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Провайдеры прокси не могут быть пустыми",
    ),
    "proxyTraffic": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxyType": MessageLookupByLibrary.simpleMessage("Тип прокси"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Очистить кэш"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Чисто черный режим"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR-код"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Сканируйте QR-код для получения профиля",
    ),
    "quickFill": MessageLookupByLibrary.simpleMessage("Быстрое заполнение"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("Радужные"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir-порт"),
    "redo": MessageLookupByLibrary.simpleMessage("Повторить"),
    "remote": MessageLookupByLibrary.simpleMessage("Удаленный"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование локальных данных на WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Удалённое назначение",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Удалить"),
    "rename": MessageLookupByLibrary.simpleMessage("Переименовать"),
    "request": MessageLookupByLibrary.simpleMessage("Запрос"),
    "requests": MessageLookupByLibrary.simpleMessage("Запросы"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage(
      "Просмотр последних записей запросов",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("Сброс"),
    "resetFilters": MessageLookupByLibrary.simpleMessage("Сбросить фильтры"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "На текущей странице есть изменения. Вы уверены, что хотите сбросить?",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Убедитесь, что хотите сбросить",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Ресурсы"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage(
      "Информация, связанная с внешними ресурсами",
    ),
    "respectRules": MessageLookupByLibrary.simpleMessage("Соблюдение правил"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "DNS-соединение следует правилам, необходимо настроить proxy-server-nameserver",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Перезапустить"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите перезапустить ядро?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Восстановить"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Восстановить все данные",
    ),
    "restoreException": MessageLookupByLibrary.simpleMessage(
      "Ошибка восстановления",
    ),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "Восстановить данные из файла",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "Восстановить данные через WebDAV",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Восстановить только файлы конфигурации",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегия восстановления",
    ),
    "restoreStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "Совместимый",
    ),
    "restoreStrategy_override": MessageLookupByLibrary.simpleMessage(
      "Перезаписать",
    ),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Восстановление успешно",
    ),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Адрес маршрутизации"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Настройка адреса прослушивания маршрутизации",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Режим маршрутизации"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Обход частных адресов маршрутизации",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage(
      "Использовать конфигурацию",
    ),
    "ru": MessageLookupByLibrary.simpleMessage("Русский"),
    "rule": MessageLookupByLibrary.simpleMessage("Правило"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить полный домен",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ключевое слово домена",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставление по маске, поддерживает только * и ?",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить суффикс домена",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить метку DSCP (только для tproxy udp inbound)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон портов назначения запроса",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить код страны IP-адреса",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить домены внутри Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить входящее имя",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить входящий порт",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить входящий тип",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить входящее имя пользователя, поддерживает несколько имен через /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ASN IP-адреса",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов (IP-CIDR6 — это просто псевдоним)",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон суффиксов IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить все запросы, условия не требуются",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить TCP или UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило OR",
    ),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по имени процесса, на Android соответствует имени пакета",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению имени процесса, на Android соответствует имени пакета",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по полному пути процесса",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению пути процесса",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Ссылка на набор правил, требуется настройка rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить код страны исходного IP",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ASN исходного IP",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон исходных IP-адресов",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон исходных суффиксов IP",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон портов источника запроса",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить с подправилом, обратите внимание на использование скобок",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить Linux USER ID",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("Правило пусто"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Название правила"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Провайдеры правил"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Набор правил"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Цель правила"),
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Сохранить изменения?"),
    "script": MessageLookupByLibrary.simpleMessage("Скрипт"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Режим скрипта, использование внешних расширяющих скриптов, предоставление возможности переопределения конфигурации одним кликом",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Поиск"),
    "seconds": MessageLookupByLibrary.simpleMessage("Секунд"),
    "secondsCount": m28,
    "selectAll": MessageLookupByLibrary.simpleMessage("Выбрать все"),
    "selectProxies": MessageLookupByLibrary.simpleMessage("Выбрать прокси"),
    "selectProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Выбрать провайдеров прокси",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, выберите набор правил",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, выберите стратегию разделения",
    ),
    "selectSubRule": MessageLookupByLibrary.simpleMessage(
      "Пожалуйста, выберите подправило",
    ),
    "selected": MessageLookupByLibrary.simpleMessage("Выбрано"),
    "selectedCountTitle": m29,
    "settings": MessageLookupByLibrary.simpleMessage("Настройки"),
    "show": MessageLookupByLibrary.simpleMessage("Показать"),
    "shrink": MessageLookupByLibrary.simpleMessage("Сжать"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Тихий запуск"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Запуск в фоновом режиме",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Размер"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks-порт"),
    "sort": MessageLookupByLibrary.simpleMessage("Сортировка"),
    "sortByConnections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "sortByDownload": MessageLookupByLibrary.simpleMessage("Получено"),
    "sortByTotal": MessageLookupByLibrary.simpleMessage("Всего"),
    "sortByUpload": MessageLookupByLibrary.simpleMessage("Отправлено"),
    "source": MessageLookupByLibrary.simpleMessage("Источник"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Исходный IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Специальный прокси"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Специальные правила"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage(
      "Статистика скорости",
    ),
    "splitStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегия разделения",
    ),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Стратегия разделения не может быть пустой",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs is empty"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Режим стека"),
    "standard": MessageLookupByLibrary.simpleMessage("Стандартный"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Стандартный режим, переопределение базовой конфигурации, предоставление возможности простого добавления правил",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Старт"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Запуск VPN..."),
    "status": MessageLookupByLibrary.simpleMessage("Статус"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "Системный DNS будет использоваться при выключении",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Стоп"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Остановка VPN..."),
    "style": MessageLookupByLibrary.simpleMessage("Стиль"),
    "subRule": MessageLookupByLibrary.simpleMessage("Подправило"),
    "subRuleEmpty": MessageLookupByLibrary.simpleMessage("Подправило пусто"),
    "subRuleNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Подправило не может быть пустым",
    ),
    "submit": MessageLookupByLibrary.simpleMessage("Отправить"),
    "suspended": MessageLookupByLibrary.simpleMessage("Приостановлено..."),
    "sync": MessageLookupByLibrary.simpleMessage("Синхронизация"),
    "system": MessageLookupByLibrary.simpleMessage("Система"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Системное приложение"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Прикрепить HTTP-прокси к VpnService",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Вкладка"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Анимация вкладок"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Действительно только в мобильном виде",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "Нажмите, чтобы разрешить",
    ),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP параллелизм"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Включение позволит использовать параллелизм TCP",
    ),
    "testInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал тестирования",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("Тест URL"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage(
      "Тестировать при использовании",
    ),
    "textScale": MessageLookupByLibrary.simpleMessage("Масштабирование текста"),
    "theme": MessageLookupByLibrary.simpleMessage("Тема"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Цвет темы"),
    "themeDesc": MessageLookupByLibrary.simpleMessage(
      "Установить темный режим, настроить цвет",
    ),
    "themeMode": MessageLookupByLibrary.simpleMessage("Режим темы"),
    "tight": MessageLookupByLibrary.simpleMessage("Плотный"),
    "time": MessageLookupByLibrary.simpleMessage("Время"),
    "timeTrend": MessageLookupByLibrary.simpleMessage("Динамика"),
    "timeout": MessageLookupByLibrary.simpleMessage("Таймаут"),
    "tip": MessageLookupByLibrary.simpleMessage("подсказка"),
    "todayProxyUsage": MessageLookupByLibrary.simpleMessage(
      "Прокси-трафик сегодня",
    ),
    "toggle": MessageLookupByLibrary.simpleMessage("Переключить"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("Тональный акцент"),
    "tools": MessageLookupByLibrary.simpleMessage("Инструменты"),
    "topApplications": MessageLookupByLibrary.simpleMessage(
      "Лучшие приложения",
    ),
    "topDomains": MessageLookupByLibrary.simpleMessage("Лучшие домены"),
    "topNodes": MessageLookupByLibrary.simpleMessage("Лучшие узлы"),
    "topProfiles": MessageLookupByLibrary.simpleMessage(
      "Лучшие профили конфигурации",
    ),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy-порт"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage(
      "Использование трафика",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "действительно только в режиме администратора",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Выключить"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Включить"),
    "undo": MessageLookupByLibrary.simpleMessage("Отменить"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage(
      "Унифицированная задержка",
    ),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Убрать дополнительные задержки, такие как рукопожатие",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Неизвестно"),
    "unknownApplication": MessageLookupByLibrary.simpleMessage(
      "Неизвестное приложение",
    ),
    "unknownDomain": MessageLookupByLibrary.simpleMessage(
      "Неизвестный домен или IP",
    ),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Неизвестная сетевая ошибка",
    ),
    "unknownNode": MessageLookupByLibrary.simpleMessage("Неизвестный узел"),
    "unknownProfile": MessageLookupByLibrary.simpleMessage(
      "Неизвестный профиль конфигурации",
    ),
    "unnamed": MessageLookupByLibrary.simpleMessage("Без имени"),
    "update": MessageLookupByLibrary.simpleMessage("Обновить"),
    "upload": MessageLookupByLibrary.simpleMessage("Загрузка"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "Получить профиль через URL",
    ),
    "urlTip": m30,
    "usage": MessageLookupByLibrary.simpleMessage("Расход"),
    "usageApplications": MessageLookupByLibrary.simpleMessage("Приложения"),
    "usageConnections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "usageDegradedIssue": MessageLookupByLibrary.simpleMessage(
      "Очередь ожидающих данных достигла безопасного предела, поэтому детализация была сокращена. Общий объём байтов сохранён, но часть данных по приложениям, доменам, узлам, подпискам или минутам недоступна.",
    ),
    "usageDesc": MessageLookupByLibrary.simpleMessage(
      "Локальный трафик по времени, узлам, приложениям, доменам и профилям",
    ),
    "usageDomains": MessageLookupByLibrary.simpleMessage("Домены"),
    "usageNodes": MessageLookupByLibrary.simpleMessage("Узлы"),
    "usageNotEnabled": MessageLookupByLibrary.simpleMessage(
      "Запись расхода выключена",
    ),
    "usageNotEnabledDesc": MessageLookupByLibrary.simpleMessage(
      "Включите её вручную в настройках приложения. Исторический трафик восстановить невозможно.",
    ),
    "usageOverview": MessageLookupByLibrary.simpleMessage("Обзор"),
    "usagePersistenceIssue": MessageLookupByLibrary.simpleMessage(
      "Не удалось сохранить данные об использовании. Повторная попытка будет выполнена автоматически; не отключайте запись и не выходите из приложения, пока предупреждение не исчезнет.",
    ),
    "usagePrivacyDesc": MessageLookupByLibrary.simpleMessage(
      "FlClash будет локально хранить на этом Mac объём трафика, пути процессов, домены, IP назначения, узлы и снимки профилей. Поминутные данные хранятся 90 дней, не включаются в резервные копии конфигурации или WebDAV и не могут быть восстановлены задним числом. Это локальные измерения, а не платёжные данные.",
    ),
    "usagePrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Включить локальную запись расхода?",
    ),
    "usageProfiles": MessageLookupByLibrary.simpleMessage(
      "Профили конфигурации",
    ),
    "usageProfilesDesc": MessageLookupByLibrary.simpleMessage(
      "Группировка по профилю конфигурации FlClash, активному в момент установления соединения. Это не квота провайдера и не биллинговый трафик.",
    ),
    "usageRecording": MessageLookupByLibrary.simpleMessage("Запись расхода"),
    "usageRecordingDesc": MessageLookupByLibrary.simpleMessage(
      "Хранить на этом Mac поминутную статистику трафика, приложений и доменов в течение 90 дней",
    ),
    "usageToday": MessageLookupByLibrary.simpleMessage("Сегодня"),
    "usageTotal": MessageLookupByLibrary.simpleMessage("Всего"),
    "useHosts": MessageLookupByLibrary.simpleMessage("Использовать hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Использовать системные hosts",
    ),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "value": MessageLookupByLibrary.simpleMessage("Значение"),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("Яркие"),
    "view": MessageLookupByLibrary.simpleMessage("Просмотр"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "Обнаружено изменение конфигурации VPN",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Автоматически направляет весь системный трафик через VpnService",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Изменения вступят в силу после перезапуска VPN",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Конфигурация WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage(
      "Режим белого списка",
    ),
    "yearsAgo": m31,
    "zh_CN": MessageLookupByLibrary.simpleMessage("Упрощенный китайский"),
  };
}
