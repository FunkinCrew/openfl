package;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
#end

@:dox(hide)
@:access(lime.app.Application)
@:access(lime.system.System)
@:access(openfl.display.Stage)
@:access(openfl.events.UncaughtErrorEvents)
#if (static_link || ios || tvos || emscripten)
@:buildXml("<include name=\"Configuration.xml\" />")
#if !emscripten
@:cppFileCode("\nextern \"C\" int zlib_register_prims ();\nextern \"C\" int lime_register_prims ();\n::foreach ndlls::::if (registerStatics)::extern \"C\" int ::nameSafe::_register_prims ();::end::::end::")
#else
@:cppFileCode("\nextern \"C\" int zlib_register_prims ();\n::foreach ndlls::::if (registerStatics)::extern \"C\" int ::nameSafe::_register_prims ();::end::::end::")
#end
#end
class ApplicationMain
{
	#if !macro
	public static function main()
	{
		#if (static_link || ios || tvos || emscripten)
		untyped __cpp__("zlib_register_prims ()");
		#if !emscripten
		untyped __cpp__("lime_register_prims ()");
		#end
		::foreach ndlls::::if (registerStatics)::untyped __cpp__("::nameSafe::_register_prims ()");::end::::end::
		#end

		lime.system.System.__registerEntryPoint("::APP_FILE::", create);

		#if !html5
		create(null);
		#end
	}

	public static function create(config):Void
	{
		::if (WIN_ORIENTATION != "auto")::
		lime.system.System.setHint("ORIENTATIONS", ::if (WIN_ORIENTATION == "portrait")::"Portrait PortraitUpsideDown"::else::"LandscapeLeft LandscapeRight"::end::);
		::end::

		final appMeta:Map<String, String> = [];

		appMeta.set("build", "::meta.buildNumber::");
		appMeta.set("company", "::meta.company::");
		appMeta.set("file", "::APP_FILE::");
		appMeta.set("name", "::meta.title::");
		appMeta.set("packageName", "::meta.packageName::");
		appMeta.set("version", "::meta.version::");

		var app = new openfl.display.Application(appMeta);

		#if !disable_preloader_assets
		ManifestResources.init(config);
		#end

		::foreach windows::
		var attributes:lime.ui.WindowAttributes = {
			allowHighDPI: ::allowHighDPI::,
			alwaysOnTop: ::alwaysOnTop::,
			transparent: ::transparent::,
			borderless: ::borderless::,
			// display: ::display::,
			element: null,
			frameRate: ::fps::,
			#if !web
			fullscreen: ::fullscreen::,
			#end
			height: ::height::,
			hidden: ::hidden::,
			maximized: ::maximized::,
			minimized: ::minimized::,
			parameters: ::parameters::,
			resizable: ::resizable::,
			title: "::title::",
			width: ::width::,
			x: ::x::,
			y: ::y::,
		};

		attributes.context = {
			antialiasing: ::antialiasing::,
			background: ::background::,
			colorDepth: ::colorDepth::,
			depth: ::depthBuffer::,
			hardware: ::hardware::,
			stencil: ::stencilBuffer::,
			type: null,
			vsync: ::vsync::
		};

		if (app.window == null)
		{
			if (config != null)
			{
				for (field in Reflect.fields(config))
				{
					if (Reflect.hasField(attributes, field))
					{
						Reflect.setField(attributes, field, Reflect.field(config, field));
					}
					else if (Reflect.hasField(attributes.context, field))
					{
						Reflect.setField(attributes.context, field, Reflect.field(config, field));
					}
				}
			}

			#if sys
			lime.system.System.__parseArguments(attributes);
			#end
		}

		app.createWindow(attributes);
		::end::

		var preloader = getPreloader();
		app.preloader.onProgress.add (function(loaded, total)
		{
			@:privateAccess preloader.update(loaded, total);
		});
		app.preloader.onComplete.add(function()
		{
			@:privateAccess preloader.start();
		});

		preloader.onComplete.add(start.bind((cast app.window:openfl.display.Window).stage));

		#if !disable_preloader_assets
		for (library in ManifestResources.preloadLibraries)
		{
			app.preloader.addLibrary(library);
		}

		for (name in ManifestResources.preloadLibraryNames)
		{
			app.preloader.addLibraryName(name);
		}
		#end

		app.preloader.load();

		var result = app.exec();

		#if (sys && !ios && !emscripten && !nodejs)
		lime.system.System.exit(result);
		#end
	}

