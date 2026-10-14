package main

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

func TestDartCompiledLocalPolicySchemaThree(t *testing.T) {
	data, err := os.ReadFile("testdata/local_policy_v3_compiled.yaml")
	if err != nil {
		t.Fatal(err)
	}
	local, err := parseLocalPolicyConfig(data)
	if err != nil {
		t.Fatal(err)
	}
	if local.SchemaVersion != 3 || local.TargetID != "integration:flclash_local" || len(local.Policies) != 3 || len(local.NodeSets) != 1 {
		t.Fatal("compiled standalone contract changed")
	}
	if local.Policies[0].ID != "first" || local.Policies[1].ID != "second" || local.Policies[2].ID != "last" {
		t.Fatal("compiled rule order changed")
	}
	var raw map[string]any
	if err := yaml.Unmarshal(data, &raw); err != nil {
		t.Fatal(err)
	}
	var rules struct {
		Rules []string `yaml:"rules"`
	}
	if err := yaml.Unmarshal(data, &rules); err != nil {
		t.Fatal(err)
	}
	expected := []string{
		"DOMAIN-SUFFIX,example.test," + local.Policies[0].GroupName,
		"DOMAIN-SUFFIX,example.test," + local.Policies[1].GroupName,
		"MATCH," + local.Policies[2].GroupName,
		"MATCH,REJECT",
	}
	if !reflect.DeepEqual(rules.Rules, expected) {
		t.Fatal("flow matching order differs from the compiled policy order")
	}
	path := filepath.Join(t.TempDir(), "compiled.yaml")
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	prior := activeLocalPolicy.Load()
	if result := handleValidateConfig(path); result != "" {
		t.Fatal(result)
	}
	if activeLocalPolicy.Load() != prior {
		t.Fatal("read-only validation changed the live engine")
	}
	extension := raw["flclash-local-policy"].(map[string]any)
	policies := extension["policies"].([]any)
	policies[0].(map[string]any)["priority"] = 10
	invalid, err := yaml.Marshal(raw)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := parseLocalPolicyConfig(invalid); err == nil || !strings.Contains(err.Error(), "field priority not found") {
		t.Fatal("persistent UI fields must remain outside the strict Core wire schema", err)
	}
}
