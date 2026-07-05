package openfl.display;

#if !flash
interface IContext3DRenderer
{
	public var originBottomLeft(get, never):Bool;

	public function updateShader():Void;

	public function __flushUseArray(shader:Shader):Void;

	private function __clearBackBufferGutter():Void;
}
#end
