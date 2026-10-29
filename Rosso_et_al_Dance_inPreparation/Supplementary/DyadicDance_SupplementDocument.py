"""Assemble the Word supplement from permanent MATLAB figures and saved R tables.

Run after DyadicDance_Supplementary.m and the study R scripts. Requires
python-docx and Pillow. Outputs remain in ignored Dance_Data; sources and the
main manuscript are never edited. An existing document is not overwritten.
Authors: Mattia Rosso, Felix Bigand, Leonardo Bonetti
"""
from pathlib import Path
import argparse
import csv
import json
import re
import zipfile

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from PIL import Image


repo = Path(__file__).resolve().parents[2]
root = repo / 'Dance_Data/FREQNESS_Results_Rosso_et_al_inPreparation/legacy_logarithmic_recovered_dyads'
output = root / 'Supplementary_35'
figures = output / 'Figures'
stats = repo / 'Dance_Data/FREQNESS_Mocap_Stats_Results/legacy_logarithmic_recovered_dyads'
phase_tag = 'PhaseSpaceRQA_AA10Hz_Dwn10_Radius10_Standardize0_Window10to45s'
parser = argparse.ArgumentParser()
parser.add_argument('--name', default='DyadicDance_Supplementary_Material.docx')
parser.add_argument('--template', type=Path,
                    default=repo/'paper_drafts/TEMP_FREQNESS_Mocap_v3.docx')
args = parser.parse_args()
destination = output / args.name
if destination.exists():
    raise SystemExit('Document exists. Use --name with a new filename to preserve it.')
report = json.loads((output / 'DyadicDance_FigureSummary.json').read_text())
assert report['ndyads'] == 35 and report['ntrials'] == 1119
assert report['maximum_baseline_error'] < 1e-7


def rows(path):
    with path.open(newline='') as stream:
        return list(csv.DictReader(stream))


def ptext(value):
    value = float(value)
    return '< .001' if value < .001 else f'= {value:.3f}'.replace('0.', '.')


def pcell(value):
    value = float(value)
    return '< .001' if value < .001 else f'{value:.3f}'.replace('0.', '.')


# Reuse the manuscript package when available; replace its content, not its file.
# The explicit formatting below also reproduces its appearance without the draft.
doc = Document(args.template) if args.template.is_file() else Document()
for child in list(doc.element.body):
    if child.tag != qn('w:sectPr'):
        doc.element.body.remove(child)
for rel_id, rel in list(doc.part.rels.items()):
    kind = rel.reltype.rsplit('/',1)[-1]
    if kind in ['image','customXml','hyperlink','people'] or kind.startswith('comments'):
        del doc.part.rels[rel_id]
for tag in ['trackRevisions','documentProtection']:
    for element in doc.settings.element.findall(qn('w:'+tag)):
        element.getparent().remove(element)
section = doc.sections[0]
section.page_width = Inches(8.5)
section.page_height = Inches(11)
section.top_margin = section.bottom_margin = Inches(1)
section.left_margin = section.right_margin = Inches(1)
for style_name in ['Normal', 'Title', 'Heading 1', 'Heading 2', 'Caption']:
    if style_name not in doc.styles:
        doc.styles.add_style(style_name,WD_STYLE_TYPE.PARAGRAPH).base_style = doc.styles['Normal']
    style = doc.styles[style_name]
    style.font.name = 'Times New Roman'
    style.font.color.rgb = RGBColor(0, 0, 0)
    style.font.size = Pt(12)
    fonts = style.element.get_or_add_rPr().get_or_add_rFonts()
    for attribute in list(fonts.attrib):
        if 'Theme' in attribute:
            del fonts.attrib[attribute]
    for attribute in ['ascii','hAnsi','eastAsia','cs']:
        fonts.set(qn('w:'+attribute),'Times New Roman')
    for tag in ['spacing','kern']:
        for element in style.element.get_or_add_rPr().findall(qn('w:'+tag)):
            element.getparent().remove(element)
