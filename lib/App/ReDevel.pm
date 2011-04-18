package App::ReDevel;

use strict;
use warnings;

use base 'App::ReDevel::Base';

use File::ShareDir;
use File::Spec::Functions;

use App::ReDevel::SSHRPCClient;

use Fcntl ':mode'; # get_mode_str


=head1 NAME

App::ReDevel - Base package for remote development applications.

=head1 SYNOPSIS

Connect to remote host through SSH. Send RPC server code (App::ReDevelS
package files) to host and start RPC server on it.

=head1 DESCRIPTION

ToDo

=head1 METHODS


=head2 new

Constructor.

=cut

sub new {
    my $class = shift;
    my $params = shift;
    my $self = $class->SUPER::new( $params );

    $self->{conf} = 3;
    $self->{conf} = $params->{conf} if defined $params->{conf};

    my $base_dir = __FILE__;

    $base_dir = File::ShareDir::module_dir('App::ReDevel');
    $self->{module_auto_dir} = $base_dir;

    $self->{client} = undef;

    $self->{cmds} = {
        'test_hostname' => 'client',
        'check_server_dir' => 'client',
        'remove_server_dir' => 'client',
        'renew_server_dir' => 'client',
        'test_noop_rpc' => 'rpc_shell',
        'test_three_parts_rpc' => 'rpc_shell',
    };

    return $self;
}


=head2 run

Start options processing and run given command.

=cut

sub run {
    my ( $self, $opt ) = @_;

    $self->{ver} = $opt->{ver} if defined $opt->{ver};
    $self->dump( 'Given parameters', $opt ) if $self->{ver} >= 6;

    return $self->err("No command selected. Use --cmd option.") unless $opt->{cmd};

    my $cmd = lc( $opt->{cmd} );
    return 0 unless $self->check_cmd_name( $cmd );

    my $cmd_type = $self->{cmds}->{ $cmd };

    # Load host config for given hostname from connected DB.
    return 0 unless $self->prepare_base_host_conf( $opt );

    # Prepar SSH part of object.
    return 0 unless $self->prepare_and_connect_client();

    if ( $cmd_type eq 'rpc_shell' ) {
        return 0 unless $self->start_rpc_shell();
    }

    return $self->run_by_name( $cmd, $opt );
}


=head2 check_cmd_name

Set error msg and return 0 unless command exists.

=cut

sub check_cmd_name {
    my ( $self, $cmd ) = @_;
    return $self->err( "Unknown command '$cmd'.", 1 ) unless exists $self->{cmds}->{ $cmd };
    return 1;
}


=head2 run_by_name

Run RPC cmd on server or self method.

=cut

sub run_by_name {
    my ( $self, $cmd, $opt ) = @_;

    return 0 unless $self->check_cmd_name( $cmd );
    my $cmd_type = $self->{cmds}->{ $cmd };

    # Run simple client command or RPC command on client object.
    if ( $cmd_type eq 'client' || $cmd_type eq 'rpc_shell' ) {
        my $client_obj = $self->{client};
        my $cmd_method_name = $cmd;
        return $self->client_err() unless $client_obj->$cmd_method_name();
        return 1;
    }

    # Run given comman method.
    my $cmd_method_name = $cmd . '_cmd';
    return $self->$cmd_method_name( $opt );
}


=head2 connect_host

Do preparation steps and connect to server.

=cut

sub connect_host {
    my ( $self, $host_conf ) = @_;
    return 0 unless $self->prepare_base_host_conf( $host_conf );
    return 0 unless $self->prepare_and_connect_client();
    return 1;
}


=head2 host_is_connected

Return 1 if host machine is connected (through SSH).

=cut

sub host_is_connected {
    my $self = shift;
    return 0 unless defined $self->{client};
	return $self->{client}->is_connected();
}


=head2 disconnect_host

Disconnect from server.

=cut

sub disconnect_host {
    my ( $self, $host_conf ) = @_;
	return $self->err("Not connected.") unless $self->host_is_connected();
    return 0 unless $self->{client}->disconnect();
    return 1;
}


=head2 start_rpc_server

