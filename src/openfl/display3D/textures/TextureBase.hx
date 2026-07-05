package openfl.display3D.textures;

#if bgfx
typedef TextureBase = openfl.display3D.backends.bgfx.textures.TextureBase;
#elseif opengl
typedef TextureBase = openfl.display3D.backends.opengl.textures.TextureBase;
#elseif flash
typedef TextureBase = flash.display3D.textures.TextureBase;
#end
