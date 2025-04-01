package openfl.media._internal;
import haxe.Constraints.Function;
import lime.system.BackgroundWorker;

/**
 * ...
 * @author Christopher Speciale
 */
class NativeVideoUtil
{
	
	/**
	 * Delays a callback function for the specified time in seconds.
	 * Accurate to ~2ms assuming timeBeginPeriod(1) is active.
	 */
	public static function delay(callback:Function, seconds:Float):Void {
			var worker = new BackgroundWorker();
			worker.onComplete.add(__onComplete);

			
		var workerObj:WorkerObject = {
			delay_worker: worker,
			delay_callback: callback,
			delay_seconds: seconds
		};
		
		worker.doWork.add(__backgroundWork);
		worker.run(workerObj);
	}

	private static function __onComplete(callback:Function):Void {
		callback();
	}

	private static function __backgroundWork(obj:WorkerObject):Void {
		usleep(obj.delay_seconds);
		obj.sendComplete(obj.delay_callback);
	}
	
	/**
	 * Sleeps for the specified time in seconds.
	 * Accurate to ~2ms assuming timeBeginPeriod(1) is active.
	 */
	public static function usleep(seconds:Float):Void
	{
		if (seconds <= 0) return;

		var target = Sys.time() + seconds;

		if (seconds >= 0.002)
		{
			Sys.sleep(seconds - 0.001);
		}

		while (Sys.time() < target)
		{
			Sys.sleep(0);
		}
	}
}

@:noCompletion private typedef WorkerObject =
	{
		delay_worker:BackgroundWorker,
		delay_callback:Function,
		delay_seconds:Float;
	}