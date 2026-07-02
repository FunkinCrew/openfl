package openfl.errors;

/**
	The ArgumentError class represents an error that occurs when the arguments
	supplied in a function do not match the arguments defined for that function.
	This error occurs, for example, when a function is called with the wrong
	number of arguments, an argument of the incorrect type, or an invalid
	argument.
**/
class ArgumentError extends Error
{
	/**
		Creates an ArgumentError object.
	**/
	public function new(message:String = "")
	{
		super(message);

		name = "ArgumentError";
	}
}
