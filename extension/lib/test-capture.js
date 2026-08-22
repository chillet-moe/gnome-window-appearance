import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';

let captureScheduled = false;

export function scheduleTestCapture(window) {
    const artifactDir = GLib.getenv('TEST_ARTIFACT_DIR');
    if (!artifactDir || captureScheduled ||
        window.get_wm_class() !== 'window-probe') {
        return;
    }

    captureScheduled = true;
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 750, () => {
        const path = GLib.build_filenamev([artifactDir, 'fractional-2.5.png']);
        const file = Gio.File.new_for_path(path);
        let stream;
        try {
            stream = file.replace(
                null,
                false,
                Gio.FileCreateFlags.REPLACE_DESTINATION,
                null,
            );
        } catch (error) {
            console.error(`[gnome-window-appearance] test capture open failed: ${error}`);
            return GLib.SOURCE_REMOVE;
        }

        const screenshot = new Shell.Screenshot();
        screenshot.screenshot(false, stream, (_source, result) => {
            try {
                const [success] = screenshot.screenshot_finish(result);
                stream.close(null);
                if (!success)
                    throw new Error('Shell.Screenshot returned false');
                console.log(`[gnome-window-appearance] test capture ${path}`);
            } catch (error) {
                console.error(`[gnome-window-appearance] test capture failed: ${error}`);
            }
        });
        return GLib.SOURCE_REMOVE;
    });
}
