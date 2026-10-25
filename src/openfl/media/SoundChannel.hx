package openfl.media;

import lime.media.AudioSource;
import openfl.events.Event;
import openfl.events.EventDispatcher;

/**
	The SoundChannel class controls a sound in an application. Every sound is
	assigned to a sound channel, and the application can have multiple sound
	channels that are mixed together. The SoundChannel class contains a
	`stop()` method, properties for monitoring the amplitude
	(volume) of the channel, and a property for assigning a SoundTransform
	object to the channel.

	@event soundComplete Dispatched when a sound has finished playing.

	@see [Playing sounds](https://books.openfl.org/openfl-developers-guide/working-with-sound/playing-sounds.html)
	@see `openfl.media.Sound`
**/
@:access(openfl.events.Event)
@:access(openfl.media.Sound)
@:access(openfl.media.SoundMixer)
@:final @:keep class SoundChannel extends EventDispatcher
{
	/**
		The current amplitude (volume) of the left channel, from 0 (silent) to 1
		(full amplitude).
	**/
	public var leftPeak(default, null):Float;

	/**
		When the sound is playing, the `position` property indicates in
		milliseconds the current point that is being played in the sound file.
		When the sound is stopped or paused, the `position` property
		indicates the last point that was played in the sound file.

		A common use case is to save the value of the `position`
		property when the sound is stopped. You can resume the sound later by
		restarting it from that saved position.

		If the sound is looped, `position` is reset to 0 at the
		beginning of each loop.
	**/
	public var position(get, set):Float;

	/**
		The current amplitude (volume) of the right channel, from 0 (silent) to 1
		(full amplitude).
	**/
	public var rightPeak(default, null):Float;

	/**
		The SoundTransform object assigned to the sound channel. A SoundTransform
		object includes properties for setting volume, panning, left speaker
		assignment, and right speaker assignment.
	**/
	public var soundTransform(get, set):SoundTransform;

	@:noCompletion private var __sound:Sound;
	@:noCompletion private var __isValid:Bool;
	@:noCompletion private var __soundTransform:SoundTransform;
	@:noCompletion private var __audioSource:AudioSource;

	@:noCompletion private function new(sound:Sound, audioSource:AudioSource = null, soundTransform:SoundTransform = null):Void
	{
		super(this);

		__sound = sound;

		leftPeak = 1;
		rightPeak = 1;

		if (soundTransform != null)
		{
			__soundTransform = soundTransform;
		}
		else
		{
			__soundTransform = new SoundTransform();
		}

		__initAudioSource(audioSource);

		SoundMixer.__registerSoundChannel(this);
	}

	/**
		Stops the sound playing in the channel.

		@see [Playing sounds](https://books.openfl.org/openfl-developers-guide/working-with-sound/playing-sounds.html)
	**/
	public function stop():Void
	{
		SoundMixer.__unregisterSoundChannel(this);

		if (!__isValid) return;

		__audioSource.stop();

		__dispose();
	}

	@:noCompletion private function __dispose():Void
	{
		if (!__isValid) return;

		__audioSource.onComplete.remove(audioSource_onComplete);
		__audioSource.dispose();
		__audioSource = null;

		__isValid = false;
	}

	@:noCompletion private function __updateTransform():Void
	{
		this.soundTransform = soundTransform;
	}

	@:noCompletion private function __initAudioSource(audioSource:AudioSource):Void
	{
		__audioSource = audioSource;
		if (__audioSource == null)
		{
			return;
		}

		__audioSource.onComplete.add(audioSource_onComplete);
		__isValid = true;

		__audioSource.play();
	}

	// Get & Set Methods
	@:noCompletion private function get_position():Float
	{
		if (!__isValid) return 0;

		return __audioSource.currentTime;
	}

	@:noCompletion private function set_position(value:Float):Float
	{
		if (!__isValid) return 0;

		__audioSource.currentTime = value;

		return value;
	}

	@:noCompletion private function get_soundTransform():SoundTransform
	{
		return __soundTransform.clone();
	}

	@:noCompletion private function set_soundTransform(value:SoundTransform):SoundTransform
	{
		if (value != null)
		{
			__soundTransform.pan = value.pan;
			__soundTransform.volume = value.volume;

			if (__isValid)
			{
				__audioSource.gain = SoundMixer.__soundTransform.volume * __soundTransform.volume;
				__audioSource.pan = Math.max(-1, Math.min(1, SoundMixer.__soundTransform.pan + __soundTransform.pan));
			}
		}

		return value;
	}

	// Event Handlers
	@:noCompletion private function audioSource_onComplete():Void
	{
		SoundMixer.__unregisterSoundChannel(this);

		__dispose();

		#if openfl_pool_events
		var soundCompleteEvent = Event.__pool.get();
		soundCompleteEvent.type = Event.SOUND_COMPLETE;
		#else
		var soundCompleteEvent = new Event(Event.SOUND_COMPLETE);
		#end

		dispatchEvent(soundCompleteEvent);

		#if openfl_pool_events
		Event.__pool.release(soundCompleteEvent);
		#end
	}
}
