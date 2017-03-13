(function () {
    "use strict";
    const _ = require('lodash');
    const coffee = require('gulp-coffee');
    const concat = require('gulp-concat');
    const jade = require('gulp-jade');
    const stylus = require('gulp-stylus');
    const declare = require('gulp-declare');
    const plumber = require('gulp-plumber');
    const beep = require('beepbeep');
    const flatten = require('gulp-flatten');
    const autoprefixer = require('gulp-autoprefixer');
    const cleanCss = require('gulp-clean-css');

    const notify = require('gulp-notify');

    const AUTOPREFIXER_BROWSERS = [
        'ie >= 8',
        'ie_mob >= 10',
        'ff >= 30',
        'chrome >= 34',
        'safari >= 7',
        'opera >= 23',
        'ios >= 7',
        'android >= 4.4',
        'bb >= 10'
    ];

    const Util = function (gulp) {
        this.gulp = gulp;
        this.watches = [];
        this.defaultTasks = [];
    };

    exports.Util = Util;

    Util.prototype.relativePaths = function (parentPath, paths) {
        return _.map(paths, function (p) {
            return parentPath + p
        });
    };

    // handle errors
    function errorAlert(error) {
        notify.onError({
            title: "Error in plugin '" + error.plugin + "'",
            message: 'Check your terminal',
            sound: 'Sosumi'
        })(error);
        console.log(error.toString());
        //this.emit('end');
    }

    Util.prototype.errorHandler = function (err) {
        beep(2);
        errorAlert(err)
    };

    Util.prototype.compileServerCoffee = function (srcPaths, descPath) {
        this.gulp.src(srcPaths)
            .pipe(plumber({errorHandler: this.errorHandler}))
            .pipe(coffee())
            .pipe(this.gulp.dest(descPath));
    };

    Util.prototype.compileStylus = function (srcPaths, concatFile, descPath) {
        "use strict";
        let p = this.gulp.src(srcPaths)
            .pipe(plumber({errorHandler: this.errorHandler}))
            .pipe(stylus())
            .pipe(autoprefixer(AUTOPREFIXER_BROWSERS))
            .pipe(cleanCss({compatibility: 'ie8'}));
        if (concatFile) {
            p = p.pipe(concat(concatFile));
        } else {
            p = p.pipe(flatten())
        }
        p.pipe(this.gulp.dest(descPath));
    };

    Util.prototype.compileClientCoffee = function (srcPaths, concatFile, destPath) {
        "use strict";
        let p = this.gulp.src(srcPaths)
            .pipe(plumber({errorHandler: this.errorHandler}))
            .pipe(coffee());
        if (concatFile) {
            p = p.pipe(concat(concatFile));
        } else {
            p = p.pipe(flatten())
        }
        p.pipe(this.gulp.dest(destPath));
    };

    Util.prototype.copy = function (src, dest) {
        this.gulp.src(src).pipe(this.gulp.dest(dest))
    };

    Util.prototype.jadeToClient = function (src, namespace, concatFile, dest) {
        this.gulp.src(src)
            .pipe(plumber({errorHandler: this.errorHandler}))
            .pipe(jade({client: true}))
            .pipe(declare({namespace: namespace, noRedeclare: true}))
            .pipe(concat(concatFile))
            .pipe(this.gulp.dest(dest));
    };

    Util.prototype.jadeToHtml = function (src, dest) {
        this.gulp.src(src)
            .pipe(plumber({errorHandler: this.errorHandler}))
            .pipe(jade())
            .pipe(this.gulp.dest(dest));
    };

    Util.prototype.watchTask = function (task, watchPaths, fn) {
        this.defaultTasks.push(task);
        this.watches.push({task: task, paths: watchPaths});
        this.gulp.task(task, fn);
    };

    Util.prototype.startWatchAndDefault = function () {
        console.log("enter startWatchAndDefault");
        let that = this;
        this.gulp.task('watch', ['default'], function () {
            _.each(that.watches, function (w) {
                if (_.isArray(w.paths)) {
                    _.each(w.paths, function (path) {
                        console.log("watch " + path + " to " + w.task);
                        that.gulp.watch(path, [w.task]);
                    });
                } else {
                    console.log("watch " + w.paths + " to " + w.task);
                    that.gulp.watch(w.paths, [w.task]);
                }
            });
        });

        this.gulp.task('default', this.defaultTasks);
    };
})();