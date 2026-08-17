package openfl.geom;

import openfl.Vector;

/**
	The Utils3D class contains static methods that simplify the implementation of
	certain three-dimensional matrix operations.
**/
class Utils3D
{
	/**
		Using a projection Matrix3D object, projects a Vector3D object from one space
		coordinate to another. The `projectVector()` method is like the
		`Matrix3D.transformVector()` method except that the `projectVector()` method
		divides the x, y, and z elements of the original Vector3D object by the
		projection depth value. The depth value is the distance from the eye to the
		Vector3D object in view or eye space. The default value for this distance is the
		value of the z element.

		@param	m	A projection Matrix3D object that implements the projection
		transformation. If a display object has a PerspectiveProjection object, you can
		use the `perspectiveProjection.toMatrix()` method to produce a projection Matrix3D
		object that applies to the children of the display object. For more advance
		projections, use the `matrix3D.rawData` property to create a custom projection
		matrix. There is no built-in Matrix3D method for creating a projection Matrix3D
		object.
		@param	v	The Vector3D object that is projected to a new space coordinate.
		@returns	A new Vector3D with a transformed space coordinate.
	**/
	public static function projectVector(m:Matrix3D, v:Vector3D):Vector3D
	{
		var n = m.rawData;
		var l_oProj = new Vector3D();

		l_oProj.x = v.x * n[0] + v.y * n[4] + v.z * n[8] + n[12];
		l_oProj.y = v.x * n[1] + v.y * n[5] + v.z * n[9] + n[13];
		l_oProj.z = v.x * n[2] + v.y * n[6] + v.z * n[10] + n[14];
		var w:Float = v.x * n[3] + v.y * n[7] + v.z * n[11] + n[15];

		l_oProj.z /= w;
		l_oProj.x /= w;
		l_oProj.y /= w;

		return l_oProj;
	}

	/**
		Using a projection Matrix3D object, projects a Vector3D object from one space
		coordinate to another. The `projectVector()` method is like the
		`Matrix3D.transformVector()` method except that the `projectVector()` method
		divides the x, y, and z elements of the original Vector3D object by the
		projection depth value. The depth value is the distance from the eye to the
		Vector3D object in view or eye space. The default value for this distance is the
		value of the z element.

		@param	m	A projection Matrix3D object that implements the projection
		transformation. If a display object has a PerspectiveProjection object, you can
		use the `perspectiveProjection.toMatrix()` method to produce a projection Matrix3D
		object that applies to the children of the display object. For more advance
		projections, use the `matrix3D.rawData` property to create a custom projection
		matrix. There is no built-in Matrix3D method for creating a projection Matrix3D
		object.
		@param	v	The Vector3D object that is projected to a new space coordinate.
		@param output An optional Vector3D object that will be used for the
					  output rather than creating a new Vector3D object
		@returns	A new Vector3D with a transformed space coordinate.
	**/
	public static function projectVectorToOutput(m:Matrix3D, v:Vector3D, output:Vector3D):Vector3D
	{
		var n = m.rawData;
		if (output == null)
		{
			output = new Vector3D();
		}

		output.x = v.x * n[0] + v.y * n[4] + v.z * n[8] + n[12];
		output.y = v.x * n[1] + v.y * n[5] + v.z * n[9] + n[13];
		output.z = v.x * n[2] + v.y * n[6] + v.z * n[10] + n[14];
		var w:Float = v.x * n[3] + v.y * n[7] + v.z * n[11] + n[15];

		output.z /= w;
		output.x /= w;
		output.y /= w;

		return output;
	}

	/**
		Using a projection Matrix3D object, projects a Vector of three-dimensional space
		coordinates (`verts`) to a Vector of two-dimensional space coordinates
		(`projectedVerts`). The projected Vector object should be pre-allocated before it
		is used as a parameter.

		The `projectVectors()` method also sets the t value of the uvt data. You should
		pre-allocate a Vector that can hold the uvts data for each projected Vector set of
		coordinates. Also specify the u and v values of the uvt data. The uvt data is a
		Vector of normalized coordinates used for texture mapping. In UV coordinates,
		(0,0) is the upper left of the bitmap, and (1,1) is the lower right of the bitmap.

		This method can be used in conjunction with the `Graphics.drawTriangles()` method
		and the GraphicsTrianglePath class.

		@param	m	A projection Matrix3D object that implements the projection
		transformation. You can produce a projection Matrix3D object using the
		`Matrix3D.rawData` property.
		@param	verts	A Vector of Floats, where every three Floats represent the x, y,
		and z coordinates of a three-dimensional space, like `Vector3D(x,y,z)`.
		@param	projectedVerts	A vector of Floats, where every two Floats represent a
		projected two-dimensional coordinate, like Point(x,y). You should pre-allocate the
		Vector. The `projectVectors()` method fills the values for each projected point.
		@param	uvts	A vector of Floats, where every three Floats represent the u, v,
		and t elements of the uvt data. The u and v are the texture coordinate for each
		projected point. The t value is the projection depth value, the distance from
		the eye to the Vector3D object in the view or eye space. You should pre-allocate
		the Vector and specify the u and v values. The projectVectors method fills the t
		value for each projected point.
	**/
	public static function projectVectors(m:Matrix3D, verts:Vector<Float>, projectedVerts:Vector<Float>, uvts:Vector<Float>):Void
	{
		if (verts.length % 3 != 0) return;

		var n = m.rawData;
		var x:Float, y:Float, z:Float, w:Float;
		var x1:Float, y1:Float, z1:Float, w1:Float;
		var i = 0;

		while (i < verts.length)
		{
			x = verts[i];
			y = verts[i + 1];
			z = verts[i + 2];
			w = 1;

			x1 = x * n[0] + y * n[4] + z * n[8] + w * n[12];
			y1 = x * n[1] + y * n[5] + z * n[9] + w * n[13];
			z1 = x * n[2] + y * n[6] + z * n[10] + w * n[14];
			w1 = x * n[3] + y * n[7] + z * n[11] + w * n[15];

			projectedVerts.push(x1 / w1);
			projectedVerts.push(y1 / w1);

			uvts[i + 2] = 1 / w1;

			i += 3;
		}
	}
}
