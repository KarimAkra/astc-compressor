package;

import sys.io.File;

import util.ProcessUtil;

import haxe.Json;
import haxe.io.Path;
import haxe.ds.Map;

import sys.FileSystem;

import util.ANSIUtil;
import util.CPUUtil;
import util.FileUtil;

using StringTools;

@:nullSafety
class Main
{
	@:noCompletion
	private static final VERSION:String = '1.0.0';

	@:noCompletion
	private static final SUPPORTED_EXTENSIONS:Array<String> = ['bmp', 'jpg', 'jpeg', 'jpe', 'jfif', 'png', 'tga', 'hdr', 'exr'];

	@:noCompletion
	private static final COMPRESSION:Array<String> = ['exhaustive', 'verythorough', 'thorough', 'medium', 'fast', 'fastest'];

	@:noCompletion
	private static final COLOR_PROFILES:Array<String> = ['cl', 'cs', 'ch', 'cH'];

	@:noCompletion
	private static var ARCHITECTURE:Architecture = Architecture.UNKNOWN;

	@:noCompletion
	private static var THREADS:Int = 0;

	@:noCompletion
	private static var ASTC_ENCODER_PATH:String = '';

	@:noCompletion
	private static var LIB_PATH:String = '';

	@:noCompletion
	private static var COMPRESSION_DATA:Null<ComppressionData> = null;

	@:noCompletion
	private static var CUSTOM_COMPRESSION_DATA:Null<Map<String, CustomCompressionAsset>> = null;

	public static function main():Void
	{
		ARCHITECTURE = CPUUtil.getArchitecture();
		THREADS = CPUUtil.getThreadsAmount();
		LIB_PATH = Sys.getCwd();

		final args:Array<String> = Sys.args();
		final dir:Null<String> = args.pop();
		final command:Null<String> = args.shift();
		final options:Map<String, String> = [];

		var i:Int = 0;

		while (i < args.length)
		{
			final arg:String = args[i];

			if (arg.startsWith('--'))
			{
				options.set(arg.substr(2), '');
				i += 1;
			}
			if (arg.startsWith('-'))
			{
				if (i + 1 < args.length && !args[i + 1].startsWith('-'))
				{
					options.set(arg.substr(1), args[i + 1]);
					i += 2;
				}
				else
				{
					options.set(arg.substr(1), '');
					i += 1;
				}
			}
			else
			{
				i += 1;
			}
		}

		if (dir != null && dir.length > 0)
		{
			Sys.setCwd(dir);

			if (command != null)
			{
				switch (command)
				{
					case 'compress':
						prepareEncoder();

						final colorprofile:Null<String> = options.get('colorprofile');
						final input:Null<String> = options.get('i');
						final blocksize:Null<String> = options.get('blocksize');
						final quality:Null<String> = options.get('quality');

						final hasColorProfile:Bool = colorprofile != null
							&& colorprofile.length > 0 ? COLOR_PROFILES.contains(colorprofile) : false;
						final hasInput:Bool = input != null && input.length > 0;
						final hasBlocksize:Bool = blocksize != null && ~/^\d+x\d+$/.match(blocksize);
						final hasQuality:Bool = quality != null && quality.length > 0 ? COMPRESSION.contains(quality) : false;

						if (hasColorProfile && hasInput && hasBlocksize && hasQuality)
						{
							@:nullSafety(Off)
							compressCommand(colorprofile, input, blocksize, quality, options.get('o'), options.get('excludes'), options.exists('clean'));
						}
						else
						{
							Sys.println(ANSIUtil.apply('Missing required options for compress command:', [Red]));

							if (!hasColorProfile)
								Sys.println(ANSIUtil.apply('  -colorprofile <cl|cs|ch|cH> is required', [Yellow]));

							if (!hasInput)
								Sys.println(ANSIUtil.apply('  -i <input> is required', [Yellow]));

							if (!hasBlocksize)
								Sys.println(ANSIUtil.apply('  -blocksize <4x4|6x6|8x8> is required', [Yellow]));

							if (!hasQuality)
								Sys.println(ANSIUtil.apply('  -quality <fast|medium|thorough> is required', [Yellow]));

							Sys.exit(1);
						}
					case 'compress-from-json':
						var jsonFile:Null<String> = options.get('json');

						if (jsonFile != null)
						{
							parseCompressionJSON(jsonFile);
							prepareEncoder();
							compressFromJSONCommand();
						}
						else
						{
							Sys.println(ANSIUtil.apply('Missing required options for compress-from-json command:', [Red]));
							Sys.println(ANSIUtil.apply('  -json <json/file/path> is required', [Yellow]));

							Sys.exit(1);
						}
					case 'rebuild':
						printTitle();
						rebuildCommand();
					case 'help':
						printTitle();
						helpCommand();
					default:
						Sys.println(ANSIUtil.apply('Unknown command "$command".', [Red]));
						Sys.exit(1);
				}
			}
			else
			{
				Sys.println(ANSIUtil.apply('No command to run.', [Red]));
				Sys.exit(1);
			}
		}
		else
		{
			Sys.println(ANSIUtil.apply('No dir to run.', [Red]));
			Sys.exit(1);
		}
	}

