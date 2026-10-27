package main;
use strict;
use warnings;
use utf8;
use Test::More;
use FindBin;
use File::Spec;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Digest::SHA qw(sha256_hex);
use Encode qw(encode);
use JSON::PP;
use HTML::Parser;
use lib 'lib';
BEGIN { unshift @INC, $ENV{I18N_TEST_PRODUCT_LIB_ROOT} if $ENV{I18N_TEST_PRODUCT_LIB_ROOT}; }
use SGN::I18N;

# Execute only the reviewed pure source methods/HTML loops. No Catalyst app,
# Moose model, database, upload archive, transaction or ledger is loaded.
my $root = $ENV{I18N_TEST_PRODUCT_ROOT} || File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, '..', '..', '..'));
my $before_root = $ENV{I18N_SEEDLOT_BEFORE_ROOT};
my $json = JSON::PP->new->utf8;
sub bytes {
    my ($path) = @_;
    open my $fh, '<:raw', $path or BAIL_OUT("Cannot read source: $path: $!");
    return do { local $/; <$fh> };
}
sub source { return Encode::decode('UTF-8', bytes(File::Spec->catfile($root, $_[0])), Encode::FB_CROAK()); }
if (my $manifest = $ENV{I18N_SEEDLOT_FREEZE_MANIFEST}) {
    my $inputs = $json->decode(bytes($manifest))->{source_inputs};
    BAIL_OUT('Expected frozen 38-path source manifest') unless @$inputs == 38;
    for my $row (@$inputs) {
        BAIL_OUT('Invalid manifest path') if File::Spec->file_name_is_absolute($row->{path}) || $row->{path} =~ /(?:^|\/)\.\.(?:\/|$)/;
        BAIL_OUT('Frozen product source changed: '.$row->{path}) unless sha256_hex(bytes(File::Spec->catfile($root,$row->{path}))) eq $row->{after_sha256};
        if ($before_root) {
            BAIL_OUT('Original snapshot changed: '.$row->{path}) unless sha256_hex(bytes(File::Spec->catfile($before_root,$row->{path}))) eq $row->{before_sha256};
        }
    }
    pass('All 38 actual product inputs and supplied originals match their frozen hashes before execution');
}
sub method {
    my ($text,$name) = @_;
    my ($body) = $text =~ /^(sub \Q$name\E\b.*?)(?=^sub |^1;|^no Moose;|\z)/ms;
    BAIL_OUT("Missing actual method $name") unless defined $body;
    return $body;
}
sub compile_methods {
    my ($package,$text,@names) = @_;
    my $program = "package $package; use strict; use warnings; use Data::Dumper; use HTML::Entities qw(encode_entities); use SGN::I18N;\n";
    $program .= join("\n", map {method($text,$_)} @names) . "\n1;";
    my $ok = eval $program;
    BAIL_OUT("Actual source method compilation failed: $@") unless $ok;
}

{
    package OwnedSeedlotObservedI18N;
    our @ISA = ('SGN::I18N');
    our @calls;
    sub p { push @calls, [$_[1],$_[2],$_[3]]; return SGN::I18N::p(@_); }
    package CXGN::List::Validate;
    our %missing;
    our @calls;
    sub new { bless {},shift }
    sub validate { my ($self,$schema,$type,$names)=@_; push @calls,[$type,$names]; return {missing=>$missing{$type} || []}; }
    package CXGN::List;
    our @elements;
    sub new { bless {},shift }
    sub elements { return [@elements]; }
    package SGN::Model::Cvterm;
    sub get_cvterm_row { my ($self,$schema,$name)=@_; return bless {id=>{accession=>1,plot=>2,subplot=>3,plant=>4,plot_of=>5,subplot_of=>6,plant_of=>7,seedlot=>8}->{$name}},'OwnedSeedlotTerm'; }
    package OwnedSeedlotTerm;
    sub cvterm_id { shift->{id} }
    package OwnedSeedlotSchema;
    sub new { bless {lookups=>[]},shift }
    sub storage { shift }
    sub dbh { return undef }
    sub resultset { my ($self,$kind)=@_; return bless {schema=>$self,kind=>$kind},'OwnedSeedlotResultSet'; }
    sub txn_do { die 'Unexpected transaction/data write' }
    package OwnedSeedlotResultSet;
    sub find {
        my ($self,$criteria)=@_;
        push @{$self->{schema}{lookups}},[$self->{kind},$criteria];
        return bless {object_id=>99},'OwnedSeedlotRow' if $self->{kind} eq 'Stock::StockRelationship';
        return bless {stock_id=>10,type_id=>1},'OwnedSeedlotRow' if exists $criteria->{type_id};
        return bless {stock_id=>20,type_id=>2},'OwnedSeedlotRow';
    }
    sub search { my ($self,$criteria)=@_; push @{$self->{schema}{lookups}},[$self->{kind},$criteria]; return $self; }
    sub count { return 0 }
    sub next { return undef }
    sub create { die 'Unexpected create' }
    sub update { die 'Unexpected update' }
    sub delete { die 'Unexpected delete' }
    package OwnedSeedlotRow;
    sub stock_id { shift->{stock_id} }
    sub type_id { shift->{type_id} }
    sub object_id { shift->{object_id} }
    package CXGN::File::Parse;
    our $parsed;
    our @constructors;
    sub new { my ($class,%args)=@_; push @constructors,\%args; return bless {},$class; }
    sub parse { return $parsed; }
    package OwnedSeedlotParser;
    sub get_filename { 'owned-validation.tsv' }
    sub get_chado_schema { return $_[0]{schema} }
    sub i18n { return $_[0]{i18n} }
    sub _set_parse_errors { $_[0]{errors}=$_[1] }
    sub _set_parsed_data { die 'Unexpected valid-data branch' }
    package OwnedSeedlotOriginalParser;
    our @ISA=('OwnedSeedlotParser');
}

