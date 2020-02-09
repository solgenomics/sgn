package Net::Server::SS::PreFork;

use strict;
use warnings;

use Net::Server::PreFork;
use Net::Server::Proto::TCP;
use Server::Starter qw(server_ports);

use base qw(Net::Server::PreFork);

our $VERSION = 0.05;

sub pre_bind {
    my $self = shift;
    my $prop = $self->{server};
    
    my %ports = %{server_ports()};
    for my $port (sort keys %ports) {
        my $sock = Net::Server::Proto::TCP->new();
        if ($port =~ /^(.*):(.*?)$/) {
            $sock->NS_host($1);
            $sock->NS_port($2);
        } else {
            $sock->NS_host('*');
            $sock->NS_port($port);
        }
        $sock->NS_proto('TCP');
        $sock->fdopen($ports{$port}, 'r')
            or $self->fatal("failed to bind listening socket:$ports{$port}:$!");
        push @{$prop->{sock}}, $sock;
    }
    $prop->{multi_port} = 1 if @{$prop->{sock}} > 1;
}

sub bind {
  my $self = shift;
  my $prop = $self->{server};
  
  ### if more than one port we'll need to select on it
  if( @{ $prop->{port} } > 1 || $prop->{multi_port} ){
    $prop->{multi_port} = 1;
    $prop->{select} = IO::Select->new();
    foreach ( @{ $prop->{sock} } ){
      $prop->{select}->add( $_ );
    }
  }else{
    $prop->{multi_port} = undef;
    $prop->{select}     = undef;
  }
}

sub sig_hup {
    my $self = shift;
    $self->log(
        0,
        $self->log_time(),
        "Net::Server::SS::PreFork does not accept SIGHUP, send it to the"
            . " daemon!",
    );
}

sub shutdown_sockets {
    # Net::Server::shutdown_sockets uses shutdown(2) to close accept(2)ing
    # sockets (which is a bug IMHO).  On OSX, shutdown(2) returns ENOTSOCK
    # so the socket is not closed.  On Linux, shutdown(2) closes the accepting
    # connection on all the forked processes sharing the socket (and the
    # next generation workers spawned by Server::Starter woul never be able
    # to accept incoming connections).  Thus we override the function and use
    # close(2) instead of shutdown(2).
    my $self = shift;
    my $prop = $self->{server};
    
    for my $sock (@{$prop->{sock}}) {
        $sock->close; # close sockets - nobody should be reading/writing still
    }
    
    ### delete the sock objects
    $prop->{sock} = [];
    
    return 1;
}

1;
__END__

=head1 NAME

Net::Server::SS::PreFork - a hot-deployable variant of Net::Server::PreFork

=head1 SYNOPSIS

  # from command line
  % start_server --port=80 my_server.pl

  # in my_server.pl
  use base qw(Net::Server::SS::PreFork);

  sub process_request {
      #...code...
  }

  __PACKAGE__->run();

=head1 DESCRIPTION

L<Net::Server::SS::PreFork> is L<Net::Server> personality, extending L<Net::Server::PreFork>, that can be run by the L<start_server> script of L<Server::Starter>.

=head1 AUTHOR

Kazuho Oku E<lt>kazuhooku@gmail.comE<gt>
Copyright (C) 2009 Cybozu Labs, Inc.

=head1 SEE ALSO

L<Net::Server>
L<Server::Starter>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
