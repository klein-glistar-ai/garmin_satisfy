import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Math;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Position;
import Toybox.Weather;

class TacticalFaceView extends WatchUi.WatchFace {

    private const BG = 0xAAAAAA;
    private const FG = 0x000000;

    // 坐标全部按 COROS 官方原图 (426px) 实测换算到 280 基准
    private const ARC_R   = 132;   // 顶部虚线弧半径
    private const ARC_PEN = 4;
    private const BOLT_X  = 117;   // ⚡ 图标左边
    private const BOLT_Y  = 24;    // ⚡ 组 ink 顶
    private const NUM_X   = 129;   // ⚡ 数字左边
    private const DATE_X  = 34;  private const DATE_Y = 55;
    private const TIME_X  = 26;  private const TIME_Y = 74;
    private const SAT_X   = 197; private const SAT_Y  = 104;
    private const ROW_X   = 25;  private const VAL_X  = 196;
    private const ROW_Y0  = 129; private const ROW_DY = 19;
    private const BAND    = 208;
    private const SUN_Y   = 210;   // 日落行 ink 顶
    private const ADV_MD  = 13;

    private var _w as Number = 280; private var _h as Number = 280;
    private var _cx as Number = 140; private var _cy as Number = 140;
    private var _scale as Float = 1.0;

    private var _fTime as FontResource? = null;
    private var _fMd as FontResource? = null;
    private var _fSm as FontResource? = null;
    private var _band as BitmapResource? = null;

    private var _bbId as Complications.Id? = null;      // BODY BATTERY
    private var _stressId as Complications.Id? = null;  // STRESS
    private var _runId as Complications.Id? = null;     // WEEKLY RUN（米）
    private var _riseId as Complications.Id? = null;    // 日出（当日零点起秒数）
    private var _setId as Complications.Id? = null;     // 日落
    private var _bb as Number? = null;
    private var _stress as Number? = null;
    private var _run as Float? = null;
    private var _riseSec as Number? = null;
    private var _setSec as Number? = null;
    private var _scanAt as Number = 0;

    private var _sunrise as Time.Moment? = null;
    private var _sunset as Time.Moment? = null;
    private var _sunDay as Number = -1;

    private const DOW = ["SUN","MON","TUE","WED","THU","FRI","SAT"];

    function initialize() { WatchFace.initialize(); }

    function onLayout(dc as Dc) as Void {
        _w = dc.getWidth(); _h = dc.getHeight();
        _cx = _w / 2; _cy = _h / 2;
        _scale = (_w < _h ? _w : _h).toFloat() / 280.0;
        _fTime = WatchUi.loadResource(Rez.Fonts.MonoTime) as FontResource;
        _fMd = WatchUi.loadResource(Rez.Fonts.MonoMd) as FontResource;
        _fSm = WatchUi.loadResource(Rez.Fonts.MonoSm) as FontResource;
        _band = WatchUi.loadResource(Rez.Drawables.BandBmp) as BitmapResource;
        scanComplications();
    }
    function onShow() as Void {}
    function onHide() as Void {}
    function onExitSleep() as Void {}
    function onEnterSleep() as Void {}

    // ---------------- Complications ----------------
    private function scanComplications() as Void {
        if (!(Toybox has :Complications)) { return; }
        try {
            var it = Complications.getComplications();
            var c = it.next();
            while (c != null) {
                var t = c.getType();
                if (t == Complications.COMPLICATION_TYPE_BODY_BATTERY)          { _bbId = c.complicationId; }
                else if (t == Complications.COMPLICATION_TYPE_STRESS)           { _stressId = c.complicationId; }
                else if (t == Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE) { _runId = c.complicationId; }
                else if (t == Complications.COMPLICATION_TYPE_SUNRISE)          { _riseId = c.complicationId; }
                else if (t == Complications.COMPLICATION_TYPE_SUNSET)           { _setId = c.complicationId; }
                c = it.next();
            }
        } catch (e) {}
    }

    private function readNum(id as Complications.Id?) as Number? {
        if (id == null) { return null; }
        try {
            var c = Complications.getComplication(id);
            if (c != null && c.value instanceof Number) { return c.value as Number; }
        } catch (e) {}
        return null;
    }

    private function refresh(now as Number) as Void {
        if (!(Toybox has :Complications)) { return; }
        if (now - _scanAt > 300) {
            _scanAt = now;
            if (_bbId == null || _stressId == null ||
                _runId == null || _riseId == null || _setId == null) { scanComplications(); }
        }
        var v = readNum(_bbId);      if (v != null) { _bb = v; }
        v = readNum(_stressId);      if (v != null) { _stress = v; }
        v = readNum(_riseId);        if (v != null) { _riseSec = v; }
        v = readNum(_setId);         if (v != null) { _setSec = v; }
        if (_runId != null) {
            try {
                var c = Complications.getComplication(_runId);
                if (c != null && c.value != null) {
                    if (c.value instanceof Float)       { _run = c.value as Float; }
                    else if (c.value instanceof Number) { _run = (c.value as Number).toFloat(); }
                }
            } catch (e) {}
        }
    }

