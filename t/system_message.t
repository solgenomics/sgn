use Test::Most tests => 2;
use File::Temp;

use SGN::Context;
use CXGN::MasonFactory;

my $c = SGN::Context->new;

my $tempfile = File::Temp->new;
$tempfile->print("fogbat!");
$tempfile->close;

$c->config->{system_message_file} = undef;
is( CXGN::MasonFactory->bare_render('/system_message.mas' ),
    '',
    'system message is empty for no message file'
   );

# correctly set system_message_file var
$c->config->{system_message_file} = "$tempfile";
like( CXGN::MasonFactory->bare_render('/system_message.mas'),
      qr/fogbat/,
      'system message looks correct'
     );