	@:noCompletion
	private static function printTitle():Void
	{
		Sys.println('');
		Sys.println('==========================');
		Sys.println('=                        =');
		Sys.println('= ${ANSIUtil.apply('ASTC Compressor', [Red, Bold])} v${ANSIUtil.apply(VERSION, [White, Bold])} =');
		Sys.println('=                        =');
		Sys.println('==========================');
		Sys.println('');
	}

	@:noCompletion
	private static function prepareEncoder():Void
	{
		switch (Sys.systemName())
		{
			case 'Windows':
				if (ARCHITECTURE == Architecture.X64)
				{
					ASTC_ENCODER_PATH = Path.join([LIB_PATH, 'plugins/Windows/x64/astcenc-sse2.exe']);
				}
				else if (ARCHITECTURE == Architecture.ARM64)
				{
					ASTC_ENCODER_PATH = Path.join([LIB_PATH, 'plugins/Windows/arm64/astcenc-neon.exe']);
				}

				ASTC_ENCODER_PATH = ASTC_ENCODER_PATH.replace('/', '\\');
			case 'Linux':
				if (ARCHITECTURE == Architecture.X64)
				{
					ASTC_ENCODER_PATH = Path.join([LIB_PATH, 'plugins/Linux/x64/astcenc-sse2']);
				}
				else if (ARCHITECTURE == Architecture.ARM64)
				{
					ASTC_ENCODER_PATH = Path.join([LIB_PATH, 'plugins/Linux/arm64/astcenc-neon']);
				}
			case 'Mac':
				ASTC_ENCODER_PATH = Path.join([LIB_PATH, 'plugins/MacOS/astcenc']);
		}

		if (ASTC_ENCODER_PATH.length <= 0)
		{
			Sys.println(ANSIUtil.apply('Could not determine ASTC encoder path for this platform/architecture.', [Red]));
			Sys.exit(1);
		}
		else if (!FileSystem.exists(ASTC_ENCODER_PATH))
		{
			Sys.println(ANSIUtil.apply('Could not find ASTC encoder at: "$ASTC_ENCODER_PATH".', [Red]));
			Sys.exit(1);
		}
		else if (FileSystem.exists(ASTC_ENCODER_PATH))
		{
			if (Sys.systemName() == 'Linux' || Sys.systemName() == 'Mac')
				ProcessUtil.runCommand('chmod', ['+x', ASTC_ENCODER_PATH]);
		}
	}

