include $(THEOS)/makefiles/common.mk
TWEAK_NAME = LiquidAssBackboardd
LiquidAssBackboardd_FILES = Tweak.mm LGSymbolResolver.mm
LiquidAssBackboardd_CFLAGS = -fobjc-arc -std=c++17 -fno-objc-arc-exceptions -I$(THEOS_PROJECT_DIR)/Shared
LiquidAssBackboardd_FRAMEWORKS = Metal QuartzCore CoreFoundation
LiquidAssBackboardd_LDFLAGS = -lc++
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
LiquidAssBackboardd_LIBRARIES += roothide
endif
include $(THEOS_MAKE_PATH)/tweak.mk
