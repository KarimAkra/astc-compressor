package compressor.util;

import sys.io.Process;

using StringTools;

/**
 * Utility class for CPU-related information such as architecture type and thread count.
 */
class CPUUtil
{
	/**
	 * Returns the number of logical CPU threads available on the system.
	 * 
	 * On Windows, it reads the NUMBER_OF_PROCESSORS environment variable.
	 * On Linux, it tries `nproc` or falls back to parsing `/proc/cpuinfo`.
	 * On macOS, it uses `system_profiler` to extract the core count.
	 * 
	 * @return The number of logical threads (cores) detected.
	 */
	public static function getThreadsAmount():Int
	{
		var threads:Int = 0;

		switch (Sys.systemName())
		{
			case 'Windows':
				final parsedThreads:Null<Int> = Std.parseInt(Sys.getEnv('NUMBER_OF_PROCESSORS'));

				if (parsedThreads != null)
				{
					threads = parsedThreads;
				}
			case 'Linux':
				final process:Process = new Process('nproc');

				final output:Null<String> = process.stdout.readAll().toString().trim();

				process.exitCode();

				final parsedThreads:Null<Int> = Std.parseInt(output);

				if (parsedThreads != null)
				{
					threads = parsedThreads;
				}
				else
				{
					final process:Process = new Process('cat', ['/proc/cpuinfo']);

					final output:Null<String> = process.stdout.readAll().toString();

					process.exitCode();

					if (output != null)
						threads = output.split('processor').length - 1;
				}

			case 'Mac':
				final process:Process = new Process('/usr/sbin/system_profiler', ['-detailLevel', 'full', 'SPHardwareDataType']);

				final output:Null<String> = process.stdout.readAll().toString().trim();

				process.exitCode();

				if (output != null && output.length > 0)
				{
					final totalNummberOfCoresRegex:EReg = ~/Total Number of Cores: (\d+)/;

					if (totalNummberOfCoresRegex.match(output))
					{
						final parsedThreads:Null<Int> = Std.parseInt(totalNummberOfCoresRegex.matched(1));

						if (parsedThreads != null)
						{
							threads = parsedThreads;
						}
					}
				}
		}

		return threads;
	}

	/**
	 * Detects and returns the CPU architecture of the current system.
	 * 
	 * On Windows, it checks the PROCESSOR_ARCHITECTURE environment variable.
	 * On Unix-like systems, it uses `uname -m`.
	 * 
	 * Supported values include: X86, X64, ARM, ARM64. If unrecognized, returns UNKNOWN.
	 * 
	 * @return The detected architecture as an enum value.
	 */
	public static function getArchitecture():Architecture
	{
		var architecture:String = '';

		switch (Sys.systemName())
		{
			case 'Windows':
				architecture = Sys.getEnv('PROCESSOR_ARCHITECTURE');
			case 'Linux' | 'Mac':
				final process:Process = new Process('/usr/bin/uname', ['-m']);

				architecture = process.stdout.readAll().toString().trim();

				process.exitCode();
		}

		switch (architecture.toLowerCase())
		{
			case 'x86', 'i386', 'i486', 'i586', 'i686':
				return Architecture.X86;
			case 'x86_64', 'amd64':
				return Architecture.X64;
			case 'arm', 'armv7l', 'armv7', 'armhf':
				return Architecture.ARM;
			case 'aarch64', 'arm64':
				return Architecture.ARM64;
		}

		return Architecture.UNKNOWN;
	}
}

/**
 * Enum representing supported CPU architectures.
 */
enum Architecture
{
	X86;
	X64;
	ARM;
	ARM64;
	UNKNOWN;
}
