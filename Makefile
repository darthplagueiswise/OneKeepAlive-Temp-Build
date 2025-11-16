# Configuração do Theos
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BLSbxAutomator
BLSbxAutomator_FILES = bl_sbx_tweak.m
BLSbxAutomator_FRAMEWORKS = Foundation CoreFoundation
BLSbxAutomator_PRIVATE_FRAMEWORKS = MobileCoreServices
BLSbxAutomator_CFLAGS = -fobjc-arc

# Adicionar a biblioteca SQLite3
BLSbxAutomator_LIBRARIES = sqlite3

# Configuração do pacote Debian
include $(THEOS_MAKE_FILES)/tweak.mk

# Adicionar o arquivo de controle
control::
	cp control $(THEOS_STAGING_DIR)/DEBIAN/control
