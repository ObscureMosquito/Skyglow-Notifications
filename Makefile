TARGET := iphone:clang:latest:6.0
INSTALL_TARGET_PROCESSES = SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DiscordClassicNotificationsDaemon
DiscordClassicNotificationsDaemon_FILES = Tweak.x
DiscordClassicNotificationsDaemon_FRAMEWORKS = UIKit SystemConfiguration
DiscordClassicNotificationsDaemon_PRIVATEFRAMEWORKS = SpringBoardServices SpringBoard 
DiscordClassicNotificationsDaemon_LIBRARIES = substrate
DiscordClassicNotificationsDaemon_CFLAGS = -Wno-deprecated-declarations -Wno-objc-method-access -Wno-module-import-in-extern-c -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
