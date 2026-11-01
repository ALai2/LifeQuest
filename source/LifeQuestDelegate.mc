import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class LifeQuestDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.CustomMenu(82, Graphics.COLOR_BLACK, {
            :title => new LifeQuestSystemMenuHeaderDrawable("SYSTEM MENU")
        });
        menu.addItem(new LifeQuestMainMenuCustomItem(
            :log_reading,
            "LOG STUDY / READ",
            "+INT XP • Daily Quest",
            0x00D9FF,
            :icon_book
        ));
        menu.addItem(new LifeQuestMainMenuCustomItem(
            :equip_title,
            "EQUIP TITLE",
            "Passive Stat Buffs",
            0xFFD700,
            :icon_crown
        ));
        menu.addItem(new LifeQuestMainMenuCustomItem(
            :reset_reading,
            "RESET STUDY",
            "Undo Today's Mins",
            0xFF3333,
            :icon_reset
        ));
        WatchUi.pushView(menu, new LifeQuestMainCustomMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onNextPage() as Boolean {
        getApp().nextPage();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        getApp().previousPage();
        WatchUi.requestUpdate();
        return true;
    }
}

class LifeQuestMainCustomMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :log_reading) {
            openReadingPicker();
        } else if (id == :equip_title) {
            openTitleSelectorMenu();
        } else if (id == :reset_reading) {
            var state = getApp().getCharacterState();
            state.resetReading();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.requestUpdate();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    function openTitleSelectorMenu() as Void {
        var state = getApp().getCharacterState();
        var equipped = state.data.hasKey("equippedTitle")
            ? (state.data["equippedTitle"] as String)
            : "AUTO";

        var menu = new WatchUi.CustomMenu(78, Graphics.COLOR_BLACK, {
            :title => new LifeQuestSystemMenuHeaderDrawable("EQUIP TITLE")
        });

        var autoBuff = "+" + state.autoRankBuffPercent().toString() + "% ALL";
        var autoColor = state.titleColorFor(state.hunterTitle());
        menu.addItem(new LifeQuestTitleCustomItem(
            "AUTO",
            "Auto (" + state.hunterTitle() + ")",
            autoBuff + " (" + state.hunterTitle() + ")",
            autoColor,
            true,
            equipped.equals("AUTO")
        ));

        var allTitles = state.getAllAchievementTitles();
        for (var i = 0; i < allTitles.size(); i++) {
            var entry = allTitles[i] as Dictionary;
            var id = entry["id"] as String;
            var buff = entry["buff"] as String;
            var hint = entry["hint"] as String;
            var color = entry["color"] as Number;
            var unlocked = state.isTitleUnlocked(id);
            var subLine = unlocked ? (buff + " (" + hint + ")") : (buff + " • " + hint);

            menu.addItem(new LifeQuestTitleCustomItem(
                unlocked ? id : ("LOCKED_" + id),
                id,
                subLine,
                color,
                unlocked,
                equipped.equals(id)
            ));
        }

        WatchUi.pushView(menu, new LifeQuestTitleMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function openReadingPicker() as Void {
        var studyView = new LifeQuestStudyHudView();
        WatchUi.pushView(studyView, new LifeQuestStudyHudDelegate(studyView), WatchUi.SLIDE_UP);
    }
}

class LifeQuestStudyHudView extends WatchUi.View {
    var manualMinutes as Number = 0;
    var uiTimer as Timer.Timer or Null;

    const COLOR_CYAN      = 0x00D9FF;
    const COLOR_DARK_BLUE = 0x003366;
    const COLOR_GREEN     = 0x00FF66;
    const COLOR_AMBER     = 0xFF8800;
    const COLOR_GOLD      = 0xFFCC00;
    const COLOR_WHITE     = Graphics.COLOR_WHITE;
    const COLOR_LT_GRAY   = Graphics.COLOR_LT_GRAY;
    const COLOR_DK_GRAY   = Graphics.COLOR_DK_GRAY;

    function initialize() {
        View.initialize();
        manualMinutes = 0;
    }

    function onShow() as Void {
        syncTimerTick();
    }

    function onHide() as Void {
        stopUiTimer();
    }

    function syncTimerTick() as Void {
        var state = getApp().getCharacterState();
        var startEpoch = state.data.hasKey("studyTimerStart") ? (state.data["studyTimerStart"] as Number) : 0;
        if (startEpoch > 0) {
            if (uiTimer == null) {
                uiTimer = new Timer.Timer();
                uiTimer.start(method(:onTimerTick), 1000, true);
            }
        } else {
            stopUiTimer();
        }
    }

    function stopUiTimer() as Void {
        if (uiTimer != null) {
            uiTimer.stop();
            uiTimer = null;
        }
    }

    function onTimerTick() as Void {
        WatchUi.requestUpdate();
    }

    function adjustManualMinutes(delta as Number) as Void {
        var state = getApp().getCharacterState();
        var startEpoch = state.data.hasKey("studyTimerStart") ? (state.data["studyTimerStart"] as Number) : 0;
        if (startEpoch > 0) {
            // Ignore manual +/- while live stopwatch is actively running
            return;
        }
        manualMinutes += delta;
        if (manualMinutes < 0) {
            manualMinutes = 0;
        } else if (manualMinutes > 180) {
            manualMinutes = 180;
        }
        WatchUi.requestUpdate();
    }

    function handleSelectAction() as Boolean {
        var state = getApp().getCharacterState();
        var startEpoch = state.data.hasKey("studyTimerStart") ? (state.data["studyTimerStart"] as Number) : 0;

        if (startEpoch > 0) {
            // Stop Live Timer & Log Elapsed Minutes (minimum 1 minute if ran >= 15 seconds)
            var elapsedSec = Time.now().value() - startEpoch;
            state.data["studyTimerStart"] = 0;
            state.save();
            stopUiTimer();

            var minsToLog = (elapsedSec / 60).toNumber();
            if (minsToLog < 1 && elapsedSec >= 15) {
                minsToLog = 1;
            }
            if (minsToLog > 0) {
                state.recordReading(minsToLog);
            }
            // Pop both Study HUD and System Menu back to the main dashboard
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.requestUpdate();
            return true;
        }

        if (manualMinutes > 0) {
            // Quick-Log Mode: Log selected manual minutes immediately
            state.recordReading(manualMinutes);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.requestUpdate();
            return true;
        }

        // Start Live Focus Stopwatch
        state.data["studyTimerStart"] = Time.now().value();
        state.save();
        syncTimerTick();
        WatchUi.requestUpdate();
        return true;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = w / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var state = getApp().getCharacterState();
        var startEpoch = state.data.hasKey("studyTimerStart") ? (state.data["studyTimerStart"] as Number) : 0;
        var isRunning = (startEpoch > 0);

        // 1. Solo Leveling Outer Bezel Arcs & Corner Frame
        var mainView = getApp().getLifeQuestView();
        if (mainView != null) {
            mainView.drawHudOverlayMode(dc, false);
        }

        var headerY = (h * 0.10).toNumber();
        var headerTitle = isRunning ? "STUDYING..." : "INTELLECT HUD";
        dc.setColor(isRunning ? COLOR_GREEN : COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, headerY, Graphics.FONT_XTINY, "[ " + headerTitle + " ]", Graphics.TEXT_JUSTIFY_CENTER);

        var lineY = headerY + hTiny + 2;
        dc.setColor(COLOR_DARK_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.18).toNumber(), lineY, (w * 0.82).toNumber(), lineY);

        var curY = lineY + 6;

        // 2. Center Readout: Live Stopwatch (MM:SS) or Manual Quick-Log (+Xm)
        var elapsedSec = isRunning ? (Time.now().value() - startEpoch) : 0;
        if (elapsedSec < 0) { elapsedSec = 0; }

        var mainReadout = "00:00";
        var previewMins = 0.0;
        if (isRunning) {
            var mm = (elapsedSec / 60).toNumber();
            var ss = (elapsedSec % 60).toNumber();
            mainReadout = mm.format("%02d") + ":" + ss.format("%02d");
            previewMins = elapsedSec.toFloat() / 60.0;
        } else if (manualMinutes > 0) {
            mainReadout = "+" + manualMinutes.toString() + " MIN";
            previewMins = manualMinutes.toFloat();
        } else {
            mainReadout = "00:00";
            previewMins = 0.0;
        }

        var hMed = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var readoutColor = isRunning ? COLOR_GREEN : (manualMinutes > 0 ? COLOR_GOLD : COLOR_WHITE);
        dc.setColor(readoutColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, curY, Graphics.FONT_MEDIUM, mainReadout, Graphics.TEXT_JUSTIFY_CENTER);
        curY += hMed + 2;

        // 3. Live INT XP Preview & Today's Quest Progress Bar
        var quests = state.data["quests"] as Dictionary;
        var todayMins = quests["readingMinutes"] as Number;
        var goalMins = state.readingGoalMinutes();
        var effectiveTotal = todayMins.toFloat() + previewMins;
        var pct = (goalMins > 0) ? (effectiveTotal / goalMins.toFloat()) : 0.0;
        if (pct > 1.0) { pct = 1.0; }

        var xpGain = (previewMins / 10.0) * state.fatigueMultiplier(:INT) * state.titleBuffMultiplier(:INT);
        var subInfo = "Today: " + todayMins.toString() + "/" + goalMins.toString() + "m";
        if (previewMins > 0.0) {
            subInfo = "+" + xpGain.format("%.1f") + " INT • " + todayMins.toString() + "/" + goalMins.toString() + "m";
        }
        dc.setColor(COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, curY, Graphics.FONT_XTINY, subInfo, Graphics.TEXT_JUSTIFY_CENTER);
        curY += hTiny + 4;

        var barW = (w * 0.62).toNumber();
        var barX = center - (barW / 2);
        if (mainView != null) {
            mainView.drawRpgProgressBar(dc, barX, curY, barW, 6, pct, pct >= 1.0 ? COLOR_GREEN : COLOR_CYAN);
        }
        curY += 12;

        // 4. Primary Action Button Box (START Timer / STOP & SAVE / LOG +Xm)
        var btnW = (w * 0.68).toNumber();
        var btnH = hTiny + 6;
        var btnX = center - (btnW / 2);
        var btnColor = isRunning ? COLOR_GREEN : (manualMinutes > 0 ? COLOR_GOLD : COLOR_CYAN);
        var btnText = "[START] TIMER";
        if (isRunning) {
            btnText = "[START] SAVE & STOP";
        } else if (manualMinutes > 0) {
            btnText = "[START] LOG " + manualMinutes.toString() + "M";
        }

        dc.setColor(0x001A33, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(btnX, curY, btnW, btnH, 4);
        dc.setColor(btnColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(btnX, curY, btnW, btnH, 4);
        dc.setColor(COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, curY + 2, Graphics.FONT_XTINY, btnText, Graphics.TEXT_JUSTIFY_CENTER);
        curY += btnH + 4;

        // 5. Bottom Hint for Dual Mode Controls
        dc.setColor(COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var hintStr = isRunning ? "Timer active in bg" : "UP/DN: Quick +/-5m";
        dc.drawText(center, curY, Graphics.FONT_XTINY, hintStr, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class LifeQuestStudyHudDelegate extends WatchUi.BehaviorDelegate {
    var view as LifeQuestStudyHudView;

    function initialize(v as LifeQuestStudyHudView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() as Boolean {
        return view.handleSelectAction();
    }

    function onNextPage() as Boolean {
        // DOWN button / swipe up -> -5m (or +5m if at 0)
        if (view.manualMinutes == 0) {
            view.adjustManualMinutes(20); // First press jumps straight to 20m daily goal!
        } else {
            view.adjustManualMinutes(-5);
        }
        return true;
    }

    function onPreviousPage() as Boolean {
        // UP button / swipe down -> +5m (first press jumps to 20m daily goal if at 0)
        if (view.manualMinutes == 0) {
            view.adjustManualMinutes(20);
        } else {
            view.adjustManualMinutes(5);
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}

class LifeQuestSystemMenuHeaderDrawable extends WatchUi.Drawable {
    var headerTitle as String;

    function initialize(title as String) {
        Drawable.initialize({});
        headerTitle = title;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = w / 2;
        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Push header down below the top bezel curve so it never clips
        var textY = h - hTiny - 10;
        if (textY < (h * 0.35).toNumber()) {
            textY = (h * 0.35).toNumber();
        }

        var textW = dc.getTextDimensions(headerTitle, Graphics.FONT_XTINY)[0];
        var badgeR = 7;
        var badgeGap = 5;
        var totalW = (badgeR * 2) + badgeGap + textW;
        var startX = center - (totalW / 2);

        // 1. Solo Leveling [ ! ] Notification Badge
        var badgeCx = startX + badgeR;
        var badgeCy = textY + (hTiny / 2);
        dc.setColor(0x003366, Graphics.COLOR_BLACK);
        dc.fillCircle(badgeCx, badgeCy, badgeR);
        dc.setColor(0x00D9FF, Graphics.COLOR_BLACK);
        dc.drawCircle(badgeCx, badgeCy, badgeR);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillRectangle(badgeCx - 1, badgeCy - 4, 2, 5);
        dc.fillRectangle(badgeCx - 1, badgeCy + 2, 2, 2);

        // 2. Header Title
        dc.setColor(0x00D9FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + (badgeR * 2) + badgeGap, textY, Graphics.FONT_XTINY, headerTitle,
            Graphics.TEXT_JUSTIFY_LEFT);

        // 3. Double-Line Glowing System Divider Bar
        var lineY = h - 4;
        var outerPad = (w * 0.14).toNumber();
        var innerPad = (w * 0.26).toNumber();
        dc.setColor(0x003366, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(outerPad, lineY, w - outerPad, lineY);
        dc.setColor(0x00D9FF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(innerPad, lineY, w - innerPad, lineY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(center - 2, lineY - 2, 5, 5);
    }
}

class LifeQuestMainMenuCustomItem extends WatchUi.CustomMenuItem {
    var labelText as String;
    var subText as String;
    var accentColor as Number;
    var iconType as Symbol;

    function initialize(id as Symbol, label as String, sub as String, color as Number, icon as Symbol) {
        CustomMenuItem.initialize(id, {});
        labelText = label;
        subText = sub;
        accentColor = color;
        iconType = icon;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Solo Leveling HUD Card with Corner Brackets
        var cardX = 8;
        var cardY = 3;
        var cardW = w - 16;
        var cardH = h - 6;

        if (focused) {
            dc.setColor(0x001A33, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 5);
            dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 5);
            // Glowing corner ticks
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cardX, cardY + 6, cardX, cardY);
            dc.drawLine(cardX, cardY, cardX + 6, cardY);
            dc.drawLine(cardX + cardW - 6, cardY + cardH - 1, cardX + cardW - 1, cardY + cardH - 1);
            dc.drawLine(cardX + cardW - 1, cardY + cardH - 6, cardX + cardW - 1, cardY + cardH - 1);
        } else {
            dc.setColor(0x002244, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 5);
        }

        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var topY = ((h - (hTiny * 2) - 2) / 2).toNumber();
        if (topY < 2) { topY = 2; }
        var subY = topY + hTiny + 2;

        // Custom RPG Vector Icon on Left
        var iconCx = 24;
        var iconCy = h / 2;
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);

        if (iconType == :icon_book) {
            // Arcane Tome / Crystal Icon
            dc.drawRectangle(iconCx - 6, iconCy - 7, 12, 14);
            dc.drawLine(iconCx - 3, iconCy - 3, iconCx + 3, iconCy - 3);
            dc.drawLine(iconCx - 3, iconCy + 1, iconCx + 3, iconCy + 1);
        } else if (iconType == :icon_crown) {
            // Monarch Crown / Crest Icon
            var pts = [
                [iconCx - 7, iconCy + 5],
                [iconCx - 7, iconCy - 4],
                [iconCx - 3, iconCy + 1],
                [iconCx,     iconCy - 6],
                [iconCx + 3, iconCy + 1],
                [iconCx + 7, iconCy - 4],
                [iconCx + 7, iconCy + 5]
            ];
            dc.fillPolygon(pts);
        } else {
            // Reset / Rewind Warning Diamond
            var pts = [
                [iconCx, iconCy - 6],
                [iconCx + 6, iconCy],
                [iconCx, iconCy + 6],
                [iconCx - 6, iconCy]
            ];
            dc.drawLine(pts[0][0], pts[0][1], pts[1][0], pts[1][1]);
            dc.drawLine(pts[1][0], pts[1][1], pts[2][0], pts[2][1]);
            dc.drawLine(pts[2][0], pts[2][1], pts[3][0], pts[3][1]);
            dc.drawLine(pts[3][0], pts[3][1], pts[0][0], pts[0][1]);
            dc.fillRectangle(iconCx - 1, iconCy - 1, 3, 3);
        }

        var textX = 40;
        dc.setColor(focused ? Graphics.COLOR_WHITE : accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, topY, Graphics.FONT_XTINY, labelText, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(focused ? accentColor : 0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, subY, Graphics.FONT_XTINY, subText, Graphics.TEXT_JUSTIFY_LEFT);
    }
}

class LifeQuestTitleCustomItem extends WatchUi.CustomMenuItem {
    var titleText as String;
    var subText as String;
    var statColor as Number;
    var isUnlocked as Boolean;
    var isEquipped as Boolean;

    function initialize(id as String, label as String, hint as String, color as Number, unlocked as Boolean, equipped as Boolean) {
        CustomMenuItem.initialize(id, {});
        titleText = label;
        subText = hint;
        statColor = color;
        isUnlocked = unlocked;
        isEquipped = equipped;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Subtle RPG System Card background when focused
        if (focused) {
            dc.setColor(0x001A33, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(6, 2, w - 12, h - 4, 4);
            dc.setColor(isUnlocked ? statColor : 0x444444, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(6, 2, w - 12, h - 4, 4);
        }

        var hTiny = dc.getFontHeight(Graphics.FONT_XTINY);
        var topY = ((h - (hTiny * 2) - 4) / 2).toNumber();
        if (topY < 2) { topY = 2; }
        var subY = topY + hTiny + 4;

        // Left Icon aligned vertically with Row 1 (Title Name)
        var iconCx = 18;
        var iconCy = topY + (hTiny / 2);

        if (isUnlocked) {
            dc.setColor(statColor, Graphics.COLOR_TRANSPARENT);
            var pts = [
                [iconCx, iconCy - 5],
                [iconCx + 5, iconCy],
                [iconCx, iconCy + 5],
                [iconCx - 5, iconCy]
            ];
            dc.fillPolygon(pts);
            if (isEquipped) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(iconCx - 1, iconCy - 1, 3, 3);
            }
        } else {
            // Vector Padlock Icon (Shackle + Body + Keyhole)
            var lockColor = focused ? 0x999999 : 0x666666;
            dc.setColor(lockColor, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(iconCx - 3, iconCy - 6, 7, 5);
            dc.fillRectangle(iconCx - 5, iconCy - 2, 11, 8);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(iconCx - 1, iconCy, 3, 4);
        }

        // Row 1: Title Name (+ compact "[ON]" pill when equipped so Row 2 has full room for buff/hint)
        var textX = 30;
        var nameColor = isUnlocked ? statColor : 0x777777;
        dc.setColor(nameColor, Graphics.COLOR_TRANSPARENT);
        var displayTitle = isEquipped ? (titleText + " [ON]") : titleText;
        dc.drawText(textX, topY, Graphics.FONT_XTINY, displayTitle, Graphics.TEXT_JUSTIFY_LEFT);

        // Row 2: Compact Buff + Unlock Hint (fits well inside the round bezel)
        if (isEquipped) {
            dc.setColor(0x00FF66, Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, subY, Graphics.FONT_XTINY, subText, Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(statColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(textX, subY + (hTiny / 2) - 2, 4, 4);
            dc.setColor(focused ? 0xCCCCCC : 0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX + 8, subY, Graphics.FONT_XTINY, subText, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}

class LifeQuestTitleMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var idObj = item.getId();
        if (idObj != null) {
            var idStr = idObj.toString();
            // Only equip if unlocked (or "AUTO"); ignore taps on "[LOCKED]" items
            if (idStr.find("LOCKED_") == null) {
                var state = getApp().getCharacterState();
                state.equipTitle(idStr);
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                WatchUi.requestUpdate();
            }
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