	@:noCompletion
	private static function compressCommand(colorprofile:String, input:String, blockSize:String, quality:String, ?output:String, ?excludes:String,
			?clean:Bool):Void
	{
		if (clean && (output != null && output.length > 0 && FileSystem.exists(output) && FileUtil.isDirectory(output)))
			FileUtil.deletePath(output);

		final excludedFiles:Array<String> = [];

		if (excludes != null && FileSystem.exists(excludes) && !FileUtil.isDirectory(excludes))
		{
			final fileList:Array<String> = File.getContent(excludes).split('\n');

			for (i in 0...fileList.length)
				excludedFiles[i] = fileList[i].trim();
		}

		if (FileSystem.exists(input))
		{
			if (FileUtil.isDirectory(input))
			{
				var files:Array<String> = FileUtil.readDirectoryRecursive(input);

				for (i in 0...files.length)
					files[i] = Path.join([input, files[i]]);

				files = files.filter(function(f:String):Bool
				{
					if (f != null && f.length > 0)
					{
						final path:Path = new Path(f);

						if (path.ext != null && path.ext.length > 0)
						{
							var outputFile:String = Path.withExtension(path.toString(), 'astc');

							if (output != null && output.length > 0)
								outputFile = Path.join([output, outputFile]);

							final doesOutputedExist:Bool = FileSystem.exists(outputFile);
							final supportedExtension:Bool = SUPPORTED_EXTENSIONS.contains(path.ext);
							final excluded:Bool = isExcluded(path.toString(), excludedFiles);

							return !doesOutputedExist && supportedExtension && !excluded;
						}
					}

					return false;
				});

				if (files.length > 0)
				{
					printTitle();

					Sys.println('- ${ANSIUtil.apply('${ANSIUtil.apply('Compressing:', [Black, Bold])} colorProfile=${ANSIUtil.apply(colorprofile, [Yellow])} blockSize=${ANSIUtil.apply(blockSize, [Yellow])} quality=${ANSIUtil.apply(quality, [Yellow])}', [White, Bold])}');

					for (file in files)
					{
						compressFile(colorprofile, file, output, blockSize, quality);
					}
				}
			}
			else
			{
				printTitle();

				final path:Path = new Path(input);

				if (path.ext != null && path.ext.length > 0)
				{
					if (SUPPORTED_EXTENSIONS.contains(path.ext))
					{
						Sys.println('- ${ANSIUtil.apply('${ANSIUtil.apply('Compressing:', [Black, Bold])} colorProfile=${ANSIUtil.apply(colorprofile, [Yellow])} blockSize=${ANSIUtil.apply(blockSize, [Yellow])} quality=${ANSIUtil.apply(quality, [Yellow])}', [White, Bold])}');

						compressFile(colorprofile, path.toString(), output, blockSize, quality);
					}
					else
					{
						Sys.println('Unsupported file extension for input: "$input"');
						Sys.exit(1);
					}
				}
				else
				{
					Sys.println('No extension for input: "$input"');
					Sys.exit(1);
				}
			}
		}
		else
		{
			Sys.println(ANSIUtil.apply('Input doesnt exist.', [Red]));
			Sys.exit(1);
		}
	}

