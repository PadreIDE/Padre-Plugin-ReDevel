package SSH::RPC::Shell::PP::Base;

use strict;

$SSH::RPC::Shell::PP::Base::VERSION = '0.100';


=head1 NAME

SSH::RPC::Shell::PP::Base - The shell of an RPC call over SSH.

=head1 SYNOPSIS

ToDo. See L<App::ReDevelS>.

=head1 DESCRIPTION

Based on SSH::RPC::Shell, but without Class::InsideOut.

=head1 METHODS


=head2 new

Constructor.

=cut

sub new {
    my ( $class, $ver ) = @_;

    my $self  = {};
    $self->{ver} = $ver;

    bless( $self, $class );
    return $self;
}


=head2 process_request( request )

Process request. Return ret_code or result hash.

=cut

sub process_request {
    my ( $self, $request ) = @_;

    my $command_sub_name = 'run_'.$request->{command};
    my $args = $request->{args};
    if ( my $sub = $self->can($command_sub_name) ) {
        return $sub->( $self, $args );
    }
    return { "error" => "Method not allowed.", "status" => "405" };
}


=head2 init_test_obj

Initialize test run object (SSH::RPC::Shell::PP::TestCmds).

=cut

sub init_test_obj {
    my ( $self ) = @_;
    $self->{test_obj} = SSH::RPC::Shell::PP::TestCmds->new();
}


=head2 run_test_noop

Roon noop command on test run object.

=cut

sub run_test_noop {
    my ( $self, $file ) = @_;
    $self->init_test_obj() unless $self->{test_obj};
    return $self->{test_obj}->run_test_noop();
}


=head2 run_test_three_parts

Roon test_three_parts command on test run object.

=cut

sub run_test_three_parts {
    my ( $self, $file ) = @_;
    $self->init_test_obj() unless $self->{test_obj};
    return $self->{test_obj}->run_test_three_parts();
}


1;