    private function refreshSun(now as Time.Moment, today as Number) as Void {
        if (_sunDay == today) { return; }
        if (!(Toybox has :Position) || !(Toybox has :Weather)) { return; }
        try {
            var loc = Position.getInfo().position;
            if (loc == null) { return; }
            _sunrise = Weather.getSunrise(loc, now);
            _sunset = Weather.getSunset(loc, now);
            _sunDay = today;
        } catch (e) {}
    }

    // ---------------- 绘制辅助 ----------------
    private function p(v as Number) as Number {
        return (v.toFloat() * _scale).toNumber();
    }

    private function textR(dc as Dc, x as Number, y as Number, f as FontResource?, s as String) as Void {
        dc.drawText(x, y, f, s, Graphics.TEXT_JUSTIFY_RIGHT);
    }
    private function textL(dc as Dc, x as Number, y as Number, f as FontResource?, s as String) as Void {
        dc.drawText(x, y, f, s, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // 在点阵上绘制：先用背景色描边形成留白，再画正文
    private function textHalo(dc as Dc, x as Number, y as Number, f as FontResource?, s as String) as Void {
        var d = p(2);
        dc.setColor(BG, Graphics.COLOR_TRANSPARENT);
        for (var i = -1; i <= 1; i++) {
            for (var j = -1; j <= 1; j++) {
                if (i != 0 || j != 0) { dc.drawText(x + i * d, y + j * d, f, s, Graphics.TEXT_JUSTIFY_LEFT); }
            }
        }
        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, f, s, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function _fSm2() as FontResource? { return _fMd; }

    private function drawTopArc(dc as Dc) as Void {
        dc.setColor(FG, BG);
        // 虚线段：14.2° 长 + 1.6° 间隔，覆盖 -39°..+22.7°
        dc.setPenWidth(p(ARC_PEN));
        var starts = [-39.0, -23.2, -7.4, 8.4];
        for (var i = 0; i < 4; i++) {
            var a0 = starts[i]; var a1 = a0 + 14.2;
            // drawArc 角度：0=3点钟、逆时针为正；本表以 12 点为 0、顺时针为正
            var d0 = (90 - a1).toNumber(); var d1 = (90 - a0).toNumber();
            dc.drawArc(_cx, _cy, p(ARC_R), Graphics.ARC_COUNTER_CLOCKWISE, d0, d1);
        }
        // 右端胶囊：同径向带的空心轮廓 (+24.2°..+39.1°)
        dc.setPenWidth(p(1));
        var ri = p(ARC_R - 2); var ro = p(ARC_R + 2);
        var c0 = (90 - 39.1).toNumber(); var c1 = (90 - 24.2).toNumber();
        dc.drawArc(_cx, _cy, ri, Graphics.ARC_COUNTER_CLOCKWISE, c0, c1);
        dc.drawArc(_cx, _cy, ro, Graphics.ARC_COUNTER_CLOCKWISE, c0, c1);
        var e0 = Math.toRadians(24.2); var e1 = Math.toRadians(39.1);
        dc.drawLine((_cx + ri * Math.sin(e0)).toNumber(), (_cy - ri * Math.cos(e0)).toNumber(),
                    (_cx + ro * Math.sin(e0)).toNumber(), (_cy - ro * Math.cos(e0)).toNumber());
        dc.drawLine((_cx + ri * Math.sin(e1)).toNumber(), (_cy - ri * Math.cos(e1)).toNumber(),
                    (_cx + ro * Math.sin(e1)).toNumber(), (_cy - ro * Math.cos(e1)).toNumber());
    }

    private function drawBolt(dc as Dc, x as Number, y as Number) as Void {
        dc.setColor(FG, BG);
        dc.fillPolygon([[x + p(6), y], [x, y + p(8)], [x + p(4), y + p(8)], [x + p(2), y + p(16)], [x + p(9), y + p(6)], [x + p(5), y + p(6)]]);
    }

    // 日落图标：实测 26x16（太阳 + 光芒 + 地平线 + 向下箭头）
    private function drawSunsetIcon(dc as Dc, x as Number, y as Number) as Void {
        dc.setColor(FG, BG);
        dc.setPenWidth(p(2));
        dc.drawCircle(x, y - p(3), p(3));                       // 太阳
        dc.drawLine(x, y - p(10), x, y - p(8));                 // 顶部光芒
        dc.drawLine(x - p(7), y - p(7), x - p(5), y - p(5));    // 左上光芒
        dc.drawLine(x + p(7), y - p(7), x + p(5), y - p(5));    // 右上光芒
        dc.drawLine(x - p(9), y + p(2), x + p(9), y + p(2));    // 地平线
        dc.setPenWidth(p(1));
        dc.fillPolygon([[x, y + p(7)], [x - p(3), y + p(4)], [x + p(3), y + p(4)]]);
    }

    private function hhmm(m as Time.Moment?) as String {
        if (m == null) { return "--:--"; }
        var i = Gregorian.info(m as Time.Moment, Time.FORMAT_SHORT);
        return (i.hour as Number).format("%02d") + ":" + (i.min as Number).format("%02d");
    }

    // ---------------- 主绘制 ----------------
    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var ds = System.getDeviceSettings();
        refresh(now.value());
        refreshSun(now, info.day as Number);

        // 圆外保持黑色，和参考图的圆形表盘边界一致。
        dc.setColor(FG, FG);
        dc.clear();
        dc.setColor(BG, BG);
        dc.fillCircle(_cx, _cy, ((_w < _h ? _w : _h) / 2).toNumber());
        dc.setColor(FG, BG);

        drawTopArc(dc);

        // ---- ⚡ + 电池电量 ----
        var battStr = System.getSystemStats().battery.format("%d");
        drawBolt(dc, p(BOLT_X), p(BOLT_Y));
        textL(dc, p(NUM_X), p(BOLT_Y), _fMd, battStr);

        // ---- 日期 ----
        var dateStr = DOW[(info.day_of_week as Number) - 1] + "." +
                      (info.day as Number).format("%02d") + "." +
                      (info.month as Number).format("%02d");
        textL(dc, p(DATE_X), p(DATE_Y), _fMd, dateStr);

        // ---- 时间 ----
        var hour = clock.hour;
        if (!ds.is24Hour) { hour = hour % 12; if (hour == 0) { hour = 12; } }
        textL(dc, p(TIME_X), p(TIME_Y), _fTime, hour.format("%02d") + ":" + clock.min.format("%02d"));
        textL(dc, p(SAT_X), p(SAT_Y), _fSm, "SATISFY");

        // ---- 四行数据（数值左对齐于同一列，与原图一致）----
        var runStr = "--";
        if (_run != null) { runStr = ((_run as Float) / 1000.0).format("%.0f") + "KM"; }
        var elevStr = "--";
        var am = ActivityMonitor.getInfo();
        if (am != null && am.metersClimbed != null) { elevStr = (am.metersClimbed as Float).format("%.0f"); }
        var bodyStr = (_bb == null) ? "--" : (_bb as Number).format("%d") + "%";
        var strStr = (_stress == null) ? "--" : (_stress as Number).format("%d");
        var labels = ["WEEKLY RUN", "ELEV. GAIN", "BODY BATT", "STRESS"];
        var values = [runStr, elevStr, bodyStr, strStr];
        for (var i = 0; i < 4; i++) {
            var ry = p(ROW_Y0 + i * ROW_DY);
            textL(dc, p(ROW_X), ry, _fSm2(), labels[i]);
            textL(dc, p(VAL_X), ry, _fSm2(), values[i]);
        }

        // ---- 底部网点带 + 日落 ----
        if (_band != null) { dc.drawBitmap(0, p(BAND), _band); }
        // 太阳球：沿穹顶弧线随昼间进度移动（圆心 140,487 半径 241）
        var nv = now.value();
        var showSet = true;
        // 当日零点的绝对秒数，用于把 Complication 的"零点起秒数"还原成时刻
        var midnight = nv - (clock.hour * 3600 + clock.min * 60 + clock.sec);
        var srAbs = null; var ssAbs = null;
        if (_riseSec != null && _setSec != null) {
            srAbs = midnight + (_riseSec as Number);
            ssAbs = midnight + (_setSec as Number);
        } else if (_sunrise != null && _sunset != null) {
            srAbs = (_sunrise as Time.Moment).value();
            ssAbs = (_sunset as Time.Moment).value();
        }
        if (srAbs != null && ssAbs != null) {
            var sr = srAbs as Number; var ss = ssAbs as Number;
            if (ss > sr && nv >= sr && nv <= ss) {
                var f = (nv - sr).toFloat() / (ss - sr).toFloat();
                // 沿弧线移动（R=78，圆心 y=316，可见跨度 ±58）
                var dxu = (-58 + 116 * f).toNumber();
                var dyu = (316 - Math.sqrt((78 * 78 - dxu * dxu).toFloat())).toNumber();
                var bxx = p(dxu); var byy = p(dyu);
                dc.setColor(FG, BG);
                dc.fillCircle(_cx + bxx, byy, p(4));                        // 黑环
                dc.setColor(Graphics.COLOR_WHITE, BG);
                dc.fillCircle(_cx + bxx, byy, p(2));                        // 白心
            } else {
                showSet = false;                     // 夜间 → 显示下一次日出
            }
        }
        var sunStr = "--:--";
        if (_riseSec != null && _setSec != null) {
            var sec = showSet ? (_setSec as Number) : (_riseSec as Number);
            sunStr = (sec / 3600).format("%02d") + ":" + ((sec % 3600) / 60).format("%02d");
        } else {
            sunStr = showSet ? hhmm(_sunset) : hhmm(_sunrise);
        }
        // 日落图标 + 时间，整组居中（图标 26px + 间隔 4px + 文字）
        var tw = p(30 + sunStr.length() * ADV_MD);
        var sx = _cx - tw / 2;
        drawSunsetIcon(dc, sx + p(11), p(SUN_Y + 8));
        textHalo(dc, sx + p(28), p(SUN_Y), _fMd, sunStr);
    }
}
