package openfl.display3D;

#if flash
typedef Context3D = flash.display3D.Context3D;
#elseif bgfx
typedef Context3D = openfl.display3D.backends.bgfx.Context3D;
#elseif opengl
typedef Context3D = openfl.display3D.backends.opengl.Context3D;
#else
typedef Context3D = Dynamic;
#end
