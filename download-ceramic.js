#!/usr/bin/env node

const childProcess = require('child_process');
const fs = require('fs');
const download = require('download');
const axios = require('axios');

process.chdir(__dirname);

// Determine platform and architecture
const platform = process.platform == 'darwin' ? 'mac' : 'linux';
const arch = process.arch;

// Construct the asset name based on platform and architecture
function getAssetName() {
    if (platform === 'mac') {
        return 'ceramic-mac.zip';
    } else if (platform === 'linux') {
        // Map Node.js arch values to the expected file naming
        const archMap = {
            'x64': 'x86_64',
            'arm64': 'arm64'
        };
        const mappedArch = archMap[arch] || arch;
        return `ceramic-linux-${mappedArch}.zip`;
    }
}

const assetName = getAssetName();

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
                if (asset.name == assetName) {
                    return release;
                }
            }
        }
    }

    fail(`Failed to resolve latest ceramic version! Looking for ${assetName}. Try again later?`);
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

    console.log(`Resolve latest Ceramic release for ${platform} (${arch})`);
    var releaseInfo = await resolveLatestRelease();
    var targetTag = releaseInfo.tag_name;
    var ceramicZipPath = 'ceramic.zip';
    var ceramicArchiveUrl = `https://github.com/ceramic-engine/ceramic/releases/download/${targetTag}/${assetName}`;

    console.log('Download ceramic archive: ' + ceramicArchiveUrl);
    fs.writeFileSync(ceramicZipPath, await download(ceramicArchiveUrl));

    console.log('Unzip...');
    unzipFile(ceramicZipPath, 'ceramic');

})();