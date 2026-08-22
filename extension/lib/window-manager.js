import GLib from 'gi://GLib';
import Meta from 'gi://Meta';

import {scheduleTestCapture} from './test-capture.js';
import {WindowAppearanceEffect} from './window-effect.js';

const SUPPORTED_WINDOW_TYPES = new Set([
    Meta.WindowType.NORMAL,
    Meta.WindowType.DIALOG,
    Meta.WindowType.MODAL_DIALOG,
]);

export class WindowAppearanceManager {
    #settings;
    #effects = new Map();
    #connections = [];
    #enabled = false;

    constructor(settings) {
        this.#settings = settings;
    }

    enable() {
        this.#enabled = true;
        this.#connect(global.display, 'window-created', (_display, window) => {
            this.#addWindowWhenReady(window);
        });
        this.#connect(global.display, 'restacked', () => {
            for (const effect of this.#effects.values())
                effect.restackShadow();
        });
        this.#connect(this.#settings, 'changed', () => {
            for (const effect of this.#effects.values())
                effect.update();
        });
        this.#connect(global.windowManager, 'destroy', (_wm, actor) => {
            this.#removeActor(actor);
        });

        for (const actor of global.get_window_actors())
            this.#addActor(actor);
    }

    disable() {
        this.#enabled = false;
        for (const effect of this.#effects.values())
            effect.disable();
        this.#effects.clear();

        for (const [object, id] of this.#connections.splice(0))
            object.disconnect(id);
    }

    #connect(object, signal, callback) {
        this.#connections.push([object, object.connect(signal, callback)]);
    }

    #addWindowWhenReady(window, remainingAttempts = 30) {
        if (!this.#enabled)
            return;

        const actor = window.get_compositor_private();
        if (actor?.get_texture() && window.get_wm_class() !== null) {
            this.#addActor(actor);
            return;
        }

        if (remainingAttempts <= 0) {
            console.warn(
                `[gnome-window-appearance] no texture for ${window.get_wm_class()}`,
            );
            return;
        }

        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
            this.#addWindowWhenReady(window, remainingAttempts - 1);
            return GLib.SOURCE_REMOVE;
        });
    }

    #addActor(actor) {
        if (this.#effects.has(actor))
            return;

        const window = actor.get_meta_window();
        if (!window ||
            window.get_wm_class() === null ||
            window.get_client_type() !== Meta.WindowClientType.WAYLAND ||
            !SUPPORTED_WINDOW_TYPES.has(window.get_window_type())) {
            return;
        }

        const effect = new WindowAppearanceEffect(actor, this.#settings);
        if (effect.enable()) {
            this.#effects.set(actor, effect);
            console.log(
                `[gnome-window-appearance] applied ${window.get_wm_class()}`,
            );
            scheduleTestCapture(window);
        }
    }

    #removeActor(actor) {
        const effect = this.#effects.get(actor);
        if (!effect)
            return;

        effect.disable();
        this.#effects.delete(actor);
    }
}
