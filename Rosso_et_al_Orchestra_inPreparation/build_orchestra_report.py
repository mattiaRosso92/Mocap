"""Publish Block 3's MATLAB figures as an offline HTML gallery (stdlib only).

No analysis or replotting happens here: MATLAB's catalogs supply the spectra,
chronological order, empirical peaks, labels, and original figure paths.
"""
import argparse
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
const piece=document.querySelector('#piece'),recording=document.querySelector('#recording'),search=document.querySelector('#search'),grid=document.querySelector('#cards'),more=document.querySelector('#more');
let kind='leading',limit=12;
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
for(const p of [...new Set(DATA.observations.map(o=>o.piece))])piece.add(new Option(p[0].toUpperCase()+p.slice(1),p));piece.value=initialPiece;
function setRecordings(){const previous=recording.value;recording.replaceChildren(new Option('All recordings',''));for(const o of DATA.observations.filter(o=>!piece.value||o.piece===piece.value)){if(![...recording.options].some(x=>x.value===o.recording))recording.add(new Option(o.piece+' · '+o.recording_label,o.recording))}recording.value=[...recording.options].some(o=>o.value===previous)?previous:''}
function render(){const q=search.value.trim().toLowerCase(), overlay=kind==='leading'||kind==='h2';let selected;grid.classList.toggle('landscapes',overlay);
if(overlay){selected=DATA.overlays.filter(o=>(!piece.value||o.piece===piece.value)&&(!recording.value||!o.recording||o.recording===recording.value)&&(!q||[o.title,...o.labels].join(' ').toLowerCase().includes(q))).map(o=>({title:o.title,src:o.figures[kind],meta:o.ncurves+' individual curves · '+(stage==='full_piece'?'all sessions for this piece':'musical segments in score order'),caption:kind==='leading'?'Component 1 · percent of complete eigenvalue sum':'H2 entropy · nats · complete eigenspectrum'}))}
else{selected=DATA.observations.filter(o=>(!piece.value||o.piece===piece.value)&&(!recording.value||o.recording===recording.value)&&(!q||[o.piece,o.recording,o.recording_label,o.segment_label].join(' ').toLowerCase().includes(q))&&o.figures[kind]).map(o=>({title:o.piece+' · '+o.recording_label+(o.segment_label?' · '+o.segment_index+' | '+o.segment_label:''),src:o.figures[kind],meta:o.ntracks+' tracks · '+o.npnts.toLocaleString()+' frames',caption:'Component 1 at '+o.peak_frequency.toFixed(2)+' Hz · maximum '+o.peak_value.toFixed(1)+'%'+(o.boundary_peak?' · FREQUENCY BOUNDARY':'')+(o.peak_tie_count>1?' · FIRST TIED BIN':''),flag:o.boundary_peak||o.peak_tie_count>1}))}
document.querySelector('#count').textContent=selected.length+' figures match · showing '+Math.min(limit,selected.length)+(overlay&&stage==='full_piece'?' · each overlay retains all sessions for its piece':'');grid.innerHTML=selected.slice(0,limit).map(o=>`<article class="card"><header><h3>${esc(o.title)}</h3><p class="meta">${esc(o.meta)}</p></header><a class="image-link" href="${o.src}" data-title="${esc(o.title)}"><img loading="lazy" src="${o.src}" alt="${esc(o.title+' — '+o.caption)}"></a><div class="caption ${o.flag?'flag':''}">${esc(o.caption)} · <a href="${o.src}" target="_blank">Full size ↗</a></div></article>`).join('')||'<p>No matching figures.</p>';more.hidden=selected.length<=limit}
piece.onchange=()=>{setRecordings();limit=12;render()};recording.onchange=search.oninput=()=>{limit=12;render()};document.querySelectorAll('[data-kind]').forEach(b=>b.onclick=()=>{kind=b.dataset.kind;document.querySelectorAll('[data-kind]').forEach(x=>x.classList.toggle('active',x===b));limit=12;render()});more.onclick=()=>{limit+=12;render()};setRecordings();render();
const dialog=document.querySelector('dialog');document.addEventListener('click',e=>{const link=e.target.closest('a.image-link');if(!link)return;e.preventDefault();dialog.querySelector('img').src=link.href;dialog.querySelector('.title').textContent=link.dataset.title;dialog.querySelector('.original').href=link.href;dialog.showModal()});dialog.querySelector('button').onclick=()=>dialog.close();dialog.onclick=e=>{if(e.target===dialog)dialog.close()};
"""


def as_list(value):
    """MATLAB jsonencode emits a scalar struct/string without array brackets."""
    return value if isinstance(value, list) else [value]


def build_report(visualization_path, report_path):
    report_path.mkdir(parents=True, exist_ok=True)
    datasets = {}
    figure_paths = set()
    palettes = []

    def figure_url(path):
        path = Path(path)
        if not path.is_file():
            raise FileNotFoundError(path)
        figure_paths.add(path)
        return quote(os.path.relpath(path, report_path), safe='/')

    for stage in ['full_piece', 'segment_piece']:
        source = visualization_path / stage / 'figure_catalog.json'
        if not source.is_file():
            continue
        raw = json.loads(source.read_text())
        palettes.append(tuple(tuple(raw['settings'][key]) for key in
                              ['color_first', 'color_last', 'color_concert']))
        observations, overlays = [], []
        for observation in as_list(raw['observations']):
            paths = as_list(observation.pop('figure_files'))
            observation['figures'] = {
                ('matrix' if Path(p).name.startswith('pattern_matrix') else 'activation'): figure_url(p)
                for p in paths
            }
            observations.append(observation)
        for overlay in as_list(raw['overlays']):
            overlay['labels'] = as_list(overlay['labels'])
            paths = as_list(overlay.pop('figure_files'))
            overlay['figures'] = {kind: figure_url(path) for kind, path in zip(['leading', 'h2'], paths)}
            overlays.append(overlay)
        datasets[stage] = {'observations': observations, 'overlays': overlays}
    if not datasets:
        raise ValueError('No Block 3 figure catalogs found.')
    if any(palette != palettes[0] for palette in palettes):
        raise ValueError('Stage catalogs use different chronological colors; rerun Block 3 consistently.')
    palette_css = ':root{' + ';'.join(
        '--'+name+':rgb('+','.join(str(round(255*v)) for v in color)+')'
        for name, color in zip(['first', 'last', 'concert'], palettes[0])) + '}'
    all_observations = [o for data in datasets.values() for o in data['observations']]
    rates = ', '.join(f'{rate:g}' for rate in sorted({o['srate'] for o in all_observations}))
    clock_status = 'unconfirmed' if any(not o['srate_confirmed'] for o in all_observations) else 'confirmed'
    clock_text = f'{rates} Hz sampling rate ({clock_status})'
    pieces = sorted({o['piece'] for data in datasets.values() for o in data['observations']})
    missing_text = 'Missing source segments have no estimate or pattern.'
    index_path = visualization_path.parent.parent / '02_Core_SegmentPiece' / 'core_index.csv'
    if index_path.is_file():
        with index_path.open(newline='') as stream:
            missing = [row for row in csv.DictReader(stream) if row['Status'] == 'missing_source']
        if missing:
            labels = [' · '.join([row['Piece'], row['Recording'], row['SegmentLabel']]) for row in missing]
            missing_text = 'Missing source segments (not reconstructed): ' + '; '.join(labels) + '.'
    observation_count = sum(len(d['observations']) for d in datasets.values())
    overlay_count = sum(len(d['overlays']) for d in datasets.values())

    def page(title, body, stage='', piece='', script=''):
        nav = '<nav>' + ''.join(
            f'<a class="{"active" if key == stage else ""}" href="{url}">{label}</a>'
            for key, url, label in [('', 'index.html', 'Overview'), ('full_piece', 'full-pieces.html', 'Full pieces'),
                                    ('segment_piece', 'segments.html', 'Musical segments')]) + '</nav>'
        return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)} · Orchestra FREQ-NESS</title><style>{CSS}{palette_css}</style></head><body data-stage="{stage}" data-piece="{piece}"><header><div class="muted">ORCHESTRA STUDY · MATLAB FIGURES</div><h1>{html.escape(title)}</h1>{nav}<div class="note">Component 1 and H2 are shown separately. Every curve represents a recording or musical segment, with no averaging. Patterns use each observation's highest component-1 value on its analyzed frequency grid; a boundary maximum is flagged. The displayed data use a <strong>{clock_text}</strong>. No core estimates or toolbox functions were changed.</div><div class="legend"><span>First</span><span class="gradient"></span><span>Last rehearsal / musical segment</span><span class="purple"></span><span>Concert sessions (full-piece plots); Concert 2 dashed</span></div></header><main>{body}</main><footer>{observation_count} observations · {overlay_count} overlay pairs · {len(figure_paths)} original MATLAB figures. <a href="figure_catalog.json">Figure catalog and plotted numerical values</a>.<br>H2 = −ln Σp², where p is normalized across the complete eigenspectrum. Lower H2 indicates greater concentration; raw H2 also depends on the number of available channels. Leading components are ranked independently at each frequency.<br>Peak frequencies can differ across observations. Boundaries/ties are identified rather than treated as unambiguous interior peaks. Signed patterns retain the toolbox's sign and display normalization; Z is an unmeasured placeholder. These descriptive plots do not test the plasticity hypothesis.<br>{html.escape(missing_text)} D means day and R rehearsal; concert numbers identify files, with their version meaning still unconfirmed.</footer>{script}</body></html>'''

    rows = ''.join('<tr><td>'+p.title()+'</td>'+''.join(
        f'<td><a href="{prefix}-{p}.html">{sum(o["piece"] == p for o in datasets.get(stage,{"observations":[]})["observations"])} {label}</a></td>'
        for stage, prefix, label in [('full_piece','full','recordings'),('segment_piece','segments','musical segments')])+'</tr>' for p in pieces)
    body = f'''<section class="panel"><h2>Full pieces and musical segments</h2><p>Full-piece overlays compare sessions within each piece in numeric day/rehearsal order, followed by concerts. Segment overlays compare every available musical segment within one recording, ordered by its manifest index. The same colors identify the same curves in the leading-component and H2 plots.</p><table><thead><tr><th>Piece</th><th>Full pieces</th><th>Musical segments</th></tr></thead><tbody>{rows}</tbody></table></section><section class="panel"><h2>Reading the revised figures</h2><p>Use the four gallery buttons to view component 1, H2 entropy, activation matrices, or overhead activations. Click a plot to enlarge it. Landscapes connect the original analyzed frequency bins with no display smoothing. Axes use common limits within each stage to support comparison.</p><p>Activation matrices and overhead views use the exact same empirical frequency for each observation. Peak selection uses the largest stored component-1 value, including boundaries; exact ties select the first (lowest-frequency) bin. The selected frequency is saved in the pipeline's visualization metadata.</p></section>'''
    (report_path / 'index.html').write_text(page('Chronological orchestra landscapes', body))
    for stage, data in datasets.items():
        prefix, name = ('full','Full pieces') if stage == 'full_piece' else ('segments','Musical segments')
        for piece in ['', *pieces]:
            subset = {key: [o for o in values if not piece or o['piece'] == piece] for key, values in data.items()}
            links = ''.join(f'<a href="{prefix}-{p}.html">{p.title()}</a>' for p in pieces)
            body = f'''<div class="links">{links}</div><section class="panel"><div class="filters"><label>Piece<select id="piece"><option value="">All pieces</option></select></label><label>Recording<select id="recording"><option value="">All recordings</option></select></label><label>Find a segment or recording<input id="search" type="search" placeholder="e.g. Start, D2, Concert"></label></div><div class="types"><button class="active" data-kind="leading">Component 1</button><button data-kind="h2">H2 entropy</button><button data-kind="matrix">Activation matrices</button><button data-kind="activation">Overhead activations</button></div><p class="muted" id="count"></p></section><div class="cards" id="cards"></div><button class="more" id="more">Show 12 more figures</button><dialog><div class="bar"><span class="title"></span><a class="original" target="_blank">Open original ↗</a><button aria-label="Close figure">Close</button></div><img alt="Full-resolution MATLAB figure"></dialog>'''
            payload = json.dumps(subset, separators=(',', ':')).replace('</', '<\\/')
            filename = f'{prefix}-{piece}.html' if piece else ('full-pieces.html' if stage == 'full_piece' else 'segments.html')
            (report_path / filename).write_text(page(name+(' · '+piece.title() if piece else ''), body, stage, piece,
                                                  '<script>const DATA='+payload+';\n'+JS+'</script>'))
    (report_path / 'figure_catalog.json').write_text(json.dumps(datasets, indent=2))
    validation = {'observations': observation_count, 'overlay_pairs': overlay_count, 'original_figures': len(figure_paths),
                  'all_figure_paths_exist': True, 'visualization_path': str(visualization_path)}
    (report_path / 'report_validation.json').write_text(json.dumps(validation, indent=2))
    return validation


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--visualization-path', type=Path, required=True)
    parser.add_argument('--output-path', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_report(args.visualization_path.resolve(), args.output_path.resolve()), indent=2))
