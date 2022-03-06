#!/vendor/bin/sh
# Uperf Setup
# https://github.com/yc9559/
# Author: Matt Yang & cjybyjk (cjybyjk@gmail.com) &HamJTY(coolapk@HamJTY)
# Version: 20201129

BASEDIR=$MODPATH
USER_PATH="/data/media/0/yc/uperf"

# $1:error_message
_abort() {
    echo "$1"
    echo "! Uperf installation failed."
    exit 1
}

# $1:file_node $2:owner $3:group $4:permission $5:secontext
_set_perm() {
    local con
    chown $2:$3 $1
    chmod $4 $1
    con=$5
    [ -z $con ] && con=u:object_r:system_file:s0
    chcon $con $1
}

# $1:directory $2:owner $3:group $4:dir_permission $5:file_permission $6:secontext
_set_perm_recursive() {
    find $1 -type d 2>/dev/null | while read dir; do
        _set_perm $dir $2 $3 $4 $6
    done
    find $1 -type f -o -type l 2>/dev/null | while read file; do
        _set_perm $file $2 $3 $5 $6
    done
}

_get_nr_core() {
    echo "$(cat /proc/stat | grep cpu[0-9] | wc -l)"
}

_is_aarch64() {
    if [ "$(getprop ro.product.cpu.abi)" == "arm64-v8a" ]; then
        echo "true"
    else
        echo "false"
    fi
}

_is_eas() {
    if [ "$(grep sched /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)" != "" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# $1:cpuid
_get_maxfreq() {
    local fpath="/sys/devices/system/cpu/cpu$1/cpufreq/cpuinfo_max_freq"
    local maxfreq="0"

    if [ ! -f "$fpath" ]; then
        echo ""
        return
    fi

    for f in $(cat $fpath); do
        [ "$f" -gt "$maxfreq" ] && maxfreq="$f"
    done
    echo "$maxfreq"
}

_get_maxfreq_6893() {
    local fpath="/sys/devices/system/cpu/cpufreq/policy$1/cpuinfo_max_freq"
    local maxfreq="0"
    if [ ! -f "$fpath" ]; then
        echo ""
        return
    fi

    for f in $(cat $fpath); do
        [ "$f" -gt "$maxfreq" ] && maxfreq="$f"
    done
    echo "$maxfreq"
}

_get_socid() {
    if [ -f /sys/devices/soc0/soc_id ]; then
        echo "$(cat /sys/devices/soc0/soc_id)"
    else
        echo "$(cat /sys/devices/system/soc/soc0/id)"
    fi
}

_get_sm6150_type() {
    [ -f /sys/devices/soc0/soc_id ] && SOC_ID="$(cat /sys/devices/soc0/soc_id)"
    [ -f /sys/devices/system/soc/soc0/id ] && SOC_ID="$(cat /sys/devices/system/soc/soc0/id)"
    case "$SOC_ID" in
    365 | 366) echo "sdm730" ;;
    355 | 369) echo "sdm675" ;;
    esac
}

_get_sdm76x_type() {
    if [ "$(_get_maxfreq 7)" -gt 2800000 ]; then
        echo "sdm768"
    elif [ "$(_get_maxfreq 7)" -gt 2300000 ]; then
        echo "sdm765"
    else
        echo "sdm750"
    fi
}

_get_msm8916_type() {
    case "$(_get_socid)" in
    "206" | "247" | "248" | "249" | "250") ui_print "msm8916" ;;
    "233" | "240" | "242") ui_print "sdm610" ;;
    "239" | "241" | "263" | "268" | "269" | "270" | "271") ui_print "sdm616" ;;
    *) ui_print "msm8916" ;;
    esac
}

_get_msm8952_type() {
    case "$(_get_socid)" in
    "264" | "289")
        echo "msm8952"
        ;;
    *)
        if [ "$(_get_nr_core)" == "8" ]; then
            echo "sdm652"
        else
            echo "sdm650"
        fi
        ;;
    esac
}

_get_sdm636_type() {
    if [ "$(_is_eas)" == "true" ]; then
        echo "sdm636_eas"
    else
        echo "sdm636_hmp"
    fi
}

_get_sdm660_type() {
    local b_max
    b_max="$(_get_maxfreq 4)"
    # sdm660 & sdm636 may share the same platform name
    if [ "$b_max" -gt 2000000 ]; then
        if [ "$(_is_eas)" == "true" ]; then
            echo "sdm660_eas"
        else
            echo "sdm660_hmp"
        fi
    else
        echo "$(_get_sdm636_type)"
    fi
}

_get_sdm652_type() {
    if [ "$(_is_eas)" == "true" ]; then
        echo "sdm652_eas"
    else
        echo "sdm652_hmp"
    fi
}

_get_sdm650_type() {
    if [ "$(_is_eas)" == "true" ]; then
        echo "sdm650_eas"
    else
        echo "sdm650_hmp"
    fi
}

