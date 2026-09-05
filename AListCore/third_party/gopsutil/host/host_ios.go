//go:build ios

package host

// PlatformInformation returns a conservative iOS-safe description.
func PlatformInformation() (platform, family, version string, err error) {
	return "iOS", "", "", nil
}

func KernelVersion() (string, error) { return "", nil }
func KernelArch() (string, error) { return "arm64", nil }
