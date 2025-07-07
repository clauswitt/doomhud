# Ultra-Granular DOOM HUD Implementation Plan

## Phase 1: Project Foundation (8 tasks)
1. **Create Xcode Project** - New macOS SwiftUI project with bundle ID
2. **Add SQLite Dependency** - Package.swift with SQLite.swift
3. **Create Core Data Models** - MetricData, Session, Screenshot, UserPreferences structs
4. **Setup DatabaseManager** - SQLite connection, table creation, basic CRUD
5. **Configure Info.plist** - Camera, accessibility, screen recording permissions
6. **Create HUDWindow Class** - Custom NSWindow, always-on-top, 800x120px
7. **Setup App Structure** - Main App class, ContentView, WindowGroup
8. **Test Basic Setup** - Launch app, verify window positioning

## Phase 2: Input Monitoring (12 tasks)
9. **Create MouseTracker** - CGEvent tap setup, click counting
10. **Add Accessibility Permission Check** - Request and verify access
11. **Test Mouse Click Detection** - Verify left/right clicks counted
12. **Create KeystrokeTracker** - NSEvent global monitor setup
13. **Add Input Monitoring Permission** - Request and verify access
14. **Test Keystroke Detection** - Verify all keys counted including modifiers
15. **Create ContextTracker** - NSWorkspace app switching detection
16. **Add Window Change Detection** - Accessibility API for window/tab changes
17. **Combine Context Shift Logic** - App switches + window changes
18. **Test Context Switching** - Verify accurate context shift counting
19. **Create ActivityDetector** - Combine mouse/keyboard activity
20. **Test Activity Detection** - Verify 5-minute pause logic

## Phase 3: Git & Webcam Integration (10 tasks)
21. **Create GitTracker Class** - Basic git command execution
22. **Add Git Directory Selection** - UserDefaults storage for selected paths
23. **Implement Git Log Parsing** - Parse commit counts by time period
24. **Test Git Commit Detection** - Verify counts for session/day/week
25. **Create WebcamManager** - AVCaptureSession setup
26. **Add Camera Permission Check** - Request and verify camera access
27. **Implement 120x120 Video Display** - AVCaptureVideoPreviewLayer
28. **Add Motion Detection** - Basic pixel difference algorithm
29. **Test Webcam Functionality** - Verify video feed and motion detection
30. **Integrate Motion with Activity** - Combine for pause/resume logic

## Phase 4: UI Components (15 tasks)
31. **Create DOOM Color Palette** - Define retro colors as constants
32. **Design 7-Segment Font Style** - Custom text styling for metrics
33. **Create MetricDisplayView** - Reusable component for number display
34. **Build Left Panel Layout** - Mouse clicks, keystrokes, context shifts
35. **Build Right Panel Layout** - Git commits, time period counters
36. **Create WebcamView Component** - Center webcam display
37. **Implement HUD Layout** - Combine all components in 800x120 frame
38. **Add Real-time Updates** - Bind UI to metric observables
39. **Test Left Panel Updates** - Verify mouse/keyboard/context metrics
40. **Test Right Panel Updates** - Verify git commit displays
41. **Test Webcam Display** - Verify video feed in HUD
42. **Style Polish** - Final retro aesthetic adjustments
43. **Test Window Positioning** - Verify bottom 20%, centered
44. **Test Always-on-Top** - Verify HUD stays above other windows
45. **Test UI Responsiveness** - Verify smooth 60fps updates

## Phase 5: Screenshot System (8 tasks)
46. **Create ScreenshotManager** - CGWindowListCreateImage implementation
47. **Add Screen Recording Permission** - Request and verify access
48. **Implement 60-Second Timer** - Scheduled screenshot capture
49. **Create File Organization** - Date-based folder structure
50. **Test Screenshot Capture** - Verify full-screen captures
51. **Add Activity-Based Pausing** - Pause when inactive 5+ minutes
52. **Test Pause/Resume Logic** - Verify activity detection triggers
53. **Create Screenshot Metadata** - Database logging of captures

## Phase 6: Timelapse Generation (6 tasks)
54. **Create TimelapseGenerator** - AVAssetWriter for MP4 creation
55. **Implement 12fps Assembly** - Convert screenshots to video
56. **Add Progress Tracking** - User feedback during generation
57. **Test Timelapse Creation** - Verify MP4 output quality
58. **Add Automatic Daily Generation** - End-of-day timelapse creation
59. **Test File Management** - Verify timelapse storage organization

## Phase 7: User Controls (10 tasks)
60. **Create HotkeyManager** - Global hotkey registration system
61. **Implement Default Hotkeys** - ⌘⇧P, ⌘⇧R, ⌘⇧T, ⌘⇧Q
62. **Test Hotkey Functionality** - Verify all hotkey actions
63. **Create MenuBarManager** - NSStatusBar integration
64. **Add Menu Items** - View metrics, generate timelapse, preferences, quit
65. **Test Menu Bar Integration** - Verify menu actions work
66. **Create PreferencesView** - SwiftUI settings window
67. **Add Git Directory Selector** - File picker for git repos
68. **Implement Hotkey Configuration** - User-customizable hotkeys
69. **Test Preferences System** - Verify settings persist

## Phase 8: Data & Polish (8 tasks)
70. **Implement Database Operations** - Save metrics, sessions, screenshots
71. **Create Data Aggregation** - Session/day/week calculations
72. **Add Real-time Database Updates** - Continuous metric persistence
73. **Test Database Performance** - Verify <5% CPU usage
74. **Add Error Handling** - Permission failures, file system errors
75. **Implement Memory Management** - Target <100MB usage
76. **Performance Optimization** - Profile and optimize bottlenecks
77. **Final Integration Testing** - Complete end-to-end testing

**Total: 77 specific, actionable tasks**

Each task should take 15-60 minutes to complete, allowing for systematic progress tracking and testing at each step.

## Key Technologies
- **Framework**: SwiftUI for modern declarative UI
- **Database**: SQLite for local data persistence
- **Media**: AVFoundation for webcam, Core Graphics for screenshots
- **System APIs**: CGEvent, NSEvent, NSWorkspace for monitoring
- **Permissions**: Accessibility, Input Monitoring, Camera, Screen Recording

## Success Metrics
- Accurate activity tracking with <1% error rate
- Smooth 60fps webcam feed
- Screenshot capture success rate >95%
- Minimal CPU impact (<5% average usage)
- Memory usage <100MB

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