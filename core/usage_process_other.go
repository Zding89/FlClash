//go:build !darwin

package main

func newUsageProcessResolver() usageProcessResolver {
	return nil
}
