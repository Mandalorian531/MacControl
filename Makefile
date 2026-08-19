.PHONY: build run dmg helper

build:
	./scripts/build.sh

run: build
	open dist/MacControl.app

dmg: build
	./scripts/package-dmg.sh

helper:
	./dist/MacControl.app/Contents/MacOS/smc-helper read
