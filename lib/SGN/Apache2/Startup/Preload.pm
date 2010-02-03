=head1 NAME

SGN::Apache2::Startup::Preload - solely a class to pre-load many of
our modules at apache startup time

=cut

package SGN::Apache2::Startup::Preload;

use Module::Find;

useall CXGN::BioTools;
useall CXGN::BlastDB;
useall CXGN::Chado;
useall CXGN::CDBI;
useall CXGN::Class;
useall CXGN::Config;
useall CXGN::Cview;
useall CXGN::DB;

useall CXGN::Error;
useall CXGN::Genomic;

useall CXGN::Graphics;
useall CXGN::Image;

useall CXGN::ITAG;


useall CXGN::Map;
useall CXGN::Marker;

use CXGN::MasonFactory;

useall CXGN::Metadata;

useall CXGN::People;

useall CXGN::Phenome;

useall CXGN::Phylo;


useall CXGN::PotatoGenome;


useall CXGN::Scrap;

useall CXGN::Search;

useall CXGN::Searches;

useall CXGN::Secretary;

useall CXGN::SNP;

useall CXGN::Sunshine;

useall CXGN::Tools;

useall CXGN::Unigene;

useall CXGN::UserList;

useall CXGN::UserPrefs;


useall Bio::Annotation;
useall Bio::Seq;
useall Bio::SeqFeature;

use Bio::SeqIO;
use Bio::SeqIO::fasta;

useall Bio::SearchIO;

useall SGN::Controller;

use SGN::Context;

# pre-create and cache the SGN context singleton, and its default
# DBIx::Connector connection
SGN::Context->new->dbc;

###
1;# do not remove
###
