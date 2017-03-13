(function () {
    "use strict";
    const _ = require('lodash');
    const coffee = require('gulp-coffee');
    const plumber = require('gulp-plumber');
    const beep = require('beepbeep');

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

    Util.prototype.errorHandler = function (err) {
        console.error(err.toString());
        beep(2);
    };

    Util.prototype.compileServerCoffee = function (srcPaths, descPath) {
        this.gulp.src(srcPaths)
            .pipe(plumber({errorHandler: this.errorHandler}))
            .pipe(coffee())
            .pipe(this.gulp.dest(descPath));
    };

    Util.prototype.copy = function (src, dest) {
        this.gulp.src(src).pipe(this.gulp.dest(dest))
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