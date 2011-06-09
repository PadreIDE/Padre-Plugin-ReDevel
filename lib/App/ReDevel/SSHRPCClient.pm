package App::ReDevel::SSHRPCClient;

use strict;
use warnings;

use base 'App::ReDevel::Base';

use Data::Dumper;
use Net::OpenSSH;
use File::Spec;

use SSH::RPC::PP::Client;


=head1 NAME

App::ReDevel::SSHRPCClient - The requestor of an RPC call over SSH.

=head1 SYNOPSIS

ToDo

=head1 DESCRIPTION

ToDo

=head1 METHODS


=head2 new

Constructor.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );

    return undef unless $self->set_default_values();
    return $self;
}


=head2 set_default_values

Validate and sets options.

=cut

sub set_default_values {
    my ( $self ) = @_;

    $self->{ssh} = undef;

    $self->{user} = 'root';
    $self->{host} = 'localhost';
    $self->{host_dist_type} = undef;
    $self->{server_dir} = $self->set_server_dir();

    $self->{rpc} = undef;
    $self->{rpc_ver} = $self->{ver};
    $self->{rpc_nice} = 10;
    $self->{rpc_last_cmd} = undef;

    $self->{module_auto_dir} = '';
    $self->{server_src_dir} = $self->get_server_src_dir();

    return 1;
}


=head2 set_options

Validate and sets options.

=cut

sub set_options {
    my ( $self, $options ) = @_;

    $self->{ver} = $options->{ver} if defined $options->{ver};

    if ( defined $options->{user} ) {
        return 0 unless $self->set_user( $options->{user} );
    }

    if ( defined $options->{host} ) {
        return 0 unless $self->set_host( $options->{host} );
    }

    if ( defined $options->{host_dist_type} ) {
        $self->{host_dist_type} = $options->{host_dist_type};
    }

    if ( defined $options->{server_src_dir} ) {
        $self->{server_src_dir} = $options->{server_src_dir};
    } elsif ( defined $options->{module_auto_dir} ) {
        $self->{module_auto_dir} = $options->{module_auto_dir};
        $self->{server_src_dir} = $self->get_server_src_dir();
    }

    if ( defined $options->{rpc_ver} ) {
        $self->{rpc_ver} = $options->{rpc_ver};
    } else {
        $self->{rpc_ver} = $self->{ver};
    }

    return 1;
}


=head2 disconnect

Disconnect from server.

=cut

sub disconnect {
    my ( $self ) = @_;
    $self->stop_rpc_shell() if defined $self->{rpc};
    print "Disconnecting from server.\n" if $self->{ver} >= 5;
    $self->{ssh} = undef;
    return 1;
}


=head2 set_host

Validate hostname and set it.

=cut

sub set_host {
    my ( $self, $host ) = @_;

    $self->disconnect() if defined $self->{ssh};
    print "Setting new host to '$host'.\n" if $self->{ver} >= 5;
    $self->{host} = $host;
    return 1;
}


=head2 get_server_dir

Return App::ReDevelS directory path on server for user name.

=cut

sub get_server_dir {
    my ( $self ) = @_;

    # ToDo - use HomeDir module
    return '/root/app-redevels' if $self->{user} eq 'root';
    return '/home/' . $self->{user} . '/app-redevels'
}


=head2 set_server_dir

Sets App::ReDevelS directory path on server for user name.

=cut

sub set_server_dir {
    my ( $self ) = @_;

    $self->{server_dir} = $self->get_server_dir();
    print "Setting new server_dir: '$self->{server_dir}'\n" if $self->{ver} >= 5;
    return 1;
}


=head2 set_user

Validate user name and set it.

=cut

