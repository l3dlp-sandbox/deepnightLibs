package dn.heaps.filter;

class Crt extends h2d.filter.Shader<InternalShader> {
	/** Scanline texture color (RGB format, defaults to 0xffffff) **/
	public var scanlineColor(default,set) : Col;

	/** Scanline texture opacity (0-1) (defaults to 1.0) **/
	public var scanlineAlpha(get,set) : Float;

	/** Horizontal screen distorsion intensity (0-1), defaults to 0.5 **/
	public var curvatureH(default,set) : Float;

	/** Verticval screen distorsion intensity (0-1), defaults to 0.5 **/
	public var curvatureV(default,set) : Float;

	/** Dark vignetting intensity (0-1), defaults to 0.5 **/
	public var vignetting(default,set) : Float;

	/** Height of the scanlines **/
	public var scanlineSize(default,set) : Int;

	/** Bloom intensity (0-1), defaults to 0 **/
	public var bloomIntensity(default,set) : Float;

	/** Bloom threshold (0-1), defaults to 0.75 **/
	public var bloomThreshold(default,set) : Float;

	/** Bloom radius in pixels, defaults to 2 **/
	public var bloomRadius(default,set) : Float;

	/** RGB chromatic aberration offset in pixels, defaults to 0 **/
	public var chromaticAberration(default,set) : Float;

	/** Small blur amount (0-1), defaults to 0 **/
	public var blurIntensity(default,set) : Float;

	/** Small blur radius in pixels, defaults to 1 **/
	public var blurRadius(default,set) : Float;

	/** Set this method to automatically update scanline size based on your own criterions. It should return the new scanline size. **/
	public var autoUpdateSize: Null< Void->Int > = null;

	var scanlineTex : h3d.mat.Texture;
	var invalidated = true;

	/**
		@param scanlineSize Height of the scanline overlay texture blocks
	**/
	public function new(scanlineSize=2, scanlineColor:Col=0xffffff, alpha=1.0) {
		super( new InternalShader() );
		this.scanlineAlpha = alpha;
		this.scanlineSize = scanlineSize;
		this.scanlineColor = scanlineColor;
		curvatureH = 0.5;
		curvatureV = 0.5;
		vignetting = 0.5;
		bloomIntensity = 0;
		bloomThreshold = 0.75;
		bloomRadius = 2;
		chromaticAberration = 0;
		blurIntensity = 0;
		blurRadius = 1;
	}

	/** Force re-creation of the overlay texture (not to be called often!) **/
	inline function invalidate() {
		invalidated = true;
	}

	inline function set_curvatureH(v:Float) {
		curvatureH = v;
		return shader.curvature.y = v<=0 ?  99  :  2 + (1-v) * 10;
	}

	inline function set_curvatureV(v:Float) {
		curvatureV = v;
		return shader.curvature.x = v<=0 ?  99  :  2 + (1-v) * 10;
	}

	inline function set_vignetting(v:Float) {
		shader.vignetting = M.fclamp(v, 0, 1);
		return vignetting = shader.vignetting;
	}

	inline function set_bloomIntensity(v:Float) {
		shader.bloomIntensity = M.fclamp(v, 0, 1);
		return bloomIntensity = shader.bloomIntensity;
	}

	inline function set_bloomThreshold(v:Float) {
		shader.bloomThreshold = M.fclamp(v, 0, 1);
		return bloomThreshold = shader.bloomThreshold;
	}

	inline function set_bloomRadius(v:Float) {
		if( v<0 )
			v = 0;
		shader.bloomRadius = v;
		return bloomRadius = v;
	}

	inline function set_chromaticAberration(v:Float) {
		if( v<0 )
			v = 0;
		shader.chromaticAberration = v;
		return chromaticAberration = v;
	}

	inline function set_blurIntensity(v:Float) {
		shader.blurIntensity = M.fclamp(v, 0, 1);
		return blurIntensity = shader.blurIntensity;
	}

	inline function set_blurRadius(v:Float) {
		if( v<0 )
			v = 0;
		shader.blurRadius = v;
		return blurRadius = v;
	}

	inline function set_scanlineSize(v) {
		if( scanlineSize!=v )
			invalidate();
		return scanlineSize = v;
	}

	inline function set_scanlineColor(v) {
		if( scanlineColor!=v )
			invalidate();
		return scanlineColor = v;
	}

	inline function set_scanlineAlpha(v:Float) return shader.alpha = v;
	inline function get_scanlineAlpha() return shader.alpha;

	override function sync(ctx:h2d.RenderContext, s:h2d.Object) {
		super.sync(ctx, s);

		if( !Std.isOfType(s, h2d.Scene) )
			throw "CRT filter should only be attached to a 2D Scene";

		if( invalidated ) {
			invalidated = false;
			initTexture(ctx.scene.width, ctx.scene.height);
		}

		if( autoUpdateSize!=null && scanlineSize!=autoUpdateSize() ) {
			scanlineSize = autoUpdateSize();
			// The invalidation re-render will only occur during next frame, to make sure scene width/height is properly set
		}
	}

