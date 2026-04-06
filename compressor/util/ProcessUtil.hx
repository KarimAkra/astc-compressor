package compressor.util;

using StringTools;

/**
 * Utility class for process and command-line operations.
 */
class ProcessUtil
{
	/**
	 * Runs a command with specified arguments and returns the exit code.
	 * 
	 * @param cmd The command to run.
	 * @param args The arguments for the command.
	 * @return The exit code of the command.
	 */
	public static function runCommand(cmd:String, args:Array<String>):Int
	{
		return Sys.command(cmd, args);
	}

	/**
	 * Checks whether a command exists on the system.
	 * This method will return true if the command is found, and false otherwise.
	 * 
	 * @param cmd The command to check for existence.
	 * @return True if the command exists, false otherwise.
	 */
	public static function commandExists(cmd:String):Bool
	{
		var result:Int = 0;

		if (Sys.systemName() == "Windows")
			// For Windows, use 'where' command to check if the command exists
			result = Sys.command("cmd", ["/c", "where", cmd, ">", "NUL", "2>&1"]);
		else
			// For Unix-like systems, use 'command -v' to check if the command exists
			result = Sys.command("/bin/sh", ["-c", "command -v " + cmd + " > /dev/null 2>&1"]);

		return result == 0;
	}
}
