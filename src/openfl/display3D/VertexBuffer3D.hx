package openfl.display3D;

import haxe.io.Bytes;
import lime.graphics.bgfx.BGFXAttrib;
import lime.graphics.bgfx.BGFXAttribType;
import lime.graphics.bgfx.BGFXDynamicVertexBuffer;
import lime.graphics.bgfx.BGFXMemoryRef;
import lime.graphics.bgfx.BGFXTransientVertexBuffer;
import lime.graphics.bgfx.BGFXVertexBuffer;
import lime.graphics.bgfx.BGFXVertexLayout;
import lime.graphics.bgfx.BGFXVertexLayoutHandle;
import lime.graphics.opengl.GLBuffer;
import lime.utils.ArrayBufferView;
import lime.utils.Float32Array;
import openfl.Vector;
import openfl.utils.ByteArray;

/**
	The VertexBuffer3D class represents a set of vertex data uploaded to a rendering context.

	Use a VertexBuffer3D object to define the data associated with each point in a set
	of vertexes. You can upload the vertex data either from a Vector array or a ByteArray.
	(Once uploaded, the data in the original array is no longer referenced; changing or
	discarding the source array does not change the vertex data.)

	The data associated with each vertex is in an application-defined format and is used
	as the input for the vertex shader program. Identify which values belong to which
	vertex program input using the Context3D `setVertexBufferAt()` function. A vertex
	program can use up to eight inputs (also known as vertex attribute registers). Each
	input can require between one and four 32-bit values. For example, the [x,y,z]
	position coordinates of a vertex can be passed to a vertex program as a vector
	containing three 32 bit values. The Context3DVertexBufferFormat class defines
	constants for the supported formats for shader inputs. You can supply up to
	sixty-four 32-bit values (256 bytes) of data for each point (but a single vertex
	shader cannot use all of the data in this case).

	The `setVertexBufferAt()` function also identifies which vertex buffer to use for
	rendering any subsequent `drawTriangles()` calls. To render data from a different
	vertex buffer, call setVertexBufferAt() again with the appropriate arguments. (You
	can store data for the same point in multiple vertex buffers, say position data in
	one buffer and texture coordinates in another, but typically rendering is more
	efficient if all the data for a point comes from a single buffer.)

	The Index3DBuffer object passed to the Context3D `drawTriangles()` method organizes
	the vertex data into triangles. Each value in the index buffer is the index to a
	vertex in the vertex buffer. A set of three indexes, in sequence, defines a triangle.

	You cannot create a VertexBuffer3D object directly. Use the Context3D
	`createVertexBuffer()` method instead.

	To free the render context resources associated with a vertex buffer, call the object's
	`dispose()` method.
**/
@:access(openfl.display3D.Context3D)
@:access(openfl.display.Stage)
class VertexBuffer3D
{
	@:noCompletion private var __context:Context3D;
	@:noCompletion private var __memoryUsage:Int = -1;
	@:noCompletion private var __numVertices:Int;
	@:noCompletion private var __stride:Int;
	@:noCompletion private var __tempFloat32Array:Float32Array;
	@:noCompletion private var __usage:Context3DBufferUsage;
	@:noCompletion private var __vertexSize:Int;
	@:noCompletion private var __id:GLBuffer;
	@:noCompletion private var __layoutStartVertex:Int = 0;
	@:noCompletion private var __lastFrameId:Int = -1;
	@:noCompletion private var __attribs:Array<BGFXVertexAttrib>;
	@:noCompletion private var __attribMask:Int = 0;
	@:noCompletion private var __vbh:BGFXVertexBufferHandle;
	@:noCompletion private var __vbLayout:BGFXVertexLayoutData;
	@:noCompletion private var __transientData:ArrayBufferView;
	@:noCompletion private var __transientDataLength:Int = -1;
	@:noCompletion private var __skipTransient:Bool = false;
	@:noCompletion private var __transientDynamic(get, never):Bool;

	@:noCompletion private static inline var MAX_ATTRIBS:Int = 18;

	@:noCompletion private static var __defaultLayout:BGFXVertexLayoutData;
	@:noCompletion private static var __layouts:Array<BGFXVertexLayoutData>;
	@:noCompletion private static var __sortedAttribs:Array<BGFXVertexAttrib> = [];

	@:noCompletion private function new(context3D:Context3D, numVertices:Int, dataPerVertex:Int, bufferUsage:Context3DBufferUsage)
	{
		__context = context3D;
		__numVertices = numVertices;
		__vertexSize = dataPerVertex;

		if (!__context.isBGFX)
		{
			var gl = __context.gl;
			__id = gl.createBuffer();
		}

		__stride = __vertexSize * 4;
		__usage = bufferUsage;
	}

