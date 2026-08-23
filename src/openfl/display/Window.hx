package openfl.display;

import openfl.utils._internal.Lib;
import lime.app.Application;
import lime.ui.Window as LimeWindow;
import lime.ui.WindowAttributes;

/**
	The Window class is a Lime Window instance that automatically
	initializes an OpenFL stage for the current window.
**/
@:access(openfl.display.LoaderInfo)
@:access(openfl.display.Stage)
@SuppressWarnings("checkstyle:FieldDocComment")
class Window extends LimeWindow
{
	@:noCompletion private function new(application:Application, attributes:WindowAttributes)
	{
		super(application, attributes);

		#if !macro
		#if commonjs
		if (Reflect.hasField(attributes, "stage"))
		{
			stage = Reflect.field(attributes, "stage");
			stage.window = this;
			Reflect.deleteField(attributes, "stage");
		}
		else
		#end
		stage = new Stage(this, Reflect.hasField(attributes.context, "background") ? attributes.context.background : 0xFFFFFF);

		if (Reflect.hasField(attributes, "parameters"))
		{
			try
			{
				stage.loaderInfo.parameters = attributes.parameters;
			}
			catch (e:Dynamic) {}
		}

		stage.__setLogicalSize(attributes.width, attributes.height);

		if (Reflect.hasField(attributes, "resizable") && !attributes.resizable)
		{
			stage.scaleMode = StageScaleMode.SHOW_ALL;
		}

		application.addModule(stage);
		#else
		stage = Lib.current.stage;
		#end
	}

	override public function close():Void
	{
		super.close();
		if (onClose.canceled)
		{
			return;
		}
		if (stage == null)
		{
			// already closed
			return;
		}

		application.removeModule(stage);

		stage = null;
	}
}
