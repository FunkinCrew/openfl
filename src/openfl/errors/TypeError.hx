package openfl.errors;

/**
	A TypeError exception is thrown when the actual type of an operand is
	different from the expected type.
**/
class TypeError extends Error
{
	public function new(message:String = "")
	{
		super(message, 0);

		name = "TypeError";
	}
}
