import 'package:collection/collection.dart';
import 'package:fl_clash/policy/models.dart';

final class AgentPolicyContract {
  static Map<String, Object?> _object(
    Map<String, Object?> properties, {
    List<String> required = const [],
    String? description,
  }) => {
    'type': 'object',
    'properties': properties,
    'required': required,
    'additionalProperties': false,
    'description': ?description,
  };

  static Map<String, Object?> _string([int maximum = 1024]) => {
    'type': 'string',
    'maxLength': maximum,
  };

  static Map<String, Object?> _integer(int minimum, int maximum) => {
    'type': 'integer',
    'minimum': minimum,
    'maximum': maximum,
  };

  static Map<String, Object?> _enum(Iterable<Enum> values) => {
    'type': 'string',
    'enum': values.map((value) => value.name).toList(),
  };

  static Map<String, Object?> _array(Map<String, Object?> items, int maximum) =>
      {'type': 'array', 'items': items, 'maxItems': maximum};

  static const _boolean = {'type': 'boolean'};
  static const _maximum = 9007199254740991;
  static Map<String, Object?> get _identity => {
    ..._string(128),
    'minLength': 1,
    'pattern': r'^[A-Za-z0-9_-]+$',
  };
  static Map<String, Object?> get _target => {
    ..._string(128),
    'enum': [localPolicyTargetId],
    'description':
        'Independent local target; never a subscription profile or proxy-group name.',
  };
  static Map<String, Object?> get _region => {
    ..._string(2),
    'pattern': r'^[A-Z]{2}$',
  };
  static Map<String, Object?> get _multiplier => {
    'type': ['number', 'null'],
    'exclusiveMinimum': 0,
    'maximum': 1000,
  };

  static Map<String, Object?> _match([int depth = 0]) => _object(
    {
      'type': _enum(PolicyMatchType.values),
      'values': _array(_string(), 50),
      'children': _array(
        depth < 6 ? _match(depth + 1) : _object({}),
        depth < 6 ? 20 : 0,
      ),
    },
    description:
        'global: no values/children and matches remaining traffic; group: exactly one existing group name, compatibility only. domain/domainSuffix/domainKeyword/processName/processPath/processPathRegex/destinationRegion/ipCidr/ipCidr6: nonempty values, no children. destinationRegion uses ISO codes or !ISO; domains have no scheme/path. processPathRegex only accepts installed application bundle paths. all/any: >=2 children; not: exactly 1 child; no values. Nested global/group are forbidden; maximum depth 6.',
  );

  static Map<String, Object?> get _probe => _object(
    {
      'url': _string(),
      'intervalSeconds': _integer(5, 3600),
      'timeoutSeconds': _integer(1, 30),
      'failureThreshold': _integer(1, 20),
      'successThreshold': _integer(1, 20),
      'expectedStatus': _string(32),
      'method': {
        'type': 'string',
        'enum': ['HEAD', 'GET'],
      },
      'automatic': _boolean,
      'retrySeconds': _integer(5, 86400),
      'validitySeconds': _integer(5, 86400),
    },
    description:
        'HTTP(S) URL without user info. timeoutSeconds must be below intervalSeconds; validitySeconds must be at least intervalSeconds. expectedStatus is a single HTTP status 100-599 or ascending range, for example 200-399.',
  );

  static Map<String, Object?> get _schedule => _object({
    'timeZone': {
      'type': 'string',
      'enum': ['Asia/Shanghai', 'UTC'],
    },
    'windows': _array(
      _object(
        {
          'weekdays': {
            ..._array(_integer(1, 7), 7),
            'minItems': 1,
            'uniqueItems': true,
          },
          'startMinute': _integer(0, 1439),
          'endMinute': _integer(0, 1440),
        },
        description:
            'Start and end must differ; crossing midnight is supported.',
      ),
      20,
    ),
  });

