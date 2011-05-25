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
    $self->{test_obj} = undef;
    $self->{run_obj} = undef;
    return $self;
}


=head2 init_run_obj

Initialize run object (App::ReDevelS::Run).

=cut

sub init_run_obj {
    my ( $self ) = @_;
    $self->{run_obj} = App::ReDevelS::Run->new();
}


=head2 run_mkpath

Run mkpath command.

=cut

sub run_mkpath {
    my $self = shift;
    $self->init_run_obj() unless $self->{run_obj};
    return $self->{run_obj}->run_mkpath( @_ );
}


1;