sub set_user {
    my ( $self, $user ) = @_;

    unless ( defined $user ) {
        $self->err('No user name defined');
        return 0;
    }

    unless ( $user ) {
        $self->err('User name is empty');
        return 0;
    }

    if ( $user =~ /\s/ ) {
        $self->err('User name contains empty string.');
        return 0;
    }

    if ( $user =~ /[\:\;\\\/]/ ) {
        $self->err('User name contains not allowed char.');
        return 0;
    }

    $self->disconnect if defined $self->{ssh};
    print "Seting new user '$user'.\n" if $self->{ver} >= 5;
    $self->{user} = $user;

    return $self->set_server_dir();
}


=head2 get_server_src_dir

Return App::ReDevelS source code directory path on server.

=cut

sub get_server_src_dir {
    my ( $self ) = @_;
    return File::Spec->catdir( $self->{module_auto_dir}, 'server' );
}


=head2 connect

Connect to remote host.

=cut

sub connect {
    my ( $self, $host, $user ) = @_;

    return $self->err('No hostname sets.') if (not defined $host) && (not defined $self->{host});
    $host = $self->{host} unless defined $host;

    return $self->err("Bad user name '$user'.") if $user && ! $self->check_user_name( $user );

    if ( defined $user ) {
        return 0 unless $self->set_user( $user );
    } else {
        return $self->err('No user sets.') unless defined $self->{user};
        $host = $self->{user} unless defined $user;
    }

    print "Connecting to host '$self->{host}' as user '$self->{user}'.\n" if $self->{ver} >= 5;
    my $ssh = Net::OpenSSH->new(
        $self->{host},
        user => $self->{user},
        master_opts => [ '-T']
    );
    return $self->err("Couldn't establish SSH connection: ". $ssh->error ) if $ssh->error;

    print "Connect finished ok.\n" if $self->{ver} >= 5;
    $self->{ssh} = $ssh;
    return 1;
}


=head2 is_connected

Return 1 if host is connected through SSH.

=cut

sub is_connected {
    my $self = shift;
    return ( defined $self->{ssh} );
}


=head2 err_ssh

Create and set error message from error provided by Net::OpenSSH.

=cut

sub err_ssh {
    my ( $self, $cmd, $msg_prefix ) = @_;

    my $full_err = '';
    $full_err .= $msg_prefix . ' ' if $msg_prefix;
    $full_err .= $self->{ssh}->error;
    return $self->err( $full_err );
}


=head2 err_rcc_cmd

Create and set error message for command.

=cut

sub err_rcc_cmd {
    my ( $self, $cmd, $err ) = @_;

    chomp($err);
    my $full_err = "RCC '$cmd' return error output: '$err'";
    return $self->err( $full_err );
}


=head2 do_rcc

Run command on server over SSH.

=cut

sub do_rcc {
    my ( $self, $cmd, $report_err ) = @_;
    $report_err = 1 unless defined $report_err;

    print "Running server command '$cmd':\n" if $self->{ver} >= 6;

    my ( $out, $err ) = $self->{ssh}->capture2( $cmd );
    my $exit_code = $?;

    if ( $self->{ver} >= 5 && ( $out || $err || $exit_code ) ) {
        my $msg_out = 'undef';
        $msg_out = "'" . $out . "'" if defined $out;

        my $msg_err = 'undef';
        $msg_err = "'" . $err . "'" if defined $err;

        my $msg_exit_code = 'undef';
        $msg_exit_code = "'" . $exit_code . "'" if defined $exit_code;

        print "out: $msg_out, err: $msg_err, exit_code: $msg_exit_code\n";
    }

    # Set error. Caller should do "return 0 if $err;".
    if ( $err && $report_err ) {
        $self->err_rcc_cmd( $cmd, $err );
    }
    return ( $out, $err, $exit_code );
}


=head2 test_hostname

Call hostname command on server and compare it.

=cut

