#!/usr/bin/env node

const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

// Keep this info for later
var prevDotHaxelibPath = null;

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
function build(sample, done) {

    console.log('');
    console.log(' --- build sample: ' + sample + ' ---');
    console.log('');

    // Recycle local haxelib directory to prevent having to redownload libs for each sample
    var dotHaxelibPath = path.join(__dirname, sample, '.haxelib');
    if (prevDotHaxelibPath != null) {
        if (!fs.existsSync(dotHaxelibPath)) {
            command('mv', [
                prevDotHaxelibPath,
                dotHaxelibPath
            ]);
        }
    }
    prevDotHaxelibPath = dotHaxelibPath;

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

    var gitignorePath = path.join(__dirname, '_export', sample, '.gitignore');
    if (fs.existsSync(gitignorePath)) {
        fs.unlinkSync(gitignorePath);
    }

    var screenshotPath = path.join(__dirname, sample, 'screenshot.png');
    var exportScreenshotPath = path.join(__dirname, '_export', sample, 'screenshot.png');
    var exportScreenshot400Path = path.join(__dirname, '_export', sample, 'thumbnail.png');
    if (fs.existsSync(screenshotPath)) {
        command('cp', [
            screenshotPath,
            exportScreenshotPath
        ]);
        sharp(screenshotPath)
            .resize({ width: 320 })
            .toFile(exportScreenshot400Path)
            .then(function() {
                done();
            });
    }
    else {
        done();
    }

}

// Reset _export directory
if (fs.existsSync('_export'))
    command('rm', ['-rf', '_export']);
command('mkdir', ['_export']);

function buildNext() {
    if (samplesList.length > 0) {
        build(samplesList.shift(), buildNext);
    }
    else {
        allBuilt();
    }
}

function allBuilt() {
    // Generate index
    //
    var sampleLinks = [];
    for (sample of samplesList) {
        sampleLinks.push('<li><a href="' + sample + '">' + sample + '</a></li>');
    }

    var indexHtml = `
    <!DOCTYPE html>
    <html>
        <head>
            <title>Ceramic Samples</title>
        </head>
        <body>
            <ul>
                ${sampleLinks.join('\n            ')}
            </ul>
        </body>
    </html>
    `.trim();

    fs.writeFileSync(path.join(__dirname, '_export', 'index.html'), indexHtml);
}

// Start building
buildNext();
