package no.olog.logtargets {
	import flash.events.StatusEvent;
	import no.olog.Oline;
	import no.olog.Olog;
	import flash.net.LocalConnection;

	/**
	 * Forwards log messages through a LocalConnection at the ID specified by Olog.LOCAL_CONNECTION_ID, to a function called "ologTrace"
	 * @author Oyvind Nordhagen
	 * @date 22. jan. 2011
	 */
	public class LocalConnectionTarget implements ILogTarget {
		private var _conn:LocalConnection;
		private var _errorReported:Boolean;

		public function writeLogLine ( line:Oline ):void {
			try {
				_connection.send( Olog.LOCAL_CONNECTION_ID, "ologTrace", line );
			}
			catch (e:Error) {
				Olog.trace( "LocalConnection.send failed: " + e.message, 2, "Olog" );
			}
		}

		private function get _connection ():LocalConnection {
			if (_conn) return _conn;
			else {
				try {
					_conn = new LocalConnection();
					_conn.addEventListener( StatusEvent.STATUS, _statusHandler );
					Olog.trace( "Broadcasting on " + _conn.domain + ":" + Olog.LOCAL_CONNECTION_ID, 0, "Olog" );
					return _conn;
				}
				catch (error:ArgumentError) {
					Olog.trace( "No active LocalConnection reciever found at " + _conn.domain + ":" + Olog.LOCAL_CONNECTION_ID, 3, "Olog" );
				}
			}
			return null;
		}

		private function _statusHandler ( event:StatusEvent ):void {
			if (event.level == "error" && !_errorReported) {
				Olog.trace( "LocalConnection.send failed", 3, "Olog" );
				_errorReported = true;
			}
		}
	}
}