sub test_hostname {
    my ( $self ) = @_;

    print "Testing host hostanem.\n" if $self->{ver} >= 5;
    my ( $out, $err ) = $self->do_rcc( 'hostname', 1 );
    return 0 if $err;

    my $hostname = $out;
    chomp( $hostname );

    my $ok = 0;
    if ( $self->{host} eq $hostname ) {
        $ok = 1;

    } elsif ( $self->{host} !~ m{\.} ) {
        if ( my ($base_hostname) = $hostname =~ m{ ^ ([^\.]+) \. }x ) {
            if ( $base_hostname eq $self->{host} ) {
                print "Hostname reported from server is '$hostname' and probably match provided '$self->{host}'.\n" if $self->{ver} >= 4;
                $ok = 1;
            }
        }
    }

    unless ( $ok ) {
        return $self->err("Hostname reported from server is '$hostname', but object attribute host is '$self->{host}'.");
    }

    print "Command 'test_hostname' succeeded.\n" if $self->{ver} >= 3;
    return 1;
}


=head2 check_is_dir

Run test -d on server and return 1 (exists and is directory), 0 (not exists or isn't directory) or undef (error).

=cut

sub check_is_dir {
    my ( $self, $path ) = @_;

    my $cmd = "test -d $path";
    my ( $out, $err, $exit_code ) = $self->do_rcc( $cmd, 1 );
    return undef if $err;
    return 0 if $exit_code;
    return 1;
}


=head2 ls_output_contains_unknown_dir

Return 1 if output captured from ls command contains any unknown directory. This is useful to check
if we are not doing critical mistake by recursively removing (rm -rf).

=cut

sub ls_output_contains_unknown_dir {
    my ( $self, $out ) = @_;

    chomp $out;
    my @lines = split( /\n/, $out );
    shift @lines; # remove line "total \d+"
    foreach my $line ( @lines ) {
        if ( $line =~ /^\s*d/ ) {
            return 1 if $line !~ /(bin|lib|libcpan|libdist){1}\s*$/;
        }
    }
    return 0;
}


=head2 check_server_dir

Run ls command on server and validate output. See L<ls_output_contains_unknown_dir> method.

=cut

sub check_server_dir {
    my ( $self ) = @_;

    print "Checking server source files.\n" if $self->{ver} >= 5;
    my $server_dir = $self->{server_dir};

    # Process error output of command own way.
    my $cmd = "ls -l $server_dir";
    my ( $out, $err ) = $self->do_rcc( $cmd, 0 );
    if ( $err ) {
        if ( $err =~ /No such file or directory/i ) {
            print "Directory '$server_dir' doesn't exists on host.\n" if $self->{ver} >= 3;
        } else {
            return $self->err_rcc_cmd( $cmd, $err );
        }

    } elsif ( $self->ls_output_contains_unknown_dir($out) ) {
        $self->err("Directory '$server_dir' on server contains some unknown directories.\nCmd 'ls -l' output is\n$out.");
        return 0;
    }

    print "Command 'check_server_dir' succeeded.\n" if $self->{ver} >= 3;
    return 1;
}


=head2 remove_server_dir

L<check_server_dir> and erase its content with rm -rf.

=cut

sub remove_server_dir {
    my ( $self ) = @_;

    print "Removing server source files on remote host.\n" if $self->{ver} >= 5;

    # ToDo - safe enought?
    return 0 unless $self->check_server_dir();

    my $server_dir = $self->{server_dir};

    my ( $out, $err );

    # ToDo - path escaping?
    ( $out, $err ) = $self->do_rcc( "rm -rf $server_dir", 1 );
    return 0 if $err;

    print "Command 'remove_server_dir' succeeded.\n" if $self->{ver} >= 3;
    return 1;
}


=head2 get_server_dir_items

Return items list of provided directory (on server).

=cut

sub get_server_dir_items {
    my ( $self, $dir_name ) = @_;

    print "Trying to list items inside '$dir_name' on remote host.\n" if $self->{ver} >= 5;

    # Load directory items list.
    my $dir_handle;
    if ( not opendir($dir_handle, $dir_name) ) {
        #add_error("Directory '$dir_name' not open for read.");
        return 0;
    }
    my @all_dir_items = readdir($dir_handle);
    close($dir_handle);

    my @dir_items = ();
    foreach my $item ( @all_dir_items ) {
        next if $item eq '.';
        next if $item eq '..';
        next if $item =~ /^\s*$/;
        push @dir_items, $item;
    }

    return \@dir_items;
}


=head2 put_file

Put provided file on server.

=cut

sub put_file {
    my ( $self, $full_src_path, $full_dest_fpath ) = @_;

    print "Putting item '$full_src_path' -> '$full_dest_fpath'\n" if $self->{ver} >= 5;
    return 1 if $self->{ssh}->scp_put(
        { recursive => 0, glob => 0, },
        $full_src_path,
        $full_dest_fpath
    );
    return $self->err_ssh( "scp_put '$full_src_path' -> '$full_dest_fpath' failed" );
}


=head2 put_file

Put provided file on server.

=cut

sub put_file_create_dirs {
    my ( $self, $full_src_path, $full_dest_fpath ) = @_;

    my ( undef, $dest_dir, undef ) = File::Spec->splitpath( $full_dest_fpath );
    print "Creating destination dir path '$dest_dir'\n" if $self->{ver} >= 5;
    return undef unless defined $self->do_rpc( 'mkpath', $dest_dir );

    return $self->put_file( $full_src_path, $full_dest_fpath );
}


=head2 put_dir_content

Put provided directory on server. Skips Subversion and .git directories.

=cut

sub put_dir_content {
    my ( $self, $base_src_dir, $sub_src_dir, $base_dest_dir  ) = @_;

    my $full_src_dir = File::Spec->catdir( $base_src_dir, $sub_src_dir );
    print "Starting to put items to host from local source dir '$full_src_dir'.\n" if $self->{ver} >= 5;
    my $dir_items = $self->get_server_dir_items( $full_src_dir );
    return 0 unless ref $dir_items;

    my $sub_dirs = [];
    my $full_src_path;
    ITEM: foreach my $name ( sort @$dir_items ) {

        $full_src_path = File::Spec->catdir( $full_src_dir, $name );

        if ( -d $full_src_path ) {
            # ignore Subversion and Git dirs
            next if $name eq '.svn';
            next if $name eq '.git';
            push @$sub_dirs, $name;

        } elsif ( -f $full_src_path ) {
            my $full_dest_fpath = File::Spec->catfile( $base_dest_dir, $sub_src_dir, $name );
            $self->put_file( $full_src_path, $full_dest_fpath );
        }
    }

    foreach my $sub_dir ( sort @$sub_dirs ) {
        my $new_sub_src_dir = File::Spec->catdir( $sub_src_dir, $sub_dir );
        my $full_dest_fpath = File::Spec->catdir( $base_dest_dir, $new_sub_src_dir );
        my ( $err, $out ) = $self->do_rcc( "mkdir $full_dest_fpath", 1 );
        return 0 if $err;
        return 0 unless $self->put_dir_content( $base_src_dir, $new_sub_src_dir, $base_dest_dir );
    }

    return 1;
}


=head2 renew_server_dir

Remove old (if needed) and put new App::ReDevelS source files (script, base dist and
arch dist libraries) on server.

* full - remove dir and copy new
* smart - no not send content if exists on remote machine - ToDo
$ remove - only remove server dir
* no - do nothing

=cut

sub renew_server_dir {
    my ( $self, $renew_type ) = @_;

    print "Running renew_server_dir type $renew_type.\n" if $self->{ver} >= 5;
    return 1 if $renew_type eq 'no';

    my $server_dir = $self->{server_dir};

    # check if dir (source on server) exists
    my $dir_exists = $self->check_is_dir( $server_dir );
    return 0 unless defined $dir_exists;

    # remove old dir
    if ( $dir_exists ) {
        return 0 unless $self->remove_server_dir();
    }

    return 1 if $renew_type eq 'remove';

    unless ( $self->{host_dist_type} ) {
        return $self->err("Parameter 'host_dist_type' is mandatory for this command.");
    }

    my $server_src_dir = $self->{server_src_dir};

    # create new
    my ( $err, $out ) = $self->do_rcc( "mkdir $server_dir", 1 );
    return 0 if $err;

    # put base script
    my $server_src_name = 'app-redevels.pl';
    my $server_src_fpath = File::Spec->catfile( $server_src_dir, $server_src_name );
    $self->{ssh}->scp_put( $server_src_fpath, $server_dir );

    # put base dist directory
    my $dist_base_src_dir = File::Spec->catdir( $server_src_dir, 'dist', '_base' );
    return 0 unless $self->put_dir_content( $dist_base_src_dir, '', $server_dir );

    # put arch dist directory
    my $dist_type = $self->{host_dist_type};
    my $dist_arch_src_dir = File::Spec->catdir( $server_src_dir, 'dist', $dist_type );
    return 0 unless $self->put_dir_content( $dist_arch_src_dir, '', $server_dir );

    print "Command 'renew_server_dir' succeeded.\n" if $self->{ver} >= 3;
    return 1;
}


=head2 start_rpc_shell

Start App::ReDevelS RPC shell on server machine.

=cut

sub start_rpc_shell {
    my ( $self ) = @_;

    print "Starting RPC shell on host.\n" if $self->{ver} >= 5;
    my $server_src_name = 'app-redevels.pl';
    my $server_script_fpath = File::Spec->catfile( $self->{server_dir}, $server_src_name );

    my $server_start_cmd = "nice -n $self->{rpc_nice} /usr/bin/perl $server_script_fpath $self->{rpc_ver}";

    print "Server start command: '$server_start_cmd'\n" if $self->{ver} >= 7;
    my $rpc = SSH::RPC::PP::Client->new(
        $self->{ssh},
        $server_start_cmd,
        $self->{ver}
    );
    $self->{rpc} = $rpc;
    $self->{rpc_last_cmd} = undef;

    print "RPC shell started ok.\n" if $self->{ver} >= 5;
    return 1;
}


=head2 rpc_shell_is_running

Return 1 if RPC shell is running on server.

=cut

sub rpc_shell_is_running {
    my ( $self ) = @_;
    return ( defined $self->{rpc} );
}


=head2 stop_rpc_shell

Stop App::ReDevelS RPC shell on server machine.

=cut

sub stop_rpc_shell {
    my ( $self ) = @_;

    print "Stopping RPC shell.\n" if $self->{ver} >= 5;
    $self->{rpc} = undef;
    $self->{rpc_last_cmd} = undef;
    return 1;
}


=head2 validate_result_obj

Validate result_obj from do_rpc or get_next_response method.

=cut

sub validate_result_obj {
    my ( $self, $result_obj, $report_response_error ) = @_;

    my $is_ok = $result_obj->isSuccess;

    $result_obj->dump() if $self->{ver} >= 7 || ( !$is_ok && $self->{ver} >= 1 );

    if ( ! $is_ok ) {
        my $err_msg = "Fatal error for server shell command '$self->{rpc_last_cmd}': '" . $result_obj->getStatusMessage() . "'";
        $self->err( $err_msg );
        return undef;
    }

    if ( $report_response_error ) {
        my $err = $result_obj->getResponseError();
        if ( defined  $err )  {
            my $base_err_msg = ( ref $err ? Dumper( $err ) : $err );
            my $err_msg = "Error for server shell command '$self->{rpc_last_cmd}': '$base_err_msg'";
            $self->err( $err_msg );
            return undef;
        }
    }

    return $result_obj;

}


=head2 do_rpc

Run command (remote procedure) on server shell. Return result_obj or undef (on error).

=cut

sub do_rpc {
    my ( $self, $cmd, $cmd_conf, $report_response_error ) = @_;
    $report_response_error = 1 unless defined $report_response_error;

    print "Running shell command '$cmd':\n" if $self->{ver} >= 6;
    $self->{rpc_last_cmd} = $cmd;

    my $result_obj = $self->{rpc}->run( $cmd, $cmd_conf );
    return $self->validate_result_obj( $result_obj, $report_response_error );
}


=head2 do_debug_rpc

Run command (remote procedure) on server shell in debug mode. Return exit code of SSH system command.

=cut

sub do_debug_rpc {
    my ( $self, $cmd, $cmd_conf ) = @_;

    print "Running shell command '$cmd' in debug mode:\n" if $self->{ver} >= 5;
    $self->{rpc_last_cmd} = $cmd;

    my $ret_code = $self->{rpc}->debug_run( $cmd, $cmd_conf );
    return $ret_code;
}


=head2 get_next_response

Run next response for running command started by do_rpc method.

=cut

sub get_next_response {
    my ( $self, $report_response_error ) = @_;
    $report_response_error = 1 unless defined $report_response_error;

    my $result_obj = $self->{rpc}->get_next_response();
    return $self->validate_result_obj( $result_obj, $report_response_error );
}


=head2 compare_test_name

Compare test name in provided response. Return 1 on succeed or sets error.

=cut

sub compare_test_name {
    my ( $self, $response, $expected_test_name ) = @_;

    my $test_name = $response->{test};

    if ( (not defined $test_name) || $test_name ne $expected_test_name ) {
        my $msg_test_name = 'undef';
        $msg_test_name = "'$test_name'" if defined $test_name;
        return $self->err("Response should contain '$expected_test_name' as test name, but contains $msg_test_name.");
    }

    return 1;
}


=head2 test_noop_rpc

Run 'test_noop' remote procedure.

=cut

sub test_noop_rpc {
    my ( $self ) = @_;

    my $result_obj = $self->do_rpc( 'test_noop', undef, 1 );
    return 0 unless defined $result_obj;

    my $response = $result_obj->getResponse();
    return 0 unless $self->compare_test_name( $response, 'noop' );

    print "Command 'test_noop' succeeded.\n" if $self->{ver} >= 3;
    return 1;
}


=head2 compare_test_three_parts_response

Compare test name in provided response. Return 1 on succeed or sets error.

=cut

sub compare_test_three_parts_response {
    my ( $self, $response, $expected_test_name, $expected_test_part_num ) = @_;

    return 0 unless $self->compare_test_name( $response, $expected_test_name );

    my $test_part_num = $response->{part_num};
    if ( (not defined $test_part_num) || $test_part_num ne $expected_test_part_num ) {
        $test_part_num = 'undef' unless defined $test_part_num;
        return $self->err("Attribute part_num in response should be $expected_test_part_num, but is $test_part_num.");
    }

    return 1;
}


=head2 test_three_parts_rpc

Run 'test_three_parts' remote procedure.

=cut

sub test_three_parts_rpc {
    my ( $self ) = @_;

    my $expected_test_part_num = 1;
    my $result_obj = $self->do_rpc( 'test_three_parts', undef, 1 );
    return 0 unless defined $result_obj;

    my $response = $result_obj->getResponse();
    return 0 unless $self->compare_test_three_parts_response( $response, 'three_parts', $expected_test_part_num );

    while ( $result_obj->isSuccess && !$result_obj->isLast ) {
        $expected_test_part_num++;
        $result_obj = $self->get_next_response( 1 );

        $response = $result_obj->getResponse();
        return 0 unless $self->compare_test_three_parts_response( $response, 'three_parts', $expected_test_part_num );
    }

    print "Command 'test_three_parts_rpc' succeeded.\n" if $self->{ver} >= 3;
    return 1;
}


=head1 SEE ALSO

L<SSH::RPC::PP::Client>, L<App::ReDevel>.

=head1 LICENSE

This file is part of App::ReDevel. See L<App::ReDevel> license.

=cut


1;
