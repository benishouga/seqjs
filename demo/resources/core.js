(function() {
  var isLive = function() {
    return window.location.hash === "#live";
  };

  var updateLinkColor = function() {
    $(".nav a").each(function(index, element) {
      if ($(element).attr("href") === (window.location.hash || "#")) {
        $(element).parent().addClass("active");
      } else {
        $(element).parent().removeClass("active");
      }
    });
  };

  var exec = function(code) {
    var result = (function() {
      var LOGS_MAX_LENGTH = 100;
      var logs = [];
      var console = {
        log : function() {
          if (LOGS_MAX_LENGTH < logs.length) {
            logs.push("... This log is tooooooo long...");
            this.log = function() {
            };
            return;
          }

          var args = [];
          for ( var i = 0; i < arguments.length; i++) {
            args.push(arguments[i]);
          }
          logs.push(args.join(" "));
        }
      };

      try {
        eval(code);
      } catch (e) {
        logs.push("failed by " + e);
      }

      return logs.join("\n");
    })();

    return result;
  };

  $(function() {
    if (isLive()) {
      $("#live").show();
      $("#overview").hide();
    } else {
      $("#live").hide();
      $("#overview").show();
    }

    updateLinkColor();

    var socket = io.connect('/');
    socket.on('connect', function() {
      console.log('connect');
    });
    socket.on('disconnect', function() {
      console.log('disconnect');
    });

    var living = false;
    var startLive = function() {
      if (living) {
        return;
      }
      living = true;

      var FORCE_PUSH = 50;

      var inputCode = CodeMirror.fromTextArea(document.getElementById("inputCode"), {
        lineNumbers : true,
        matchBrackets : true
      });

      var prev;
      var count = 0;
      var loop = function() {
        inputCode.save();
        var code = $('#inputCode').val();
        if (prev !== code || FORCE_PUSH < count) {
          socket.emit("postCode", code);
          prev = code;
          count = 0;
        }
        count++;
        setTimeout(loop, 100);
      };
      loop();

      $("#execute").click(function() {
        var MAX_TEXT_LENGTH = 1000;
        var result = exec($('#inputCode').val());

        $("#result").text(result);
        console.log(result);
        if (MAX_TEXT_LENGTH < result.length) {
          result = result.substr(0, MAX_TEXT_LENGTH) + "... The log is tooooooo long...";
        }
        socket.emit("executedCode", result);
      });

      socket.emit("startLive", {});
    };

    var liveTemplate = $("#liveTemplate").template();
    var addLive = function(liveId) {
      $.tmpl(liveTemplate, {
        liveId : liveId
      }).appendTo("#views");
    };

    socket.on('startLive', function(msg) {
      console.log("on startLive", msg);
      addLive(msg.liveId);
    });

    socket.on('listenLive', function(msg) {
      console.log("on listenLive", msg);
      var lives = msg.lives;
      for ( var key in lives) {
        addLive(lives[key]);
      }
    });

    socket.on('closeLive', function(msg) {
      console.log("on startLive", msg);
      $("#" + msg.liveId).hide(function() {
        $("#views").remove("#" + msg.liveId);
      });
    });

    socket.on('postCode', function(msg) {
      console.log("on postCode", msg);
      var code = msg.code;
      code = $("<p></p>").text(code).html().replace(/\r\n/g, "<br />").replace(/\r/g, "<br />").replace(/\n/g, "<br />");
      code = prettyPrintOne(code, 'javascript', true);
      $('#' + msg.liveId + ' .outputCode').html(code);
    });

    socket.on('executedCode', function(msg) {
      console.log("on executedCode", msg);

      $('#' + msg.liveId + ' .outputResult').text(msg.result);
    });

    if (isLive()) {
      startLive();
    }

    $(window).hashchange({
      callback : function() {
        updateLinkColor();
        if (isLive()) {
          $("#live").slideDown(100);
          $("#overview").slideUp(100);
          startLive();
        } else {
          $("#live").slideUp(100);
          $("#overview").slideDown(100);
        }
      }
    });

  });

})();