	public static function start(stage:openfl.display.Stage):Void
	{
		if (stage.__uncaughtErrorEvents.__enabled)
		{
			try
			{
				ApplicationMain.getEntryPoint();

				stage.dispatchEvent(new openfl.events.Event(openfl.events.Event.RESIZE, false, false));

				if (stage.window.fullscreen)
				{
					stage.dispatchEvent(new openfl.events.FullScreenEvent(openfl.events.FullScreenEvent.FULL_SCREEN, false, false, true, true));
				}
			}
			catch (e:Dynamic)
			{
				#if !display
				stage.__handleError(e);
				#end
			}
		}
		else
		{
			ApplicationMain.getEntryPoint();

			stage.dispatchEvent(new openfl.events.Event(openfl.events.Event.RESIZE, false, false));

			if (stage.window.fullscreen)
			{
				stage.dispatchEvent(new openfl.events.FullScreenEvent(openfl.events.FullScreenEvent.FULL_SCREEN, false, false, true, true));
			}
		}
	}
	#end

	macro public static function getEntryPoint()
	{
		var hasMain = false;

		switch (Context.follow(Context.getType("::APP_MAIN::")))
		{
			case TInst(t, params):

				var type = t.get();
				for (method in type.statics.get())
				{
					if (method.name == "main")
					{
						hasMain = true;
						break;
					}
				}

				if (hasMain)
				{
					return Context.parse("@:privateAccess ::APP_MAIN::.main()", Context.currentPos());
				}
				else if (type.constructor != null)
				{
					return macro
					{
						var current = stage.getChildAt (0);

						if (current == null || !(current is openfl.display.DisplayObjectContainer))
						{
							current = new openfl.display.MovieClip();
							stage.addChild(current);
						}

						//this define is for internal use only
						//note: it may be removed abruptly in the future
						#if !no_openfl_entry_point
						new DocumentClass(cast current);
						#end
					};
				}
				else
				{
					Context.fatalError("Main class \"::APP_MAIN::\" has neither a static main nor a constructor.", Context.currentPos());
				}

			default:

				Context.fatalError("Main class \"::APP_MAIN::\" isn't a class.", Context.currentPos());
		}

		return null;
	}

	macro public static function getPreloader()
	{
		::if (PRELOADER_NAME != "")::
		var type = Context.getType("::PRELOADER_NAME::");

		switch (type)
		{
			case TInst(classType, _):

				var searchTypes = classType.get();

				while (searchTypes != null)
				{
					if (searchTypes.pack.length == 2 && searchTypes.pack[0] == "openfl" && searchTypes.pack[1] == "display" && searchTypes.name == "Preloader")
					{
						return macro
						{
							new ::PRELOADER_NAME::();
						};
					}

					if (searchTypes.superClass != null)
					{
						searchTypes = searchTypes.superClass.t.get();
					}
					else
					{
						searchTypes = null;
					}
				}

			default:
		}

		return macro
		{
			new openfl.display.Preloader(new ::PRELOADER_NAME::());
		}
		::else::
		return macro
		{
			new openfl.display.Preloader(new openfl.display.Preloader.DefaultPreloader());
		};
		::end::
	}

	#if !macro
	@:noCompletion @:dox(hide) public static function __init__()
	{
		var init = lime.app.Application;
	}
	#end
}

#if !macro
@:build(DocumentClass.build())
@:keep @:dox(hide) class DocumentClass extends ::APP_MAIN:: {}
#else
class DocumentClass
{
	macro public static function build():Array<Field>
	{
		var classType = Context.getLocalClass().get();
		var searchTypes = classType;

		while (searchTypes != null)
		{
			if (searchTypes.module == "openfl.display.DisplayObject")
			{
				var fields = Context.getBuildFields();

				var method = macro
				{
					current.addChild(this);
					super();
					dispatchEvent(new openfl.events.Event(openfl.events.Event.ADDED_TO_STAGE, false, false));
				}

				fields.push({ name: "new", access: [ APublic ], kind: FFun({ args: [ { name: "current", opt: false, type: macro :openfl.display.DisplayObjectContainer, value: null } ], expr: method, params: [], ret: macro :Void }), pos: Context.currentPos() });

				return fields;
			}

			if (searchTypes.superClass != null)
			{
				searchTypes = searchTypes.superClass.t.get();
			}
			else
			{
				searchTypes = null;
			}
		}

		return null;
	}
}
#end
