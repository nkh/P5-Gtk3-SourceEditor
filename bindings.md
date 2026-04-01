## Vim Bindings Documentation

### Implemented Bindings

#### Normal Mode (Navigation & Actions)

| Binding     | Description                                                      |
| ---------   | ---------------------------------------------------------------- |
| `h`         | Move left one character. Stops at the beginning of the line.     |
| `j`         | Move down one line. Maintains column position if possible.       |
| `k`         | Move up one line. Maintains column position if possible.         |
| `l`         | Move right one character. Stops at the end of the line.          |
| `w`         | Move to the end of the next word.                                |
| `b`         | Move to the beginning of the current/previous word.              |
| `e`         | Move to the end of the current word.                             |
| `0`         | Move to the beginning of the line.                               |
| `$`         | Move to the end of the line.                                     |
| `gg`        | Move to the first line of the buffer.                            |
| `G`         | Move to the last line of the buffer.                             |
| `Page_Up`   | Scroll up one viewport page.                                     |
| `Page_Down` | Scroll down one viewport page.                                   |

#### Insert Mode

| Binding  | Description                                                                            |
| -------  | -----------------------------------------------------------------                      |
| `i`      | Enter insert mode at current cursor position.                                          |
| `a`      | Enter insert mode one character to the right.                                          |
| `A`      | Enter insert mode at the end of the line.                                              |
| `I`      | Enter insert mode at the first non-whitespace character of the line (not implemented). |
| `o`      | Insert a newline below and enter insert mode.                                          |
| `O`      | Insert a newline above and enter insert mode.                                          |
| `Escape` | Exit insert mode, returning to Normal mode.                                            |

#### Edit Mode (Single Characters)

| Binding | Description                                                            |
| ------- | -----------------------------------------------------------------      |
| `x`     | Delete the character under the cursor and place it in the yank buffer. |
| `r`     | Replace a single character under the cursor (not implemented).         |
| `.`     | Repeat the last change (not implemented).                              |

#### Edit Mode (Line Operations)

| Binding | Description                                                              |
| ------- | -----------------------------------------------------------------        |
| `dd`    | Delete the current line entirely and place it in the yank buffer.        |
| `cc`    | Replace the current line with what's under the cursor (not implemented). |
| `cw`    | Change the word under the cursor (not implemented).                      |
| `C`     | Change from cursor to the end of the line (not implemented).             |
| `U`     | Undo a series of changes to the current line (not implemented).          |

#### Yank (Copy/Paste)

| Binding | Description                                                                |
| ------- | -----------------------------------------------------------------          |
| `yy`    | Yank (copy) the entire current line into the yank buffer.                  |
| `yw`    | Yank (copy) the current word (not implemented).                            |
| `p`     | Paste the contents of the yank buffer after the cursor.                    |
| `P`     | Paste the contents of the yank buffer before the cursor (not implemented). |
| `xp`    | Replace the current word with the yank buffer (not implemented).           |

### Command Mode

| Binding         | Description                                                       |
| ----------      | ----------------------------------------------------------------- |
| `:`             | Enter command mode (focuses the bottom entry widget).             |
| `:w`            | Save the file.                                                    |
| `w <filename>`  | Save the file to a new filename.                                  |
| `q`             | Quit if no modifications have been made, otherwise errors out.    |
| `q!`            | Force quit, discarding unsaved changes.                           |
| `:wq`           | Save and quit.                                                    |
| `:wq!`          | Force save and quit.                                              |
| `:w <filename>` | Save the buffer to <filename>.                                    |
| `:e <filename>` | Open a file and replace the current buffer (not implemented).     |
| `r <filename>`  | Insert a file below the current line (not implemented).           |
| `:q`            | Quit (from command mode).                                         |
| `:q!`           | Force quit (from command mode).                                   |

## Not Implemented (Standard Vim Features)

| Feature                                           | Description                    |
| ------------------------------------------------- | ------------------------------ |
| Replace (`c`, `C`, `r`, `R`)                      | Find and replace functionality |
| Search (`/`, `?`, `n`, `N`)                       | Regex searching                |
| Marks (`m`, `a`, `d`, `y`, backtick)              | Text bookmarks                 |
| Visual mode (`v`, `V`)                            | Visual selection               |
| Macros (`q:qa`, `q:`)                             | Recording keystrokes           |
| Undo (`.`)                                        | Repeat last change             |
| Join (`J`)                                        | Join split lines               |
| Indentation (`>>` / `<<`)                         | Adjust indentation             |
| Line numbers (`:{number}`)                        | Jump to line                   |
| Split windows (`:split`, `:vs`)                   | Window management              |
| Session (`mksession`, `source` / `source <file>`) | Session management             |


