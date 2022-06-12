#!/system/bin/sh
#
# Copyright (C) 2021-2022 Matt Yang
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Runonce after boot, to speed up the transition of power modes in powercfg

# Modified by Ham Jin

BASEDIR="$(dirname $(readlink -f "$0"))"
. $BASEDIR/pathinfo.sh
. $BASEDIR/libcommon.sh
. $BASEDIR/libpowercfg.sh
. $BASEDIR/libcgroup.sh

unify_cgroup() {
    # clear top-app
    for cg in stune cpuctl; do
        for p in $(cat /dev/$cg/top-app/tasks); do
            echo $p >/dev/$cg/foreground/tasks
        done
    done

    # unused
    rmdir /dev/cpuset/foreground/boost

    # work with uperf/ContextScheduler
    change_task_cgroup "surfaceflinger|system_server" "" "cpuset"
    change_task_cgroup "netd|allocator|kswapd0|kcompactd0" "foreground" "cpuset"
    change_task_cgroup "android.hardware.media|vendor.mediatek.hardware" "background" "cpuset"
    change_task_cgroup "aal_sof|kfps|dsp_send_thread|vdec_ipi_recv|mtk_drm_disp_id|hif_thread|main_thread|ged_" "background" "cpuset"
    change_task_cgroup "pp_event|crtc_" "background" "cpuset"

}

unify_sched() {
    # clear stune & uclamp
    for d in /dev/stune/*/; do
        lock_val "0" $d/schedtune.boost
    done
    for d in /dev/cpuctl/*/; do
        lock_val "0" $d/cpu.uclamp.min
    done

    for d in kernel walt; do
        lock_val "0" /proc/sys/$d/sched_force_lb_enable
        lock_val "255" /proc/sys/$d/sched_busy_hysteresis_enable_cpus
        lock_val "2000000" /proc/sys/$d/sched_busy_hyst_ns
    done
}
unify_cpufreq() {
    # unify hmp interactive governor, only 2+2 4+2 4+4
    set_governor_param "interactive/use_sched_load" "0:1 2:1 4:1"
    set_governor_param "interactive/use_migration_notif" "0:1 2:1 4:1"
    set_governor_param "interactive/enable_prediction" "0:1 2:1 4:1"
    set_governor_param "interactive/ignore_hispeed_on_notif" "0:1 2:1 4:1"
    set_governor_param "interactive/fast_ramp_down" "0:0 2:0 4:0"
    set_governor_param "interactive/boostpulse_duration" "0:0 2:0 4:0"
    set_governor_param "interactive/boost" "0:0 2:0 4:0"
    set_governor_param "interactive/above_hispeed_delay" "0:0 2:0 4:0"
    set_governor_param "interactive/hispeed_freq" "0:0 2:0 4:0"
    set_governor_param "interactive/go_hispeed_load" "0:90 2:90 4:90"
    set_governor_param "interactive/target_loads" "0:80 2:80 4:80"
    set_governor_param "interactive/min_sample_time" "0:0 2:0 4:0"
    set_governor_param "interactive/max_freq_hysteresis" "0:0 2:0 4:0"
}
unify_devfreq() {
    for d in $(ls /sys/class/devfreq/); do
        local maxfreq="0"
        for f in $(cat /sys/class/devfreq/$d/available_frequencies); do
            [ "$f" -gt "$maxfreq" ] && maxfreq="$f"
        done
        [ "$maxfreq" -gt "0" ] && mutate "$maxfreq" "$d/max_freq"
    done
    for d in DDR LLCC L3; do
        mutate "9999000000" "/sys/devices/system/cpu/bus_dcvs/$d/*/max_freq"
    done
}
unify_lpm() {
    # Qualcomm enter C-state level 3 took ~500us
    lock_val "0" /sys/module/lpm_levels/parameters/lpm_ipi_prediction
    lock_val "0" /sys/module/lpm_levels/parameters/lpm_prediction
    lock_val "2" /sys/module/lpm_levels/parameters/bias_hyst
}
disable_hotplug() {
    # Exynos hotplug
    mutate "0" /sys/power/cpuhotplug/enabled
    mutate "0" /sys/devices/system/cpu/cpuhotplug/enabled

    # turn off msm_thermal
    lock_val "0" /sys/module/msm_thermal/core_control/enabled
    lock_val "N" /sys/module/msm_thermal/parameters/enabled

    # 3rd
    lock_val "0" /sys/kernel/intelli_plug/intelli_plug_active
    lock_val "0" /sys/module/blu_plug/parameters/enabled
    lock_val "0" /sys/devices/virtual/misc/mako_hotplug_control/enabled
    lock_val "0" /sys/module/autosmp/parameters/enabled
    lock_val "0" /sys/kernel/zen_decision/enabled

    # stop sched core_ctl
    set_corectl_param "enable" "0:0 2:0 4:0 6:0 7:0"

    # bring all cores online
    for i in 0 1 2 3 4 5 6 7 8 9; do
        mutate "1" /sys/devices/system/cpu/cpu$i/online
    done
    # bring all core_ctls online
    for i in 0 1 2 3 4 5 6 7 8 9; do
        mutate "1" /sys/devices/system/cpu/cpu$i/core_ctl/enable
    done
    # bring all core_ctls boost off
    for i in 0 1 2 3 4 5 6 7 8 9; do
        mutate "0" /sys/devices/system/cpu/cpu$i/core_ctl/core_ctl_boost
    done
    for i in 0 1 2 3 4 5 6 7 8 9; do
        mutate "0" /sys/devices/system/cpu/cpu$i/core_ctl/min_cpus
    done
}

