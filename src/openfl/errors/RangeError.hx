package openfl.errors;

/**
	A RangeError exception is thrown when a numeric value is outside the
	acceptable range.

	Some situations that cause this exception to be thrown include the
	following:

	- Any OpenFL API that expects a depth number is invoked with an invalid depth number.
	- Any OpenFL API that expects a frame number is invoked with an invalid frame number.
	- Any OpenFL API that expects a layer number is invoked with an invalid layer number.
**/
class RangeError extends Error
{
	public function new(message:String = "")
	{
		super(message, 0);

		name = "RangeError";
	}
}
