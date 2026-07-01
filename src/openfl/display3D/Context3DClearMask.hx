package openfl.display3D;

/**
	Defines the values to use for specifying Context3D clear masks.
**/
enum abstract Context3DClearMask(UInt) from UInt to UInt from Int to Int
{
	/**
		Clear all buffers.
	**/
	public var ALL = 0x07;

	/**
		Clear only the color buffer.
	**/
	public var COLOR = 0x01;

	/**
		Clear only the depth buffer.
	**/
	public var DEPTH = 0x02;

	/**
		Clear only the stencil buffer.
	**/
	public var STENCIL = 0x04;
}