Update files on server if required and start RPC shell.

=cut

sub start_rpc_server {
    my ( $self, $renew_type ) = @_;
	return $self->err("You should run prepare_server first.") unless defined $self->{host_conf};
    return 0 unless $self->{client}->renew_server_dir( $renew_type );
    return 0 unless $self->start_rpc_shell();
	return 1;
}


=head2 rpc_shell_is_running

Return 1 if host machine is connected (through SSH) and RPC shell
was already started.

=cut

sub rpc_shell_is_running {
    my $self = shift;
    return 0 unless defined $self->{client};
	return $self->{client}->rpc_shell_is_running();
}


=head2 renew_server_dir

Update files on server if required. Do not start RPC shell.

=cut

sub renew_server_dir {
    my ( $self, $renew_type ) = @_;
	return $self->err("You should run prepare_server first.") unless defined $self->{host_conf};
    return 0 unless $self->{client}->renew_server_dir( $renew_type );
	return 1;
}


=head2 stop_rpc_server

Stop RPC shell.

=cut

sub stop_rpc_server {
    my ( $self ) = @_;
	return $self->err("Nothing to stop. You should run prepare_server first.") unless defined $self->{host_conf};
    return 0 unless $self->{client}->stop_rpc_shell();
	return 1;
}


=head2 client_err

Set error message to error from client object (after normal or rpc command).
Return 0 as method err.

=cut

sub client_err  {
    my ( $self ) = @_;

    return undef unless defined $self->{client};
    my $client_err = $self->{client}->err();
    return $self->err( $client_err, 1 );
}


=head2 set_mandatory_param_err

Set 'param is mandatory' error and return undef.

=cut

sub set_mandatory_param_err {
    my ( $self, $param_name, $err_msg_end ) = @_;
    my $err_msg = "Parameter --${param_name} is mandatory";
    if ( $err_msg_end ) {
        $err_msg .= $err_msg_end
    } else {
        $err_msg .= '.';
    }
    return $self->err( $err_msg, 1 );
}


=head2 prepare_base_host_conf

Init base host_conf from given options.

=cut

sub prepare_base_host_conf {
    my ( $self, $opt ) = @_;

    my $host_conf = {
        ver => $self->{ver},
        module_auto_dir => $self->{module_auto_dir},
        host => $opt->{host},
    };

    $host_conf->{user} = $opt->{user} if defined $opt->{user};
    $host_conf->{client_ver} = $opt->{client_ver} if defined $opt->{client_ver};
    $host_conf->{server_src_dir} = $opt->{server_src_dir} if defined $opt->{server_src_dir};
    $host_conf->{host_dist_type} = $opt->{host_dist_type} if defined $opt->{host_dist_type};

    $self->{host_conf} = $host_conf;
    $self->dump( 'Host conf:', $self->{host_conf} ) if $self->{ver} >= 6;
    return 1;
}


=head2 init_client_obj

Initializce object for RPC over SSH and connect to server. Do not start perl shell for RPC.

=cut

sub init_client_obj  {
    my ( $self ) = @_;

    my $client = App::ReDevel::SSHRPCClient->new();
    unless ( defined $client ) {
        $self->err('Initialization of SSH RPC Client object failed.');
        return 0;
    }

    $self->{client} = $client;

    return $self->client_err() unless $self->{client}->set_options( $self->{host_conf} );
    return 1;
}


=head2 prepare_and_connect_client

Prepare SSH part of RPC object.

=cut

sub prepare_and_connect_client {
    my ( $self ) = @_;

    return 1 if $self->host_is_connected();

    unless ( defined $self->{client} ) {
        return 0 unless $self->init_client_obj();
    }

	return $self->client_err() unless $self->{client}->connect();
    return 1;
}


=head2 start_rpc_shell

Start perl shell on server.

=cut

sub start_rpc_shell {
    my ( $self ) = @_;

    return $self->client_err() unless $self->{client}->start_rpc_shell();
    return 1;
}


=head1 SEE ALSO

L<App::ReDevel>

=head1 LICENSE

This file is part of App::ReDevel. See L<App::ReDevel> license.

=cut


1;
