# astc-compressor

![](https://img.shields.io/github/repo-size/KarimAkra/astc-compressor) ![](https://badgen.net/github/open-issues/KarimAkra/astc-compressor) ![](https://badgen.net/badge/license/MIT/green)

A Haxe runner for compressing image files as ASTC textures using [ASTC-Encoder](https://github.com/ARM-software/astc-encoder).

### Installation

You can install it through `Haxelib`
```bash
haxelib install astc-compressor
```
Or through `Git`, if you want the latest updates
```bash
haxelib git astc-compressor https://github.com/KarimAkra/astc-compressor.git
```

### Commands

#### `compress`

```bash
haxelib run astc-compressor compress -i ./textures -blocksize 6x6 -quality medium -colorprofile cl -o ./output
```

> Compresses images in the specified file or directory using ASTC with the given settings.

**Options:**
- `-i <input>`: Path to image file or folder.
- `-blocksize <WxH>`: Block size (e.g. 4x4, 6x6, 8x8).
- `-quality <level>`: Compression quality: `fastest`, `fast`, `medium`, `thorough`, `exhaustive`.
- `-colorprofile <cl|cs|ch|cH>`: ASTC color profile mode.
- `-o <output>`: (Optional) Output directory for `.astc` files.
- `-excludes <file>`: (Optional) File with list of input paths to skip.
- `-clean`: (Optional) Clean output directory before compressing.

---

#### `rebuild`

```bash
haxelib run astc-compressor rebuild
```

> Rebuilds the Haxe runner (useful if native binaries or dependencies change).

---

#### `help`

```bash
haxelib run astc-compressor help
```

> Displays help text with command usage, options, and examples.

### Licensing

**astc-compressor** is made available under the **MIT License**. See [LICENSE](./LICENSE) for details.

This project includes prebuilt `astcenc` binaries from the [ASTC Encoder project](https://github.com/ARM-software/astc-encoder), which is licensed under the **Apache License 2.0**.

The binaries are included inside the [plugins](./plugins) folder.

See [plugins/LICENSE-ARM.txt](./plugins/LICENSE-ARM.txt) for a copy of the ASTC Encoder license.
