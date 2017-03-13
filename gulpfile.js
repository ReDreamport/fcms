(function () {
    "use strict";

    const gulp = require('gulp');
    const gulputil = require('./gulputil');
    const util = new gulputil.Util(gulp);

// ===================================================================
// 服务器
// ===================================================================

    util.watchTask('fcms-server', 'server/**/**.coffee', function () {
        util.compileServerCoffee('server/**/**.coffee', '../node_modules/fcms');
    });

// ===================================================================
// Simple UI
// ===================================================================

    util.watchTask('simple-ui-script', 'simple-ui/**/**.coffee', function () {
        let srcPaths = util.relativePaths("simple-ui/", ["base.coffee", "event.coffee", "**/**.coffee"]);
        util.compileClientCoffee(srcPaths, 'simple-ui.js', "build/ui");
    });

    util.watchTask('simple-ui-css', 'simple-ui/**/**.styl', function () {
        util.compileStylus("simple-ui/**/**.styl", 'simple-ui.css', "build/ui");
    });

    util.watchTask('simple-ui-template', "simple-ui/**/**.jade", function () {
        util.jadeToClient(["simple-ui/**/**.jade"], 'FWT', 'simple-ui-template.js', 'build/ui');
    });

// ===================================================================
// Admin UI
// ===================================================================

    util.watchTask('template', "admin-ui/**/**.jade", function () {
        util.jadeToClient(["admin-ui/**/**.jade", "!admin-ui/index.jade"], 'FT', 'template.js', 'build/ui');
    });

    util.watchTask('html', "admin-ui/index.jade", function () {
        util.jadeToHtml("admin-ui/index.jade", 'build/ui');
    });

    util.watchTask('css', 'admin-ui/**/**.styl', function () {
        util.compileStylus("admin-ui/**/**.styl", 'app.css', "build/ui");
    });

    util.watchTask('setup-js', "admin-ui/setup.js", function () {
        util.copy("admin-ui/setup.js", 'build/ui');
    });

    util.watchTask('script', 'admin-ui/**/**.coffee', function () {
        let srcPaths = util.relativePaths("admin-ui/", ["**/**.coffee", "main.coffee"]);
        util.compileClientCoffee(srcPaths, 'app.js', "build/ui");
    });

    util.watchTask('img', "admin-ui/img/**", function () {
        util.copy("admin-ui/img/**", 'build/ui/img');
    });

    util.watchTask('lib', "admin-ui-lib/**", function () {
        util.copy("admin-ui-lib/**/**", 'build/ui/lib');
    });

    util.startWatchAndDefault();
})();