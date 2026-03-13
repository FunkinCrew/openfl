package flash.display3D;

#if flash
import openfl.utils._internal.ArrayBufferView;
import openfl.utils.ByteArray;
import openfl.Vector;

@:final extern class IndexBuffer3D
{
	public function dispose():Void;
	public function uploadFromByteArray(data:ByteArray, byteArrayOffset:Int, startOffset:Int, count:Int):Void;
	public inline function uploadFromTypedArray(data:ArrayBufferView):Void
	{
		uploadFromByteArray(data.buffer, data.byteOffset, 0, data.byteLength);
	}
	public function uploadFromVector(data:Vector<UInt>, startOffset:Int, count:Int):Void;
	public inline function uploadFromArray(data:Array<UInt>, startOffset:Int, count:Int):Void
	{
		var vector = new Vector<UInt>(data.length);
		for (i in 0...data.length)
		{
			vector[i] = data[i];
		}
		uploadFromVector(vector, startOffset, count);
	}
}
#else
typedef IndexBuffer3D = openfl.display3D.IndexBuffer3D;
#end
