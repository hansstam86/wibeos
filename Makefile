APP = WibeOS

.PHONY: run build app clean

run:
	swift run -c release

build:
	swift build -c release

app: build
	rm -rf $(APP).app
	mkdir -p $(APP).app/Contents/MacOS $(APP).app/Contents/Resources
	cp .build/release/$(APP) $(APP).app/Contents/MacOS/
	cp -R .build/release/WibeOS_WibeOS.bundle $(APP).app/Contents/Resources/
	cp Info.plist $(APP).app/Contents/
	@echo "Built $(APP).app — open it with: open $(APP).app"

clean:
	rm -rf .build $(APP).app
