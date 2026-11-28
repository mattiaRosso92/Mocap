"""Publish Block 3's MATLAB figures as an offline HTML gallery (stdlib only).

No analysis or replotting happens here: MATLAB's catalogs supply the spectra,
chronological order, empirical peaks, labels, and original figure paths.
"""
import argparse
from collections import Counter
import csv
import html
import json
import os
from pathlib import Path
from urllib.parse import quote

CSS = """
:root{font-family:system-ui,-apple-system,sans-serif;color:#193049;background:#f4f6f8}
*{box-sizing:border-box}[hidden]{display:none!important}body{max-width:1500px;margin:auto;padding:32px}h1{font-size:32px;margin:10px 0 20px}h2{font-size:22px}p{line-height:1.6}a{color:#28568a}nav,.types,.links{display:flex;gap:10px;flex-wrap:wrap;margin:18px 0}nav a,.types button,.links a,.more{background:white;border:1px solid #d4dce5;border-radius:8px;padding:11px 15px;text-decoration:none;font:inherit;cursor:pointer}.active{background:#243e59!important;color:white!important}.note{background:#eaf0f6;border-left:4px solid #6789ab;padding:14px 18px;font-size:14px;line-height:1.6}.legend{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin:18px 0;font-size:14px}.gradient{display:inline-block;width:180px;height:12px;border-radius:8px;background:linear-gradient(90deg,var(--first),var(--last))}.purple{width:13px;height:13px;background:var(--concert);border-radius:50%}.panel{background:white;padding:22px;border:1px solid #dce3ea;border-radius:12px;margin:22px 0}.filters{display:flex;gap:18px;flex-wrap:wrap}label{display:flex;flex-direction:column;gap:7px;font-size:14px}select,input{min-width:210px;padding:10px;border:1px solid #cbd4dd;border-radius:7px;font:inherit}.cards{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}.cards.landscapes{grid-template-columns:1fr}.card{background:white;border:1px solid #dce3ea;border-radius:12px;overflow:hidden}.card header{padding:18px 20px 2px}.card h3{font-size:18px;margin:0 0 8px}.card img{display:block;width:100%;height:auto}.caption{padding:12px 20px;font-size:14px;line-height:1.5}.muted,.meta{color:#5b6c7d;font-size:14px;line-height:1.6}.flag{color:#8c4614;font-weight:600}.more{display:block;margin:22px auto}footer{padding:30px 0;font-size:13px;color:#5b6c7d;line-height:1.7}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:13px;border-bottom:1px solid #e3e8ed}dialog{width:97vw;max-width:1800px;max-height:95vh;border:0;border-radius:12px;padding:0}dialog::backdrop{background:#102334bb}dialog img{display:block;max-width:100%;max-height:83vh;object-fit:contain;margin:auto}.bar{padding:14px;display:flex;align-items:center;gap:16px;background:#edf2f7}.bar .title{flex:1}.bar button{font:inherit;padding:8px;cursor:pointer}@media(max-width:850px){body{padding:18px}.cards{grid-template-columns:1fr}h1{font-size:26px}}
"""
JS = r"""
const stage=document.body.dataset.stage, initialPiece=document.body.dataset.piece;
const calibration=document.querySelector('#calibration'),reference=document.querySelector('#reference');
const piece=document.querySelector('#piece'),recording=document.querySelector('#recording'),search=document.querySelector('#search'),grid=document.querySelector('#cards'),more=document.querySelector('#more');
const params=new URLSearchParams(location.search);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let kind='leading',limit=12;
calibration.value=DATA.calibrations.includes(params.get('calibration'))?params.get('calibration'):DATA.default_calibration;
reference.value=DATA.references.includes(params.get('reference'))?params.get('reference'):DATA.references[0];
function selectedData(){return DATA.datasets[calibration.value+':'+reference.value]||{}}
function current(){return selectedData()[stage]||{observations:[],overlays:[]}}
function updateLinks(){const query=new URLSearchParams({calibration:calibration.value,reference:reference.value});document.querySelectorAll('a[data-navigation]').forEach(a=>a.search=query.toString());history.replaceState(null,'','?'+query.toString())}
function setRecordings(){const previous=recording.value;recording.replaceChildren(new Option('All recordings',''));for(const o of current().observations.filter(o=>!piece.value||o.piece===piece.value)){if(![...recording.options].some(x=>x.value===o.recording))recording.add(new Option(o.piece+' · '+o.recording_label,o.recording))}recording.value=[...recording.options].some(o=>o.value===previous)?previous:''}
function render(){
 const data=current(),q=search.value.trim().toLowerCase(),overlay=kind==='leading'||kind==='h2';grid.classList.toggle('landscapes',overlay);let selected;
 const recordingPiece=data.observations.find(o=>o.recording===recording.value)?.piece;
 const matchesRecording=o=>!recording.value||(o.recording?o.recording===recording.value:o.piece===recordingPiece);
 if(overlay){selected=data.overlays.filter(o=>(!piece.value||o.piece===piece.value)&&matchesRecording(o)&&(!q||[o.title,...o.labels].join(' ').toLowerCase().includes(q))).map(o=>({title:o.title,src:o.figures[kind],meta:o.ncurves+' individual curves · '+(stage==='full_piece'?'all sessions for this piece':'musical segments in score order'),caption:(kind==='leading'?'Component 1 · percent of complete eigenvalue sum':'H2 entropy · nats · complete eigenspectrum')+(o.insufficient_cycles_flag?' · Crosses: limited cycle support':'')+(o.bandwidth_below_resolution_flag?' · Triangles: filter bandwidth below Fourier spacing':''),flag:!!o.insufficient_cycles_flag||!!o.bandwidth_below_resolution_flag}))}
 else{selected=data.observations.filter(o=>(!piece.value||o.piece===piece.value)&&(!recording.value||o.recording===recording.value)&&(!q||[o.piece,o.recording,o.recording_label,o.segment_label].join(' ').toLowerCase().includes(q))&&o.figures[kind]).map(o=>({title:o.piece+' · '+o.recording_label+(o.segment_label?' · '+o.segment_index+' | '+o.segment_label:''),src:o.figures[kind],meta:o.ntracks+' tracks · '+o.npnts.toLocaleString()+' frames',caption:'Component 1 at '+o.peak_frequency.toFixed(3)+' Hz'+(o.peak_frequency_normalized!=null?' / '+o.peak_frequency_normalized.toFixed(3)+' × beat':'')+' · '+({matrix:'Absolute weights; raw pattern units',activation:'Absolute coordinate weights / observation maximum',xy_norm:'XY vector magnitude / observation maximum'}[kind])+(o.boundary_peak?' · FREQUENCY BOUNDARY':'')+(o.peak_tie_count>1?' · FIRST TIED BIN':'')+(o.insufficient_cycles?.some(Boolean)?' · Limited cycle support; see landscape markers':'')+(o.bandwidth_below_resolution?.some(Boolean)?' · Some filter bandwidths are below Fourier spacing':''),flag:o.boundary_peak||o.peak_tie_count>1||o.insufficient_cycles?.some(Boolean)||o.bandwidth_below_resolution?.some(Boolean)}))}
 document.querySelector('#count').textContent=selected.length+' figures match · showing '+Math.min(limit,selected.length)+(overlay&&stage==='full_piece'?' · each overlay retains all sessions for its piece':'');
 grid.innerHTML=selected.slice(0,limit).map(o=>`<article class="card"><header><h3>${esc(o.title)}</h3><p class="meta">${esc(o.meta)}</p></header><a class="image-link" href="${esc(o.src)}" data-title="${esc(o.title)}"><img loading="lazy" src="${esc(o.src)}" alt="${esc(o.title+' — '+o.caption)}"></a><div class="caption ${o.flag?'flag':''}">${esc(o.caption)} · <a href="${esc(o.src)}" target="_blank">Full size ↗</a></div></article>`).join('')||'<p>No figures available for this selection. Beat normalization applies to segments with accepted tempo estimates.</p>';more.hidden=selected.length<=limit;
}
function changeMode(){
 const datasets=selectedData(),all=Object.values(datasets).flatMap(d=>d.observations);
 const rates=[...new Set(all.map(o=>o.srate))].join(', ');
 const confirmed=all.length&&all.every(o=>o.srate_confirmed&&o.timing_provenance?.srate_confirmation_source==='user');
 document.querySelector('#provenance').textContent=(calibration.value==='physical'?'Physical':'Legacy')+' filters · '+(reference.value==='beat'?'Beat-relative segment analysis':'Physical-frequency analysis')+' · '+(all.length?rates+' Hz sampling rate'+(confirmed?' (user-confirmed 28 November 2026)':' (see catalog provenance)'):'results not available');
 document.querySelector('#tempo-context').textContent=reference.value==='beat'?'Tempo is estimated independently for each existing WAV segment. Only estimates passing the recorded screening rules are included; metrical-level interpretation and audio/frame alignment remain limitations. Crosses flag limited cycle support; triangles flag filter bandwidths below the segment’s Fourier spacing. These diagnostics do not certify narrowband validity.':(DATA.references.includes('beat')?'':'Beat-normalized results are not available in this report.');
 document.querySelector('#coverage').textContent=all.length+' observations in this selection. '+Object.values(datasets).map(d=>d.missing_text||'').filter(Boolean).filter((v,i,a)=>a.indexOf(v)===i).join(' ');
 if(stage){setRecordings();limit=12;render()}else{
 document.querySelector('#overview-rows').innerHTML=DATA.pieces.map(p=>'<tr><td>'+esc(p[0].toUpperCase()+p.slice(1))+'</td>'+[['full_piece','full','recordings'],['segment_piece','segments','segments']].map(([s,prefix,label])=>'<td><a data-navigation href="'+prefix+'-'+p+'.html">'+(datasets[s]?.observations||[]).filter(o=>o.piece===p).length+' '+label+'</a></td>').join('')+'</tr>').join('');}
 updateLinks();
}
calibration.onchange=reference.onchange=changeMode;
if(stage){for(const p of DATA.pieces)piece.add(new Option(p[0].toUpperCase()+p.slice(1),p));piece.value=initialPiece;
piece.onchange=()=>{setRecordings();limit=12;render()};recording.onchange=search.oninput=()=>{limit=12;render()};document.querySelectorAll('[data-kind]').forEach(b=>b.onclick=()=>{kind=b.dataset.kind;document.querySelectorAll('[data-kind]').forEach(x=>x.classList.toggle('active',x===b));limit=12;render()});more.onclick=()=>{limit+=12;render()};
const dialog=document.querySelector('dialog');document.addEventListener('click',e=>{const link=e.target.closest('a.image-link');if(!link)return;e.preventDefault();dialog.querySelector('img').src=link.href;dialog.querySelector('.title').textContent=link.dataset.title;dialog.querySelector('.original').href=link.href;dialog.showModal()});dialog.querySelector('button').onclick=()=>dialog.close();dialog.onclick=e=>{if(e.target===dialog)dialog.close()};}
changeMode();
"""


