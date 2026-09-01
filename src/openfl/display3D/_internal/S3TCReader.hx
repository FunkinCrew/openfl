package openfl.display3D._internal;

import lime.utils.UInt8Array;
import openfl.errors.IllegalOperationError;
import openfl.utils.ByteArray;

/**
 * This class can read DDS texture containers compressed with S3TC (DXT1, DXT3, DXT5).
 *
 * To use this reader:
 *
 * - Create a new `S3TCReader` instance with a `ByteArray` containing the DDS file.
 * - Access the header properties such as width, height, mipmap count, and format.
 * - Retrieve the compressed block data to upload to a GPU API like OpenGL's
 *   `compressedTexImage2D`.
 *
 * The reader does not decode S3TC into pixels. It only validates the container and computes information needed for GPU uploads.
 */
@SuppressWarnings("checkstyle:FieldDocComment")
class S3TCReader
{
	public static inline final HEADER_SIZE:Int = 128;

	public static inline final FOURCC_DXT1:Int = 0x31545844;
	public static inline final FOURCC_DXT3:Int = 0x33545844;
	public static inline final FOURCC_DXT5:Int = 0x35545844;
	public static inline final FOURCC_DX10:Int = 0x30315844;

	public static inline final DXGI_FORMAT_BC1_UNORM:Int = 71;
	public static inline final DXGI_FORMAT_BC1_UNORM_SRGB:Int = 72;
	public static inline final DXGI_FORMAT_BC2_UNORM:Int = 74;
	public static inline final DXGI_FORMAT_BC2_UNORM_SRGB:Int = 75;
	public static inline final DXGI_FORMAT_BC3_UNORM:Int = 77;
	public static inline final DXGI_FORMAT_BC3_UNORM_SRGB:Int = 78;

	public var flags(default, null):Int;
	public var width(default, null):Int;
	public var height(default, null):Int;
	public var mipmapCount(default, null):Int;
	public var pfSize(default, null):Int;
	public var pfFlags(default, null):Int;
	public var fourCC(default, null):Int;
	public var dxgiFormat(default, null):Int;
	public var formatName(default, null):String;
	public var expectedDataSize(default, null):Int;

	@:noCompletion
	private var data:ByteArray;

	public function new(data:ByteArray):Void
	{
		this.data = data;
		data.position = 0;

		final magic:Int = data.readInt();

		if (magic != 0x20534444)
		{
			throw new IllegalOperationError("S3TC: Invalid DDS signature");
		}

		final headerSize:Int = data.readInt();

		if (headerSize != 124)
		{
			throw new IllegalOperationError("S3TC: Invalid DDS header size");
		}

		flags = data.readInt();
		height = data.readInt();
		width = data.readInt();

		data.position += 8;

		mipmapCount = data.readInt();

		if (mipmapCount == 0)
		{
			mipmapCount = 1;
		}

		data.position += 44;

		pfSize = data.readInt();
		pfFlags = data.readInt();
		fourCC = data.readInt();

		dxgiFormat = 0;

		switch (fourCC)
		{
			case FOURCC_DXT1:
				formatName = "DXT1";
			case FOURCC_DXT3:
				formatName = "DXT3";
			case FOURCC_DXT5:
				formatName = "DXT5";
			case FOURCC_DX10:
				if (data.length < HEADER_SIZE + 20)
				{
					throw new IllegalOperationError("S3TC: File too short for DX10 header");
				}

				data.position = HEADER_SIZE;

				dxgiFormat = data.readInt();

				switch (dxgiFormat)
				{
					case DXGI_FORMAT_BC1_UNORM, DXGI_FORMAT_BC1_UNORM_SRGB:
						formatName = "DXT1";
					case DXGI_FORMAT_BC2_UNORM, DXGI_FORMAT_BC2_UNORM_SRGB:
						formatName = "DXT3";
					case DXGI_FORMAT_BC3_UNORM, DXGI_FORMAT_BC3_UNORM_SRGB:
						formatName = "DXT5";
					default:
						throw new IllegalOperationError("S3TC: Unsupported DX10 DXGI format");
				}
			default:
				throw new IllegalOperationError("S3TC: Unsupported FourCC compression format");
		}

		expectedDataSize = 0;

		var currentWidth:Int = width;
		var currentHeight:Int = height;

		for (i in 0...mipmapCount)
		{
			final blockCountX:Int = Math.ceil(Math.max(1, currentWidth) / 4);
			final blockCountY:Int = Math.ceil(Math.max(1, currentHeight) / 4);

			expectedDataSize += blockCountX * blockCountY * ((formatName == "DXT1") ? 8 : 16);

			currentWidth = Math.floor(currentWidth / 2);
			currentHeight = Math.floor(currentHeight / 2);
		}

		if (((fourCC == FOURCC_DX10) ? HEADER_SIZE + 20 : HEADER_SIZE) + expectedDataSize > data.length)
		{
			throw new IllegalOperationError("S3TC: File too short for header + compressed blocks");
		}
	}

	public function getCompressedData():UInt8Array
	{
		return new UInt8Array(data.toArrayBuffer(), (fourCC == FOURCC_DX10) ? HEADER_SIZE + 20 : HEADER_SIZE, expectedDataSize);
	}

	public function dispose():Void
	{
		data = null;
	}
}