	@:noCompletion
	private static function compressFromJSONCommand():Void
	{
		if (COMPRESSION_DATA == null)
			return;

		var colorprofile:String = COMPRESSION_DATA.colorprofile;
		var input:String = COMPRESSION_DATA.input;
		var blockSize:String = COMPRESSION_DATA.blocksize;
		var quality:String = COMPRESSION_DATA.quality;
		var output:String = COMPRESSION_DATA.output;
		var excludes:Null<Array<String>> = COMPRESSION_DATA.excludes;
		var clean:Null<Bool> = COMPRESSION_DATA.clean ?? false;

		if (clean && (output != null && output.length > 0 && FileSystem.exists(output) && FileUtil.isDirectory(output)))
			FileUtil.deletePath(output);

		final excludedFiles:Array<String> = [];

		if (excludes != null)
		{
			for (i in 0...excludes.length)
				excludedFiles[i] = excludes[i].trim();
		}

		if (FileSystem.exists(input))
		{
			if (FileUtil.isDirectory(input))
			{
				var files:Array<String> = FileUtil.readDirectoryRecursive(input);

				for (i in 0...files.length)
					files[i] = Path.join([input, files[i]]);

				files = files.filter(function(f:String):Bool
				{
					if (f != null && f.length > 0)
					{
						final path:Path = new Path(f);

						if (path.ext != null && path.ext.length > 0)
						{
							var outputFile:String = Path.withExtension(path.toString(), 'astc');

							if (output != null && output.length > 0)
								outputFile = Path.join([output, outputFile]);

							final doesOutputedExist:Bool = FileSystem.exists(outputFile);
							final supportedExtension:Bool = SUPPORTED_EXTENSIONS.contains(path.ext);
							final excluded:Bool = isExcluded(path.toString(), excludedFiles);

							return !doesOutputedExist && supportedExtension && !excluded;
						}
					}

					return false;
				});

				if (files.length > 0)
				{
					printTitle();

					Sys.println('- ${ANSIUtil.apply('${ANSIUtil.apply('Compressing:', [Black, Bold])} colorProfile=${ANSIUtil.apply(colorprofile, [Yellow])} blockSize=${ANSIUtil.apply(blockSize, [Yellow])} quality=${ANSIUtil.apply(quality, [Yellow])}', [White, Bold])}');

					for (file in files)
					{
						var customDataKey:Null<String> = getCustomDataKey(file);

						if (customDataKey != null && CUSTOM_COMPRESSION_DATA != null)
						{
							var customData:Null<CustomCompressionAsset> = CUSTOM_COMPRESSION_DATA.get(customDataKey);
							@:nullSafety(Off)
							compressFile(customData.colorprofile ?? colorprofile, file, output, customData.blocksize ?? blockSize,
								customData.quality ?? quality, true);
						}
						else
						{
							compressFile(colorprofile, file, output, blockSize, quality, false);
						}
					}
				}
			}
			else
			{
				Sys.println(ANSIUtil.apply('Input is not a directory. Json compression only works on directories..', [Red]));
				Sys.exit(1);
			}
		}
		else
		{
			Sys.println(ANSIUtil.apply('Input doesnt exist.', [Red]));
			Sys.exit(1);
		}
	}

	private static function compressFile(colorprofile:String, file:String, output:Null<String>, blockSize:String, quality:String, extraLogs:Bool = false):Void
	{
		var outputFile:String = Path.withExtension(file, 'astc');

		if (output != null && output.length > 0)
			outputFile = Path.join([output, outputFile]);

		if (FileSystem.exists(outputFile))
			return;

		FileUtil.createDirectory(Path.directory(outputFile));

		if (extraLogs)
			Sys.println('  - ${ANSIUtil.apply(file, [Black, Bold])} as ${ANSIUtil.apply(outputFile, [Yellow])} (${ANSIUtil.apply(quality + ' - ' + blockSize, [Green, Bold])})');
		else
			Sys.println('  - ${ANSIUtil.apply(file, [Black, Bold])} as ${ANSIUtil.apply(outputFile, [Yellow])}');

		ProcessUtil.runCommand(ASTC_ENCODER_PATH, ['-$colorprofile', file, outputFile, blockSize, '-$quality', '-silent']);
	}

	@:noCompletion
	private static function rebuildCommand():Void
	{
		final oldCwd:String = Sys.getCwd();

		Sys.setCwd(LIB_PATH);

		final result:Int = ProcessUtil.runCommand('haxe', ['build.hxml']);

		Sys.setCwd(oldCwd);

		if (result != 0)
		{
			Sys.println(ANSIUtil.apply('Failed to rebuild.', [Red]));
			Sys.exit(result);
		}
		else
			Sys.println(ANSIUtil.apply('Successfully rebuilt "astc-compressor" runner.', [Green]));
	}

