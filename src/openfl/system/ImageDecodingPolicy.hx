package openfl.system;

#if (!flash && sys && (!flash_doc_gen || air_doc_gen))
/**
	The ImageDecodingPolicy class provides values for `imageDecodingPolicy` in
	the LoaderContext class.
**/
enum abstract ImageDecodingPolicy(Null<Int>)
{
	/**
		Specifies that the image being loaded will be decoded when needed and
		that the decoded data may be flushed at will by the system. If flushed,
		it will be re-decoded as needed.
	**/
	public var ON_DEMAND = 0;

	/**
		Specifies that the image being loaded will be decoded on load, prior to
		the `complete` event being sent. The decoded image data is cached, and
		may be flushed at will by the system. If flushed, it will be re-decoded
		as needed.
	**/
	public var ON_LOAD = 1;

	@:from private static function fromString(value:String):ImageDecodingPolicy
	{
		return switch (value)
		{
			case "onDemand": ON_DEMAND;
			case "onLoad": ON_LOAD;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : ImageDecodingPolicy)
		{
			case ImageDecodingPolicy.ON_DEMAND: "onDemand";
			case ImageDecodingPolicy.ON_LOAD: "onLoad";
			default: null;
		}
	}
}
#end
