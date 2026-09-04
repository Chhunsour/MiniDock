.PHONY: all build install run clean restore

all: build

build:
	@./Scripts/build_app.sh

install:
	@./Scripts/install.sh

run:
	@./Scripts/minidock enable

stop:
	@./Scripts/minidock disable

status:
	@./Scripts/minidock status

restore:
	@./Scripts/restore_apple_dock.sh

clean:
	@rm -rf .build MiniDock.app
