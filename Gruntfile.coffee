# Generated on 2014-12-29 using generator-bower 0.0.1
'use strict'

mountFolder = (connect, dir) ->
    connect.static require('path').resolve(dir)

module.exports = (grunt) ->
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

  yeomanConfig =
    src: 'src'
    dist : 'dist'
  grunt.initConfig
    yeoman: yeomanConfig


    coffee:
      dist:
        files: [
          expand: true
          cwd: '<%= yeoman.src %>'
          src: '{,*/}*.coffee'
          dest: '<%= yeoman.dist %>'
          ext: '.js'
        ]
    uglify:
      build:
        src: '<%=yeoman.dist %>/gridedit.js'
        dest: '<%=yeoman.dist %>/gridedit.min.js'
    mochaTest:
      test:
        options:
          reporter: 'spec'
          compilers: 'coffee:coffee-script'
        src: ['test/**/*.coffee']
    connect:
      options:
        port: 9000
        hostname: 'localhost'
        livereload: 35729
      livereload:
        options:
          open:
            target: 'http://localhost:9000/'
          base: ['demo']
          keepalive: true
          # middleware: (connect) ->
          #   connect.static 'demo/index.html'


    grunt.registerTask 'serve', 'Compile then start a connect web server', (target) ->
      grunt.task.run [
        'coffee'
        'uglify'
        'connect:livereload'
      ]

    grunt.registerTask 'default', [
      'mochaTest'
      'coffee'
      'uglify'
    ]
