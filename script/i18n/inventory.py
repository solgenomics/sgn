#!/usr/bin/env python3
"""Read a pinned SGN Git tree; write auditable localization inventory outside Git."""
import argparse
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess
from collections import Counter

from extract import regions, tokens, ExtractionError, is_mason_source
from r_discovery import discover_r, source_position

TEXT_SUFFIXES = {'.mas','.pm','.pl','.js','.tt','.tmpl','.html','.htm','.md','.txt','.conf','.cfg','.ini','.yaml','.yml','.json','.xml','.tex','.css','.scss','.R','.r','.Rmd','.sh','.po','.pot'}
MAX_TEXT_BYTES = 2 * 1024 * 1024
MAX_EXCERPT = 240
VENDOR_PART = re.compile(r'^(?:jquery|bootstrap|d3(?:-|$)|flot|jstree|MochiKit|Dynarch|Prototype|JSAN|JBrowse|gbrowse|yui|YUI|kinetic|buttons|leaflet|esri|flatpickr|fullcalendar|moment|MathJax|colorbox|DataTables|datatables)',re.I)
SQL = re.compile(r'^\s*(?:select|insert|update|delete|create|alter|drop|with|grant|set)\b.+\b(?:from|into|table|where|join|values|view|select)\b',re.I|re.S)


def git(repository, *args):
    return subprocess.check_output(['git','-C',str(repository),*args])


def canonical(value):
    return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':'))


def pinned_files(repository, revision):
    commit = git(repository,'rev-parse','--verify',revision+'^{commit}').decode().strip()
    rows = []
    for entry in git(repository,'ls-tree','-r','-l','-z',commit).split(b'\0'):
        if not entry:
            continue
        metadata,path = entry.split(b'\t',1)
        mode,kind,blob,size = metadata.decode().split()
        rows.append({'path':path.decode('utf-8'),'git_mode':mode,'git_kind':kind,
                     'git_blob':blob,'bytes':int(size) if size!='-' else None})
    return commit, sorted(rows,key=lambda row:row['path'])


def category(path,mode):
    p = Path(path)
    if mode=='160000': return 'external_repository','git_submodule'
    if mode=='120000': return 'symlink','git_symlink'
    if path.startswith(('t/','tests/','test/','js/test/','support_data/')): return 'fixture_or_reference_data','fixture_root'
    if path=='static/js/sgn-i18n.js': return 'vendor_with_application_facade','pinned_jed_plus_facade'
    vendor_asset=p.suffix in ('.js','.css','.scss') and (any(VENDOR_PART.match(part) for part in p.parts[1:-1]) or VENDOR_PART.match(p.name))
    if path.startswith(('node_modules/','js/node_modules/','features/gbrowse2/')) or vendor_asset:
        return ('vendor_generated' if '.min.' in p.name else 'vendor'),'recognized_vendor_path'
    if path.startswith(('js/build/','js/build_test/','docs/_site/')) or '.min.' in p.name:
        return 'generated','generated_path_or_filename'
    if p.suffix in ('.po','.pot'): return 'gettext_catalog_source','gettext_source_extension'
    if is_mason_source(path): return 'mason_template','mason_extension' if p.suffix=='.mas' else 'reviewed_mason_special_component'
    if p.suffix in ('.R','.r'): return 'r_source','R_source_extension'
    if p.suffix not in TEXT_SUFFIXES and p.name not in ('README','Dockerfile','Build.PL','Makefile.PL'):
        return 'asset','non_source_extension'
    if path.startswith('lib/SGN/Controller/') and p.suffix=='.pm': return 'controller','native_controller_root'
    if path.startswith('cgi-bin/') and p.suffix=='.pl': return 'legacy_cgi','native_cgi_root'
    if p.suffix in ('.pm','.pl'): return 'perl_source','perl_extension'
    if p.suffix=='.js': return 'javascript_source','javascript_extension'
    if path.startswith('docs/') or p.suffix in ('.md','.Rmd','.tex'): return 'documentation','docs_root_or_extension'
    if p.suffix in ('.html','.htm','.tt','.tmpl'): return 'other_template','template_extension'
    if p.suffix in ('.conf','.cfg','.ini','.yaml','.yml','.json','.xml') or path.startswith(('.github/','deployment/')):
        return 'configuration_or_structured_data','structured_file_extension'
    return 'other_text','other_text_source'


