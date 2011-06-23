use strict;
use warnings;

use CXGN::Phenome::Qtl;
use Path::Class;
use CatalystX::GlobalContext qw( $c );

my $login_id = $c->user()->get_object->get_sp_person_id() if $c->user;
my $pop_id = $c->request->param('pop_id');
my $stat_params = $c->request->param('stat_params');

if ($login_id) {

    my $qtl = CXGN::Phenome::Qtl->new($login_id);
    my ($temp_qtl_dir, $temp_user_dir) = $qtl->create_user_qtl_dir($c); 
                     
    my $f = file( $temp_user_dir, "stat_options_${pop_id}.txt" )->openw
        or die "Can't create file: $! \n";

    if ( $stat_params eq 'default' ) 
    {
        $f->print( "default parameters\tYes" );
    } 
    else 
    {
        $f->print( "default parameters\tNo" );
    }
  
}                
