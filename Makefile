TARGET := iphone:clang:latest:6.0
export TARGET=iphone:clang:6.0
INSTALL_TARGET_PROCESSES = SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DiscordClassicNotificationsDaemon
DiscordClassicNotificationsDaemon_FILES = Tweak.x KeyManager.m CommonDefinitions.m SettingsUtilities.x
DiscordClassicNotificationsDaemon_FRAMEWORKS = UIKit SystemConfiguration Security
DiscordClassicNotificationsDaemon_LIBRARIES = substrate ssl crypto
DiscordClassicNotificationsDaemon_CFLAGS = -Wno-deprecated-declarations -Wno-objc-method-access -Wno-module-import-in-extern-c -Wno-error -I/Users/mauro/Desktop/DiscordClassicNotificationDaemon/openssl-ios-dist/include
DiscordClassicNotificationsDaemon_LDFLAGS = -L/Users/mauro/Desktop/DiscordClassicNotificationDaemon/openssl-ios-dist/lib

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += skyglownotificationsdaemonpreferences
include $(THEOS_MAKE_PATH)/aggregate.mk
