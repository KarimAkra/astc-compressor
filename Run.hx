package;

import compressor.Progress;
import compressor.util.ANSIUtil;
import compressor.util.CPUUtil;
import compressor.util.FileUtil;
import compressor.util.ProcessUtil;

import haxe.Json;
import haxe.crypto.Md5;
import haxe.ds.Map;
import haxe.io.Bytes;
import haxe.io.Path;

import sys.FileSystem;
import sys.io.File;

using StringTools;

@:nullSafety
class Run
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
	private static var COMPRESSION_DATA:Null<CompressionData> = null;

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
							compressCommand(colorprofile, input, blocksize, quality, options.get('o'), options.get('excludes'), options.exists('premultiplyAlpha'),
								options.exists('clean'));
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
							compressFromJSONCommand(options.exists('clean'));
						}
						else
						{
							Sys.println(ANSIUtil.apply('Missing required options for compress-from-json command:', [Red]));
							Sys.println(ANSIUtil.apply('  -json <json/file/path> is required', [Yellow]));

							Sys.exit(1);
						}
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
			premultiplyAlpha:Bool, clean:Bool):Void
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

							final supportedExtension:Bool = SUPPORTED_EXTENSIONS.contains(path.ext);

							if (!supportedExtension)
								return false;

							return needsRecompiled(f, outputFile, blockSize, quality, colorprofile, premultiplyAlpha, [])
								&& !isExcluded(path.toString(), excludedFiles);
						}
					}

					return false;
				});

				if (files.length > 0)
				{
					printTitle();

					final progress:Progress = new Progress(0, files.length);

					Sys.println('- ${ANSIUtil.apply('${ANSIUtil.apply('Compressing: (${progress.total} file${progress.total > 1 ? 's' : ''})', [Black, Bold])} colorProfile=${ANSIUtil.apply(colorprofile, [Yellow])} blockSize=${ANSIUtil.apply(blockSize, [Yellow])} quality=${ANSIUtil.apply(quality, [Yellow])}', [White, Bold])}');

					for (file in files)
					{
						compressFile(progress, colorprofile, file, output, blockSize, quality, premultiplyAlpha, []);
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

						compressFile(colorprofile, path.toString(), output, blockSize, quality, premultiplyAlpha, []);
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
	private static function compressFromJSONCommand(clean:Bool):Void
	{
		if (COMPRESSION_DATA == null)
			return;

		var colorprofile:String = COMPRESSION_DATA.colorprofile;
		var input:String = COMPRESSION_DATA.input;
		var blockSize:String = COMPRESSION_DATA.blocksize;
		var quality:String = COMPRESSION_DATA.quality;
		var output:String = COMPRESSION_DATA.output;
		var excludes:Null<Array<String>> = COMPRESSION_DATA.excludes;
		var premultiplyAlpha:Bool = COMPRESSION_DATA.premultiplyAlpha ?? false;
		var extraParams:Array<String> = COMPRESSION_DATA.extraParams ?? [];

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

							final supportedExtension:Bool = SUPPORTED_EXTENSIONS.contains(path.ext);

							if (!supportedExtension)
								return false;

							var shouldRecompile:Bool = true;
							final customDataKey:Null<String> = getCustomDataKey(f);

							if (customDataKey != null && CUSTOM_COMPRESSION_DATA != null)
							{
								var customData:Null<CustomCompressionAsset> = CUSTOM_COMPRESSION_DATA.get(customDataKey);

								@:nullSafety(Off)
								shouldRecompile = needsRecompiled(f, outputFile, customData.blocksize ?? blockSize, customData.quality ?? quality,
									customData.colorprofile ?? colorprofile, customData.premultiplyAlpha ?? premultiplyAlpha,
									customData.extraParams == null ? extraParams : customData.extraParams.concat(extraParams));
							}
							else
							{
								shouldRecompile = needsRecompiled(f, outputFile, blockSize, quality, colorprofile, premultiplyAlpha, extraParams);
							}
							return shouldRecompile && !isExcluded(path.toString(), excludedFiles);
						}
					}

					return false;
				});

				if (files.length > 0)
				{
					printTitle();

					final progress:Progress = new Progress(0, files.length);

					Sys.println('- ${ANSIUtil.apply('${ANSIUtil.apply('Compressing: (${progress.total} file${progress.total > 1 ? 's' : ''})', [Black, Bold])} colorProfile=${ANSIUtil.apply(colorprofile, [Yellow])} blockSize=${ANSIUtil.apply(blockSize, [Yellow])} quality=${ANSIUtil.apply(quality, [Yellow])}', [White, Bold])}');

					for (file in files)
					{
						final customDataKey:Null<String> = getCustomDataKey(file);

						if (customDataKey != null && CUSTOM_COMPRESSION_DATA != null)
						{
							var customData:Null<CustomCompressionAsset> = CUSTOM_COMPRESSION_DATA.get(customDataKey);

							@:nullSafety(Off)
							compressFile(progress, customData.colorprofile ?? colorprofile, file, output, customData.blocksize ?? blockSize,
								customData.quality ?? quality, customData.premultiplyAlpha ?? premultiplyAlpha,
								customData.extraParams == null ? extraParams : customData.extraParams.concat(extraParams), true);
						}
						else
						{
							compressFile(progress, colorprofile, file, output, blockSize, quality, premultiplyAlpha, extraParams, false);
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

	private static function compressFile(?progress:Progress, colorprofile:String, file:String, output:Null<String>, blockSize:String, quality:String,
			premultiplyAlpha:Bool, extraParams:Array<String>, extraLogs:Bool = false):Void
	{
		var outputFile:String = Path.withExtension(file, 'astc');

		if (output != null && output.length > 0)
			outputFile = Path.join([output, outputFile]);

		FileUtil.createDirectory(Path.directory(outputFile));

		if (progress != null)
		{
			progress.current++;

			if (extraLogs)
				Sys.println('  - ${progress.getFormattedProgress()} ${prettyOutputFile(outputFile)} (${ANSIUtil.apply(quality + ' - ' + blockSize, [Green, Bold])})');
			else
				Sys.println('  - ${progress.getFormattedProgress()} ${prettyOutputFile(outputFile)}');
		}
		else
		{
			if (extraLogs)
				Sys.println('  - ${prettyOutputFile(outputFile)} (${ANSIUtil.apply(quality + ' - ' + blockSize, [Green, Bold])})');
			else
				Sys.println('  - ${prettyOutputFile(outputFile)}');
		}

		var args:Array<String> = [];
		args.push('-$colorprofile');
		args.push(file);
		args.push(outputFile);
		args.push(blockSize);
		args.push('-$quality');
		args.push('-silent');
		if (premultiplyAlpha)
			args.push('-pp-premultiply');
		args = args.concat(extraParams);

		ProcessUtil.runCommand(ASTC_ENCODER_PATH, args);

		final hashData = Bytes.ofString(createHash(file, blockSize, quality, colorprofile, premultiplyAlpha, extraParams));
		final output = File.write(Path.withExtension(outputFile, 'hash'), true);
		output.writeInt32(hashData.length);
		output.write(hashData);
		output.close();
	}

	@:noCompletion
	private static function prettyOutputFile(s:String):String
	{
		var outputFile:String = s;

		{
			var split:Array<String> = outputFile.split('/');

			if (split.length > 1)
				outputFile = ANSIUtil.apply('${split.slice(0, split.length - 1).join('/')}/${ANSIUtil.applyModifierToCode(Yellow, 1)}${split[split.length - 1]}',
					[Yellow]);
			else
				outputFile = ANSIUtil.apply(outputFile, [ANSIUtil.applyModifierToCode(Yellow, 1)]);
		}

		return outputFile;
	}

	@:noCompletion
	private static function helpCommand():Void
	{
		Sys.println('- ${ANSIUtil.apply('Usage:', [Cyan, Bold])} ${ANSIUtil.apply('haxelib run astc-compressor', [Yellow])} <command> [options] <dir>');
		Sys.println('');

		Sys.println('- ${ANSIUtil.apply('Commands:', [Cyan, Bold])}');
		Sys.println('  ${ANSIUtil.apply('compress', [Green])}             Compress images in the specified directory or file.');
		Sys.println('  ${ANSIUtil.apply('compress-from-json', [Green])}   Use data from a JSON file to compress images in a specified directory.');
		Sys.println('  ${ANSIUtil.apply('help', [Green])}                 Displays this help message.');
		Sys.println('');

		Sys.println('- ${ANSIUtil.apply('Options for compress:', [Cyan, Bold])}');
		Sys.println('  ${ANSIUtil.apply('-colorprofile <cl|cs|ch|cH>', [Green])}  ASTC color profile mode.');
		Sys.println('  ${ANSIUtil.apply('-i <input>', [Green])}                   Path to a file or folder to compress.');
		Sys.println('  ${ANSIUtil.apply('-blocksize <WxH>', [Green])}             Block size for ASTC compression (e.g., 4x4, 6x6, 8x8).');
		Sys.println('  ${ANSIUtil.apply('-quality <level>', [Green])}             Compression quality level: ${ANSIUtil.apply('fastest', [Magenta])}, ${ANSIUtil.apply('fast', [Magenta])}, ${ANSIUtil.apply('medium', [Magenta])}, ${ANSIUtil.apply('thorough', [Magenta])}, ${ANSIUtil.apply('exhaustive', [Magenta])}');
		Sys.println('  ${ANSIUtil.apply('-o <output>', [Green])}                  (Optional) Output directory for .astc files.');
		Sys.println('  ${ANSIUtil.apply('-excludes <file>', [Green])}             (Optional) File with list of input paths to skip.');
		Sys.println('  ${ANSIUtil.apply('-premultiplyAlpha', [Green])}            (Optional) Enable alpha premultiplying.');
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
				if (file.startsWith(exclusion))
					return true;
			}
			else if (exclusion.endsWith("/*"))
			{
				exclusion = exclusion.substr(0, exclusion.length - 2);
				var fileDirectory = Path.directory(file);

				if (fileDirectory == exclusion)
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
	private static function needsRecompiled(input:String, output:String, blocksize:String, quality:String, colorprofile:String, premultiplyAlpha:Bool,
			extraParams:Array<String>):Bool
	{
		if (!FileSystem.exists(output))
			return true;

		final outputHashFilePath:String = Path.withExtension(output, 'hash');

		if (FileSystem.exists(outputHashFilePath))
		{
			final outputHashFile = File.read(outputHashFilePath);
			final dataLength = outputHashFile.readInt32();

			final outputHash:String = outputHashFile.read(dataLength).toString().trim();
			final inputHash:String = createHash(input, blocksize, quality, colorprofile, premultiplyAlpha, extraParams);
			outputHashFile.close();

			return inputHash != outputHash;
		}

		return true;
	}

	@:noCompletion
	private static function createHash(path:String, blocksize:String, quality:String, colorprofile:String, premultiplyAlpha:Bool,
			extraParams:Array<String>):String
	{
		var astcFormatList:Array<String> = [];
		astcFormatList.push(path);
		astcFormatList.push(blocksize);
		astcFormatList.push(quality);
		astcFormatList.push(colorprofile);
		astcFormatList.push(premultiplyAlpha ? 'true' : 'false');
		astcFormatList = astcFormatList.concat(extraParams);
		var astcFormat:String = astcFormatList.join('//');
		var astcData:Bytes = Bytes.ofString(astcFormat);
		var sourceData:Bytes = File.getBytes(path);
		return '${Md5.make(sourceData).toHex() + Md5.make(astcData).toHex()}'.trim();
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
			CUSTOM_COMPRESSION_DATA = new Map<String, CustomCompressionAsset>();

			for (data in COMPRESSION_DATA.custom)
				CUSTOM_COMPRESSION_DATA.set(data.asset, data);
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

typedef CompressionData =
{
	public var input:String;
	public var output:String;
	public var blocksize:String;
	public var quality:String;
	public var colorprofile:String;
	@:optional public var premultiplyAlpha:Bool;
	@:optional public var extraParams:Array<String>;
	@:optional public var excludes:Array<String>;
	@:optional public var custom:Array<CustomCompressionAsset>;
}

typedef CustomCompressionAsset =
{
	public var asset:String;
	@:optional public var blocksize:String;
	@:optional public var quality:String;
	@:optional public var colorprofile:String;
	@:optional public var premultiplyAlpha:Bool;
	@:optional public var extraParams:Array<String>;
}
