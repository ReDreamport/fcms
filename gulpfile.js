(function () {
    "use strict";

    const gulp = require('gulp');
    const gulputil = require('./gulputil');
    const util = new gulputil.Util(gulp);

// ===================================================================
// 服务器
// ===================================================================

    util.watchTask('server', 'server/**/**.coffee', function () {
        util.compileServerCoffee('server/**/**.coffee', '../build/server');
    });

    util.watchTask('configs', 'server/config.js', function () {
        util.copy('server/config.js', '../build/server');
    });

    util.watchTask('server-jade', 'server/jade/**/**', function () {
        util.copy('server/jade/**/**', '../build/server/jade');
    });

// ===================================================================
// root app
// ===================================================================

    util.watchTask('root-server', 'apps/root/**/**.coffee', function () {
        util.compileServerCoffee('apps/root/**/**.coffee', '../build/server/apps/root');
    });

    util.watchTask('root-config', 'apps/root/server/config.js', function () {
        util.copy('apps/root/config.js', '../build/server/apps/root');
    });

    util.startWatchAndDefault();
})();