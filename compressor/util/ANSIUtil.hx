package compressor.util;

using StringTools;

/**
 * Enum abstract representing ANSI codes for text colors, background colors, and text styles.
 */
@:forward
enum abstract ANSICode(String) from String to String
{
	var Reset = '\x1b[0m';
	var Bold = '\x1b[1m';
	var Dim = '\x1b[2m';
	var Underline = '\x1b[4m';
	var Blink = '\x1b[5m';
	var Inverse = '\x1b[7m';
	var Hidden = '\x1b[8m';
	var Strikethrough = '\x1b[9m';

	var Black = '\x1b[30m';
	var Red = '\x1b[31m';
	var Green = '\x1b[32m';
	var Yellow = '\x1b[33m';
	var Blue = '\x1b[34m';
	var Magenta = '\x1b[35m';
	var Cyan = '\x1b[36m';
	var White = '\x1b[37m';

	var BgBlack = '\x1b[40m';
	var BgRed = '\x1b[41m';
	var BgGreen = '\x1b[42m';
	var BgYellow = '\x1b[43m';
	var BgBlue = '\x1b[44m';
	var BgMagenta = '\x1b[45m';
	var BgCyan = '\x1b[46m';
	var BgWhite = '\x1b[47m';

	var BrightBlack = '\x1b[90m';
	var BrightRed = '\x1b[91m';
	var BrightGreen = '\x1b[92m';
	var BrightYellow = '\x1b[93m';
	var BrightBlue = '\x1b[94m';
	var BrightMagenta = '\x1b[95m';
	var BrightCyan = '\x1b[96m';
	var BrightWhite = '\x1b[97m';

	var BgBrightBlack = '\x1b[100m';
	var BgBrightRed = '\x1b[101m';
	var BgBrightGreen = '\x1b[102m';
	var BgBrightYellow = '\x1b[103m';
	var BgBrightBlue = '\x1b[104m';
	var BgBrightMagenta = '\x1b[105m';
	var BgBrightCyan = '\x1b[106m';
	var BgBrightWhite = '\x1b[107m';
}

/**
 * Utility class for applying ANSI codes to strings for terminal output.
 */
@:nullSafety
class ANSIUtil
{
	@:noCompletion
	private static final REGEX_TEAMCITY_VERSION:EReg = ~/^9\.(0*[1-9]\d*)\.|\d{2,}\./;

	@:noCompletion
	private static final REGEX_TERM_256:EReg = ~/(?i)-256(color)?$/;

	@:noCompletion
	private static final REGEX_TERM_TYPES:EReg = ~/(?i)^screen|^xterm|^vt100|^vt220|^rxvt|color|ansi|cygwin|linux/;

	@:noCompletion
	private static final REGEX_ANSI_CODES:EReg = ~/\x1b\[[0-9;]*m/g;

	@:noCompletion
	private static var codesSupported:Null<Bool> = null;

	/**
	 * Applies the specified ANSI codes to the input string.
	 * 
	 * You can pass one or multiple ANSI codes for combining styles.
	 * 
	 * @param input The input.
	 * @param codes The ANSI codes to apply.
	 * 
	 * @return The styled string.
	 */
	public static function apply(input:Dynamic, codes:Array<ANSICode>):String
	{
		return stripCodes(codes.join('') + input + ANSICode.Reset);
	}

	/**
	 * Adds a numeric modifier to an ANSI code (e.g., bold, underline).
	 *
	 * @param code Base ANSI code string.
	 * @param m Numeric modifier to apply.
	 * @return ANSI code with the modifier appended.
	 */
	public static function applyModifierToCode(code:ANSICode, m:Int):String
	{
		if (code.endsWith('m'))
			return code.substr(0, code.length - 1) + ';' + m + 'm';

		return code + ';' + m + 'm';
	}

	@:noCompletion
	private static function stripCodes(output:String):String
	{
		if (codesSupported == null)
		{
			final term:String = Sys.getEnv('TERM');

			if (term == 'dumb')
				codesSupported = false;
			else
			{
				if (codesSupported != true && term != null)
					codesSupported = REGEX_TERM_256.match(term) || REGEX_TERM_TYPES.match(term);

				if (Sys.getEnv('CI') != null)
				{
					final ciEnvNames:Array<String> = [
						"GITHUB_ACTIONS",
						"GITEA_ACTIONS",
						"TRAVIS",
						"CIRCLECI",
						"APPVEYOR",
						"GITLAB_CI",
						"BUILDKITE",
						"DRONE"
					];

					for (ci in ciEnvNames)
					{
						if (Sys.getEnv(ci) != null)
						{
							codesSupported = true;
							break;
						}
					}

					if (codesSupported != true && Sys.getEnv("CI_NAME") == "codeship")
						codesSupported = true;
				}

				if (codesSupported != true && Sys.getEnv("TEAMCITY_VERSION") != null)
					codesSupported = REGEX_TEAMCITY_VERSION.match(Sys.getEnv("TEAMCITY_VERSION"));

				if (codesSupported != true)
				{
					codesSupported = Sys.getEnv('TERM_PROGRAM') == 'iTerm.app'
						|| Sys.getEnv('TERM_PROGRAM') == 'Apple_Terminal'
						|| Sys.getEnv('COLORTERM') != null
						|| Sys.getEnv('ANSICON') != null
						|| Sys.getEnv('ConEmuANSI') != null
						|| Sys.getEnv('WT_SESSION') != null;
				}
			}
		}

		return codesSupported == true ? output : REGEX_ANSI_CODES.replace(output, '');
	}
}
