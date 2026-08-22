import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {layoutManager} from 'resource:///org/gnome/shell/ui/main.js';

import {WindowAppearanceManager} from './lib/window-manager.js';

export default class WindowAppearanceExtension extends Extension {
    #manager = null;
    #startupSignalId = 0;

    enable() {
        const start = () => {
            this.#manager = new WindowAppearanceManager(this.getSettings());
            this.#manager.enable();
            console.log('[gnome-window-appearance] enabled');
        };

        if (layoutManager._startingUp) {
            this.#startupSignalId = layoutManager.connect(
                'startup-complete',
                () => {
                    layoutManager.disconnect(this.#startupSignalId);
                    this.#startupSignalId = 0;
                    start();
                },
            );
        } else {
            start();
        }
    }

    disable() {
        if (this.#startupSignalId !== 0) {
            layoutManager.disconnect(this.#startupSignalId);
            this.#startupSignalId = 0;
        }

        this.#manager?.disable();
        this.#manager = null;
        console.log('[gnome-window-appearance] disabled');
    }
}
