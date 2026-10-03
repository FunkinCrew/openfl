package openfl.display3D;

import openfl.geom.Rectangle;

/**
	What the shader blend modes use as their destination.
**/
enum Context3DBlendTarget
{
	/**
		Blend ontop of whatever is currently being rendered on.
		The default.
	**/
	BlendRenderTarget;

	/**
		Blend against the backbuffer, ignoring the current target if it was a render texture.

		`viewport` is the view offset.
		Must be configured if youre current submit has it's own render target with a transform.
	**/
	BlendBackBuffer(?viewport:Rectangle);

	/**
		Blend ontop of whatever is currently being rendered on.

		BUT use the backbuffer as a background!
		`viewport` is the backbuffer view offset.
		Must be configured if youre current submit has it's own render target with a transform.
	**/
	BlendMergedTarget(?viewport:Rectangle);

	/**
		Blend against a `bitmap` you speicify.
	**/
	BlendCustomTarget(bitmap:openfl.display.BitmapData);
}
