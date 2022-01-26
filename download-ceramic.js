#!/usr/bin/env node

const childProcess = require('child_process');
const fs = require('fs');
const download = require('download');
const axios = require('axios');

process.chdir(__dirname);

const platform = process.platform == 'darwin' ? 'mac' : 'linux';

function fail(message) {
    console.error(message);
    process.exit(1);
}

async function resolveLatestRelease() {

    var res = await axios.get('https://api.github.com/repos/ceramic-engine/ceramic/releases', { responseType: 'json' });
    var releases = res.data;

    for (var release of releases) {

        if (release.assets != null) {
            var assets = release.assets;
            for (var asset of assets) {
                if (asset.name == 'ceramic-'+platform+'.zip') {
                    return release;
                }
            }
        }
    }

    fail('Failed to resolve latest ceramic version! Try again later?');
    return null;

}

function cleanup() {
    if (fs.existsSync('ceramic.zip'))
        childProcess.execFileSync('rm', ['ceramic.zip']);
    if (fs.existsSync('ceramic'))
        childProcess.execFileSync('rm', ['-rf', 'ceramic']);
}

function unzipFile(source, targetPath) {
    childProcess.execFileSync('unzip', ['-q', source, '-d', targetPath]);
}

cleanup();

(async () => {

    console.log('Resolve latest Ceramic release');
    var releaseInfo = await resolveLatestRelease();
    var targetTag = releaseInfo.tag_name;
    var ceramicZipPath = 'ceramic.zip';
    var ceramicArchiveUrl = 'https://github.com/ceramic-engine/ceramic/releases/download/'+targetTag+'/ceramic-'+platform+'.zip';

    console.log('Download ceramic archive: ' + ceramicArchiveUrl);
    fs.writeFileSync(ceramicZipPath, await download(ceramicArchiveUrl));

    console.log('Unzip...');
    unzipFile(ceramicZipPath, 'ceramic');

})();
