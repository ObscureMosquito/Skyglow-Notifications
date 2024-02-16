TARGET := iphone:clang:latest:6.0
export TARGET=iphone:clang:6.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SkyglowNotificationsDaemonPreferences

SkyglowNotificationsDaemonPreferences_FILES = SNRootListController.m SNGuideViewController.m
SkyglowNotificationsDaemonPreferences_FRAMEWORKS = UIKit
SkyglowNotificationsDaemonPreferences_PRIVATE_FRAMEWORKS = Preferences
SkyglowNotificationsDaemonPreferences_INSTALL_PATH = /Library/PreferenceBundles
SkyglowNotificationsDaemonPreferences_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
