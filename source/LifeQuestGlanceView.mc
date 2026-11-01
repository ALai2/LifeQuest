import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class LifeQuestGlanceView extends WatchUi.GlanceView {
    const COLOR_CYAN     = 0x00D9FF;
    const COLOR_DARK_BLU = 0x002244;
    const COLOR_RED      = 0xFF3333;
    const COLOR_DARK_RED = 0x3A0808;
    const COLOR_GREEN    = 0x00FF66;
    const COLOR_DK_GRAY  = 0x444444;

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 1. Fetch decoupled lightweight summary cache (< 180 bytes, < 10KB Glance heap)
        // If not yet initialized (e.g. fresh install or simulator reset), default to Level 1 Novice
        var rawSummary = Application.Storage.getValue("glanceSummary");
        var summary = (rawSummary != null && (rawSummary instanceof Dictionary))
            ? (rawSummary as Dictionary)
            : ({
                "lvl"   => 1,
                "rank"  => "F",
                "title" => "NOVICE",
                "xpPct" => 0.0,
                "steps" => false,
                "read"  => false,
                "wkt"   => false,
                "alert" => false
            } as Dictionary);
        var isAlert = summary.hasKey("alert") ? (summary["alert"] as Boolean) : false;
        var primaryColor = isAlert ? COLOR_RED : COLOR_CYAN;
        var badgeBgColor = isAlert ? COLOR_DARK_RED : COLOR_DARK_BLU;

        // 2. Compact Left Column: Solo Leveling Rank Shield Crest (Polygon Shield)
        var badgeH = (h * 0.62).toNumber();
        var badgeW = (badgeH * 0.86).toNumber();
        var badgeX = 4;
        var badgeY = ((h - badgeH) / 2).toNumber();
        var cx = badgeX + (badgeW / 2);
        var shoulderY = badgeY + ((badgeH * 58) / 100);
        var tipY = badgeY + badgeH;

        var outerShield = [
            [badgeX, badgeY],
            [badgeX + badgeW, badgeY],
            [badgeX + badgeW, shoulderY],
            [cx, tipY],
            [badgeX, shoulderY]
        ];
        dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(outerShield);

        var inset = 2;
        var innerShield = [
            [badgeX + inset, badgeY + inset],
            [badgeX + badgeW - inset, badgeY + inset],
            [badgeX + badgeW - inset, shoulderY - 1],
            [cx, tipY - inset - 1],
            [badgeX + inset, shoulderY - 1]
        ];
        dc.setColor(badgeBgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(innerShield);

        // Top highlight bar inside shield crest
        dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(badgeX + inset + 2, badgeY + inset + 2, badgeX + badgeW - inset - 2, badgeY + inset + 2);

        var rankStr = summary.hasKey("rank") ? (summary["rank"] as String) : "F";
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, badgeY + ((badgeH * 44) / 100), Graphics.FONT_GLANCE,
            rankStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 3. Right Column Content (leave 8px right margin for round bezel curvature)
        var contentX = badgeX + badgeW + 7;
        var availableW = w - contentX - 8;

        // Row 1: LV.X + Quest Pips [S][R][W]
        var lvl = summary.hasKey("lvl") ? (summary["lvl"] as Number) : 1;
        var title = summary.hasKey("title") ? (summary["title"] as String) : "NOVICE";
        var lvlStr = "LV." + lvl.toString();

        var pipSize = 7;
        var pipGap = 3;
        var pipsTotalW = (3 * pipSize) + (2 * pipGap);
        var pipStartX = w - pipsTotalW - 8;
        var pipY = (h * 0.13).toNumber();
        var row1Y = (h * 0.05).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(contentX, row1Y, Graphics.FONT_XTINY,
            lvlStr, Graphics.TEXT_JUSTIFY_LEFT);

        var stepsDone = summary.hasKey("steps") ? (summary["steps"] as Boolean) : false;
        var readDone  = summary.hasKey("read")  ? (summary["read"] as Boolean)  : false;
        var wktDone   = summary.hasKey("wkt")   ? (summary["wkt"] as Boolean)   : false;

        drawQuestPip(dc, pipStartX, pipY, pipSize, stepsDone);
        drawQuestPip(dc, pipStartX + pipSize + pipGap, pipY, pipSize, readDone);
        drawQuestPip(dc, pipStartX + ((pipSize + pipGap) * 2), pipY, pipSize, wktDone);

        // Row 2: Active Title (or "! PENALTY !" when Penalty is active)
        var row2Y = (h * 0.36).toNumber();
        if (isAlert) {
            dc.setColor(COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(contentX, row2Y, Graphics.FONT_XTINY,
                "! PENALTY !", Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            var titleColor = summary.hasKey("tColor") ? (summary["tColor"] as Number) : COLOR_CYAN;
            dc.setColor(titleColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(contentX, row2Y, Graphics.FONT_XTINY,
                title, Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Row 3: Segmented RPG XP Bar
        var barY = (h * 0.74).toNumber();
        var barH = 6;
        var pct = summary.hasKey("xpPct") ? (summary["xpPct"] as Float) : 0.0;
        if (pct < 0.0) { pct = 0.0; }
        if (pct > 1.0) { pct = 1.0; }

        dc.setColor(COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(contentX, barY, availableW, barH);

        var fillW = (availableW * pct).toNumber();
        if (fillW > 2) {
            dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(contentX + 1, barY + 1, fillW - 2, barH - 2);
            if (pct < 0.99) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(contentX + fillW - 2, barY + 1, 2, barH - 2);
            }
        }

        // 5-Cell RPG Segment Dividers
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        for (var s = 1; s < 5; s++) {
            var segX = contentX + ((availableW * s) / 5);
            dc.drawLine(segX, barY + 1, segX, barY + barH - 2);
        }
    }

    function drawQuestPip(dc as Graphics.Dc, x as Number, y as Number, size as Number, done as Boolean) as Void {
        if (done) {
            dc.setColor(COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, size, size);
        } else {
            dc.setColor(COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x, y, size, size);
        }
    }
}