doc.styles['Normal'].paragraph_format.line_spacing = 1
doc.styles['Normal'].paragraph_format.space_before = Pt(12)
doc.styles['Normal'].paragraph_format.space_after = Pt(0)
doc.styles['Normal'].paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
doc.styles['Title'].font.size = Pt(16)
doc.styles['Title'].font.bold = True
doc.styles['Title'].paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
doc.styles['Title'].paragraph_format.space_before = Pt(0)
doc.styles['Title'].paragraph_format.space_after = Pt(0)
doc.styles['Heading 1'].font.size = Pt(12)
doc.styles['Heading 1'].font.italic = True
doc.styles['Heading 1'].font.bold = False
doc.styles['Heading 1'].paragraph_format.line_spacing = 1
doc.styles['Heading 1'].paragraph_format.space_before = Pt(12)
doc.styles['Heading 1'].paragraph_format.space_after = Pt(0)
doc.styles['Heading 1'].paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
doc.styles['Caption'].font.size = Pt(10)
doc.styles['Caption'].font.italic = False
doc.styles['Caption'].font.bold = False
doc.styles['Caption'].paragraph_format.line_spacing = 1
doc.styles['Caption'].paragraph_format.space_before = Pt(12)
doc.styles['Caption'].paragraph_format.space_after = Pt(0)
doc.styles['Caption'].paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
doc.core_properties.title = 'Supplementary material for the dyadic dance study'
doc.core_properties.author = 'Mattia Rosso; Felix Bigand; Leonardo Bonetti'
figure_number = 0
table_number = 0
used_statistics = set()


def paragraph(text):
    return doc.add_paragraph(text)


def heading(text, new_page=True):
    p = doc.add_heading(text, level=1)
    p.paragraph_format.page_break_before = new_page


def figure(stem, caption, max_height=5.8):
    global figure_number
    figure_number += 1
    path = figures / f'{stem}.png'
    with Image.open(path) as image:
        width, height = image.size
    display_width = min(6.5, max_height * width / height)
    p = doc.add_paragraph()
    p.paragraph_format.keep_with_next = True
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    shape = p.add_run().add_picture(str(path), width=Inches(display_width))
    shape._inline.docPr.set('descr', caption)
    p = doc.add_paragraph(style='Caption')
    p.paragraph_format.keep_together = True
    lead, separator, remainder = caption.partition('. ')
    p.add_run(f'Supplementary Figure {figure_number}. '+lead+separator).bold = True
    p.add_run(remainder)


def table(headers, records, caption, font_size=10):
    global table_number
    table_number += 1
    p = doc.add_paragraph(style='Caption')
    p.paragraph_format.keep_with_next = True
    p.add_run(f'Supplementary Table {table_number}. ').bold = True
    p.add_run(caption)
    tab = doc.add_table(rows=1, cols=len(headers))
    tab.autofit = False
    widths = [2.2] + [(6.5 - 2.2) / (len(headers) - 1)] * (len(headers) - 1)
    for col, width in zip(tab.columns, widths):
        col.width = Inches(width)
    for cell, text, width in zip(tab.rows[0].cells, headers, widths):
        cell.width = Inches(width); cell.text = text
    repeat = OxmlElement('w:tblHeader'); tab.rows[0]._tr.get_or_add_trPr().append(repeat)
    for record in records:
        cells = tab.add_row().cells
        for cell, text, width in zip(cells, record, widths):
            cell.width = Inches(width); cell.text = str(text)
    for rowi, row in enumerate(tab.rows):
        for celli, cell in enumerate(row.cells):
            tcpr = cell._tc.get_or_add_tcPr()
            borders = OxmlElement('w:tcBorders')
            for edge in ['top', 'left', 'bottom', 'right']:
                border = OxmlElement('w:' + edge)
                border.set(qn('w:val'), 'single'); border.set(qn('w:sz'), '4')
                border.set(qn('w:color'), 'D9D9D9'); borders.append(border)
            tcpr.append(borders)
            if rowi == 0:
                shade = OxmlElement('w:shd'); shade.set(qn('w:fill'), 'E7E6E6'); tcpr.append(shade)
            for p in cell.paragraphs:
                p.paragraph_format.space_before = Pt(3)
                p.paragraph_format.space_after = Pt(3)
                p.paragraph_format.line_spacing = 1
                if celli:
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                for run in p.runs:
                    run.font.size = Pt(font_size)
                    run.bold = rowi == 0
    doc.add_paragraph().paragraph_format.space_after = Pt(2)


def outcome_path(component, outcome):
    method = Path('SpatialCoordination/Raw') if outcome == 'Mirror' else Path(phase_tag)
    return stats / method / f'Component_{component}' / outcome