def as_list(value):
    """MATLAB encodes a scalar struct/string without array brackets."""
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def build_report(visualization_paths, report_path):
    """Combine independently computed calibrations; never relabel a result."""
    paths = [visualization_paths] if isinstance(visualization_paths, (str, Path)) else visualization_paths
    report_path = Path(report_path).resolve()
    datasets, figure_paths, palettes = {}, set(), []

    def figure_url(path):
        path = Path(path)
        if not path.is_file():
            raise FileNotFoundError(path)
        figure_paths.add(path)
        return quote(os.path.relpath(path, report_path), safe='/')

    for visualization_path in map(Path, paths):
        for stage in ['full_piece', 'segment_piece']:
            source = visualization_path / stage / 'figure_catalog.json'
            if not source.is_file():
                continue
            raw = json.loads(source.read_text())
            settings = raw['settings']
            calibration = settings.get('filter_width_calibration')
            if calibration not in ['legacy', 'physical']:
                raise ValueError(f'Catalog lacks explicit legacy/physical calibration: {source}')
            reference = settings.get('frequency_reference', 'hz')
            if reference not in ['hz', 'beat']:
                raise ValueError(f'Unknown frequency reference: {reference}')
            if reference == 'beat' and stage == 'full_piece':
                raise ValueError('Beat-relative results must use existing musical segments.')
            key = f'{calibration}:{reference}'
            if stage in datasets.setdefault(key, {}):
                raise ValueError(f'Duplicate catalog for {key}/{stage}; select one run.')
            palettes.append(tuple(tuple(settings[k]) for k in ['color_first', 'color_last', 'color_concert']))
            observations, overlays = [], []
            for observation in as_list(raw['observations']):
                if observation.get('filter_width_calibration') != calibration:
                    raise ValueError(f'Observation calibration disagrees with catalog: {source}')
                if observation.get('frequency_reference', 'hz') != reference:
                    raise ValueError(f'Observation frequency reference disagrees with catalog: {source}')
                if reference == 'beat' and not observation.get('beat_frex', 0) > 0:
                    raise ValueError(f'Beat-relative observation lacks its positive beat frequency: {source}')
                files = as_list(observation.pop('figure_files'))
                roles = as_list(observation.pop('figure_roles', None))
                if len(files) != len(roles) or len(set(roles)) != len(roles):
                    raise ValueError(f'Missing, duplicate or mismatched figure roles: {source}')
                if not set(roles).issubset({'matrix', 'activation', 'xy_norm'}):
                    raise ValueError(f'Unknown spatial figure role: {source}')
                observation['figures'] = {role: figure_url(p) for role, p in zip(roles, files)}
                observations.append(observation)
            for overlay in as_list(raw['overlays']):
                overlay['labels'] = as_list(overlay['labels'])
                files = as_list(overlay.pop('figure_files'))
                if len(files) != 2:
                    raise ValueError(f'Expected component-1/H2 overlay pair: {source}')
                overlay['figures'] = {kind: figure_url(p) for kind, p in zip(['leading', 'h2'], files)}
                overlays.append(overlay)
            missing_text = ''
            index_path = visualization_path.parent.parent / '02_Core_SegmentPiece' / 'core_index.csv'
            if stage == 'segment_piece' and index_path.is_file():
                with index_path.open(newline='') as stream:
                    missing = [r for r in csv.DictReader(stream) if r['Status'] not in ['saved', 'existing', 'not_selected']]
                if missing:
                    if len(missing) <= 3:
                        missing_text = 'Unavailable segments: ' + '; '.join(' · '.join([r['Piece'], r['Recording'], r['SegmentLabel'], r['Status']]) for r in missing) + '.'
                    else:
                        counts = Counter(r['Status'] for r in missing)
                        missing_text = 'Unavailable segments: ' + ', '.join(f'{n} {status.replace("_", " ")}' for status, n in sorted(counts.items())) + '. See the core index for individual reasons.'
            datasets[key][stage] = {'observations': observations, 'overlays': overlays, 'missing_text': missing_text}
    if not datasets:
        raise ValueError('No Block 3 figure catalogs found.')
    if any(p != palettes[0] for p in palettes):
        raise ValueError('Catalogs use inconsistent chronological colors.')
    calibrations = [c for c in ['physical', 'legacy'] if any(k.startswith(c+':') for k in datasets)]
    references = [r for r in ['hz', 'beat'] if any(k.endswith(':'+r) for k in datasets)]
    pieces = sorted({o['piece'] for d in datasets.values() for s in d.values() for o in s['observations']})
    payload = {'datasets': datasets, 'calibrations': calibrations, 'references': references,
               'default_calibration': calibrations[0], 'pieces': pieces}
    # Keep the complete numerical catalog once; pages need navigation metadata
    # only, not repeated signed/absolute pattern arrays and eigenspectra.
    ui_payload = {**payload, 'datasets': {}}
    observation_fields = {'piece', 'recording', 'recording_label', 'segment_index',
        'segment_label', 'ntracks', 'npnts', 'srate', 'srate_confirmed',
        'timing_provenance', 'peak_frequency', 'peak_frequency_normalized',
        'boundary_peak', 'peak_tie_count', 'figures', 'insufficient_cycles',
        'bandwidth_below_resolution'}
    overlay_fields = {'piece', 'recording', 'title', 'labels', 'ncurves',
        'figures', 'insufficient_cycles_flag', 'bandwidth_below_resolution_flag'}
    for key, stages in datasets.items():
        ui_payload['datasets'][key] = {stage: {
            'observations': [{k: v for k, v in o.items() if k in observation_fields}
                             for o in data['observations']],
            'overlays': [{k: v for k, v in o.items() if k in overlay_fields}
                         for o in data['overlays']],
            'missing_text': data['missing_text']}
            for stage, data in stages.items()}
    palette_css = ':root{' + ';'.join('--'+name+':rgb('+','.join(str(round(255*v)) for v in color)+')'
        for name, color in zip(['first', 'last', 'concert'], palettes[0])) + '}'
    report_path.mkdir(parents=True, exist_ok=True)

    def page(title, body, stage='', piece=''):
        nav = '<nav>' + ''.join(f'<a data-navigation class="{"active" if key == stage else ""}" href="{url}">{label}</a>'
            for key, url, label in [('', 'index.html', 'Overview'), ('full_piece', 'full-pieces.html', 'Full pieces'), ('segment_piece', 'segments.html', 'Musical segments')]) + '</nav>'
        calibration_options = ''.join(f'<option value="{c}">{c.title()}</option>' for c in calibrations)
        reference_options = ''.join(f'<option value="{r}" {"disabled" if r not in references else ""}>{label}</option>' for r, label in [('hz', 'Hz'), ('beat', 'Frequency / beat (segments)')])
        script_data = json.dumps(ui_payload, separators=(',', ':')).replace('</', '<\\/')
        return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)} · Orchestra FREQ-NESS</title><style>{CSS}{palette_css}</style></head><body data-stage="{stage}" data-piece="{piece}">
