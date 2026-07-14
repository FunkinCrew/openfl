package openfl.display3D.textures;

#if lime_bgfx
typedef TextureBase = openfl.display3D.backends.bgfx.textures.TextureBase;
#elseif (lime_opengl || lime_opengles)
typedef TextureBase = openfl.display3D.backends.opengl.textures.TextureBase;
#elseif flash
typedef TextureBase = flash.display3D.textures.TextureBase;
#end
