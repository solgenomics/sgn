package main;
use strict;
use warnings;
use Test::More;
use lib 'lib';
BEGIN {unshift @INC,$ENV{I18N_TEST_PRODUCT_LIB_ROOT} if $ENV{I18N_TEST_PRODUCT_LIB_ROOT};}
use DBIx::Class::Schema;
use DBIx::Class::Exception;
use SGN::I18N;
use CXGN::Pedigree::AddPedigrees;
# Whole real model method; a real blessed DBIC exception is thrown before its
# transaction callback. No schema connection, CV/stock lookup or data write.
{
 package OwnedPedigreeThrowSchema;
 our @ISA=('DBIx::Class::Schema');our ($error,$txn_calls,$lookup_calls);
 sub txn_do {++$txn_calls;die $error;}
 sub resultset {++$lookup_calls;die 'Unexpected database or lookup work';}
}
my $error;eval{DBIx::Class::Exception->throw('Owned transaction diagnostic, raw values remain data');};$error=$@;
is(ref($error),'DBIx::Class::Exception','Actual blessed DBIC exception class is used');
my $diagnostic="$error";
$OwnedPedigreeThrowSchema::error=$error;
my $schema=bless {},'OwnedPedigreeThrowSchema';
my $plain=CXGN::Pedigree::AddPedigrees->new(schema=>$schema,pedigrees=>[])->add_pedigrees(0);
is($plain->{error},'Transaction error creating pedigrees: '.$diagnostic,'Whole source-only method preserves original interpolated diagnostic');
for my $locale(qw(en uk)) {
 my $translator=SGN::I18N->new(locale=>$locale,catalog_root=>$ENV{I18N_TEST_CATALOG_ROOT}||'locale/build',domain=>'sgn');
 my $result=eval{CXGN::Pedigree::AddPedigrees->new(schema=>$schema,pedigrees=>[],i18n=>$translator)->add_pedigrees(0)};
 is($@,'','Whole request-translated method accepts a native blessed diagnostic: '.$locale);
 my $wanted=$translator->p('pedigree.store.transaction_error_creating_pedigrees_detail','Transaction error creating pedigrees: %{detail}',{detail=>$diagnostic});
 is($result&&$result->{error},$wanted,'Translated result retains the exact legacy diagnostic string: '.$locale);
}
is(ref($OwnedPedigreeThrowSchema::error),'DBIx::Class::Exception','Original exception reference remains intact');
is($OwnedPedigreeThrowSchema::txn_calls,3,'Only the owned pre-callback throw boundary is reached');
is($OwnedPedigreeThrowSchema::lookup_calls||0,0,'No model callback/CV/stock/database work occurs');
done_testing;
