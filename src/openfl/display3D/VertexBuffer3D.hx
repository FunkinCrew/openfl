package openfl.display3D;

#if !flash
#if lime_bgfx
import haxe.io.Bytes;
import lime.graphics.bgfx.BGFXAttrib;
import lime.graphics.bgfx.BGFXMemoryRef;
import lime.graphics.bgfx.BGFXAttribType;
import lime.graphics.bgfx.BGFXAttribInfo;
import lime.graphics.bgfx.BGFXDynamicVertexBuffer;
import lime.graphics.bgfx.BGFXVertexBuffer;
import lime.graphics.bgfx.BGFXVertexLayout;
import lime.graphics.bgfx.BGFXVertexLayoutHandle;
import haxe.ds.Map;
#elseif lime_webgl
import openfl.display3D._internal.GLBuffer;
#end
import openfl.utils._internal.ArrayBufferView;
import openfl.utils._internal.Float32Array;
import openfl.utils.ByteArray;
import openfl.Vector;

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
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
#if lime_bgfx
@:access(openfl.display3D.backends.bgfx.Context3D)
#elseif lime_webgl
@:access(openfl.display3D.backends.opengl.Context3D)
#end
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
	#if lime_webgl
	@:noCompletion private var __id:GLBuffer;
	#elseif lime_bgfx
	@:noCompletion private var __layoutStartVertex:Int = 0;
	@:noCompletion private var __layoutQueue:Array<{attrib:BGFXAttrib, info:BGFXAttribInfo, offset:Int}> = [];
	@:noCompletion private var __vbh:BGFXVertexBufferHandle;
	@:noCompletion private var __vbLayout:{layout:BGFXVertexLayout, handle:BGFXVertexLayoutHandle};

	@:noCompletion private static var __defaultMainLayoutKey:String = '';
	@:noCompletion private static var __vlayouts:Map<String, {layout:BGFXVertexLayout, handle:BGFXVertexLayoutHandle}>;
	#end

	#if lime_bgfx
	// Basically on bgfx you have to build static VertexLayout and pass them onto the vbuffer
	// OpenFL (and GL itself) is designed so you write the layout every time you use the buffer
	// Best way to have the static BGFX layout work seamlessly with OpenFL is a hash based layout cache
	@:noCompletion private static function __registerDefaultLayouts(context3D:Context3D)
	{
		if (__vlayouts != null) return;

		var bgfx = context3D.bgfx;
		__vlayouts = new Map();

		// Create the most common and regular layout that would be used
		// This layout defines a vertex with a 2 floats texture position and 2 floats texture coords
		__defaultMainLayoutKey = __registerLayout(context3D, [
			{
				attrib: BGFXAttrib.POSITION,
				offset: 0,
				info: {
					num: 2,
					type: BGFXAttribType.FLOAT,
					normalized: false,
					asInt: false
				}
			},
			{
				attrib: BGFXAttrib.TEXCOORD0,
				offset: 2,
				info: {
					num: 2,
					type: BGFXAttribType.FLOAT,
					normalized: false,
					asInt: false
				}
			}
		]);

		// This layout defines a vertex with a 4 floats texture position and 2 floats texture coords
		__registerLayout(context3D, [
			{
				attrib: BGFXAttrib.POSITION,
				offset: 0,
				info: {
					num: 4,
					type: BGFXAttribType.FLOAT,
					normalized: false,
					asInt: false
				}
			},
			{
				attrib: BGFXAttrib.TEXCOORD0,
				offset: 4,
				info: {
					num: 2,
					type: BGFXAttribType.FLOAT,
					normalized: false,
					asInt: false
				}
			}
		]);
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

	@:noCompletion private static function __registerLayout(context3D:Context3D, layout:Array<{attrib:BGFXAttrib, info:BGFXAttribInfo, offset:Int}>,
			stride:Int = 0):String
	{
		var bgfx = context3D.bgfx;

		layout.sort((a, b) -> a.offset - b.offset);

		var key:Bytes = Bytes.alloc((layout.length * 6) + 2);
		for (i => layoutData in layout)
		{
			var base = i * 6;
			key.set(base + 0, layoutData.attrib);
			key.set(base + 1, layoutData.info.num);
			key.set(base + 2, layoutData.info.type);
			key.set(base + 3, layoutData.info.normalized ? 1 : 0);
			key.set(base + 4, layoutData.info.asInt ? 1 : 0);
			key.set(base + 5, layoutData.offset);
		}
		key.set(layout.length * 6 + 0, stride & 0xFF);
		key.set(layout.length * 6 + 1, (stride >> 8) & 0xFF);

		var keyHex:String = key.toHex();
		if (!__vlayouts.exists(keyHex))
		{
			var _layout = bgfx.createVertexLayout();
			_layout.begin(bgfx.getRendererType());

			var pos = 0;
			for (layoutData in layout)
			{
				var byteOffset = layoutData.offset * 4;
				if (byteOffset > pos) _layout.skip(byteOffset - pos);
				_layout.add(layoutData.attrib, layoutData.info.num, layoutData.info.type, layoutData.info.normalized, layoutData.info.asInt);
				pos = byteOffset + layoutData.info.num * __attribTypeSize(layoutData.info.type);
			}
			if (stride > pos) _layout.skip(stride - pos);

			_layout.end();

			var handle = bgfx.registerVertexLayout(_layout);
			__vlayouts.set(keyHex, {layout: _layout, handle: handle});
		}

		return keyHex;
	}

	@:noCompletion private function __queueLayout(attrib:BGFXAttrib, info:BGFXAttribInfo, offset:Int = 0)
	{
		__layoutQueue.push({attrib: attrib, info: info, offset: offset});
	}

	@:noCompletion private function __buildLayoutQueue()
	{
		var batchStart = 0;
		if (__layoutQueue.length > 0)
		{
			batchStart = __layoutQueue[0].offset;
			for (q in __layoutQueue)
				if (q.offset < batchStart) batchStart = q.offset;
		}
		__layoutStartVertex = (batchStart > 0 && __vertexSize > 0) ? Std.int(batchStart / __vertexSize) : 0;
		if (batchStart > 0)
		{
			for (q in __layoutQueue)
				q.offset -= batchStart;
		}

		var keyHex = __registerLayout(__context, __layoutQueue, __stride);
		__vbLayout = __vlayouts[keyHex];
		__layoutQueue = [];
	}

	@:noCompletion private function __updateLayout(vertices:Null<Int>)
	{
		var bgfx = __context.bgfx;

		var vertexCount = vertices;
		if (vertexCount == null)
		{
			vertexCount = (__memoryUsage > 0 && __stride > 0) ? Std.int(__memoryUsage / __stride) : __numVertices;
		}

		switch (__vbh)
		{
			case Static(vb):
				bgfx.setVertexBufferLayout(0, vb, __layoutStartVertex, vertexCount, __vbLayout.handle);
			case Dynamic(dvb):
				bgfx.setDynamicVertexBufferLayout(0, dvb, __layoutStartVertex, vertexCount, __vbLayout.handle);
		}
	}
	#end

	@:noCompletion private function new(context3D:Context3D, numVertices:Int, dataPerVertex:Int, bufferUsage:Context3DBufferUsage)
	{
		__context = context3D;
		__numVertices = numVertices;
		__vertexSize = dataPerVertex;

		#if lime_webgl
		var gl = __context.gl;
		__id = gl.createBuffer();
		#end

		__stride = __vertexSize * 4;
		__usage = bufferUsage;
	}

	/**
		Frees all resources associated with this object. After disposing a vertex
		buffer, calling `upload()` and rendering using this object will fail.
	**/
	public function dispose():Void
	{
		#if lime_webgl
		var gl = __context.gl;
		gl.deleteBuffer(__id);
		#elseif lime_bgfx
		if (__vbh != null)
		{
			var bgfx = __context.bgfx;
			switch (__vbh)
			{
				case Static(vb):
					bgfx.destroyVertexBuffer(vb);
				case Dynamic(dvb):
					bgfx.destroyDynamicVertexBuffer(dvb);
			}
		}
		#end
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
		#if lime
		var offset = byteArrayOffset + startVertex * __stride;
		var length = numVertices * __vertexSize;

		uploadFromTypedArray(new Float32Array(data, offset, length));
		#end
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
		#if lime_webgl
		var gl = __context.gl;
		var usage = (bufferUsage == Context3DBufferUsage.DYNAMIC_DRAW) ? gl.DYNAMIC_DRAW : gl.STATIC_DRAW;
		__context.__bindGLArrayBuffer(__id);

		if (__memoryUsage == data.byteLength) gl.bufferSubData(gl.ARRAY_BUFFER, 0, data);
		else
			gl.bufferData(gl.ARRAY_BUFFER, data, usage);
		#elseif lime_bgfx
		var bgfx = __context.bgfx;
		var mem = bgfx.copy(data);

		if (__memoryUsage == data.byteLength)
		{
			switch (__vbh)
			{
				case Static(vb):
					// you can't update a static buffer
					// recreate it!!!
					bgfx.destroyVertexBuffer(vb);
					__vbh = Static(bgfx.createVertexBuffer(mem, __vbLayout != null ? __vbLayout.layout : __vlayouts[__defaultMainLayoutKey].layout));
				case Dynamic(dvb):
					bgfx.updateDynamicVertexBuffer(dvb, 0, mem);
			}
		}
		else
		{
			__vbh = switch (__usage)
			{
				case STATIC_DRAW: Static(bgfx.createVertexBuffer(mem, __vlayouts[__defaultMainLayoutKey].layout));
				case DYNAMIC_DRAW: Dynamic(bgfx.createDynamicVertexBufferMem(mem, __vlayouts[__defaultMainLayoutKey].layout, bgfx.BUFFER_ALLOW_RESIZE));
			};
		}
		#end
		__memoryUsage = data.byteLength;
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
		#if lime
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
		#end
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
		#if lime
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
		#end
	}
}

#if lime_bgfx
// to hold either static or dynamic buffer in one field
enum BGFXVertexBufferHandle
{
	Static(vb:BGFXVertexBuffer);
	Dynamic(dvb:BGFXDynamicVertexBuffer);
}
#end
#else
typedef VertexBuffer3D = flash.display3D.VertexBuffer3D;
#end
