################################################################################
#
# openpower_pnor
#
################################################################################

# remove the quotes from the XML/Targeting package as
# make doesn't care for quotes in the dependencies.
XML_PACKAGE=$(subst $\",,$(BR2_OPENPOWER_XML_PACKAGE))

OPENPOWER_PNOR_VERSION ?= afd3c076c5cfe3de38c75fbd230106e3e2d2906c
OPENPOWER_PNOR_SITE ?= $(call github,bofferdn,pnor,$(OPENPOWER_PNOR_VERSION))

OPENPOWER_PNOR_LICENSE = Apache-2.0
OPENPOWER_PNOR_DEPENDENCIES = hostboot hostboot-binaries $(XML_PACKAGE) skiboot host-openpower-ffs occ capp-ucode

ifeq ($(BR2_PACKAGE_SKIBOOT_EMBED_PAYLOAD),n)

ifeq ($(BR2_TARGET_ROOTFS_INITRAMFS),y)
OPENPOWER_PNOR_DEPENDENCIES += linux-rebuild-with-initramfs
else
OPENPOWER_PNOR_DEPENDENCIES += linux
endif

endif

ifeq ($(BR2_OPENPOWER_PNOR_XZ_ENABLED),y)
OPENPOWER_PNOR_DEPENDENCIES += host-xz
XZ_ARG=-xz_compression
endif

ifeq ($(BR2_OPENPOWER_SECUREBOOT_ENABLED),y)
OPENPOWER_PNOR_DEPENDENCIES += host-sb-signing-utils
SECUREBOOT_ARG =-secureboot
endif

ifneq ($(BR2_OPENPOWER_SECUREBOOT_KEY_TRANSITION),"")
KEY_TRANSITION_ARG=-key_transition $(BR2_OPENPOWER_SECUREBOOT_KEY_TRANSITION)
endif

ifneq ($(BR2_OPENPOWER_SECUREBOOT_SIGN_MODE),"")
SIGN_MODE_ARG=-sign_mode $(BR2_OPENPOWER_SECUREBOOT_SIGN_MODE)
endif

# PULL REQUEST https://github.com/open-power/op-build/pull/669/files
# Also adds "release" params to the make directives below.
# When pull request is accepted, remove the changes
ifeq ($(BR2_OPENPOWER_POWER9),y)
    OPENPOWER_RELEASE=p9
else
    OPENPOWER_RELEASE=p8
endif

OPENPOWER_PNOR_INSTALL_IMAGES = YES
OPENPOWER_PNOR_INSTALL_TARGET = NO

HOSTBOOT_IMAGE_DIR=$(STAGING_DIR)/hostboot_build_images/
HOSTBOOT_BINARY_DIR = $(STAGING_DIR)/hostboot_binaries/
OPENPOWER_PNOR_SCRATCH_DIR = $(STAGING_DIR)/openpower_pnor_scratch/
OPENPOWER_VERSION_DIR = $(STAGING_DIR)/openpower_version

# Subpackages we want to include in the version info (do not include openpower-pnor)
#OPENPOWER_VERSIONED_SUBPACKAGES = skiboot hostboot linux petitboot $(XML_PACKAGE) occ hostboot-binaries capp-ucode
OPENPOWER_VERSIONED_SUBPACKAGES = hostboot occ skiboot linux petitboot $(XML_PACKAGE)
OPENPOWER_PNOR = openpower-pnor

define OPENPOWER_PNOR_INSTALL_IMAGES_CMDS
        mkdir -p $(OPENPOWER_PNOR_SCRATCH_DIR)

        $(TARGET_MAKE_ENV) $(@D)/update_image.pl \
            -release  $(OPENPOWER_RELEASE) \
            -op_target_dir $(HOSTBOOT_IMAGE_DIR) \
            -hb_image_dir $(HOSTBOOT_IMAGE_DIR) \
            -scratch_dir $(OPENPOWER_PNOR_SCRATCH_DIR) \
            -hb_binary_dir $(HOSTBOOT_BINARY_DIR) \
            -targeting_binary_filename $(BR2_OPENPOWER_TARGETING_ECC_FILENAME) \
            -targeting_binary_source $(BR2_OPENPOWER_TARGETING_BIN_FILENAME) \
            -sbe_binary_filename $(BR2_HOSTBOOT_BINARY_SBE_FILENAME) \
            -sbec_binary_filename $(BR2_HOSTBOOT_BINARY_SBEC_FILENAME) \
            -wink_binary_filename $(BR2_HOSTBOOT_BINARY_WINK_FILENAME) \
            -occ_binary_filename $(OCC_STAGING_DIR)/$(BR2_OCC_BIN_FILENAME) \
            -capp_binary_filename $(BINARIES_DIR)/$(BR2_CAPP_UCODE_BIN_FILENAME) \
            -ima_catalog_filename $(BR2_IMA_CATALOG_FILENAME) \
            -openpower_version_filename $(OPENPOWER_PNOR_VERSION_FILE) \
            -payload $(BINARIES_DIR)/$(BR2_SKIBOOT_LID_NAME) \
            -payload_filename $(BR2_SKIBOOT_LID_XZ_NAME) \
            -binary_dir $(BINARIES_DIR) \
            -bootkernel_filename $(LINUX_IMAGE_NAME) \
            -pnor_layout $(@D)/"$(OPENPOWER_RELEASE)"Layouts/$(BR2_OPENPOWER_PNOR_XML_LAYOUT_FILENAME) \
			-sb_signing_config_file $(BR2_SB_SIGNING_UTILS_CONFIG_FILE) \
            $(XZ_ARG) $(SECUREBOOT_ARG) $(KEY_TRANSITION_ARG) $(SIGN_MODE_ARG) \

        mkdir -p $(STAGING_DIR)/pnor/
        $(TARGET_MAKE_ENV) $(@D)/create_pnor_image.pl \
            -release $(OPENPOWER_RELEASE) \
            -xml_layout_file $(@D)/"$(OPENPOWER_RELEASE)"Layouts/$(BR2_OPENPOWER_PNOR_XML_LAYOUT_FILENAME) \
            -pnor_filename $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) \
            -hb_image_dir $(HOSTBOOT_IMAGE_DIR) \
            -scratch_dir $(OPENPOWER_PNOR_SCRATCH_DIR) \
            -outdir $(STAGING_DIR)/pnor/ \
            -payload $(OPENPOWER_PNOR_SCRATCH_DIR)/$(BR2_SKIBOOT_LID_XZ_NAME) \
            -bootkernel $(OPENPOWER_PNOR_SCRATCH_DIR)/$(LINUX_IMAGE_NAME) \
            -sbe_binary_filename $(BR2_HOSTBOOT_BINARY_SBE_FILENAME) \
            -sbec_binary_filename $(BR2_HOSTBOOT_BINARY_SBEC_FILENAME) \
            -wink_binary_filename $(BR2_HOSTBOOT_BINARY_WINK_FILENAME) \
            -occ_binary_filename $(OCC_STAGING_DIR)/$(BR2_OCC_BIN_FILENAME) \
            -ima_catalog_filename $(BR2_IMA_CATALOG_ECC_FILENAME) \
            -targeting_binary_filename $(BR2_OPENPOWER_TARGETING_ECC_FILENAME) \
            -openpower_version_filename $(OPENPOWER_PNOR_VERSION_FILE)

        $(INSTALL) $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) $(BINARIES_DIR)

        # if this config has an UPDATE_FILENAME defined, create a 32M (1/2 size)
        # image that only updates the non-golden side
        if [ "$(BR2_OPENPOWER_PNOR_UPDATE_FILENAME)" != "" ]; then \
            dd if=$(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_FILENAME) of=$(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_UPDATE_FILENAME) bs=32M count=1; \
            $(INSTALL) $(STAGING_DIR)/pnor/$(BR2_OPENPOWER_PNOR_UPDATE_FILENAME) $(BINARIES_DIR); \
        fi
endef

$(eval $(generic-package))
# Generate openPOWER pnor version string by combining subpackage version string files
$(eval $(call OPENPOWER_VERSION,$(OPENPOWER_PNOR)))
