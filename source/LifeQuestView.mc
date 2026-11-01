import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class LifeQuestView extends WatchUi.View {
    var page as Number;

    // --- High-tech RPG / The System Palette ---
    const COLOR_CYAN = 0x00D9FF;
    const COLOR_DARK_BLUE = 0x003366;
    const COLOR_AMBER = 0xFF8800;
    const COLOR_GOLD = 0xFFCC00;
    const COLOR_GREEN = 0x00FF66;
    const COLOR_RED = 0xFF3333;
    const COLOR_PURPLE = 0xAA00FF;
    const COLOR_WHITE = Graphics.COLOR_WHITE;
    const COLOR_LT_GRAY = Graphics.COLOR_LT_GRAY;
    const COLOR_DK_GRAY = Graphics.COLOR_DK_GRAY;

    function initialize() {
        View.initialize();
        page = 0;
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    function onShow() as Void {}

    function onUpdate(dc as Dc) as Void {
        var state = getApp().getCharacterState();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (page == 1) {
            drawQuests(dc, state);
        } else if (page == 2) {
            drawReading(dc, state);
        } else {
            drawCharacter(dc, state);
        }
    }

    function nextPage() as Void {
        page = (page + 1) % 3;
    }

    function previousPage() as Void {
        page -= 1;
        if (page < 0) {
            page = 2;
        }
    }

    // --- Global RPG HUD Overlay ---
    function drawHudOverlay(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var pad = (w * 0.11).toNumber();
        var tick = (w * 0.045).toNumber();

        dc.setColor(COLOR_DARK_BLUE, Graphics.COLOR_BLACK);
        if (dc has :setPenWidth) {
            dc.setPenWidth(1);
        }

        // Top-Left corner bracket ┌
        dc.drawLine(pad, pad + tick, pad, pad);
        dc.drawLine(pad, pad, pad + tick, pad);

        // Top-Right corner bracket ┐
        dc.drawLine(w - pad - tick, pad, w - pad, pad);
        dc.drawLine(w - pad, pad, w - pad, pad + tick);

        // Bottom-Left corner bracket └
        dc.drawLine(pad, h - pad - tick, pad, h - pad);
        dc.drawLine(pad, h - pad, pad + tick, h - pad);

        // Bottom-Right corner bracket ┘
        dc.drawLine(w - pad - tick, h - pad, w - pad, h - pad);
        dc.drawLine(w - pad, h - pad - tick, w - pad, h - pad);
    }

    function drawSystemHeader(dc as Dc, title as String) as Number {
        var width = dc.getWidth();
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        // Title strictly at top margin
        var headerY = (dc.getHeight() * 0.07).toNumber();
        dc.setColor(COLOR_CYAN, Graphics.COLOR_BLACK);
        dc.drawText(center, headerY, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);

        // Divider line strictly below font with gap
        var lineY = headerY + hTiny + 3;
        var linePad = (width * 0.18).toNumber();
        dc.setColor(COLOR_DARK_BLUE, Graphics.COLOR_BLACK);
        dc.drawLine(linePad, lineY, width - linePad, lineY);

        // Glowing center accent diamond
        dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle(center - 2, lineY - 1, 5, 3);

        return lineY;
    }

    function drawPageIndicator(dc as Dc, currentPage as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var center = width / 2;
        var y = (height * 0.93).toNumber();
        var dotSpacing = (width * 0.05).toNumber();
        var size = (width * 0.015).toNumber();
        if (size < 2) {
            size = 2;
        }

        for (var i = 0; i < 3; i++) {
            var dotX = center + ((i - 1) * dotSpacing);
            if (i == currentPage) {
                drawRpgDiamond(dc, dotX, y, size + 1, true, COLOR_CYAN);
            } else {
                drawRpgDiamond(dc, dotX, y, size, false, COLOR_DK_GRAY);
            }
        }
    }

    function rankColor(rank as String) as Number {
        if (rank.equals("S") || rank.equals("SS") || rank.equals("SSS")) {
            return COLOR_GOLD;
        } else if (rank.equals("A") || rank.equals("B")) {
            return COLOR_PURPLE;
        } else if (rank.equals("C") || rank.equals("D")) {
            return COLOR_CYAN;
        }
        return COLOR_AMBER;
    }

    // --- Screen 1: Status / Character Window ---
    function drawCharacter(dc as Dc, state as LifeQuestState) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        drawHudOverlay(dc);
        var curY = drawSystemHeader(dc, "[ STATUS ]") + 5;

        // Level text
        dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(center, curY, Graphics.FONT_XTINY, "LEVEL " + state.totalLevel().toString(), Graphics.TEXT_JUSTIFY_CENTER);
        curY += hTiny + 2;

        // Rank Badge
        var rankStr = state.rank();
        var rColor = rankColor(rankStr);
        var badgeW = (width * 0.34).toNumber();
        var badgeH = hTiny + 3;
        var badgeX = center - (badgeW / 2);
        var badgeY = curY;

        dc.setColor(rColor, Graphics.COLOR_BLACK);
        dc.drawRoundedRectangle(badgeX, badgeY, badgeW, badgeH, 3);
        dc.drawText(center, badgeY + 1, Graphics.FONT_XTINY, "RANK - " + rankStr, Graphics.TEXT_JUSTIFY_CENTER);
        curY += badgeH + 4;

        // XP Information
        var curXp = state.characterXp().toNumber();
        var nextXp = state.characterNextLevelXp().toNumber();
        var pct = (characterProgress(state) * 100).toNumber();
        dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(center, curY, Graphics.FONT_XTINY,
            "XP " + curXp.toString() + " / " + nextXp.toString() + " (" + pct.toString() + "%)",
            Graphics.TEXT_JUSTIFY_CENTER);
        curY += hTiny + 3;

        // RPG XP Bar
        var barW = (width * 0.62).toNumber();
        var barX = center - (barW / 2);
        var barH = 6;
        drawRpgProgressBar(dc, barX, curY, barW, barH, characterProgress(state), COLOR_CYAN);
        curY += barH + 7;

        // 2-Column Attribute Matrix
        var statSpacing = hTiny + 3;

        // Subtle vertical column divider
        dc.setColor(COLOR_DARK_BLUE, Graphics.COLOR_BLACK);
        dc.drawLine(center, curY - 1, center, curY + (statSpacing * 2) + hTiny);

        var colLeftX = (width * 0.18).toNumber();
        var colRightX = (width * 0.54).toNumber();

        // Left Column: STR, AGI, INT
        drawStatBadge(dc, colLeftX, curY, "STR", COLOR_AMBER, state, :STR);
        drawStatBadge(dc, colLeftX, curY + statSpacing, "AGI", COLOR_GREEN, state, :AGI);
        drawStatBadge(dc, colLeftX, curY + (statSpacing * 2), "INT", COLOR_CYAN, state, :INT);

        // Right Column: VIT, PER, Status
        drawStatBadge(dc, colRightX, curY, "VIT", COLOR_GOLD, state, :VIT);
        drawStatBadge(dc, colRightX, curY + statSpacing, "PER", COLOR_RED, state, :PER);
        drawConditionStatus(dc, colRightX, curY + (statSpacing * 2), state);

        drawPageIndicator(dc, 0);
    }

    function drawStatBadge(dc as Dc, x as Number, y as Number, label as String,
        color as Number, state as LifeQuestState, statSym as Symbol) as Void {
        var stat = (state.data["stats"] as Dictionary)[label] as Dictionary;
        var level = stat["level"] as Number;
        var isFatigued = state.isFatigued(statSym);

        // Stat Label
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);

        var labelW = dc.getTextDimensions(label + " ", Graphics.FONT_XTINY)[0];

        // Level text
        dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
        var levelStr = "LV " + level.toString();
        dc.drawText(x + labelW, y, Graphics.FONT_XTINY, levelStr, Graphics.TEXT_JUSTIFY_LEFT);

        // If fatigued, draw a debuff marker
        if (isFatigued) {
            var lvW = dc.getTextDimensions(levelStr, Graphics.FONT_XTINY)[0];
            dc.setColor(COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(x + labelW + lvW + 2, y, Graphics.FONT_XTINY, "!", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    function drawConditionStatus(dc as Dc, x as Number, y as Number, state as LifeQuestState) as Void {
        if (state.hasAnyFatigue()) {
            dc.setColor(COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(x, y, Graphics.FONT_XTINY, "FATIGUE", Graphics.TEXT_JUSTIFY_LEFT);
            var w = dc.getTextDimensions("FATIGUE ", Graphics.FONT_XTINY)[0];
            dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(x + w, y, Graphics.FONT_XTINY, "50%", Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(x, y, Graphics.FONT_XTINY, "STATUS", Graphics.TEXT_JUSTIFY_LEFT);
            var w = dc.getTextDimensions("STATUS ", Graphics.FONT_XTINY)[0];
            dc.setColor(COLOR_GREEN, Graphics.COLOR_BLACK);
            dc.drawText(x + w, y, Graphics.FONT_XTINY, "OK", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // --- Screen 2: Daily Quests Window ---
    function drawQuests(dc as Dc, state as LifeQuestState) as Void {
        var width = dc.getWidth();
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var quests = state.data["quests"] as Dictionary;

        state.syncSteps();

        drawHudOverlay(dc);
        var curY = drawSystemHeader(dc, "[ DAILY QUESTS ]") + 8;

        var rowSpacing = hTiny + 6;

        // 1. Workout
        var workoutDone = quests["workoutComplete"] as Boolean;
        drawQuestItem(dc, curY, "WORKOUT",
            workoutDone ? "DONE +20XP" : "10+ MIN", workoutDone);
        curY += rowSpacing;

        // 2. Reading
        var readingDone = quests["readingComplete"] as Boolean;
        var readingMins = quests["readingMinutes"] as Number;
        drawQuestItem(dc, curY, "READING",
            readingDone ? "20m DONE" : (readingMins.toString() + " / 20 MIN"), readingDone);
        curY += rowSpacing;

        // 3. Steps
        var stepsDone = quests["stepsComplete"] as Boolean;
        var steps = state.currentSteps();
        drawQuestItem(dc, curY, "10K STEPS",
            stepsDone ? "DONE +20XP" : (steps.toString() + " / 10K"), stepsDone);
        curY += rowSpacing + 5;

        // Penalty Zone Status Card
        var penaltyActive = quests["penaltyActive"] as Boolean;
        var penaltyDone = quests["penaltyComplete"] as Boolean;
        var boxW = (width * 0.76).toNumber();
        var boxH = (hTiny * 2) + 8;
        var boxX = center - (boxW / 2);
        var boxY = curY;

        if (penaltyActive) {
            dc.setColor(COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawRoundedRectangle(boxX, boxY, boxW, boxH, 4);
            dc.drawText(center, boxY + 2, Graphics.FONT_XTINY, "[ ! PENALTY ZONE ! ]", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(center, boxY + hTiny + 2, Graphics.FONT_XTINY,
                penaltyDone ? "CLEARED: 1.0 MI" : "RUN 1.0 MILE", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(COLOR_DARK_BLUE, Graphics.COLOR_BLACK);
            dc.drawRoundedRectangle(boxX, boxY, boxW, boxH, 4);
            dc.setColor(COLOR_CYAN, Graphics.COLOR_BLACK);
            dc.drawText(center, boxY + 2, Graphics.FONT_XTINY, "[ PENALTY: CLEAR ]", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(center, boxY + hTiny + 2, Graphics.FONT_XTINY, "COMPLETE BY MIDNIGHT", Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawPageIndicator(dc, 1);
    }

    function drawQuestItem(dc as Dc, y as Number, title as String, detail as String, complete as Boolean) as Void {
        var width = dc.getWidth();
        var diaX = (width * 0.16).toNumber();
        var diaY = y + 8;
        var diaSize = 5;

        var color = complete ? COLOR_GREEN : COLOR_AMBER;
        drawRpgDiamond(dc, diaX, diaY, diaSize, complete, color);

        var titleX = diaX + 13;
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(titleX, y, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_LEFT);

        var detailX = (width * 0.84).toNumber();
        dc.setColor(complete ? COLOR_GREEN : COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(detailX, y, Graphics.FONT_XTINY, detail, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // --- Screen 3: Reading / Intellect Training ---
    function drawReading(dc as Dc, state as LifeQuestState) as Void {
        var width = dc.getWidth();
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var quests = state.data["quests"] as Dictionary;
        var readingMinutes = quests["readingMinutes"] as Number;
        var goalMinutes = state.readingGoalMinutes();

        drawHudOverlay(dc);
        var curY = drawSystemHeader(dc, "[ INTELLECT ]") + 4;

        // Digital Readout
        var hLarge = dc.getFontHeight(Graphics.FONT_LARGE);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(center, curY, Graphics.FONT_LARGE, readingMinutes.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        curY += hLarge;

        // Subtitle
        dc.setColor(COLOR_CYAN, Graphics.COLOR_BLACK);
        dc.drawText(center, curY, Graphics.FONT_XTINY, "MINUTES LOGGED", Graphics.TEXT_JUSTIFY_CENTER);
        curY += hTiny + 2;

        // Goal
        dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(center, curY, Graphics.FONT_XTINY,
            "GOAL: " + goalMinutes.toString() + " MIN", Graphics.TEXT_JUSTIFY_CENTER);
        curY += hTiny + 4;

        // RPG Progress Bar
        var barW = (width * 0.64).toNumber();
        var barX = center - (barW / 2);
        var barH = 6;
        var progress = readingMinutes.toFloat() / goalMinutes.toFloat();
        drawRpgProgressBar(dc, barX, curY, barW, barH, progress,
            readingMinutes >= goalMinutes ? COLOR_GREEN : COLOR_CYAN);
        curY += barH + 10;

        // Action Command Box
        var btnW = (width * 0.68).toNumber();
        var btnH = hTiny + 8;
        var btnX = center - (btnW / 2);
        var btnY = curY;

        dc.setColor(COLOR_CYAN, Graphics.COLOR_BLACK);
        dc.drawRoundedRectangle(btnX, btnY, btnW, btnH, 4);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(center, btnY + 3, Graphics.FONT_XTINY, "[ MENU ] LOG TIME", Graphics.TEXT_JUSTIFY_CENTER);

        drawPageIndicator(dc, 2);
    }

    // --- UI Helpers & Geometric Primitives ---
    function characterProgress(state as LifeQuestState) as Float {
        var next = state.characterNextLevelXp();
        if (next <= 0.0) {
            return 0.0;
        }
        return state.characterXp() / next;
    }

    function drawRpgDiamond(dc as Dc, cx as Number, cy as Number, size as Number,
        filled as Boolean, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_BLACK);
        if (filled) {
            var pts = [
                [cx, cy - size],
                [cx + size, cy],
                [cx, cy + size],
                [cx - size, cy]
            ];
            dc.fillPolygon(pts);
            // Center white accent pip
            dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.fillRectangle(cx - 1, cy - 1, 3, 3);
        } else {
            dc.drawLine(cx, cy - size, cx + size, cy);
            dc.drawLine(cx + size, cy, cx, cy + size);
            dc.drawLine(cx, cy + size, cx - size, cy);
            dc.drawLine(cx - size, cy, cx, cy - size);
        }
    }

    function drawRpgProgressBar(dc as Dc, x as Number, y as Number, width as Number,
        height as Number, progress as Float, color as Number) as Void {
        var boundedProgress = progress;
        if (boundedProgress < 0.0) {
            boundedProgress = 0.0;
        } else if (boundedProgress > 1.0) {
            boundedProgress = 1.0;
        }

        // Background track (dark navy with border)
        dc.setColor(COLOR_DARK_BLUE, Graphics.COLOR_BLACK);
        dc.drawRoundedRectangle(x, y, width, height, 2);

        // Fill bar
        var fillW = ((width - 4) * boundedProgress).toNumber();
        if (fillW > 0) {
            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.fillRoundedRectangle(x + 2, y + 2, fillW, height - 4, 1);

            // Leading glow head
            var tipX = x + 2 + fillW;
            var tipY = y + (height / 2);
            var tipRadius = (height / 2);
            if (tipRadius < 2) {
                tipRadius = 2;
            }
            dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.fillRectangle(tipX - 1, tipY - tipRadius, 2, tipRadius * 2);
        }
    }

    function drawProgressBar(dc as Dc, x as Number, y as Number, width as Number,
        progress as Float, color as Number) as Void {
        drawRpgProgressBar(dc, x, y, width, 6, progress, color);
    }

    function onHide() as Void {}
}
