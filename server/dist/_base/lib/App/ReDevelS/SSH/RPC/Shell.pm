package App::ReDevelS::SSH::RPC::Shell;

$__PACKAGE__::VERSION = '0.100';

use base 'SSH::RPC::Shell::PP::JSON';

use strict;

# Common commands.
use SSH::RPC::Shell::PP::TestCmds;
use App::ReDevelS::Run;


=head1 NAME

App::ReDevelS::SSH::RPC::Shell - The App::ReDevelS shell of an RPC call over SSH.

=head1 SYNOPSIS

ToDo. See L<App::ReDevelS>.

=head1 DESCRIPTION

Server side of RPC.

=head1 METHODS


=head2 new

Constructor.

=cut

sub new {
    my ( $class, $ver ) = @_;
    my $self = $class->SUPER::new( $ver );
    return $self;
}


1;
