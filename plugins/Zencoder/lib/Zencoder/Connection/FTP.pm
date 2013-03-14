package Zencoder::Connection::FTP;

use strict;
use warnings;

use File::Basename;

# Create the basic FTP connection format based on the plugin Settings:
# `ftp://user:password@ftp.example.com`
sub base {
    my $plugin = MT->component('zencoder');

    # Prep the FTP credentials to be used for the output URLs.
    my $ftp_server = $plugin->get_config_value('ftp_server');
    my $ftp_user   = $plugin->get_config_value('ftp_user');
    my $ftp_pass   = $plugin->get_config_value('ftp_pass');
    my $ftp        = '';

    if ( $ftp_server && $ftp_user && $ftp_pass) {
        # Compose a string to be used for the FTP connection. The $ftp_path is
        # modified for each output, below, to ensure relative uniqueness for
        # each output.
        return "ftp://$ftp_user:$ftp_pass@" . $ftp_server;
    }
    else {
        die "Zencoder configuration was not completed: review the FTP "
            . "Connection Configuration fields in Zencoder's plugin Settings "
            . "before resubmitting.";
    }
}

# Grab the FTP path specified in the plugin Settings.
sub ftp_path {
    my $plugin = MT->component('zencoder');
    my $path = $plugin->get_config_value('ftp_path');

    if ( $path ) {
        return $path;
    }
    else {
        die "Zencoder configuration was not completed: review the FTP "
            . "Connection Configuration FTP Destination Path in Zencoder's "
            . "plugin Settings before resubmitting.";
    }
}

# Grab the absolute server path specified in the plugin Settings.
sub server_path {
    my $plugin = MT->component('zencoder');
    my $path = $plugin->get_config_value('server_path');

    if ( $path ) {
        return $path;
    }
    else {
        die "Zencoder configuration was not completed: review the FTP "
            . "Connection Configuration Server Destination Path in Zencoder's "
            . "plugin Settings before resubmitting.";
    }
}

# Move the file from the FTP'd location to the MT-accessible location.
sub save_file {
    my ($arg_ref)  = @_;
    my $connection = $arg_ref->{connection};
    my $source_url = $arg_ref->{source_url};
    my $dest_path  = $arg_ref->{dest_path};
    my $blog       = $arg_ref->{blog};
    my $fmgr       = $blog->file_mgr;

    my $ftp_path    = $connection->{ftp_path};
    my $server_path = $connection->{server_path};

    # Source: this output's file has been saved to the server already, to the
    # location specified in $ftp_path. The $ftp_path doesn't necessarily
    # correspond to the server path, so strip the $ftp_path and replace it with
    # the $server_path. That should give us a real path where the file can be
    # found.
    # Strip everything prior to the $ftp_path
    $source_url =~ s/^.*$ftp_path(.*)/$1/;
    # Rebuild the path.
    $source_url = File::Spec->catfile( $server_path, $1);

    # Can the source file be found with this new path?
    if ( !$fmgr->exists($source_url) ) {
        MT->log({
            level   => MT->model('log')->ERROR(),
            blog_id => $blog->id,
            class   => 'zencoder',
            message => "Zencoder Notification was unable to find an expected "
                . "file at the source path of $source_url.",
        });
        return {
            success => 0,
        };
    }

    # Build the destination path for the asset file.
    my ($filename, undef, $ext) = fileparse($source_url, '\..*?');
    my $dest = File::Spec->catfile( $dest_path, $filename . $ext );

    # Check if the destination is empty. That is, we don't want to overwrite
    # another file. If the $dest exists we need to come up with a new file name;
    # keep trying to find a new file name until we get something unique.
    my $counter = 0;
    while ( $fmgr->exists($dest) ) {
        # A file already exists at the destination. We want to come up with a
        # unique name for the file so it won't overwrite something else.
        $dest = File::Spec->catfile(
            $dest_path,
            $filename . '-' . ++$counter . $ext
        );
    }

    # Collect the final filename with counter.
    $filename .= '-' . $counter
        if $counter;

    # Finally, the file is prepped and we've got a unique file name for this
    # asset. Move it!
    my $success;
    if ( $fmgr->rename($source_url, $dest) ) {
        $success = 1;
    }
    # Moving the file failed!
    else {
        $success = 0;
        MT->log({
            level   => MT->model('log')->ERROR(),
            blog_id => $blog->id,
            class   => 'zencoder',
            message => "Zencoder Notification was unable to move the file "
                . "$source_url to its destination at $dest.",
        });
    }

    return {
        success   => $success,
        file_name => $filename . $ext,
        file_ext  => substr($ext, 1), # Strip the leading "."
    };
}

1;

__END__
