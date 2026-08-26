# TACTICAL MONO — Garmin Enduro 3 表盘

单色战术风格表盘（纯黑底 + 白/灰），显示：时间、日期、光照强度（太阳能）、训练准备度、月相、电池。

## 编译
    ./build.sh

## 模拟器
    "$SDK/bin/connectiq"            # 启动模拟器
    "$SDK/bin/monkeydo" bin/TacticalFace.prg enduro3

## 安装到手表
把 `bin/TacticalFace.prg` 复制到手表的 `GARMIN/APPS/` 目录（USB 连接），然后在手表上选择表盘。
