import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class LifeQuestView extends WatchUi.View {
    var page as Number;

    // --- High-tech RPG / The System Palette ---
    const COLOR_CYAN = 0x00D9FF;
    const COLOR_DARK_BLUE = 0x003366;
    const COLOR_DARK_RED = 0x550000;
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
        // 1. Fetch the raw state that could technically be Null
        var rawState = getApp().getCharacterState();
        
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 2. 🎯 CRITICAL SHIELD: Render a safe boot overlay if memory slots aren't ready
        if (rawState == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            var w = dc.getWidth() / 2;
            var h = dc.getHeight() / 2;
            dc.drawText(w, h, Graphics.FONT_TINY, "INITIALIZING SYSTEM...", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // 3. 🎯 TYPE CAST ESCALATION: Tell the watch compiler it is 100% safe to treat as a strict object now
        var state = rawState as LifeQuestState;

        // 4. Streamlined 4-Page RPG System Carousel
        if (page == 1) {
            drawQuests(dc, state);
        } else if (page == 2) {
            drawStatRadar(dc, state);
        } else if (page == 3) {
            drawDailySummary(dc, state);
        } else {
            drawCharacter(dc, state);
        }
    }

    function nextPage() as Void {
        page = (page + 1) % 4;
    }

    function previousPage() as Void {
        page -= 1;
        if (page < 0) {
            page = 3;
        }
    }

    // --- Global Solo Leveling "The System" HUD Frame ---
    function drawHudOverlay(dc as Dc) as Void {
        drawHudOverlayMode(dc, false);
    }

    function drawHudOverlayMode(dc as Dc, isAlert as Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var r = (w < h ? w : h) / 2;

        var primaryColor = isAlert ? COLOR_RED : COLOR_CYAN;
        var secondaryColor = isAlert ? COLOR_DARK_RED : COLOR_DARK_BLUE;

        // 1. Outer Bezel Holographic Arcs (Left & Right System Energy Rails)
        if (dc has :drawArc) {
            if (dc has :setPenWidth) {
                dc.setPenWidth(2);
            }
            dc.setColor(secondaryColor, Graphics.COLOR_BLACK);
            // Left outer arc (138° to 222°) & Right outer arc (318° to 42°)
            dc.drawArc(cx, cy, r - 3, Graphics.ARC_COUNTER_CLOCKWISE, 138, 222);
            dc.drawArc(cx, cy, r - 3, Graphics.ARC_COUNTER_CLOCKWISE, 318, 42);

            if (dc has :setPenWidth) {
                dc.setPenWidth(1);
            }
            dc.setColor(primaryColor, Graphics.COLOR_BLACK);
            // Inner glowing core arcs (154° to 206° & 334° to 26°)
            dc.drawArc(cx, cy, r - 6, Graphics.ARC_COUNTER_CLOCKWISE, 154, 206);
            dc.drawArc(cx, cy, r - 6, Graphics.ARC_COUNTER_CLOCKWISE, 334, 26);
        }

        // Side bezel cardinal diamond nodes (9 o'clock & 3 o'clock)
        drawRpgDiamond(dc, 6, cy, 2, true, primaryColor);
        drawRpgDiamond(dc, w - 6, cy, 2, true, primaryColor);

        // 2. Double-Line Solo Leveling System Bottom Corner Brackets (top is framed by the header divider)
        var pad = (w * 0.19).toNumber();
        var innerPad = pad + 3;
        var tick = (w * 0.045).toNumber();
        var innerTick = tick - 2;

        if (dc has :setPenWidth) {
            dc.setPenWidth(1);
        }

        // Outer bracket layer (glowing primary cyan/red)
        dc.setColor(primaryColor, Graphics.COLOR_BLACK);
        // Bottom-Left └
        dc.drawLine(pad, h - pad - tick, pad, h - pad);
        dc.drawLine(pad, h - pad, pad + tick, h - pad);
        // Bottom-Right ┘
        dc.drawLine(w - pad - tick, h - pad, w - pad, h - pad);
        dc.drawLine(w - pad, h - pad - tick, w - pad, h - pad);

        // Inner double-frame layer (deep secondary blue/crimson)
        dc.setColor(secondaryColor, Graphics.COLOR_BLACK);
        // Bottom-Left inner
        dc.drawLine(innerPad, h - innerPad - innerTick, innerPad, h - innerPad);
        dc.drawLine(innerPad, h - innerPad, innerPad + innerTick, h - innerPad);
        // Bottom-Right inner
        dc.drawLine(w - innerPad - innerTick, h - innerPad, w - innerPad, h - innerPad);
        dc.drawLine(w - innerPad, h - innerPad - innerTick, w - innerPad, h - innerPad);

        // Bottom corner accent nodes
        drawRpgDiamond(dc, pad, h - pad, 2, true, COLOR_WHITE);
        drawRpgDiamond(dc, w - pad, h - pad, 2, true, COLOR_WHITE);
    }

    function drawSystemHeader(dc as Dc, title as String) as Number {
        return drawSystemHeaderMode(dc, title, false);
    }

    function drawSystemHeaderMode(dc as Dc, title as String, isAlert as Boolean) as Number {
        var width = dc.getWidth();
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        var primaryColor = isAlert ? COLOR_RED : COLOR_CYAN;
        var secondaryColor = isAlert ? COLOR_DARK_RED : COLOR_DARK_BLUE;

        // Clean bracket characters if passed so the [!] System Badge frames the title cleanly
        var cleanTitle = title;
        if (title.find("[ ") != null && title.find(" ]") != null) {
            cleanTitle = title.substring(2, title.length() - 2);
        }

        // Top padding so the [!] badge + widest title ("STAT PROGRESS") sit safely inside the top curve
        var headerY = (dc.getHeight() * 0.10).toNumber();
        var textW = dc.getTextDimensions(cleanTitle, Graphics.FONT_XTINY)[0];
        var badgeR = (hTiny * 0.34).toNumber();
        if (badgeR < 6) { badgeR = 6; }
        var badgeGap = 5;
        var totalHeaderW = (badgeR * 2) + badgeGap + textW;
        var startX = center - (totalHeaderW / 2);

        // 1. Solo Leveling [ ! ] System Notification Badge
        var badgeCx = startX + badgeR;
        var badgeCy = headerY + (hTiny / 2);
        dc.setColor(secondaryColor, Graphics.COLOR_BLACK);
        dc.fillCircle(badgeCx, badgeCy, badgeR);
        dc.setColor(primaryColor, Graphics.COLOR_BLACK);
        dc.drawCircle(badgeCx, badgeCy, badgeR);

        // Exclamation mark '!' inside the badge
        dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle(badgeCx - 1, badgeCy - badgeR + 3, 2, badgeR - 2);
        dc.fillRectangle(badgeCx - 1, badgeCy + badgeR - 4, 2, 2);

        // 2. System Header Title Text
        dc.setColor(primaryColor, Graphics.COLOR_BLACK);
        dc.drawText(startX + (badgeR * 2) + badgeGap, headerY, Graphics.FONT_XTINY, cleanTitle, Graphics.TEXT_JUSTIFY_LEFT);

        // 3. Double-Line Glowing System Divider Bar
        var lineY = headerY + hTiny + 3;
        var outerPad = (width * 0.16).toNumber();
        var innerPad = (width * 0.27).toNumber();

        dc.setColor(secondaryColor, Graphics.COLOR_BLACK);
        dc.drawLine(outerPad, lineY, width - outerPad, lineY);
        dc.drawLine(outerPad + 6, lineY + 2, width - outerPad - 6, lineY + 2);

        dc.setColor(primaryColor, Graphics.COLOR_BLACK);
        dc.drawLine(innerPad, lineY, width - innerPad, lineY);

        // End-cap nodes & glowing center diamond
        drawRpgDiamond(dc, outerPad, lineY, 2, true, primaryColor);
        drawRpgDiamond(dc, width - outerPad, lineY, 2, true, primaryColor);
        drawRpgDiamond(dc, center, lineY, 3, true, COLOR_WHITE);

        return lineY + 2;
    }

    function drawPageIndicator(dc as Dc, currentPage as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var center = width / 2;
        var y = (height * 0.93).toNumber();
        var dotSpacing = (width * 0.044).toNumber();
        var size = (width * 0.014).toNumber();
        if (size < 2) {
            size = 2;
        }

        var totalPages = 4;
        var startX = center - (((totalPages - 1) * dotSpacing) / 2);

        for (var i = 0; i < totalPages; i++) {
            var dotX = startX + (i * dotSpacing);
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
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        drawHudOverlay(dc);
        var curY = drawSystemHeader(dc, "[ STATUS ]") + 3;

        // Combined Level + Rank Line ("LV. 1  [F-RANK]")
        var lvlStr = "LV." + state.totalLevel().toString() + " ";
        var rankStr = "[" + state.rank() + "-RANK]";
        var rColor = rankColor(state.rank());
        var lvlW = dc.getTextDimensions(lvlStr, Graphics.FONT_XTINY)[0];
        var rankW = dc.getTextDimensions(rankStr, Graphics.FONT_XTINY)[0];
        var topStartX = center - ((lvlW + rankW) / 2);

        dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(topStartX, curY, Graphics.FONT_XTINY, lvlStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(rColor, Graphics.COLOR_BLACK);
        dc.drawText(topStartX + lvlW, curY, Graphics.FONT_XTINY, rankStr, Graphics.TEXT_JUSTIFY_LEFT);
        curY += hTiny + 2;

        // RPG Class / Equipped Achievement Title Banner Badge (colored by stat affinity or rank)
        var titleStr = state.activeTitle();
        var tColor = state.titleColorFor(titleStr);
        var titleW = dc.getTextDimensions(titleStr, Graphics.FONT_XTINY)[0];
        var badgeW = titleW + 24;
        var badgeH = hTiny + 2;
        var badgeX = center - (badgeW / 2);
        var badgeY = curY;

        dc.setColor(0x001A33, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(badgeX, badgeY, badgeW, badgeH, 4);
        dc.setColor(tColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(badgeX, badgeY, badgeW, badgeH, 4);
        dc.drawText(center, badgeY, Graphics.FONT_XTINY, titleStr, Graphics.TEXT_JUSTIFY_CENTER);
        curY += badgeH + 3;

        // XP Information
        var curXp = state.characterXp().toNumber();
        var nextXp = state.characterNextLevelXp().toNumber();
        var pct = (characterProgress(state) * 100).toNumber();
        dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(center, curY, Graphics.FONT_XTINY,
            "XP " + curXp.toString() + "/" + nextXp.toString() + " (" + pct.toString() + "%)",
            Graphics.TEXT_JUSTIFY_CENTER);
        curY += hTiny + 2;

        // Segmented RPG XP Bar
        var barW = (width * 0.62).toNumber();
        var barX = center - (barW / 2);
        var barH = 6;
        drawRpgProgressBar(dc, barX, curY, barW, barH, characterProgress(state), COLOR_CYAN);
        curY += barH + 5;

        // 2-Column Attribute Matrix with Custom RPG Vector Icons
        var statSpacing = hTiny + 2;

        // Subtle vertical column divider
        dc.setColor(COLOR_DARK_BLUE, Graphics.COLOR_BLACK);
        dc.drawLine(center, curY, center, curY + (statSpacing * 2) + hTiny - 2);

        var colLeftX = (width * 0.14).toNumber();
        var colRightX = (width * 0.53).toNumber();

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
        var statsDict = state.data["stats"] as Dictionary;
        var stat = statsDict[label] as Dictionary;

        var level = stat["level"] as Number;
        var isFatigued = state.isFatigued(statSym);
        var activeColor = isFatigued ? COLOR_DK_GRAY : color;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var iconR = (hTiny * 0.30).toNumber();
        if (iconR < 5) { iconR = 5; }
        var iconSpan = (iconR * 2) + 5;

        // 1. Scaled RPG Vector Icon
        drawStatIcon(dc, x + iconR, y + (hTiny / 2), statSym, activeColor);

        // 2. Stat Label
        var textX = x + iconSpan;
        dc.setColor(activeColor, Graphics.COLOR_BLACK);
        dc.drawText(textX, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);

        var labelW = dc.getTextDimensions(label + " ", Graphics.FONT_XTINY)[0];

        // 3. Level text
        dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
        var levelStr = "LV" + level.toString();
        dc.drawText(textX + labelW, y, Graphics.FONT_XTINY, levelStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // --- Screen 2: Daily Quest Log (Solo Leveling Live Counters) ---
    function drawQuests(dc as Dc, state as LifeQuestState) as Void {
        var width = dc.getWidth();
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        var quests = state.data["quests"] as Dictionary;
        var stepsComplete = quests["stepsComplete"] as Boolean;
        var readingComplete = quests["readingComplete"] as Boolean;
        var workoutComplete = quests["workoutComplete"] as Boolean;
        var penaltyActive = quests["penaltyActive"] as Boolean;
        var inPenalty = penaltyActive && !(quests["penaltyComplete"] as Boolean);

        drawHudOverlayMode(dc, inPenalty);
        var headerTitle = inPenalty ? "[ PENALTY QUEST ]" : "[ QUEST INFO ]";
        var curY = drawSystemHeaderMode(dc, headerTitle, inPenalty) + 6;

        var rowSpacing = hTiny + 5;
        var leftX = (width * 0.14).toNumber();
        var rightX = (width * 0.86).toNumber();

        if (inPenalty) {
            // High Alert Solo Leveling Penalty Mode Layout (3 Escape Options)
            dc.setColor(COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(center, curY, Graphics.FONT_XTINY, "CLEAR ANY 1 TO ESCAPE:", Graphics.TEXT_JUSTIFY_CENTER);
            curY += rowSpacing;

            dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(center, curY, Graphics.FONT_XTINY, "1. Run 1.0 Mile", Graphics.TEXT_JUSTIFY_CENTER);
            curY += rowSpacing - 2;

            dc.drawText(center, curY, Graphics.FONT_XTINY, "2. 20m Workout (Any)", Graphics.TEXT_JUSTIFY_CENTER);
            curY += rowSpacing - 2;

            dc.drawText(center, curY, Graphics.FONT_XTINY, "3. 12,000 Steps", Graphics.TEXT_JUSTIFY_CENTER);
            curY += rowSpacing;

            dc.setColor(COLOR_AMBER, Graphics.COLOR_BLACK);
            dc.drawText(center, curY, Graphics.FONT_XTINY, "Reward: Clear Fatigue", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // Format live step counter (e.g. "[4.2k/10k]" or "[850/10k]")
            var steps = state.currentSteps();
            var stepCountStr = "";
            if (stepsComplete || steps >= 10000) {
                stepCountStr = "[10k/10k]";
            } else if (steps >= 1000) {
                stepCountStr = "[" + (steps.toFloat() / 1000.0).format("%.1f") + "k/10k]";
            } else {
                stepCountStr = "[" + steps.toString() + "/10k]";
            }

            var readMins = quests["readingMinutes"] as Number;
            var readGoal = state.readingGoalMinutes();
            var readCountStr = "[" + readMins.toString() + "/" + readGoal.toString() + "m]";
            var wktCountStr = workoutComplete ? "[1/1]" : "[0/1]";

            var raidMins = state.currentWeeklyActiveMinutes();
            var raidGoal = state.weeklyActiveMinutesGoal();
            var raidComplete = state.isWeeklyRaidComplete() || (raidMins >= raidGoal && raidGoal > 0);
            var raidCountStr = "[" + raidMins.toString() + "/" + raidGoal.toString() + "m]";

            rowSpacing = hTiny + 2;

            drawQuestCounterRow(dc, leftX, rightX, curY, "Steps", stepCountStr, stepsComplete);
            curY += rowSpacing;

            drawQuestCounterRow(dc, leftX, rightX, curY, "Reading", readCountStr, readingComplete);
            curY += rowSpacing;

            drawQuestCounterRow(dc, leftX, rightX, curY, "Workout", wktCountStr, workoutComplete);
            curY += rowSpacing;

            // Weekly Raid / Boss Quest Row (WHO & Garmin standard 150 Intensity Minutes, customizable in Garmin Connect)
            drawWeeklyRaidRow(dc, leftX, rightX, curY, "Wk Raid", raidCountStr, raidComplete);
            curY += rowSpacing + 3;

            // Solo Leveling System Quest Footer Status
            if (stepsComplete && readingComplete && workoutComplete) {
                dc.setColor(COLOR_GOLD, Graphics.COLOR_BLACK);
                dc.drawText(center, curY, Graphics.FONT_XTINY, "* DAILY CLEARED *", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.setColor(COLOR_AMBER, Graphics.COLOR_BLACK);
                dc.drawText(center, curY, Graphics.FONT_XTINY, "INCOMPLETE = PENALTY", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        drawPageIndicator(dc, 1);
    }

    function drawWeeklyRaidRow(dc as Dc, leftX as Number, rightX as Number, y as Number,
        title as String, counterText as String, isComplete as Boolean) as Void {
        var boxText = isComplete ? "[X] " : "[!] ";
        var boxColor = isComplete ? COLOR_GOLD : COLOR_PURPLE;
        var textColor = isComplete ? COLOR_GOLD : COLOR_PURPLE;
        var countColor = isComplete ? COLOR_GOLD : COLOR_PURPLE;

        dc.setColor(boxColor, Graphics.COLOR_BLACK);
        dc.drawText(leftX, y, Graphics.FONT_XTINY, boxText, Graphics.TEXT_JUSTIFY_LEFT);

        var boxWidth = dc.getTextDimensions(boxText, Graphics.FONT_XTINY)[0];
        dc.setColor(textColor, Graphics.COLOR_BLACK);
        dc.drawText(leftX + boxWidth, y, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(countColor, Graphics.COLOR_BLACK);
        dc.drawText(rightX, y, Graphics.FONT_XTINY, counterText, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function drawQuestCounterRow(dc as Dc, leftX as Number, rightX as Number, y as Number,
        title as String, counterText as String, isComplete as Boolean) as Void {
        var boxText = isComplete ? "[X] " : "[ ] ";
        var boxColor = isComplete ? COLOR_GREEN : COLOR_DK_GRAY;
        var textColor = isComplete ? COLOR_LT_GRAY : COLOR_WHITE;
        var countColor = isComplete ? COLOR_GREEN : COLOR_CYAN;

        dc.setColor(boxColor, Graphics.COLOR_BLACK);
        dc.drawText(leftX, y, Graphics.FONT_XTINY, boxText, Graphics.TEXT_JUSTIFY_LEFT);

        var boxWidth = dc.getTextDimensions(boxText, Graphics.FONT_XTINY)[0];
        dc.setColor(textColor, Graphics.COLOR_BLACK);
        dc.drawText(leftX + boxWidth, y, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(countColor, Graphics.COLOR_BLACK);
        dc.drawText(rightX, y, Graphics.FONT_XTINY, counterText, Graphics.TEXT_JUSTIFY_RIGHT);
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

    // --- Screen 4: Detailed Stat Progress Window (Centered with Icons & Segmented Bars) ---
    function drawStatProgress(dc as Dc, state as LifeQuestState) as Void {
        var width = dc.getWidth();
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        drawHudOverlay(dc);
        var curY = drawSystemHeader(dc, "[ STAT PROGRESS ]") + 3;

        var stats = state.data["stats"] as Dictionary;

        var statOrder = [:STR, :AGI, :INT, :VIT, :PER];
        var statLabels = ["STR", "AGI", "INT", "VIT", "PER"];
        var statColors = [COLOR_AMBER, COLOR_GREEN, COLOR_CYAN, COLOR_GOLD, COLOR_RED];

        var barW = (width * 0.56).toNumber();
        var barX = center - (barW / 2);
        var barH = 5;

        var spacingY = hTiny + 9;

        for (var i = 0; i < statOrder.size(); i++) {
            var sym = statOrder[i];
            var label = statLabels[i];
            var color = statColors[i];

            var statData = stats[label] as Dictionary;
            var lvl = statData["level"] as Number;
            var currentXp = statData["xp"] as Float;

            var nextXpThreshold = state.nextLevelXp(lvl).toFloat();
            var progressPct = (nextXpThreshold > 0) ? (currentXp / nextXpThreshold) : 0.0;
            if (progressPct > 1.0) { progressPct = 1.0; }
            if (progressPct < 0.0) { progressPct = 0.0; }

            var displayPct = (progressPct * 100).toNumber();

            if (state.isFatigued(sym)) {
                color = COLOR_DK_GRAY;
            }

            // Center icon + label text (e.g., "[icon] STR 1 (54%)")
            var labelText = label + " " + lvl.toString() + " (" + displayPct.toString() + "%)";
            var textW = dc.getTextDimensions(labelText, Graphics.FONT_XTINY)[0];
            var iconR = (hTiny * 0.30).toNumber();
            if (iconR < 5) { iconR = 5; }
            var iconSpan = (iconR * 2) + 6;
            var rowStartX = center - ((textW + iconSpan) / 2);

            drawStatIcon(dc, rowStartX + iconR, curY + (hTiny / 2), sym, color);
            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.drawText(rowStartX + iconSpan, curY, Graphics.FONT_XTINY, labelText, Graphics.TEXT_JUSTIFY_LEFT);

            // Step down and draw the horizontal segmented experience bar
            var barY = curY + hTiny;
            drawRpgProgressBar(dc, barX, barY, barW, barH, progressPct, color);

            curY += spacingY;
        }

        drawPageIndicator(dc, 3);
    }

    // --- Screen 5: 5-Axis RPG Pentagon Stat Radar Chart ---
    function drawStatRadar(dc as Dc, state as LifeQuestState) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        drawHudOverlay(dc);
        var topY = drawSystemHeader(dc, "[ STAT RADAR ]");
        var bottomY = (height * 0.90).toNumber();
        var cy = ((topY + bottomY) / 2) + 4;
        var maxR = ((bottomY - topY) * 0.34).toNumber();

        // Unit vectors for 5 pentagon vertices (Top, Top-Right, Bottom-Right, Bottom-Left, Top-Left)
        var cosA = [0.0, 0.951, 0.588, -0.588, -0.951];
        var sinA = [-1.0, -0.309, 0.809, 0.809, -0.309];
        var statLabels = ["STR", "AGI", "INT", "VIT", "PER"];
        var statColors = [COLOR_AMBER, COLOR_GREEN, COLOR_CYAN, COLOR_GOLD, COLOR_RED];

        // 1. Draw outer & inner pentagon radar web + 5 radial spokes
        dc.setColor(COLOR_DARK_BLUE, Graphics.COLOR_BLACK);
        var midR = (maxR * 0.55).toNumber();
        for (var i = 0; i < 5; i++) {
            var nextI = (i + 1) % 5;
            var ox1 = cx + (maxR * cosA[i]).toNumber();
            var oy1 = cy + (maxR * sinA[i]).toNumber();
            var ox2 = cx + (maxR * cosA[nextI]).toNumber();
            var oy2 = cy + (maxR * sinA[nextI]).toNumber();

            // Outer web ring + spoke from center
            dc.drawLine(ox1, oy1, ox2, oy2);
            dc.drawLine(cx, cy, ox1, oy1);

            // Inner 55% web ring
            var mx1 = cx + (midR * cosA[i]).toNumber();
            var my1 = cy + (midR * sinA[i]).toNumber();
            var mx2 = cx + (midR * cosA[nextI]).toNumber();
            var my2 = cy + (midR * sinA[nextI]).toNumber();
            dc.drawLine(mx1, my1, mx2, my2);
        }

        // 2. Compute normalized stat radii (combining level + current XP progress)
        var stats = state.data["stats"] as Dictionary;
        var rawVals = [0.0, 0.0, 0.0, 0.0, 0.0];
        var lvls = [1, 1, 1, 1, 1];
        var pcts = [0, 0, 0, 0, 0];
        var maxVal = 1.0;

        for (var i = 0; i < 5; i++) {
            var st = stats[statLabels[i]] as Dictionary;
            var lvl = st["level"] as Number;
            var xp = st["xp"] as Float;
            var req = state.nextLevelXp(lvl).toFloat();
            var pct = (req > 0.0) ? (xp / req) : 0.0;
            if (pct < 0.0) { pct = 0.0; }
            if (pct > 1.0) { pct = 1.0; }
            lvls[i] = lvl;
            pcts[i] = (pct * 100.0).toNumber();
            var eff = (lvl - 1).toFloat() + pct;
            rawVals[i] = eff;
            if (eff > maxVal) {
                maxVal = eff;
            }
        }

        var px = [0, 0, 0, 0, 0];
        var py = [0, 0, 0, 0, 0];
        for (var i = 0; i < 5; i++) {
            var ratio = 0.25 + (0.75 * (rawVals[i] / maxVal));
            if (ratio > 1.0) { ratio = 1.0; }
            var rStat = maxR.toFloat() * ratio;
            px[i] = cx + (rStat * cosA[i]).toNumber();
            py[i] = cy + (rStat * sinA[i]).toNumber();
        }

        // 3. Draw glowing player stat polygon outline & vertex nodes
        if (dc has :setPenWidth) {
            dc.setPenWidth(2);
        }
        dc.setColor(COLOR_CYAN, Graphics.COLOR_BLACK);
        for (var i = 0; i < 5; i++) {
            var nextI = (i + 1) % 5;
            dc.drawLine(px[i], py[i], px[nextI], py[nextI]);
        }
        if (dc has :setPenWidth) {
            dc.setPenWidth(1);
        }

        // 4. Vertex Labels with Stat Name + Level + XP % (replaces standalone Stat Progress page)
        var labelR = maxR + (hTiny * 0.72).toNumber();
        for (var i = 0; i < 5; i++) {
            drawRpgDiamond(dc, px[i], py[i], 2, true, statColors[i]);
            var lx = cx + (labelR * cosA[i]).toNumber();
            var ly = cy + (labelR * sinA[i]).toNumber() - (hTiny / 2);
            dc.setColor(statColors[i], Graphics.COLOR_TRANSPARENT);

            if (i == 0) {
                // Top vertex (STR): draw "STR 1 " in Amber + "(0%)" in Light Gray so it matches the other 4 stats
                var strPart = statLabels[i] + " " + lvls[i].toString() + " ";
                var pctPart = "(" + pcts[i].toString() + "%)";
                var strW = dc.getTextDimensions(strPart, Graphics.FONT_XTINY)[0];
                var pctW = dc.getTextDimensions(pctPart, Graphics.FONT_XTINY)[0];
                var startX = lx - ((strW + pctW) / 2);

                dc.setColor(statColors[i], Graphics.COLOR_TRANSPARENT);
                dc.drawText(startX, ly - 2, Graphics.FONT_XTINY, strPart, Graphics.TEXT_JUSTIFY_LEFT);
                dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(startX + strW, ly - 2, Graphics.FONT_XTINY, pctPart, Graphics.TEXT_JUSTIFY_LEFT);
            } else {
                // Side & bottom vertices: stacked 2-line badge ("AGI 1" over "(0%)") for consistent formatting
                var line1 = statLabels[i] + " " + lvls[i].toString();
                var line2 = "(" + pcts[i].toString() + "%)";
                var baseLy = (i == 2 || i == 3) ? (ly - 4) : (ly - (hTiny / 2) + 2);
                dc.drawText(lx, baseLy, Graphics.FONT_XTINY, line1, Graphics.TEXT_JUSTIFY_CENTER);
                dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(lx, baseLy + hTiny - 4, Graphics.FONT_XTINY, line2, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        drawPageIndicator(dc, 2);
    }

    // --- Screen 4: Daily Activity History Log (Centered Layout) ---
    function drawDailySummary(dc as Dc, state as LifeQuestState) as Void {
        var width = dc.getWidth();
        var center = width / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        drawHudOverlay(dc);
        var curY = drawSystemHeader(dc, "[ ACTIVITY LOG ]") + 12;

        var log = state.data["dailyLog"] as Array;
        var spacingY = hTiny + 8;

        if (log == null || log.size() == 0) {
            // Empty Slate Placeholder View
            dc.setColor(COLOR_DK_GRAY, Graphics.COLOR_BLACK);
            dc.drawText(center, center - (hTiny / 2), Graphics.FONT_XTINY, "No quests completed today.", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            for (var i = 0; i < log.size(); i++) {
                var entry = log[i].toString();

                dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);

                // If it contains a "+" sign, highlight the stats in neon green while centering the full line
                var plusIdx = entry.find("+");
                if (plusIdx != null) {
                    var titleText = entry.substring(0, plusIdx);
                    var statText = entry.substring(plusIdx, entry.length());

                    var titleW = dc.getTextDimensions(titleText, Graphics.FONT_XTINY)[0];
                    var statW = dc.getTextDimensions(statText, Graphics.FONT_XTINY)[0];
                    var startX = center - ((titleW + statW) / 2);

                    dc.setColor(COLOR_CYAN, Graphics.COLOR_BLACK);
                    dc.drawText(startX, curY, Graphics.FONT_XTINY, titleText, Graphics.TEXT_JUSTIFY_LEFT);

                    dc.setColor(COLOR_GREEN, Graphics.COLOR_BLACK);
                    dc.drawText(startX + titleW, curY, Graphics.FONT_XTINY, statText, Graphics.TEXT_JUSTIFY_LEFT);
                } else {
                    dc.drawText(center, curY, Graphics.FONT_XTINY, entry, Graphics.TEXT_JUSTIFY_CENTER);
                }

                curY += spacingY;
            }
        }

        drawPageIndicator(dc, 3);
    }

    // --- UI Helpers & Geometric Primitives ---
    function characterProgress(state as LifeQuestState) as Float {
        var currentXp = state.characterXp();
        var nextXp = state.characterNextLevelXp();
        if (nextXp <= 0.0) {
            return 0.0;
        }
        var progress = currentXp / nextXp;
        if (progress > 1.0) { progress = 1.0; }
        if (progress < 0.0) { progress = 0.0; }
        return progress.toFloat();
    }

    // 🌟 Scaled Vector RPG Attribute Icons (Sword, Lightning Bolt, Arcane Crystal, Shield Crest, All-Seeing Eye)
    function drawStatIcon(dc as Dc, cx as Number, cy as Number, statSym as Symbol, color as Number) as Void {
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var r = (hTiny * 0.30).toNumber();
        if (r < 5) { r = 5; }
        var half = (r * 0.55).toNumber();
        if (half < 3) { half = 3; }

        dc.setColor(color, Graphics.COLOR_BLACK);
        if (dc has :setPenWidth) {
            dc.setPenWidth(2);
        }

        if (statSym == :STR) {
            // Broad Sword: Thick diagonal blade + wide crossguard + pommel
            dc.drawLine(cx - r, cy + r, cx + r, cy - r);
            dc.drawLine(cx - half, cy - (half / 2), cx + (half / 2), cy + half);
            dc.fillCircle(cx - r, cy + r, 2);
        } else if (statSym == :AGI) {
            // Bold Filled Lightning Bolt
            dc.fillPolygon([
                [cx + 2, cy - r],
                [cx - half - 1, cy + 1],
                [cx, cy + 1],
                [cx - 2, cy + r],
                [cx + half + 1, cy - 1],
                [cx, cy - 1]
            ]);
        } else if (statSym == :INT) {
            // Arcane Crystal: Thick outer diamond + glowing inner diamond core
            dc.drawLine(cx, cy - r, cx + r, cy);
            dc.drawLine(cx + r, cy, cx, cy + r);
            dc.drawLine(cx, cy + r, cx - r, cy);
            dc.drawLine(cx - r, cy, cx, cy - r);
            drawRpgDiamond(dc, cx, cy, half - 1, true, COLOR_WHITE);
        } else if (statSym == :VIT) {
            // Heater Shield Crest: Broad top + tapered bottom point + inner emblem
            dc.drawLine(cx - r, cy - r + 1, cx + r, cy - r + 1);
            dc.drawLine(cx - r, cy - r + 1, cx - r, cy);
            dc.drawLine(cx + r, cy - r + 1, cx + r, cy);
            dc.drawLine(cx - r, cy, cx, cy + r);
            dc.drawLine(cx + r, cy, cx, cy + r);
            dc.fillCircle(cx, cy - 1, 2);
        } else {
            // PER: Bold All-Seeing Eye + Glowing Pupil
            var eyeH = (r * 0.72).toNumber();
            if (eyeH < 4) { eyeH = 4; }
            dc.drawLine(cx - r, cy, cx, cy - eyeH);
            dc.drawLine(cx, cy - eyeH, cx + r, cy);
            dc.drawLine(cx - r, cy, cx, cy + eyeH);
            dc.drawLine(cx, cy + eyeH, cx + r, cy);
            dc.fillCircle(cx, cy, (r * 0.35).toNumber());
        }

        if (dc has :setPenWidth) {
            dc.setPenWidth(1);
        }
    }

    // 🌟 Renders page indicator accent geometric nodes
    function drawRpgDiamond(dc as Dc, x as Number, y as Number, size as Number, fill as Boolean, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_BLACK);
        if (fill) {
            dc.fillPolygon([
                [x, y - size],
                [x + size, y],
                [x, y + size],
                [x - size, y]
            ]);
        } else {
            dc.drawLine(x, y - size, x + size, y);
            dc.drawLine(x + size, y, x, y + size);
            dc.drawLine(x, y + size, x - size, y);
            dc.drawLine(x - size, y, x, y - size);
        }
    }

    // 🌟 Segmented RPG Energy Bar with 5 Cells & Glowing White Leading Edge
    function drawRpgProgressBar(dc as Dc, x as Number, y as Number, width as Number, height as Number, progress as Float, color as Number) as Void {
        // 1. Background slate trough frame border
        dc.setColor(COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawRectangle(x, y, width, height);

        // 2. Filled energy track
        var fillWidth = (width * progress).toNumber();
        if (fillWidth > 2) {
            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.fillRectangle(x + 1, y + 1, fillWidth - 2, height - 2);

            // Glowing white energy cap at the leading edge
            if (progress < 0.99) {
                dc.setColor(COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.fillRectangle(x + fillWidth - 2, y + 1, 2, height - 2);
            }
        }

        // 3. 5-Cell RPG segment divider notches
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        for (var s = 1; s < 5; s++) {
            var segX = x + ((width * s) / 5);
            dc.drawLine(segX, y + 1, segX, y + height - 2);
        }
    }

    function drawProgressBar(dc as Dc, x as Number, y as Number, width as Number,
        progress as Float, color as Number) as Void {
        drawRpgProgressBar(dc, x, y, width, 6, progress, color);
    }

    // 🌟 Status / Condition text engine (Scaled diamond icon + FATIGUE or NORMAL label)
    function drawConditionStatus(dc as Dc, x as Number, y as Number, state as LifeQuestState) as Void {
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var iconY = y + (hTiny / 2);
        var iconR = (hTiny * 0.30).toNumber();
        if (iconR < 5) { iconR = 5; }
        var textX = x + (iconR * 2) + 5;

        if (state.hasAnyFatigue()) {
            drawRpgDiamond(dc, x + iconR, iconY, iconR - 1, true, COLOR_RED);
            dc.setColor(COLOR_RED, Graphics.COLOR_BLACK);
            dc.drawText(textX, y, Graphics.FONT_XTINY, "FATIGUE", Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            drawRpgDiamond(dc, x + iconR, iconY, iconR - 1, true, COLOR_GREEN);
            dc.setColor(COLOR_GREEN, Graphics.COLOR_BLACK);
            dc.drawText(textX, y, Graphics.FONT_XTINY, "NORMAL", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    function onHide() as Void {}
}