_get_sdm626_type() {
    if [ "$(_is_eas)" == "true" ]; then
        echo "sdm626_eas"
    else
        echo "sdm626_hmp"
    fi
}

_get_sdm625_type() {
    local b_max
    b_max="$(_get_maxfreq 4)"
    # sdm625 & sdm626 may share the same platform name
    if [ "$b_max" -lt 2100000 ]; then
        if [ "$(_is_eas)" == "true" ]; then
            echo "sdm625_eas"
        else
            echo "sdm625_hmp"
        fi
    else
        echo "$(_get_sdm626_type)"
    fi
}

_get_sdm835_type() {
    if [ "$(_is_eas)" == "true" ]; then
        echo "sdm835_eas"
    else
        echo "sdm835_hmp"
    fi
}

_get_sdm82x_type() {
    if [ "$(_is_eas)" == "true" ]; then
        ui_print "sdm82x_eas"
        return
    fi

    local l_max
    local b_max
    l_max="$(_get_maxfreq 0)"
    b_max="$(_get_maxfreq 2)"

    # sdm820 OC 1728/2150
    if [ "$l_max" -lt 1800000 ]; then
        if [ "$b_max" -gt 2100000 ]; then
            # 1593/2150
            echo "sdm820_hmp"
        elif [ "$b_max" -gt 1900000 ]; then
            # 1593/1996
            echo "sdm821_v1_hmp"
        else
            # 1363/1824
            echo "sdm820_hmp"
        fi
    else
        if [ "$b_max" -gt 2300000 ]; then
            # 2188/2342
            echo "sdm821_v3_hmp"
        else
            # 1996/2150
            echo "sdm821_v2_hmp"
        fi
    fi
}

_get_e8890_type() {
    if [ "$(_is_eas)" == "true" ]; then
        echo "e8890_eas"
    else
        echo "e8890_hmp"
    fi
}

_get_e8895_type() {
    if [ "$(_is_eas)" == "true" ]; then
        echo "e8895_eas"
    else
        echo "e8895_hmp"
    fi
}

_get_mt6853_type() {
    local b_max
    b_max="$(_get_maxfreq 6)"
    if [ "$b_max" -gt 2200000 ]; then
        echo "mtd800u"
    else
        echo "mtd720"
    fi
}

_get_mt6873_type() {
    local b_max
    b_max="$(_get_maxfreq 4)"
    if [ "$b_max" -gt 2500000 ]; then
        echo "mtd820"
    else
        echo "mtd800"
    fi
}

_get_mt6877_type() {
    local b_max
    b_max="$(_get_maxfreq 4)"
    if [ "$b_max" -gt 2500000 ]; then
        echo "mtd920"
    else
        echo "mtd900"
    fi
}
_get_mt6885_type() {
    local b_max
    b_max="$(_get_maxfreq 4)"
    if [ "$b_max" -ge 2500000 ]; then
        echo "mtd1000"
    else
        echo "mtd1000l"
    fi
}

_get_mt6893_type() {
    local b_max
    b_max="$(_get_maxfreq_6893 7)"
    if [ "$b_max" -ge 2700000 ]; then
        echo "mtd1200"
    else
        echo "mtd1100"
    fi
}
_get_mt6895_type() {
    local b_max
    b_max="$(_get_maxfreq_6895 4)"
    if [ "$b_max" -ge 2800000 ]; then
        echo "mtd8100"
    else
        echo "mtd8000"
    fi
}
_get_mt6833_type() {
    local b_max
    b_max="$(_get_maxfreq 7)"
    if [ "$b_max" -ge 2300000 ]; then
        echo "mtd810"
    else
        echo "mtd700"
    fi
}
_get_lahaina_type() {
    local b_max
    b_max="$(_get_maxfreq 7)"
    if [ "$b_max" -gt 2600000 ]; then
        echo "sdm888"
    else
        echo "sdm780"
    fi
}

# $1:cfg_name
_setup_platform_file() {
    mv -f $USER_PATH/cfg_uperf.json $USER_PATH/cfg_uperf.json.bak 2>/dev/null
    cp $BASEDIR/config/$1.json $USER_PATH/cfg_uperf.json 2>/dev/null
    echo "balance" >$USER_PATH/cur_powermode
}

_place_user_config() {
    if [ ! -e "$USER_PATH/cfg_uperf_display.txt" ]; then
        cp $BASEDIR/config/cfg_uperf_display.txt $USER_PATH/cfg_uperf_display.txt 2>/dev/null
    fi
}

