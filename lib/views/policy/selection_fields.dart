import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

class PolicyMultiSelect extends StatelessWidget {
  const PolicyMultiSelect({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final String label;
  final Map<String, String> options;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    final selected = [...value];
    var query = '';
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: 440,
            height: 380,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: context.appLocalizations.search,
                  ),
                  onChanged: (text) => update(() => query = text.toLowerCase()),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry
                          in {
                            ...options,
                            for (final id in value)
                              if (!options.containsKey(id)) id: id,
                          }.entries.where(
                            (entry) => '${entry.key} ${entry.value}'
                                .toLowerCase()
                                .contains(query),
                          ))
                        CheckboxListTile(
                          value: selected.contains(entry.key),
                          title: Text(entry.value),
                          onChanged: (checked) => update(() {
                            if (checked == true) {
                              selected.add(entry.key);
                            } else {
                              selected.remove(entry.key);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.appLocalizations.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text(context.appLocalizations.confirm),
            ),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: value.isEmpty
            ? Text(context.appLocalizations.policySelectValues)
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final id in value)
                    InputChip(
                      label: Text(options[id] ?? id),
                      onDeleted: enabled
                          ? () => onChanged(
                              value.where((item) => item != id).toList(),
                            )
                          : null,
                    ),
                ],
              ),
      ),
    ),
  );
}

Map<String, String> policyRegionOptions(
  BuildContext context,
  Iterable<String> extra,
) => {
  'CN': context.appLocalizations.policyRegionCN,
  'JP': context.appLocalizations.policyRegionJP,
  'HK': context.appLocalizations.policyRegionHK,
  'TW': context.appLocalizations.policyRegionTW,
  'US': context.appLocalizations.policyRegionUS,
  'SG': context.appLocalizations.policyRegionSG,
  'KR': context.appLocalizations.policyRegionKR,
  'DE': context.appLocalizations.policyRegionDE,
  'GB': context.appLocalizations.policyRegionGB,
  'FR': context.appLocalizations.policyRegionFR,
  'CA': context.appLocalizations.policyRegionCA,
  'AU': context.appLocalizations.policyRegionAU,
  'NL': context.appLocalizations.policyRegionNL,
  'RU': context.appLocalizations.policyRegionRU,
  'IN': context.appLocalizations.policyRegionIN,
  'TH': context.appLocalizations.policyRegionTH,
  'VN': context.appLocalizations.policyRegionVN,
  'MY': context.appLocalizations.policyRegionMY,
  'TR': context.appLocalizations.policyRegionTR,
  'PH': context.appLocalizations.policyRegionPH,
  'ID': context.appLocalizations.policyRegionID,
  'MO': context.appLocalizations.policyRegionMO,
  for (final region in {
    ...'AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW'
        .split(' '),
    ...extra,
  })
    if (!{
      'CN',
      'JP',
      'HK',
      'TW',
      'US',
      'SG',
      'KR',
      'DE',
      'GB',
      'FR',
      'CA',
      'AU',
      'NL',
      'RU',
      'IN',
      'TH',
      'VN',
      'MY',
      'TR',
      'PH',
      'ID',
      'MO',
    }.contains(region))
      region: region,
};
