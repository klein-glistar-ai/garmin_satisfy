import Toybox.Application;
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

    private const BG_LIGHT = 0xC4BA9D;  // 暖卡其纸色
    private const FG_LIGHT = 0x000000;
    private const BG_INV   = 0x000000;  // 纸色反转
    private const FG_INV   = 0xC4BA9D;

    // 坐标全部按 COROS 官方原图 (426px) 实测换算到 280 基准
    private const ARC_R   = 132;   // 顶部虚线弧半径
    private const ARC_PEN = 4;
    private const BOLT_Y  = 24;    // ⚡ 组 ink 顶
    private const DATE_Y  = 55;
    private const TIME_X  = 26;  private const TIME_Y = 74;
    private const SAT_Y   = 104;
    private const ROW_X   = 25;  private const VAL_X  = 196;
    private const ROW_Y0  = 129;
    private const BAND    = 208;
    private const SUN_Y   = 210;   // 日落行 ink 顶
    private const TEMP_Y  = 248;   // 底部气温

    private var _w as Number = 280; private var _h as Number = 280;
    private var _cx as Number = 140; private var _cy as Number = 140;
    private var _scale as Float = 1.0;
    private var _hi as Boolean = false;
    private var _dateY as Number = DATE_Y;
    private var _timeX as Number = TIME_X;
    private var _timeY as Number = TIME_Y;
    private var _rowX as Number = ROW_X;
    private var _valX as Number = VAL_X;
    private var _rowY0 as Number = ROW_Y0;
    private var _bandY as Number = BAND;
    private var _sunTextY as Number = SUN_Y;
    private var _tempY as Number = TEMP_Y;
    private var _valRight as Boolean = false;
    private var _rowStep as Number = 0;

    private var _fTime as FontResource? = null;
    private var _fMd as FontResource? = null;
    private var _fSm as FontResource? = null;
    private var _band as BitmapResource? = null;
    private var _bandInv as BitmapResource? = null;
    private var _paper as BitmapResource? = null;
    private var _paperInv as BitmapResource? = null;
    private var _invert as Boolean = false;
    private var _bg as Number = BG_LIGHT;
    private var _fg as Number = FG_LIGHT;
    private var _hole as Number = 0xFFFFFF;

    private var _bbId as Complications.Id? = null;      // BODY BATTERY
    private var _stressId as Complications.Id? = null;  // STRESS
    private var _runId as Complications.Id? = null;     // WEEKLY RUN（米）
    private var _riseId as Complications.Id? = null;    // 日出（当日零点起秒数）
    private var _setId as Complications.Id? = null;     // 日落
    private var _hrId as Complications.Id? = null;
    private var _recId as Complications.Id? = null;
    private var _readyId as Complications.Id? = null;
    private var _tempId as Complications.Id? = null;
    private var _intId as Complications.Id? = null;
    private var _statusId as Complications.Id? = null;
    private var _bb as Number? = null;
    private var _stress as Number? = null;
    private var _run as Float? = null;
    private var _riseSec as Number? = null;
    private var _setSec as Number? = null;
    private var _hr as Number? = null;
    private var _rec as Number? = null;
    private var _ready as Number? = null;
    private var _temp as Number? = null;
    private var _intMin as Number? = null;
    private var _status as String? = null;
    private var _scanAt as Number = 0;
    private var _page as Number = 0;
    private var _statusTries as Number = 0;
    private var _statusSub as Boolean = false;

    private var _sunrise as Time.Moment? = null;
    private var _sunset as Time.Moment? = null;
    private var _sunriseNext as Time.Moment? = null;
    private var _sunDay as Number = -1;
    private var _wxAt as Number = 0;
    private var _compAt as Number = 0;
    private var _didScan as Boolean = false;
    private var _simple as Boolean = false;

    private const DOW = ["SUN","MON","TUE","WED","THU","FRI","SAT"];

    function initialize() {
        WatchFace.initialize();
        try {
            var v = Application.Storage.getValue("metricPage");
            if ((v instanceof Number) && ((v as Number) == 1)) { _page = 1; }
        } catch (e) {}
    }

    function onLayout(dc as Dc) as Void {
        _w = dc.getWidth(); _h = dc.getHeight();
        _cx = _w / 2; _cy = _h / 2;
        _scale = (_w < _h ? _w : _h).toFloat() / 280.0;
        _hi = _w >= 400;
        if (_hi) {
            _dateY = 48;
            _timeX = 22; _timeY = 72;
            _rowX = 30; _valX = 250;
            _rowY0 = 132;
            _bandY = 218; _sunTextY = 218; _tempY = 254;
            _valRight = true;
        } else {
            _dateY = 46;
            _timeX = 22; _timeY = 64;
            _rowX = ROW_X; _valX = VAL_X;
            _rowY0 = ROW_Y0;
            _bandY = BAND; _sunTextY = SUN_Y; _tempY = TEMP_Y;
            _valRight = false;
        }
        if (_fTime == null) {
            _fTime = WatchUi.loadResource(Rez.Fonts.MonoTime) as FontResource;
            _fMd = WatchUi.loadResource(Rez.Fonts.MonoMd) as FontResource;
            _fSm = WatchUi.loadResource(Rez.Fonts.MonoSm) as FontResource;
        }
        _rowStep = 0;
        if (!_hi) {
            var timeBottom = p(_timeY) + dc.getFontHeight(_fTime);
            var rowStart = timeBottom + 4;
            _rowY0 = (rowStart.toFloat() / _scale).toNumber();
            var mdH = dc.getFontHeight(_fMd);
            var room = p(_bandY) - 2 - rowStart;
            var step = (room - mdH) / 3;
            if (step < mdH) { step = mdH; }
            _rowStep = step;
        }
        applyTheme();
        loadThemeBitmaps();
    }

    // 只留当前主题的图。MIP 不加载全屏纸纹；970 也不再同时解码两套 454 纸纹。
    private function loadThemeBitmaps() as Void {
        try {
            if (_invert) {
                _band = null;
                _paper = null;
                if (_bandInv == null) {
                    _bandInv = WatchUi.loadResource(Rez.Drawables.BandBmpInv) as BitmapResource;
                }
                if (_hi && _paperInv == null) {
                    _paperInv = WatchUi.loadResource(Rez.Drawables.PaperBgInv) as BitmapResource;
                }
            } else {
                _bandInv = null;
                _paperInv = null;
                if (_band == null) {
                    _band = WatchUi.loadResource(Rez.Drawables.BandBmp) as BitmapResource;
                }
                if (_hi && _paper == null) {
                    _paper = WatchUi.loadResource(Rez.Drawables.PaperBg) as BitmapResource;
                }
            }
            if (!_hi) {
                _paper = null;
                _paperInv = null;
            }
        } catch (e) {
            _band = null;
            _bandInv = null;
            if (!_hi) {
                _paper = null;
                _paperInv = null;
            }
        }
    }

    function trimForBudget() as Void {
        _simple = true;
        if (!_hi) {
            _paper = null;
            _paperInv = null;
            _band = null;
            _bandInv = null;
        }
    }

    private function applyTheme() as Boolean {
        var prev = _invert;
        _invert = false;
        try {
            var v = Application.Properties.getValue("invert");
            if (v instanceof Boolean) { _invert = v as Boolean; }
            else if (v instanceof Number) { _invert = (v as Number) != 0; }
        } catch (e) {}
        if (_invert) {
            _bg = BG_INV;
            _fg = FG_INV;
            _hole = BG_INV;
        } else {
            _bg = BG_LIGHT;
            _fg = FG_LIGHT;
            _hole = 0xFFFFFF;
        }
        return prev != _invert;
    }

    // SATISFY 所在右上区域：点按切换浅色/反色
    function hitThemeToggle(x as Number, y as Number) as Boolean {
        var y0 = p(_timeY) - 10;
        var y1 = p(_rowY0) - 4;
        return (x > (_w / 2)) && (y >= y0) && (y <= y1);
    }

    // 四行数据区域：点按切换两页指标（表盘收不到真正的双击）
    function hitMetricRows(x as Number, y as Number) as Boolean {
        var y0 = p(_rowY0) - 6;
        var y1 = p(_bandY) - 2;
        return (y >= y0) && (y <= y1);
    }

    function toggleMetricPage() as Void {
        _page = (_page == 0) ? 1 : 0;
        try { Application.Storage.setValue("metricPage", _page); } catch (e) {}
        WatchUi.requestUpdate();
    }

    function toggleInvert() as Void {
        applyTheme();
        Application.Properties.setValue("invert", !_invert);
        applyTheme();
        loadThemeBitmaps();
        WatchUi.requestUpdate();
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
                else if (t == Complications.COMPLICATION_TYPE_INTENSITY_MINUTES) { _intId = c.complicationId; }
                else if (t == Complications.COMPLICATION_TYPE_TRAINING_STATUS) { _statusId = c.complicationId; }
                else if ((Complications has :COMPLICATION_TYPE_HEART_RATE) && t == Complications.COMPLICATION_TYPE_HEART_RATE) { _hrId = c.complicationId; }
                else if ((Complications has :COMPLICATION_TYPE_RECOVERY_TIME) && t == Complications.COMPLICATION_TYPE_RECOVERY_TIME) { _recId = c.complicationId; }
                else if ((Complications has :COMPLICATION_TYPE_TRAINING_READINESS) && t == Complications.COMPLICATION_TYPE_TRAINING_READINESS) { _readyId = c.complicationId; }
                else if ((Complications has :COMPLICATION_TYPE_CURRENT_TEMPERATURE) && t == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE) { _tempId = c.complicationId; }
                c = it.next();
            }
        } catch (e) {}
        if (_statusId == null) {
            try { _statusId = new Complications.Id(Complications.COMPLICATION_TYPE_TRAINING_STATUS); } catch (e) {}
        }
        subscribeStatus();
    }

    private function subscribeStatus() as Void {
        if (_statusSub || _statusId == null) { return; }
        try {
            Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
            Complications.subscribeToUpdates(_statusId);
            _statusSub = true;
        } catch (e) {}
    }

    function onComplicationChanged(id as Complications.Id) as Void {
        readStatus();
        WatchUi.requestUpdate();
    }

    private function readStatus() as Void {
        if (_statusId == null) { return; }
        try {
            var c = Complications.getComplication(_statusId);
            if (c != null && c.value instanceof String) {
                var s = c.value as String;
                if (s.length() > 0) { _status = statusAbbrev(s); }
            }
        } catch (e) {}
    }

    // 点阵字体只有 A–Z，中文训练状态要映射成英文缩写
    private function statusAbbrev(s as String) as String {
        var u = s.toUpper();
        if (u.find("UNPRODUCTIVE") != null || s.find("无效") != null) { return "UNP"; }
        if (u.find("PRODUCTIVE") != null || s.find("高效") != null || s.find("有成效") != null) { return "PROD"; }
        if (u.find("MAINTAIN") != null || s.find("保持") != null || s.find("维持") != null) { return "MNT"; }
        if (u.find("PEAK") != null || s.find("巅峰") != null || s.find("高峰") != null) { return "PEAK"; }
        if (u.find("DETRAIN") != null || s.find("下降") != null || s.find("退步") != null) { return "DET"; }
        if (u.find("OVERREACH") != null || u.find("STRAIN") != null || s.find("过度") != null || s.find("力竭") != null) { return "STR"; }
        if (u.find("RECOVERY") != null || s.find("恢复") != null) { return "REC"; }
        if (u.find("NO RESULT") != null || u.find("NO STATUS") != null || s.find("无状态") != null || s.find("无结果") != null) { return "--"; }
        return "--";
    }

    private function readNum(id as Complications.Id?) as Number? {
        if (id == null) { return null; }
        try {
            var c = Complications.getComplication(id);
            if (c != null) { return asTemp(c.value); }
        } catch (e) {}
        return null;
    }

    // Weather / Complication 的气温可能是 Number 或 Float
    private function asTemp(v as Object?) as Number? {
        if (v instanceof Number) { return v as Number; }
        if (v instanceof Float) { return Math.round(v as Float).toNumber(); }
        return null;
    }

    private function refresh(now as Number) as Void {
        if (!(Toybox has :Complications)) { return; }
        if (!_didScan) {
            scanComplications();
            _didScan = true;
            _scanAt = now;
        } else if ((_statusId == null || _status == null) && _statusTries < 8 && (now - _scanAt >= 45)) {
            scanComplications();
            _statusTries = _statusTries + 1;
            _scanAt = now;
        } else if ((now - _scanAt > 1800) &&
            (_bbId == null || _riseId == null || _setId == null || _tempId == null)) {
            scanComplications();
            _scanAt = now;
        }
        if (_compAt != 0 && (now - _compAt < 60)) { return; }
        _compAt = now;
        var v = readNum(_bbId);      if (v != null) { _bb = v; }
        v = readNum(_stressId);      if (v != null) { _stress = v; }
        v = readNum(_riseId);        if (v != null) { _riseSec = v; }
        v = readNum(_setId);         if (v != null) { _setSec = v; }
        v = readNum(_hrId);          if (v != null) { _hr = v; }
        v = readNum(_recId);         if (v != null) { _rec = v; }
        v = readNum(_readyId);       if (v != null) { _ready = v; }
        v = readNum(_intId);         if (v != null) { _intMin = v; }
        readStatus();
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
            _sunriseNext = Weather.getSunrise(loc, now.add(new Time.Duration(86400)));
            _sunDay = today;
        } catch (e) {}
    }

    private function refreshWeather(now as Number) as Void {
        var wait = (_temp != null) ? 600 : 60;
        if (_wxAt != 0 && (now - _wxAt < wait)) { return; }
        _wxAt = now;
        var t = null;
        if (Toybox has :Weather) {
            try {
                var cur = Weather.getCurrentConditions();
                if (cur != null) {
                    t = asTemp(cur.temperature);
                    if (t == null) { t = asTemp(cur.feelsLikeTemperature); }
                }
            } catch (e) {}
            // MIP 表盘内存只有 128KB，小时/逐日预报数组会直接 OOM
            if (_hi && t == null && (Weather has :getHourlyForecast)) {
                try {
                    var hrs = Weather.getHourlyForecast();
                    if (hrs != null && hrs.size() > 0) {
                        t = asTemp(hrs[0].temperature);
                    }
                } catch (e) {}
            }
            if (_hi && t == null && (Weather has :getDailyForecast)) {
                try {
                    var days = Weather.getDailyForecast();
                    if (days != null && days.size() > 0) {
                        t = asTemp(days[0].highTemperature);
                    }
                } catch (e) {}
            }
        }
        if (t == null) { t = readNum(_tempId); }
        if (t != null) { _temp = t as Number; }
    }

    private function tempNumStr(ds as System.DeviceSettings) as String {
        if (_temp == null) { return "--"; }
        var c = _temp as Number;
        if (ds.temperatureUnits == System.UNIT_STATUTE) {
            return ((c * 9) / 5 + 32).format("%d");
        }
        return c.format("%d");
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

    private function textSpacedW(dc as Dc, f as FontResource?, s as String, extra as Number) as Number {
        var n = s.length();
        return dc.getTextWidthInPixels(s, f) + extra * (n - 1);
    }

    private function textSpacedR(dc as Dc, x as Number, y as Number, f as FontResource?, s as String, extra as Number) as Void {
        var n = s.length();
        var w = textSpacedW(dc, f, s, extra);
        var cx = x - w;
        var i = 0;
        while (i < n) {
            var ch = s.substring(i, i + 1);
            dc.drawText(cx, y, f, ch, Graphics.TEXT_JUSTIFY_LEFT);
            cx = cx + dc.getTextWidthInPixels(ch, f) + extra;
            i = i + 1;
        }
    }

    // 在点阵上绘制：先用背景色描边形成留白，再画正文
    private function textHalo(dc as Dc, x as Number, y as Number, f as FontResource?, s as String) as Void {
        if (!_hi || _simple) {
            dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, f, s, Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }
        var d = 1;
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        for (var i = -1; i <= 1; i++) {
            for (var j = -1; j <= 1; j++) {
                if (i != 0 || j != 0) { dc.drawText(x + i * d, y + j * d, f, s, Graphics.TEXT_JUSTIFY_LEFT); }
            }
        }
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, f, s, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawDegree(dc as Dc, cx as Number, cy as Number, r as Number) as Void {
        if (!_hi || _simple) {
            dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawCircle(cx, cy, r);
            return;
        }
        dc.setPenWidth(2);
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r + 1);
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
    }

    private function drawTemperature(dc as Dc, ds as System.DeviceSettings) as Void {
        var num = tempNumStr(ds);
        var unit = (ds.temperatureUnits == System.UNIT_STATUTE) ? "F" : "C";
        var numW = dc.getTextWidthInPixels(num, _fMd);
        var unitW = dc.getTextWidthInPixels(unit, _fMd);
        var degR = _hi ? 3 : 2;
        var degGap = _hi ? 4 : 2;
        var unitGap = _hi ? 2 : 1;
        var total = numW + degGap + degR * 2 + unitGap + unitW;
        var x = _cx - total / 2;
        var y = p(_tempY);
        textHalo(dc, x, y, _fMd, num);
        var cx = x + numW + degGap + degR;
        var cy = y + dc.getFontHeight(_fMd) / 4;
        drawDegree(dc, cx, cy, degR);
        textHalo(dc, x + numW + degGap + degR * 2 + unitGap, y, _fMd, unit);
    }

    private function rowMetric(i as Number) as Number {
        if (_page == 1) {
            if (i == 0) { return 0; }
            if (i == 1) { return 11; }
            if (i == 2) { return 12; }
            return 9;
        }
        if (i == 0) { return 4; }
        if (i == 1) { return 5; }
        if (i == 2) { return 2; }
        return 6;
    }

    private function metricLabel(id as Number) as String {
        if (id == 1) { return "ELEV. GAIN"; }
        if (id == 2) { return "BODY BATT"; }
        if (id == 3) { return "STRESS"; }
        if (id == 4) { return "STEPS"; }
        if (id == 5) { return "CALORIES"; }
        if (id == 6) { return "HEART RATE"; }
        if (id == 7) { return "FLOORS"; }
        if (id == 8) { return "DISTANCE"; }
        if (id == 9) { return "RECOVERY"; }
        if (id == 10) { return "READINESS"; }
        if (id == 11) { return "INTENSITY"; }
        if (id == 12) { return "TRAINING"; }
        return "WEEKLY RUN";
    }

    private function metricValue(id as Number, am as ActivityMonitor.Info?) as String {
        if (id == 1) {
            if (am != null && am.metersClimbed != null) { return (am.metersClimbed as Float).format("%.0f"); }
            return "--";
        }
        if (id == 2) { return (_bb == null) ? "--" : (_bb as Number).format("%d") + "%"; }
        if (id == 3) { return (_stress == null) ? "--" : (_stress as Number).format("%d"); }
        if (id == 4) {
            if (am != null && am.steps != null) { return (am.steps as Number).format("%d"); }
            return "--";
        }
        if (id == 5) {
            if (am != null && am.calories != null) { return (am.calories as Number).format("%d"); }
            return "--";
        }
        if (id == 6) {
            var act = Activity.getActivityInfo();
            if (act != null && act.currentHeartRate != null) { return (act.currentHeartRate as Number).format("%d") + "BPM"; }
            return (_hr == null) ? "--" : (_hr as Number).format("%d") + "BPM";
        }
        if (id == 7) {
            if (am != null && am.floorsClimbed != null) { return (am.floorsClimbed as Number).format("%d"); }
            return "--";
        }
        if (id == 8) {
            if (am != null && am.distance != null) {
                return ((am.distance as Float) / 100000.0).format("%.1f") + "KM";
            }
            return "--";
        }
        if (id == 9) {
            if (_rec == null) { return "--"; }
            var min = _rec as Number;
            if (min >= 60) { return (min / 60).format("%d") + "H"; }
            return min.format("%d") + "M";
        }
        if (id == 10) { return (_ready == null) ? "--" : (_ready as Number).format("%d"); }
        if (id == 11) {
            if (_intMin != null) { return (_intMin as Number).format("%d"); }
            if (am != null && am.activeMinutesWeek != null) {
                var w = am.activeMinutesWeek as ActivityMonitor.ActiveMinutes;
                return (w.moderate + w.vigorous * 2).format("%d");
            }
            return "--";
        }
        if (id == 12) { return (_status == null) ? "--" : (_status as String); }
        if (_run != null) { return ((_run as Float) / 1000.0).format("%.0f") + "KM"; }
        return "--";
    }

    private function drawTopArc(dc as Dc) as Void {
        dc.setColor(_fg, _bg);
        // 5 道等长虚线，以 12 点为中心对称
        dc.setPenWidth(_hi ? 2 : p(ARC_PEN));
        var dash = 10.5;
        var gap = 3.0;
        var n = 5;
        var total = n * dash + (n - 1) * gap;
        var a = -total / 2.0;
        var r = p(ARC_R);
        for (var i = 0; i < n; i++) {
            var a0 = a;
            var a1 = a + dash;
            var d0 = (90.0 - a1).toNumber();
            var d1 = (90.0 - a0).toNumber();
            dc.drawArc(_cx, _cy, r, Graphics.ARC_COUNTER_CLOCKWISE, d0, d1);
            a = a + dash + gap;
        }
    }

    // 空心线稿闪电；充电时填实。宽约 10、高约 16（280 基准）
    private function drawBolt(dc as Dc, x as Number, y as Number, solid as Boolean) as Void {
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_hi ? 2 : p(2));
        var x1 = x + p(6);
        var y2 = y + p(8);
        var x3 = x + p(4);
        var x4 = x + p(2);
        var y4 = y + p(16);
        var x5 = x + p(9);
        var y5 = y + p(6);
        var x6 = x + p(5);
        if (solid && (dc has :fillPolygon)) {
            dc.fillPolygon([
                [x1, y] as [Numeric, Numeric],
                [x, y2] as [Numeric, Numeric],
                [x3, y2] as [Numeric, Numeric],
                [x4, y4] as [Numeric, Numeric],
                [x5, y5] as [Numeric, Numeric],
                [x6, y5] as [Numeric, Numeric]
            ] as Array<[Numeric, Numeric]>);
        }
        dc.drawLine(x1, y, x, y2);
        dc.drawLine(x, y2, x3, y2);
        dc.drawLine(x3, y2, x4, y4);
        dc.drawLine(x4, y4, x5, y5);
        dc.drawLine(x5, y5, x6, y5);
        dc.drawLine(x6, y5, x1, y);
    }

    // 日出/日落图标（网点上用背景色描一圈，避免一块实心底）
    private function drawSunIcon(dc as Dc, x as Number, y as Number, isSet as Boolean) as Void {
        var d = _hi ? 1 : p(1);
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        for (var i = -1; i <= 1; i++) {
            for (var j = -1; j <= 1; j++) {
                if (i != 0 || j != 0) { drawSunGlyph(dc, x + i * d, y + j * d, isSet); }
            }
        }
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        drawSunGlyph(dc, x, y, isSet);
    }

    private function drawSunGlyph(dc as Dc, x as Number, y as Number, isSet as Boolean) as Void {
        dc.setPenWidth(_hi ? 2 : p(2));
        dc.fillCircle(x, y - p(3), _hi ? 3 : p(3));
        dc.drawLine(x, y - p(10), x, y - p(8));
        dc.drawLine(x - p(7), y - p(7), x - p(5), y - p(5));
        dc.drawLine(x + p(7), y - p(7), x + p(5), y - p(5));
        dc.drawLine(x - p(9), y + p(2), x + p(9), y + p(2));
        if (isSet) {
            dc.drawLine(x, y + p(7), x - p(3), y + p(4));
            dc.drawLine(x - p(3), y + p(4), x + p(3), y + p(4));
            dc.drawLine(x + p(3), y + p(4), x, y + p(7));
        } else {
            dc.drawLine(x, y + p(3), x - p(3), y + p(6));
            dc.drawLine(x - p(3), y + p(6), x + p(3), y + p(6));
            dc.drawLine(x + p(3), y + p(6), x, y + p(3));
        }
    }

    // 日出日落弧：AMOLED 上用抗锯齿画，避免底带点阵放大后的锯齿
    private function drawSunArc(dc as Dc) as Void {
        var r = (80.0 * _scale).toNumber();
        var cy = (321.0 * _scale).toNumber();
        var rise = 52.915 * _scale;
        var span = 60.0 * _scale;
        var a0 = Math.toDegrees(Math.atan2(rise, span)).toNumber();
        var a1 = Math.toDegrees(Math.atan2(rise, -span)).toNumber();
        dc.setColor(_bg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(5);
        dc.drawArc(_cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, a0, a1);
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(_cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, a0, a1);
    }

    private function hhmm(m as Time.Moment?) as String {
        if (m == null) { return "--:--"; }
        var i = Gregorian.info(m as Time.Moment, Time.FORMAT_SHORT);
        return (i.hour as Number).format("%02d") + ":" + (i.min as Number).format("%02d");
    }

    private function secToHm(sec as Number?, m as Time.Moment?) as String {
        if (sec != null) {
            var s = sec as Number;
            return (s / 3600).format("%02d") + ":" + ((s % 3600) / 60).format("%02d");
        }
        return hhmm(m);
    }

    // ---------------- 主绘制 ----------------
    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var ds = System.getDeviceSettings();
        refresh(now.value());
        refreshSun(now, info.day as Number);
        refreshWeather(now.value());
        if (applyTheme()) { loadThemeBitmaps(); }

        // 圆外保持黑色，和参考图的圆形表盘边界一致。
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (!_invert && _paper != null) {
            dc.drawBitmap(0, 0, _paper);
        } else if (_invert && _paperInv != null) {
            dc.drawBitmap(0, 0, _paperInv);
        } else {
            dc.setColor(_bg, _bg);
            dc.fillCircle(_cx, _cy, ((_w < _h ? _w : _h) / 2).toNumber());
        }
        // 盖住纸纹圆边抗锯齿漏出的浅色杂点
        if (_hi && !_simple) {
            var rim = ((_w < _h ? _w : _h) / 2).toNumber();
            if (dc has :setAntiAlias) { dc.setAntiAlias(false); }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            dc.drawCircle(_cx, _cy, rim);
            if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        }
        dc.setColor(_fg, _bg);

        if (!_simple) { drawTopArc(dc); }

        // ---- ⚡ + 电池电量（整组相对 5 道杠水平居中）----
        var stats = System.getSystemStats();
        var battStr = stats.battery.format("%d");
        var boltW = p(10);
        var boltGap = p(4);
        var battW = dc.getTextWidthInPixels(battStr, _fMd);
        var battX = _cx - (boltW + boltGap + battW) / 2;
        drawBolt(dc, battX, p(BOLT_Y), stats.charging);
        textL(dc, battX + boltW + boltGap, p(BOLT_Y), _fMd, battStr);

        // ---- 时间（加粗）+ SATISFY（加粗）----
        var hour = clock.hour;
        if (!ds.is24Hour) { hour = hour % 12; if (hour == 0) { hour = 12; } }
        var timeStr = hour.format("%02d") + ":" + clock.min.format("%02d");
        var timeX = p(_timeX);
        var timeW = dc.getTextWidthInPixels(timeStr, _fTime);
        textL(dc, timeX, p(_timeY), _fTime, timeStr);
        var satExtra = _hi ? 3 : 2;
        var satY = p(_timeY) + dc.getFontHeight(_fTime) - dc.getFontHeight(_fSm);
        var satRight = _valRight ? p(_valX) : (_w - p(_rowX));
        var satLeft = satRight - textSpacedW(dc, _fSm, "SATISFY", satExtra);
        textSpacedR(dc, satRight, satY, _fSm, "SATISFY", satExtra);

        // ---- 日期：与时间水平居中对齐 ----
        var dateStr = DOW[(info.day_of_week as Number) - 1] + "." +
                      (info.day as Number).format("%02d") + "." +
                      (info.month as Number).format("%02d");
        var dateW = dc.getTextWidthInPixels(dateStr, _fMd);
        textL(dc, timeX + (timeW - dateW) / 2, p(_dateY), _fMd, dateStr);

        // ---- 四行数据：数值左缘与 SATISFY 的 S 对齐 ----
        var am = ActivityMonitor.getInfo();
        var rowH = dc.getFontHeight(_fMd);
        var rowDy = _rowStep > 0 ? _rowStep : ((rowH.toFloat() * 12.0) / 10.0).toNumber();
        var rowY = p(_rowY0);
        for (var i = 0; i < 4; i++) {
            var mid = rowMetric(i);
            var ry = rowY + i * rowDy;
            textL(dc, p(_rowX), ry, _fMd, metricLabel(mid));
            textL(dc, satLeft, ry, _fMd, metricValue(mid, am));
        }

        // ---- 底部网点带 + 日出/日落 ----
        var band = _invert ? _bandInv : _band;
        if (band != null) { dc.drawBitmap(0, p(_bandY), band); }
        if (_hi) { drawSunArc(dc); }

        var nv = now.value();
        var midnight = nv - (clock.hour * 3600 + clock.min * 60 + clock.sec);
        var srAbs = null;
        var ssAbs = null;
        if (_riseSec != null && _setSec != null) {
            srAbs = midnight + (_riseSec as Number);
            ssAbs = midnight + (_setSec as Number);
        } else if (_sunrise != null && _sunset != null) {
            srAbs = (_sunrise as Time.Moment).value();
            ssAbs = (_sunset as Time.Moment).value();
        }

        var showSet = false;
        var sunStr = "--:--";
        var markerF = null;
        if (srAbs != null && ssAbs != null) {
            var sr = srAbs as Number;
            var ss = ssAbs as Number;
            if (nv < sr) {
                showSet = false;
                sunStr = secToHm(_riseSec, _sunrise);
            } else if (nv < ss) {
                showSet = true;
                sunStr = secToHm(_setSec, _sunset);
                if (ss > sr) {
                    markerF = (nv - sr).toFloat() / (ss - sr).toFloat();
                }
            } else {
                showSet = false;
                if (_sunriseNext != null) {
                    sunStr = hhmm(_sunriseNext);
                } else {
                    sunStr = secToHm(_riseSec, _sunrise);
                }
            }
        }

        if (markerF != null) {
            var f = markerF as Float;
            var span = _hi ? 60.0 : 58.0;
            var rr = _hi ? 80.0 : 78.0;
            var cyu = _hi ? 321.0 : 316.0;
            var dxu = -span + (2.0 * span) * f;
            var inside = rr * rr - dxu * dxu;
            if (inside < 0.0) { inside = 0.0; }
            var dyu = cyu - Math.sqrt(inside);
            var bx = _cx + (dxu * _scale).toNumber();
            var by = (dyu * _scale).toNumber();
            var rad = _hi ? 7 : p(5);
            dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(bx, by, rad);
        }

        var tw = dc.getTextWidthInPixels(sunStr, _fMd);
        var iconW = p(26);
        var gap = p(_hi ? 6 : 4);
        var boxPadX = _hi ? 8 : p(5);
        var boxPadY = _hi ? 5 : p(3);
        var boxW = iconW + gap + tw + boxPadX * 2;
        var boxH = dc.getFontHeight(_fMd) + boxPadY * 2;
        var boxX = _cx - boxW / 2;
        var boxY = p(_sunTextY) - boxPadY;
        var paper = _invert ? _paperInv : _paper;
        if (paper != null && (dc has :setClip)) {
            dc.setClip(boxX, boxY, boxW, boxH);
            dc.drawBitmap(0, 0, paper);
            dc.clearClip();
        } else {
            dc.setColor(_bg, _bg);
            dc.fillRectangle(boxX, boxY, boxW, boxH);
        }
        var sx = boxX + boxPadX;
        dc.setColor(_fg, Graphics.COLOR_TRANSPARENT);
        drawSunGlyph(dc, sx + iconW / 2, p(_sunTextY + 8), showSet);
        textL(dc, sx + iconW + gap, p(_sunTextY), _fMd, sunStr);

        drawTemperature(dc, ds);
    }
}