<header><div class="muted">ORCHESTRA STUDY · MATLAB FIGURES</div><h1>{html.escape(title)}</h1>
<div class="panel filters"><label>Filter calibration<select id="calibration">{calibration_options}</select></label><label>Frequency reference<select id="reference">{reference_options}</select></label></div>{nav}
<div class="note"><strong id="provenance"></strong><br><span id="tempo-context"></span><br>Component 1 and complete-spectrum H2 are shown separately. Every curve is one observation, without averaging. Spatial displays use its highest analyzed component-1 bin; boundary maxima are flagged. Magnitudes affect displays only; signed cores are preserved.</div>
<div class="legend"><span>First</span><span class="gradient"></span><span>Last rehearsal / musical segment</span><span class="purple"></span><span>Concerts; Concert 2 dashed</span></div></header><main>{body}</main>
<footer><span id="coverage"></span> <a href="figure_catalog.json">Figure catalog and numerical values</a>.<br>H2 = −ln Σp², normalized across the complete eigenspectrum. Raw H2 depends on channel count. Leading components are ranked independently at each frequency.<br>Absolute coordinate and XY-magnitude overhead views use separate, recorded observation-level maxima; matrices retain raw absolute weights. These show relative spatial distributions, not cross-recording absolute movement amplitudes. Z is unmeasured. Track IDs are retained; musician labels and playing annotations are deferred.<br>Audio/frame alignment remains unresolved; the 25 Hz analysis rate is user-confirmed, not independently verified camera metadata. Existing WAV segments differ from Peter's new score sections. Boundary maxima need not be interior spectral peaks, and short segments may not resolve the narrowest filters. These descriptive plots do not test the plasticity hypothesis.</footer>
<script>const DATA={script_data};{JS}</script></body></html>'''

    body = '''<section class="panel"><h2>Full pieces and musical segments</h2><p>Choose the filter calibration above. Each selection displays independently estimated results. Full-piece overlays compare sessions within each piece; segment overlays follow score-label order within each recording.</p><table><thead><tr><th>Piece</th><th>Full pieces</th><th>Musical segments</th></tr></thead><tbody id="overview-rows"></tbody></table></section><section class="panel"><h2>Spatial displays</h2><p>Absolute activation matrices and overhead coordinate views retain the existing plots. XY vector magnitude adds an orientation-invariant view in the measured image plane, computed as sqrt(X² + Y²) from the signed pattern weights before display scaling. All spatial views use the same empirical leading-component peak.</p></section>'''
    (report_path/'index.html').write_text(page('Orchestra results explorer', body))
    for stage, prefix, name in [('full_piece', 'full', 'Full pieces'), ('segment_piece', 'segments', 'Musical segments')]:
        for piece in ['', *pieces]:
            links = ''.join(f'<a data-navigation href="{prefix}-{p}.html">{p.title()}</a>' for p in pieces)
            body = f'''<div class="links">{links}</div><section class="panel"><div class="filters"><label>Piece<select id="piece"><option value="">All pieces</option></select></label><label>Recording<select id="recording"><option value="">All recordings</option></select></label><label>Find a segment or recording<input id="search" type="search" placeholder="e.g. Start, D2, Concert"></label></div><div class="types"><button class="active" data-kind="leading">Component 1</button><button data-kind="h2">H2 entropy</button><button data-kind="matrix">Absolute activation matrices</button><button data-kind="activation">Absolute overhead activations</button><button data-kind="xy_norm">XY vector magnitude</button></div><p class="muted" id="count"></p></section><div class="cards" id="cards"></div><button class="more" id="more">Show 12 more figures</button><dialog><div class="bar"><span class="title"></span><a class="original" target="_blank">Open original ↗</a><button aria-label="Close figure">Close</button></div><img alt="Full-resolution MATLAB figure"></dialog>'''
            filename = f'{prefix}-{piece}.html' if piece else ('full-pieces.html' if stage == 'full_piece' else 'segments.html')
            (report_path/filename).write_text(page(name+(' · '+piece.title() if piece else ''), body, stage, piece))
    (report_path/'figure_catalog.json').write_text(json.dumps(payload, indent=2))
    validation = {'calibrations': calibrations, 'frequency_references': references,
        'default_calibration': calibrations[0], 'original_figures': len(figure_paths),
        'all_figure_paths_exist': True, 'datasets': {k: {s: {'observations': len(v['observations']), 'overlay_pairs': len(v['overlays'])} for s, v in d.items()} for k, d in datasets.items()}}
    (report_path/'report_validation.json').write_text(json.dumps(validation, indent=2))
    return validation


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--visualization-path', type=Path, action='append', required=True,
                        help='Repeat for independently computed calibration/reference runs.')
    parser.add_argument('--output-path', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_report([p.resolve() for p in args.visualization_path], args.output_path), indent=2))