disable_kernel_boost() {
    # Qualcomm
    lock_val "0" "/sys/devices/system/cpu/cpu_boost/*"
    lock_val "0" "/sys/devices/system/cpu/cpu_boost/parameters/*"
    lock_val "0" "/sys/module/cpu_boost/parameters/*"
    lock_val "0" "/sys/module/msm_performance/parameters/*"
    lock_val "0" "/proc/sys/walt/input_boost/*"

    # no msm_performance limit
    set_cpufreq_min "0:0 1:0 2:0 3:0 4:0 5:0 6:0 7:0"
    set_cpufreq_max "0:9999000 1:9999000 2:9999000 3:9999000 4:9999000 5:9999000 6:9999000 7:9999000"

    # MediaTek
    # policy_status
    # [0] PPM_POLICY_PTPOD: Meature PMIC buck currents
    # [1] PPM_POLICY_UT: Unit test
    # [2] PPM_POLICY_FORCE_LIMIT: enabled
    # [3] PPM_POLICY_PWR_THRO: enabled
    # [4] PPM_POLICY_THERMAL: enabled
    # [5] PPM_POLICY_DLPT: Power measurment and power budget managing
    # [6] PPM_POLICY_HARD_USER_LIMIT: enabled
    # [7] PPM_POLICY_USER_LIMIT: enabled
    # [8] PPM_POLICY_LCM_OFF: disabled
    # [9] PPM_POLICY_SYS_BOOST: disabled
    # [10] PPM_POLICY_HICA: ?
    # Usage: echo <policy_idx> <1(enable)/0(disable)> > /proc/ppm/policy_status

    # first disable all policy
    lock_val "1" /proc/ppm/enabled
    for i in 0 1 2 3 4 5 7 8 9 10; do
        lock_val "$i 0" /proc/ppm/policy_status
    done
    # enable the policy used by uperf
    lock_val "6 1" /proc/ppm/policy_status
    lock "/proc/ppm/policy/*"
    lock "/proc/ppm/*"
    # Disable Touch Boost in 6893 and before
    lock_val "enable 0" /proc/perfmgr/tchbst/user/usrtch

    # Samsung
    mutate "0" "/sys/class/input_booster/*"

    # Oneplus
    lock_val "N" "/sys/module/control_center/parameters/*"
    lock_val "0" /sys/module/aigov/parameters/enable
    lock_val "0" "/sys/module/houston/parameters/*"
    # OnePlus opchain always pins UX threads on the big cluster
    lock_val "0" /sys/module/opchain/parameters/chain_on

    # 3rd
    lock_val "0" "/sys/kernel/cpu_input_boost/*"
    lock_val "0" "/sys/module/cpu_input_boost/parameters/*"
    lock_val "0" "/sys/module/dsboost/parameters/*"
    lock_val "0" "/sys/module/devfreq_boost/parameters/*"
}

disable_userspace_boost() {
    # xiaomi vip-task scheduler override
    chmod 0000 /dev/migt
    for f in /sys/module/migt/parameters/*; do
        chmod 0000 $f
    done

    # xiaomi perfservice
    stop vendor.perfservice
    stop miuibooster
    stop vendor.miperf

    # brain service maybe not smart
    stop oneplus_brain_service 2>/dev/null

    # Qualcomm perfd
    stop perfd 2>/dev/null

    # work with uperf/ContextScheduler
    #lock_val "0" "/sys/module/mtk_fpsgo/parameters/boost_affinity*"
    #lock_val "0" "/sys/module/fbt_cpu/parameters/boost_affinity*"
    #lock_val "0" /sys/kernel/fpsgo/fbt/switch_idleprefer
    #lock_val "1" /proc/perfmgr/syslimiter/syslimiter_force_disable
    #lock_val "0" /sys/module/mtk_core_ctl/parameters/policy_enable
    #lock_val "0" /sys/kernel/fpsgo/fbt/thrm_enable
    #lock_val "90" /sys/kernel/fpsgo/fbt/thrm_temp_th
    #lock_val "-1" /sys/kernel/fpsgo/fbt/thrm_limit_cpu
    #lock_val "-1" /sys/kernel/fpsgo/fbt/thrm_sub_cpu

    # Qualcomm&MTK perfhal
    perfhal_stop

    # libperfmgr
    stop vendor.power-hal-1-0
    stop vendor.power-hal-1-1
    stop vendor.power-hal-1-2
    stop vendor.power-hal-1-3
    stop vendor.power-hal-aidl

}

restart_userspace_boost() {
    # Qualcomm&MTK perfhal
    perfhal_start

    # libperfmgr
    start vendor.power-hal-1-0
    start vendor.power-hal-1-1
    start vendor.power-hal-1-2
    start vendor.power-hal-1-3
    start vendor.power-hal-aidl

}

disable_userspace_thermal() {
    # yes, let it respawn
    killall mi_thermald
    # prohibit mi_thermald use cpu thermal interface
    for i in 0 2 4 6 7; do
        local maxfreq="$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq)"
        [ "$maxfreq" -gt "0" ] && lock_val "cpu$i $maxfreq" /sys/devices/virtual/thermal/thermal_message/cpu_limits
    done
}

restart_userspace_thermal() {
    # yes, let it respawn
    killall mi_thermald
}

# set permission
disable_kernel_boost
disable_hotplug
unify_sched
unify_devfreq
unify_lpm

disable_userspace_thermal
restart_userspace_thermal
disable_userspace_boost
restart_userspace_boost

# unify value
disable_kernel_boost
disable_hotplug
unify_sched
unify_devfreq
unify_lpm

# make sure that all the related cpu is online
rebuild_process_scan_cache
unify_cgroup
