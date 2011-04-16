package SSH::RPC::Shell::PP::Cmd::Base;

use strict;
use Data::Dumper;


=head1 NAME

SSH::RPC::Shell::PP::Cmd::Base - Base class for remote side commands.

=head1 SYNOPSIS

ToDo. See L<App::ReDevelS>.

=head1 METHODS


=head2 new

Constructor.

=cut

sub new {
    my ( $class ) = @_;

    my $self  = {};
    $self->{errors} = [];
    $self->{debug} = 0;
    $self->{debug_out} = 0;

    bless( $self, $class );
    return $self;
}

=head2 process_base_command_args

Prepare common command parameters.

=cut

sub process_base_command_args {
    my ( $self, $args ) = @_;

    $self->{debug} = $args->{debug};

    $self->{debug_out} = $args->{debug_out} if $args->{debug_out};

    if ( $self->{debug} ) {
        $self->dump( $args );
    }

    return 1;
}

=head2 add_error

Add error message to array or errors.

=cut

sub add_error {
    my ( $self, $err_str ) = @_;
    push @{$self->{errors}}, $err_str;
    return 1;
}


=head2 get_errors

Return array of error messages.

=cut

sub get_errors {
    my ( $self ) = @_;
    return $self->{errors};
}


=head2 debug

Add string to debug output.

=cut

sub debug {
    my ( $self, $output_to_add ) = @_;
    $self->{debug_output} .= $output_to_add;
    return 1;
}


=head2 dump

Add stringified perl data structures to debug output.

=cut

sub dump {
    my @caller0 = caller(0);
    my @caller1 = caller(1);
    my ( $self, @data ) = @_;

    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 1;
    my $debug_output = "dump called on line $caller0[2] of $caller1[3] - " . Data::Dumper->Dump( \@data );
    $self->debug( $debug_output );
    return 1;
}


=head2 flush_debug_output

Return curret debug output and reset it.

=cut

sub flush_debug_output {
    my ( $self ) = @_;
    my $debug_output = $self->{debug_output};
    $self->{debug_output} = '';
    return $debug_output;
}


=head2 pack_ok_response ()

Pack result to success response and add debug_output.

=cut

sub pack_ok_response {
    my ( $self, $response, $is_last ) = @_;

    my $result = {
        status => 200,
        response => $response,
        version => $__PACKAGE__::VERSION,
    };
    $result->{is_last} = 1 if $is_last;

    my $debug_output = $self->flush_debug_output();
    $result->{debug_output} = $debug_output if $debug_output;

    return $result;
}


1;
