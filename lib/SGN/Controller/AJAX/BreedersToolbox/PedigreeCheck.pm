package SGN::Controller::AJAX::BreedersToolbox::PedigreeCheck;

use Moose;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Stock;
use CXGN::Genotype;
use CXGN::Genotype::PedigreeCheck;
use CXGN::Genotype::Search;
use CXGN::Stock::StockLookup;
use Bio::GeneticRelationships::Pedigree;

use JSON -support_by_pp;
use List::MoreUtils qw /any /;
use CXGN::BreedersToolbox::Accessions;
use CXGN::Stock::Accession;
use CXGN::Chado::Stock;
use CXGN::List;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub pedigree_check : Path('/ajax/accession_list/pedigree_check') : ActionClass('REST') { }

sub pedigree_check_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $self->pedigree_check_POST($c);
}

sub pedigree_check_POST :  Args(0) {
  my $self = shift;
  my $c = shift;
  my %result_hash;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $default_genotyping_protocol = $c->config->{default_genotyping_protocol};
  my $protocol_id = $schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$default_genotyping_protocol})->nd_protocol_id();

  my $accession_list_json = $c->req->param('accession_list');
  print STDERR "acccession list json $accession_list_json\n";
  my @accession_list = @{_parse_list_from_json($accession_list_json)}; ##add package and find function
  print STDERR Dumper (@accession_list);

  foreach my $accession (@accession_list){
    #keep stock object if not in addpedigrees
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    $stock_lookup->set_stock_name($accession);
    my $stock_lookup_result = $stock_lookup->get_stock_exact();
    my $stock_id = $stock_lookup_result->stock_id();
    print STDERR "stock id is $stock_id";

    my $stock = CXGN::Stock->new(schema => $schema, stock_id => $stock_id);

    my $parents = $stock->get_parents();
    my $mother_id = $parents->{'mother_id'};
    #print STDERR "mother id is $mother_id";

    my $father_id = $parents->{'father_id'};
    #print STDERR "father id is $father_id";
    if (!$mother_id && !$father_id){
      $result_hash{missing}->{$accession} = "$accession misses both female and male parents";
    }
    elsif(!$mother_id){
      $result_hash{missing}->{$accession} = "$accession misses its female parent";
    }
    elsif(!$father_id){
      $result_hash{missing}->{$accession} = "$accession misses its male parent";
    }
    else{
      my $conflict_object = CXGN::Genotype::PedigreeCheck->new({schema=>$schema, accession_name => $accession, mother_id => $mother_id, father_id => $father_id, protocol_id => $protocol_id});
      my $conflict_results = $conflict_object->pedigree_check();

      if ($conflict_results->{error}){
        my $error = $conflict_results->{error};
        $result_hash{missing}->{$accession} = $error;
        print STDERR "controller an error has occurred: $error";
      }
      else{
        my $conflict_score = $conflict_results->{'score'};
        $result_hash{calculated}->{$accession} = $conflict_score;
      }
    }
  }
    $c->stash->{rest} = \%result_hash;
}
sub _parse_list_from_json {
  my $list_json = shift;
  my $json = new JSON;
  if ($list_json) {
    my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
    #my $decoded_list = decode_json($list_json);
    my @array_of_list_items = @{$decoded_list};
    return \@array_of_list_items;
  }
  else {
    return;
  }
}
1;
