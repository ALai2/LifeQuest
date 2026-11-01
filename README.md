# LifeQuest - Real-Life RPG System for Garmin Smartwatches

A gamified self-improvement and fitness companion app for Garmin smartwatches, inspired by **The System** from *Solo Leveling*. 

Turn daily steps, workouts, habits, and recovery into a high-tech RPG progression system complete with character levels, ranks, attribute matrix, daily quests, and penalty zones.

---

## ⚡ Features

### 1. Hunter Status Window
- **Player Level & Rank Progression:** Level up from **Rank F** all the way to **Rank SSS** based on accumulated XP.
- **Experience Gauge:** High-contrast RPG XP bar tracking progress toward the next level with percentage readouts.
- **2-Column Attribute Matrix:**
  - **STR (Strength):** Leveled through strength training, gym sessions, and weighted exercise.
  - **AGI (Agility):** Leveled through running, speed work, and yoga.
  - **VIT (Vitality):** Leveled through daily endurance, steps, cycling, and swimming.
  - **INT (Intelligence):** Leveled through daily reading and mental training.
  - **PER (Perception):** Leveled through sleep score and consistent recovery.
- **Fatigue System:** Tracks missed daily quests and applies temporary stat fatigue debuffs (50% XP penalty) until cleared.

### 2. Daily Quest Log
- **Daily Objectives:**
  - **Workout:** 10+ minute tracked workout session (+20 XP).
  - **Reading:** 20 minutes of intellect training (+20 INT XP).
  - **10K Steps:** Automatically synchronized with Garmin's native step counter (+10 VIT / +10 AGI XP).
- **The Penalty Zone:**
  - If daily quests are missed, the System triggers a high-alert **Penalty Zone** survival quest (1.0 mile run) to clear the penalty and remove stat fatigue.

### 3. Intellect / Reading Training
- Dedicated training screen with minutes counter and goal tracker.
- Built-in timer and manual session logging via the watch menu.

---

## ⌚ Supported Devices

- Garmin Forerunner 255 (MIP Display)
- Garmin Forerunner 265 (AMOLED Display)
- Any Garmin Connect IQ device running API Level 3.2.0+

---

## 🛠️ Building & Developing

1. Install the **Garmin Connect IQ SDK** and the **Monkey C** extension in Visual Studio Code.
2. Generate or locate your `developer_key.der`.
3. Open this folder in VS Code.
4. Press `F5` or run **Monkey C: Run Application** to launch the Connect IQ Simulator.

---

## 📜 License

MIT License.