my @class_methods = qw(verify_seedlot_stock_lists verify_seedlot_plot_compatibility verify_seedlot_family_plot_compatibility verify_seedlot_accessions_crosses verify_seedlot_accessions_family_names verify_seedlot_seedlot_compatibility verify_all_seedlots_compatibility verify_accession_content_source_compatibility delete_verify_using_list delete_using_list);
my $model_path='lib/CXGN/Stock/Seedlot.pm';
my $model=source($model_path);
compile_methods('OwnedSeedlotModel',$model,@class_methods);
my $parser_path='lib/CXGN/Stock/Seedlot/ParseUpload/Plugin/SeedlotFromAccessionGeneric.pm';
my $parser_source=source($parser_path);
compile_methods('OwnedSeedlotParser',$parser_source,'_validate_with_plugin');
my $controller=source('lib/SGN/Controller/AJAX/Seedlot.pm');
compile_methods('OwnedSeedlotHTML',$controller,'_sgn_seedlot_html','_sgn_seedlot_error_html');
my @producers=qw(upload_seedlots_POST upload_seedlots_inventory_POST upload_transactions_POST);
for my $name (@producers) {
    my $body=method($controller,$name);
    my ($loop)=$body =~ /(foreach my \$error_string \(\@\{\$parse_errors->\{'error_messages'\}\}\)\s*\{[^\n]*\n[^\n]*\n[ \t]*\})/;
    BAIL_OUT("Missing actual HTML assembly loop in $name") unless $loop;
    my $ok=eval 'package OwnedSeedlotHTML; sub '.$name.' { my ($parse_errors)=@_; my $return_error=""; '.$loop.' return $return_error; } 1;';
    BAIL_OUT("Cannot compile actual assembly $name: $@") unless $ok;
}

my $catalog_root=tempdir(DIR=>($ENV{I18N_TEST_QA_ROOT} || File::Spec->tmpdir),CLEANUP=>1);
make_path("$catalog_root/uk");
my %translations=(
    "seedlots.model.no_pair_array_passed\x04No pair array passed!"=>'Не передано пари!',
    "seedlots.model.no_accession_list_selected\x04No accession list selected!"=>'Не вибрано зразки!',
    "seedlots.model.no_seedlot_list_supplied\x04No seedlot list supplied!"=>'Не надано партії!',
    "seedlots.model.the_following_accessions_are_not_valid_in_the_da\x04The following accessions are not valid in the database, so you must add them first: %{names}"=>'Відсутні зразки: %{names}',
    "seedlots.model.no_seedlot_named_ele_could_be_found_in_the_datab\x04No seedlot named '%{ele}' could be found in the database"=>"Немає партії '%{ele}'",
    "seedlots.model.the_source_name_source_name_is_not_linked_to_the\x04The source name: %{source_name} is not linked to the same accession as the access content: %{accession_name}"=>'Джерело %{source_name} не відповідає зразку %{accession_name}',
    "seedlots.parse.the_following_columns_are_not_recognized_columns_please_check_the_spread\x04The following columns are not recognized: %{columns}. Please check the spreadsheet format for the allowed columns."=>'Невідомі стовпці: %{columns}',
);
open my $catalog,'>:raw',"$catalog_root/uk/sgn.json" or die $!;
print {$catalog} $json->encode({schema=>1,api=>1,locale=>'uk',direction=>'ltr',nplurals=>1,pluralForms=>'nplurals=1; plural=0;',pluralAst=>{type=>'NUM',val=>0},messages=>{map {$_=>{plural=>undef,forms=>[$translations{$_}]}} keys %translations}});
close $catalog;
my $translated=OwnedSeedlotObservedI18N->new(locale=>'uk-UA',catalog_root=>$catalog_root);
my $fallback=OwnedSeedlotObservedI18N->new(locale=>'zz',catalog_root=>$catalog_root);
is($translated->locale,'uk','Real runtime selects parent language of regional request');
is($fallback->locale,'en','Real runtime keeps whole English fallback for missing language assets');