doc.add_paragraph('Supplementary material for the dyadic dance study', style='Title')
paragraph('We examined the dependence of bodily networks on decomposition, filter bandwidth and kinematic representation, together with lower-ranked components, metric prominence and landscape similarity. All analyses included 35 dyads and 1,119 retained trials. Conditions crossed Visual contact (absent/present) and Musical input (different/same). Unless stated otherwise, individual measures were averaged across trials and then partners, giving equal weight to each dyad. Curves and error bars show means and SEMs across dyads. Re-estimation controls are descriptive, without additional inferential tests.')
heading('Network landscapes and effective dimensionality across conditions', False)
top_two = report['top_two_metric_percent']
ed = report['ed_metric_mean']
paragraph('We first examined the network landscape separately for each experimental condition. Effective dimensionality was computed from the complete 66-eigenvalue spectrum at each frequency, as the squared sum of the eigenvalues divided by their sum of squares. The first two components accounted for ' + ', '.join(f'{value:.1f}%' for value in top_two) + ' of the normalized eigenspectrum at beat/4, beat/2, beat and 2 × beat, respectively. The corresponding mean effective dimensionalities were ' + ', '.join(f'{value:.2f}' for value in ed) + '.')
figure('S01_Conditions_Landscapes_ED', 'Condition-specific network landscapes and effective dimensionality. Upper panels show the first four components; lower panels show effective dimensionality computed from the full eigenspectrum. Frequencies are expressed relative to each participant’s musical beat and displayed on a logarithmic axis. Shading denotes ± SEM across 35 dyads.', 4.2)

heading('Comparison between GED and PCA')
paragraph('To distinguish frequency-selective covariance contrast from narrowband variance, we compared GED with PCA applied to the same filtered marker trajectories. Both decompositions used identical frequency grids, participant-specific filter widths and a diagonal perturbation of 10⁻⁶ in the narrowband covariance. GED additionally used the broadband reference covariance with 1% shrinkage. PCA decomposed the narrowband covariance alone. The full eigenspectrum was retained for effective dimensionality in both cases.')
paragraph('Eigenvalues were normalized by their sum within each frequency and participant. For GED, these percentages express relative covariance contrast; they should not be interpreted as ordinary percentages of marker variance explained. For PCA, they express the proportion of the regularized narrowband covariance variance. The comparison is shown for the No visual contact–Different music condition, as are the following re-estimation controls.')
paragraph(f"Both decompositions showed a local prominence maximum at the beat. At that frequency, the first component accounted for {report['control_first_component'][7][2]:.1f}% of the GED eigenspectrum and {report['control_first_component'][7][7]:.1f}% of the PCA eigenspectrum, with effective dimensionalities of {report['control_ED'][7][2]:.2f} and {report['control_ED'][7][7]:.2f}, respectively. Above 2 × beat, the leading PCA component gained relative weight toward 4 × beat, whereas the corresponding GED component declined.")
figure('S02_GED_PCA', 'GED and PCA network landscapes and effective dimensionality. Columns distinguish the two decompositions; upper panels show the four leading normalized eigenvalues and lower panels show effective dimensionality. Means and SEMs include all 35 dyads.', 4.1)

heading('Sensitivity to filter bandwidth')
paragraph('We repeated the position-based decomposition with Gaussian bandwidths multiplied by ¼, ½, 1, 2 and 4 relative to the primary analysis. The beat-relative frequency grid remained fixed at 32 frequencies, from beat/8 to 4 × beat in steps of beat/8. This comparison varies bandwidth while holding the sampled frequencies constant.')
paragraph('The reference width schedule reproduced the primary study implementation: the lowest requested frequency was matched to a reference grid from 0.1 to 10 Hz, with logarithmic widths from 0.01 to 1 Hz; the selected starting width was then extended logarithmically to 32 times that value. Widths were computed independently for the two partners. Narrower kernels can approach the Fourier-bin spacing of a 60-s recording (approximately 0.0167 Hz). Thus, differences in local peak sharpness must be interpreted together with finite-record spectral resolution, rather than as additional evidence for a distinct physiological timescale.')
assert all(report['control_first_component'][7][i] > max(report['control_first_component'][6][i], report['control_first_component'][8][i]) for i in range(10))
paragraph(f"The beat-associated local maximum remained visible across all five bandwidths in both decompositions. In GED, increasing the multiplier from ¼ to 4 reduced the first-component value at beat from {report['control_first_component'][7][0]:.1f}% to {report['control_first_component'][7][4]:.1f}% and increased effective dimensionality from {report['control_ED'][7][0]:.2f} to {report['control_ED'][7][4]:.2f}. The precise magnitude and dimensionality therefore depend on bandwidth even when the local peak is retained.")
figure('S03_Bandwidth_Method1', 'Bandwidth sensitivity of GED. Five panels show the first four components for the indicated bandwidth multiplier. The final panel compares effective dimensionality across bandwidths. Eigenvalue ribbons show ± SEM across 35 dyads; ED overlays show group means.', 4.0)
heading('Bandwidth sensitivity of PCA')
paragraph('The same bandwidth manipulation was applied to PCA. All other inputs and covariance conventions were unchanged, allowing the consequences of filter width to be compared across the two decompositions.')
figure('S04_Bandwidth_Method2', 'Bandwidth sensitivity of PCA. Panel organization and averaging match the preceding GED comparison. The comparison concerns bandwidth, not a separate manipulation of the frequency grid.', 6.4)

