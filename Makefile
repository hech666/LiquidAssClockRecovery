TARGET := iphone:clang:16.5:14.0
ARCHS ?= arm64e
THEOS_PACKAGE_SCHEME ?= roothide
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidAssClock
LiquidAssClock_FILES = Hooks/Clock.x \
                       Shared/LGGlassKit.x \
                       Shared/LGLiveBackdropView.m \
                       Shared/LGSharedSupport.m
LiquidAssClock_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I$(THEOS_PROJECT_DIR)/Shared
LiquidAssClock_FRAMEWORKS = UIKit QuartzCore CoreText CoreGraphics CoreMotion
LiquidAssClock_LIBRARIES = substrate
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
  LiquidAssClock_LIBRARIES += roothide
endif

include $(THEOS_MAKE_PATH)/tweak.mk