my $name='Crop_é_Жито_試験_دفعة_<br>_<strong>_&amp;_%{names}_%{source_name}';
my $accession='Acc_é_<strong>_&amp;_%{accession_name}';
my $schema=OwnedSeedlotSchema->new;
my $names=[$name];
local $CXGN::List::Validate::missing{accessions}=[$name];
my $plain_model=OwnedSeedlotModel->verify_seedlot_stock_lists($schema,undef,undef,$names,[])->{error};
is($plain_model,'Your seedlot list is empty!','Original empty-list behavior returns before lookups');
my $seed_names=['owned_seed'];
my $model_error=OwnedSeedlotModel->verify_seedlot_stock_lists($schema,undef,undef,$names,$seed_names,$translated)->{error};
is($model_error,'Відсутні зразки: '.$name,'Actual model emits translated plain data, preserving placeholder-looking scientific name');
is_deeply($CXGN::List::Validate::calls[-2],['accessions',$names],'Actual model lookup receives raw scientific names');
my $english_error=OwnedSeedlotModel->verify_seedlot_stock_lists($schema,undef,undef,$names,$seed_names,$fallback)->{error};
is($english_error,'The following accessions are not valid in the database, so you must add them first: '.$name,'Missing assets retain the whole exact English model message');

my $pairs=[[$accession,$name]];
my $compatibility=OwnedSeedlotModel->verify_accession_content_source_compatibility($schema,$pairs,$translated)->{error};
is($compatibility,"Джерело $name не відповідає зразку $accession\n",'Actual translated model compatibility message uses authored plain newline');
my $legacy_compatibility=OwnedSeedlotModel->verify_accession_content_source_compatibility($schema,$pairs)->{error};
is($legacy_compatibility,"The source name: $name is not linked to the same accession as the access content: $accession<br>",'No-translator model retains exact legacy authored HTML suffix');
is_deeply($pairs,[[$accession,$name]],'Model presentation leaves scientific input values untouched');
is($schema->{lookups}[-3][1]{uniquename},$accession,'Accession lookup receives exact raw name');
is($schema->{lookups}[-2][1]{uniquename},$name,'Source lookup receives exact raw name');

my @columns=($name,'<br>','<strong>','&amp;','%{columns}');
$CXGN::File::Parse::parsed={additional_columns=>\@columns,errors=>[],data=>[],values=>{}};
my $parser=bless {schema=>$schema,i18n=>$translated},'OwnedSeedlotParser';
$parser->_validate_with_plugin;
my $parser_error=$parser->{errors}{error_messages}[0];
is($parser_error,'Невідомі стовпці: '.join(', ',@columns),'Actual parser emits translated plain diagnostic with colliding placeholders');
is($CXGN::File::Parse::constructors[-1]{i18n},$translated,'Actual validator propagates the explicit translator into its parser');
is_deeply($CXGN::File::Parse::constructors[-1]{required_columns},[qw(seedlot_name accession_name operator_name box_name)],'Original canonical headers stay exact');
is_deeply(\@columns,[$name,'<br>','<strong>','&amp;','%{columns}'],'Parser presentation does not mutate diagnostic data');
my $no_translator_parser=bless {schema=>$schema},'OwnedSeedlotParser';
$no_translator_parser->_validate_with_plugin;
my $plain_parser=$no_translator_parser->{errors}{error_messages}[0];
is($plain_parser,'The following columns are not recognized: '.join(', ',@columns).'. Please check the spreadsheet format for the allowed columns.','No-translator parser retains exact English fallback');

sub decoded_fragment {
    my ($html)=@_; my (@tags,$text);
    $text='';
    my $parser=HTML::Parser->new(api_version=>3,start_h=>[sub {push @tags,$_[0];$text.="\n" if $_[0] eq 'br';},'tagname'],text_h=>[sub {$text.=$_[0]},'dtext']);
    $parser->parse($html);$parser->eof;
    return ($text,\@tags);
}
for my $producer (@producers) {
    my $errors=[$model_error,$parser_error,$compatibility,$english_error];
    # Wrappers compiled from the actual loops use a function argument, not a class.
    no strict 'refs'; my $html=&{'OwnedSeedlotHTML::'.$producer}({error_messages=>$errors}); use strict 'refs';
    like($html,qr/\Q&lt;br&gt;\E/,'Literal br is escaped once: '.$producer);
    like($html,qr/\Q&lt;strong&gt;\E/,'Literal strong is inert text: '.$producer);
    like($html,qr/\Q&amp;amp;\E/,'Literal entity spelling is escaped once: '.$producer);
    unlike($html,qr/<(?:strong|script|img)\b/i,'Only authored separator markup is active: '.$producer);
    my ($text,$tags)=decoded_fragment($html);
    is($text,join('',map {$_ . "\n"} @$errors),'Real HTML parser recovers exact Unicode/scientific text after one decode: '.$producer);
    is_deeply($tags,[('br') x 5],'Three ordinary separators plus one newline conversion and final separator: '.$producer);
    is_deeply($errors,[$model_error,$parser_error,$compatibility,$english_error],'Actual HTML producer does not mutate error inputs: '.$producer);
}

