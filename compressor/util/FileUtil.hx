package compressor.util;

import haxe.io.Path;

import sys.FileSystem;
import sys.io.File;

/**
 * Utility class for file system operations.
 */
class FileUtil
{
	/**
	 * Checks if the given path is a directory.
	 *
	 * Attempts to read the contents of the specified path using `FileSystem.readDirectory`.
	 * If the operation succeeds, the path is considered a directory and the function returns `true`.
	 * If an exception is thrown, the function returns `false`, indicating the path is not a directory.
	 *
	 * @param path The file system path to check.
	 * @return `true` if the path is a directory, `false` otherwise.
	 */
	public static function isDirectory(path:String):Bool
	{
		try
		{
			FileSystem.readDirectory(path);
			return true;
		}
		catch (e:Dynamic) {}

		return false;
	}

	/**
	 * Recursively deletes a file or directory at the given path.
	 * If the path is a directory, all its contents will be deleted.
	 * 
	 * @param path The path to the file or directory to delete.
	 */
	public static function deletePath(path:String):Void
	{
		if (!FileSystem.exists(path))
			return;

		if (FileUtil.isDirectory(path))
		{
			for (file in FileSystem.readDirectory(path))
				deletePath(Path.join([path, file]));

			FileSystem.deleteDirectory(path);
		}
		else
			FileSystem.deleteFile(path);
	}

	/**
	 * Creates a directory and any parent directories at the specified path.
	 * The path is normalized and trailing slashes are removed before creating directories.
	 * 
	 * @param path The path where the directory will be created.
	 */
	public static function createDirectory(path:String):Void
	{
		if (path == null || path.length == 0)
			return;

		path = Path.removeTrailingSlashes(Path.normalize(path));

		var currentPath:String = '';

		for (part in path.split('/'))
		{
			if (part.length == 0)
				continue;

			currentPath += Path.addTrailingSlash(part);

			if (!FileSystem.exists(currentPath))
				FileSystem.createDirectory(currentPath);
		}
	}

	/**
	 * Copies a directory and its contents from the source to the destination path.
	 * Creates the destination directory if it does not exist.
	 * 
	 * @param src The path to the source directory.
	 * @param dest The path to the destination directory.
	 */
	public static function copyDirectory(src:String, dest:String)
	{
		if (!FileSystem.exists(dest))
			createDirectory(dest);

		for (file in FileSystem.readDirectory(src))
		{
			final srcPath:String = Path.join([src, file]);
			final destPath:String = Path.join([dest, file]);

			if (FileUtil.isDirectory(srcPath))
				copyDirectory(srcPath, destPath);
			else
				File.copy(srcPath, destPath);
		}
	}

	/**
	 * Recursively reads the contents of a directory and returns a list of all file paths.
	 * Optionally includes directories in the result.
	 *
	 * @param path The root directory to read.
	 * @param includeDirs Whether to include directories in the result (default: false).
	 * @return An array of file (and optionally directory) paths relative to the input path.
	 */
	public static function readDirectoryRecursive(path:String, includeDirs:Bool = false):Array<String>
	{
		final results:Array<String> = [];

		if (!FileSystem.exists(path) || !FileUtil.isDirectory(path))
			return results;

		readHelper(path, '', results, includeDirs);

		return results;
	}

	@:noCompletion
	private static function readHelper(base:String, subPath:String, results:Array<String>, includeDirs:Bool):Void
	{
		var fullPath:String = Path.join([base, subPath]);
		if (fullPath.length < 1) fullPath = './';

		for (entry in FileSystem.readDirectory(fullPath))
		{
			final relPath = Path.join([subPath, entry]);
			final absPath = Path.join([base, relPath]);

			if (FileUtil.isDirectory(absPath))
			{
				if (includeDirs)
					results.push(relPath);

				readHelper(base, relPath, results, includeDirs);
			}
			else
			{
				results.push(relPath);
			}
		}
	}
}