# $1:board_name
_get_cfgname() {
    local ret
    case "$1" in
    "lahaina") ret="$(_get_lahaina_type)" ;;
    "shima") ret="sdm775" ;;
    "kona") ret="sdm865" ;;
    "msmnile") ret="sdm855" ;;
    "sdm845") ret="sdm845" ;;
    "lito") ret="$(_get_sdm76x_type)" ;;
    "sm6150") ret="$(_get_sm6150_type)" ;;
    "sdm710") ret="sdm710" ;;
    "msm8916") ret="$(_get_msm8916_type)" ;;
    "msm8939") ret="sdm616" ;;
    "msm8952") ret="$(_get_msm8952_type)" ;;
    "msm8953") ret="$(_get_sdm625_type)" ;;
    "msm8953pro") ret="$(_get_sdm626_type)" ;;
    "sdm660") ret="$(_get_sdm660_type)" ;;
    "sdm636") ret="$(_get_sdm636_type)" ;;
    "trinket") ret="sdm665" ;;
    "bengal") ret="sdm665" ;; # sdm662
    "msm8976") ret="$(_get_sdm652_type)" ;;
    "msm8956") ret="$(_get_sdm650_type)" ;;
    "msm8998") ret="$(_get_sdm835_type)" ;;
    "msm8996") ret="$(_get_sdm82x_type)" ;;
    "msm8996pro") ret="$(_get_sdm82x_type)" ;;
    "exynos2100") ret="e2100" ;;
    "exynos1080") ret="e1080" ;;
    "exynos990") ret="e990" ;;
    "universal2100") ret="e2100" ;;
    "universal1080") ret="e1080" ;;
    "universal990") ret="e990" ;;
    "universal9825") ret="e9820" ;;
    "universal9820") ret="e9820" ;;
    "universal9810") ret="e9810" ;;
    "universal8895") ret="$(_get_e8895_type)" ;;
    "universal8890") ret="$(_get_e8890_type)" ;;
    "universal7420") ret="e7420" ;;
    "mt6768") ret="mtg80" ;; # Helio P65(mt6768)/G70(mt6769v)/G80(mt6769t)/G85(mt6769z)
    "mt6785") ret="mtg90t" ;;
    "mt6853") ret="$(_get_mt6853_type)" ;;
    "mt6873") ret="$(_get_mt6873_type)" ;;
    "mt6875") ret="$(_get_mt6873_type)" ;;
    "mt6885") ret="$(_get_mt6885_type)" ;;
    "mt6889") ret="$(_get_mt6885_type)" ;;
    "mt6891") ret="mtd1100" ;;             # D1100(4+4)
    "mt6893") ret="$(_get_mt6893_type)" ;; # D1100(1+3+4) & D1200 & D1300
    "mt6877") ret="$(_get_mt6877_type)" ;; # D900 D920
    "mt6833") ret="$(_get_mt6833_type)" ;; # D810 & D700
    "mt6833p") ret="mtd810" ;;             # D810
    "mt6833v") ret="mtd810" ;;             # D810
    "mt6983") ret="mtd9000" ;;             # D9000
    "mt6895") ret="$(_get_mt6895_type)" ;; # D8000 & D8100
    *) ret="unsupported" ;;
    esac
    echo "$ret"
}

uperf_print_banner() {
    # 获取模块版本
    module_version="$(grep_prop version $MODPATH/module.prop)"
    # 获取模块名称
    module_name="$(grep_prop name $MODPATH/module.prop)"
    # 获取模块id
    module_id="$(grep_prop id $MODPATH/module.prop)"
    # 获取模块作者
    module_author="$(grep_prop author $MODPATH/module.prop)"
    ui_print ""
    ui_print "* Uperf (For Mediatek SoCs Only) https://gitee.com/hamjin/uperf/"
    ui_print "* Author: $module_author"
    ui_print "* Version: $module_version"
}

uperf_print_finish() {
    ui_print "- Uperf Install Succeed."
}

