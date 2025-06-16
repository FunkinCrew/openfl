package openfl.sensors;

#if !flash
import haxe.Timer;
import openfl.errors.ArgumentError;
import openfl.events.DeviceRotationEvent;
import openfl.events.EventDispatcher;
#if lime
import lime.system.Sensor;
import lime.system.SensorType;
#end

/**
	The DeviceRotation class dispatches events based on activity detected by the
	device's accelerometer, gyroscope sensors. This data represents the device's
	roll, pitch, yaw and quaternions. When the device rotates, the sensors
	detect this rotation and return this data. The DeviceRotation class provides
	methods to query whether or not device rotation event handling is supported,
	and also to set the rate at which device rotation events are dispatched.

	Note: Use the `DeviceRotation.isSupported` property to test the runtime
	environment for the ability to use this feature. While the DeviceRotation
	class and its members are accessible for multiple runtime platforms an
	devices, this does not imply that the handler is always supported at
	runtime. There are a few cases such as Android version etc where this
	handler is not supported, so you must check the support of this handler by
	using `DeviceRotation.isSupported` property. If
	`DeviceRotation.isSupported` is `true` at runtime, then DeviceRotation
	support currently exists.

	_OpenFL target support:_ Not currently supported, except when targeting AIR.

	_Adobe AIR profile support:_ This feature is supported only on mobile
	devices. It is not supported on desktop or AIR for TV devices. See
	[AIR Profile Support](https://help.adobe.com/en_US/air/build/WS144092a96ffef7cc16ddeea2126bb46b82f-8000.html)
	for more information regarding API support across multiple profiles.
**/
class DeviceRotation extends EventDispatcher
{
	/**
		The isSupported property is set to `true` if the
		gyroscope sensors are available on the device, otherwise it is set to
		`false`.
	**/
	public static var isSupported(get, never):Bool;

	@:noCompletion private static var defaultInterval:Int = 34;
	@:noCompletion private static var currentPitch:Float = 0.0;
	@:noCompletion private static var currentRoll:Float = 0.0;
	@:noCompletion private static var currentYaw:Float = 0.0;

	@:noCompletion private static var initialized:Bool = false;
	@:noCompletion private static var supported:Bool = false;

	/**
		Specifies whether the user has denied access to the Device Rotation data
		(`true`) or allowed access (`false`). When this value changes, a
		`status` event is dispatched.
	**/
	public var muted(get, set):Bool;

	@:noCompletion private var __interval:Int;
	@:noCompletion private var __muted:Bool;
	@:noCompletion private var __timer:Timer;

	#if openfljs
	@:noCompletion private static function __init__()
	{
		untyped Object.defineProperty(DeviceRotation.prototype, "muted", {
			get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_muted (); }"),
			set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_muted (v); }")
		});
		untyped Object.defineProperty(DeviceRotation, "isSupported", {
			get: function()
			{
				return DeviceRotation.get_isSupported();
			}
		});
	}
	#end

	/**
		Creates a new DeviceRotation instance.
	**/
	public function new()
	{
		super();

		initialize();

		__interval = 0;
		__muted = false;

		setRequestedUpdateInterval(defaultInterval);
	}

	override public function addEventListener(type:String, listener:Dynamic->Void, useCapture:Bool = false, priority:Int = 0,
			useWeakReference:Bool = false):Void
	{
		super.addEventListener(type, listener, useCapture, priority, useWeakReference);
		update();
	}

	@:noCompletion private static function initialize():Void
	{
		if (!initialized)
		{
			#if lime
			var sensors = Sensor.getSensors(SensorType.GYROSCOPE);

			if (sensors.length > 0)
			{
				sensors[0].onUpdate.add(gyroscope_onUpdate);
				supported = true;
			}
			#end

			initialized = true;
		}
	}

	/**
		The `setRequestedUpdateInterval` method is used to set the
		desired time interval for updates. The time interval is measured in
		milliseconds. The update interval is only used as a hint to conserve the
		battery power. The actual time between acceleration updates may be greater
		or lesser than this value. Any change in the update interval affects all
		registered listeners. You can use the DeviceRotation class without calling
		the `setRequestedUpdateInterval()` method. In this case, the
		application receives updates based on the device's default interval.

		@param interval The requested update interval. If `interval` is
						set to 0, then the minimum supported update interval is
						used.
		@throws ArgumentError The specified `interval` is less than
							  zero.
	**/
	public function setRequestedUpdateInterval(interval:Int):Void
	{
		__interval = interval;

		if (__interval < 0)
		{
			throw new ArgumentError();
		}
		else if (__interval == 0)
		{
			__interval = defaultInterval;
		}

		if (__timer != null)
		{
			__timer.stop();
			__timer = null;
		}

		if (supported && !muted)
		{
			__timer = new Timer(__interval);
			__timer.run = update;
		}
	}

	@:noCompletion private function update():Void
	{
		var event = new DeviceRotationEvent(DeviceRotationEvent.UPDATE);

		event.timestamp = Timer.stamp();
		event.pitch = currentPitch;
		event.roll = currentRoll;
		event.yaw = currentYaw;

		dispatchEvent(event);
	}

	@:noCompletion private static function gyroscope_onUpdate(x:Float, y:Float, z:Float):Void
	{
		currentPitch = x;
		currentRoll = y;
		currentYaw = z;
	}

	// Getters & Setters
	private static function get_isSupported():Bool
	{
		initialize();
		return supported;
	}

	@:noCompletion private function get_muted():Bool
	{
		return __muted;
	}

	@:noCompletion private function set_muted(value:Bool):Bool
	{
		__muted = value;
		setRequestedUpdateInterval(__interval);

		return value;
	}
}
#else
#if air
typedef DeviceRotation = flash.sensors.DeviceRotation;
#end
#end
