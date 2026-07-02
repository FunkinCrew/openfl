package openfl.errors;

/**
	Permission error is dispatched when the application tries to access a
	resource without requesting appropriate permissions.
**/
class PermissionError extends Error
{
	/**
		Creates a new instance of the PermissionError class.

		@param message The error description
		@param id The general error number
	**/
	public function new(message:String = "", id:Int = 0)
	{
		super(message, id);

		name = "PermissionError";
	}
}
