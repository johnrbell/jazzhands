.PHONY: build run clean xcode

build:
	swift build

run:
	swift build && .build/debug/JazzHands

clean:
	swift package clean
	rm -rf .build

xcode:
	open JazzHands.xcodeproj
