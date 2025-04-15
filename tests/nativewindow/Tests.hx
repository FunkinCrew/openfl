import utest.Runner;
import utest.ui.Report;

class Tests
{
	public static function main()
	{
		#if (sys || air)
		var runner = new Runner();
		runner.addCase(new NativeWindowTest());
		Report.create(runner);
		runner.run();
		#else
		lime.system.System.exit(0);
		#end
	}
}
