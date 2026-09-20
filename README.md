# garmin_satisfy

Garmin Connect IQ 表盘，手表上显示为 **TACTICAL MONO**。单色战术排版：卡其纸底 / 反色，大号时间，四行可配置数据，日出日落与气温。

灵感来自 SATISFY × COROS APEX 4 Environment Overview，**非官方、无关联**。

## 机型

| 设备 | 屏幕 | 说明 |
|---|---|---|
| Forerunner 970 | 454×454 AMOLED | 默认编译目标 |
| Forerunner 965 | 454×454 AMOLED | 与 970 共用资源 |
| Forerunner 955 | 260×260 MIP | 独立小字号；不用全屏纸纹，避免 128KB 表盘内存爆掉 |
| Forerunner 255 / 255 Music | 260×260 MIP | 与 955 共用资源 |
| Enduro 3 | 280×280 MIP | 默认 `resources/` |

Connect IQ `minApiLevel`：**5.0.0**

## 功能

- 时间、日期、电量；秒数用小字叠在 **SATISFY** 上方
- 四行数据，点按该区域切换两页
  - 第一页：步数 / 热量 / 身体电量 / 心率
  - 第二页：周跑量 / 强度活动时间 / 训练状态 / 恢复时间
- 日出或日落（过了日出显示日落，过了日落显示次日日出）
- 白天弧上实心圆标
- 底部气温，单位写成 ℃ / ℉
- 充电时顶部闪电为实心
- 点按 **SATISFY** 切换浅色 / 反色

## 编译

需要 [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) 和 JDK 11+。

```bash
cd TacticalFace
./build.sh          # Forerunner 970
./build.sh fr965
./build.sh fr955
./build.sh fr255
./build.sh enduro3
```

首次编译若没有密钥，脚本会在 `keys/` 生成 `developer_key.der`（已 gitignore，不要提交）。

产物：`TacticalFace/bin/TacticalFace-<device>.prg`

## 模拟器

```bash
"$SDK/bin/connectiq"
"$SDK/bin/monkeydo" TacticalFace/bin/TacticalFace-fr970.prg fr970
"$SDK/bin/monkeydo" TacticalFace/bin/TacticalFace-fr955.prg fr955
"$SDK/bin/monkeydo" TacticalFace/bin/TacticalFace-fr255.prg fr255
```

`monkeydo` 需保持连接，断开后面盘会从模拟器卸下。

## 安装到手表

1. 退出 Garmin Express（会占住 MTP）
2. USB 用 OpenMTP / Android File Transfer 打开手表
3. 把**对应机型**的 `.prg` 拷到 `GARMIN/APPS/`
4. 手表长按 UP → 表盘，滚到最后选 **TACTICAL MONO**

不要把 970 的包拷到 955 / 255 上，机型不对会直接 IQ 感叹号。

## 许可证

MIT。见 [LICENSE](LICENSE)。
