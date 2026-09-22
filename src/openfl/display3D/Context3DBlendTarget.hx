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
		Blend against a `bitmap` you speicify.
	**/
	BlendCustomTarget(bitmap:openfl.display.BitmapData);
}
