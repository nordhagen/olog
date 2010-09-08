package no.olog 
{
	import flash.display.InteractiveObject;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TextEvent;
	import flash.net.FileReference;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.text.StyleSheet;
	import flash.ui.Keyboard;
	import flash.utils.getTimer;
	/**
	 * @author Oyvind Nordhagen
	 * @date 19. feb. 2010
	 */
	internal class Ocore 
	{
		internal static var alwaysOnTop:Boolean = true;
		internal static var scrollOnNewline:Boolean = true;
		private static var _stage:Stage;
		private static var _lineNumber:int = -1;
		private static var _versionLoader:URLLoader;
		private static var _versions:XML;
		private static var _password:String;
		private static var _passwordOk:Boolean = true;
		private static var _enableCMI:Boolean = true;
		private static var _pwPrompt:OpwPrompt;
		private static var _stageFocusRestore:InteractiveObject;
		private static var _pwPromptOpen:Boolean;
		private static var _lines:Array = new Array( );
		private static var _linesFiltered:Array = new Array( );
		private static var _linesAreFiltered:Boolean = false;
		private static var _levelFilter:int = -1;
		private static var _lastLine:Oline = new Oline( "", 0, null, "", "", 0, "", "" );
		private static var _runTimeMarkers:Array = new Array( );
		private static var _numLinesPendingWrite:int;

		public function Ocore():void
		{
		}

		internal static function formatText(text:String, level:int):String 
		{
			return "<font color=\"" + Oplist.TEXT_COLORS_HEX[level] + "\">" + text + "</font>";
		}

		internal static function getLogCSS():StyleSheet
		{
			var p:Object = {fontFamily:Oplist.FONT, fontSize:Oplist.SIZE, leading:Oplist.LEADING};
			var a:Object = {textDecoration:"underline", color:Oplist.TEXT_COLORS_HEX[1]};
			var css:StyleSheet = new StyleSheet( );
			css.setStyle( "p", p );
			css.setStyle( "a", a );
			return css;
		}

		internal static function getTitleBarCSS():StyleSheet
		{
			var p:Object = {fontFamily:Oplist.TB_FONT, fontSize:Oplist.TB_FONT_SIZE, textAlign:Oplist.TB_ALIGN};
			var css:StyleSheet = new StyleSheet( );
			css.setStyle( "p", p );
			return css; 
		}

		internal static function getTitleBarText():String 
		{
			var nameVersion:String = formatText( Oplist.NAME + " " + Oplist.VERSION, 1 );
			var initTime:String = formatText( " - " + _getCurrentTime( ), 0 );
			return "<p><b>" + nameVersion + "</b>" + initTime + "</p>";
		}

		internal static function onAddedToStage(e:Event):void 
		{
			Owindow.exists = true;
			_stage = e.target.stage;
			_evalKeyboard( );
			_evalCMI( );
			_initPWPrompt( );
			evalAlwaysOnTop( );
			enableScrolling( );
			Owindow.setDefaultBounds( );
			if (_lines.length > 0) refreshLog( );
		}

		private static function _evalKeyboard():void 
		{
			if (Oplist.keyBoardEnabled) _stage.addEventListener( KeyboardEvent.KEY_DOWN, _onKeyDown );
			else _stage.removeEventListener( KeyboardEvent.KEY_DOWN, _onKeyDown );
		}

		internal static function evalAlwaysOnTop():void 
		{
			if (_stage)
			{
				if (Oplist.alwaysOnTop)
					_stage.addEventListener( Event.ADDED, Owindow.moveToTop );
				else
					_stage.removeEventListener( Event.ADDED, Owindow.moveToTop );
			}
		}
		
		internal static function trace(message:Object, level:uint = 1, origin:Object = null, useLineStart:Boolean = true, bypassValidation:Boolean = false):void 
		{
			var c:String = Otils.getClassName( message );
			
			if (c == Oplist.AI_LOGGER_EVENT || c == Oplist.OLOG_EVENT)
			{
				_handleLogEvent( message, c );
			}
			else
			{
				var m:String;
				var s:String;
				var l:int;
				var isTruncated:Boolean;
				if (!bypassValidation)
				{
					m = Otils.parseMsgType( message );
					s = Otils.getClassName( message, true );
					l = Otils.parseTypeAndLevel( s, level );
					isTruncated = _evalTruncation( m );
				}
				else
				{
					m = String( message );
					s = "String";
					l = level;
				}
				
				var o:String = Otils.parseOrigin( origin );
				var i:int = _getLineIndex( );
				var t:String = _getCurrentTime( );
				var r:String = _getRunTime( );
				var line:Oline = new Oline( m, l, o, t, r, i, c, s, useLineStart, bypassValidation );
				line.isTruncated = isTruncated;
				line.truncationEnabled = line.isTruncated;
				_lines[i] = line;
				_evalAddOrRepeat( line );
			}
		}

		private static function _evalAddOrRepeat(line:Oline):void 
		{
			if (line.msg != _lastLine.msg || line.level != _lastLine.level || !Oplist.stackRepeatedMessages) _addLine( line );
			else _incrementLastLineRepeat( );
			if (Oplist.enableRegularTraceOutput) Otils.regularTrace( line );
		}

		private static function _incrementLastLineRepeat():void 
		{
			_lastLine.repeatCount++;
			if (Owindow.exists) Owindow.replaceLastLine( _getLogTextFromVO( _lastLine ) );
		}

		private static function _handleLogEvent(e:Object, type:String):void 
		{
			var level:int = (type == Oplist.OLOG_EVENT) ? e.level : e.severity;
			
			switch (e.type)
			{
				case OlogEvent.TRACE:
				case "log":
					trace( e.message, level, e.target );
					break;
				
				case OlogEvent.DESCRIBE:
				case "describe":
					describe( e.message, level, e.target );
					break;
				
				case OlogEvent.HEADER:
				case "header":
					writeHeader( e.message, level );
					break;
				
				case OlogEvent.NEWLINE:
				case "cr":
					writeNewline( int( e.message ) );
					break;
				
				default:
					trace( new Error( "Invalid event type for " + type + ":" + e.type ), 3, "Olog" );
					return;
			}
		}

		internal static function traceRuntimeInfo():void
		{
			var header:String = "RUNTIME INFORMATION\n";
			var type:String = (Capabilities.isDebugger) ? "Debugger" : "Standard";
			var msg:String = "Platform:\t" + Capabilities.os + "\n";
			msg += "Language:\t" + Capabilities.language.toUpperCase() + "\n";
			msg += "HW Manufactorer:\t" + Capabilities.manufacturer + "\n";
			msg += "Player:\t" + Capabilities.version + " (" + Capabilities.playerType + ", " + type + ")\n";
			msg += "Screen:\t" + Capabilities.screenResolutionX + "x" + Capabilities.screenResolutionY + " @ " + Capabilities.screenDPI + " dpi\n";
			if (Owindow.exists) msg += "Stage:\t" + _stage.stageWidth + "x" + _stage.stageHeight + "\n" ;
			msg += "Accessibility aids:\t" + Capabilities.hasAccessibility + "\n";
			msg += "AV Hardware Disabled:\t" + Capabilities.avHardwareDisable + "\n";
			msg += "Audio:\t" + Capabilities.hasAudio + "\n";
			msg += "Audio Encoder:\t" + Capabilities.hasAudioEncoder + "\n";
			msg += "MP3 Decoder:\t" + Capabilities.hasMP3 + "\n";
			msg += "Video Encoder:\t" + Capabilities.hasVideoEncoder + "\n";
			msg += "Embedded Video:\t" + Capabilities.hasEmbeddedVideo + "\n";
			msg += "Screen Broadcast:\t" + Capabilities.hasScreenBroadcast + "\n";
			msg += "Screen Playback:\t" + Capabilities.hasScreenPlayback + "\n";
			msg += "Streaming Audio:\t" + Capabilities.hasStreamingAudio + "\n";
			msg += "Streaming Video:\t" + Capabilities.hasStreamingVideo + "\n";
			msg += "Native SSL Sockets:\t" + Capabilities.hasTLS + "\n";
			msg += "Input Method editor:\t" + Capabilities.hasIME + "\n";
			msg += "Local File Read Access:\t" + Capabilities.localFileReadDisable + "\n";
			msg += "Printing:\t" + Capabilities.hasPrinting + "\n";
			
			trace( header + msg, 0, null, false );
		}

		internal static function describe(message:Object, level:int, origin:Object):void 
		{
			var m:String = Otils.getDescriptionOf( message );
			trace( m, level, origin, true, true );
		}

		internal static function writeHeader(message:String, level:uint = 1):void
		{
			var m:String = "\n\t" + message.toUpperCase( ) + "\n";
			trace( m, level, null, false, true );
		}

		internal static function writeNewline(numLines:int = 1):void
		{
			var m:String = "";
			for (var i:int = 0; i < numLines; i++) m += "<br>";
			trace( m, 0, null, false, true );
		}

		private static function _addLine(line:Oline):void 
		{
			_lastLine = line;
			_filter( line );
			if (Owindow.isOpen)
				_writeLine( line );
			else
				_numLinesPendingWrite++;
		}

		private static function _filter(line:Oline):void 
		{
			if (!_linesAreFiltered || line.level == _levelFilter)
			{
				_linesFiltered.push( line );
			}
		}

		internal static function setPassword(val:String):void
		{
			if (!val || val == "")
			{
				_password = null;
				_passwordOk = true;
			}
			else if (val != _password)
			{
				_password = val;
				_passwordOk = false;
			}
		}

		internal static function getPassword():String
		{
			return _password;
		}

		internal static function setCMI(val:Boolean):void 
		{
			_enableCMI = val;
			_evalCMI( );
		}

		internal static function get hasCMI():Boolean
		{
			return _enableCMI;
		}

		internal static function evalOpenClose(e:Event = null):void
		{
			if (!Owindow.isOpen && _passwordOk) _openWindow( );
			else if (Owindow.isOpen) Owindow.close( );
			else if (!_pwPromptOpen && !_passwordOk) _openPWPrompt( );
		}

		private static function _openWindow():void 
		{
			Owindow.open( );
			_writePendingLines( );
		}

		private static function _writePendingLines():void 
		{
			var num:int = _lines.length;
			for (var i:int = _lines.length - _numLinesPendingWrite; i < num; i++)
			{
				var line:Oline = _lines[i];
				if (!_linesAreFiltered || line.level == _levelFilter)
				_writeLine( line );
			}
		}

		internal static function validatePassword(e:Event):void 
		{
			if (e.target.text == _password)
			{
				_passwordOk = true;
				_closePWPrompt( );
				Owindow.open( );
				_writePendingLines( );
			}
		}

		internal static function disableScrolling():void
		{
			if (Owindow.exists) _stage.removeEventListener( KeyboardEvent.KEY_DOWN, _scroll );
		}

		internal static function enableScrolling():void
		{
			if (Owindow.exists) _stage.addEventListener( KeyboardEvent.KEY_DOWN, _scroll );
		}

		private static function _scroll(e:KeyboardEvent):void
		{
			if (e.keyCode == Keyboard.DOWN) Owindow.scrollDown( );
			else if (e.keyCode == Keyboard.UP) Owindow.scrollUp( );
			else if (e.keyCode == Keyboard.HOME) Owindow.scrollHome( );
			else if (e.keyCode == Keyboard.END) Owindow.scrollEnd( );
			Owindow.instance.addEventListener( MouseEvent.MOUSE_OVER, Owindow.onMouseOver );
		}

		internal static function refreshLog():void 
		{
			Owindow.clear( );
			var num:int = _linesFiltered.length;
			for (var i:int = 0; i < num; i++)
			{
				_writeLine( _linesFiltered[i] );
			}
		}

		private static function _initPWPrompt():void 
		{
			_pwPrompt = new OpwPrompt( );
		}

		private static function _closePWPrompt():void 
		{
			_stage.removeChild( _pwPrompt );
			_stage.focus = _stageFocusRestore;
			_pwPromptOpen = false;
		}

		private static function _openPWPrompt():void 
		{
			_stageFocusRestore = _stage.focus;
			_pwPrompt.x = (_stage.stageWidth - Ocore._pwPrompt.width) * 0.5;
			_pwPrompt.y = (_stage.stageHeight - Ocore._pwPrompt.height) * 0.5;
			_stage.addChild( _pwPrompt );
			_stage.focus = _pwPrompt.field;
			_pwPromptOpen = true;
		}

		private static function _evalCMI():void 
		{
			if (Owindow.exists)
			{
				if (_enableCMI) Owindow.createCMI( );
				else Owindow.removeCMI( );
			}
		}

		internal static function checkForUpdates():void 
		{
			_versionLoader = new URLLoader( );
			_versionLoader.addEventListener( Event.COMPLETE, _onVersionHistoryResult );
			_versionLoader.addEventListener( IOErrorEvent.IO_ERROR, _onVersionHistoryResult );
			_versionLoader.addEventListener( SecurityErrorEvent.SECURITY_ERROR, _onVersionHistoryResult );
			try 
			{
				_versionLoader.load( new URLRequest( Oplist.VERSION_CHECK_URL ) );
			}
			catch (e:Error)
			{
				trace("Check for updates not allowed by sandbox", 3, "Olog");
			}
		}

		private static function _onVersionHistoryResult(e:Event):void 
		{
			if (e.type == Event.COMPLETE)
			{
				_versions = new XML( e.target.data );
				var newestVersion:String = _versions.version[0].@id;
				if (newestVersion != Oplist.VERSION)
				{
					var str:String = Oplist.NEW_VERSION_MSG.replace( "@version", newestVersion );
					trace( "<p><a href=\"event:" + Oplist.EVENT_VERSION_DETAILS + "\">" + str + "</a></p>", 4, null, true, true );
					Otils.recordVersionCheckTime( );
				}
				else
				{
					trace( "You are using the current version of Olog", 4 );
				}
			}
		}

		internal static function onTextLink(e:TextEvent):void
		{
			var linkParts:Array = e.text.split( "@" );
			var event:String = linkParts[0];
			switch (event)
			{
				case Oplist.EVENT_OPEN_TRUNCATED:
				case Oplist.EVENT_CLOSE_TRUNCATED:
					_toggleTruncation( int( linkParts[1] ) );
					break;
				
				case Oplist.EVENT_VERSION_DETAILS:
					_traceVersionDetails( );
					break;
				
				default:
					throw new Error( "switch case unsupported" );
			}
		}

		private static function _toggleTruncation(i:int):void 
		{
			var line:Oline = _lines[i] as Oline;
			line.truncationEnabled = !line.truncationEnabled;
			refreshLog( );
		}

		private static function _traceVersionDetails():void
		{
			var str:String = "<br><p>Version " + _versions.version[0].@id + " contains the following changes:</p>";
			
			if (_versions.version[0].hasOwnProperty( "features" ))
			{
				str += "<br><p><b>" + Oplist.FEATURES + "</b></p>";
				for each (var feature:XML in _versions.version[0].features.feature)
				{
					str += "<li>" + feature + "</li>";
				}
			}
			if (_versions.version[0].hasOwnProperty( "fixes" ))
			{
				str += "<br><p><b>" + Oplist.FIXES + "</b></p>";
				for each (var fix:XML in _versions.version[0].fixes.fix)
				{
					str += "<li>" + fix + "</li>";
				}
			}
			if (_versions.version[0].hasOwnProperty( "notes" ))
			{
				str += "<br><p><b>" + Oplist.NOTES + "</b></p>";
				str += "<p>" + _versions.version[0].notes.text( ) + "</p>";
			}
			
			
			str += "<br><p><a href=\"" + Oplist.DL_LINK + "\">" + Oplist.DL_LABEL + "</a></p><br>";
			
			trace( formatText( str, 1 ), 1, null, false, true );
		}

		private static function _onKeyDown(e:KeyboardEvent):void 
		{
			var levelKey:int = _charCodeAsLevel( e.charCode, e.keyCode );
			if (e.shiftKey && e.keyCode == Keyboard.ENTER)
			{
				evalOpenClose( );
			}
			else if (_pwPromptOpen && e.keyCode == Keyboard.ESCAPE)
			{
				_closePWPrompt( );
			}
			else if (Owindow.isOpen && levelKey > -1)
			{
				_levelFilter = levelKey;
				_filterLines( );
				refreshLog( );
			}
			else if (Owindow.isOpen && _linesAreFiltered && e.keyCode == Keyboard.ESCAPE)
			{
				_levelFilter = -1;
				_filterLines( );
				refreshLog( );
			}
		}

		private static function _charCodeAsLevel(charCode:int, keyCode:int):int
		{
			// keyCode 48-53 equals numbers 0 through 5
			var numberKey:int = parseInt( String.fromCharCode( charCode ) );
			if (!isNaN( numberKey ) && 48 <= keyCode && keyCode <= 53) return numberKey;
			else return -1;
		}

		private static function _filterLines():void 
		{
			_linesFiltered = new Array( );
			if (_levelFilter == -1)
			{
				_linesFiltered = _lines;
				_linesAreFiltered = false;
			}
			else
			{
				_linesAreFiltered = true;
				var num:int = _lines.length;
				for (var i:int = 0; i < num; i++)
				{
					if (_lines[i].level == _levelFilter)
					{
						_linesFiltered.push( _lines[i] );
					}
				}
			}
		}

		private static function _writeLine(oline:Oline):void
		{
			if (Owindow.exists)
			{
				Owindow.write( _getLogTextFromVO( oline ) );
			}
		}

		private static function _getLogTextFromVO(oline:Oline):String
		{
			var rawText:String;
			if (!oline.isTruncated)
				rawText = oline.msg;
			else
				rawText = (oline.truncationEnabled) ? _getTruncated( oline.msg, oline.index ) : _getUntruncated(oline.msg, oline.index);
				
			var lStart:String = (oline.useLineStart) ? formatText( Otils.getLineStart( oline.index, oline.timestamp, oline.runtime ), 0) : "";
			var repeatCount:String = (oline.repeatCount == 1) ? "" : formatText(" (" + oline.repeatCount + ")", 1);
			//var msg:String = (!oline.bypassValidation) ? formatText( rawText, oline.level ) : oline.msg;
			var msg:String = formatText( rawText, oline.level );
			var origin:String = _getOrigin( oline.origin );
			return lStart + msg + repeatCount + origin;
		}

		private static function _evalTruncation(msg:String):Boolean 
		{
			var truncateChars:Boolean = Oplist.maxUntruncatedLength > 0 && msg.length > Oplist.maxUntruncatedLength;
			var truncateLines:Boolean = Oplist.truncateMultiline && msg.indexOf( "\n" ) != -1;
			return truncateChars || truncateLines;
		}

		private static function _getTruncated(msg:String, index:int):String 
		{
			if (Oplist.truncateMultiline) msg = msg.substr(0, msg.indexOf("\n"));
			if (Oplist.maxUntruncatedLength > -1) msg = msg.substr( 0, Oplist.maxUntruncatedLength - 3 );
			return msg + "... " + "<a href=\"event:" + Oplist.EVENT_OPEN_TRUNCATED + "@" + index + "\">" + Oplist.OPEN_TRUNCATED_LABEL + "</a>";
		}

		private static function _getUntruncated(msg:String, index:int):String 
		{
			return msg + " <a href=\"event:" + Oplist.EVENT_OPEN_TRUNCATED + "@" + index + "\">" + Oplist.CLOSE_TRUNCATED_LABEL + "</a>";
		}

		private static function _getOrigin(origin:String):String 
		{
			return (origin) ? formatText( Oplist.ORIGIN_DELIMITER + origin, 0 ) : "";
		}

		private static function _getCurrentTime():String 
		{
			return new Date( ).toTimeString( ).substr( 0, 8 );
		}

		private static function _getRunTime():String 
		{
			return Otils.formatTime( getTimer( ) );
		}

		private static function _getLineIndex():int
		{
			return ++_lineNumber;
		}

		internal static function newTimeMarker(name:String = null, origin:Object = null):int
		{
			var n:String = (name) ? name : "Operation";
			var o:String = Otils.parseOrigin( origin );
			var t:int = getTimer( );
			return _runTimeMarkers.push( [n, t, o] ) - 1;
		}

		internal static function completeTimeMarker(id:int):void
		{
			var marker:Array = _runTimeMarkers[id];
			if (marker)
			{
				var markerDuration:int = getTimer( ) - marker[1];
				var durationString:String = Otils.formatTime( markerDuration );
				trace( marker[0] + " completed in " + durationString, Oplist.MARKER_COLOR_INDEX, marker[2], true, true );
			}
			else
			{
				trace( "Invalid time marker ID \"" + id + "\"", 3, "Olog" );
			}
		}

		internal static function saveLogAsXML(e:MouseEvent = null):void 
		{
			var d:Date = new Date( );
			var ds:String = d.getDate( ) + "" + d.getMonth( ) + "" + d.getFullYear( );
			var ts:String = d.toTimeString( ).substr( 0, 8 ).replace( /:/g, "" );
			
			var xml:XML = <olog_output></olog_output>;
			xml.@date = ds;
			xml.@time = ts;
			
			var num:int = _lines.length;
			for (var i:int = 0; i < num; i++)
			{
				var line:Oline = _lines[i];
				var node:XML = <line>{line.msg}</line>;
				node.@timeStamp = line.timestamp;
				node.@runTime = line.runtime;
				node.@level = line.level;
				node.@originatingClass = line.origin;
				node.@dataType = line.type;
				node.@treatedAs = line.supportedType;
				node.@repeatCount = line.repeatCount;
				xml.appendChild( node );
			}

			_save( xml );
		}

		internal static function saveLogAsText(e:MouseEvent = null):void 
		{
			_save( Owindow.getLogText( ) );
		}

		private static function _save(contents:*):void
		{
			var d:Date = new Date( );
			var ds:String = d.getDate( ) + "" + d.getMonth( ) + "" + d.getFullYear( );
			var ts:String = d.toTimeString( ).substr( 0, 8 ).replace( /:/g, "" );
			var suff:String = (contents is XML) ? ".xml" : ".txt";
			var fr:FileReference = new FileReference( );
			try
			{
				fr["save"]( contents, Oplist.XML_OUTPUT_FILENAME + "_" + ds + "_" + ts + suff );
			}
			catch (e:Error)
			{
				trace( "Save operation requires FlashPlayer 10", 3, "Olog" );
			}
		}

		internal static function setKeyboardEnabled(val:Boolean):void 
		{
			Oplist.keyBoardEnabled = val;
			_evalKeyboard( );
		}

		internal static function getLastLineLevel():int 
		{
			return _lastLine.level;
		}
	}
}