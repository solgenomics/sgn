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

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );
#process in control until standardized input

sub pedigree_check : Path('/ajax/accession_list/pedigree_check') : ActionClass('REST') { }

sub pedigree_check_POST :  Args(0) {
  my $self = shift;
  my $c = shift;
  my %result_hash;
  my $result_hash;
	my $schema = $c->debic_schema("Bio::Chado::Schema"); ##syntax

  my $default_genotyping_protocol = $c->config->{default_genotyping_protocol};
  my $protocol_id = $schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$default_genotyping_protocol})->nd_protocol_id();

  my $accession_list_json = $c->req->param('accession_list');
  my @accession_list = @{_parse_list_from_json($accession_list_json)}; ##add package and find function

  foreach my $accession (@accession_list){
    #keep stock object if not in addpedigrees
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    $stock_lookup->set_stock_name($accession);
    my $stock_lookup_result = $stock_lookup->get_stock_exact();
    my $stock_id = $stock_lookup_result->stock_id();
    my $stock = CXGN::Stock->new(schema => $schema, stock_id => $stock_id);

    my $parents = $stock->get_parents();
    my $mother_id = $parents->{'mother_id'};
    print STDERR "mother id controller is $mother_id\n";
    my $father_id = $parents->{'father_id'};
    print STDERR "father id controller is $father_id\n";

    my $conflict_object = CXGN::Genotype::PedigreeCheck->new({schema=>$schema, accession_name => $accession, mother_id => $mother_id, father_id => $father_id, protocol_id => $protocol_id});
    my $conflict_results = $conflict_object->pedigree_check();

    print STDERR "conflict results are ".Dumper $conflict_results;

    if ($conflict_results->{error}){
      my $error = $conflict_results->{error};
      $result_hash{$accession} = $error;
      print STDERR "controller an error has occurred: $error";
    }
    else{
      my $conflict_score = $conflict_results->{'score'};
      $result_hash{$accession} = $conflict_score;
      print STDERR "conflict score is controller $conflict_score";
    }
    }
    $c->stash->{rest} = $result_hash;
}
1;
