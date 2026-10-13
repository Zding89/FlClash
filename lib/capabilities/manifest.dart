import 'package:fl_clash/ai/runtime.dart';

class ApplicationCapability {
  const ApplicationCapability({
    required this.command,
    required this.domain,
    required this.description,
    this.mutating = false,
    this.parameters = const {
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
      'additionalProperties': false,
    },
  });
  final String command;
  final String domain;
  final String description;
  final bool mutating;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => {
    'command': command,
    'domain': domain,
    'description': description,
    'parameters': parameters,
    'platforms': ['macos'],
    'risk': mutating ? 'requires_confirmation' : 'read',
    'completion': 'operation_query',
    'idempotency': mutating,
  };

  AgentToolDefinition get tool => AgentToolDefinition(
    name: command,
    description: description,
    parameters: parameters,
  );
}

const capabilityString = {'type': 'string', 'maxLength': 4096};
const capabilityId = {'type': 'string', 'maxLength': 96};
const capabilityInteger = {'type': 'integer', 'minimum': 0};
const capabilityBoolean = {'type': 'boolean'};

Map<String, Object?> capabilitySchema(
  Map<String, Object?> properties, [
  List<String> required = const [],
]) => {
  'type': 'object',
  'properties': properties,
  'required': required,
  'additionalProperties': false,
};

ApplicationCapability _cap(
  String command,
  String domain,
  String description, {
  bool mutating = false,
  Map<String, Object?> properties = const {},
  List<String> required = const [],
}) => ApplicationCapability(
  command: command,
  domain: domain,
  description: description,
  mutating: mutating,
  parameters: capabilitySchema(properties, required),
);

