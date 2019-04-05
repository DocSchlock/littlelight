package main

import (
	"github.com/go-flutter-desktop/go-flutter"
)
import "github.com/go-flutter-desktop/plugins/path_provider"
import "github.com/go-flutter-desktop/plugins/shared_preferences"

var options = []flutter.Option{
	flutter.WindowInitialDimensions(800, 1280),
	flutter.AddPlugin(&path_provider.PathProviderPlugin{
		VendorName:      "LittleLight",
		ApplicationName: "LittleLight",
	}),
	flutter.AddPlugin(&shared_preferences.SharedPreferencesPlugin{
		VendorName:      "LittleLight",
		ApplicationName: "LittleLight",
	}),
}


