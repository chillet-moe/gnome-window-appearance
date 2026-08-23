import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { spawn } from 'node:child_process';

const repoDir = fileURLToPath(new URL('../..', import.meta.url));
const runner = join(repoDir, 'tests/lib/run-isolated-session.sh');

function run(command, args, options = {}) {
    return new Promise((resolve, reject) => {
        const child = spawn(command, args, options);
        let stdout = '';
        let stderr = '';
        child.stdout?.setEncoding('utf8');
        child.stderr?.setEncoding('utf8');
        child.stdout?.on('data', chunk => stdout += chunk);
        child.stderr?.on('data', chunk => stderr += chunk);
        child.on('error', reject);
        child.on('close', (code, signal) => resolve({ code, signal, stdout, stderr }));
    });
}

test('nested D-Bus session uses and cleans an isolated runtime directory', async () => {
    const hostRuntime = await mkdtemp(join(tmpdir(), 'gwa-host-runtime.'));
    const hostDoc = join(hostRuntime, 'doc');
    const sentinel = join(hostDoc, 'host-mount');
    await mkdir(hostDoc);
    await writeFile(sentinel, 'mounted\n');

    try {
        const script = String.raw`
            test "$XDG_RUNTIME_DIR" != "$HOST_XDG_RUNTIME_DIR"
            test "$(stat -c %a "$XDG_RUNTIME_DIR")" = 700
            test -n "$DBUS_SESSION_BUS_ADDRESS"
            printf '%s\n' "$XDG_RUNTIME_DIR"
            mkdir "$XDG_RUNTIME_DIR/doc"
            printf 'private\n' >"$XDG_RUNTIME_DIR/doc/session-mount"
        `;
        const result = await run(runner, [
            'dbus-run-session', '--', 'bash', '-euo', 'pipefail', '-c', script,
        ], {
            env: {
                ...process.env,
                XDG_RUNTIME_DIR: hostRuntime,
                HOST_XDG_RUNTIME_DIR: hostRuntime,
            },
            stdio: ['ignore', 'pipe', 'pipe'],
        });

        assert.equal(result.code, 0, result.stderr);
        const isolatedRuntime = result.stdout.trim();
        assert.match(isolatedRuntime, /^\/tmp\/gwa-runtime\.[A-Za-z0-9]+$/);
        await assert.rejects(stat(isolatedRuntime), { code: 'ENOENT' });
        assert.equal(await readFile(sentinel, 'utf8'), 'mounted\n');
    } finally {
        await rm(hostRuntime, { recursive: true, force: true });
    }
});

test('both nested test entry points use the isolated session runner', async () => {
    for (const entryPoint of ['run-nested.sh', 'run-mutter-nested.sh']) {
        const source = await readFile(join(repoDir, 'tests', entryPoint), 'utf8');
        assert.match(source, /run-isolated-session\.sh" \\\n+\s+dbus-run-session --/);
    }
});

test('signal cleanup removes the runtime directory and stops the session', async () => {
    const child = spawn(runner, [
        'bash', '-c', String.raw`
            printf '%s\n' "$XDG_RUNTIME_DIR"
            trap 'exit 0' TERM
            while :; do sleep 1; done
        `,
    ], { stdio: ['ignore', 'pipe', 'pipe'] });
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');

    let stderr = '';
    child.stderr.on('data', chunk => stderr += chunk);
    const isolatedRuntime = await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error('session did not start')), 5000);
        child.stdout.once('data', chunk => {
            clearTimeout(timeout);
            resolve(chunk.trim());
        });
        child.once('error', reject);
    });

    child.kill('SIGTERM');
    const result = await new Promise((resolve, reject) => {
        child.once('error', reject);
        child.once('close', (code, signal) => resolve({ code, signal }));
    });

    assert.deepEqual(result, { code: 143, signal: null }, stderr);
    await assert.rejects(stat(isolatedRuntime), { code: 'ENOENT' });
});

test('concurrent sessions use distinct runtime directories', async () => {
    const command = [
        'bash', '-c', 'printf \'%s\\n\' "$XDG_RUNTIME_DIR"; sleep 0.05',
    ];
    const [first, second] = await Promise.all([
        run(runner, command, { stdio: ['ignore', 'pipe', 'pipe'] }),
        run(runner, command, { stdio: ['ignore', 'pipe', 'pipe'] }),
    ]);

    assert.equal(first.code, 0, first.stderr);
    assert.equal(second.code, 0, second.stderr);
    const firstRuntime = first.stdout.trim();
    const secondRuntime = second.stdout.trim();
    assert.notEqual(firstRuntime, secondRuntime);
    await assert.rejects(stat(firstRuntime), { code: 'ENOENT' });
    await assert.rejects(stat(secondRuntime), { code: 'ENOENT' });
});
