package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type settings struct {
	Version           int  `json:"version"`
	PrivacyMode       bool `json:"privacyMode"`
	RetentionMaxItems int  `json:"retentionMaxItems"`
	DedupeWindow      int  `json:"dedupeWindow"`
}

func defaultSettings() settings {
	return settings{
		Version:           1,
		PrivacyMode:       false,
		RetentionMaxItems: 500,
		DedupeWindow:      50,
	}
}

func settingsPath(dataDir string) string {
	return filepath.Join(dataDir, "config", "settings.json")
}

func loadSettings(dataDir string) (settings, error) {
	p := settingsPath(dataDir)
	b, err := os.ReadFile(p)
	if err != nil {
		if os.IsNotExist(err) {
			return defaultSettings(), nil
		}
		return settings{}, fmt.Errorf("read settings: %w", err)
	}

	var s settings
	if err := json.Unmarshal(b, &s); err != nil {
		return settings{}, fmt.Errorf("parse settings: %w", err)
	}

	// Apply defaults for missing/zero fields
	def := defaultSettings()
	if s.Version == 0 {
		s.Version = def.Version
	}
	if s.RetentionMaxItems <= 0 {
		s.RetentionMaxItems = def.RetentionMaxItems
	}
	if s.DedupeWindow <= 0 {
		s.DedupeWindow = def.DedupeWindow
	}

	return s, nil
}

func saveSettings(dataDir string, s settings) error {
	p := settingsPath(dataDir)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return fmt.Errorf("mkdir settings dir: %w", err)
	}

	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal settings: %w", err)
	}

	// Atomic write
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return fmt.Errorf("write settings tmp: %w", err)
	}
	if err := os.Rename(tmp, p); err != nil {
		return fmt.Errorf("rename settings: %w", err)
	}
	return nil
}
