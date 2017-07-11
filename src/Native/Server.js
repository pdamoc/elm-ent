var _pdamoc$elm_ent$Native_Server = function(){
    const http = require('http'); 
    const ecstatic = require('ecstatic');
    const fs = require('fs');

    function listen (port, settings) {
        return _elm_lang$core$Native_Scheduler.nativeBinding(function (callback) {

          const server = http.createServer();
          const serveFiles = ecstatic({ root: __dirname + '/public' });
          server.on('listening', function () {
            callback(_elm_lang$core$Native_Scheduler.succeed(server));

          });

          server.on('request', function (req, res) {
            const localName = __dirname +  '/public' + req.url
            if (fs.existsSync(localName) && fs.lstatSync(localName).isFile()){
              serveFiles(req, res);
              return;
            }              
            var ctx = {
                ctor: "Request",
                _0: { 
                    request: req,
                    response: res
                }
            };
            _elm_lang$core$Native_Scheduler.rawSpawn(settings.onRequest(ctx));
          });

          server.on('close', function () {
            _elm_lang$core$Native_Scheduler.rawSpawn(settings.onClose());
          });

          server.listen(port);

          return;
        });
    }

    function respond (ctx, res) {
        return _elm_lang$core$Native_Scheduler.nativeBinding(function (callback) {
            ctx._0.response.end(res.body);
            callback(_elm_lang$core$Native_Scheduler.succeed({ ctor: '_Tuple0' }));
        });
    }

    function close (server) {
        return _elm_lang$core$Native_Scheduler.nativeBinding(function (callback) {
            server.close();
            callback(_elm_lang$core$Native_Scheduler.succeed({ ctor: '_Tuple0' }));
        });
    }

    return {
        listen: F2(listen),
        respond: F2(respond),
        close: close
    };
}();

