"""Explicit literal R message compilation through trusted source-as-data ASTs."""
import json
import os
from pathlib import Path
import subprocess

from extract import ExtractionError


def extract_r(file, source):
    configured = os.environ.get('SGN_I18N_R_EXTRACT_COMMAND')
    if configured:
        try:
            command = json.loads(configured)
        except ValueError as error:
            raise ExtractionError('SGN_I18N_R_EXTRACT_COMMAND must be a JSON argv array') from error
        if not isinstance(command, list) or not command or any(not isinstance(arg, str) or not arg or '\x00' in arg for arg in command):
            raise ExtractionError('SGN_I18N_R_EXTRACT_COMMAND must be a nonempty JSON argv array')
    else:
        command = ['Rscript', '--vanilla', str(Path(__file__).with_name('r_extract.R'))]
    if not isinstance(source, str) or len(source.encode('utf-8')) > 2 * 1024 * 1024:
        raise ExtractionError('Invalid or oversized R extraction source')
    try:
        run = subprocess.run(command, input=json.dumps({'schema': 1, 'file': file, 'source': source}, ensure_ascii=False),
                             text=True, encoding='utf-8', capture_output=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ExtractionError('R explicit extraction unavailable; configure qualified SGN_I18N_R_EXTRACT_COMMAND') from error
    if run.returncode:
        # R diagnostics can echo source. Only recognized tool-owned categories
        # are returned to compiler users; raw stderr never enters reports.
        categories = ['R source syntax is unsupported', 'R marked message arguments must be whole literal strings',
                      'Unsupported mutation of an R translator receiver', 'Unsupported computed R translator method',
                      'Unsupported R translator method alias', 'Unsupported partial or duplicate R message argument',
                      'Missing R literal message arguments', 'Empty R English source', 'Unsupported missing R message argument',
                      'Unsupported extra R message argument']
        category = next((label for label in categories if '\nError: ' + label + '\n' in '\n' + run.stderr), 'Unsupported or ambiguous R translator binding')
        raise ExtractionError(category + ' in ' + file)
    try:
        payload = json.loads(run.stdout)
    except ValueError as error:
        raise ExtractionError('R extraction helper returned invalid JSON') from error
    if (not isinstance(payload, dict) or type(payload.get('schema')) is not int or payload['schema'] != 1
            or payload.get('parser') != 'R explicit messages' or (payload.get('parserVersion'), payload.get('jsonVersion')) not in {('4.5.0', '2.0.0'), ('4.5.1', '1.8.7')} or not isinstance(payload.get('records'), list)):
        raise ExtractionError('R extraction helper returned an incompatible protocol')
    for record in payload['records']:
        if (not isinstance(record, dict) or not isinstance(record.get('context'), str)
                or not isinstance(record.get('source'), str) or not record['source']
                or (record.get('plural') is not None and (not isinstance(record['plural'], str) or not record['plural']))
                or not isinstance(record.get('reference'), str) or not record['reference'].startswith(file + ':')
                or not record['reference'][len(file) + 1:].isdigit()):
            raise ExtractionError('R extraction helper returned invalid literal records')
    return payload['records']
