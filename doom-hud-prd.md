# DOOM-Style Productivity HUD - PRD

## Product Overview

A retro-styled productivity monitoring application inspired by the classic DOOM status bar, providing real-time visual feedback on work activity while automatically capturing screenshots for daily timelapse generation.

## Core Features

### 1. Visual Interface Design
- **Style**: Classic DOOM status bar aesthetic with pixelated retro design
- **Layout**: Fixed overlay window, always on top, centered on wide screens
- **Dimensions**: ~800px wide × 120px tall (maintaining DOOM proportions)
- **Position**: Horizontally centered, positioned at bottom 20% of screen

### 2. Central Webcam Feed
**Options for webcam display:**

| Option | Resolution | Pros | Cons |
|--------|------------|------|------|
| Small Square | 80×80px | Minimal screen space, fast processing | Limited detail for presence detection |
| Medium Square | 120×120px | Good balance, clear enough for face detection | Moderate processing load |
| Small Rectangle | 160×90px (16:9) | Natural aspect ratio, good detail | Slightly more processing |

**Recommendation**: 120×120px square for optimal balance of visibility and performance.

### 3. Left Panel Metrics
- **Mouse Clicks**: Total click count
- **Keystrokes**: All keyboard input (including modifiers)
- **Context Shifts**: App switches + tab/window changes within apps
- **Display Format**: Retro 7-segment style numbers with labels

### 4. Right Panel Metrics  
- **Git Commits**: Count from local repositories
- **Time Periods**: Session / Day / Week counters for each metric
- **Display Format**: Matching left panel aesthetic

### 5. Screenshot & Timelapse System
- **Frequency**: Every 60 seconds when active
- **Resolution**: Full screen at native display resolution
- **Detection Logic**: 
  - Pause when: No webcam motion AND no input activity for 5+ minutes
  - Resume when: Webcam detects motion OR keyboard/mouse activity
- **Storage**: Screenshots saved to `~/Library/Application Support/DoomHUD/screenshots/YYYY-MM-DD/`
- **Timelapse**: Generated at 12fps, saved as MP4

## Technical Implementation

### Core Technologies
- **Framework**: SwiftUI for modern declarative UI
- **Database**: SQLite for local data persistence
- **Media**: AVFoundation for webcam, Core Graphics for screenshots

### Required System APIs & Permissions

#### 1. Mouse Click Monitoring
```swift
// Using CGEvent tap for global mouse monitoring
let eventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
```
**Permission Required**: Accessibility access in System Preferences

#### 2. Keystroke Monitoring  
```swift
// Global key event monitoring
NSEvent.addGlobalMonitorForEvents(matching: [.keyDown])
```
**Permission Required**: Input Monitoring in Privacy & Security

#### 3. Context Shift Detection
```swift
// App switching
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification)

// Window/tab changes within apps
NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
```
**Permission Required**: Accessibility access

#### 4. Git Commit Monitoring
```swift
// Monitor git directories using FileSystemEventStream
// Parse git log for commit counts
let gitProcess = Process()
gitProcess.launchPath = "/usr/bin/git"
gitProcess.arguments = ["log", "--oneline", "--since=today"]
```
**Permission Required**: Full Disk Access (for accessing git repositories)

#### 5. Webcam Access
```swift
import AVFoundation
AVCaptureDevice.requestAccess(for: .video)
```
**Permission Required**: Camera access

#### 6. Screenshot Capture
```swift
CGWindowListCreateImage(CGRect.infinite, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
```
**Permission Required**: Screen Recording in Privacy & Security

### Database Schema

```sql
CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    mouse_clicks INTEGER DEFAULT 0,
    keystrokes INTEGER DEFAULT 0,
    context_shifts INTEGER DEFAULT 0,
    git_commits INTEGER DEFAULT 0
);

CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    start_time DATETIME,
    end_time DATETIME,
    total_screenshots INTEGER DEFAULT 0
);

CREATE TABLE screenshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    file_path TEXT,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE TABLE user_preferences (
    key TEXT PRIMARY KEY,
    value TEXT
);

-- Hotkey preferences stored as JSON in user_preferences table
-- Example: {"action": "toggle_pause", "modifiers": ["cmd", "shift"], "key": "p"}
```

## User Controls

### Hotkeys (User Configurable)
**Default Assignments:**
- **⌘⇧P**: Toggle pause/resume (hides HUD and stops screenshots)
- **⌘⇧R**: Reset session counters
- **⌘⇧T**: Generate timelapse for current day
- **⌘⇧Q**: Quit application

**Customization:**
- All hotkeys fully user-definable through Preferences
- Support for ⌘, ⌥, ⌃, ⇧ modifier combinations
- Conflict detection with system shortcuts
- Option to disable any hotkey if not needed

### Menu Bar Options
- View today's metrics
- Generate timelapse
- Open screenshots folder
- Preferences (including hotkey configuration)
- Quit

## File Structure
```
~/Library/Application Support/DoomHUD/
├── database.sqlite
├── screenshots/
│   ├── 2025-07-07/
│   │   ├── screenshot_001.png
│   │   └── ...
│   └── timelapses/
│       └── 2025-07-07.mp4
└── logs/
    └── app.log
```

## Privacy & Security
- All data stored locally only
- No network connections required
- User controls all data retention
- Clear data deletion options in preferences

## Success Metrics
- Accurate activity tracking with <1% error rate
- Smooth 60fps webcam feed
- Screenshot capture success rate >95%
- Minimal CPU impact (<5% average usage)
- Memory usage <100MB

## Future Enhancements (V2)
- Multiple git repository monitoring
- Custom metric plugins
- Export data to CSV
- Themes beyond DOOM aesthetic
- Multi-monitor support
- Cloud backup options