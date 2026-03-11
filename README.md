# Propel

Kanban-style task management for macOS. Move fast, stay focused.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)

## Overview

Propel is a native macOS Kanban board app built with SwiftUI. It's designed for personal task management with a focus on content creation workflows (blog posts, conference talks, videos, podcasts).

## Features

### Board Management

- **4-column Kanban board** — Backlog, In Progress, Blocked, Completed
- **Drag-and-drop** cards between columns
- **Collapsible columns** to focus on what matters
- **Per-column sort configuration** — sort by priority, due date, or creation date
- **Status-driven color signals** — visual column indicators (blue for active, red for blocked, green for done)

### Cards

- **Labels** — Blog Post, Conference Talk, Video, Podcast (color-coded)
- **Priority levels** — Urgent, Normal, Low with visual badges
- **Due dates** with overdue tracking
- **Checklists** with progress bars
- **Rich descriptions** with clickable link detection and YouTube/Vimeo video embeds
- **Recurring tasks** — daily, weekly, monthly, or custom intervals
- **Context menu** actions — duplicate, change priority/label, block/unblock

### Smart Features

- **Search** (Cmd+F) — search across card titles and descriptions
- **Filter bar** — filter by label and/or priority
- **Attention view** — highlights overdue, due-soon, and blocked cards
- **Weekly review** — summary of completed, created, in-progress, and overdue cards
- **Auto-archive** — completed cards older than 7 days are automatically hidden
- **Completion celebration** — particle animation when tasks are completed
- **macOS notifications** — alerts for overdue and upcoming due dates

### Productivity

- **Quick capture** (Ctrl+Shift+N) — global hotkey to create a new card
- **Menu bar presence** — quick stats and badge count for overdue/blocked items
- **Notes tab** — scratchpad with full-text search
- **Keyboard shortcuts** — Cmd+N (new card), Cmd+F (search), Escape (close panel)

### Data

- **Local-first** — all data stored in `~/Library/Application Support/Propel/`
- **Auto-save** with 1-second debounce
- **Atomic writes with backup** — safe file operations prevent data loss
- **JSON format** — human-readable, easy to backup

## Architecture

```text
Sources/Propel/
├── PropelApp.swift              # App entry point, scenes, menu bar, About window
├── Models/
│   ├── Board.swift              # Board & Column models, card sorting logic
│   ├── Card.swift               # Card & ChecklistItem models, recurring instance creation
│   ├── Enums.swift              # Label, Priority, SortField, Frequency, ColumnStatus enums
│   ├── Note.swift               # Note & NotesStore models
│   └── RecurrenceRule.swift     # Recurrence date calculation
├── ViewModels/
│   ├── BoardViewModel.swift     # Board state, CRUD, filters, search, attention, notifications
│   └── NotesViewModel.swift     # Notes state, CRUD, search
├── Views/
│   ├── ContentView.swift        # Main layout, tab switching, search bar, toolbar
│   ├── AboutView.swift          # About window with version, copyright, links
│   ├── Board/
│   │   ├── BoardView.swift      # Horizontal column layout
│   │   ├── ColumnView.swift     # Column with header, collapse, drag-drop, celebration
│   │   ├── CardView.swift       # Card face with label/priority badges, checklist progress
│   │   ├── CardContextMenu.swift # Right-click menu for cards
│   │   ├── FilterBar.swift      # Label & priority filters, weekly review button
│   │   ├── ColumnSortConfig.swift # Per-column sort field picker
│   │   ├── CompletionCelebration.swift # Particle animation overlay
│   │   ├── AttentionView.swift  # Overdue/blocked/due-soon card highlights
│   │   ├── WeeklyReviewView.swift # Weekly stats and card review sheet
│   │   └── MenuBarView.swift    # Menu bar extra with stats and quick actions
│   ├── CardDetail/
│   │   ├── CardDetailPanel.swift # Side panel for editing cards
│   │   ├── CardCreationPanel.swift # Side panel for creating cards
│   │   ├── ChecklistEditor.swift # Checklist add/remove/toggle UI
│   │   └── RichDescriptionView.swift # Link detection and video embed previews
│   └── Notes/
│       ├── NotesView.swift      # Split view: note list + editor
│       ├── NoteListItem.swift   # Note row in sidebar
│       └── NoteEditorView.swift # Title + content text editor
├── Services/
│   └── StorageService.swift     # JSON persistence with atomic writes and backup
└── Utilities/
    ├── DebouncedSave.swift      # Task-based debounce for auto-save
    └── AppInfo.swift            # Version, copyright, and build metadata
```

### Design Decisions

- **Swift 6 strict concurrency** — `@Observable`, `@MainActor`, `Sendable` throughout
- **SPM-only** — no Xcode project file, builds with `swift build`
- **No external dependencies** — pure SwiftUI + Foundation
- **Dark mode only** — `.preferredColorScheme(.dark)` for a focused aesthetic
- **Observable pattern** — `@Observable` view models injected via `@Environment`
- **Debounced auto-save** — `Task` cancellation pattern prevents excessive disk writes
- **Atomic file writes** — write to temp, backup existing, rename for crash safety

## Requirements

- macOS 15.0+
- Xcode 16+ (for building)

## Build & Run

```bash
# Build
make build

# Build and run
make run

# Run tests
make test

# Create .app bundle (release)
make app-bundle

# Create .dmg installer
make dmg

# Install to /Applications
make install

# Generate app icon
make generate-icon
```

## Testing

110 tests across 21 test suites covering:

- Models (Board, Card, Column, Note, Enums, RecurrenceRule, Codable roundtrips)
- ViewModels (BoardViewModel CRUD/movement/recurring, NotesViewModel CRUD/search)
- Features (Filters, Column Sort, Search, Collapsible Columns, Auto-Archive, Attention View, Weekly Review, Menu Bar Badge, Status Colors)

```bash
swift test
```

## License

MIT License - Copyright (c) 2026 Ran Isenberg

See [LICENSE](LICENSE) for details.

## Author

**Ran Isenberg** — [ranthebuilder.cloud](https://ranthebuilder.cloud)
