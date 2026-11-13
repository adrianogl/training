import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

(:background)
class ReadinessServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() {
        var token = Settings.watchToken();
        if (token == null) {
            Background.exit(ReadinessBridge.UNAUTHORIZED);
            return;
        }
        Communications.makeWebRequest(
            ReadinessBridge.URL,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => { "Authorization" => "Bearer " + token },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse)
        );
    }

    function onResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data instanceof Dictionary) {
            Background.exit({
                ReadinessBridge.DAY => data[ReadinessBridge.DAY],
                ReadinessBridge.SCORE => data[ReadinessBridge.SCORE],
                ReadinessBridge.VERDICT => data[ReadinessBridge.VERDICT]
            });
            return;
        }
        Background.exit(responseCode);
    }
}
