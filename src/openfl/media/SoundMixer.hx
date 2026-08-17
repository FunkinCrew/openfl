package openfl.media;

/**
	The SoundMixer class contains static properties and methods for global
	sound control in the application. The SoundMixer class controls embedded
	and streaming sounds in the application. it does not control dynamically
	created sounds (that is, sounds generated in response to a Sound object
	dispatching a `sampleData` event).
**/
@:access(openfl.media.SoundChannel)
@:final class SoundMixer
{
	@:noCompletion private static inline var MAX_ACTIVE_CHANNELS:Int = 32;

	/**
		The number of seconds to preload an embedded streaming sound into a
		buffer before it starts to stream. The data in a loaded sound,
		including its buffer time, cannot be accessed by a SWF file that is in
		a different domain unless you implement a cross-domain policy file.
		For more information about security and sound, see the Sound class
		description. The data in a loaded sound, including its buffer time,
		cannot be accessed by code in a file that is in a different domain
		unless you implement a cross-domain policy file. However, in the
		application sandbox in an AIR application, code can access data in
		sound files from any source. For more information about security and
		sound, see the Sound class description.
		The `SoundMixer.bufferTime` property only affects the buffer time for
		embedded streaming sounds in a SWF and is independent of dynamically
		created Sound objects (that is, Sound objects created in
		Haxe code). The value of `SoundMixer.bufferTime` cannot override or
		set the default of the buffer time specified in the SoundLoaderContext
		object that is passed to the `Sound.load()` method.
	**/
	public static var bufferTime:Int;

	/**
		The SoundTransform object that controls global sound properties. A
		SoundTransform object includes properties for setting volume, panning,
		left speaker assignment, and right speaker assignment. The
		SoundTransform object used in this property provides final sound
		settings that are applied to all sounds after any individual sound
		settings are applied.
	**/
	public static var soundTransform(get, set):SoundTransform;

	@:noCompletion private static var __soundChannels:Array<SoundChannel> = new Array();
	@:noCompletion private static var __soundTransform:SoundTransform = #if (mute || mute_sound) new SoundTransform(0) #else new SoundTransform() #end;

	/**
		Determines whether any sounds are not accessible due to security
		restrictions. For example, a sound loaded from a domain other than
		that of the content calling this method is not accessible if the
		server for the sound has no URL policy file that grants access to the
		domain of that domain. The sound can still be loaded and played, but
		low-level operations, such as getting ID3 metadata for the sound,
		cannot be performed on inaccessible sounds.
		For AIR application content in the application security sandbox,
		calling this method always returns `false`. All sounds, including
		those loaded from other domains, are accessible to content in the
		application security sandbox.

		@return The string representation of the boolean.
	**/
	public static function areSoundsInaccessible():Bool
	{
		return false;
	}

	/**
		Stops all sounds currently playing.
		>In Flash Professional, this method does not stop the playhead. Sounds
		set to stream will resume playing as the playhead moves over the
		frames in which they are located.

		When using this property, consider the following security model:

		*  By default, calling the `SoundMixer.stopAll()` method stops only
		sounds in the same security sandbox as the object that is calling the
		method. Any sounds whose playback was not started from the same
		sandbox as the calling object are not stopped.
		* When you load the sound, using the `load()` method of the Sound
		class, you can specify a `context` parameter, which is a
		SoundLoaderContext object. If you set the `checkPolicyFile` property
		of the SoundLoaderContext object to `true`, Flash Player or Adobe AIR
		checks for a cross-domain policy file on the server from which the
		sound is loaded. If the server has a cross-domain policy file, and the
		file permits the domain of the calling content, then the file can stop
		the loaded sound by using the `SoundMixer.stopAll()` method; otherwise
		it cannot.

		However, in Adobe AIR, content in the `application` security sandbox
		(content installed with the AIR application) are not restricted by
		these security limitations.

		For more information related to security, see the Flash Player
		Developer Center Topic: [Security](http://www.adobe.com/go/devnet_security_en).

	**/
	public static function stopAll():Void
	{
		var i = __soundChannels.length;
		while (i > 0)
		{
			i--;
			__soundChannels[i].stop();
		}
	}

	@:noCompletion private static function __registerSoundChannel(soundChannel:SoundChannel):Void
	{
		__soundChannels.push(soundChannel);
	}

	@:noCompletion private static function __unregisterSoundChannel(soundChannel:SoundChannel):Void
	{
		__soundChannels.remove(soundChannel);
	}

	// Get & Set Methods
	@:noCompletion private static function get_soundTransform():SoundTransform
	{
		return __soundTransform;
	}

	#if lime
	@:noCompletion private static function __unregisterSoundChannelByBuffer(buffer:lime.media.AudioBuffer):Void
	{
		var i = __soundChannels.length;
		while (i > 0)
		{
			i--;
			var channel = __soundChannels[i];
			if (channel.__audioSource.buffer == buffer)
			{
				channel.stop();
			}
		}
	}
	#end

	@:noCompletion private static function set_soundTransform(value:SoundTransform):SoundTransform
	{
		__soundTransform = value.clone();

		for (channel in __soundChannels)
		{
			channel.__updateTransform();
		}

		return value;
	}
}