	/**
		Frees all resources associated with this object. After disposing a vertex
		buffer, calling `upload()` and rendering using this object will fail.
	**/
	public function dispose():Void
	{
		if (__context.isBGFX)
		{
			if (__vbh != null)
			{
				var bgfx = __context.bgfx;
				switch (__vbh)
				{
					case Static(vb):
						bgfx.destroyVertexBuffer(vb);
					case Dynamic(dvb):
						bgfx.destroyDynamicVertexBuffer(dvb);
					case Transient(_, _):
						// bgfx clears those internally at the end of the frame
				}
			}
		}
		else
		{
			var gl = __context.gl;
			gl.deleteBuffer(__id);
		}
	}

	/**
		Uploads the data for a set of points to the rendering context from a byte array.

		@param	data	a byte array containing the vertex data. Each data value is four
		bytes long. The number of values in a vertex is specified at buffer creation
		using the data32PerVertex parameter to the Context3D `createVertexBuffer3D()`
		method. The length of the data in bytes must be `byteArrayOffset` plus four times
		the number of values per vertex times the number of vertices. The ByteArray object
		must use the little endian format.
		@param	byteArrayOffset	number of bytes to skip from the beginning of data
		@param	startVertex	The index of the first vertex to be loaded. A value for
		startVertex not equal to zero may be used to load a sub-region of the vertex data.
		@param	numVertices	The number of vertices to be loaded from data.
		@throws	TypeError	Null Pointer Error: when data is `null`.
		@throws	RangeError	Bad Input Size: if `byteArrayOffset` is less than 0, or if
		`byteArrayOffset` is greater than or equal to the length of data, or if no. of
		elements in data - `byteArrayOffset` is less than `numVertices*data32pervertex*4`
		given in Context3D `createVertexBuffer()`.
		@throws	Error	3768: The Stage3D API may not be used during background execution.
	**/
	public function uploadFromByteArray(data:ByteArray, byteArrayOffset:Int, startVertex:Int, numVertices:Int):Void
	{
		var offset = byteArrayOffset + startVertex * __stride;
		var length = numVertices * __vertexSize;

		uploadFromTypedArray(new Float32Array(data, offset, length));
	}