heading('Position and velocity representations')
paragraph('We next repeated the decomposition using velocity instead of marker position. Velocity was computed by taking the first temporal difference and multiplying by the sampling rate of 250 Hz, without additional smoothing. This operation yields one fewer time point. The same beat-relative frequencies, width schedule and decomposition settings were used. Where a position gap required interpolation, differences adjacent to reconstructed samples were excluded from covariance estimation.')
paragraph('Differentiation changes the relative contribution of slow and fast motion. Accordingly, this comparison assesses the dependence of network prominence and dimensionality on the kinematic representation; it does not replace the position-based estimates used in the primary coordination analyses.')
paragraph(f"Velocity retained the beat-associated peak, while increasing effective dimensionality at the upper end of the frequency range. At 4 × beat, GED dimensionality changed from {report['control_ED'][31][2]:.2f} for position to {report['control_ED'][31][10]:.2f} for velocity; PCA changed from {report['control_ED'][31][7]:.2f} to {report['control_ED'][31][11]:.2f}.")
figure('S05_Position_Velocity', 'Network landscapes from position and velocity. The upper and middle rows show position- and velocity-based GED and PCA, respectively. The bottom row compares their effective dimensionalities. All panels summarize 35 dyads in the No visual contact–Different music condition.', 4.4)

heading('Axis specific network estimation')
paragraph('To assess the contribution of each spatial dimension, we repeated GED after retaining only the X, Y or Z coordinates. Coordinates from the other dimensions were set to zero before estimation, preserving the original 66-coordinate representation and regularization convention. These controls therefore represent separate decompositions, rather than projections of the full XYZ solution onto an individual axis.')
figure('S06_Axis_Landscapes_ED', 'Axis-only GED landscapes and effective dimensionality. Rows show X-, Y- and Z-only input. The first four normalized eigenvalues are shown on the left and effective dimensionality on the right. Shading denotes ± SEM across 35 dyads.', 6.2)

heading('Spatial activation patterns across components')
paragraph('We inspected the first four components at each metric level in the full XYZ solution. Spatial patterns were converted to absolute magnitudes before trial and group averaging. For display, a common maximum across components and partners was used within each frequency and condition. This shared scale preserves magnitude differences between leading and lower-ranked components. Marker size varies inversely with the normalized SEM, following the study visualization convention. The displayed body positions are a reference configuration, not an estimate of an average pose.')
for i, level in enumerate(['beat/4', 'beat/2', 'beat', '2 × beat'], 1):
    if i > 1:
        heading('Spatial activation patterns at ' + ['one quarter beat', 'one half beat', 'the beat', 'twice the beat'][i-1])
    figure(f'S07_{i}_SpatialPatterns', f'Full XYZ spatial activation patterns at {level}. Rows show components 1–4 and columns show the X, Y and Z contributions. Colors indicate normalized absolute magnitude on a common scale across components and partners. The No visual contact–Different music condition is shown, using all 35 dyads.', 6.5 if i > 1 else 5.6)
for i, axis in enumerate(['X', 'Y', 'Z'], 1):
    heading(f'Spatial patterns from {axis} only estimation')
    paragraph(f'For the {axis}-only control, we visualized the activation pattern along the retained axis. The other coordinates were zero during estimation. The color scale is shared across components and partners within each metric level.')
    figure(f'S08_{i}_AxisPatterns', f'{axis}-only spatial activation patterns. Rows show components 1–4 and columns show beat/4, beat/2, beat and 2 × beat. The corresponding landscape is shown in the axis-specific comparison. All summaries include 35 dyads.', 6.5)

