DERIVED_DATA ?= .build/DerivedData
CONFIGURATION ?= Release

.PHONY: build install-cli doctor

build:
	xcodebuild -project Aeroxy.xcodeproj -scheme Aeroxy -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

install-cli: build
	Scripts/install-cli.sh

doctor:
	$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/aeroxy --json doctor
