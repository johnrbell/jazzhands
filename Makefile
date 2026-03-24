.PHONY: build run clean xcode

build:
	swift build

run:
	swift build && .build/debug/Orbit

clean:
	swift package clean
	rm -rf .build

xcode:
	open Orbit.xcodeproj
