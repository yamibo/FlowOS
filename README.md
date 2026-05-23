# FlowOS

FlowOS is a native macOS focus app that combines a Pomodoro timer, hierarchical tasks, session history, and iCloud Drive based data storage.

This repository currently represents the **FlowOS 1.x** line: a clean TodoList + Pomodoro app without gamified progression. Gamification and growth systems are planned for the future 2.x line.

## Features

- Pomodoro timer with focus, short break, and long break sessions
- Hierarchical todo list with subtasks, priorities, pinning, completion progress, and notes
- Session completion flow for recording completed tasks
- History view with date filtering, session statistics, and completed task summaries
- Menu bar timer controls
- Runtime Chinese / English language switching
- User-selected iCloud Drive compatible data directory
- macOS sandbox compatible directory authorization

## Requirements

- macOS
- Xcode
- SwiftUI

## Build

```bash
cd FlowOSAppleApp
/usr/bin/xcodebuild -project FlowOSAppleApp.xcodeproj -scheme FlowOSAppleApp -configuration Debug build
```

## Data Storage

FlowOS stores user data as local JSON / JSONL files in a user-authorized directory. Choosing an iCloud Drive folder enables Apple-provided file sync between devices.

Main data files:

- `todos.json`
- `settings.json`
- `sessions.jsonl`

## Versioning

- `v0.1`: original public macOS prototype
- `v1.0`: polished FlowOS 1.x TodoList + Pomodoro release
- `2.x`: planned gamified growth system

## License

FlowOS is free software licensed under the GNU General Public License v3.0 or later.

See [LICENSE](LICENSE) for details.