uperf_install() {
    ui_print "- Start Install"
    DEVICE=$(getprop ro.product.board)
    DEVCODE=$(getprop ro.product.device)
    ui_print "- Platform: $(getprop ro.board.platform)"
    ui_print "- Model: $DEVCODE"
    ui_print "- DeviceCode: $DEVICE"

    local target
    local cfgname
    target="$(getprop ro.board.platform)"
    setprop ro.product.board $target
    cfgname="$(_get_cfgname $target)"
    if [ "$cfgname" == "unsupported" ]; then
        target="$(getprop ro.product.board)"
        cfgname="$(_get_cfgname $target)"
    fi
    if [ "$cfgname" != "unsupported" ] && [ -f $MODPATH/config/$cfgname.json ]; then
        #Redmi K30 Ultra
        if [ "$DEVICE" == "cezanne" ] || [ "$DEVCODE" == "cezanne" ]; then
            cfgname="k30u"
            ui_print "- Found Redmi K30 Ultra！Using specified config！"
        #Redmi 10X &Redmi 10X Pro
        elif [ "$DEVCODE" == "atom" ] || [ "$DEVICE" == "atom" ] || [ "$DEVCODE" == "bomb" ] || [ "$DEVICE" == "bomb" ]; then
            cfgname="10x"
            ui_print "- Found Redmi 10X Series！Using specified config！"
        #Others
        else
            ui_print "- found CPU: $target"
        fi
        #make dir for the platform is supported
        ui_print "- Config File: $cfgname"
        mkdir -p $USER_PATH
        rm -rf $USER_PATH/cfgname $USER_PATH/device $USER_PATH/device_code
        mkdir -p $USER_PATH/deviceinfo
        echo $cfgname >$USER_PATH/deviceinfo/cfgname.txt
        echo $DEVICE >$USER_PATH/deviceinfo/device.txt
        echo $DEVCODE >$USER_PATH/deviceinfo/device_code.txt
        _setup_platform_file "$cfgname"
    else
        ui_print "- Target: $cfgname"
        _abort "! [$target] is not supproted yet."
    fi

    _place_user_config
    rm -rf $BASEDIR/config
    #ARM64
    if [ "$(_is_aarch64)" == "true" ]; then
        killall -9 adjustment uperf
    else
        _abort "! Only ARM64 platform is supported!"
    fi
    _set_perm_recursive $BASEDIR 0 0 0755 0644
    _set_perm_recursive $BASEDIR/bin 0 0 0755 0755
    # in case of set_perm_recursive is broken
    chmod 0755 $BASEDIR/bin/*

}
clear_path() {
    if [ -f "$1" ]; then
        chattr -i "$1"
        rm -rf "$1"
        touch "$1"
        chmod 000 "$1"
        chattr +i "$1"
    fi
}
disable_mtk_thermal() {

    chattr -i "/data/vendor/.tp"
    chattr -i /data/vendor/thermal
    rm -rf "/data/vendor/.tp"
    ui_print "- Disable Mediatek Temp Limit by modify /data"
    rm -rf /data/vendor/thermal
    clear_path /data/thermal
    clear_path /data/system/mcd
    ui_print "- Disable MIUI Cloud Control by modify /data"
    clear_path /data/system/migt
    clear_path /data/system/whetstone
}
injector_install() {
    ui_print "- Installing SurfaceFlinger Injector"
    ui_print "- Automaticly Set SeLinux to \"permissive\" before injection and Enable it after injection would get better compatibility."
    ui_print "- If you need, please remove flags/allow_permissive in this module's dir by yourself to prevent this action"

    _set_perm "$BASEDIR/bin/sfa_injector" 0 0 0755 u:object_r:system_file:s0
    _set_perm "$BASEDIR/bin/libsfanalysis.so" 0 0 0644 u:object_r:system_lib_file:s0

    # in case of set_perm_recursive is broken
    chmod 0755 $BASEDIR/bin/*
}

powerhal_stub_install() {
    ui_print "- Modify perfhal files"
    ui_print "- Disable Mediatek Temp Limit by modify /vendor"
    # do not place empty json if it doesn't exist in system
    # vendor/etc/powerhint.json: android perf hal
    # vendor/etc/powerscntbl.cfg: mediatek perf hal (android 9)
    # vendor/etc/powerscntbl.xml: mediatek perf hal (android 10+)
    # vendor/etc/perf/commonresourceconfigs.json: qualcomm perf hal resource
    # vendor/etc/perf/targetresourceconfigs.json: qualcomm perf hal resource overrides
    local perfcfgs
    perfcfgs="
    vendor/etc/powerhint.json
    vendor/etc/powerscntbl.cfg
    vendor/etc/powerscntbl.xml
    vendor/etc/perf/commonresourceconfigs.xml
    vendor/etc/perf/targetresourceconfigs.xml
    vendor/etc/power_app_cfg.xml
    vendor/etc/powercontable.xml
    vendor/etc/task_profiles.json
    vendor/etc/fstb.cfg
    vendor/etc/gbe.cfg
    vendor/etc/xgf.cfg
    "
    for f in $perfcfgs; do
        if [ ! -f "/$f" ]; then
            rm "$BASEDIR/system/$f"
        else
            _set_perm "$BASEDIR/system/$f" 0 0 0644 u:object_r:vendor_configs_file:s0
            true >$BASEDIR/flags/enable_perfhal_stub
        fi
    done
}

busybox_install() {
    ui_print "- Using BusyBox in Magisk"
    local dst_path
    dst_path="$BASEDIR/bin/busybox/"

    mkdir -p "$dst_path"
    ln -s "/data/adb/magisk/busybox" "$dst_path/busybox"
    chmod 0755 "$dst_path/busybox"

    rm -rf $BASEDIR/busybox
}
uperf_print_banner
uperf_install
disable_mtk_thermal
injector_install
powerhal_stub_install
busybox_install
uperf_print_finish
