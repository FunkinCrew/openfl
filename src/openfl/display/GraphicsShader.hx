package openfl.display;

import openfl.utils.ByteArray;

class GraphicsShader extends Shader
{
	@:glVertexHeader("attribute float openfl_Alpha;
		attribute vec4 openfl_ColorMultiplier;
		attribute vec4 openfl_ColorOffset;
		attribute vec4 openfl_Position;
		attribute vec2 openfl_TextureCoord;

		varying float openfl_Alphav;
		varying vec4 openfl_ColorMultiplierv;
		varying vec4 openfl_ColorOffsetv;
		varying vec2 openfl_TextureCoordv;

		uniform mat4 openfl_Matrix;
		uniform bool openfl_HasColorTransform;
		uniform vec2 openfl_TextureSize;", true)
	@:glVertexBody("openfl_Alphav = openfl_Alpha;
		openfl_TextureCoordv = openfl_TextureCoord;

		if (openfl_HasColorTransform) {

			openfl_ColorMultiplierv = openfl_ColorMultiplier;
			openfl_ColorOffsetv = openfl_ColorOffset / 255.0;

		}

		gl_Position = openfl_Matrix * openfl_Position;")
	@:glVertexSource("#pragma header

		void main(void) {

			#pragma body

		}")
	@:glFragmentHeader("varying float openfl_Alphav;
		varying vec4 openfl_ColorMultiplierv;
		varying vec4 openfl_ColorOffsetv;
		varying vec2 openfl_TextureCoordv;

		uniform bool openfl_HasColorTransform;
		uniform vec2 openfl_TextureSize;
		uniform bool sampleAttachment;
		uniform sampler2D bitmap;
		uniform sampler2D openfl_BlendBitmap;
		uniform vec4 openfl_BlendBitmapTransform;
		uniform int openfl_BlendMode;

		const int OPENFL_BLEND_NONE = 0;
		const int OPENFL_BLEND_ADD = 1;
		const int OPENFL_BLEND_DARKEN = 3;
		const int OPENFL_BLEND_DIFFERENCE = 4;
		const int OPENFL_BLEND_HARDLIGHT = 6;
		const int OPENFL_BLEND_INVERT = 7;
		const int OPENFL_BLEND_LIGHTEN = 9;
		const int OPENFL_BLEND_MULTIPLY = 10;
		const int OPENFL_BLEND_OVERLAY = 12;
		const int OPENFL_BLEND_SCREEN = 13;
		const int OPENFL_BLEND_SUBTRACT = 15;
		const int OPENFL_BLEND_COLORDODGE = 16;
		const int OPENFL_BLEND_COLORBURN = 17;
		const int OPENFL_BLEND_SOFTLIGHT = 18;
		const int OPENFL_BLEND_EXCLUSION = 19;
		const int OPENFL_BLEND_HUE = 20;
		const int OPENFL_BLEND_SATURATION = 21;
		const int OPENFL_BLEND_COLOR = 22;
		const int OPENFL_BLEND_LUMINOSITY = 23;

		float openfl_minVec3(vec3 color) {

			return min(min(color.r, color.g), color.b);

		}

		float openfl_maxVec3(vec3 color) {

			return max(max(color.r, color.g), color.b);

		}

		float openfl_lum(vec3 color) {

			return dot(color, vec3(0.30, 0.59, 0.11));

		}

		float openfl_sat(vec3 color) {

			return openfl_maxVec3(color) - openfl_minVec3(color);

		}

		vec3 openfl_clipColor(vec3 color) {

			float luminance = openfl_lum(color);
			float minColor = openfl_minVec3(color);
			float maxColor = openfl_maxVec3(color);

			if (minColor < 0.0) {

				color = luminance + ((color - luminance) * luminance) / (luminance - minColor);

			}

			if (maxColor > 1.0) {

				color = luminance + ((color - luminance) * (1.0 - luminance)) / (maxColor - luminance);

			}

			return color;

		}

		vec3 openfl_setLum(vec3 _col, vec3 colorLum) {

			vec3 delta = colorLum - openfl_lum(_col);
			vec3 c = _col;
			c.r = c.r + delta.r;
			c.g = c.g + delta.g;
			c.b = c.b + delta.b;
			return openfl_clipColor(c);

		}

		vec3 openfl_setSat(vec3 c, float s) {

			float colorMin = openfl_minVec3(c);
			float colorMax = openfl_maxVec3(c);

			if (colorMax > colorMin) {

				if (c.r > colorMin && c.r < colorMax) {

					c.r = (((c.r - colorMin) * s) / (colorMax - colorMin));

				} else if (c.g > colorMin && c.g < colorMax) {

					c.g = (((c.g - colorMin) * s) / (colorMax - colorMin));

				} else if (c.b > colorMin && c.b < colorMax) {

					c.b = (((c.b - colorMin) * s) / (colorMax - colorMin));

				}

				if (c.r == colorMax) c.r = s;
				else if (c.r == colorMin) c.r = 0.0;

				if (c.g == colorMax) c.g = s;
				else if (c.g == colorMin) c.g = 0.0;

				if (c.b == colorMax) c.b = s;
				else if (c.b == colorMin) c.b = 0.0;

			} else {

				c = vec3(0.0, 0.0, 0.0);

			}

			return c;

		}

		vec3 openfl_screen(vec3 bg, vec3 src) {

			return 1.0 - (1.0 - bg) * (1.0 - src);

		}

		vec3 openfl_hardlight(vec3 bg, vec3 src) {

			vec3 c1 = bg * src * 2.0;
			vec3 c2 = openfl_screen(bg, 2.0 * src - 1.0);
			return mix(c1, c2, step(vec3(0.5, 0.5, 0.5), src));

		}

		vec3 openfl_difference(vec3 bg, vec3 src) {

			return abs(bg - src);

		}

		vec3 openfl_invert(vec3 bg) {

			return vec3(1.0, 1.0, 1.0) - bg;

		}

		vec3 openfl_colordodge(vec3 bg, vec3 src) {

			if (all(equal(bg, vec3(0.0, 0.0, 0.0)))) {

				return bg;

			} else if (all(equal(src, vec3(1.0, 1.0, 1.0)))) {

				return src;

			} else {

				vec3 _res = bg / (vec3(1.0, 1.0, 1.0) - src);
				return min(vec3(1.0, 1.0, 1.0), _res);

			}

		}

		vec3 openfl_colorburn(vec3 bg, vec3 src) {

			if (all(equal(bg, vec3(1.0, 1.0, 1.0)))) {

				return bg;

			} else if (all(equal(src, vec3(0.0, 0.0, 0.0)))) {

				return src;

			} else {

				return 1.0 - min(vec3(1.0, 1.0, 1.0), (vec3(1.0, 1.0, 1.0) - bg) / src);

			}

		}

		vec3 openfl_softlight(vec3 bg, vec3 src) {

			vec3 blended = mix(((16.0 * bg - 12.0) * bg + 4.0) * bg, sqrt(bg), step(0.25, bg));

			return mix(bg - (1.0 - 2.0 * src) * bg * (1.0 - bg), bg + (2.0 * src - 1.0) * (blended - bg), step(0.5, src));

		}

		vec3 openfl_exclusion(vec3 bg, vec3 src) {

			return bg + src - vec3(2.0, 2.0, 2.0) * bg * src;

		}

		vec3 openfl_hue(vec3 bg, vec3 src) {

			float lumBg = openfl_lum(bg);
			return openfl_setLum(openfl_setSat(src, openfl_sat(bg)), vec3(lumBg, lumBg, lumBg));

		}

		vec3 openfl_saturation(vec3 bg, vec3 src) {

			float lumBg = openfl_lum(bg);
			return openfl_setLum(openfl_setSat(bg, openfl_sat(src)), vec3(lumBg, lumBg, lumBg));

		}

		vec3 openfl_color(vec3 bg, vec3 src) {

			float lumBg = openfl_lum(bg);
			return openfl_setLum(src, vec3(lumBg, lumBg, lumBg));

		}

		vec3 openfl_blend(vec3 bg, vec3 src) {

			if (openfl_BlendMode == OPENFL_BLEND_SCREEN) {

				return openfl_screen(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_MULTIPLY) {

				return bg * src;

			} else if (openfl_BlendMode == OPENFL_BLEND_ADD) {

				return min(vec3(1.0, 1.0, 1.0), bg + src);

			} else if (openfl_BlendMode == OPENFL_BLEND_SUBTRACT) {

				return max(vec3(0.0, 0.0, 0.0), bg - src);

			} else if (openfl_BlendMode == OPENFL_BLEND_DARKEN) {

				return min(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_HARDLIGHT) {

				return openfl_hardlight(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_LIGHTEN) {

				return max(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_OVERLAY) {

				// NOTE: OVERLAY is the inverse of HARDLIGHT
				return openfl_hardlight(src, bg);

			} else if (openfl_BlendMode == OPENFL_BLEND_DIFFERENCE) {

				return openfl_difference(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_INVERT) {

				return openfl_invert(bg);

			} else if (openfl_BlendMode == OPENFL_BLEND_COLORDODGE) {

				return openfl_colordodge(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_COLORBURN) {

				return openfl_colorburn(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_SOFTLIGHT) {

				return openfl_softlight(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_EXCLUSION) {

				return openfl_exclusion(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_HUE) {

				return openfl_hue(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_SATURATION) {

				return openfl_saturation(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_COLOR) {

				return openfl_color(bg, src);

			} else if (openfl_BlendMode == OPENFL_BLEND_LUMINOSITY) {

				// NOTE: LUMINOSITY is the inverse of COLOR
				return openfl_color(src, bg);

			} else {

				return src;

			}

		}

		bool openfl_hasBlendBitmap() {

			return openfl_BlendMode != OPENFL_BLEND_NONE;

		}

		vec4 openfl_applyBlend(vec4 src) {

			if (!openfl_hasBlendBitmap()) return src;

			if (src.a <= 0.0) return src;

			vec2 blendCoord = gl_FragCoord.xy * openfl_BlendBitmapTransform.xy + openfl_BlendBitmapTransform.zw;

			vec4 bg = texture2D(openfl_BlendBitmap, blendCoord);

			vec3 _res = openfl_blend(bg.rgb, src.rgb / src.a);

			return vec4(_res * src.a, src.a);

		}

		vec4 openfl_texture2D(sampler2D bitmap, vec2 coord) {

			vec4 color = texture2D (bitmap, coord);

			if (color.a == 0.0) {

				return openfl_applyBlend (vec4 (0.0, 0.0, 0.0, 0.0));

			} else if (openfl_HasColorTransform) {

				color = vec4 (color.rgb / color.a, color.a);

				mat4 colorMultiplier = mat4 (0);
				colorMultiplier[0][0] = openfl_ColorMultiplierv.x;
				colorMultiplier[1][1] = openfl_ColorMultiplierv.y;
				colorMultiplier[2][2] = openfl_ColorMultiplierv.z;
				colorMultiplier[3][3] = 1.0; // openfl_ColorMultiplierv.w;

				color = clamp (openfl_ColorOffsetv + (color * colorMultiplier), 0.0, 1.0);

				if (color.a > 0.0) {

					return openfl_applyBlend (vec4 (color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav));

				}

				return openfl_applyBlend (vec4 (0.0, 0.0, 0.0, 0.0));

			}

			return openfl_applyBlend (color * openfl_Alphav);

		}", true)
	@:glFragmentBody("gl_FragColor = openfl_texture2D (bitmap, openfl_TextureCoordv);", true)
	@:glFragmentSource("#pragma header

		void main(void) {

			#pragma body

		}")
	public function new(code:ByteArray = null)
	{
		super(code);
	}
}
