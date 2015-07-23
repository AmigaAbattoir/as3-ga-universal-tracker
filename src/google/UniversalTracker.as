package com.google.analytics {
	import flash.crypto.generateRandomBytes;
	import flash.display.Loader;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.UncaughtErrorEvent;
	import flash.net.SharedObject;
	import flash.net.SharedObjectFlushStatus;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.utils.ByteArray;

	/**
	 * Based on Zwetan Kjukov's as3-universal-analytics SimplestTracker documentation 
	 * (https://code.google.com/p/as3-universal-analytics/wiki/SimplestTracker)
	 *
	 * @author Christopher Pollati
	 *
	 * @todo Ensure some items are trimmed to Maximum Lengths as defined in 
	 * https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
	 * @todo Transaction/Item Hits for (Enhanced) E-Commerce tracking
	 * @todo For encoded string, multiple whitespace characters should be reduced to 1 space.
	 * @todo Check if passed clientID is a valid UUID V4 string
	 * @todo Remove trace statements and workout a better response from event handlers
	 */
	public class UniversalTracker {
		private var _sharedObject:SharedObject;
		private var _loader:Loader;

		public var trackingID:String;
		public var clientID:String;
		// Optional
		public var userId:String;

		// Application Tracking
		private var _applicationName:String;
		private var _applicationId:String;
		private var _applicationVersion:String;
		private var _applicationInstallerId:String;

		// Options
		public var useSSL:Boolean = false;
		public var useCacheBuster:Boolean = false;
		public var anonymizeIP:Boolean = false;

		// Overrides
		public var ipOverride:String;
		public var userAgenOverride:String;
		public var geographicOverride:String; // @see http://developers.google.com/analytics/devguides/collection/protocol/v1/geoid

		/**
		 * Creates a class to handle Google Analytics Universal Tracking.
		 *
		 * @param trackingID
		 * @param clientID
		 */
		public function UniversalTracker( trackingID:String, clientID:String = "" ) {
			trace( "SimplestTracker starts" );
			this.trackingID = trackingID;
			trace( "trackingID = " + trackingID );

			// If you have generated a Client ID, then you can pass it instead of using a generated one
			if(clientID && (clientID.length>0)) {
				trace( "passed a Client ID (it better be valid UUID (version 4)!" );
				this.clientID  = clientID;
				trace( "clientID = " + clientID );
			} else {
				trace( "obtain the Client ID" );
				this.clientID  = _getClientID();
				trace( "clientID = " + clientID );
			}
		}

		/**
		 * In order to register hits if the Analytics Measurement mode is set to Application, you
		 * must specify at least the name of the application.
		 *
		 * @param name Reuired for all hit types. Specifies the application name. This field is
		 * required for all hit types sent to app properties. (ie: My App). Max length: 100 bytes
		 * URI encoded
		 * @param id Optional application identifier (ie: com.company.app). Max length: 150 bytes
		 * URI encoded
		 * @param version Optional application version (ie: 1.2). Max length: 100 bytes URI encoded
		 * @param installerId Optional application installer indentifier (ie: com.platform.vending).
		 * Max length: 150 bytes URI encoded
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		public function setToApplicationMode(name:String, id:String = "", version:String = "", installerId:String = ""):void {
			_applicationName = name;
			_applicationId = id;
			_applicationVersion = version;
			_applicationInstallerId = installerId;

			if(name.length>0) {
				trace( "Application Tracking Mode on");
			} else {
				trace( "Application name cannot be blank, Application Tracking Mode is Off" );
			}
		}

		// ---- Send Hits ----
		/**
		 * Sends an Analytics Measurement pageview hit using a full URL
		 *
		 * @param page Required. The full URL (document location) of the page on which content
		 * resides. (ie: http://foo.com/home?a=b). Max length: 2048 bytes URI encoded
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		public function sendPageviewByUrl( docLocationURL:String, isNonInteractionHit:Boolean = false, additionalPayload:Array = null ):void {
			trace( "sendPageview()" );

			var payload:Array = _generateDefaultPayload();
			payload.push( "t=pageview" );
			/** @todo Should make sure it starts with a 'http' */
			payload.push( "dl=" + encodeURIComponent( docLocationURL ) );

			_sendGoogleAnalyticsRequest(payload, isNonInteractionHit, additionalPayload);
		}

		/**
		 * Sends an Analytics Measurement pageview hit using the host name and document path
		 *
		 * @param host Specifies the hostname from which content was hosted. Max length: 100 bytes
		 * URI encoded
		 * @param path The path portion of the page URL. Should begin with '/'. (ie: /foo). Max
		 * length: 2048 bytes URI encoded
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		public function sendPageviewByHostAndPage( host:String, path:String, isNonInteractionHit:Boolean = false, additionalPayload:Array = null ):void {
			trace( "sendPageview()" );

			var payload:Array = _generateDefaultPayload();
			payload.push( "t=pageview" );
			payload.push( "dh=" + encodeURIComponent( host ) );
			/** @todo Should make sure it starts with a '/' */
			payload.push( "dp=" + encodeURIComponent( path ) );

			_sendGoogleAnalyticsRequest(payload, isNonInteractionHit, additionalPayload);
		}

		/**
		 * Send an Analytics Measurement event hit
		 *
		 * @param category Required. Specifies the event category. Must not be empty. Max length:
		 * 150 bytes URI encoded
		 * @param action Required. Specifies the event action. Must not be empty. Max length: 500
		 * bytes URI encoded
		 * @param label Specifies the event label. Max length: 500 bytes URI encode
		 * @param value Specifies the event value. Values must be non-negative, otherwise it is not sent.
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		public function sendEvent( category:String, action:String, label:String = "", value:int = -1, isNonInteractionHit:Boolean = false, additionalPayload:Array = null ):void {
			trace( "sendEvent()" );

			var payload:Array = _generateDefaultPayload();
			payload.push( "t=event" );
			payload.push( "ec=" + encodeURIComponent( category ) );
			payload.push( "ea=" + encodeURIComponent( action ) );

			if( label && (label.length > 0) ) {
				payload.push( "el=" + encodeURIComponent( label ) );
			}

			if( value > -1) {
				payload.push( "ev=" + value);
			}

			_sendGoogleAnalyticsRequest(payload, isNonInteractionHit, additionalPayload);
		}

		/**
		 * Send an Analytics Measurement social interaction hit
		 *
		 * @param network Required. Specifies the social network, for example Facebook or Google
		 * Plus. Max length: 50 bytes URI encoded
		 * @param action Required. Specifies the social interaction action. For example on Google
		 * Plus when a user clicks the +1 button, the social action is 'plus'. Max length: 50
		 * bytes URI encoded
		 * @param actionTarget Required. Specifies the target of a social interaction. This value
		 * is typically a URL but can be any text. (ie: http://foo.com). Max length: 2048 bytes
		 * URI encoded
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		public function sendSocial( network:String, action:String, actionTarget:String, isNonInteractionHit:Boolean = false, additionalPayload:Array = null ):void {
			trace( "sendSocial()" );

			var payload:Array = _generateDefaultPayload();
			payload.push( "t=social" );
			payload.push( "sn=" + encodeURIComponent( network ) );
			payload.push( "sa=" + encodeURIComponent( action ) );
			payload.push( "st=" + encodeURIComponent( actionTarget ) );

			_sendGoogleAnalyticsRequest(payload, isNonInteractionHit, additionalPayload);
		}

		/**
		 * Send an Analytics Measurement screenview hit
		 *
		 * @param screenName Required. This parameter is optional on web properties, and required
		 * on mobile properties for screenview hits, where it is used for the 'Screen Name' of the
		 * screenview hit. (ie: High Scores).Max length: 2048 bytes URI encoded
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		public function sendScreenview( screenName:String, isNonInteractionHit:Boolean = false, additionalPayload:Array = null ):void {
			trace( "sendScreenview()" );

			var payload:Array = _generateDefaultPayload();
			payload.push( "t=screenview" );
			payload.push( "cd=" + encodeURIComponent( screenName ) );

			_sendGoogleAnalyticsRequest(payload, isNonInteractionHit, additionalPayload);
		}

		/**
		 * Send an Analytics Measurement exception hit
		 *
		 * @param description Specifies the description of an exception. Max length: 150 bytes URI encoded
		 * @param isFatal Specifies whether the exception was fatal.
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		public function sendException( description:String = "", isFatal:Boolean = true, isNonInteractionHit:Boolean = false, additionalPayload:Array = null ):void {
			trace( "sendException()" );

			var payload:Array = _generateDefaultPayload();
			payload.push( "t=exception" );

			if(description && (description.length > 0)) {
				payload.push( "exd=" + encodeURIComponent( description ) );
			}

			if(isFatal==false) {
				payload.push( "exf=0" );
			}

			_sendGoogleAnalyticsRequest(payload, isNonInteractionHit, additionalPayload);
		}

		/**
		 * Send an Analytics Measurement timing hit
		 *
		 * @param category Required. Specifies the user timing category. (ie: category) Max length: 150 bytes URI encoded
		 * @param variableName Required. (ie: lookup) Max length: 500 bytes URI encoded
		 * @param time Required. Specifies the user timing value. The value is in milliseconds.
		 * @param label Specifies the user timing label
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		public function sendTiming(category:String, variableName:String, time:int, label:String = "", isNonInteractionHit:Boolean = false, additionalPayload:Array = null ):void {
			trace( "sendTiming()" );

			var payload:Array = _generateDefaultPayload();
			payload.push( "t=timing" );

			payload.push( "utc=" + encodeURIComponent( category ) );
			payload.push( "utv=" + encodeURIComponent( variableName ) );
			payload.push( "utt=" + time );

			if(label && (label.length > 0)) {
				payload.push( "utl=" + encodeURIComponent( label ) );
			}

			_sendGoogleAnalyticsRequest(payload, isNonInteractionHit, additionalPayload);
		}

/*
		public function sendTransaction():void {

		}

		public function sendItem():void {

		}
*/

		/**
		 * Builds the final URL and sends out the actual analytics hit
		 *
		 * @param payload An array containing the payload for the Loader request
		 * @param isNonInteractionHit Specifies that a hit be considered non-interactive.
		 * @param additionalPayload Any additonal payload items should be specified in this array.
		 */
		private function _sendGoogleAnalyticsRequest(payload:Array, isNonInteractionHit:Boolean = false, additionalPayload:Array = null):void {
			var url:String = "";
			if(useSSL) {
				url = "https://ssl.google-analytics.com/collect";
			} else {
				url = "http://www.google-analytics.com/collect";
			}

			if(isNonInteractionHit) {
				payload.push( "ni=1" );
			}

			if(additionalPayload && (additionalPayload.length>0)) {
				payload = payload.concat(additionalPayload);
			}

			if(useCacheBuster) {
				payload.push( "z=" + encodeURIComponent( generateRandomBytes( 6 ).toString()) );
			}

			/**
			 * @todo Check if length of data sent is too big (>2000 bytes) then it should really
			 * done as a POST and not a GET! However a POST may have cross-domain issues according
			 * to the SimplestTracker documentation.
			 */
			var request:URLRequest = new URLRequest();
			request.method = URLRequestMethod.GET;
			request.url    = url;
			request.data   = payload.join( "&" );

			trace( "request is: " + request.url + "?" + request.data );

			_loader = new Loader();
			addLoaderEvents();

			try {
				trace( "Loader send request" );
				_loader.load( request );
			} catch( e:Error ) {
				trace( "unable to load requested page: " + e.message );
				removeLoaderEvents();
			}
		}

		/**
		 * Handles creating the payload that is required of all analytics hits. This takes the
		 * tracking ID, the client ID, any override infomation, and if the analytics mode is set
		 * to "application", then it adds the correct information needs for sending any hits.
		 *
		 * @return An array containing all the items that need to be sent for the Google Analytics request
		 */
		private function _generateDefaultPayload():Array {
			var payload:Array = [];
			// https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
			// General Parameters...
			payload.push( "v=1" );
			payload.push( "tid=" + trackingID );
			// User...
			payload.push( "cid=" + clientID );

			if(userId && (userId.length>0)) {
				payload.push("uid=" + encodeURIComponent( userId ) );
			}

			if(anonymizeIP) {
				payload.push("aip=1");
			}

			if(ipOverride && (ipOverride.length>0) ){
				payload.push("uip=" + encodeURIComponent( ipOverride ) );
			}

			if(userAgenOverride && (userAgenOverride.length>0) ){
				payload.push("ua=" + encodeURIComponent( userAgenOverride ) );
			}

			if(geographicOverride && (geographicOverride.length>0) ){
				payload.push("geoid=" + encodeURIComponent( geographicOverride ) );
			}

			// If in application mode, add that information
			if(_applicationName && (_applicationName.length > 0)) {
				payload.push( "ds=app" );

				// Application - Required!
				payload.push( "an=" + encodeURIComponent( _applicationName ));

				// Application ID
				if(_applicationId && (_applicationId.length > 0)) {
					payload.push( "aid=" + encodeURIComponent( _applicationId ));
				}

				// Application Verison
				if(_applicationVersion && (_applicationVersion.length > 0)) {
					payload.push( "av=" + encodeURIComponent( _applicationVersion ));
				}

				// Application Installer ID
				if(_applicationInstallerId && (_applicationInstallerId.length > 0)) {
					payload.push( "aiid=" + encodeURIComponent( _applicationInstallerId ));
				}
			}

			return payload;
		}

		// ---- Client ID ----
		/**
		 * Creates a string of random numbers to be used to help prevent a browser from caching
		 * the hit
		 *
		 * @return A 16 character string
		 */
		private function _generateCacheBuster():String {
			var result:String = "";
			for(var i:int = 0;i<16;i++) {
				result += Math.floor(Math.random() * 10).toString();
			}
			return result;
		}

		/**
		 * Gets a Client ID to use for the analytics measurements. Since we want to make sure we
		 * use the same Client ID for this instance, we will also store the value if one does not
		 * exist
		 *
		 * @return A unique Client ID, that has been generated by this instance and stored for
		 * later use.
		 */
		private function _getClientID():String {
			trace( "Load the SharedObject '_ga'" );
			_sharedObject = SharedObject.getLocal( "_ga" );

			var clientID:String;
			if( !_sharedObject.data.clientid ) {
				trace( "CID not found, generate Client ID" );
				clientID = resetClientID();
			} else {
				trace( "CID found, restore from SharedObject" );
				clientID = _sharedObject.data.clientid;
			}

			return clientID;
		}

		/**
		 * Resets the client ID and stores it to a Shared Object
		 *
		 * @return A string with the new client ID
		 */
		public function resetClientID():String {
			var clientID:String = _generateUUID();

			trace( "Save CID into SharedObject" );
			_sharedObject.data.clientid = clientID;

			var flushStatus:String = null;
			try {
				flushStatus = _sharedObject.flush( 1024 ); //1KB
			} catch( e:Error ) {
				trace( "Could not write SharedObject to disk: " + e.message );
			}

			if( flushStatus != null ) {
				switch( flushStatus ) {
					case SharedObjectFlushStatus.PENDING:
						trace( "Requesting permission to save object..." );
						_sharedObject.addEventListener( NetStatusEvent.NET_STATUS, onFlushStatus);
						break;
					case SharedObjectFlushStatus.FLUSHED:
						trace( "Value flushed to disk" );
						break;
				}
			}

			return clientID;
		}

		/**
		 * Creates a UUID Version 4 string that should be unique to the user
		 *
		 * @see https://code.google.com/p/as3-universal-analytics/wiki/SimplestTracker
		 *
		 * @return A UUID string
		 */
		private function _generateUUID():String {
			var randomBytes:ByteArray = generateRandomBytes( 16 );
			randomBytes[6] &= 0x0f; /* clear version */
			randomBytes[6] |= 0x40; /* set to version 4 */
			randomBytes[8] &= 0x3f; /* clear variant */
			randomBytes[8] |= 0x80; /* set to IETF variant */

			var toHex:Function = function( n:uint ):String {
				var h:String = n.toString( 16 );
				h = (h.length > 1 ) ? h: "0"+h;
				return h;
			}

			var str:String = "";
			var i:uint;
			var l:uint = randomBytes.length;
			randomBytes.position = 0;
			var byte:uint;

			for( i=0; i<l; i++ ) {
				byte = randomBytes[ i ];
				str += toHex( byte );
			}

			var uuid:String = "";
			uuid += str.substr( 0, 8 );
			uuid += "-";
			uuid += str.substr( 8, 4 );
			uuid += "-";
			uuid += str.substr( 12, 4 );
			uuid += "-";
			uuid += str.substr( 16, 4 );
			uuid += "-";
			uuid += str.substr( 20, 12 );

			return uuid;
		}

		// ---- Event Handling ----
		private function removeLoaderEvents():void {
			_loader.uncaughtErrorEvents.removeEventListener( UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderUncaughtError );
			_loader.contentLoaderInfo.removeEventListener( HTTPStatusEvent.HTTP_STATUS, onLoaderHTTPStatus );
			_loader.contentLoaderInfo.removeEventListener( Event.COMPLETE, onLoaderComplete );
			_loader.contentLoaderInfo.removeEventListener( IOErrorEvent.IO_ERROR, onLoaderIOError );
		}

		private function addLoaderEvents():void {
			_loader.uncaughtErrorEvents.addEventListener( UncaughtErrorEvent.UNCAUGHT_ERROR, onLoaderUncaughtError );
			_loader.contentLoaderInfo.addEventListener( HTTPStatusEvent.HTTP_STATUS, onLoaderHTTPStatus );
			_loader.contentLoaderInfo.addEventListener( Event.COMPLETE, onLoaderComplete );
			_loader.contentLoaderInfo.addEventListener( IOErrorEvent.IO_ERROR, onLoaderIOError );
		}

		private function onFlushStatus( event:NetStatusEvent ):void {
			_sharedObject.removeEventListener( NetStatusEvent.NET_STATUS, onFlushStatus);
			trace( "User closed permission dialog..." );

			switch( event.info.code ) {
				case "SharedObject.Flush.Success":
					trace( "User granted permission, value saved" );
					break;
				case "SharedObject.Flush.Failed":
					trace( "User denied permission, value not saved" );
					break;
			}
		}

		private function onLoaderUncaughtError( event:UncaughtErrorEvent ):void {
			trace( "onLoaderUncaughtError()" );

			if( event.error is Error ) {
				var error:Error = event.error as Error;
				trace( "Error: " + error );
			} else if( event.error is ErrorEvent ) {
				var errorEvent:ErrorEvent = event.error as ErrorEvent;
				trace( "ErrorEvent: " + errorEvent );
			} else {
				trace( "a non-Error, non-ErrorEvent type was thrown and uncaught" );
			}

			removeLoaderEvents();
		}

		private function onLoaderHTTPStatus( event:HTTPStatusEvent ):void {
			trace( "onLoaderHTTPStatus()" );
			trace( "status: " + event.status );

			if( event.status == 200 ) {
				trace( "the request was accepted" );
			} else {
				trace( "the request was not accepted" );
			}
		}

		private function onLoaderIOError( event:IOErrorEvent ):void {
			trace( "onLoaderIOError()" );
			removeLoaderEvents();
		}

		private function onLoaderComplete( event:Event ):void {
			trace( "onLoaderComplete()" );

			trace( "done" );
			removeLoaderEvents();
		}
	}
}