my $original_model;
if ($before_root) {
    $original_model=Encode::decode('UTF-8',bytes(File::Spec->catfile($before_root,$model_path)),Encode::FB_CROAK());
    compile_methods('OwnedSeedlotOriginalModel',$original_model,@class_methods);
    my $old_parser=Encode::decode('UTF-8',bytes(File::Spec->catfile($before_root,$parser_path)),Encode::FB_CROAK());
    compile_methods('OwnedSeedlotOriginalParser',$old_parser,'_validate_with_plugin');
    my $old=bless {schema=>$schema},'OwnedSeedlotOriginalParser';
    $old->_validate_with_plugin;
    is(encode('UTF-8',$plain_parser),encode('UTF-8',$old->{errors}{error_messages}[0]),'Parser no-translator fallback matches frozen original bytes');
}
for my $method (@class_methods) {
    my $body=method($model,$method);
    my @arguments=$body =~ /^\s*my (?:SGN::I18N )?(\$\w+) = shift;/mg;
    is($arguments[-1],'$'.$method.'_i18n','Translator remains the final optional argument: '.$method);
    if ($original_model) {
        my @old=method($original_model,$method) =~ /^\s*my (\$\w+) = shift;/mg;
        is_deeply([@arguments[0..$#arguments-1]],\@old,'Every original argument position remains exact: '.$method);
    }
    my @args = $method eq 'verify_seedlot_stock_lists' ? ($schema,undef,undef,undef,undef) : $method =~ /^delete_/ ? ($schema,undef,123) : ($schema,undef);
    local @CXGN::List::elements=($name);
    @OwnedSeedlotObservedI18N::calls=();
    my (@plain,@localized,@original);
    { open my $quiet,'>',\my $diagnostics or die $!; local *STDERR=$quiet;
      @plain=OwnedSeedlotModel->$method(@args);
      @localized=OwnedSeedlotModel->$method(@args,$translated);
      @original=OwnedSeedlotOriginalModel->$method(@args) if $original_model;
    }
    ok(@OwnedSeedlotObservedI18N::calls,'Actual method reaches the supplied final translator: '.$method);
    if ($original_model) { is($json->canonical->encode(\@plain),$json->canonical->encode(\@original),'No-translator error/data fallback matches original bytes: '.$method); }
}
if (my $compiled_root=$ENV{I18N_TEST_CATALOG_ROOT}) {
    for my $locale (qw(en uk es ar uk-UA)) {
        my $runtime=OwnedSeedlotObservedI18N->new(locale=>$locale,catalog_root=>$compiled_root);
        is($runtime->locale,$locale eq 'uk-UA' ? 'uk' : $locale,'Actual compiled catalog/fallback language: '.$locale);
        my $actual_model=OwnedSeedlotModel->verify_seedlot_stock_lists($schema,undef,undef,$names,$seed_names,$runtime)->{error};
        my $actual_parser=bless {schema=>$schema,i18n=>$runtime},'OwnedSeedlotParser';
        $actual_parser->_validate_with_plugin;
        my $actual_error=$actual_parser->{errors}{error_messages}[0];
        like($actual_model,qr/\Q$name\E/,'Compiled translation preserves colliding scientific name: '.$locale);
        like($actual_error,qr/\Q%{columns}\E/,'Compiled parser translation does not recurse into data placeholders: '.$locale);
        isnt($actual_model,$english_error,'Actual compiled human message differs from English: '.$locale) unless $locale eq 'en';
        for my $producer (@producers) {
            no strict 'refs'; my $html=&{'OwnedSeedlotHTML::'.$producer}({error_messages=>[$actual_model,$actual_error]}); use strict 'refs';
            my ($text,$tags)=decoded_fragment($html);
            is($text,$actual_model."\n".$actual_error."\n",'Actual compiled locale survives the real HTML producer: '.$locale.' '.$producer);
            is_deeply($tags,['br','br'],'Scientific tags never become markup in compiled locale: '.$locale.' '.$producer);
        }
    }
}
done_testing;
