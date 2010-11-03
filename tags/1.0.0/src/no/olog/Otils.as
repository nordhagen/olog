package no.olog 
{
	import flash.geom.Rectangle;
	import flash.net.SharedObject;
	import flash.utils.describeType;
	/**
	 * @author Oyvind Nordhagen
	 * @date 19. feb. 2010
	 */
	internal class Otils 
	{
		private static var _so:SharedObject;

		public function Otils():void
		{
		}

		internal static function parseMsgType(message:Object):String 
		{
			var className:String = getClassName( message );
			var classNameSupported:String = getClassName( message, true );
			var result:String;
			switch (classNameSupported)
			{
				case "String":
					result = (message != "") ? String( message ) : Oplist.EMPTY_MSG_STRING;
					break;

				case "null":
					result = "null";
					break;
				
				case "Number":
				case "int":
					result = String( message );
					break;
				
				case "XML":
				case "XMLList":
					result = parseMsgType( message.toXMLString( ) );
					break;
					
				case "Array":
				case "Vector":
					result = message.join( ", " ) + " (" + message.length + " items)";
					break;
				
				case "Sprite":
					result = classNameSupported + " (type:" + className + ", name:" + message.name + ")";
					break;
				
				case "MovieClip":
					result = classNameSupported + " (type:" + className + ", name:" + message.name + ", frames:" + message.totalFrames + ")";
					break;
				
				case "ErrorEvent":
					result = className + "." + _styleEventType( message.type );
					if (message.target) result += " from " + message.target;
					if (message.target != message.currentTarget) result += " (via " + message.currentTarget + "): ";
					else result += ": ";
					result += message.text;
					break;
					
				case "Event":
					result = className + "." + _styleEventType( message.type );
					if (message.target) result += " from " + message.target;
					if (message.target != message.currentTarget) result += " (via " + message.currentTarget + "): ";
					else result += ": ";
					result += _parseProperties( message );
					break;

				case "Error":
					result = className + _getClosestStackMethod( message ) + ": " + message.message + " (id=" + message.errorID + ")";
					break;
				
				default:
					result = String( message );
			}
			
			return result.replace( /</g, "&lt;" ).replace( /\>/g, "&gt;" );
			;
		}

		private static function _getClosestStackMethod(message:Object):String 
		{
			return message.getStackTrace( ).split( "\n" )[1].replace( "\t", " " );
		}

		private static function _styleEventType(type:String):String 
		{
			return type.replace( /[A-Z]/g, "_$&" ).toUpperCase( );
		}

		private static function _parseProperties(message:Object, includeType:Boolean = false):String 
		{
			var result:String = "";
			var props:XMLList = describeType( message ).accessor;
			var num:int = props.length( );
			for (var i:int = 0; i < num; i++)
			{
				var p:XML = props[i];
				result += p.@name;
				if (includeType) result += ":" + p.@type;
				result += "=" + message[p.@name];
				if (i < num - 1) result += ", "; 
			}
			return result;
		}

		internal static function parseOrigin(origin:Object = null):String 
		{
			var result:String = (origin is String) ? String( origin ) : getClassName( origin );
			return (result != "null") ? result : "";
		}

		internal static function getClassName(o:Object, supported:Boolean = false):String
		{
			if (o == null) return "null";
			
			var result:String;
			var info:XML = describeType( o );
			var className:String = _extractClassOnly( info.@name );
			
			if (!supported || _isSupportedClass( className ))
			{
				result = className;
			}
			else
			{
				var inheritanceTree:XMLList = info.extendsClass;
				var num:int = inheritanceTree.length( );
				for (var i:int = 0; i < num; i++)
				{
					result = extractClassNameFromPackage( inheritanceTree[i].@type );
					if (_isSupportedClass( result )) break;
				}
			}
			return result;
		}

		private static function extractClassNameFromPackage(packageString:String):String 
		{
			if (packageString.indexOf( "::" ) != -1)
			{
				return packageString.split( "::" )[1];
			}
			else
			{
				return packageString;
			}
		}

		private static function _isSupportedClass(name:String):Boolean 
		{
			var result:Boolean = false;
			var num:int = Oplist.SUPPORTED_TYPES.length;
			for (var i:int = 0; i < num; i++)
			{
				if (Oplist.SUPPORTED_TYPES[i] == name)
				{
					result = true;
					break;
				}
			}
			return result;
		}

		private static function _extractClassOnly(className:String):String
		{
			if (className.indexOf( ":" ) != -1) return className.split( "::" )[1];
			else return className;
		}

		internal static function validateLevel(level:int):int 
		{
			return Math.min( Math.max( level, 0 ), Oplist.TEXT_COLOR_LAST_INDEX );
		}

		internal static function getDefaultWindowBounds():Rectangle
		{
			var b:Rectangle = new Rectangle( );
			_so = SharedObject.getLocal( "OlogSettings" );
			if (_so)
			{
				b.x = Math.max( uint( _so.data.x ), Oplist.PADDING );
				b.y = Math.max( uint( _so.data.y ), Oplist.PADDING );
				b.width = uint( _so.data.width );
				b.height = uint( _so.data.height );
			}
			else
			{
				b.x = Math.max( Oplist.x, Oplist.PADDING );
				b.y = Math.max( Oplist.y, Oplist.PADDING );
				b.width = (Oplist.width != -1) ? Oplist.width : Oplist.DEFAULT_WIDTH;
				b.height = (Oplist.height != -1) ? Oplist.height : Oplist.DEFAULT_HEIGHT;
			}
			
			return b;
		}

		internal static function getDaysSinceVersionCheck():int
		{
			_so = SharedObject.getLocal( "OlogSettings" );
			if (_so)
			{
				var now:int = new Date( ).getTime( );
				var then:int = int( _so.data.lastVersionCheck );
				return (then > 0) ? Math.floor( (now - then) / Oplist.DAY_IN_MS ) : Oplist.VERSION_CHECK_INTERVAL_DAYS;
			}
			else
			{
				return Oplist.VERSION_CHECK_INTERVAL_DAYS;
			}
		}

		internal static function getSavedMinimizedState():Boolean
		{
			_so = SharedObject.getLocal( "OlogSettings" );
			return (_so) ? Boolean( _so.data.isMinimized ) : false;
		}

		internal static function getSavedOpenState():Boolean
		{
			_so = SharedObject.getLocal( "OlogSettings" );
			return (_so) ? Boolean( _so.data.isOpen ) : true;
		}

		internal static function recordWindowState():void
		{
			if (!Oplist.rememberWindowState) return;
			if (!_so) _so = SharedObject.getLocal( "OlogSettings" );
			_so.data.x = Math.min( Math.max( 0, Owindow.instance.x ), Owindow.instance.stage.stageWidth );
			_so.data.y = Math.min( Math.max( 0, Owindow.instance.y ), Owindow.instance.stage.stageHeight );
			_so.data.width = Owindow.instance.width;
			_so.data.height = Owindow.instance.height;
			_so.data.isMinimized = Owindow.isMinimized;
			_so.data.isOpen = Owindow.isOpen;
			_savePersistentData( );
		}

		internal static function recordVersionCheckTime():void
		{
			if (!_so) _so = SharedObject.getLocal( "OlogSettings" );
			_so.data.lastVersionCheck = new Date( ).getTime( );
			_savePersistentData( );
		}

		private static function _savePersistentData():void
		{
			var flushStatus:String = null;
			try
			{
				flushStatus = _so.flush( );
			}
            catch (e:Error)
			{
				Olog.trace( e );
			}
		}

		internal static function formatTime(ms:int):String 
		{
			var d:Date = new Date( ms );
			var strms:String = addLeadingZeroes( String( d.getMilliseconds( ) ), 3 );
			var strsec:String = addLeadingZeroes( String( d.getSeconds( ) ), 2 );
			var strmin:String = addLeadingZeroes( String( d.getMinutes( ) ), 2 );
			var strhrs:String = String( d.getHours( ) - 1 );
			return strhrs + ":" + strmin + ":" + strsec + "'" + strms;
		}

		internal static function addLeadingZeroes(numString:String, numZeroes:int = 2):String
		{
			while (numString.length < numZeroes) numString = "0" + numString;
			return numString;
		}

		internal static function parseTypeAndLevel(supportedType:String, level:uint):int 
		{
			switch (supportedType)
			{
				case "Error":
				case "ErrorEvent":
					return 3;
					break;

				case "Event":
					return 5;
					break;
				
				default:
					return validateLevel( level );
			}
		}

		internal static function getDescriptionOf(o:Object):String 
		{
			var separator:String = "\n\t" + Ocore.formatText( "-", 0 );
			var result:String = "\n\n";
			var d:XML = describeType( o );
			var type:String = getClassName( o );
			var propsArr:Array = new Array( );
			if (d.@isDynamic) propsArr.push( "dynamic" );
			if (d.@isStatic) propsArr.push( "static" );
			if (d.@isFinal) propsArr.push( "final" );
			
			result += Ocore.formatText( "\tDescription of " + type, 1 );
			if (propsArr.length > 0) result += " (" + propsArr.join( ", " ) + ")";
			
			var baseList:XMLList = d.extendsClass;
			var heritage:String = "";
			var numClasses:int = baseList.length( );
			for (var curClass:int = 0; curClass < numClasses; curClass++)
			{
				heritage += extractClassNameFromPackage( baseList[curClass].@type );
				if (curClass < numClasses - 1) heritage += "-";
			}
			
			result += Ocore.formatText( "\n\tInheritance tree: " + heritage, 0 );
			
			var varList:XMLList = d.variable;
			var variables:String = "";
			var numVars:int = varList.length( );
			for (var curVar:int = 0; curVar < numVars; curVar++)
			{
				var v:XML = varList[curVar];
				variables += "\n\tvar " + v.@name + Ocore.formatText( ":" + extractClassNameFromPackage( v.@type ), 0 ) + "\t= " + o[v.@name];
			}
			
			if (numVars > 0) result += separator + "\n\t" + Ocore.formatText( variables, 1 );
			
			var constList:XMLList = d.constant;
			var constants:String = "";
			var numConst:int = constList.length( );
			for (var curConst:int = 0; curConst < numConst; curConst++)
			{
				var c:XML = constList[curConst];
				constants += "\n\tconst " + c.@name + Ocore.formatText( ":" + extractClassNameFromPackage( c.@type ), 0 ) + "\t= " + o[c.@name];
			}
			
			if (numConst > 0) result += separator + "\n\t" + Ocore.formatText( constants, 1 );
			result += "\n\t" + Ocore.formatText( "-", 0 );
			result += "\n\t" + Ocore.formatText( (numVars + numConst) + " values found", 1 ) + "\n";
			return result;
		}
	}
}