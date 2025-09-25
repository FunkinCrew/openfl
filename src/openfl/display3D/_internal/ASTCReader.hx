package openfl.display3D._internal;

#if !flash
import openfl.errors.IllegalOperationError;
import openfl.utils.ByteArray;
import openfl.utils._internal.UInt8Array;

/**
	This class can read ASTC texture containers according to the Khronos ASTC specification.

	To use this reader:
	- Create a new `ASTCReader` instance with a `ByteArray` containing the ASTC file.
	- Access the header properties such as block dimensions, width, height, and depth.
	- Retrieve the compressed block data to upload to a GPU API like OpenGL's `compressedTexImage2D`.

	The reader does not decode ASTC into pixels. It only validates the container and computes information needed for GPU uploads.
**/
@SuppressWarnings("checkstyle:FieldDocComment")
class ASTCReader
{
	public static inline final HEADER_SIZE:Int = 16;

	public var width(default, null):Int;
	public var height(default, null):Int;
	public var depth(default, null):Int;

	public var blockX(default, null):Int;
	public var blockY(default, null):Int;
	public var blockZ(default, null):Int;

	public var blockCountX(default, null):Int;
	public var blockCountY(default, null):Int;
	public var blockCountZ(default, null):Int;

	public var expectedDataSize(default, null):Int;

	@:noCompletion
	private var data:ByteArray;

	public function new(data:ByteArray):Void
	{
		this.data = data;

		final sig0:UInt = data.readUnsignedByte();
		final sig1:UInt = data.readUnsignedByte();
		final sig2:UInt = data.readUnsignedByte();
		final sig3:UInt = data.readUnsignedByte();

		if (sig0 != 0x13 || sig1 != 0xAB || sig2 != 0xA1 || sig3 != 0x5C)
		{
			throw new IllegalOperationError("ASTC signature not found");
		}

		blockX = data.readUnsignedByte();
		blockY = data.readUnsignedByte();
		blockZ = data.readUnsignedByte();

		if (blockZ == 0)
		{
			blockZ = 1;
		}

		width = data.readUnsignedByte() | (data.readUnsignedByte() << 8) | (data.readUnsignedByte() << 16);
		height = data.readUnsignedByte() | (data.readUnsignedByte() << 8) | (data.readUnsignedByte() << 16);
		depth = data.readUnsignedByte() | (data.readUnsignedByte() << 8) | (data.readUnsignedByte() << 16);

		if (depth == 0)
		{
			depth = 1;
		}

		blockCountX = Math.ceil(width / blockX);
		blockCountY = Math.ceil(height / blockY);
		blockCountZ = Math.ceil(depth / blockZ);

		expectedDataSize = blockCountX * blockCountY * blockCountZ * 16;

		if (data.position + expectedDataSize > data.length)
		{
			throw new IllegalOperationError("ASTC: file too short for header + blocks");
		}
	}

	public function getCompressedData():UInt8Array
	{
		return new UInt8Array(data.toArrayBuffer(), HEADER_SIZE, expectedDataSize);
	}

	public function dispose():Void
	{
		data = null;
	}
}
#end