heading('Spatial similarity between the first two components')
paragraph('To quantify whether the first two components expressed similar bodily configurations, we correlated their absolute spatial activation patterns across the 66 marker coordinates, separately for each participant, frequency and trial. These correlations describe within-participant similarity between components and are distinct from the between-partner spatial coordination measure. Following the original analysis, the descriptive curve averages the available participant–trial correlations across all conditions; trials therefore receive equal weight in this figure.')
low, high = report['pattern_correlation_range']
paragraph(f'The group-mean correlations ranged from {low:.2f} to {high:.2f} across frequencies. The components therefore showed partially overlapping distributions of marker contributions without expressing identical spatial patterns. This comparison concerns activation patterns; orthogonality of decomposition filters does not require their absolute activation patterns to be uncorrelated.')
figure('S09_ComponentPatternCorrelation', 'Spatial pattern correlation between components 1 and 2 within participants. Pearson correlations were computed on absolute marker contributions and averaged across retained observations from all 35 dyads. The horizontal reference line marks zero correlation.', 3.3)

heading('Component sign indeterminacy')
paragraph('The sign of a component is arbitrary in a linear eigendecomposition. We therefore evaluated its implications for the measures retained here. For spatial coordination and the within-participant comparison above, taking absolute activation patterns makes the result invariant to a global sign reversal of either component. This convention quantifies the distribution of contribution magnitudes and does not preserve signed directional relationships between body coordinates.')
paragraph('For phase-space RQA, each partner contributes one coordinate to the joint state. Reversing the sign of either coordinate reflects the trajectory about an axis. Euclidean distances between all pairs of states, their maximum and the resulting 10%-of-maximum threshold remain unchanged. Consequently, the recurrence matrix, RR and DET are invariant to such sign reversals. This is an algebraic property of the implemented distance and threshold rule, applicable to every trial, rather than an additional empirical test of coupling.')
paragraph('These invariances do not address arbitrary rotations among exactly degenerate components or potential mismatching of components across participants. They also do not establish that recurrence in a joint trajectory uniquely identifies interpersonal coupling independently of individual dynamics.')

heading('Temporal recurrence in the first component')
paragraph('For comparison with the second component, we show the condition profiles of the first component using the same 35-dyad phase-space RQA. The factorial RR model showed effects of Visual contact, Musical input and Metric level, together with a Visual-by-Music interaction (p = .028). Interactions involving Metric level were not significant. Bonferroni-corrected follow-ups identified a Visual-by-Music interaction at beat (p = .018) and Music effects at beat/4 (p = .0214) and beat (p < .001). The localized interaction significance does not establish a difference in Visual-by-Music interactions between metric levels.')
figure(f'{phase_tag}/S10_C1_RR', 'Recurrence rate for component 1. Original-scale means and SEMs are shown across all four conditions and metric levels. Models used log RR and 35 dyads. Red and blue denote absence and presence of visual contact.', 5.4)
heading('Determinism in the first component')
paragraph('The factorial DET model showed effects of Musical input and Metric level, and a Music-by-Metric interaction (p < .001). Bonferroni-corrected Music effects occurred at beat/4 (p = .0142) and beat (p < .001). No Visual effect passed correction (2 × beat: p = .080); the overall Visual effect and Visual-by-Metric interaction were not significant.')
figure(f'{phase_tag}/S10_C1_DET', 'Determinism for component 1. Points show means and error bars denote SEMs across 35 dyads. Both the plotted values and the modeled dependent variable are on the original scale.', 5.5)
heading('Spatial coordination in the first component')
paragraph('For the first component, the raw-correlation factorial model showed effects of Visual contact and Metric level. Musical input and all interactions were nonsignificant. The Bonferroni-corrected Visual effect was significant at beat (p < .001); none of the other level-specific effects survived correction. The absence of a Visual-by-Metric interaction again limits claims of uniquely beat-specific modulation.')
figure('S10_C1_Mirror', 'Spatial coordination for component 1. Means and SEMs of raw partner-pattern correlations are shown for 35 dyads. Correlations were computed on absolute activation patterns within each trial and then averaged within dyad and condition.', 5.5)