  static Map<String, Object?> get _policy => _object(
    {
      'id': _identity,
      'label': _string(200),
      'targetId': _target,
      'enabled': _boolean,
      'priority': {
        ..._integer(0, 1000000),
        'description':
            'Lower values match first. New AI policies append after existing rules and priorities are normalized; update existing priorities together to reorder without collisions.',
      },
      'scope': _match(),
      'action': _enum(PolicyAction.values),
      'candidateNodeIds': {
        ..._array(_string(), 10),
        'uniqueItems': true,
        'description':
            'Persisted compatibility field only. Do not set candidateNodeIds when creating or editing rules; preserve existing omitted values and use choices for current rules. Mutually exclusive with choices; only proxy actions may have candidates.',
      },
      'choices': {
        ..._array(
          _object(
            {'type': _enum(PolicyChoiceType.values), 'id': _string(256)},
            required: ['type', 'id'],
          ),
          10,
        ),
        'uniqueItems': true,
        'description':
            'Selection references: node IDs from nodes_list or stable nodeSet IDs from policies_read. Default to one existing nodeSet reference sharing targetId. Proxy requires nonempty choices or an existing legacy candidate list; direct/reject require both empty.',
      },
      'origin': {
        ..._enum(PolicyOrigin.values),
        'description':
            'New AI rules are always ai; existing origin is preserved.',
      },
      'userModified': _boolean,
      'probe': _probe,
      'guard': _object({
        'expiryMarginSeconds': _integer(0, 31536000),
        'minRemainingBytes': _integer(0, _maximum),
        'metadataMaxAgeSeconds': _integer(60, 2592000),
        'unknownBehavior': _enum(PolicyUnknownBehavior.values),
      }),
      'schedule': _schedule,
      'recoverySeconds': _integer(0, 86400),
      'cooldownSeconds': _integer(0, 3600),
      'autoRecover': _boolean,
      'fallback': {
        ..._enum(PolicyFallback.values),
        'description':
            'Persisted compatibility field only. Do not set fallback when creating or editing rules; preserve existing omitted values.',
      },
      'terminateConnectionsOnExclusion': _boolean,
    },
    required: ['id'],
    description:
        'Merge by stable id. New rules additionally require label and targetId. Omitted fields on existing rules are preserved; arrays replace that field. Use the same id for further edits, including draft edits.',
  );

  static Map<String, Object?> get _nodeSet => _object(
    {
      'id': _identity,
      'label': _string(200),
      'targetId': _target,
      'sourceIds': {
        ..._array({..._string(), 'pattern': r'^[1-9][0-9]*$'}, 20),
        'minItems': 1,
        'uniqueItems': true,
      },
      'regions': {..._array(_region, 250), 'uniqueItems': true},
      'excludedSourceIds': {
        ..._array({..._string(), 'pattern': r'^[1-9][0-9]*$'}, 20),
        'uniqueItems': true,
      },
      'excludedRegions': {..._array(_region, 250), 'uniqueItems': true},
      'nameIncludes': {..._array(_string(200), 20), 'uniqueItems': true},
      'nameExcludes': {..._array(_string(200), 20), 'uniqueItems': true},
      'preferences': {
        ..._array(
          _object(
            {
              'type': _enum(NodePreferenceType.values),
              'direction': _enum(SortDirection.values),
            },
            required: ['type', 'direction'],
          ),
          5,
        ),
        'description': 'Ordered sort criteria, each type at most once.',
      },
      'selectionMode': _enum(NodeSelectionMode.values),
      'balanceStrategy': _enum(NodeBalanceStrategy.values),
      'schedule': _schedule,
      'maxMultiplier': _multiplier,
      'unknownMultiplier': _enum(UnknownMultiplier.values),
      'allowUnknownRegion': _boolean,
      'strategy': _enum(NodeSetStrategy.values),
      'hideUnavailable': _boolean,
      'probe': _probe,
      'recoverySeconds': _integer(0, 86400),
      'cooldownSeconds': _integer(0, 3600),
      'improvementPercent': _integer(1, 100),
    },
    required: ['id'],
    description:
        'Dynamic local node set, distinct from subscription proxy groups. New sets need label, targetId and nonempty sourceIds. Reuse existing HK/US/low-multiplier sets by id; no profile selection is needed to create rules.',
  );

