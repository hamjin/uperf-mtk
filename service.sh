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

BASEDIR="$(dirname $(readlink -f "$0"))"

crash_recuser() {
    rm $BASEDIR/logcat.log
    logcat -f $BASEDIR/logcat.log &
    sleep 60
    killall logcat
    rm -f $BASEDIR/flag/need_recuser
    rm $BASEDIR/logcat.log
}

(crash_recuser &)

#BootStrap Uperf
sh $BASEDIR/initsvc_uperf.sh