heading('Coordination in the second component')
paragraph('We repeated the coordination analyses for the second body network using the same retained trials and settings as for the first. Temporal recurrence was computed from non-standardized network activation time series after a fourth-order, zero-phase 10-Hz low-pass filter and downsampling from 250 to 25 Hz. The interval from 10 to 45 s after recording onset was retained, using inclusive downsampled indices 251–1126 (876 samples). Each partner formed one dimension of the joint phase space; recurrences were defined by Euclidean distances strictly below 10% of the maximum joint distance. The identity diagonal was retained and the minimum diagonal length for DET was two samples.')
paragraph('For RR, the factorial model showed effects of Musical input and Metric level, but no significant effect of Visual contact or interaction. After Bonferroni correction across the four metric levels, the Musical-input effect was significant at beat/4 (p = .0440). For DET, Metric level was significant in the factorial model, whereas the overall Musical-input effect did not reach the .05 threshold (p = .107). The retained level-specific tests showed Musical-input effects at beat/4 (p = .01153) and beat (p = .00383). These follow-up results do not establish a significant Music-by-Metric interaction.')
figure(f'{phase_tag}/S10_C2_RR', 'Recurrence rate for component 2 across the four metric levels. Red and blue indicate absence and presence of visual contact, respectively. Points and error bars show original-scale means ± SEM across 35 dyads. Inferential models used log-transformed RR.', 4.9)
heading('Determinism in the second component')
figure(f'{phase_tag}/S10_C2_DET', 'Determinism for component 2. The four panels show beat/4, beat/2, beat and 2 × beat. Means and SEMs are shown on the original scale, which was also used in the inferential models. All 35 dyads are included.', 5.7)
heading('Spatial coordination in the second component')
paragraph('Spatial coordination was quantified as the Pearson correlation between the partners’ absolute activation patterns and averaged across retained trials within each dyad and condition. The raw-correlation factorial model showed effects of Visual contact and Metric level, without a reliable Musical-input effect or interaction. Bonferroni-corrected Visual-contact effects were significant at beat (p = .033) and 2 × beat (p < .001). The absence of a Visual-by-Metric interaction means that this pattern should not be interpreted as formal evidence that the Visual effect differs between metric levels.')
figure('S10_C2_Mirror', 'Spatial coordination for component 2. Points show mean raw pattern correlations and error bars denote ± SEM across 35 dyads. The inferential model used raw correlations rather than Fisher-transformed values.', 5.5)

heading('Extended statistical model comparisons')
paragraph('For each coordination outcome and component, we compared linear, quadratic and cubic representations of ordered Metric level, including interactions with Visual contact and Musical input and a random intercept for Dyad. Comparisons used maximum likelihood. With four metric levels, the cubic model spans the same fixed-effect space as the factorial representation; it does not provide an independent test that the data follow a uniquely cubic biological law.')
records = []
for component in [1, 2]:
    for outcome in ['RR', 'DET', 'Mirror']:
        path = outcome_path(component, outcome) / 'All_Meters/Polynomial_Model_Comparison.txt'
        used_statistics.add(path)
        text = path.read_text()
        model_lines = {}
        for line in text.splitlines():
            match = re.match(r'^(linear_model|quadratic_model|cubic_model)\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)', line)
            if match:
                model_lines[match[1]] = (float(match[3]), float(match[4]))
        assert len(model_lines) == 3
        records.append([f'{outcome} C{component}'] + [f'{model_lines[name][0]:.2f}' for name in ['linear_model','quadratic_model','cubic_model']])
table(['Outcome', 'Linear AIC', 'Quadratic AIC', 'Cubic AIC'], records,
      'Maximum-likelihood model comparisons. Smaller AIC indicates better relative fit. RR is log-transformed; DET and spatial correlation are untransformed.')
