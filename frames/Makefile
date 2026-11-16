# Builds the HyprPunk.Frames QML plugin into build/<Qt version>, so a new Qt gets a fresh
# build. install.sh installs it with the qmldir into Qt's QML folder.
#   make           builds the plugin
#   make install   copies it into $(DESTDIR)/usr/lib/qt6/qml/HyprPunk/Frames
#   make clean     removes every build

QT_MODULES := Qt6Quick Qt6Qml Qt6Gui Qt6Core
QT_VERSION := $(shell pkg-config --modversion Qt6Core)
BUILD := build/$(QT_VERSION)
TARGET := $(BUILD)/libhyprpunkframes.so
QML_DIR := $(DESTDIR)$(shell pkg-config --variable=prefix Qt6Core)/lib/qt6/qml/HyprPunk/Frames
MOC := $(shell pkg-config --variable=libexecdir Qt6Core)/moc

# Qt's private headers live under its version: the driver reaches Qt's render loop
PRIVATE := $(foreach m,QtCore QtGui QtQml QtQuick,-I/usr/include/qt6/$(m)/$(QT_VERSION) -I/usr/include/qt6/$(m)/$(QT_VERSION)/$(m))
CXXFLAGS := -std=c++20 -O2 -fPIC -Wall -Wextra $(shell pkg-config --cflags $(QT_MODULES)) $(PRIVATE) -I$(BUILD)
LDLIBS := $(shell pkg-config --libs $(QT_MODULES))

$(TARGET): framedriver.cpp framedriver.h plugin.cpp $(BUILD)/plugin.moc
	$(CXX) $(CXXFLAGS) -shared -o $@ framedriver.cpp plugin.cpp $(LDLIBS)

$(BUILD)/plugin.moc: plugin.cpp
	@mkdir -p $(BUILD)
	$(MOC) $(shell pkg-config --cflags-only-I $(QT_MODULES)) $< -o $@

install: $(TARGET)
	install -Dm755 $(TARGET) $(QML_DIR)/libhyprpunkframes.so
	install -Dm644 qmldir $(QML_DIR)/qmldir

clean:
	rm -rf build

.PHONY: install clean
