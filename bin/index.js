#!/usr/bin/env node

const path = require('path');
const fs = require('fs');
const fsExtra = require('fs-extra');
const yargs = require('yargs');
const simpleGit = require('simple-git')();
const compareSemver = require('compare-semver');

var sys = require('sys')
var exec = require('child_process').exec;


const yargv = yargs
    .example('ent init', 'Initializes an ent app')
    .example('ent build', 'Builds an ent app')
    .alias('v', 'verbose')
    .default('v', false)
    .describe('v', 'Print all messages out')
    .help('h')
    .alias('h', 'help')
    .argv;

const init (template) => {

}

const main = () => {
	const command = yargv._[0] === undefined ? "init" : yargv._[0];
    console.log(command);
    const child = exec("dir", function (error, stdout, stderr) {
    sys.print('stdout: ' + stdout);
      sys.print('stderr: ' + stderr);
      if (error !== null) {
        console.log('exec error: ' + error);
      }
    });

};

main();