paragraph('The cubic model improved fit over the quadratic model for RR and DET in both components and for spatial coordination in component 1. For component-2 spatial coordination, the quadratic model improved on the linear model (likelihood-ratio χ²(4) = 17.16, p = .0018), whereas adding cubic terms did not improve fit (χ²(4) = 3.82, p = .431). A cubic model was therefore not uniformly preferred across outcomes. Factorial models are reported consistently to retain the experimental interpretation of the four metric levels.')
paragraph('The following tables report all factorial effects and all level-specific tests, including nonsignificant results. Factorial models used 560 dyad-by-condition-by-metric observations per outcome; each follow-up model used 140 dyad-by-condition observations. Bonferroni correction was applied across the four levels separately for each effect and outcome. These corrections do not cover the entire collection of supplementary analyses.')
for outcome in ['RR', 'DET', 'Mirror']:
    heading('Statistical results for ' + {'RR':'recurrence rate','DET':'determinism','Mirror':'spatial coordination'}[outcome])
    full = []
    post = []
    for component in [1,2]:
        path = outcome_path(component,outcome)
        fullfile = path/'All_Meters/Factorial_Type_III_ANOVA.csv'
        postfile = path/'PostHoc_Type_III_ANOVA_Bonferroni.csv'
        used_statistics.update([fullfile,postfile])
        full.append({r['Term']:r for r in rows(fullfile)})
        post.append({(r['Meter'],r['Term']):r for r in rows(postfile)})
    records = []
    for term in full[0]:
        values = []
        for comp in full:
            r = comp[term]
            values.append(f"{float(r['F value']):.2f}; {pcell(r['Pr(>F)'])}")
        records.append([term.replace(':',' × ')] + values)
    table(['Effect','Component 1 F; p','Component 2 F; p'],records,
          'Type III factorial tests. Numerator df = 3 for effects containing Metric and 1 otherwise; denominator df ≈ 510. P-values are not corrected across these factorial terms.')
    records=[]
    for component in [1,2]:
        for meter, label in zip(['M1','M2','M3','M4'],['Beat/4','Beat/2','Beat','2 × beat']):
            records.append([f'C{component} {label}']+[pcell(post[component-1][(meter,term)]['PValueBonferroni']) for term in ['Visual','Music','Visual:Music']])
    table(['Level','Visual p','Music p','Visual × Music p'],records,
          'Bonferroni-corrected p-values for the level-specific tests. Numerator df = 1 and denominator df ≈ 102 for each test.')
    diagnostics=[]
    for component in [1,2]:
        path=outcome_path(component,outcome)/'All_Meters/Factorial_Residual_Shapiro_Wilk.csv'
        used_statistics.add(path)
        r=rows(path)[0]
        diagnostics.append(r)
    paragraph('Shapiro–Wilk tests of the factorial-model residuals yielded ' +
        '; '.join(f"W = {float(r['W']):.3f}, p {ptext(r['PValue'])} for component {i+1}" for i,r in enumerate(diagnostics)) +
        '. These diagnostics concern model residuals, not the marginal distribution of the dependent variable. Outcome transformations were retained from the established analysis (log RR, raw DET and raw spatial correlations); they were not selected to obtain significant condition effects.')

heading('Metric prominence')
paragraph('To quantify the prominence of beat-related networks relative to the remaining frequency landscape, we used the MetricProminence function on the first component. For each participant and trial, component prominence at a requested metric level was divided by its mean prominence at nonmetric frequencies. The global measure used the mean over the available harmonic and subharmonic set with the same denominator. Theoretical levels were matched to the nearest sampled bins, with duplicate bins represented once; on the present grid, the 1/3-beat target maps to 3/8 beat.')
paragraph('Ratios were averaged across partners and then across retained trials within each dyad and condition. This measure describes individual network prominence averaged within a dyad, rather than coordination between partners. We tested Global, beat/4, beat/2, beat and 2 × beat separately using log prominence as the dependent variable, Visual contact and Musical input as fixed factors, and a random intercept for Dyad. Holm correction was applied across the five outcomes separately for each effect.')
paragraph('Visual contact increased prominence at beat/4 (F(1,102) = 10.98, Holm-corrected p = .006). No other effect survived correction. In particular, the uncorrected Visual effect at beat (p = .047) did not remain significant after correction (p = .187). Residual Shapiro–Wilk tests did not reject normality for these five models (all p ≥ .074).')
figure('S11_MetricProminence', 'Global and level-specific metric prominence. Points show arithmetic means of the original-scale ratios and error bars denote ± SEM across 35 dyads. Models used log-transformed ratios. Red and blue distinguish absence and presence of visual contact.', 3.8)
heading('Metric prominence statistical tests')
path=root/'04_MetricProminence/Component_1/R_Statistics/Tests_Holm_FiveLevels.csv'
used_statistics.add(path)
records=[]
for r in rows(path):
    label = {'Global':'Global','M1':'Beat/4','M2':'Beat/2','M3':'Beat','M4':'2 × beat'}[r['Level']]
    records.append([label+' / '+r['Term'].replace(':',' × '), f"{float(r['F value']):.2f}",pcell(r['PValueHolm'])])
table(['Outcome and effect','F(1,102)','Holm p'],records,'Complete metric-prominence tests, with correction across five outcomes separately for each effect.')