class Blobs:
    """Stream Git objects, including binary hashes, without source snapshots."""
    def __init__(self,repository):
        self.process=subprocess.Popen(['git','-C',str(repository),'cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
        self.cache={}
    def read(self,blob,want_text):
        if blob in self.cache and (not want_text or self.cache[blob][1] is not None):
            return self.cache[blob]
        self.process.stdin.write((blob+'\n').encode());self.process.stdin.flush()
        header=self.process.stdout.readline().decode().split()
        if len(header)!=3 or header[1]!='blob': raise ValueError('unreadable Git blob')
        remaining=int(header[2]);data=[];digest=hashlib.sha256()
        keep=want_text and remaining<=MAX_TEXT_BYTES
        while remaining:
            block=self.process.stdout.read(min(remaining,1024*1024))
            if not block: raise ValueError('truncated Git object stream')
            digest.update(block)
            if keep:data.append(block)
            remaining-=len(block)
        if self.process.stdout.read(1)!=b'\n':raise ValueError('invalid Git object stream separator')
        raw=b''.join(data) if keep else None
        self.cache[blob]=(digest.hexdigest(),raw)
        return self.cache[blob]
    def close(self):
        self.process.stdin.close();self.process.stdout.close();self.process.wait()


def human_text(value):
    value=html.unescape(value).strip()
    if not value or len(value)>4096 or not re.search(r'[A-Za-z\u00c0-\uffff]{2}',value):return False
    if SQL.search(value) or (re.fullmatch(r'[A-Za-z0-9_.:/\\@+%=-]+',value) and any(ch in value for ch in '_./\\@')):return False
    if re.search(r'(?:BEGIN (?:RSA |OPENSSH )?PRIVATE KEY|Bearer\s+[A-Za-z0-9._-]{15,}|(?:password|api[_-]?key|secret)\s*[:=]\s*\S{8,})',value,re.I):return False
    return True


def candidate(path,sha,position,text,kind,source,evidence):
    line=source[:position].count('\n')+1
    excerpt=' '.join(text.split())[:MAX_EXCERPT]
    identity=hashlib.sha256((path+'\0'+str(position)+'\0'+kind+'\0'+text).encode()).hexdigest()
    return {'id':identity,'path':path,'content_sha256':sha,'line':line,'column':position-source.rfind('\n',0,position),
            'kind':kind,'text_excerpt':excerpt,'text_sha256':hashlib.sha256(text.encode()).hexdigest(),
            'evidence':evidence,'classification':'human_text_candidate','needs_review':True,
            'counts_as_coverage_denominator':False}


class Markup(HTMLParser):
    def __init__(self,path,sha,masked,original):
        super().__init__(convert_charrefs=True)
        self.path,self.sha,self.masked,self.original=path,sha,masked,original
        self.lines=[0]
        for m in re.finditer('\n',masked):self.lines.append(m.end())
        self.skip=0;self.records=[]
    def position(self):
        line,column=self.getpos();return self.lines[line-1]+column
    def handle_starttag(self,tag,attrs):
        if tag in ('script','style','code','pre'):self.skip+=1
        if not self.skip:
            for name,value in attrs:
                if name in ('title','placeholder','aria-label','alt') and value and human_text(value):
                    self.records.append(candidate(self.path,self.sha,self.position(),value,'markup_attribute',self.original,'HTMLParser '+tag+'.'+name))
    def handle_endtag(self,tag):
        if tag in ('script','style','code','pre') and self.skip:self.skip-=1
    def handle_data(self,value):
        if not self.skip and human_text(value):
            self.records.append(candidate(self.path,self.sha,self.position(),value,'markup_text',self.original,'HTMLParser text node; dynamic/data ownership not inferred'))


def scan_code(path,sha,text):
    records=[];marked=[];gaps=[];excluded=Counter()
    suffix='.mas' if is_mason_source(path) else Path(path).suffix
    try:chunks=regions(text,suffix)
    except ExtractionError as error:
        chunks=[];gaps.append({'path':path,'kind':'embedded_language_parse_gap','evidence':str(error),'needs_review':True})
    aliases=set(re.findall(r'\b(?:my\s+)?\$(\w+)\s*=\s*\$\w+(?:->\w+)*->i18n\b',text))
    for offset,source,language in chunks:
        try:ts=list(tokens(source,language))
        except ExtractionError as error:
            gaps.append({'path':path,'line':text[:offset].count('\n')+1,'kind':'lexical_parse_gap','evidence':str(error),'needs_review':True});continue
        marked_positions=set()
        for i,(kind,name,pos) in enumerate(ts):
            if kind!='name' or name not in ('p','np') or i<2 or i+1>=len(ts) or ts[i-1][1] not in ('.','->') or ts[i+1][1]!='(':continue
            receiver=ts[i-2][1]
            prefix=source[max(0,pos-90):pos]
            known=receiver in aliases or receiver=='i18n' or bool(re.search(r'->i18n(?:\(\))?\s*->\s*$',prefix))
            if not known:continue
            required=2 if name=='p' else 3;j=i+2;args=[];valid=True
            for k in range(required):
                if j>=len(ts) or ts[j][0]!='string':valid=False;break
                args.append(ts[j][1]);marked_positions.add(j);j+=1
                if k<required-1:
                    if j>=len(ts) or ts[j][1]!=',':valid=False;break
                    j+=1
            if not valid or j>=len(ts) or ts[j][1] not in (',',')'):
                gaps.append({'path':path,'line':text[:offset+pos].count('\n')+1,'kind':'dynamic_marked_call','evidence':'nonliteral '+name+' source arguments','needs_review':True});continue
            marked.append({'path':path,'content_sha256':sha,'line':text[:offset+pos].count('\n')+1,
                           'context':args[0],'source':args[1],'plural':args[2] if name=='np' else None,
                           'evidence':'literal marked '+language+' call; recognized i18n receiver','classification':'instrumented_source_occurrence'})
        for i,(kind,value,pos) in enumerate(ts):
            if kind not in ('string','dynamic') or i in marked_positions:continue
            if SQL.search(value):excluded['sql_or_query_literal']+=1;continue
            prefix=source[max(0,pos-100):pos]
            if re.search(r'(?:password|dbpass|api[_-]?key|secret|access[_-]?token)[\'"]?\s*(?:=>|=)\s*$',prefix,re.I):
                excluded['sensitive_assignment_literal']+=1;continue
            if human_text(value):
                records.append(candidate(path,sha,offset+pos,value,'dynamic_string' if kind=='dynamic' else 'code_string',text,'bounded '+language+' string lexer; user-facing use not inferred'))
        if language=='perl' and re.search(r'\bq[qwrx]?\s*[({\[/]|<<\s*[\'"]?[A-Za-z_]',source):
            gaps.append({'path':path,'line':text[:offset].count('\n')+1,'kind':'unsupported_quote_like_or_heredoc','evidence':'bounded scanner cannot establish complete Perl string coverage','needs_review':True})
    if suffix=='.mas':
        masked=list(text)
        for offset,source,_ in chunks:
            for i in range(offset,offset+len(source)):
                if masked[i]!='\n':masked[i]=' '
        # Remove Mason delimiters/comments, retaining line positions for HTMLParser.
        joined=''.join(masked)
        joined=re.sub(r'<%doc>.*?</%doc>',lambda m:''.join('\n' if ch=='\n' else ' ' for ch in m.group()),joined,flags=re.S)
        parser=Markup(path,sha,joined,text)
        try:parser.feed(joined);records.extend(parser.records)
        except Exception as error:gaps.append({'path':path,'kind':'markup_parse_gap','evidence':type(error).__name__,'needs_review':True})
    return records,marked,gaps,dict(excluded)


def r_candidates(path, sha, text, parsed):
    """R constants are source evidence, not translated-message identities."""
    records=[];excluded=Counter()
    for record in parsed['records']:
        if record['sensitiveAssignment']:
            reason=record.get('protectionReason')
            excluded['credential_call_literal_review' if reason=='external_credential_call_review' else 'sensitive_assignment_literal']+=1
            continue
        value=record['value']
        if SQL.search(value):
            excluded['sql_or_query_literal']+=1
            continue
        if human_text(value):
            position=source_position(text,record['line'],record['column'])
            records.append(candidate(path,sha,position,value,'R_literal_string',text,
                'R 4.5.0 parse/getParseData STR_CONST; source parsed as data; user-facing use not inferred'))
    return records,dict(excluded)


def literal_argument(value):
    match=re.fullmatch(r'\s*([\'"])(.*?)\1\s*',value or '',re.S)
    return match.group(2) if match else None


def routes(path,sha,text):
    result=[]
    if path.startswith('cgi-bin/') and path.endswith('.pl'):
        return [{'path':path,'content_sha256':sha,'line':1,'kind':'cgi_dispatcher_candidate','url_candidate':'/'+path[len('cgi-bin/'):],
                 'resolution':'requires_runtime_dispatcher_configuration','needs_review':True,'evidence':'tracked .pl beneath cgi_root; not proof of enabled/reachable route'}]
    if not path.startswith('lib/SGN/Controller/') or not path.endswith('.pm'):return []
    configuration=re.search(r'__PACKAGE__\s*->\s*config\s*\((.*?)\)\s*;',text,re.S)
    explicit=re.search(r'\bnamespace\s*=>\s*([\'"])(.*?)\1',configuration.group(1),re.S) if configuration else None
    namespace=explicit.group(2) if explicit else None
    for match in re.finditer(r'^[ \t]*sub\s+(\w+)\b',text,re.M):
        name=match.group(1);start=match.end(1);end=start;quote=None;depth=0
        while end<len(text) and end-start<2048:
            ch=text[end]
            if quote:
                if ch=='\\':end+=2;continue
                if ch==quote:quote=None
            elif ch in "'\"":quote=ch
            elif ch=='(':depth+=1
            elif ch==')':depth-=1
            elif ch in '{;' and depth==0:break
            end+=1
        signature=text[start:end]
        if ':' not in signature:continue
        attrs=[]
        for attr in re.finditer(r':\s*([A-Za-z]\w*)\s*(?:\(([^)]*)\))?',signature):
            attrs.append({'name':attr.group(1),'argument':attr.group(2),'literal':literal_argument(attr.group(2))})
        if not attrs:continue
        mapping={a['name']:a for a in attrs}
        row={'path':path,'content_sha256':sha,'line':text[:match.start()].count('\n')+1,'action':name,
             'namespace_literal':namespace,'attributes':attrs,'needs_review':True,'evidence':'bounded Catalyst action declaration scanner; runtime registration not asserted'}
        if 'Private' in mapping:row.update(kind='private_action',resolution='not_a_public_route')
        elif 'Chained' in mapping or 'PathPart' in mapping:row.update(kind='chained_action',resolution='chain_resolution_requires_runtime')
        elif 'Path' in mapping:
            value=mapping['Path']['literal']
            if value is not None and value.startswith('/'):
                row.update(kind='literal_path_action',url_candidate=value or '/',resolution='literal_path_with_argument_family')
            elif value is not None and namespace is not None:
                row.update(kind='literal_path_action',url_candidate='/'+ '/'.join(p for p in (namespace,value) if p),resolution='literal_namespace_and_path_with_argument_family')
            else:row.update(kind='dynamic_or_implicit_path_action',resolution='dynamic_argument_or_Catalyst_namespace_requires_runtime')
        elif 'Local' in mapping or 'Global' in mapping or 'LocalRegex' in mapping or 'Regex' in mapping:
            row.update(kind='implicit_or_regex_action',resolution='Catalyst_registration_requires_runtime')
        else:row.update(kind='other_action_declaration',resolution='attribute_semantics_requires_runtime')
        result.append(row)
    return result


def documentation_candidates(path,sha,text):
    if Path(path).suffix in ('.html','.htm','.tt','.tmpl'):
        parser=Markup(path,sha,text,text);parser.feed(text);return parser.records
    records=[];offset=0;code=False
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith('```'):code=not code
        if not code and (re.match(r'^#{1,6}\s+\S',line) or re.match(r'^\\(?:chapter|section|subsection)\{',line)) and human_text(line):
            records.append(candidate(path,sha,offset,line.strip(),'documentation_heading',text,'source heading; document audience and translation scope require review'))
        offset+=len(line)
    return records


def write_jsonl(path,rows):
    with path.open('w',encoding='utf-8') as handle:
        for row in rows:handle.write(canonical(row)+'\n')


def pot_messages(text):
    """Read the generated source POT's literal fields; never executable callbacks."""
    records=[];record={};field=None
    for line in text.splitlines()+['']:
        if not line.strip():
            if record.get('msgid'):records.append((record.get('msgctxt',''),record['msgid'],record.get('msgid_plural')))
            record={};field=None;continue
        match=re.match(r'^(msgctxt|msgid|msgid_plural)\s+(".*")$',line)
        if match:
            field=match.group(1);record[field]=json.loads(match.group(2))
        elif line.startswith('"') and field:record[field]+=json.loads(line)
        elif not line.startswith('#'):field=None
    return records


def audit(repository,revision,output):
    repository=repository.resolve();output=output.resolve()
    if output==repository or output.is_relative_to(repository):raise ValueError('changing reports must be outside the Git source tree')
    if output.exists() and any(output.iterdir()):raise ValueError('refusing to overwrite a nonempty report directory')
    commit,files=pinned_files(repository,revision)
    output.mkdir(parents=True,exist_ok=True)
    candidates=[];instrumented=[];route_rows=[];gaps=[];catalog_messages=set();blob_reader=Blobs(repository)
    category_counts=Counter();excluded=Counter();r_pending=[];r_success=0;r_literals=0
    try:
        for row in files:
            path=row['path'];kind,evidence=category(path,row['git_mode']);row.update(category=kind,classification_evidence=evidence,
                source_revision=commit,classification_status='proposed',needs_review=True)
            category_counts[kind]+=1
            code=kind in ('controller','legacy_cgi','perl_source','javascript_source','mason_template')
            scan=code or kind=='r_source' or kind in ('documentation','other_template') or Path(path).suffix=='.pot'
            if row['git_kind']!='blob':row.update(content_sha256=None,scan_status='external_reference_not_read');continue
            # Always request bounded text for text extensions, so a duplicate blob
            # first seen as an asset cannot lose later source scanning.
            sha,raw=blob_reader.read(row['git_blob'],scan)
            row['content_sha256']=sha
            if not scan:row['scan_status']='metadata_only_'+kind;continue
            if raw is None:row['scan_status']='scan_size_limit';gaps.append({'path':path,'kind':'size_limit','needs_review':True});continue
            try:text=raw.decode('utf-8')
            except UnicodeDecodeError:row['scan_status']='encoding_review';gaps.append({'path':path,'kind':'non_utf8_source','needs_review':True});continue
            if '\x00' in text:row['scan_status']='binary_content';gaps.append({'path':path,'kind':'binary_source_extension','needs_review':True});continue
            if kind=='r_source':
                row['scan_status']='r_ast_discovery_pending'
                row['instrumented_occurrences']=None
                r_pending.append((row,text))
            elif Path(path).suffix=='.pot':
                try:catalog_messages.update(pot_messages(text));row['scan_status']='source_catalog_fields_read'
                except (ValueError,TypeError):
                    row['scan_status']='catalog_parse_review';gaps.append({'path':path,'kind':'unsupported_POT_syntax','needs_review':True})
            elif code:
                found,marks,missing,skipped=scan_code(path,sha,text)
                candidates.extend(found);instrumented.extend(marks);gaps.extend(missing);excluded.update(skipped)
                row['scan_status']='bounded_scan_with_gaps' if missing else 'bounded_scan_no_detected_gap'
                row['human_text_candidates']=len(found);row['instrumented_occurrences']=len(marks)
            else:
                found=documentation_candidates(path,sha,text);candidates.extend(found)
                row.update(scan_status='heading_or_markup_scan_only',human_text_candidates=len(found))
            route_rows.extend(routes(path,sha,text))
    finally:blob_reader.close()

    # Batch the pinned source through one qualified parser process. A missing
    # helper or malformed source remains explicit per-file review evidence.
    for start in range(0,len(r_pending),256):
        group=r_pending[start:start+256]
        try:
            parsed=discover_r([{'file':row['path'],'source':text} for row,text in group])
        except ExtractionError as error:
            for row,_ in group:
                row['scan_status']='r_ast_parser_review'
                gaps.append({'path':row['path'],'content_sha256':row['content_sha256'],'kind':'R_parser_unavailable_or_incompatible',
                    'evidence':str(error),'needs_review':True})
            continue
        for row,text in group:
            result=parsed[row['path']]
            if not result['ok']:
                row['scan_status']='r_ast_parse_review'
                gaps.append({'path':row['path'],'content_sha256':row['content_sha256'],'kind':'R_source_parse_gap',
                    'evidence':result['error'],'line':result.get('errorLine'),'column':result.get('errorColumn'),
                    'parser_version':result['parserVersion'],'needs_review':True})
                continue
            found,skipped=r_candidates(row['path'],row['content_sha256'],text,result)
            candidates.extend(found);excluded.update(skipped)
            row.update(scan_status='r_ast_literal_discovery_only',human_text_candidates=len(found))
            r_success+=1;r_literals+=len(result['records'])
            gaps.append({'path':row['path'],'kind':'R_marked_message_discovery_not_reconciled',
                'evidence':'R AST constants discovered; exact explicit R marked-call compilation remains separate from bounded inventory discovery',
                'needs_review':True})

    messages={}
    for mark in instrumented:
        key=(mark['context'],mark['source'],mark['plural'])
        messages.setdefault(key,{'context':key[0],'source':key[1],'plural':key[2],'references':[]})['references'].append(mark['path']+':'+str(mark['line']))
    message_rows=[messages[key] for key in sorted(messages,key=lambda k:(k[0],k[1],k[2] or ''))]
    summary={'schema':1,'source_revision':commit,'working_tree_used':False,'tracked_paths':len(files),
             'method_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
             'extractor_sha256':hashlib.sha256(Path(__file__).with_name('extract.py').read_bytes()).hexdigest(),
             'R_discovery':{'source_files':len(r_pending),'parsed_files':r_success,'review_files':len(r_pending)-r_success,
                            'literal_records':r_literals,'marked_message_discovery_reconciled':False,
                            'module_sha256':hashlib.sha256(Path(__file__).with_name('r_discovery.py').read_bytes()).hexdigest(),
                            'helper_sha256':hashlib.sha256(Path(__file__).with_name('r_discover.R').read_bytes()).hexdigest()},
             'files_by_category':dict(sorted(category_counts.items())),
             'scan_statuses':dict(sorted(Counter(row['scan_status'] for row in files).items())),
             'instrumentation':{'recognized_source_occurrences':len(instrumented),'recognized_unique_literal_messages':len(messages),
                                'unique_source_catalog_messages':len(catalog_messages),
                                'meaning':'source evidence; not qualified workflows'},
             'human_text_candidate_records':len(candidates),'candidate_kinds':dict(sorted(Counter(r['kind'] for r in candidates).items())),
             'candidate_coverage_denominator':None,'coverage_percentage':None,
             'coverage_reason':'candidates and file census require human scope/classification; no audited denominator',
             'route_records':len(route_rows),'route_kinds':dict(sorted(Counter(r['kind'] for r in route_rows).items())),
             'route_resolutions':dict(sorted(Counter(r['resolution'] for r in route_rows).items())),
             'route_meaning':'action/dispatcher evidence, not page counts or proof of enabled routes',
             'detected_review_gaps':len(gaps),'excluded_string_signals':dict(sorted(excluded.items())),
             'workflow_qualification':[],'workflow_qualification_reason':'requires separate test evidence; not inferred from messages'}
    for name,rows in [('files',files),('candidates',candidates),('instrumented',instrumented),('messages',message_rows),('routes',route_rows),('gaps',gaps)]:
        write_jsonl(output/(name+'.jsonl'),rows)
    (output/'summary.json').write_text(canonical(summary)+'\n',encoding='utf-8')
    columns=['path','category','git_blob','content_sha256','bytes','scan_status','needs_review']
    with (output/'file-census.tsv').open('w',encoding='utf-8') as handle:
        handle.write('\t'.join(columns)+'\n')
        for row in files:handle.write('\t'.join(str(row.get(key,'')).replace('\t','\\t').replace('\n','\\n') for key in columns)+'\n')
    return summary


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository',type=Path,default=Path.cwd())
    parser.add_argument('--revision',required=True,help='commit/ref resolved once, then Git blobs only')
    parser.add_argument('--output',type=Path,required=True,help='new/empty report directory outside Git')
    args=parser.parse_args()
    result=audit(args.repository,args.revision,args.output)
    print(canonical({'source_revision':result['source_revision'],'tracked_paths':result['tracked_paths'],
                     'instrumentation':result['instrumentation'],'route_records':result['route_records'],
                     'candidate_records':result['human_text_candidate_records'],'review_gaps':result['detected_review_gaps'],
                     'coverage_percentage':None,'output':str(args.output.resolve())}))


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,subprocess.CalledProcessError) as error:raise SystemExit(str(error))
