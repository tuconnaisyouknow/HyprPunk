# Builds xwayland-satellite, which runs the X11 apps, with HyprPunk's patch: an X11 app
# can't resize a window the compositor maximized or made fullscreen (size-requests.patch).
# install.sh installs it in /usr/local/bin, ahead of any packaged one.
#   make           fetches the version below, patches and builds it
#   make install   copies it into $(DESTDIR)/usr/local/bin
#   make clean     removes the build

VERSION := 0.8.3
SRC := build/xwayland-satellite-$(VERSION)
TARGET := $(SRC)/target/release/xwayland-satellite

$(TARGET): size-requests.patch
	rm -rf $(SRC)
	git clone --quiet --depth 1 --branch v$(VERSION) https://github.com/Supreeeme/xwayland-satellite.git $(SRC)
	patch --quiet -d $(SRC) -p1 < size-requests.patch
	cargo build --release --locked --manifest-path $(SRC)/Cargo.toml

install: $(TARGET)
	install -Dm755 $(TARGET) $(DESTDIR)/usr/local/bin/xwayland-satellite

clean:
	rm -rf build

.PHONY: install clean