	@:noCompletion
	private static function helpCommand():Void
	{
		Sys.println('- ${ANSIUtil.apply('Usage:', [Cyan, Bold])} ${ANSIUtil.apply('haxelib run astc-compressor', [Yellow])} <command> [options] <dir>');
		Sys.println('');

		Sys.println('- ${ANSIUtil.apply('Commands:', [Cyan, Bold])}');
		Sys.println('  ${ANSIUtil.apply('compress', [Green])}             Compress images in the specified directory or file.');
		Sys.println('  ${ANSIUtil.apply('compress-from-json', [Green])}   Use data from a JSON file to compress images in a specified directory.');
		Sys.println('  ${ANSIUtil.apply('rebuild', [Green])}              Rebuilds the Haxe runner.');
		Sys.println('  ${ANSIUtil.apply('help', [Green])}                 Displays this help message.');
		Sys.println('');

		Sys.println('- ${ANSIUtil.apply('Options for compress:', [Cyan, Bold])}');
		Sys.println('  ${ANSIUtil.apply('-colorprofile <cl|cs|ch|cH>', [Green])}  ASTC color profile mode.');
		Sys.println('  ${ANSIUtil.apply('-i <input>', [Green])}                   Path to a file or folder to compress.');
		Sys.println('  ${ANSIUtil.apply('-blocksize <WxH>', [Green])}             Block size for ASTC compression (e.g., 4x4, 6x6, 8x8).');
		Sys.println('  ${ANSIUtil.apply('-quality <level>', [Green])}             Compression quality level: ${ANSIUtil.apply('fastest', [Magenta])}, ${ANSIUtil.apply('fast', [Magenta])}, ${ANSIUtil.apply('medium', [Magenta])}, ${ANSIUtil.apply('thorough', [Magenta])}, ${ANSIUtil.apply('exhaustive', [Magenta])}');
		Sys.println('  ${ANSIUtil.apply('-o <output>', [Green])}                  (Optional) Output directory for .astc files.');
		Sys.println('  ${ANSIUtil.apply('-excludes <file>', [Green])}             (Optional) File with list of input paths to skip.');
		Sys.println('  ${ANSIUtil.apply('-clean', [Green])}                       (Optional) Clean output directory before compressing.');
		Sys.println('');

		Sys.println('- ${ANSIUtil.apply('Examples:', [Cyan, Bold])}');
		Sys.println('  ${ANSIUtil.apply('haxelib run astc-compressor compress -i ./textures -blocksize 4x4 -quality medium -colorprofile cl -o ./output', [White])}');
		Sys.println('  ${ANSIUtil.apply('haxelib run astc-compressor compress -i ./image.png -blocksize 8x8 -quality thorough -colorprofile cs -o ./output -clean', [White])}');
		Sys.println('  ${ANSIUtil.apply('haxelib run astc-compressor compress -i ./textures -blocksize 6x6 -quality fast -colorprofile cH -excludes ./excludes.txt', [White])}');
		Sys.println('  ${ANSIUtil.apply('haxelib run astc-compressor compress-from-json -json ./compress-data.json', [White])}');
		Sys.println('');

		Sys.println('- ${ANSIUtil.apply('Notes:', [Cyan, Bold])}');
		Sys.println('  - Use ${ANSIUtil.apply('4x4', [Yellow])} block size for best quality; ${ANSIUtil.apply('8x8', [Yellow])} for best performance.');
		Sys.println('  - ASTC color profiles: ${ANSIUtil.apply('cl', [Magenta])} (LDR linear), ${ANSIUtil.apply('cs', [Magenta])} (LDR sRGB), ${ANSIUtil.apply('ch', [Magenta])} (HDR), ${ANSIUtil.apply('cH', [Magenta])} (HDR RGB + LDR A).');
		Sys.println('  - Use relative paths (e.g., ${ANSIUtil.apply('./', [Blue])}) to avoid file access issues.');
		Sys.println('  - The compressor supports BMP, JPG, PNG, TGA, HDR, EXR input formats.');
	}

	@:noCompletion
	private static function isExcluded(file:String, excludes:Array<String>):Bool
	{
		for (exclusion in excludes)
		{
			if (exclusion.endsWith("/"))
			{
				var normalizedFilePath = Path.normalize(file);
				var normalizedExclusion = Path.normalize(exclusion);

				if (normalizedFilePath.startsWith(normalizedExclusion))
				{
					return true;
				}
			}
			else if (exclusion.endsWith("/*"))
			{
				var normalizedExclusion = Path.normalize(exclusion.substr(0, exclusion.length - 2));
				var fileDirectory = Path.directory(Path.normalize(file));

				if (fileDirectory == normalizedExclusion)
				{
					return true;
				}
			}
			else
			{
				if (file == exclusion)
				{
					return true;
				}
			}
		}

		return false;
	}

