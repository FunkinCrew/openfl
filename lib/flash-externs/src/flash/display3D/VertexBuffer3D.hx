package flash.display3D;

#if flash
import openfl.utils._internal.ArrayBufferView;
import openfl.utils.ByteArray;
import openfl.Vector;

extern class VertexBuffer3D
{
	public function dispose():Void;
	public function uploadFromByteArray(data:ByteArray, byteArrayOffset:Int, startVertex:Int, numVertices:Int):Void;
	public inline function uploadFromTypedArray(data:ArrayBufferView):Void
	{
		uploadFromByteArray(data.buffer, data.byteOffset, 0, data.byteLength);
	}
	public function uploadFromVector(data:Vector<Float>, startVertex:Int, numVertices:Int):Void;
	public inline function uploadFromArray(data:Array<Float>, startVertex:Int, numVertices:Int):Void
	{
		var vector = new Vector<Float>(data.length);
		for (i in 0...data.length)
		{
			vector[i] = data[i];
		}
		uploadFromVector(vector, startVertex, numVertices);
	}
}
#else
typedef VertexBuffer3D = openfl.display3D.VertexBuffer3D;
#end
