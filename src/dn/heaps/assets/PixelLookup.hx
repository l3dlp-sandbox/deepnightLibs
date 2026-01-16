package dn.heaps.assets;

import dn.heaps.slib.SpriteLib;
import hxd.Pixels;
import dn.Col;

class PixelLookup extends dn.Process {
	public static function fromSlib(slib:SpriteLib, ?slibPixels:Pixels, lookupColor:Col) : Map<Int,PixelPoint> {
		var pixels = slibPixels ?? slib.tile.getTexture().capturePixels();

		var col = lookupColor.withAlphaIfMissing();
		var points : Map<Int, PixelPoint> = new Map();
		for(group in slib.getGroups())
		for(frame in group.frames) {
			var pt = lookupSubPixels(pixels, frame.x, frame.y, frame.wid, frame.hei, col);
			if( pt!=null )
				points.set(frame.uid, pt);
		}

		return points;
	}


	public static function replaceColorLib(slib:SpriteLib, lookupColor:Col, newColorWithAlpha:Col, ignoreSourceAlpha:Bool) {
		var pixels = slib.tile.getTexture().capturePixels();

		var c : Col = 0;
		for(x in 0...pixels.width)
		for(y in 0...pixels.height) {
			c = pixels.getPixel(x,y);
			if( ignoreSourceAlpha && c.withoutAlpha()==lookupColor || !ignoreSourceAlpha && c==lookupColor )
				pixels.setPixel(x,y, newColorWithAlpha);
		}
		var newTile = h2d.Tile.fromPixels(pixels);
		slib.tile.switchTexture(newTile);
	}


	/**
	 * Replace multiple colors at once.
	 *
	 * @param remap A map from source color to target color.
	 * @param ignoreSourceAlpha If true, the alpha channel of the source pixel is ignored when matching (only RGB is matched).
	 *                          Otherwise, the alpha channel is considered when matching colors.
	 */
	public static function replaceColorsLib(slib:SpriteLib, remap:Map<Col, Col>, ignoreSourceAlpha:Bool) {
		var pixels = slib.tile.getTexture().capturePixels();
		replaceColorsPixels(pixels, remap, ignoreSourceAlpha);

		var newTile = h2d.Tile.fromPixels(pixels);
		slib.tile.switchTexture(newTile);
	}


	/**
	 * Replace multiple colors at once.
	 *
	 * @param pixels The pixels to modify (WARNING: this modifies the pixels in place).
	 * @param remap A map from source color to target color.
	 * @param ignoreSourceAlpha If true, the alpha channel of the source pixel is ignored when matching (only RGB is matched).
	 *                          Otherwise, the alpha channel is considered when matching colors.
	 */
	public static function replaceColorsPixels(pixels:Pixels, remap:Map<Col, Col>, ignoreSourceAlpha:Bool) {
		var c : Col = 0;
		for(x in 0...pixels.width)
		for(y in 0...pixels.height) {
			c = pixels.getPixel(x,y);
			if( remap.exists( ignoreSourceAlpha ? c.withoutAlpha() : c ) ) {
				var newCol = remap.get( ignoreSourceAlpha ? c.withoutAlpha() : c );
				pixels.setPixel( x,y, newCol );
			}
		}
	}


	static function lookupSubPixels(pixels:Pixels, x:Int, y:Int, w:Int, h:Int, col:Col) : Null<PixelPoint> {
		for(px in x...x+w)
		for(py in y...y+h)
			if( pixels.getPixel(px,py)==col )
				return new PixelPoint(px-x, py-y);

		return null;
	}
}


class PixelPoint {
	public var x : Int;
	public var y : Int;

	public inline function new(x:Int, y:Int) {
		this.x = x;
		this.y = y;
	}

	@:keep
	public function tostring() {
		return 'PixelPoint($x,$y)';
	}
}