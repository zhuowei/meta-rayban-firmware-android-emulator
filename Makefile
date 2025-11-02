# run with root.

LPUNPACK=../lpunpack_and_lpmake/bin/lpunpack
LPMAKE=../lpunpack_and_lpmake/bin/lpmake

all: out/output/system.img

VENDOR_FILES := lib64/libosutils.so lib64/vendor.oculus.hardware.wifi@1.0.so \
	bin/hw/vendor.oculus.hardware.wifi@1.0-service etc/init/vendor.oculus.hardware.wifi@1.0-service.rc \
	etc/vintf/manifest/vendor.oculus.hardware.wifi@1.0-service.xml \
	lib64/android.hardware.wifi.hostapd@1.1.so lib64/android.hardware.wifi.hostapd@1.0.so \
	lib64/android.hardware.wifi.supplicant@1.0.so lib64/libwpa_client.so \
	etc/passwd etc/group \
	bin/hw/android.hardware.bluetooth@1.0-service-qti \
	lib64/android.hardware.bluetooth@1.0.so \
	lib64/vendor.qti.hardware.bluetooth_offload@1.0.so \
	lib64/hw/vendor.qti.hardware.bluetooth_offload@1.0-impl.so \
	lib64/vendor.qti.hardware.bluetooth_sar@1.0.so \
	lib64/vendor.qti.hardware.bluetooth_sar@1.1.so \
	lib64/vendor.qti.hardware.btconfigstore@1.0.so \
	lib64/vendor.qti.hardware.btconfigstore@2.0.so \
	lib64/libqti_vndfwk_detect_vendor.so \
	lib64/hw/android.hardware.bluetooth@1.0-impl-qti.so \
	lib64/libdiag.so \
	lib64/libqmi_cci.so \
	lib64/libqmi_encdec.so \
	lib64/libbtnv.so \
	lib64/libsoc_helper.so \
	etc/init/android.hardware.bluetooth@1.0-service-qti.rc

VENDOR_REMOVE := etc/init/android.hardware.thermal@2.0-service.rc \
	etc/vintf/manifest/android.hardware.thermal@2.0-service.xml \
	etc/vintf/manifest/bluetooth-service-default.xml \
	etc/init/bluetooth-service-default.rc


# sgdisk -p system.img shows super starts on sector 4096
out/avd/super.img: avd/system.img
	mkdir -p out/avd
	dd if=avd/system.img bs=16M iflag=skip_bytes skip=$$((4096*512)) of=out/avd/super.img
out/avd/system_dlkm.img: out/avd/super.img
	$(LPUNPACK) -p system_dlkm out/avd/super.img out/avd

out/fb/vendor: fb/vendor.img
	rm -rf out/fb/vendor
	7z -oout/fb/vendor x fb/vendor.img $(VENDOR_FILES)

out/avd/vendor.img: out/avd/super.img out/fb/vendor files/manifest_bluetooth.xml
	$(LPUNPACK) -p vendor out/avd/super.img out/avd
	truncate -s 200M -c out/avd/vendor.img
	resize2fs out/avd/vendor.img
# https://x.com/topjohnwu/status/1170404631865778177
	e2fsck -E unshare_blocks out/avd/vendor.img
	mkdir -p out/avd/tempmnt_vendor out/fb/tempmnt_vendor
	mount -o rw,loop out/avd/vendor.img out/avd/tempmnt_vendor
	mount -o ro,loop fb/vendor.img out/fb/tempmnt_vendor
# emulator's vendor turns on apex; don't let it
	LC_ALL=C sed -i -e "s/ro.apex.updatable=true/#o.apex.updatable=true/" out/avd/tempmnt_vendor/build.prop
# temperature service crashes in Temperature.readVectorFromParcel
	for i in $(VENDOR_REMOVE); do \
		rm out/avd/tempmnt_vendor/$$i ; \
	done
	for i in $(VENDOR_FILES); do \
		cp -a out/fb/tempmnt_vendor/$$i out/avd/tempmnt_vendor/$$i ; \
	done
	cp files/manifest_bluetooth.xml out/avd/tempmnt_vendor/etc/vintf/manifest/
	echo "/(vendor|system/vendor)/bin/hw/vendor\.oculus\.hardware\.wifi@1\.0-service           u:object_r:hal_wifi_default_exec:s0" \
		>> out/avd/tempmnt_vendor/etc/selinux/vendor_file_contexts
	chcon u:object_r:hal_wifi_default_exec:s0 out/avd/tempmnt_vendor/bin/hw/vendor.oculus.hardware.wifi@1.0-service
	umount out/avd/tempmnt_vendor
	umount out/fb/tempmnt_vendor

# we need to patch out security_setenforce: security_getenforce conveniently returns 0 when it's not enforcing...
out/fb/system.img: fb/system.img
	mkdir -p out/fb
	LC_ALL=C sed -e "s/security_getenforce\x00security_setenforce\x00/security_getenforce\x00security_getenforce\x00/" \
		-e "s/^ro.adb.secure=1$$/ro.adb.secure=0/" \
		-e "s/^ro.debuggable=0$$/ro.debuggable=1/" \
		fb/system.img > out/fb/system.img

out/repack/super.img: out/avd/system_dlkm.img out/avd/vendor.img out/fb/system.img fb/system_ext.img fb/product.img
	# TODO(zhuowei): emulator doesn't have an odm partition
	mkdir -p out/repack
	$(LPMAKE) --device-size=$$((4*1024*1024*1024)) \
		--metadata-size=$$((64*1024)) \
		--metadata-slots=2 \
		--group=emulator_dynamic_partitions:$$(((4*1024*1024*1024) - (64*1024))) \
		--partition=system:readonly:$$(stat -c "%s" out/fb/system.img):emulator_dynamic_partitions \
		--partition=system_dlkm:readonly:$$(stat -c "%s" out/avd/system_dlkm.img):emulator_dynamic_partitions \
		--partition=system_ext:readonly:$$(stat -c "%s" fb/system_ext.img):emulator_dynamic_partitions \
		--partition=product:readonly:$$(stat -c "%s" fb/product.img):emulator_dynamic_partitions \
		--partition=vendor:readonly:$$(stat -c "%s" out/avd/vendor.img):emulator_dynamic_partitions \
		--image=system=out/fb/system.img \
		--image=system_dlkm=out/avd/system_dlkm.img \
		--image=system_ext=fb/system_ext.img \
		--image=product=fb/product.img \
		--image=vendor=out/avd/vendor.img \
		--output=$@

out/output/system.img: avd/system.img out/repack/super.img
	mkdir -p out/output
	# super, vbmeta, 1MB extra for partition table
	rm -f $@
	truncate -s $$(((4*1024*1024*1024) + (1*1024*1024) + (1*1024*1024))) $@
	sgdisk -n 1:2048:4095 $@
	sgdisk -n 2:4096:0 $@
	sgdisk -c 1:vbmeta $@
	sgdisk -c 2:super $@
	dd if=avd/system.img bs=$$(((4096-2048) * 512)) count=1 iflag=skip_bytes skip=$$((2048*512)) oflag=seek_bytes seek=$$((2048*512)) conv=notrunc of=$@
	dd if=out/repack/super.img bs=16M oflag=seek_bytes seek=$$((4096*512)) conv=notrunc of=$@

clean:
	rm -rf out