	/**
		Uploads the data for a set of points to the rendering context from a typed array.

		@param	data	a typed array of 32-bit values. A single vertex is comprised of a
		number of values stored sequentially in the vector. The number of values in a
		vertex is specified at buffer creation using the `data32PerVertex` parameter to the
		Context3D `createVertexBuffer3D()` method.
		@param	byteLength	The number of bytes to read.
	**/
	public function uploadFromTypedArray(data:ArrayBufferView, byteLength:Int = -1):Void
	{
		if (data == null) return;

		if (byteLength < 0 || byteLength > data.byteLength) byteLength = data.byteLength;

		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;

			var reupload = (__lastFrameId == __context.__frameId);
			if (__transientDynamic && !__skipTransient && __uploadTransient(data, byteLength))
			{
				__lastFrameId = __context.__frameId;
				return;
			}

			if (__vbh != null)
			{
				switch (__vbh)
				{
					case Transient(_, _):
						__vbh = null;
						__transientData = null;
						__transientDataLength = -1;
					default:
				}
			}

			var mem = bgfx.copy(data);
			switch (__usage)
			{
				case STATIC_DRAW:
					if (__vbh != null)
					{
						switch (__vbh)
						{
							case Static(vb): bgfx.destroyVertexBuffer(vb);
							case Dynamic(dvb): bgfx.destroyDynamicVertexBuffer(dvb);
							case Transient(_, _): // bgfx clears those internally at the end of the frame
						}

						__vbh = null;
					}

					__vbh = Static(bgfx.createVertexBuffer(mem, __getBaseLayout()));

				case DYNAMIC_DRAW:
					if (__vbh != null)
					{
						switch (__vbh)
						{
							case Dynamic(dvb):
								if (!reupload)
								{
									bgfx.updateDynamicVertexBuffer(dvb, 0, mem);
								}
								else
								{
									__context.__buffersReset.push(() -> __context.bgfx.destroyDynamicVertexBuffer(dvb));
									__vbh = Dynamic(bgfx.createDynamicVertexBufferMem(mem, __getBaseLayout(), bgfx.BUFFER_ALLOW_RESIZE));
								}
							default:
						}
					}
					else
					{
						__vbh = Dynamic(bgfx.createDynamicVertexBufferMem(mem, __getBaseLayout(), bgfx.BUFFER_ALLOW_RESIZE));
					}
			}

			__lastFrameId = __context.__frameId;
			__memoryUsage = data.byteLength;
		}
		else
		{
			var gl = __context.gl;
			var usage = (__usage == Context3DBufferUsage.DYNAMIC_DRAW) ? gl.DYNAMIC_DRAW : gl.STATIC_DRAW;
			__context.__bindGLArrayBuffer(__id);

			if (__memoryUsage >= data.byteLength)
			{
				#if (js && html5)
				var bytesPerElement:Int = untyped data.BYTES_PER_ELEMENT;
				gl.bufferSubData(gl.ARRAY_BUFFER, 0, data, 0, bytesPerElement > 0 ? Std.int(byteLength / bytesPerElement) : byteLength);
				#else
				gl.bufferSubData(gl.ARRAY_BUFFER, 0, data, 0, byteLength);
				#end
			}
			else
			{
				gl.bufferData(gl.ARRAY_BUFFER, data, usage);
				__memoryUsage = data.byteLength;
			}
		}
	}

	/**
		Uploads the data for a set of points to the rendering context from a vector array.

		@param	data	a vector of 32-bit values. A single vertex is comprised of a
		number of values stored sequentially in the vector. The number of values in a
		vertex is specified at buffer creation using the data32PerVertex parameter to the
		Context3D `createVertexBuffer3D()` method. The length of the vector must be the
		number of values per vertex times the number of vertexes.
		@param	startVertex	The index of the first vertex to be loaded. A value for
		`startVertex` not equal to zero may be used to load a sub-region of the vertex data.
		@param	numVertices	The number of vertices represented by data.
		@throws	TypeError	Null Pointer Error: when `data` is `null`.
		@throws	RangeError	Bad Input Size: when number of elements in data is less than
		`numVertices * data32PerVertex` given in Context3D `createVertexBuffer()`, or
		when `startVertex + numVertices` is greater than `numVertices` given in Context3D
		`createVertexBuffer()`.
	**/
	public function uploadFromVector(data:Vector<Float>, startVertex:Int, numVertices:Int):Void
	{
		if (data == null) return;

		// TODO: Optimize more

		var start = startVertex * __vertexSize;
		var count = numVertices * __vertexSize;
		var length = start + count;

		var existingFloat32Array = __tempFloat32Array;

		if (__tempFloat32Array == null || __tempFloat32Array.length < count)
		{
			__tempFloat32Array = new Float32Array(count);

			if (existingFloat32Array != null)
			{
				__tempFloat32Array.set(existingFloat32Array);
			}
		}

		for (i in start...length)
		{
			__tempFloat32Array[i - start] = data[i];
		}

		uploadFromTypedArray(__tempFloat32Array);
	}

	/**
		Uploads the data for a set of points to the rendering context from an array.

		@param	data	an array of 32-bit values. A single vertex is comprised of a
		number of values stored sequentially in the array. The number of values in a
		vertex is specified at buffer creation using the data32PerVertex parameter to the
		Context3D `createVertexBuffer3D()` method. The length of the array must be the
		number of values per vertex times the number of vertexes.
		@param	startVertex	The index of the first vertex to be loaded. A value for
		`startVertex` not equal to zero may be used to load a sub-region of the vertex data.
		@param	numVertices	The number of vertices represented by data.
		@throws	TypeError	Null Pointer Error: when `data` is `null`.
		@throws	RangeError	Bad Input Size: when number of elements in data is less than
		`numVertices * data32PerVertex` given in Context3D `createVertexBuffer()`, or
		when `startVertex + numVertices` is greater than `numVertices` given in Context3D
		`createVertexBuffer()`.
	**/
	public function uploadFromArray(data:Array<Float>, startVertex:Int, numVertices:Int):Void
	{
		if (data == null) return;

		// TODO: Optimize more

		var start = startVertex * __vertexSize;
		var count = numVertices * __vertexSize;
		var length = start + count;

		var existingFloat32Array = __tempFloat32Array;

		if (__tempFloat32Array == null || __tempFloat32Array.length < count)
		{
			__tempFloat32Array = new Float32Array(count);

			if (existingFloat32Array != null)
			{
				__tempFloat32Array.set(existingFloat32Array);
			}
		}

		for (i in start...length)
		{
			__tempFloat32Array[i - start] = data[i];
		}

		uploadFromTypedArray(__tempFloat32Array);
	}

	// Basically on bgfx you have to build static VertexLayout and pass them onto the vbuffer
	// OpenFL (and GL itself) is designed so you write the layout every time you use the buffer
	@:noCompletion private static function __registerDefaultLayouts(context3D:Context3D)
	{
		if (__layouts != null) return;

		__layouts = [];

		// Pre-Create the most common and regular layout that would be used
		// This layout defines a vertex with a 2 floats texture position and 2 floats texture coords
		__defaultLayout = __getLayout(context3D, [
			new BGFXVertexAttrib(BGFXAttrib.POSITION, 2, BGFXAttribType.FLOAT, false, false, 0),
			new BGFXVertexAttrib(BGFXAttrib.TEXCOORD0, 2, BGFXAttribType.FLOAT, false, false, 2)
		], 2, 0);

		// This layout defines a vertex with a 4 floats texture position and 2 floats texture coords
		__getLayout(context3D, [
			new BGFXVertexAttrib(BGFXAttrib.POSITION, 4, BGFXAttribType.FLOAT, false, false, 0),
			new BGFXVertexAttrib(BGFXAttrib.TEXCOORD0, 2, BGFXAttribType.FLOAT, false, false, 4)
		], 2, 0);
	}

	@:noCompletion private static inline function __attribTypeSize(type:BGFXAttribType):Int
	{
		return switch (type)
		{
			case INT8, UINT8: 1;
			case INT16, UINT16, HALF: 2;
			default: 4;
		}
	}

	@:noCompletion private static function __getLayout(context3D:Context3D, attribs:Array<BGFXVertexAttrib>, count:Int, stride:Int):BGFXVertexLayoutData
	{
		for (layout in __layouts)
			if (layout.equals(attribs, count, stride)) return layout;

		var bgfx = context3D.bgfx;

		var vertexLayout = bgfx.createVertexLayout();
		vertexLayout.begin(bgfx.getRendererType());

		var pos = 0;
		for (i in 0...count)
		{
			var attrib = attribs[i];
			var byteOffset = attrib.offset * 4;
			if (byteOffset > pos) vertexLayout.skip(byteOffset - pos);
			vertexLayout.add(attrib.attrib, attrib.num, attrib.type, attrib.normalized, attrib.asInt);
			pos = byteOffset + attrib.num * __attribTypeSize(attrib.type);
		}
		if (stride > pos) vertexLayout.skip(stride - pos);

		vertexLayout.end();

		var layout = new BGFXVertexLayoutData([for (i in 0...count) attribs[i].clone()], stride, vertexLayout, bgfx.registerVertexLayout(vertexLayout));
		__layouts.push(layout);

		return layout;
	}

	@:noCompletion private function __queueAttrib(attrib:Int, num:Int, type:BGFXAttribType, normalized:Bool, asInt:Bool, offset:Int = 0):Void
	{
		if (attrib < 0 || attrib >= MAX_ATTRIBS) return;

		if (__attribs == null) __attribs = [
			for (_ in 0...MAX_ATTRIBS) new BGFXVertexAttrib(0, 0, BGFXAttribType.FLOAT, false, false, 0)
		];

		__attribs[attrib].setTo(attrib, num, type, normalized, asInt, offset);
		__attribMask |= 1 << attrib;
	}

	@:noCompletion private function __buildLayoutQueue()
	{
		var count = 0;
		for (i in 0...MAX_ATTRIBS)
		{
			if ((__attribMask & (1 << i)) == 0) continue;

			var attrib = __attribs[i];
			var k = count++;
			while (k > 0 && __sortedAttribs[k - 1].offset > attrib.offset)
			{
				__sortedAttribs[k] = __sortedAttribs[k - 1];
				k--;
			}
			__sortedAttribs[k] = attrib;
		}
		__attribMask = 0;

		var batchStart = count > 0 ? __sortedAttribs[0].offset : 0;
		__layoutStartVertex = (batchStart > 0 && __vertexSize > 0) ? Std.int(batchStart / __vertexSize) : 0;
		if (batchStart > 0) for (i in 0...count)
			__sortedAttribs[i].offset -= batchStart;

		if (__vbLayout == null
			|| !__vbLayout.equals(__sortedAttribs, count, __stride)) __vbLayout = __getLayout(__context, __sortedAttribs, count, __stride);
	}

	@:noCompletion private function __updateLayout(vertices:Int, stream:Int = 0)
	{
		var bgfx = __context.bgfx;

		switch (__vbh)
		{
			case Transient(_, frameId) if (frameId != __context.__frameId):
				__vbh = null;

				if (__transientData == null) return;

				var data = __transientData;
				var length = __transientDataLength;
				__transientData = null;
				__transientDataLength = -1;

				__skipTransient = true;
				uploadFromTypedArray(data, length);
				__skipTransient = false;
			default:
		}

		var vertexCount = vertices;
		if (vertexCount < 0)
		{
			vertexCount = (__memoryUsage > 0 && __stride > 0) ? Std.int(__memoryUsage / __stride) : __numVertices;
		}

		if (__vbh == null) return;

		switch (__vbh)
		{
			case Static(vb):
				bgfx.setVertexBufferLayout(stream, vb, __layoutStartVertex, vertexCount, __vbLayout.handle);
			case Dynamic(dvb):
				bgfx.setDynamicVertexBufferLayout(stream, dvb, __layoutStartVertex, vertexCount, __vbLayout.handle);
			case Transient(tvb, _):
				bgfx.setTransientVertexBufferLayout(stream, tvb, __layoutStartVertex, vertexCount, __vbLayout.handle);
		}
	}

	@:noCompletion private inline function __getBaseLayout()
	{
		return __vbLayout != null ? __vbLayout.layout : __defaultLayout.layout;
	}

	@:noCompletion private function __buildSingleAttribLayout(attrib:Int, num:Int)
	{
		__queueAttrib(attrib, num, BGFXAttribType.FLOAT, false, false, 0);
		__buildLayoutQueue();
	}

	@:noCompletion private function __uploadTransient(data:ArrayBufferView, byteLength:Int = -1):Bool
	{
		var bgfx = __context.bgfx;
		var layout = __getBaseLayout();

		var bytes = byteLength >= 0 ? byteLength : data.byteLength;
		var vertexCount = __stride > 0 ? Std.int(bytes / __stride) : 0;

		if (vertexCount <= 0) return false;
		if (bgfx.getAvailTransientVertexBuffer(vertexCount, layout) < vertexCount) return false;

		var tvb = bgfx.allocTransientVertexBuffer(vertexCount, layout);
		tvb.data = data;

		__vbh = Transient(tvb, __context.__frameId);
		__transientData = data;
		__transientDataLength = byteLength;
		__numVertices = vertexCount;
		__memoryUsage = bytes;

		return true;
	}

	@:noCompletion
	private inline function get___transientDynamic():Bool
	{
		#if openfl_bgfx_no_transient_dynamic
		return false;
		#else
		return __usage == Context3DBufferUsage.DYNAMIC_DRAW;
		#end
	}
}

