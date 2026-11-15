# ⚔️ Bounce Back (Re:Bounce)

> **Master the Parry. Defy the Void.**

**Bounce Back** is an intense, fast-paced action arena game built in **Godot 4**. Combining bullet-hell survival, precision platforming, and absolute timing mastery, players must survive escalating waves of enemies using tight mechanics, unique hero abilities, and the ultimate defensive tool: the **Perfect Parry**.

Developed by **Mounib Reda**, **Chingiz Shikhgayibov**, and **Nurazkhan Nygmet**.

---

## 🌟 Features

* **The Perfect Parry System:** Passive dodging isn't enough. Press `[F]` in a tight, rewarding window to deflect incoming enemy lasers mid-air. Deflected projectiles gain an aimbot-homing effect, turning the enemy's weapons into your own arsenal.
* **Overcharged Game Feel:** Every impact, elimination, and successful parry is amplified by intense screen shaking, ground cracks, expanding shockwave rings, and dynamic hazard telegraphs.
* **Procedural Chiptune Audio:** All music and sound effects are generated mathematically in real-time through Godot's AudioStreamGenerator—no external MP3s or WAVs!
* **Code-Rendered Visuals:** Almost all visuals, from the Terraria-inspired underworld map to the Geometry Dash-inspired neon bosses, are drawn procedurally using Godot's `_draw()` API.
* **Epic Boss Encounters:** Multi-phased, complex boss fights that will test your reflexes and positioning to the absolute limit.

---

## 🎮 Controls

| Action | Keybinding |
| :--- | :--- |
| **Move Left / Right** | `A` / `D` or `Left Arrow` / `Right Arrow` |
| **Jump** | `W`, `Space`, or `Up Arrow` |
| **Perfect Parry** | `F` |
| **Hero Ability** | `Shift` |
| **Navigate Menus** | Mouse Click (or Arrows/Enter for Character Select) |

> **Pro Tip:** Pressing Parry (`F`) too early triggers a cooldown penalty. Wait until the laser is within your aura radius to execute a Perfect Parry and instantly reset your cooldown!

---

## 🛡️ Character Classes

Choose from three distinct heroes, each with a unique playstyle and special ability triggered by `[SHIFT]`:

### 🗡️ The Bandit (Agility & Burst)
* **Ability:** *Shadow Dash* (5s Cooldown)
* **Description:** Dash a massive distance across the arena in a flash. Grants complete invulnerability (hitbox negation) while dashing, leaving wind trails and ghost afterimages. Perfect for slipping through dense bullet walls or dodging boss slams.

### ⚡ The Scientist (Control & Timing)
* **Ability:** *Temporal Freeze* (10s Cooldown)
* **Description:** Stops reality itself for 1 full second. Freezes both flying mobs and incoming lasers in mid-air with an ethereal chronofield while letting you move freely to position yourself for the perfect parry.

### ✚ The Nurse (Sustain & Survival)
* **Ability:** *Vital Regeneration* (Passive)
* **Description:** Passively restores 1 Heart every 8 seconds automatically. Keeps you resilient throughout extended battles and bullet-hell swarms. The ultimate pick for outlasting extreme boss encounters.

---

## ☠️ Boss Waves

Survive standard waves of Demon Eyes, Corrupt Hornets, and Hellwing Imps to reach the apex predators of the arena:

* **Wave 5: The Apex Anomaly**
  A hyperactive crimson eye boss requiring 20 successful laser deflections. Features twin heavy aimed lasers, multi-way crossfire patterns, and an aggressive enrage state.
  
* **Wave 7: The Void Tesseract**
  A dimensional neon-purple cube. Watch out for its sudden teleportation blinks, rotating geometric laser spirals, and cataclysmic *Seismic Void Slams* that shatter the ground and erupt into void pillars.

* **Wave 10: The Auric Seraph (Final Boss)**
  A supreme golden deity with articulated wings and rotating halos. It commands the arena by dropping solar judgment pillars from the sky and executing a devastating *Golden Supernova Dive* that destroys the center of the map.

---

## 🚀 Installation & Setup

### Running the Game in Godot
1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/bounce-back.git
   ```
2. Open **Godot 4** (Recommended 4.2+).
3. Click **Import** and select the `project.godot` file in the cloned directory.
4. Open `main.tscn` as the main scene.
5. Press the **Play** button (`F5`) to run the game!

### Exporting for Web (HTML5)
1. In Godot, go to **Project** -> **Export**.
2. Add a **Web** preset.
3. Click **Export Project** and save it to an empty folder (e.g., `web_build/`).
4. To test locally, open a terminal in your export folder and run a Python server:
   ```bash
   python -m http.server 8000
   ```
5. Open your browser and navigate to `http://localhost:8000`.

---

## 🛠️ Tech Stack & Architecture

This project is a masterclass in utilizing Godot's built-in 2D rendering and procedural generation:
* **Engine:** Godot 4.x (GL Compatibility)
* **Language:** GDScript
* **Single-Script Architecture:** The vast majority of the game's logic (state machines, physics, AI, rendering, UI, and procedural audio) is elegantly contained within a single `game.gd` script.

---

## 👥 Credits

* **Mounib Reda** - Co-Creator / Developer
* **Chingiz Shikhgayibov** - Co-Creator / Developer
* **Nurazkhan Nygmet** - Co-Creator / Developer

---

## 📄 License

This project is open-source. Feel free to fork, study the procedural rendering and audio, and build upon the intense boss mechanics!