heading('Similarity between partner network landscapes')
paragraph('We next asked whether the two partners expressed similar distributions of network prominence and dimensionality across rhythmic timescales. Within each trial, we correlated the partners’ first-component eigenvalue landscapes and, separately, their quadratic Rényi entropy landscapes across all 32 frequencies. Frequencies were aligned by each partner’s own beat multiple rather than absolute Hz. Thus, partners listening to different songs were compared at corresponding relative rhythmic levels without interpolation or re-estimation.')
paragraph('Signed correlations were Fisher-transformed before averaging across trials. The resulting dyad-by-condition values were tested in Visual-contact × Musical-input models with random intercepts for Dyad. Holm correction was applied across the two outcomes separately for each effect. For visualization, means and SEM bounds were transformed back to the correlation scale. The entropy outcome uses H₂, not effective dimensionality itself; correlation is not invariant to their nonlinear relationship.')
paragraph('Both Visual contact and shared Musical input increased landscape similarity. For component prominence, the Visual and Music effects were F(1,102) = 14.84 and 17.88, respectively (both Holm-corrected p < .001). For entropy, the corresponding effects were F(1,102) = 16.06 and 21.82 (both p < .001). Neither interaction was significant. Residual normality was rejected for both outcomes despite Fisher transformation (both Shapiro–Wilk p < .001), which limits reliance on the model-based p-values and should be retained as a qualification.')
figure('S12_LandscapeSimilarity', 'Between-partner landscape similarity. Left: first-component normalized eigenvalue landscape. Right: quadratic Rényi entropy landscape. Means and SEM bounds were computed in Fisher-z space and back-transformed for display. All 35 dyads are included.', 3.2)
path=root/'05_LandscapeSimilarity/Component_1/R_Statistics/Tests_Holm_TwoOutcomes.csv'
used_statistics.add(path)
records=[[r['Outcome']+' / '+r['Term'].replace(':',' × '),f"{float(r['F value']):.2f}",pcell(r['PValueHolm'])] for r in rows(path)]
heading('Landscape similarity statistical tests')
table(['Outcome and effect','F(1,102)','Holm p'],records,'Complete landscape-similarity tests, corrected across two outcomes separately for each effect.')

heading('Reproducibility of supplementary analyses', False)
paragraph('All control estimates were generated independently for the 1,119 retained trials. The unmodified-width GED eigenspectrum was checked against the saved primary core estimate for every trial; the maximum absolute discrepancy was ' + f"{report['maximum_baseline_error']:.2g}" + ' percentage points. Complete eigenspectra were retained for effective dimensionality. Compact covariance calculations were validated against the original time-domain implementations, including participant-specific widths, axis-only inputs, velocity and reconstructed gaps. No primary network estimates or RQA outputs were overwritten.')
paragraph('The supplementary MATLAB workflow generates the numerical controls and all figure panels. The main and supplementary R scripts generate the inferential models, diagnostics and condition summaries used here. The accompanying figure archive contains publication PNG and PDF copies, while the statistical archive preserves the complete factorial, polynomial and follow-up outputs. JRQA and historical 33-dyad comparisons are not included in this supplement.')

# Remove inherited template paragraph rules, including Word's title border.
for tree in [doc.element, doc.styles.element]:
    for border in tree.xpath('.//w:pBdr'):
        border.getparent().remove(border)
doc.save(destination)
archive = output / (destination.stem + '_Figures.zip')
if not archive.exists():
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for path in sorted(figures.glob('*')) + sorted((figures / phase_tag).glob('*')):
            if path.parent == figures and re.fullmatch(r'S10_C[12]_(RR|DET)', path.stem):
                continue
            if path.suffix in ['.png','.pdf']:
                z.write(path,path.name)
archive = output / (destination.stem + '_Statistics.zip')
if not archive.exists():
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for component in [1,2]:
            for outcome in ['RR','DET','Mirror']:
                folder=outcome_path(component,outcome)
                for path in sorted(folder.rglob('*')):
                    if path.suffix in ['.csv','.txt']:
                        z.write(path,str(path.relative_to(stats)))
        for name in ['04_MetricProminence','05_LandscapeSimilarity']:
            for path in sorted((root/name/'Component_1/R_Statistics').glob('*')):
                if path.suffix in ['.csv','.txt']:
                    z.write(path,str(path.relative_to(root)))
print(f'Created {destination}; {figure_number} figures, {table_number} tables.')
