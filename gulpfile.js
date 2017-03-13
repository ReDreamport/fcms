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


    util.startWatchAndDefault();
})();