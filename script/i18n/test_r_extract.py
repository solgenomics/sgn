#!/usr/bin/env python3
"""Actual R literal extraction, lexical binding and no-execution gates."""
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from extract import extract_file, ExtractionError
from r_extract import extract_r


class RExtractionTests(unittest.TestCase):
    def records(self, source, suffix='.R'):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); path=root/('fixture'+suffix);path.write_text(source)
            return extract_file(path,root)

    def test_constructed_alias_direct_and_named_calls_preserve_references(self):
        source='''tr <- sgn_i18n(locale="uk")
alias <- tr
alias$p("button.save", "Save")
tr$np(context="count", singular="%{count} stock", plural="%{count} stocks", count=n, vars=list(count=n))
sgn_i18n_from_payload(payload)$p("direct", "Direct source")
'''
        for suffix in ['.R','.r']:
            with self.subTest(suffix=suffix):
                rows=self.records(source,suffix)
                self.assertEqual([row['context'] for row in rows],['button.save','count','direct'])
                self.assertEqual(rows[1]['plural'],'%{count} stocks')
                self.assertEqual([row['reference'] for row in rows],['fixture'+suffix+':3','fixture'+suffix+':4','fixture'+suffix+':5'])

    def test_function_scopes_and_proven_widget_exclusion(self):
        source='''outside <- sgn_i18n()
render <- function(payload) {
  inside <- sgn_i18n_from_payload(payload)
  inside$p("inside", "Inside source")
  outside$p("outer", "Outer source")
}
widget <- list(p=function(...) NULL)
widget$p("widget", dynamic)
'''
        self.assertEqual([row['context'] for row in self.records(source)],['inside','outer'])

    def test_comments_raw_literal_data_and_application_calls_are_not_executed(self):
        source='''stop("APPLICATION_SOURCE_MUST_NOT_RUN")
library(package_that_does_not_exist)
# tr$p("fake.comment", "Ignored")
example <- r"(tr$p("fake.literal", "Ignored"))"
tr <- sgn_i18n()
tr$p("", "Вітаємо 🌱")
'''
        rows=self.records(source)
        self.assertEqual([(row['context'],row['source']) for row in rows],[('','Вітаємо 🌱')])

    def test_CRLF_and_tabs_keep_original_line_numbers(self):
        rows=self.records('tr <- sgn_i18n()\r\n\ttr$p("unicode", "𝛂 source")\r\n')
        self.assertEqual(rows[0]['reference'],'fixture.R:2')

    def test_quoted_and_backtick_literal_method_names_are_marked(self):
        rows = self.records('''tr <- sgn_i18n()
tr$"p"("quoted", "Quoted source")
tr$`p`("backtick", "Backtick source")
tr$'np'("count", "one", "many", n)
`translator with spaces` <- `sgn_i18n`()
`translator with spaces`$`p`(`context`="named", `source`="Named source")
''')
        self.assertEqual([(row['context'], row['source'], row['plural']) for row in rows],
                         [('quoted', 'Quoted source', None), ('backtick', 'Backtick source', None),
                          ('count', 'one', 'many'), ('named', 'Named source', None)])
        for source in ['tr$"p"("ctx", dynamic)', 'tr$"np"("ctx", "one", dynamic, n)',
                       'method <- tr$"p"; method("ctx", "Text")']:
            with self.subTest(source=source), self.assertRaises(ExtractionError):
                self.records('tr <- sgn_i18n(); ' + source)
        for source in ['`tr` <- sgn_i18n(); f <- function(`tr`) tr$p("ctx", "Text")',
                       '`sgn_i18n` <- function(...) list(); tr <- sgn_i18n(); tr$p("ctx", "Text")',
                       '`tr` <- sgn_i18n(); for (`tr` in values) tr$p("ctx", "Text")',
                       'tr <- `sgn_i18n`(); eval(parse(text="tr <- list()")); tr$p("ctx", "Text")']:
            with self.subTest(source=source), self.assertRaises(ExtractionError):
                self.records(source)

    def test_exact_named_arguments_match_before_positional_arguments(self):
        rows = self.records('''tr <- sgn_i18n()
tr$p("Text", context="ctx")
tr$p(source="Other text", "other")
tr$np("one", "many", n, context="count")
tr$np(plural="plural", "plural.ctx", n, singular="singular")
''')
        self.assertEqual([(row['context'], row['source'], row['plural']) for row in rows],
                         [('ctx', 'Text', None), ('other', 'Other text', None),
                          ('count', 'one', 'many'), ('plural.ctx', 'singular', 'plural')])

    def test_explicit_missing_arguments_and_extra_positionals_fail(self):
        for statement in ['tr$p("ctx", "Text",,)', 'tr$p("ctx", "Text",)',
                          'tr$np("ctx", "one", "many", n,,)',
                          'tr$p(context="ctx",source="Text",vars=)',
                          'tr$p(,"Text")', 'tr$p("ctx","Text",list(),1)',
                          'tr$p()', 'tr$np()']:
            with self.subTest(statement=statement), self.assertRaises(ExtractionError):
                self.records('tr <- sgn_i18n(); ' + statement)

    def test_dynamic_marked_sources_partial_duplicate_and_missing_args_fail(self):
        for statement in ['tr$p("ctx", source)', 'tr$p(context, "Text")', 'tr$p("ctx", paste("Text",name))',
                          'tr$p("ctx", "Text", sou="partial")', 'tr$p(context="ctx", source="Text", source="again")',
                          'tr$p("ctx")', 'tr$np("ctx","one","many")', 'tr$np("ctx","one",plural,n)', 'tr$p("ctx", "")']:
            with self.subTest(statement=statement),self.assertRaises(ExtractionError):
                self.records('tr <- sgn_i18n(); '+statement)

    def test_reassignment_shadowing_loops_superassignment_and_mutation_fail(self):
        sources=['tr <- sgn_i18n(); tr <- list(); tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); f <- function(tr) tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); for(tr in values) tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); f <- function() {tr <<- list()}; tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); tr$p <- function(...) "modified"; tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); tr[["p"]] <- function(...) "modified"; tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); assign("tr",list()); tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); assign(dynamic_name,list()); tr$p("ctx","Text")',
                 'assign("sgn_i18n",function(...) list()); tr <- sgn_i18n(); tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); rm(list=dynamic_name); tr$p("ctx","Text")',
                 'tr <- sgn_i18n(); eval(parse(text="tr <- list()")); tr$p("ctx","Text")',
                 'sgn_i18n <- function(...) list(); tr <- sgn_i18n(); tr$p("ctx","Text")']
        for source in sources:
            with self.subTest(source=source),self.assertRaises(ExtractionError):self.records(source)

    def test_computed_chained_method_alias_and_unproved_injected_binding_fail(self):
        sources=['tr <- sgn_i18n(); tr[["p"]]("ctx","Text")',
                 'tr <- sgn_i18n(); method <- tr$p; method("ctx","Text")',
                 'tr <- sgn_i18n(); tr$for_locale(locale)$p("ctx","Text")',
                 'f <- function(translator) translator$p("ctx","Text")',
                 'tr <- imported_translator(); tr$p("ctx","Text")']
        for source in sources:
            with self.subTest(source=source),self.assertRaises(ExtractionError):self.records(source)

    def test_damaged_source_and_unavailable_tool_are_explicit_not_empty(self):
        with self.assertRaises(ExtractionError):self.records('tr <- sgn_i18n(); tr$p("ctx",')
        for value in ['Rscript helper.R','[]','[false]','["nonexistent-explicit-R-parser"]']:
            with self.subTest(value=value),patch.dict(os.environ,{'SGN_I18N_R_EXTRACT_COMMAND':value}),self.assertRaises(ExtractionError):self.records('tr <- sgn_i18n(); tr$p("ctx","Text")')

    def test_untrusted_helper_stderr_or_protocol_never_leaks_source(self):
        sentinel='SENTINEL_PRIVATE_SOURCE'
        with patch('r_extract.subprocess.run',return_value=SimpleNamespace(returncode=1,stdout='',stderr='bad source '+sentinel)):
            with self.assertRaises(ExtractionError) as error:extract_r('fixture.R','source')
        self.assertNotIn(sentinel,str(error.exception))
        for response in ['not JSON','{"schema":true,"records":[]}',json.dumps({'schema':1,'parser':'R explicit messages','parserVersion':'unknown','jsonVersion':'2.0.0','records':[]})]:
            with self.subTest(response=response),patch('r_extract.subprocess.run',return_value=SimpleNamespace(returncode=0,stdout=response,stderr='')),self.assertRaises(ExtractionError):extract_r('fixture.R','source')


if __name__=='__main__':unittest.main()