	@:noCompletion
	private static function parseCompressionJSON(file:String):Void
	{
		if (!FileSystem.exists(file))
		{
			Sys.println(ANSIUtil.apply('JSON file $file doesn\'t seem to exist.', [Red]));
			Sys.exit(1);
		}

		if (!file.endsWith('.json'))
		{
			Sys.println(ANSIUtil.apply('$file is not a JSON file.', [Red]));
			Sys.exit(1);
		}

		COMPRESSION_DATA = cast Json.parse(File.getContent(file));

		final colorprofile:Null<String> = COMPRESSION_DATA.colorprofile;
		final input:Null<String> = COMPRESSION_DATA.input;
		final blocksize:Null<String> = COMPRESSION_DATA.blocksize;
		final quality:Null<String> = COMPRESSION_DATA.quality;

		final hasColorProfile:Bool = colorprofile != null && colorprofile.length > 0 ? COLOR_PROFILES.contains(colorprofile) : false;
		final hasInput:Bool = input != null && input.length > 0;
		final hasBlocksize:Bool = blocksize != null && ~/^\d+x\d+$/.match(blocksize);
		final hasQuality:Bool = quality != null && quality.length > 0 ? COMPRESSION.contains(quality) : false;

		if (!(hasColorProfile && hasInput && hasBlocksize && hasQuality))
		{
			Sys.println(ANSIUtil.apply('Missing required data in JSON for compress-from-json command:', [Red]));

			if (!hasColorProfile)
				Sys.println(ANSIUtil.apply('  "colorprofile" <cl|cs|ch|cH> is required', [Yellow]));

			if (!hasInput)
				Sys.println(ANSIUtil.apply('  "input" is required', [Yellow]));

			if (!hasBlocksize)
				Sys.println(ANSIUtil.apply('  "blocksize" <4x4|6x6|8x8> is required', [Yellow]));

			if (!hasQuality)
				Sys.println(ANSIUtil.apply('  "quality" <fast|medium|thorough> is required', [Yellow]));

			Sys.exit(1);
		}

		if (COMPRESSION_DATA != null && COMPRESSION_DATA.custom != null)
		{
			for (data in COMPRESSION_DATA.custom)
			{
				CUSTOM_COMPRESSION_DATA = new Map<String, CustomCompressionAsset>();

				CUSTOM_COMPRESSION_DATA.set(data.asset, data);
			}
		}
	}

	@:noCompletion
	private static function getCustomDataKey(file:String):Null<String>
	{
		if (CUSTOM_COMPRESSION_DATA == null)
			return null;

		for (asset in CUSTOM_COMPRESSION_DATA.keys())
		{
			if (asset.endsWith("/"))
			{
				var normalizedFilePath = Path.normalize(file);
				var normalizedAsset = Path.normalize(asset.substr(0, asset.length - 2));

				if (normalizedFilePath.startsWith(normalizedAsset))
				{
					return asset;
				}
			}
			else if (asset.endsWith("/*"))
			{
				var normalizedAsset = Path.normalize(asset);
				var fileDirectory = Path.directory(Path.normalize(file));

				if (fileDirectory == normalizedAsset)
				{
					return asset;
				}
			}
			else
			{
				if (file == asset)
				{
					return asset;
				}
			}
		}

		return null;
	}
}

typedef ComppressionData =
{
	public var input:String;
	public var output:String;
	public var blocksize:String;
	public var quality:String;
	public var colorprofile:String;
	@:optional public var clean:Bool;
	@:optional public var excludes:Array<String>;
	@:optional public var custom:Array<CustomCompressionAsset>;
}

typedef CustomCompressionAsset =
{
	public var asset:String;
	@:optional public var blocksize:String;
	@:optional public var quality:String;
	@:optional public var colorprofile:String;
}
