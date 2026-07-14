package openfl.display3D;

#if flash
typedef Context3D = flash.display3D.Context3D;
#elseif lime_bgfx
typedef Context3D = openfl.display3D.backends.bgfx.Context3D;
#elseif (lime_opengl || lime_opengles)
typedef Context3D = openfl.display3D.backends.opengl.Context3D;
#else
typedef Context3D = Dynamic;
#end
