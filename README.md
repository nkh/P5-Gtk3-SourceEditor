# Gtk3 SourceView Editor Modules

A modular, reusable set of Perl modules for embedding a fully functional, Vim-bound, theme-aware text editor into any Gtk3 application.

## Architecture

*   **`SourceEditor.pm`**: The main widget factory. Generates the `Gtk3::Box` containing the scrolling text area and the bottom status/command bar. Handles fonts, wrapping, and file loading.
*   **`ThemeManager.pm`**: Handles parsing XML theme files, dynamically injecting missing properties (like the caret/cursor color), and generating the necessary CSS to force the bottom UI widgets to match the theme (bypassing default GTK system themes).
*   **`VimBindings.pm`**: A standalone key-press interceptor that attaches Vim-like modal states (Normal, Insert, Command) to a `Gtk3::SourceView::View`.

## Usage Example

```perl
use Gtk3 -init;
use SourceEditor;

my $window = Gtk3::Window->new('toplevel');
$window->signal_connect(delete_event => sub { Gtk3->main_quit(); });

my $editor = SourceEditor->new(
    file       => 'my_script.pl',
    theme_file => 'themes/theme_dark.xml',
    font_size  => 14,
    wrap       => 0,          # Disable word wrap (horizontal scroll)
    read_only  => 1,          # Open in read-only mode
    window     => $window,    # Required if using on_close callback
    on_close   => sub {
        my $text = shift;
        print "User closed window. Final text was: $text";
    }
);

$window->add($editor->get_widget());
$window->show_all();
Gtk3->main();
```

## API Reference

### `SourceEditor->new(%opts)`

Constructs and returns a new SourceEditor object.

**Parameters:**
*   `file` (string): Path to the file to load. If it doesn't exist, creates an empty buffer.
*   `theme_file` (string): Path to the `GtkSourceView` XML theme file.
*   `font_size` (int): Font size in points. Defaults to system default.
*   `wrap` (boolean): `1` for word-wrap, `0` for horizontal scrolling. Defaults to `1`.
*   `read_only` (boolean): Disables insert mode and file saving. Defaults to `0`.
*   `window` (Gtk3::Window): Reference to the parent window. Required if you want to use the `on_close` callback.
*   `on_close` (coderef): Triggered when the provided `window` emits the `destroy` signal. Passes the final buffer text as the first argument.

### `SourceEditor->get_widget()`

Returns the main `Gtk3::Widget` (a `Gtk3::Box`) to be packed into your application window.

### `SourceEditor->get_text()`

Returns the raw string contents of the text buffer at the moment it is called.

### `SourceEditor->get_buffer()`

Returns the underlying `Gtk3::SourceView::Buffer` object for advanced manipulation.

## Theming

The editor uses standard `GtkSourceView` XML themes. To set the cursor color correctly, ensure your XML has a cursor style node:

```xml
<style-scheme id="my_theme" version="1.0">
  <style name="text" foreground="#D3D7CF" background="#1E1E1E"/>
  <style name="cursor" foreground="#FFFFFF"/> <!-- Required for visible dark mode cursor -->
  <style name="selection" foreground="#FFFFFF" background="#4A90D9"/>
  <!-- ... syntax styles ... -->
</style-scheme>
```

*Note: If you omit `<style name="cursor">`, `ThemeManager` will automatically inject one using the text foreground color.*

## CLI Arguments (main.pl)

The included `main.pl` demonstrates how to map command-line arguments to the module:
*   `--theme <name>`: Loads `themes/theme_<name>.xml`
*   `--font-size <int>`: Sets monospace font size
*   `--wrap` / `--no-wrap`: Toggles line wrapping
*   `--read-only`: Blocks modifications
