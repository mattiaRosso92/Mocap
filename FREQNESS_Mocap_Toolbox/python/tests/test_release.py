"""Shared release versions and the combined MATLAB/Python download contract."""
import importlib.util
from importlib.metadata import version
from pathlib import Path
import zipfile
import pytest
from freqness_mocap import __version__


TOOLBOX = Path(__file__).resolve().parents[2]


def load_packager(path):
    spec = importlib.util.spec_from_file_location('package_release',path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def packager():
    if not (TOOLBOX/'VERSION').is_file():
        pytest.skip('Combined-release tests require the full MATLAB/Python toolbox')
    return load_packager(TOOLBOX/'python/tools/package_release.py')


def test_shared_release_version(packager):
    assert (TOOLBOX/'VERSION').read_text().strip()==__version__
    assert version('freqness-mocap')==__version__
    assert f'v{__version__}' in (TOOLBOX/'python/README.md').read_text()


def test_release_archive(packager,tmp_path):
    output = packager.package(tmp_path/'FREQNESS_Mocap.zip',tag='v'+__version__)
    with zipfile.ZipFile(output) as archive:
        names = archive.namelist()
        assert all(name.startswith('FREQNESS_Mocap/') for name in names)
        for name in ('LICENSE','VERSION','README.md','FREQNESS_Startup_Mocap.m',
                     'FREQNESS_MainPipeline_Mocap.m','FREQNESS_Data/README.md',
                     'python/pyproject.toml','python/FREQNESS_NotebookPipeline.ipynb'):
            assert 'FREQNESS_Mocap/'+name in names
        assert archive.read('FREQNESS_Mocap/VERSION').decode().strip()==__version__
        assert not any(Path(name).suffix in {'.mat','.csv','.png','.pptx','.docx','.pyc'} for name in names)
        assert not any(part.startswith('.') or part in {'Dance_Data','build','dist','__pycache__'}
                       or part.endswith('.egg-info') for name in names for part in Path(name).parts)
        archive.extractall(tmp_path/'extracted')
    # The source download must also support its documented local build command.
    extracted = tmp_path/'extracted/FREQNESS_Mocap'
    rebuilt = load_packager(extracted/'python/tools/package_release.py')
    second = rebuilt.package(tmp_path/'rebuilt.zip',tag='v'+__version__)
    with zipfile.ZipFile(second) as archive:
        assert archive.read('FREQNESS_Mocap/LICENSE')==(extracted/'LICENSE').read_bytes()


def test_release_rejects_wrong_tag_and_overwrite(packager,tmp_path):
    output = tmp_path/'release.zip'
    with pytest.raises(ValueError,match='must match'):
        packager.package(output,tag='v0.0.0-invalid')
    assert not output.exists()
    output.write_bytes(b'preserve this existing file')
    with pytest.raises(FileExistsError):
        packager.package(output,tag='v'+__version__)
    assert output.read_bytes()==b'preserve this existing file'


def test_release_rejects_mismatched_versions(packager,tmp_path,monkeypatch):
    toolbox = tmp_path/'toolbox'
    source = toolbox/'python/src/freqness_mocap'
    source.mkdir(parents=True)
    (toolbox/'VERSION').write_text('1.0.0\n')
    (source/'_version.py').write_text('__version__ = "0.9.0"\n')
    monkeypatch.setattr(packager,'__file__',str(toolbox/'python/tools/package_release.py'))
    with pytest.raises(ValueError,match='must match'):
        packager.package(tmp_path/'mismatched.zip',tag='v1.0.0')
    assert not (tmp_path/'mismatched.zip').exists()
