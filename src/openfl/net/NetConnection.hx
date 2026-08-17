package openfl.net;

import openfl.events.EventDispatcher;
import openfl.events.NetStatusEvent;

/**
	The NetConnection class creates a two-way connection between a client and
	a server. The client can be a Flash Player or AIR application. The server
	can be a web server, Flash Media Server, an application server running
	Flash Remoting, or the <a
	href="http://labs.adobe.com/technologies/stratus/" scope="external">Adobe
	Stratus</a> service. Call `NetConnection.connect()` to establish the
	connection. Use the NetStream class to send streams of media and data over
	the connection.
	For security information about loading content and data into Flash Player
	and AIR, see the following:

	* To load content and data into Flash Player from a web server or from a
	local location, see <a href="http://www.adobe.com/go/devnet_security_en"
	scope="external">Flash Player Developer Center: Security</a>.
	* To load content and data into Flash Player and AIR from Flash Media
	Server, see the <a href="http://www.adobe.com/support/flashmediaserver"
	scope="external">Flash Media Server documentation</a>.
	* To load content and data into AIR, see the <a
	href="http://www.adobe.com/devnet/air/" scope="external">Adobe AIR
	Developer Center</a>.

	To write callback methods for this class, extend the class and define the
	callback methods in the subclass, or assign the `client` property to an
	object and define the callback methods on that object.

	@event asyncError    Dispatched when an exception is thrown asynchronously
						 — that is, from native asynchronous code.
	@event ioError       Dispatched when an input or output error occurs that
						 causes a network operation to fail.
	@event netStatus     Dispatched when a NetConnection object is reporting
						 its status or error condition. The `netStatus` event
						 contains an `info` property, which is an information
						 object that contains specific information about the
						 event, such as whether a connection attempt succeeded
						 or failed.
	@event securityError Dispatched if a call to NetConnection.call() attempts
						 to connect to a server outside the caller's security
						 sandbox.
**/
class NetConnection extends EventDispatcher
{
	@SuppressWarnings("checkstyle:FieldDocComment")
	@:noCompletion @:dox(hide) public static inline var CONNECT_SUCCESS:String = "NetConnection.Connect.Success";

	/**
		Creates a NetConnection object. Call the `connect()` method to make a
		connection.
		If an application needs to communicate with servers released prior to
		Flash Player 9, set the NetConnection object's `objectEncoding`
		property.

		The following code creates a NetConnection object:

		```haxe
		var nc = new NetConnection();
		```
	**/
	public function new()
	{
		super();
	}

	/**
		Creates a two-way connection to an application on Flash Media Server
		or to Flash Remoting, or creates a two-way network endpoint for RTMFP
		peer-to-peer group communication. To report its status or an error
		condition, a call to `NetConnection.connect()` dispatches a
		`netStatus` event.
		Call `NetConnection.connect()` to do the following:

		* Pass "null" to play video and mp3 files from a local file system or
		from a web server.
		* Pass an "http" URL to connect to an application server running Flash
		Remoting. Use the NetServices class to call functions on and return
		results from application servers over a NetConnection object. For more
		information, see the <a
		href="http://www.adobe.com/support/documentation"
		scope="external">Flash Remoting documentation</a>.
		* Pass an "rtmp/e/s" URL to connect to a Flash Media Server
		application.
		* Pass an "rtmfp" URL to create a two-way network endpoint for RTMFP
		client-server, peer-to-peer, and IP multicast communication.
		* Pass the string "rtmfp:" to create a serverless two-way network
		endpoint for RTMFP IP multicast communication.

		Consider the following security model:

		* By default, Flash Player or AIR denies access between sandboxes. A
		website can enable access to a resource by using a URL policy file.
		* Your application can deny access to a resource on the server. In a
		Flash Media Server application, use Server-Side ActionScript code to
		deny access. See the <a
		href="http://www.adobe.com/go/learn_fms_docs_en"
		scope="external">Flash Media Server documentation</a>.
		* You cannot call `NetConnection.connect()` if the calling file is in
		the local-with-file-system sandbox.
		*  You cannot connect to commonly reserved ports. For a complete list
		of blocked ports, see "Restricting Networking APIs" in the
		_OpenFL Developer's Guide_.
		* To prevent a SWF file from calling this method, set the
		`allowNetworking` parameter of the the `object` and `embed` tags in
		the HTML page that contains the SWF content.

		However, in Adobe AIR, content in the `application` security sandbox
		(content installed with the AIR application) are not restricted by
		these security limitations.

		For more information about security, see the Adobe Flash Player
		Developer Center: [Security](http://www.adobe.com/go/devnet_security_en).

		@param command Use one of the following values for the `command`
					   parameter:
					   * To play video and mp3 files from a local file system
					   or from a web server, pass `null`.
					   * To connect to an application server running Flash
					   Remoting, pass a URL that uses the `http` protocol.
					   * (Flash Player 10.1 or AIR 2 or later) To create a
					   serverless network endpoint for RTMFP IP multicast
					   communication, pass the string `"rtmfp:"`. Use this
					   connection type to receive an IP multicast stream from
					   a publisher without using a server. You can also use
					   this connection type to use IP multicast to discover
					   peers on the same local area network (LAN).
					   This connection type has the following limitations:
					   Only peers on the same LAN can discover each other.
					   Using IP multicast, Flash Player can receive streams,
					   it cannot send them.
					   Flash Player and AIR can send and receive streams in a
					   peer-to-peer group, but the peers must be discovered on
					   the same LAN using IP multicast.
					   This technique cannot be used for one-to-one
					   communication.
					   <p/>
					   * To connect to Flash Media Server, pass the URI of the
					   application on the server. Use the following syntax
					   (items in brackets are optional):
					   `protocol:[//host][:port]/appname[/instanceName]`

					   Use one of the following protocols: `rtmp`, `rtmpe`,
					   `rtmps`, `rtmpt`, `rtmpte`, or `rtmfp`. If the
					   connection is successful, a `netStatus` event with a
					   `code` property of `NetConnection.Connect.Success` is
					   returned. See the `NetStatusEvent.info` property for a
					   list of all event codes returned in response to calling
					   `connect()`.

					   If the file is served from the same host where the
					   server is installed, you can omit the `//host`
					   parameter. If you omit the `/instanceName` parameter,
					   Flash Player or AIR connects to the application's
					   default instance.

					   (Flash Player 10.1 or AIR 2 or later)To create
					   peer-to-peer applications, use the `rtmfp` protocol.
		@throws ArgumentError The URI passed to the `command` parameter is
							  improperly formatted.
		@throws IOError       The connection failed. This can happen if you
							  call `connect()` from within a `netStatus` event
							  handler, which is not allowed.
		@throws SecurityError Local-with-filesystem SWF files cannot
							  communicate with the Internet. You can avoid
							  this problem by reclassifying the SWF file as
							  local-with-networking or trusted.
		@throws SecurityError You cannot connect to commonly reserved ports.
							  For a complete list of blocked ports, see
							  "Restricting Networking APIs" in the
							  _OpenFL Developer's Guide_.
	**/
	public function connect(command:String, p1 = null, p2 = null, p3 = null, p4 = null, p5 = null):Void
	{
		if (command != null)
		{
			throw "Error: Can only connect in \"HTTP streaming\" mode";
		}

		this.dispatchEvent(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, true, {code: NetConnection.CONNECT_SUCCESS}));
	}
}
