package compressor;

import compressor.util.ANSIUtil;

using StringTools;

/**
 * @see https://github.com/FunkinCrew/hxcpp/blob/funkin/tools/hxcpp/Progress.hx
 */
class Progress
{
	public var current:Int;
	public var total:Int;

	public function new(inCurrent:Int, inTotal:Int)
	{
		current = inCurrent;
		total = inTotal;
	}

	public function getProgress():String
	{
		var percent:Float = current / total;
		var pct:Float = Std.int(percent * 1000) / 10;
		var progress:String = Std.string(pct);

		if (Std.int(pct) == pct)
			progress += ".0";

		return progress + "%";
	}

	public function getFormattedProgress():String
	{
		final format:Array<String> = [];
		format.push(ANSIUtil.apply('[', [Bold]));
		format.push(ANSIUtil.apply(getProgress().lpad(' ', 6), [ANSIUtil.applyModifierToCode(Yellow, 1)]));
		format.push(ANSIUtil.apply(']', [Bold]));
		return format.join('');
	}
}
