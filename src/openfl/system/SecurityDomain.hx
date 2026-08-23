package openfl.system;

/**
	The SecurityDomain class represents the current security "sandbox," also
	known as a security domain. By passing an instance of this class to
	`Loader.load()`, you can request that loaded media be placed in a
	particular sandbox.
**/
@SuppressWarnings("checkstyle:UnnecessaryConstructor")
class SecurityDomain
{
	/**
		Gets the current security domain.
	**/
	public static var currentDomain(default, null) = new SecurityDomain();

	@:noCompletion private function new() {}
}