  static Map<String, Object?> get patchSchema => _object(
    {
      'moduleEnabled': _boolean,
      'policiesEnabled': _boolean,
      'integrationEnabled': _boolean,
      'budgetsEnabled': _boolean,
      'sourceUpdateRoute': _enum(SourceUpdateRoute.values),
      'activeIntegrationId': {
        'type': 'string',
        'enum': [localPolicyProfileId],
      },
      'nodeSets': _array(_nodeSet, 100),
      'policies': _array(_policy, 100),
      'nodeAttributes': {
        'type': 'object',
        'maxProperties': 5000,
        'additionalProperties': _object(
          {
            'region': {
              'type': ['string', 'null'],
              'pattern': r'^[A-Z]{2}$',
            },
            'multiplier': _multiplier,
            'regionBasis': _enum(NodeAttributeBasis.values),
            'multiplierBasis': _enum(NodeAttributeBasis.values),
          },
          description:
              'Keys are stable node IDs. Non-null values require a non-unknown basis; null values require unknown basis.',
        ),
      },
      'integrations': _array(
        _object(
          {
            'id': {
              'type': 'string',
              'enum': [localPolicyProfileId],
            },
            'label': _string(200),
            'sourceProfileIds': {
              ..._array({
                'type': ['string', 'integer'],
                'minimum': 1,
                'maxLength': 19,
              }, 20),
              'uniqueItems': true,
            },
            'nameFilter': {
              'type': ['string', 'null'],
              'maxLength': 200,
            },
            'excludedNodeIds': _array(_string(), 5000),
            'fallback': {
              'type': 'string',
              'enum': ['reject'],
              'description':
                  'Fixed safe default for the independent local configuration. Do not set this compatibility field when creating or editing.',
            },
          },
          required: ['id'],
        ),
        20,
      ),
      'budgets': _array(
        _object(
          {
            'sourceId': _string(128),
            'limitBytes': _integer(1, _maximum),
            'resetDay': _integer(1, 28),
            'timeZone': {
              'type': 'string',
              'enum': ['Asia/Shanghai', 'UTC'],
            },
          },
          required: ['sourceId'],
        ),
        20,
      ),
      'overrides': _array(
        _object(
          {
            'policyId': _string(128),
            'nodeId': _string(256),
            'nodeSetId': {
              'type': ['string', 'null'],
              'maxLength': 128,
            },
            'expiresAt': _integer(1, _maximum),
          },
          required: ['policyId'],
        ),
        100,
      ),
    },
    description:
        'Merge local definitions by id (budgets by sourceId, overrides by policyId). Arrays inside a definition replace that field. No source configuration or credentials are accepted. The complete resulting document is validated locally before saving a draft.',
  );

  static Map<String, Object?> describe(LocalPolicyDocument document) {
    final local = document.asStandalone();
    final set = local.nodeSets.firstOrNull;
    return {
      'targetId': localPolicyTargetId,
      'integrationId': localPolicyProfileId,
      'semantics': {
        'independentLocalConfiguration': true,
        'subscriptionProfileSelectionRequired': false,
        'nodeSetsAreSubscriptionProxyGroups': false,
        'emptyPoliciesMeans':
            'No local rules exist yet; existing nodeSets can still be referenced to draft the first local rule.',
        'ruleTools':
            'rules_read/rule_propose/groups_read/group_propose manage subscription appended/custom rules and groups only, not independent local rules or nodeSets.',
        'ordering':
            'Policies match by ascending priority; new AI rules append after existing rules. choices are selection references; default to one existing nodeSet. Node-set preferences are ordered sort criteria.',
        'compatibilityFields':
            'candidateNodeIds and fallback are persisted compatibility fields. Do not set them when creating or editing rules; preserve existing omitted values. Integration fallback is the fixed safe reject default.',
        'drafts':
            'Use policies_propose to save a draft, policies_draft_read to inspect it, then policies_propose with draftId and the same stable rule IDs for edits. Only changes_commit can request local approval and apply.',
      },
      'availableNodeSets': local.nodeSets
          .map(
            (value) => {
              'id': value.id,
              'label': value.label,
              'targetId': value.targetId,
            },
          )
          .toList(),
      'examples': [
        {
          'name': 'Draft an independent local domain rule',
          'tool': 'policies_propose',
          'arguments': {
            'patch': {
              'policies': [
                {
                  'id': 'ai_example_domain',
                  'label': 'Example domain',
                  'targetId': localPolicyTargetId,
                  'scope': {
                    'type': 'domainSuffix',
                    'values': ['example.com'],
                  },
                  if (set != null)
                    'choices': [
                      {'type': 'nodeSet', 'id': set.id},
                    ]
                  else
                    'action': 'direct',
                },
              ],
            },
          },
        },
      ],
    };
  }
}