final applicationCapabilities = <ApplicationCapability>[
  _cap(
    'capabilities_list',
    'operations',
    'Discover typed capability schemas, platform limits and approval/completion contracts.',
  ),
  _cap(
    'profile_select',
    'profiles',
    'Select a subscription or local collection through the latest-intent target owner.',
    mutating: true,
    properties: {
      'profileId': capabilityString,
      'integrationId': capabilityString,
      'moduleEnabled': capabilityBoolean,
    },
  ),
  _cap(
    'local_policy_details',
    'policies',
    'Read a bounded page of actual policy or node-set members for the specified runtime revision.',
    properties: {
      'revision': capabilityInteger,
      'policyId': {'type': 'string', 'minLength': 1, 'maxLength': 128},
      'nodeSetId': {'type': 'string', 'minLength': 1, 'maxLength': 128},
      'offset': {'type': 'integer', 'minimum': 0, 'maximum': 5000},
      'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
      'includeUnavailable': capabilityBoolean,
    },
    required: ['revision'],
  ),
  _cap(
    'policy_nodes_check',
    'policies',
    'Request a shared Core node-set check; checks stay deduplicated and bounded.',
    properties: {'revision': capabilityInteger, 'nodeSetId': capabilityId},
    required: ['revision', 'nodeSetId'],
  ),
  for (final action in ['state', 'cancel'])
    _cap(
      'policy_nodes_$action',
      'policies',
      'Read or cancel only the specified shared-check operation.',
      properties: {'revision': capabilityInteger, 'operationId': capabilityId},
      required: ['revision', 'operationId'],
    ),
  _cap(
    'runtime_read',
    'lifecycle',
    'Read actual Core, listener, traffic and memory state.',
  ),
  _cap(
    'connection_set',
    'lifecycle',
    'Start or stop the current connection using application lifecycle actions.',
    mutating: true,
    properties: {'running': capabilityBoolean},
    required: ['running'],
  ),
  _cap(
    'core_restart',
    'lifecycle',
    'Restart the owned Core and reapply the current configuration.',
    mutating: true,
  ),
  for (final action in ['show', 'hide', 'exit'])
    _cap(
      'app_$action',
      'window',
      '$action the application using its existing window/exit owner.',
      mutating: true,
    ),
  _cap(
    'proxies_read',
    'proxies',
    'Read running proxy groups, current selections and node identities.',
  ),
  _cap(
    'proxy_select',
    'proxies',
    'Select a real member of a currently running selectable group.',
    mutating: true,
    properties: {'group': capabilityString, 'node': capabilityString},
    required: ['group', 'node'],
  ),
  _cap(
    'proxy_test',
    'proxies',
    'Measure a real node or group request latency; operation results remain queryable.',
    mutating: true,
    properties: {'group': capabilityString, 'node': capabilityString},
  ),
  _cap(
    'providers_read',
    'resources',
    'Discover actual provider names and safe resource update status.',
  ),
  _cap(
    'policies_runtime',
    'policies',
    'Read actual policy selection, source restrictions, checks and budget ledger status.',
  ),
  _cap(
    'network_status',
    'network',
    'Read TUN authorization and observed system proxy application results.',
  ),
  _cap(
    'ip_detect',
    'dashboard',
    'Request actual outbound and local IP detection.',
    mutating: true,
  ),
  _cap(
    'connections_read',
    'diagnostics',
    'Read bounded active connection records.',
    properties: {
      'offset': capabilityInteger,
      'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
      'id': capabilityString,
    },
  ),
  _cap(
    'connection_close',
    'diagnostics',
    'Close a specified active connection or all connections.',
    mutating: true,
    properties: {'id': capabilityString, 'all': capabilityBoolean},
  ),
  for (final kind in ['logs', 'requests'])
    _cap(
      '${kind}_read',
      'diagnostics',
      'Read bounded filtered $kind records with credentials removed.',
      properties: {
        'search': capabilityString,
        'offset': capabilityInteger,
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
      },
    ),
  _cap(
    'usage_history',
    'usage',
    'Read historical usage for a specified range and dimension, with data quality.',
    properties: {
      'start': capabilityInteger,
      'end': capabilityInteger,
      'scope': {
        'type': 'string',
        'enum': ['proxy', 'all', 'direct'],
      },
      'dimension': {
        'type': 'string',
        'enum': ['overview', 'node', 'application', 'domain', 'profile'],
      },
      'search': capabilityString,
      'offset': capabilityInteger,
      'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
    },
    required: ['start', 'end'],
  ),
  _cap(
    'version_read',
    'maintenance',
    'Read installed application and Core version.',
  ),
  _cap(
    'update_check',
    'maintenance',
    'Check the configured application release feed.',
  ),
  _cap(
    'hotkeys_status',
    'appearance',
    'Read configured shortcuts and actual registration callback status.',
  ),
  _cap(
    'profile_qr_import',
    'profiles',
    'Use the trusted local image picker to read a QR subscription URL and create a validated import proposal; completion remains queryable.',
  ),
  _cap(
    'profiles_refresh_all',
    'profiles',
    'Create bounded individual refresh proposals for all URL subscriptions.',
  ),
  _cap(
    'profiles_reorder',
    'profiles',
    'Reorder all profiles by stable IDs.',
    mutating: true,
    properties: {
      'ids': {'type': 'array', 'items': capabilityString, 'maxItems': 500},
    },
    required: ['ids'],
  ),
  _cap(
    'file_grant',
    'files',
    'Grant a specific local input/output file. Agent origin requires local file selection; CLI supplies an explicit absolute path.',
    mutating: true,
    properties: {
      'path': capabilityString,
      'mode': {
        'type': 'string',
        'enum': ['read', 'write'],
      },
    },
    required: ['mode'],
  ),
  for (final kind in [
    'profile',
    'profile_effective',
    'script',
    'logs',
    'usage',
  ])
    _cap(
      '${kind}_export',
      kind == 'script' ? 'scripts' : 'files',
      'Export protected $kind data to an explicitly granted local output file; never return raw content to the model.',
      mutating: true,
      properties: {
        'fileGrantId': capabilityId,
        'id': capabilityString,
        'start': capabilityInteger,
        'end': capabilityInteger,
      },
      required: ['fileGrantId'],
    ),
  _cap(
    'profile_file_propose',
    'profiles',
    'Propose replacing or importing a profile from a locally granted file.',
    properties: {
      'fileGrantId': capabilityId,
      'profileId': capabilityString,
      'label': capabilityString,
    },
    required: ['fileGrantId'],
  ),
  _cap(
    'source_repair_propose',
    'recovery',
    'Propose repairing only a missing source proven to be referenced by the blocked recovery record and current policy snapshot, using a locally granted input file. Preparation does not switch or activate the target.',
    properties: {
      'recoveryId': capabilityId,
      'profileId': capabilityString,
      'fileGrantId': capabilityId,
      'label': capabilityString,
    },
    required: ['recoveryId', 'profileId', 'fileGrantId'],
  ),
  _cap(
    'script_patch',
    'scripts',
    'Propose a unique exact replacement in existing protected script content, retaining script execution approval.',
    properties: {
      'scriptId': capabilityString,
      'find': capabilityString,
      'replace': capabilityString,
    },
    required: ['scriptId', 'find', 'replace'],
  ),
  _cap(
    'backup_create',
    'backup',
    'Create a real local backup in a granted output file.',
    mutating: true,
    properties: {'fileGrantId': capabilityId},
    required: ['fileGrantId'],
  ),
  _cap(
    'backup_restore',
    'backup',
    'Restore a granted local backup through existing restore validation.',
    mutating: true,
    properties: {
      'fileGrantId': capabilityId,
      'option': {
        'type': 'string',
        'enum': ['all', 'onlyProfiles'],
      },
    },
    required: ['fileGrantId', 'option'],
  ),
  _cap(
    'webdav_upload',
    'backup',
    'Upload an actual backup to the configured WebDAV target after explicit outward-transfer confirmation.',
    mutating: true,
  ),
  _cap(
    'webdav_restore',
    'backup',
    'Download and restore the configured WebDAV backup.',
    mutating: true,
    properties: {
      'option': {
        'type': 'string',
        'enum': ['all', 'onlyProfiles'],
      },
    },
    required: ['option'],
  ),
  _cap(
    'agent_settings_read',
    'agent',
    'Read safe AI connection settings and whether credentials exist, never credential text.',
  ),
  _cap(
    'agent_settings_propose',
    'agent',
    'Propose typed AI settings changes without API keys or CLI password.',
    properties: {
      'settings': {'type': 'object'},
    },
    required: ['settings'],
  ),
  _cap(
    'credentials_panel',
    'agent',
    'Open trusted local credential management and track completion or cancellation.',
    properties: {
      'kind': {
        'type': 'string',
        'enum': ['ai', 'cli'],
      },
    },
    required: ['kind'],
  ),
  _cap(
    'maintenance_clear_cache',
    'maintenance',
    'Remove only application-owned stale profile cache through its scoped cleanup action.',
    mutating: true,
  ),
  _cap(
    'maintenance_clear_data',
    'maintenance',
    'Clear application data and exit, preserving existing explicit destructive-operation approval.',
    mutating: true,
  ),
  _cap(
    'developer_test',
    'developer',
    'Run a specific existing developer diagnostic after developer-mode and operation approval.',
    mutating: true,
    properties: {
      'kind': {
        'type': 'string',
        'enum': ['notification', 'logs', 'core_crash'],
      },
    },
    required: ['kind'],
  ),
  _cap(
    'platform_tool',
    'platform',
    'Report the accurate unsupported Windows loopback or Android app-control boundary on macOS.',
    properties: {
      'kind': {
        'type': 'string',
        'enum': ['windows_loopback', 'android_access'],
      },
    },
    required: ['kind'],
  ),
  _cap(
    'operation_query',
    'operations',
    'Read durable operation status after retries, disconnect or application restart.',
    properties: {'operationId': capabilityId},
    required: ['operationId'],
  ),
  _cap(
    'operation_cancel',
    'operations',
    'Cancel a pending approval or manual operation; never interrupt a started persistence transaction.',
    properties: {'operationId': capabilityId},
    required: ['operationId'],
  ),
  _cap(
    'capability_confirm',
    'operations',
    'Confirm exactly the previously previewed operation, bound to content digest and configuration version.',
    properties: {
      'operationId': capabilityId,
      'digest': capabilityId,
      'version': capabilityId,
    },
    required: ['operationId', 'digest', 'version'],
  ),
];
