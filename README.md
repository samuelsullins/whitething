# WhiteThing

A minimal RTF text editor for macOS with customizable appearance and hover-activated controls.

## Features

- **File Management**: Create, open, and save RTF documents
- **Customizable Appearance**: 
  - Text and background colors (hex input)
  - Font selection from common typefaces or system font picker
  - Adjustable font size (8-72pt)
  - Variable horizontal padding (0-500px)
- **Smart Interface**: Menu bar appears on hover, hides during typing
- **Auto-save**: Documents save automatically when you type space
- **Persistent Settings**: All appearance preferences saved between sessions - but font and color are UI-only, not saved to the RTF.
- **Text Formatting**: Support for bold (⌘B) and italic (⌘I) - what else do you need?

## Requirements

- macOS 12.0+
- Xcode 14.0+

## How to Run

1. Clone the repository
2. Open `WhiteThing.xcodeproj` in Xcode
3. Select target device (Mac)
4. Press ⌘R or click Run to test
5. Archive and Distribute via Custom -> Copy App and then stick it in your Applications folder

## Usage

1. **First Launch**: Click "New" or "Open" to begin
2. **File Management**: Click name of folder to change save location, click filename to rename
3. **Appearance**: Adjust colors, fonts, and padding using the hover menu
4. **Window Size**: Click "Big" to maximize window (automatically adjusts padding)

## File Format

Documents are saved as RTF (Rich Text Format) files with formatting stripped on save to maintain consistency with viewer preferences.