	function initTexture(screenWid:Float, screenHei:Float) {
		// Cleanup
		if( scanlineTex!=null )
			scanlineTex.dispose();

		// Init texture
		final neutral = 0xFF808080;
		var bd = new hxd.BitmapData(scanlineSize,scanlineSize);
		bd.clear(neutral);
		for(x in 0...bd.width)
			bd.setPixel(x, 0, scanlineColor);

		scanlineTex = h3d.mat.Texture.fromBitmap(bd);
		scanlineTex.filter = Nearest;
		scanlineTex.wrap = Repeat;

		// Update shader
		shader.scanline = scanlineTex;
		shader.texelSize.set( 1/screenWid, 1/screenHei );
		shader.uvScale = new hxsl.Types.Vec( screenWid / scanlineTex.width, screenHei / scanlineTex.width );
	}
}



// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {

	static var SRC = {
		@param var texture : Sampler2D;
		@param var scanline : Sampler2D;

		@param var curvature : Vec2;
		@param var vignetting : Float;
		@param var alpha : Float;
		@param var uvScale : Vec2;
		@param var texelSize : Vec2;

		@param var bloomIntensity : Float;
		@param var bloomThreshold : Float;
		@param var bloomRadius : Float;
		@param var chromaticAberration : Float;
		@param var blurIntensity : Float;
		@param var blurRadius : Float;

		function blendOverlay(base:Vec3, blend:Vec3) : Vec3 {
			return mix(
				1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
				2.0 * base * blend,
				step( base, vec3(0.5) )
			);
		}

		function curve(uv:Vec2) : Vec2 {
			var out = uv*2 - 1;

			var offset = abs(out.yx) / curvature;
			out = out + out * offset * offset;

			out = out*0.5 + 0.5;
			return out;
		}

		function vignette(uv:Vec2) : Float {
			var off = max( abs(uv.y*2-1) / 4,  abs(uv.x*2-1) / 4 );
			return 300 * off*off*off*off*off;
		}

		function inBounds(uv:Vec2) : Float {
			return step(0, uv.x) * step(uv.x, 1) * step(0, uv.y) * step(uv.y, 1);
		}

		function safeGet(uv:Vec2) : Vec4 {
			return texture.get(uv) * inBounds(uv);
		}

		function luminance(c:Vec3) : Float {
			return dot(c, vec3(0.299, 0.587, 0.114));
		}

		function getBloom(c:Vec4) : Vec3 {
			var k = max(0, luminance(c.rgb) - bloomThreshold) / max(0.0001, 1 - bloomThreshold);
			return c.rgb * k * c.a;
		}

		function fragment() {
			// Distortion
			var uv = curve( input.uv );

			// Center sample
			var center = safeGet(uv);
			var color = center.rgb;

			// Quick blur
			if( blurIntensity>0. ) {
				var blurOff = texelSize * blurRadius;

				var blurColor =
					safeGet(uv + vec2( blurOff.x, 0.0)).rgb +
					safeGet(uv + vec2(-blurOff.x, 0.0)).rgb +
					safeGet(uv + vec2(0.0,  blurOff.y)).rgb +
					safeGet(uv + vec2(0.0, -blurOff.y)).rgb;

				color = mix(color, blurColor * 0.25, blurIntensity);
			}

			// RGB chromatic aberration
			if( chromaticAberration>0. ) {
				var ca = texelSize * chromaticAberration;
				var caDir = normalize(input.uv*2 - 1 + vec2(0.0001));

				color.r = safeGet(uv + caDir * ca).r;
				color.g = mix(color.g, center.g, 0.5);
				color.b = safeGet(uv - caDir * ca).b;
			}

			// Cheap bloom approximation because I'm too dumb to do a proper gaussian blur in a single pass
			if( bloomIntensity>0. ) {
				var bloomOff = texelSize * bloomRadius;
				var bloom =
					getBloom(center) * 0.2 +
					getBloom(safeGet(uv + vec2( bloomOff.x, 0))) * 0.2 +
					getBloom(safeGet(uv + vec2(-bloomOff.x, 0))) * 0.2 +
					getBloom(safeGet(uv + vec2(0,  bloomOff.y))) * 0.2 +
					getBloom(safeGet(uv + vec2(0, -bloomOff.y))) * 0.2;

				color += bloom * bloomIntensity;
			}

			// Scanlines texture
			var scanlineColor = mix( vec4(0.5), scanline.get(input.uv*uvScale), alpha );
			pixelColor.rgba = vec4(
				blendOverlay( color, scanlineColor.rgb ),
				center.a
			);

			// Vignetting
			pixelColor.rgb *= 1 - vignetting * vignette(input.uv);

			// Clear out-of-bounds pixels
			pixelColor.rgba *= inBounds(uv);
		}

	};
}
