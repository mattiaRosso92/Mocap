"""Build a short-path, source-only MATLAB/Python archive; never publish it."""
import argparse
import ast
from pathlib import Path
import zipfile


def package(output, tag=None):
    toolbox = Path(__file__).resolve().parents[2]
    version = (toolbox/'VERSION').read_text().strip()
    module = ast.parse((toolbox/'python/src/freqness_mocap/_version.py').read_text())
    package_version = next(ast.literal_eval(node.value) for node in module.body if isinstance(node,ast.Assign))
    if version!=package_version or (tag is not None and tag!='v'+version):
        raise ValueError('Toolbox VERSION, Python version and release tag must match')
    output = Path(output)
    output.parent.mkdir(parents=True,exist_ok=True)
    # Explicit source whitelist: no study data, generated figures, caches or symlinks.
    extensions = {'.m','.py','.md','.toml','.txt','.ipynb'}
    excluded = {'__pycache__','.pytest_cache','.venv','build','dist'}
    with zipfile.ZipFile(output,'x',compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(toolbox.rglob('*')):
            relative = path.relative_to(toolbox)
            if path.is_symlink() or not path.is_file() or any(p.startswith('.') or p in excluded or p.endswith('.egg-info') for p in relative.parts):
                continue
            if path.suffix not in extensions and path.name not in {'VERSION','MANIFEST.in'}:
                continue
            archive.write(path,Path('FREQNESS_Mocap')/relative)
        archive.write(toolbox.parent/'LICENSE','FREQNESS_Mocap/LICENSE')
    return output


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag')
    parser.add_argument('--output',required=True)
    args = parser.parse_args()
    print(package(args.output,args.tag))