@:noCompletion
class BGFXVertexAttrib
{
	public var attrib:BGFXAttrib;
	public var num:Int;
	public var type:BGFXAttribType;
	public var normalized:Bool;
	public var asInt:Bool;
	public var offset:Int;

	public function new(attrib:BGFXAttrib, num:Int, type:BGFXAttribType, normalized:Bool, asInt:Bool, offset:Int)
	{
		setTo(attrib, num, type, normalized, asInt, offset);
	}

	public function setTo(attrib:BGFXAttrib, num:Int, type:BGFXAttribType, normalized:Bool, asInt:Bool, offset:Int):Void
	{
		this.attrib = attrib;
		this.num = num;
		this.type = type;
		this.normalized = normalized;
		this.asInt = asInt;
		this.offset = offset;
	}

	public function clone():BGFXVertexAttrib
	{
		return new BGFXVertexAttrib(attrib, num, type, normalized, asInt, offset);
	}

	public function equals(other:BGFXVertexAttrib):Bool
	{
		return attrib == other.attrib && num == other.num && type == other.type && normalized == other.normalized && asInt == other.asInt
			&& offset == other.offset;
	}
}

@:noCompletion
class BGFXVertexLayoutData
{
	public final attribs:Array<BGFXVertexAttrib>;
	public final stride:Int;
	public final layout:BGFXVertexLayout;
	public final handle:BGFXVertexLayoutHandle;

	public function new(attribs:Array<BGFXVertexAttrib>, stride:Int, layout:BGFXVertexLayout, handle:BGFXVertexLayoutHandle)
	{
		this.attribs = attribs;
		this.stride = stride;
		this.layout = layout;
		this.handle = handle;
	}

	public function equals(attribs:Array<BGFXVertexAttrib>, count:Int, stride:Int):Bool
	{
		if (this.stride != stride || this.attribs.length != count) return false;

		for (i in 0...count)
			if (!this.attribs[i].equals(attribs[i])) return false;

		return true;
	}
}

// to hold either transient, static or dynamic buffer in one field
enum BGFXVertexBufferHandle
{
	Static(vb:BGFXVertexBuffer);
	Dynamic(dvb:BGFXDynamicVertexBuffer);
	Transient(tvb:BGFXTransientVertexBuffer, frameId:Int);
}
