#!/usr/bin/env node

const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');

// Retrieve samples lists
const samplesList = [];
for (item of fs.readFileSync(path.join(__dirname, 'samples.txt'), 'utf8').split('\n')) {
    item = item.trim();
    if (item.length > 0) {
        samplesList.push(item);
    }
}

/**
 * Run a command
 */
function command(cmd, args, options) {

    if (options == null) {
        options = {};
    }

    options.stdio = 'inherit';

    childProcess.execFileSync(cmd, args, options);

}

/**
 * Build the given sample
 */
function build(sample) {

    console.log('');
    console.log(' --- build sample: ' + sample + ' ---');
    console.log('');

    command(
        'ceramic',
        ['clay', 'build', 'web', '--setup', '--assets', '-D', 'ceramic_web_minify', '-D', 'ceramic_no_skip'],
        {
            cwd: path.join(__dirname, sample)
        }
    );

    command('mv', [
        path.join(__dirname, sample, 'project', 'web'),
        path.join(__dirname, '_export', sample)
    ]);

}

// Reset _export directory
if (fs.existsSync('_export'))
    command('rm', ['-rf', '_export']);
command('mkdir', ['_export']);

// Start building
for (sample of samplesList) {
    build(sample);
}
